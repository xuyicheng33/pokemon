extends "res://test/support/gdunit_suite_bridge.gd"

const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const KashimoTestSupportScript := preload("res://tests/support/kashimo_test_support.gd")

var _support = KashimoTestSupportScript.new()

@warning_ignore("shadowed_global_identifier")
func _build_kashimo_state(harness, seed: int) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return core_payload
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return {"error": "SampleBattleFactory init failed"}
	var content_index = harness.build_loaded_content_index(sample_factory)
	var battle_state = _support.build_battle_state(core, content_index, _support.build_kashimo_setup(sample_factory), seed)
	return {
		"core": core,
		"content_index": content_index,
		"battle_state": battle_state,
	}

func _find_counter_damage(event_log: Array, target_instance_id: String) -> int:
	for event in event_log:
		if event.event_type != EventTypesScript.EFFECT_DAMAGE:
			continue
		if String(event.target_instance_id) != target_instance_id:
			continue
		if String(event.trigger_name) != "on_receive_action_hit":
			continue
		if event.value_changes.is_empty():
			continue
		return abs(int(event.value_changes[0].delta))
	return 0

func _build_override_field_state(field_def_id: String, creator_id: String):
	var field_state = preload("res://src/battle_core/runtime/field_state.gd").new()
	field_state.field_def_id = field_def_id
	field_state.instance_id = "test_kashimo_field_override"
	field_state.creator = creator_id
	field_state.remaining_turns = 3
	return field_state

func _find_rule_mod(unit_state, mod_kind: String):
	for rule_mod_instance in unit_state.rule_mod_instances:
		if String(rule_mod_instance.mod_kind) == mod_kind:
			return rule_mod_instance
	return null
