extends RefCounted
class_name BattleInitializer

const ServiceDependencyContractHelperScript := preload("res://src/composition/service_dependency_contract_helper.gd")

const COMPOSE_DEPS := [
	{
		"field": "id_factory",
		"source": "id_factory",
		"nested": true,
	},
	{
		"field": "rng_service",
		"source": "rng_service",
		"nested": true,
	},
	{
		"field": "faint_resolver",
		"source": "faint_resolver",
		"nested": true,
	},
	{
		"field": "trigger_batch_runner",
		"source": "trigger_batch_runner",
		"nested": true,
	},
	{
		"field": "battle_logger",
		"source": "battle_logger",
		"nested": true,
	},
	{
		"field": "log_event_builder",
		"source": "log_event_builder",
		"nested": true,
	},
	{
		"field": "combat_type_service",
		"source": "combat_type_service",
		"nested": true,
	},
	{
		"field": "mp_service",
		"source": "mp_service",
		"nested": true,
	},
	{
		"field": "rule_mod_service",
		"source": "rule_mod_service",
		"nested": true,
	},
	{
		"field": "battle_result_service",
		"source": "battle_result_service",
		"nested": true,
	},
	{
		"field": "field_lifecycle_service",
		"source": "turn_field_lifecycle_service",
		"nested": true,
	},
	{
		"field": "public_id_allocator",
		"source": "",
		"nested": false,
	},
	{
		"field": "_state_builder",
		"source": "",
		"nested": false,
	},
	{
		"field": "_phase_service",
		"source": "",
		"nested": false,
	},
]

const BattlePhasesScript := preload("res://src/shared/battle_phases.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const BattleResultScript := preload("res://src/battle_core/contracts/battle_result.gd")
const PublicIdAllocatorScript := preload("res://src/battle_core/turn/public_id_allocator.gd")
const BattleInitializerStateBuilderScript := preload("res://src/battle_core/turn/battle_initializer_state_builder.gd")
const BattleInitializerPhaseServiceScript := preload("res://src/battle_core/turn/battle_initializer_phase_service.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const INIT_PHASE_CONTINUE := 0
const INIT_PHASE_STOP := 1
const INIT_PHASE_FAIL := 2

var id_factory
var rng_service
var faint_resolver
var trigger_batch_runner
var battle_logger
var log_event_builder
var combat_type_service
var mp_service
var rule_mod_service
var battle_result_service
var field_lifecycle_service
var public_id_allocator = PublicIdAllocatorScript.new()
var _state_builder = BattleInitializerStateBuilderScript.new()
var _phase_service = BattleInitializerPhaseServiceScript.new()
var last_error_code: Variant = null
var last_error_message: String = ""

func resolve_missing_dependency() -> String:
	return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)

func error_state() -> Dictionary:
    return {
        "code": last_error_code,
        "message": last_error_message,
    }

func initialize_battle(battle_state, content_index, battle_setup) -> bool:
    last_error_code = null
    last_error_message = ""
    var missing_dependency := resolve_missing_dependency()
    if not missing_dependency.is_empty():
        return _fail(ErrorCodesScript.INVALID_COMPOSITION, "BattleInitializer missing dependency: %s" % missing_dependency)
    _sync_phase_service()
    missing_dependency = _phase_service.resolve_missing_dependency()
    if not missing_dependency.is_empty():
        return _fail(ErrorCodesScript.INVALID_COMPOSITION, "BattleInitializer missing dependency: %s" % missing_dependency)
    var format_config = _prepare_battle_state(battle_state, content_index, battle_setup)
    if format_config == null:
        return false
    if not _build_side_states(battle_state, battle_setup, format_config, content_index):
        return false
    _phase_service.append_battle_header_event(battle_state, content_index)
    var on_enter_outcome: int = _phase_service.run_on_enter_phase(battle_state, content_index)
    if on_enter_outcome == INIT_PHASE_FAIL:
        return false
    if on_enter_outcome == INIT_PHASE_STOP:
        return true
    if battle_result_service.resolve_initialization_victory(battle_state):
        return true
    var battle_init_outcome: int = _phase_service.run_battle_init_phase(battle_state, content_index)
    if battle_init_outcome == INIT_PHASE_FAIL:
        return false
    if battle_init_outcome == INIT_PHASE_STOP:
        return true
    if battle_result_service.resolve_initialization_victory(battle_state):
        return true
    if mp_service == null:
        return _fail(ErrorCodesScript.INVALID_COMPOSITION, "BattleInitializer requires mp_service for initial turn_start regen")
    if rule_mod_service == null:
        return _fail(ErrorCodesScript.INVALID_COMPOSITION, "BattleInitializer requires rule_mod_service for initial turn_start regen")
    _phase_service.apply_initial_turn_start_regen(battle_state)
    if battle_state.pre_applied_turn_start_regen_turn_index != battle_state.turn_index:
        return false
    battle_state.phase = BattlePhasesScript.SELECTION
    return true

func _prepare_battle_state(battle_state, content_index, battle_setup) -> Variant:
    if battle_setup == null:
        _fail(ErrorCodesScript.INVALID_BATTLE_SETUP, "Battle setup is required")
        return null
    if combat_type_service == null:
        _fail(ErrorCodesScript.INVALID_COMPOSITION, "BattleInitializer requires combat_type_service")
        return null
    if public_id_allocator == null:
        _fail(ErrorCodesScript.INVALID_COMPOSITION, "BattleInitializer requires public_id_allocator")
        return null
    if battle_result_service == null:
        _fail(ErrorCodesScript.INVALID_COMPOSITION, "BattleInitializer requires battle_result_service")
        return null
    var format_config = content_index.battle_formats.get(battle_setup.format_id)
    if format_config == null:
        _fail(ErrorCodesScript.INVALID_CONTENT_SNAPSHOT, "Missing battle format: %s" % battle_setup.format_id)
        return null
    combat_type_service.build_chart(format_config.combat_type_chart)
    if battle_setup.sides.size() != 2:
        _fail(ErrorCodesScript.INVALID_BATTLE_SETUP, "Current baseline requires exactly 2 sides")
        return null
    var setup_errors: Array = content_index.validate_setup(battle_setup)
    if not setup_errors.is_empty():
        _fail(ErrorCodesScript.INVALID_BATTLE_SETUP, "Battle setup validation failed:\n%s" % "\n".join(setup_errors))
        return null
    battle_logger.reset()
    battle_state.format_id = battle_setup.format_id
    battle_state.visibility_mode = String(format_config.visibility_mode).strip_edges()
    if battle_state.visibility_mode.is_empty():
        _fail(ErrorCodesScript.INVALID_CONTENT_SNAPSHOT, "Battle format visibility_mode must not be empty: %s" % battle_setup.format_id)
        return null
    battle_state.max_turn = format_config.max_turn
    battle_state.max_chain_depth = max(1, int(format_config.max_chain_depth))
    battle_state.battle_level = format_config.level
    battle_state.selection_deadline_ms = format_config.selection_deadline_ms
    battle_state.default_recoil_ratio = float(format_config.default_recoil_ratio)
    battle_state.domain_clash_tie_threshold = float(format_config.domain_clash_tie_threshold)
    battle_state.rng_profile = rng_service.get_profile()
    battle_state.phase = BattlePhasesScript.BATTLE_INIT
    battle_state.turn_index = 1
    battle_state.battle_result = BattleResultScript.new()
    battle_state.sides.clear()
    battle_state.fatal_damage_records_by_target.clear()
    battle_state.field_rule_mod_instances.clear()
    battle_state.last_matchup_signature = ""
    battle_state.pre_applied_turn_start_regen_turn_index = 0
    return format_config

func _build_side_states(battle_state, battle_setup, format_config, content_index) -> bool:
    for side_setup in battle_setup.sides:
        var side_state = _state_builder.build_side_state(side_setup, format_config, content_index, id_factory, public_id_allocator)
        if side_state == null:
            var state_builder_error: Dictionary = _state_builder.error_state()
            return _fail(
                state_builder_error.get("code", ErrorCodesScript.INVALID_BATTLE_SETUP),
                String(state_builder_error.get("message", "BattleInitializerStateBuilder failed"))
            )
        battle_state.sides.append(side_state)
    return true

func _sync_phase_service() -> void:
    _phase_service.id_factory = id_factory
    _phase_service.faint_resolver = faint_resolver
    _phase_service.trigger_batch_runner = trigger_batch_runner
    _phase_service.battle_logger = battle_logger
    _phase_service.log_event_builder = log_event_builder
    _phase_service.mp_service = mp_service
    _phase_service.rule_mod_service = rule_mod_service
    _phase_service.battle_result_service = battle_result_service
    _phase_service.field_lifecycle_service = field_lifecycle_service

func _fail(error_code: String, message: String) -> bool:
    last_error_code = error_code
    last_error_message = message
    return false
