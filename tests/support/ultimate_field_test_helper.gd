extends RefCounted
class_name UltimateFieldTestHelper

const EventTypesScript := preload("res://src/shared/event_types.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const FieldDefinitionScript := preload("res://src/battle_core/content/field_definition.gd")
const ApplyFieldPayloadScript := preload("res://src/battle_core/content/apply_field_payload.gd")
const ResourceModPayloadScript := preload("res://src/battle_core/content/resource_mod_payload.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const GojoTestSupportScript := preload("res://tests/support/gojo_test_support.gd")

var _support = GojoTestSupportScript.new()

func build_gojo_vs_sample_state(harness, seed: int) -> Dictionary:
	return _support.build_gojo_vs_sample_state(harness, seed)

func build_gojo_vs_sukuna_state(harness, seed: int) -> Dictionary:
	return _support.build_gojo_battle_state(harness, seed, true, true)

func build_sukuna_vs_sample_state(harness, seed: int) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return core_payload
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return {"error": "SampleBattleFactory init failed"}
	var content_index = harness.build_loaded_content_index(sample_factory)
	var battle_setup = sample_factory.build_sample_setup()
	battle_setup.sides[0].unit_definition_ids = PackedStringArray(["sukuna", "sample_mossaur", "sample_tidekit"])
	battle_setup.sides[0].starting_index = 0
	battle_setup.sides[1].unit_definition_ids = PackedStringArray(["sample_pyron", "sample_mossaur", "sample_tidekit"])
	battle_setup.sides[1].starting_index = 0
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, seed, battle_setup)
	return {
		"core": core,
		"content_index": content_index,
		"battle_state": battle_state,
	}

func run_turn(core, battle_state, content_index, p1_command, p2_command) -> void:
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [p1_command, p2_command])

func build_skill_command(core, turn_index: int, side_id: String, actor_public_id: String, skill_id: String):
	return _support.build_skill_command(core, turn_index, side_id, actor_public_id, skill_id)

func build_wait_command(core, turn_index: int, side_id: String, actor_public_id: String):
	return _support.build_wait_command(core, turn_index, side_id, actor_public_id)

func build_switch_command(core, turn_index: int, side_id: String, actor_public_id: String, target_public_id: String):
	return _support.build_switch_command(core, turn_index, side_id, actor_public_id, target_public_id)

func build_ultimate_command(core, turn_index: int, side_id: String, actor_public_id: String, skill_id: String):
	return _support.build_ultimate_command(core, turn_index, side_id, actor_public_id, skill_id)

func find_side_snapshot(public_snapshot: Dictionary, side_id: String) -> Dictionary:
	for side_snapshot in public_snapshot.get("sides", []):
		if str(side_snapshot.get("side_id", "")) == side_id:
			return side_snapshot
	return {}

func has_ultimate_point_delta(event_log: Array, delta: int, after_value: int) -> bool:
	for log_event in event_log:
		if log_event.event_type != EventTypesScript.EFFECT_RESOURCE_MOD or log_event.value_changes.is_empty():
			continue
		var value_change = log_event.value_changes[0]
		if String(value_change.resource_name) == "ultimate_points" and int(value_change.delta) == delta and int(value_change.after_value) == after_value:
			return true
	return false

func find_field_clash_event(event_log: Array):
	for log_event in event_log:
		if log_event.event_type == EventTypesScript.EFFECT_FIELD_CLASH:
			return log_event
	return null

func has_rule_mod_apply_on_target(event_log: Array, target_unit_id: String) -> bool:
	for log_event in event_log:
		if log_event.event_type == EventTypesScript.EFFECT_RULE_MOD_APPLY and log_event.target_instance_id == target_unit_id:
			return true
	return false

func has_action_cancelled_pre_start_on_actor(event_log: Array, actor_unit_id: String) -> bool:
	for log_event in event_log:
		if log_event.event_type == EventTypesScript.ACTION_CANCELLED_PRE_START and log_event.target_instance_id == actor_unit_id:
			return true
	return false

func has_domain_block_log(event_log: Array, blocked_field_id: String) -> bool:
	for log_event in event_log:
		if log_event.event_type != EventTypesScript.EFFECT_FIELD_BLOCKED:
			continue
		if String(log_event.payload_summary).find("blocked field %s" % blocked_field_id) != -1:
			return true
	return false

func register_self_break_field_test_content(content_index) -> void:
	var break_payload = ResourceModPayloadScript.new()
	break_payload.payload_type = "resource_mod"
	break_payload.resource_key = "mp"
	break_payload.amount = 5
	var break_effect = EffectDefinitionScript.new()
	break_effect.id = "test_self_break_field_reward"
	break_effect.display_name = "Self Break Reward"
	break_effect.scope = "self"
	break_effect.trigger_names = PackedStringArray(["field_break"])
	break_effect.payloads.clear()
	break_effect.payloads.append(break_payload)
	content_index.register_resource(break_effect)

	var field_definition = FieldDefinitionScript.new()
	field_definition.id = "test_self_break_field"
	field_definition.display_name = "Self Break Field"
	field_definition.on_break_effect_ids = PackedStringArray([break_effect.id])
	content_index.register_resource(field_definition)

	var apply_payload = ApplyFieldPayloadScript.new()
	apply_payload.payload_type = "apply_field"
	apply_payload.field_definition_id = field_definition.id
	var apply_effect = EffectDefinitionScript.new()
	apply_effect.id = "test_self_break_field_apply"
	apply_effect.display_name = "Apply Self Break Field"
	apply_effect.scope = "field"
	apply_effect.duration_mode = "turns"
	apply_effect.duration = 3
	apply_effect.decrement_on = "turn_end"
	apply_effect.trigger_names = PackedStringArray(["on_cast"])
	apply_effect.payloads.clear()
	apply_effect.payloads.append(apply_payload)
	content_index.register_resource(apply_effect)

	var skill = SkillDefinitionScript.new()
	skill.id = "test_self_break_field_call"
	skill.display_name = "Self Break Field Call"
	skill.damage_kind = "none"
	skill.power = 0
	skill.accuracy = 100
	skill.mp_cost = 0
	skill.priority = 0
	skill.targeting = "field"
	skill.effects_on_cast_ids = PackedStringArray([apply_effect.id])
	content_index.register_resource(skill)

func run_tied_domain_clash(harness, seed: int) -> Dictionary:
	var state_payload = build_gojo_vs_sukuna_state(harness, seed)
	if state_payload.has("error"):
		return state_payload
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	var gojo_unit = battle_state.get_side("P1").get_active_unit()
	var sukuna_unit = battle_state.get_side("P2").get_active_unit()
	gojo_unit.current_mp = gojo_unit.max_mp
	gojo_unit.ultimate_points = gojo_unit.ultimate_points_cap
	sukuna_unit.current_mp = sukuna_unit.max_mp
	sukuna_unit.ultimate_points = sukuna_unit.ultimate_points_cap
	sukuna_unit.base_speed = 999
	core.service("battle_logger").reset()
	run_turn(
		core,
		battle_state,
		content_index,
		build_ultimate_command(core, 1, "P1", "P1-A", "gojo_unlimited_void"),
		build_ultimate_command(core, 1, "P2", "P2-A", "sukuna_fukuma_mizushi")
	)
	var clash_event = find_field_clash_event(core.service("battle_logger").event_log)
	if clash_event == null or clash_event.effect_roll == null:
		return {"error": "平 MP 领域对拼必须写出带随机值的 clash 日志"}
	return {
		"field_id": battle_state.field_state.field_def_id if battle_state.field_state != null else null,
		"roll": clash_event.effect_roll,
		"summary": clash_event.payload_summary,
	}
