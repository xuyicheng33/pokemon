extends RefCounted
class_name DomainClashOrchestrator

const ServiceDependencyContractHelperScript := preload("res://src/composition/service_dependency_contract_helper.gd")

const COMPOSE_DEPS := [
	{
		"field": "field_apply_conflict_service",
		"source": "field_apply_conflict_service",
		"nested": true,
	},
]

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var field_apply_conflict_service: FieldApplyConflictService
var last_invalid_battle_code: Variant = null

func invalid_battle_code() -> Variant:
	return last_invalid_battle_code

func resolve_missing_dependency() -> String:
	return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)


func is_domain_command(command, content_index) -> bool:
	last_invalid_battle_code = null
	if command == null:
		return false
	if command.command_type != CommandTypesScript.SKILL and command.command_type != CommandTypesScript.ULTIMATE:
		return false
	if content_index == null:
		return false
	return content_index.is_domain_skill(String(command.skill_id))

func resolve_active_domain_creator_side_id(battle_state, content_index) -> String:
	last_invalid_battle_code = null
	if battle_state == null or battle_state.field_state == null or content_index == null:
		return ""
	var active_field_definition = content_index.fields.get(String(battle_state.field_state.field_def_id), null)
	if active_field_definition == null:
		last_invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
		return ""
	var creator_id := String(battle_state.field_state.creator)
	if creator_id.is_empty():
		last_invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
		return ""
	var creator_side = battle_state.get_side_for_unit(creator_id)
	if creator_side == null:
		last_invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
		return ""
	if String(active_field_definition.field_kind).strip_edges() != ContentSchemaScript.FIELD_KIND_DOMAIN:
		return ""
	return String(creator_side.side_id)

func is_side_domain_recast_blocked(battle_state, side_id: String, content_index) -> bool:
	var creator_side_id := resolve_active_domain_creator_side_id(battle_state, content_index)
	if creator_side_id.is_empty():
		return false
	return creator_side_id == side_id

func is_domain_command_blocked_by_active_side_domain(command, battle_state, content_index) -> bool:
	if not is_domain_command(command, content_index):
		return false
	return is_side_domain_recast_blocked(battle_state, String(command.side_id), content_index)

func can_bypass_domain_recast_for_clash(queued_action, command, battle_state, content_index) -> bool:
	last_invalid_battle_code = null
	if queued_action == null or not bool(queued_action.domain_clash_protected):
		return false
	if not is_domain_command(command, content_index):
		return false
	var creator_side_id := resolve_active_domain_creator_side_id(battle_state, content_index)
	if creator_side_id.is_empty():
		return false
	return creator_side_id != String(command.side_id)

func mark_domain_clash_protection(queued_actions: Array, content_index) -> void:
	last_invalid_battle_code = null
	var first_domain_action_by_side: Dictionary = {}
	for queued_action in queued_actions:
		var command = queued_action.command
		if not is_domain_command(command, content_index):
			continue
		if not first_domain_action_by_side.has(command.side_id):
			first_domain_action_by_side[command.side_id] = queued_action
	if first_domain_action_by_side.size() < 2:
		return
	var protected_domain_actions: Array = first_domain_action_by_side.values()
	for domain_action in protected_domain_actions:
		domain_action.domain_clash_protected = true
	protected_domain_actions.sort_custom(func(left, right): return left.queue_index < right.queue_index)
	protected_domain_actions[0].defer_domain_success_effects = true

func resolve_field_conflict(before_field, challenger_field_definition, effect_event, battle_state, content_index) -> Dictionary:
	last_invalid_battle_code = null
	if before_field == null:
		return {
			"blocked": false,
			"should_break_before_apply": false,
			"clash_result": null,
		}
	if content_index == null:
		last_invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
		return {}
	var incumbent_field_definition = content_index.fields.get(String(before_field.field_def_id), null)
	if incumbent_field_definition == null:
		last_invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
		return {}
	var blocked_by_domain: bool = field_apply_conflict_service.is_normal_field_blocked_by_domain(
		challenger_field_definition,
		incumbent_field_definition
	)
	var conflict_invalid_code = field_apply_conflict_service.invalid_battle_code()
	if conflict_invalid_code != null:
		last_invalid_battle_code = conflict_invalid_code
		return {}
	if blocked_by_domain:
		return {
			"blocked": true,
			"should_break_before_apply": false,
			"clash_result": null,
		}
	var should_resolve_clash: bool = field_apply_conflict_service.should_resolve_domain_clash(
		challenger_field_definition,
		incumbent_field_definition
	)
	conflict_invalid_code = field_apply_conflict_service.invalid_battle_code()
	if conflict_invalid_code != null:
		last_invalid_battle_code = conflict_invalid_code
		return {}
	if not should_resolve_clash:
		return {
			"blocked": false,
			"should_break_before_apply": true,
			"clash_result": null,
		}
	var clash_resolution: Dictionary = field_apply_conflict_service.resolve_field_clash(before_field, effect_event, battle_state)
	if clash_resolution.has("invalid_code"):
		last_invalid_battle_code = clash_resolution["invalid_code"]
		return {}
	var clash_result = clash_resolution.get("clash_result", null)
	return {
		"blocked": false,
		"should_break_before_apply": clash_result != null and bool(clash_result.challenger_won),
		"clash_result": clash_result,
	}
