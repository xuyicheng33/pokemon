extends "res://test/support/gdunit_suite_bridge.gd"

const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")



func test_nullify_field_accuracy_runtime_contract() -> void:
	_assert_legacy_result(_test_nullify_field_accuracy_runtime_contract(_harness))

func test_incoming_action_final_mod_runtime_contract() -> void:
	_assert_legacy_result(_test_incoming_action_final_mod_runtime_contract(_harness))

func test_mp_regen_runtime_value_must_be_int_contract() -> void:
	_assert_legacy_result(_test_mp_regen_runtime_value_must_be_int_contract(_harness))
func _test_nullify_field_accuracy_runtime_contract(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)

	var guaranteed_skill = _build_direct_skill("test_field_override_zero_accuracy", 0, "")
	content_index.register_resource(guaranteed_skill)
	content_index.units["sample_pyron"].skill_ids[0] = guaranteed_skill.id

	var harmless_skill = _build_harmless_skill("test_field_override_harmless")
	content_index.register_resource(harmless_skill)
	content_index.units["sample_tidekit"].skill_ids[0] = harmless_skill.id

	var baseline_state = harness.build_initialized_battle(core, content_index, sample_factory, 731)
	var baseline_actor = baseline_state.get_side("P1").get_active_unit()
	baseline_state.field_state = _build_override_field_state("gojo_unlimited_void_field", baseline_actor.unit_instance_id)
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(baseline_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": guaranteed_skill.id,
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
			"skill_id": harmless_skill.id,
		}),
	])
	if harness.extract_damage_from_log(core.service("battle_logger").event_log, "P1-A") <= 0:
		return harness.fail_result("field override should force 0-accuracy skill to hit without nullify")

	var nullify_state = harness.build_initialized_battle(core, content_index, sample_factory, 731)
	var nullify_actor = nullify_state.get_side("P1").get_active_unit()
	var nullify_target = nullify_state.get_side("P2").get_active_unit()
	nullify_state.field_state = _build_override_field_state("gojo_unlimited_void_field", nullify_actor.unit_instance_id)
	var nullify_payload = RuleModPayloadScript.new()
	nullify_payload.payload_type = "rule_mod"
	nullify_payload.mod_kind = "nullify_field_accuracy"
	nullify_payload.mod_op = "set"
	nullify_payload.value = true
	nullify_payload.scope = "self"
	nullify_payload.duration_mode = "turns"
	nullify_payload.duration = 1
	nullify_payload.decrement_on = "turn_end"
	nullify_payload.stacking = "replace"
	nullify_payload.priority = 10
	if core.service("rule_mod_service").create_instance(nullify_payload, {"scope": "unit", "id": nullify_target.unit_instance_id}, nullify_state, "test_nullify_field_accuracy", 0, nullify_target.base_speed) == null:
		return harness.fail_result("failed to create nullify_field_accuracy rule_mod")
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(nullify_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": guaranteed_skill.id,
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
			"skill_id": harmless_skill.id,
		}),
	])
	if harness.extract_damage_from_log(core.service("battle_logger").event_log, "P1-A") != 0:
		return harness.fail_result("nullify_field_accuracy should restore original miss rate")
	return harness.pass_result()

func _test_incoming_action_final_mod_runtime_contract(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)

	var thunder_skill = _build_direct_skill("test_incoming_action_thunder", 100, "thunder")
	thunder_skill.power = 50
	content_index.register_resource(thunder_skill)
	content_index.units["sample_pyron"].skill_ids[0] = thunder_skill.id

	var harmless_skill = _build_harmless_skill("test_incoming_action_harmless")
	content_index.register_resource(harmless_skill)
	content_index.units["sample_tidekit"].skill_ids[0] = harmless_skill.id

	var baseline_state = harness.build_initialized_battle(core, content_index, sample_factory, 732)
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(baseline_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": thunder_skill.id,
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
			"skill_id": harmless_skill.id,
		}),
	])
	var baseline_damage: int = harness.extract_damage_from_log(core.service("battle_logger").event_log, "P1-A")
	if baseline_damage <= 0:
		return harness.fail_result("missing baseline thunder damage for incoming_action_final_mod contract")

	var modded_state = harness.build_initialized_battle(core, content_index, sample_factory, 732)
	var target = modded_state.get_side("P2").get_active_unit()
	var incoming_payload = RuleModPayloadScript.new()
	incoming_payload.payload_type = "rule_mod"
	incoming_payload.mod_kind = "incoming_action_final_mod"
	incoming_payload.mod_op = "mul"
	incoming_payload.value = 0.5
	incoming_payload.scope = "self"
	incoming_payload.duration_mode = "turns"
	incoming_payload.duration = 1
	incoming_payload.decrement_on = "turn_end"
	incoming_payload.stacking = "replace"
	incoming_payload.priority = 10
	incoming_payload.required_incoming_command_types = PackedStringArray(["skill"])
	incoming_payload.required_incoming_combat_type_ids = PackedStringArray(["thunder"])
	if core.service("rule_mod_service").create_instance(incoming_payload, {"scope": "unit", "id": target.unit_instance_id}, modded_state, "test_incoming_action_final_mod", 0, target.base_speed) == null:
		return harness.fail_result("failed to create incoming_action_final_mod rule_mod")
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(modded_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": thunder_skill.id,
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
			"skill_id": harmless_skill.id,
		}),
	])
	var modded_damage: int = harness.extract_damage_from_log(core.service("battle_logger").event_log, "P1-A")
	if modded_damage >= baseline_damage:
		return harness.fail_result("incoming_action_final_mod should reduce matching thunder skill damage")

	var fire_skill = _build_direct_skill("test_incoming_action_fire", 100, "fire")
	fire_skill.power = 50
	content_index.register_resource(fire_skill)
	content_index.units["sample_pyron"].skill_ids[0] = fire_skill.id

	var fire_state = harness.build_initialized_battle(core, content_index, sample_factory, 733)
	var fire_target = fire_state.get_side("P2").get_active_unit()
	if core.service("rule_mod_service").create_instance(incoming_payload, {"scope": "unit", "id": fire_target.unit_instance_id}, fire_state, "test_incoming_action_final_mod_fire", 0, fire_target.base_speed) == null:
		return harness.fail_result("failed to create incoming_action_final_mod rule_mod for fire mismatch case")
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(fire_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": fire_skill.id,
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
			"skill_id": harmless_skill.id,
		}),
	])
	var fire_damage: int = harness.extract_damage_from_log(core.service("battle_logger").event_log, "P1-A")
	if fire_damage <= 0:
		return harness.fail_result("missing fire damage for incoming_action_final_mod mismatch case")
	return harness.pass_result()

func _test_mp_regen_runtime_value_must_be_int_contract(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 734)
	var target = battle_state.get_side("P1").get_active_unit()
	if target == null:
		return harness.fail_result("missing active unit for mp_regen int contract")
	var mp_regen_payload = RuleModPayloadScript.new()
	mp_regen_payload.payload_type = "rule_mod"
	mp_regen_payload.mod_kind = "mp_regen"
	mp_regen_payload.mod_op = "add"
	mp_regen_payload.value = 0
	mp_regen_payload.scope = "self"
	mp_regen_payload.duration_mode = "turns"
	mp_regen_payload.duration = 1
	mp_regen_payload.decrement_on = "turn_start"
	mp_regen_payload.stacking = "replace"
	var created_instance = core.service("rule_mod_service").create_instance(
		mp_regen_payload,
		{"scope": "unit", "id": target.unit_instance_id},
		battle_state,
		"test_fractional_mp_regen",
		0,
		target.base_speed,
		7.5
	)
	if created_instance != null:
		return harness.fail_result("mp_regen runtime value should fail-fast on fractional value")
	var error_state: Dictionary = core.service("rule_mod_service").error_state()
	if String(error_state.get("code", "")) != "invalid_rule_mod_definition":
		return harness.fail_result("fractional mp_regen runtime value should report invalid_rule_mod_definition")
	return harness.pass_result()

func _build_direct_skill(skill_id: String, accuracy: int, combat_type_id: String):
	var skill = SkillDefinitionScript.new()
	skill.id = skill_id
	skill.display_name = skill_id
	skill.damage_kind = "special"
	skill.power = 20
	skill.accuracy = accuracy
	skill.mp_cost = 0
	skill.priority = 0
	skill.targeting = "enemy_active_slot"
	skill.combat_type_id = combat_type_id
	return skill

func _build_harmless_skill(skill_id: String):
	var skill = SkillDefinitionScript.new()
	skill.id = skill_id
	skill.display_name = skill_id
	skill.damage_kind = "none"
	skill.accuracy = 100
	skill.mp_cost = 0
	skill.priority = 0
	skill.targeting = "self"
	return skill

func _build_override_field_state(field_def_id: String, creator_id: String):
	var field_state = preload("res://src/battle_core/runtime/field_state.gd").new()
	field_state.field_def_id = field_def_id
	field_state.instance_id = "test_override_field"
	field_state.creator = creator_id
	field_state.remaining_turns = 3
	return field_state
