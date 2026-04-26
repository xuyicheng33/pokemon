extends RefCounted
class_name ActionCastHitService

const DependencyContractHelperScript := preload("res://src/shared/dependency_contract_helper.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const LeaveStatesScript := preload("res://src/shared/leave_states.gd")

const COMPOSE_DEPS := [
	{"field": "hit_service", "source": "hit_service", "nested": true},
	{"field": "rule_mod_service", "source": "rule_mod_service", "nested": true},
	{"field": "rng_service", "source": "rng_service", "nested": true},
]

var hit_service: HitService
var rule_mod_service: RuleModService
var rng_service: RngService

func resolve_missing_dependency() -> String:
	return DependencyContractHelperScript.resolve_missing_dependency(self)

func resolve_hit(command: Command, skill_definition, resolved_target, battle_state: BattleState, content_index: BattleContentIndex) -> Dictionary:
	if command.command_type == CommandTypesScript.RESOURCE_FORCED_DEFAULT:
		return _hit_result(true, null)
	var resolved_accuracy: int = _resolve_base_accuracy(skill_definition)
	var field_accuracy_result: Dictionary = _apply_field_accuracy_override(
		resolved_accuracy,
		command,
		skill_definition,
		resolved_target,
		battle_state,
		content_index
	)
	if field_accuracy_result.get("invalid_battle_code", null) != null:
		return field_accuracy_result
	var incoming_accuracy_result: Dictionary = _apply_incoming_accuracy_override(
		int(field_accuracy_result.get("accuracy", resolved_accuracy)),
		command,
		skill_definition,
		resolved_target,
		battle_state
	)
	if incoming_accuracy_result.get("invalid_battle_code", null) != null:
		return incoming_accuracy_result
	resolved_accuracy = int(incoming_accuracy_result.get("accuracy", resolved_accuracy))
	if resolved_accuracy < 0:
		push_error("ActionCastHitService.resolve_hit: accuracy must be >= 0; actor=%s skill=%s accuracy=%d" % [
			String(command.actor_id),
			String(skill_definition.id) if skill_definition != null else "<null>",
			resolved_accuracy,
		])
		assert(false, "ActionCastHitService resolved_accuracy < 0")
	var hit_info: Dictionary = _roll_hit_result(resolved_accuracy)
	battle_state.rng_stream_index = rng_service.get_stream_index()
	return hit_info

func _resolve_base_accuracy(skill_definition) -> int:
	return int(skill_definition.accuracy)

func _apply_field_accuracy_override(base_accuracy: int, command: Command, skill_definition, resolved_target, battle_state: BattleState, content_index: BattleContentIndex) -> Dictionary:
	if battle_state.field_state == null or command.actor_id != battle_state.field_state.creator:
		return _accuracy_result(base_accuracy)
	var field_definition = content_index.fields.get(battle_state.field_state.field_def_id) if content_index != null else null
	if field_definition == null:
		return _accuracy_result(base_accuracy)
	if int(field_definition.creator_accuracy_override) < 0:
		return _accuracy_result(base_accuracy)
	var nullify_result: Dictionary = _should_nullify_field_accuracy(command, skill_definition, resolved_target, battle_state)
	if nullify_result.get("invalid_battle_code", null) != null:
		return nullify_result
	if bool(nullify_result.get("nullify", false)):
		return _accuracy_result(base_accuracy)
	return _accuracy_result(int(field_definition.creator_accuracy_override))

func _apply_incoming_accuracy_override(base_accuracy: int, command: Command, skill_definition, resolved_target, battle_state: BattleState) -> Dictionary:
	if base_accuracy >= 100:
		return _accuracy_result(base_accuracy)
	if not _should_read_incoming_accuracy(command, skill_definition, resolved_target, battle_state):
		return _accuracy_result(base_accuracy)
	var resolved_accuracy: int = rule_mod_service.resolve_incoming_accuracy(
		battle_state,
		resolved_target.unit_instance_id,
		base_accuracy
	)
	var rule_error: Dictionary = rule_mod_service.error_state()
	if rule_error.get("code", null) != null:
		return _invalid_result(rule_error.get("code", null))
	return _accuracy_result(resolved_accuracy)

func _roll_hit_result(resolved_accuracy: int) -> Dictionary:
	return hit_service.roll_hit(resolved_accuracy, rng_service)

func _should_nullify_field_accuracy(command: Command, skill_definition, resolved_target, battle_state: BattleState) -> Dictionary:
	if not _should_read_incoming_accuracy(command, skill_definition, resolved_target, battle_state):
		return {"nullify": false, "invalid_battle_code": null}
	var nullify := rule_mod_service.has_nullify_field_accuracy(
		battle_state,
		resolved_target.unit_instance_id
	)
	var rule_error: Dictionary = rule_mod_service.error_state()
	if rule_error.get("code", null) != null:
		return {"nullify": false, "invalid_battle_code": rule_error.get("code", null)}
	return {"nullify": nullify, "invalid_battle_code": null}

func _should_read_incoming_accuracy(command: Command, skill_definition, resolved_target, battle_state: BattleState) -> bool:
	if command.command_type != CommandTypesScript.SKILL and command.command_type != CommandTypesScript.ULTIMATE:
		return false
	if skill_definition == null or String(skill_definition.targeting) != ContentSchemaScript.TARGET_ENEMY_ACTIVE:
		return false
	if resolved_target == null or resolved_target.leave_state != LeaveStatesScript.ACTIVE or resolved_target.current_hp <= 0:
		return false
	var actor_side = battle_state.get_side_for_unit(command.actor_id)
	var target_side = battle_state.get_side_for_unit(resolved_target.unit_instance_id)
	return actor_side != null and target_side != null and actor_side.side_id != target_side.side_id

func _hit_result(hit: bool, hit_roll) -> Dictionary:
	return {"hit": hit, "hit_roll": hit_roll, "invalid_battle_code": null}

func _accuracy_result(accuracy: int) -> Dictionary:
	return {"accuracy": accuracy, "invalid_battle_code": null}

func _invalid_result(invalid_code) -> Dictionary:
	return {"accuracy": 0, "hit": false, "hit_roll": null, "invalid_battle_code": invalid_code}
