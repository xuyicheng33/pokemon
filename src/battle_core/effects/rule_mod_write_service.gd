extends RefCounted
class_name RuleModWriteService

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const RuleModSchemaScript := preload("res://src/battle_core/content/rule_mod_schema.gd")
const RuleModInstanceScript := preload("res://src/battle_core/runtime/rule_mod_instance.gd")
const RuleModOwnerScopeServiceScript := preload("res://src/battle_core/effects/rule_mod_owner_scope_service.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const ErrorStateHelperScript := preload("res://src/shared/error_state_helper.gd")

const FIELD_OWNER_ID := "field"
const STACKING_KEY_SCHEMA_BY_KIND := RuleModSchemaScript.STACKING_KEY_SCHEMA_BY_KIND

var id_factory
var last_error_code: Variant = null
var last_error_message: String = ""
var last_apply_skipped: bool = false
var _rule_mod_schema = RuleModSchemaScript.new()
var _owner_scope_service = RuleModOwnerScopeServiceScript.new()

func error_state() -> Dictionary:
	return ErrorStateHelperScript.error_state(self)

func create_instance(rule_mod_payload, owner_ref: Dictionary, battle_state, source_instance_id: String, source_kind_order: int, source_order_speed_snapshot: int, resolved_value = null, source_stacking_token: String = "") -> Variant:
	ErrorStateHelperScript.clear(self)
	last_apply_skipped = false
	if not _validate_rule_mod_payload(rule_mod_payload):
		return null
	if not _owner_scope_service.validate_owner_ref(owner_ref, rule_mod_payload.scope, battle_state):
		ErrorStateHelperScript.capture_service_state(self, _owner_scope_service)
		return null
	var owner_instances: Array = _owner_scope_service.get_owner_instances(battle_state, owner_ref)
	var resolved_source_stacking_key := _resolve_source_stacking_key(rule_mod_payload, source_stacking_token, source_instance_id)
	var stacking_key: String = _build_stacking_key(rule_mod_payload, owner_ref, resolved_source_stacking_key)
	if last_error_code != null:
		return null
	var existing_instance = _find_existing(owner_instances, stacking_key)
	var runtime_value = _resolve_runtime_value(rule_mod_payload, resolved_value)
	if last_error_code != null:
		return null
	match rule_mod_payload.stacking:
		ContentSchemaScript.STACKING_NONE:
			if existing_instance != null:
				last_apply_skipped = true
				return existing_instance
		ContentSchemaScript.STACKING_REFRESH:
			if existing_instance != null:
				existing_instance.remaining = rule_mod_payload.duration if rule_mod_payload.duration_mode == "turns" else -1
				existing_instance.value = runtime_value
				existing_instance.persists_on_switch = bool(rule_mod_payload.persists_on_switch)
				existing_instance.source_instance_id = source_instance_id
				existing_instance.source_kind_order = source_kind_order
				existing_instance.source_order_speed_snapshot = source_order_speed_snapshot
				existing_instance.source_stacking_key = resolved_source_stacking_key
				existing_instance.required_incoming_command_types = rule_mod_payload.required_incoming_command_types.duplicate()
				existing_instance.required_incoming_combat_type_ids = rule_mod_payload.required_incoming_combat_type_ids.duplicate()
				last_apply_skipped = false
				return existing_instance
		ContentSchemaScript.STACKING_REPLACE:
			if existing_instance != null:
				owner_instances.erase(existing_instance)
	var rule_mod_instance = RuleModInstanceScript.new()
	rule_mod_instance.instance_id = id_factory.next_id("rule_mod")
	rule_mod_instance.mod_kind = rule_mod_payload.mod_kind
	rule_mod_instance.mod_op = rule_mod_payload.mod_op
	rule_mod_instance.value = runtime_value
	rule_mod_instance.scope = rule_mod_payload.scope
	rule_mod_instance.duration_mode = rule_mod_payload.duration_mode
	rule_mod_instance.owner_scope = owner_ref["scope"]
	rule_mod_instance.owner_id = owner_ref["id"]
	rule_mod_instance.field_instance_id = _owner_scope_service.resolve_field_instance_id(owner_ref, battle_state)
	rule_mod_instance.stacking_key = stacking_key
	rule_mod_instance.remaining = rule_mod_payload.duration if rule_mod_payload.duration_mode == "turns" else -1
	rule_mod_instance.created_turn = battle_state.turn_index
	rule_mod_instance.decrement_on = rule_mod_payload.decrement_on
	rule_mod_instance.source_instance_id = source_instance_id
	rule_mod_instance.source_kind_order = source_kind_order
	rule_mod_instance.source_order_speed_snapshot = source_order_speed_snapshot
	rule_mod_instance.priority = rule_mod_payload.priority
	rule_mod_instance.persists_on_switch = bool(rule_mod_payload.persists_on_switch)
	rule_mod_instance.source_stacking_key = resolved_source_stacking_key
	rule_mod_instance.required_incoming_command_types = rule_mod_payload.required_incoming_command_types.duplicate()
	rule_mod_instance.required_incoming_combat_type_ids = rule_mod_payload.required_incoming_combat_type_ids.duplicate()
	owner_instances.append(rule_mod_instance)
	_owner_scope_service.set_owner_instances(battle_state, owner_ref, owner_instances)
	return rule_mod_instance

func decrement_for_trigger(battle_state, trigger_name: String) -> Array:
	var removed_instances: Array = []
	for side_state in battle_state.sides:
		for unit_state in side_state.team_units:
			var unit_result: Dictionary = _owner_scope_service.decrement_owner_instances(unit_state.rule_mod_instances, unit_state.unit_instance_id, trigger_name)
			unit_state.rule_mod_instances = unit_result["keep_instances"]
			removed_instances.append_array(unit_result["removed_instances"])
	var field_result: Dictionary = _owner_scope_service.decrement_owner_instances(battle_state.field_rule_mod_instances, FIELD_OWNER_ID, trigger_name)
	battle_state.field_rule_mod_instances = field_result["keep_instances"]
	removed_instances.append_array(field_result["removed_instances"])
	return removed_instances

func _find_existing(owner_instances: Array, stacking_key: String) -> Variant:
	for rule_mod_instance in owner_instances:
		if rule_mod_instance.stacking_key == stacking_key:
			return rule_mod_instance
	return null

func _validate_rule_mod_payload(rule_mod_payload) -> bool:
	if _rule_mod_schema.validate_payload(rule_mod_payload).is_empty():
		return true
	ErrorStateHelperScript.fail(self, ErrorCodesScript.INVALID_RULE_MOD_DEFINITION, "rule_mod payload failed schema validation")
	return false

func _build_stacking_key(rule_mod_payload, owner_ref: Dictionary, source_stacking_key: String) -> String:
	var schema: Array = _resolve_stacking_key_schema(String(rule_mod_payload.mod_kind))
	if schema.is_empty():
		ErrorStateHelperScript.fail(self, ErrorCodesScript.INVALID_RULE_MOD_DEFINITION, "Missing stacking key schema for rule_mod kind: %s" % rule_mod_payload.mod_kind)
		return ""
	var key_parts: PackedStringArray = PackedStringArray()
	for field_name in schema:
		match str(field_name):
			"mod_kind":
				key_parts.append(str(rule_mod_payload.mod_kind))
			"scope":
				key_parts.append(str(rule_mod_payload.scope))
			"owner_scope":
				key_parts.append(str(owner_ref["scope"]))
			"owner_id":
				key_parts.append(str(owner_ref["id"]))
			"mod_op":
				key_parts.append(str(rule_mod_payload.mod_op))
			"source_stacking_key":
				key_parts.append(source_stacking_key)
			"value":
				key_parts.append(_resolve_stacking_value_token(rule_mod_payload))
			_:
				ErrorStateHelperScript.fail(self, ErrorCodesScript.INVALID_RULE_MOD_DEFINITION, "Unknown stacking key field: %s" % str(field_name))
				return ""
	return "|".join(key_parts)

func _resolve_stacking_key_schema(mod_kind: String) -> Array:
	return STACKING_KEY_SCHEMA_BY_KIND.get(mod_kind, [])

func _resolve_stacking_value_token(rule_mod_payload) -> String:
	if rule_mod_payload.mod_kind == ContentSchemaScript.RULE_MOD_ACTION_LEGALITY:
		var action_value := String(rule_mod_payload.value).strip_edges()
		if action_value == ContentSchemaScript.ACTION_LEGALITY_ALL \
		or action_value == ContentSchemaScript.ACTION_LEGALITY_SKILL \
		or action_value == ContentSchemaScript.ACTION_LEGALITY_ULTIMATE \
			or action_value == ContentSchemaScript.ACTION_LEGALITY_SWITCH:
			return "action:%s" % action_value
		return "skill:%s" % action_value
	return str(rule_mod_payload.value)

func _resolve_source_stacking_key(rule_mod_payload, source_stacking_token: String, source_instance_id: String) -> String:
	var payload_key := String(rule_mod_payload.stacking_source_key).strip_edges()
	if not payload_key.is_empty():
		return payload_key
	var provided_key := String(source_stacking_token).strip_edges()
	if not provided_key.is_empty():
		return provided_key
	return str(source_instance_id)

func _resolve_runtime_value(rule_mod_payload, resolved_value) -> Variant:
	var runtime_value = resolved_value if resolved_value != null else rule_mod_payload.value
	match String(rule_mod_payload.mod_kind):
		ContentSchemaScript.RULE_MOD_MP_REGEN, ContentSchemaScript.RULE_MOD_INCOMING_ACCURACY:
			if typeof(runtime_value) != TYPE_INT and typeof(runtime_value) != TYPE_FLOAT:
				ErrorStateHelperScript.fail(self, ErrorCodesScript.INVALID_RULE_MOD_DEFINITION, "%s runtime value must be int" % String(rule_mod_payload.mod_kind))
				return null
			if not is_equal_approx(float(runtime_value), float(int(runtime_value))):
				ErrorStateHelperScript.fail(self, ErrorCodesScript.INVALID_RULE_MOD_DEFINITION, "%s runtime value must be int" % String(rule_mod_payload.mod_kind))
				return null
			return int(runtime_value)
	return runtime_value
