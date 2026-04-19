extends RefCounted
class_name BattleInitializerPhaseService

const ServiceDependencyContractHelperScript := preload("res://src/composition/service_dependency_contract_helper.gd")

const COMPOSE_DEPS := [
	{
		"field": "id_factory",
		"source": "id_factory",
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
]

const EventTypesScript := preload("res://src/shared/event_types.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const ChainContextScript := preload("res://src/battle_core/contracts/chain_context.gd")
const BattleHeaderSnapshotBuilderScript := preload("res://src/battle_core/turn/battle_header_snapshot_builder.gd")

const INIT_PHASE_CONTINUE := 0
const INIT_PHASE_STOP := 1
const INIT_PHASE_FAIL := 2

var id_factory: IdFactory = null
var faint_resolver: FaintResolver = null
var trigger_batch_runner: TriggerBatchRunner = null
var battle_logger: BattleLogger = null
var log_event_builder: LogEventBuilder = null
var mp_service: MpService = null
var rule_mod_service: RuleModService = null
var battle_result_service: BattleResultService = null
var field_lifecycle_service: TurnFieldLifecycleService = null

func resolve_missing_dependency() -> String:
	return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)

func configure_ports(ports: BattleInitializerPorts) -> void:
	if ports == null:
		id_factory = null
		faint_resolver = null
		trigger_batch_runner = null
		battle_logger = null
		log_event_builder = null
		mp_service = null
		rule_mod_service = null
		battle_result_service = null
		field_lifecycle_service = null
		return
	id_factory = ports.id_factory
	faint_resolver = ports.faint_resolver
	trigger_batch_runner = ports.trigger_batch_runner
	battle_logger = ports.battle_logger
	log_event_builder = ports.log_event_builder
	mp_service = ports.mp_service
	rule_mod_service = ports.rule_mod_service
	battle_result_service = ports.battle_result_service
	field_lifecycle_service = ports.field_lifecycle_service

func append_battle_header_event(battle_state, content_index) -> void:
	battle_state.chain_context = _build_system_chain(EventTypesScript.SYSTEM_BATTLE_HEADER, "battle_init")
	battle_logger.append_event(log_event_builder.build_event(
		EventTypesScript.SYSTEM_BATTLE_HEADER,
		battle_state,
		{
			"source_instance_id": EventTypesScript.SYSTEM_BATTLE_HEADER,
			"header_snapshot": BattleHeaderSnapshotBuilderScript.build_header_snapshot(battle_state, content_index),
			"payload_summary": "battle header",
		}
	))

func run_on_enter_phase(battle_state, content_index) -> int:
	battle_state.chain_context = _build_system_chain("system:replace", "system_replace")
	for side_state in battle_state.sides:
		var active_unit = side_state.get_active_unit()
		battle_logger.append_event(log_event_builder.build_event(
			EventTypesScript.STATE_ENTER,
			battle_state,
			{
				"source_instance_id": active_unit.unit_instance_id,
				"target_instance_id": active_unit.unit_instance_id,
				"target_slot": ContentSchemaScript.ACTIVE_SLOT_PRIMARY,
				"trigger_name": "on_enter",
				"payload_summary": "%s entered battle" % active_unit.public_id,
			}
		))
	var on_enter_invalid_code = _execute_trigger_batch("on_enter", battle_state, content_index, _collect_active_unit_ids(battle_state))
	if on_enter_invalid_code != null:
		battle_result_service.terminate_invalid_battle(battle_state, str(on_enter_invalid_code))
		return INIT_PHASE_FAIL
	var on_enter_faint_invalid_code = faint_resolver.resolve_faint_window(battle_state, content_index)
	if on_enter_faint_invalid_code != null:
		battle_result_service.terminate_invalid_battle(battle_state, str(on_enter_faint_invalid_code))
		return INIT_PHASE_FAIL
	return INIT_PHASE_STOP if field_lifecycle_service.execute_matchup_changed_if_needed(battle_state, content_index) else INIT_PHASE_CONTINUE

func run_battle_init_phase(battle_state, content_index) -> int:
	battle_state.chain_context = _build_system_chain(EventTypesScript.SYSTEM_BATTLE_INIT, "battle_init")
	battle_logger.append_event(log_event_builder.build_event(
		EventTypesScript.SYSTEM_BATTLE_INIT,
		battle_state,
		{
			"source_instance_id": "system:battle_init",
			"trigger_name": "battle_init",
			"payload_summary": "battle initialized",
		}
	))
	var battle_init_invalid_code = _execute_trigger_batch("battle_init", battle_state, content_index, _collect_active_unit_ids(battle_state))
	if battle_init_invalid_code != null:
		battle_result_service.terminate_invalid_battle(battle_state, str(battle_init_invalid_code))
		return INIT_PHASE_FAIL
	var battle_init_faint_invalid_code = faint_resolver.resolve_faint_window(battle_state, content_index)
	if battle_init_faint_invalid_code != null:
		battle_result_service.terminate_invalid_battle(battle_state, str(battle_init_faint_invalid_code))
		return INIT_PHASE_FAIL
	return INIT_PHASE_STOP if field_lifecycle_service.execute_matchup_changed_if_needed(battle_state, content_index) else INIT_PHASE_CONTINUE

func apply_initial_turn_start_regen(battle_state) -> void:
	for side_state in battle_state.sides:
		var active_unit = side_state.get_active_unit()
		if active_unit == null or active_unit.current_hp <= 0:
			continue
		var regen_value: int = rule_mod_service.resolve_mp_regen_value(
			battle_state,
			active_unit.unit_instance_id,
			active_unit.regen_per_turn
		)
		active_unit.current_mp = mp_service.apply_turn_start_regen(
			active_unit.current_mp,
			regen_value,
			active_unit.max_mp
		)
	battle_state.pre_applied_turn_start_regen_turn_index = battle_state.turn_index

func _execute_trigger_batch(trigger_name: String, battle_state, content_index, owner_unit_ids: Array) -> Variant:
	return trigger_batch_runner.execute_trigger_batch(trigger_name, battle_state, content_index, owner_unit_ids, battle_state.chain_context)

func _collect_active_unit_ids(battle_state) -> Array:
	var active_ids: Array = []
	for side_state in battle_state.sides:
		var active_unit = side_state.get_active_unit()
		if active_unit != null and active_unit.current_hp > 0:
			active_ids.append(active_unit.unit_instance_id)
	return active_ids

func _build_system_chain(command_type: String, chain_origin: String) -> Variant:
	var chain_context = ChainContextScript.new()
	chain_context.event_chain_id = id_factory.next_id("chain")
	chain_context.chain_origin = chain_origin
	chain_context.command_type = command_type
	chain_context.command_source = "system"
	chain_context.select_deadline_ms = null
	chain_context.select_timeout = null
	return chain_context

func _resolve_nested_missing_dependency(service) -> String:
	if service == null or not service.has_method("resolve_missing_dependency"):
		return ""
	return str(service.resolve_missing_dependency())
