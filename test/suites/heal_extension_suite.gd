extends "res://tests/support/gdunit_suite_bridge.gd"

const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const HealPayloadScript := preload("res://src/battle_core/content/heal_payload.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")


func test_missing_hp_percent_heal_runtime_contract() -> void:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var content_index = _harness.build_loaded_content_index(sample_factory)

	var heal_effect = _build_heal_effect("test_missing_hp_heal_effect", 10, "missing_hp")
	content_index.register_resource(heal_effect)
	var heal_skill = _build_heal_skill("test_missing_hp_heal_skill", heal_effect.id)
	content_index.register_resource(heal_skill)
	content_index.units["sample_pyron"].skill_ids[0] = heal_skill.id

	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 820)
	var actor = battle_state.get_side("P1").get_active_unit()
	var target = battle_state.get_side("P2").get_active_unit()
	if actor == null or target == null:
		fail("missing active units for missing_hp heal contract")
		return
	actor.current_hp = max(1, int(floor(float(actor.max_hp) * 0.5)))
	var before_hp: int = int(actor.current_hp)
	var missing_hp: int = int(actor.max_hp) - before_hp
	var expected_gain: int = max(1, int(floor(float(missing_hp) * 0.1)))

	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": actor.public_id,
			"skill_id": heal_skill.id,
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": target.public_id,
		}),
	])

	if int(actor.current_hp) - before_hp != expected_gain:
		fail("missing_hp percent heal mismatch: expected=%d actual=%d" % [expected_gain, int(actor.current_hp) - before_hp])
		return
	if not _has_public_heal_event(core.service("battle_logger").event_log, actor.public_id):
		fail("missing_hp heal should write effect:heal event")
		return

func test_incoming_heal_final_mod_blocks_heal_contract() -> void:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var content_index = _harness.build_loaded_content_index(sample_factory)

	var heal_effect = _build_fixed_heal_effect("test_blocked_heal_effect", 20)
	content_index.register_resource(heal_effect)
	var heal_skill = _build_heal_skill("test_blocked_heal_skill", heal_effect.id)
	content_index.register_resource(heal_skill)
	content_index.units["sample_pyron"].skill_ids[0] = heal_skill.id

	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 821)
	var actor = battle_state.get_side("P1").get_active_unit()
	var target = battle_state.get_side("P2").get_active_unit()
	if actor == null or target == null:
		fail("missing active units for incoming_heal_final_mod contract")
		return
	actor.current_hp = max(1, int(floor(float(actor.max_hp) * 0.5)))
	var before_hp: int = int(actor.current_hp)

	var incoming_heal_payload = RuleModPayloadScript.new()
	incoming_heal_payload.payload_type = "rule_mod"
	incoming_heal_payload.mod_kind = "incoming_heal_final_mod"
	incoming_heal_payload.mod_op = "set"
	incoming_heal_payload.value = 0.0
	incoming_heal_payload.scope = "self"
	incoming_heal_payload.duration_mode = "turns"
	incoming_heal_payload.duration = 1
	incoming_heal_payload.decrement_on = "turn_end"
	incoming_heal_payload.stacking = "replace"
	incoming_heal_payload.priority = 10
	if core.service("rule_mod_service").create_instance(
		incoming_heal_payload,
		{"scope": "unit", "id": actor.unit_instance_id},
		battle_state,
		"test_block_heal",
		0,
		actor.base_speed
	) == null:
		fail("failed to create incoming_heal_final_mod rule_mod")
		return

	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": actor.public_id,
			"skill_id": heal_skill.id,
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": target.public_id,
		}),
	])

	if int(actor.current_hp) != before_hp:
		fail("incoming_heal_final_mod=set0 should fully block heal")
		return
	if _has_public_heal_event(core.service("battle_logger").event_log, actor.public_id):
		fail("blocked heal should not write effect:heal event")
		return

func test_heal_extension_validation_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var content_index = _harness.build_loaded_content_index(sample_factory)

	var bad_percent_heal_payload = HealPayloadScript.new()
	bad_percent_heal_payload.payload_type = "heal"
	bad_percent_heal_payload.use_percent = true
	bad_percent_heal_payload.percent = 10
	bad_percent_heal_payload.percent_base = "bad_base"
	var bad_percent_heal_effect = EffectDefinitionScript.new()
	bad_percent_heal_effect.id = "test_bad_percent_heal_base"
	bad_percent_heal_effect.display_name = "Bad Percent Heal Base"
	bad_percent_heal_effect.scope = "self"
	bad_percent_heal_effect.trigger_names = PackedStringArray(["on_cast"])
	bad_percent_heal_effect.payloads.append(bad_percent_heal_payload)
	content_index.register_resource(bad_percent_heal_effect)

	var bad_incoming_heal_payload = RuleModPayloadScript.new()
	bad_incoming_heal_payload.payload_type = "rule_mod"
	bad_incoming_heal_payload.mod_kind = "incoming_heal_final_mod"
	bad_incoming_heal_payload.mod_op = "set"
	bad_incoming_heal_payload.value = true
	bad_incoming_heal_payload.scope = "self"
	bad_incoming_heal_payload.duration_mode = "turns"
	bad_incoming_heal_payload.duration = 1
	bad_incoming_heal_payload.decrement_on = "turn_end"
	bad_incoming_heal_payload.stacking = "replace"
	var bad_incoming_heal_effect = EffectDefinitionScript.new()
	bad_incoming_heal_effect.id = "test_bad_incoming_heal_final_mod"
	bad_incoming_heal_effect.display_name = "Bad Incoming Heal Final Mod"
	bad_incoming_heal_effect.scope = "self"
	bad_incoming_heal_effect.payloads.append(bad_incoming_heal_payload)
	content_index.register_resource(bad_incoming_heal_effect)

	var errors: Array = content_index.validate_snapshot()
	if not _has_error(errors, "effect[test_bad_percent_heal_base].heal invalid percent_base: bad_base"):
		fail("heal extension validation should reject invalid percent_base")
		return
	if not _has_error(errors, "effect[test_bad_incoming_heal_final_mod].rule_mod invalid: incoming_heal_final_mod value must be number"):
		fail("heal extension validation should reject non-number incoming_heal_final_mod")
		return


func _build_heal_effect(effect_id: String, percent: int, percent_base: String):
	var effect = EffectDefinitionScript.new()
	effect.id = effect_id
	effect.display_name = effect_id
	effect.scope = "self"
	effect.duration_mode = "permanent"
	effect.trigger_names = PackedStringArray(["on_cast"])
	var payload = HealPayloadScript.new()
	payload.payload_type = "heal"
	payload.use_percent = true
	payload.percent = percent
	payload.percent_base = percent_base
	effect.payloads.append(payload)
	return effect

func _build_fixed_heal_effect(effect_id: String, amount: int):
	var effect = EffectDefinitionScript.new()
	effect.id = effect_id
	effect.display_name = effect_id
	effect.scope = "self"
	effect.duration_mode = "permanent"
	effect.trigger_names = PackedStringArray(["on_cast"])
	var payload = HealPayloadScript.new()
	payload.payload_type = "heal"
	payload.amount = amount
	effect.payloads.append(payload)
	return effect

func _build_heal_skill(skill_id: String, effect_id: String):
	var skill = SkillDefinitionScript.new()
	skill.id = skill_id
	skill.display_name = skill_id
	skill.damage_kind = "none"
	skill.accuracy = 100
	skill.mp_cost = 0
	skill.priority = 0
	skill.targeting = "self"
	skill.effects_on_cast_ids = PackedStringArray([effect_id])
	return skill

func _has_public_heal_event(event_log: Array, public_id: String) -> bool:
	for log_event in event_log:
		if log_event.event_type != EventTypesScript.EFFECT_HEAL:
			continue
		if String(log_event.payload_summary).find(public_id) == -1:
			continue
		return true
	return false

func _has_error(errors: Array, expected_error: String) -> bool:
	for error_message in errors:
		if String(error_message) == expected_error:
			return true
	return false
