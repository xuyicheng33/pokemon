extends RefCounted
class_name RuleModOwnerScopeService

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const ErrorStateHelperScript := preload("res://src/shared/error_state_helper.gd")

const OWNER_SCOPE_UNIT := "unit"
const OWNER_SCOPE_FIELD := "field"
const FIELD_OWNER_ID := "field"

var last_error_code: Variant = null
var last_error_message: String = ""

func error_state() -> Dictionary:
	return ErrorStateHelperScript.error_state(self)

func validate_owner_ref(owner_ref: Dictionary, payload_scope: String, battle_state: BattleState) -> bool:
	ErrorStateHelperScript.clear(self)
	if owner_ref == null or not owner_ref.has("scope") or not owner_ref.has("id"):
		ErrorStateHelperScript.fail(self, ErrorCodesScript.INVALID_RULE_MOD_DEFINITION, "rule_mod owner_ref must include scope/id")
		return false
	var owner_scope: String = str(owner_ref["scope"])
	var owner_id: String = str(owner_ref["id"])
	if owner_scope == OWNER_SCOPE_UNIT:
		if payload_scope == "field":
			ErrorStateHelperScript.fail(self, ErrorCodesScript.INVALID_RULE_MOD_DEFINITION, "field-scope rule_mod requires field owner")
			return false
		if battle_state.get_unit(owner_id) == null:
			ErrorStateHelperScript.fail(self, ErrorCodesScript.INVALID_STATE_CORRUPTION, "rule_mod owner unit missing: %s" % owner_id)
			return false
		return true
	if owner_scope == OWNER_SCOPE_FIELD:
		if payload_scope != "field" or owner_id != FIELD_OWNER_ID:
			ErrorStateHelperScript.fail(self, ErrorCodesScript.INVALID_RULE_MOD_DEFINITION, "field owner_ref must bind scope=field id=field")
			return false
		return true
	ErrorStateHelperScript.fail(self, ErrorCodesScript.INVALID_RULE_MOD_DEFINITION, "unsupported rule_mod owner scope: %s" % owner_scope)
	return false

func get_owner_instances(battle_state: BattleState, owner_ref: Dictionary) -> Array:
	var owner_scope: String = str(owner_ref["scope"])
	if owner_scope == OWNER_SCOPE_FIELD:
		return battle_state.field_rule_mod_instances
	var owner_unit = battle_state.get_unit(str(owner_ref["id"]))
	if owner_unit == null:
		return []
	return owner_unit.rule_mod_instances

func set_owner_instances(battle_state: BattleState, owner_ref: Dictionary, instances: Array) -> void:
	var owner_scope: String = str(owner_ref["scope"])
	if owner_scope == OWNER_SCOPE_FIELD:
		battle_state.field_rule_mod_instances = instances
		return
	var owner_unit = battle_state.get_unit(str(owner_ref["id"]))
	if owner_unit != null:
		owner_unit.rule_mod_instances = instances

func decrement_owner_instances(owner_instances: Array, owner_id: String, trigger_name: String) -> Dictionary:
	var keep_instances: Array = []
	var removed_instances: Array = []
	for rule_mod_instance in owner_instances:
		var should_remove: bool = false
		if rule_mod_instance.duration_mode == "turns" and rule_mod_instance.decrement_on == trigger_name:
			rule_mod_instance.remaining -= 1
			if rule_mod_instance.remaining <= 0:
				should_remove = true
		if should_remove:
			removed_instances.append({
				"owner_id": owner_id,
				"instance": rule_mod_instance,
			})
		else:
			keep_instances.append(rule_mod_instance)
	return {
		"keep_instances": keep_instances,
		"removed_instances": removed_instances,
	}

func resolve_field_instance_id(owner_ref: Dictionary, battle_state: BattleState) -> String:
	if str(owner_ref.get("scope", "")) != OWNER_SCOPE_FIELD:
		return ""
	if battle_state == null or battle_state.field_state == null:
		return ""
	return str(battle_state.field_state.instance_id)
