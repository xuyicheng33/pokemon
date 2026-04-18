extends RefCounted
class_name BattleInitializerSetupValidator

const ServiceDependencyContractHelperScript := preload("res://src/composition/service_dependency_contract_helper.gd")

const COMPOSE_DEPS := [
	{
		"field": "rng_service",
		"source": "rng_service",
		"nested": true,
	},
	{
		"field": "battle_logger",
		"source": "battle_logger",
		"nested": true,
	},
	{
		"field": "combat_type_service",
		"source": "combat_type_service",
		"nested": true,
	},
]

const BattlePhasesScript := preload("res://src/shared/battle_phases.gd")
const BattleResultScript := preload("res://src/battle_core/contracts/battle_result.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var rng_service: RefCounted = null
var battle_logger: RefCounted = null
var combat_type_service: RefCounted = null
var last_error_code: Variant = null
var last_error_message: String = ""

func error_state() -> Dictionary:
	return {
		"code": last_error_code,
		"message": last_error_message,
	}

func resolve_missing_dependency() -> String:
	return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)

func configure_ports(ports: BattleInitializerPorts) -> void:
	if ports == null:
		rng_service = null
		battle_logger = null
		combat_type_service = null
		return
	rng_service = ports.rng_service
	battle_logger = ports.battle_logger
	combat_type_service = ports.combat_type_service

func validate_and_prepare_battle_state(battle_state, content_index, battle_setup) -> Variant:
	last_error_code = null
	last_error_message = ""
	if battle_setup == null:
		return _fail(ErrorCodesScript.INVALID_BATTLE_SETUP, "Battle setup is required")
	if content_index == null:
		return _fail(ErrorCodesScript.INVALID_CONTENT_SNAPSHOT, "BattleInitializer requires content_index")
	var format_config = content_index.battle_formats.get(battle_setup.format_id)
	if format_config == null:
		return _fail(ErrorCodesScript.INVALID_CONTENT_SNAPSHOT, "Missing battle format: %s" % battle_setup.format_id)
	combat_type_service.build_chart(format_config.combat_type_chart)
	if battle_setup.sides.size() != 2:
		return _fail(ErrorCodesScript.INVALID_BATTLE_SETUP, "Current baseline requires exactly 2 sides")
	var setup_errors: Array = content_index.validate_setup(battle_setup)
	if not setup_errors.is_empty():
		return _fail(ErrorCodesScript.INVALID_BATTLE_SETUP, "Battle setup validation failed:\n%s" % "\n".join(setup_errors))
	battle_logger.reset()
	battle_state.format_id = battle_setup.format_id
	battle_state.visibility_mode = String(format_config.visibility_mode).strip_edges()
	if battle_state.visibility_mode.is_empty():
		return _fail(
			ErrorCodesScript.INVALID_CONTENT_SNAPSHOT,
			"Battle format visibility_mode must not be empty: %s" % battle_setup.format_id
		)
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
	battle_state.rebuild_indexes()
	battle_state.fatal_damage_records_by_target.clear()
	battle_state.field_rule_mod_instances.clear()
	battle_state.last_matchup_signature = ""
	battle_state.pre_applied_turn_start_regen_turn_index = 0
	return format_config

func _fail(error_code: String, message: String) -> Variant:
	last_error_code = error_code
	last_error_message = message
	return null
