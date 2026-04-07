extends RefCounted
class_name CombatTypeTestHelperCases

const BattleStateScript := preload("res://src/battle_core/runtime/battle_state.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const PassiveSkillDefinitionScript := preload("res://src/battle_core/content/passive_skill_definition.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

func validate_with_sample_mutation(harness, sample_factory, mutate: Callable) -> Array:
	var content_index = harness.build_loaded_content_index(sample_factory)
	mutate.call(content_index)
	return content_index.validate_snapshot()

func run_direct_damage_case(harness, core, sample_factory, skill_type_id: String, final_mod: Variant) -> Dictionary:
	var content_index = harness.build_loaded_content_index(sample_factory)
	var skill_id = "test_fire_direct_skill" if skill_type_id == "fire" else "test_neutral_direct_skill"
	var direct_skill = SkillDefinitionScript.new()
	direct_skill.id = skill_id
	direct_skill.display_name = skill_id
	direct_skill.damage_kind = "special"
	direct_skill.power = 50
	direct_skill.accuracy = 100
	direct_skill.mp_cost = 0
	direct_skill.priority = 0
	direct_skill.targeting = "enemy_active_slot"
	direct_skill.combat_type_id = skill_type_id
	content_index.register_resource(direct_skill)
	content_index.units["sample_pyron"].skill_ids[0] = direct_skill.id

	var battle_setup = harness.build_sample_setup(sample_factory)
	battle_setup.sides[1].starting_index = 2
	var battle_state = build_initialized_battle(core, content_index, battle_setup, 501)

	if final_mod != null:
		var final_mod_payload = RuleModPayloadScript.new()
		final_mod_payload.payload_type = "rule_mod"
		final_mod_payload.mod_kind = "final_mod"
		final_mod_payload.mod_op = "mul"
		final_mod_payload.value = final_mod
		final_mod_payload.scope = "self"
		final_mod_payload.duration_mode = "turns"
		final_mod_payload.duration = 1
		final_mod_payload.decrement_on = "turn_end"
		final_mod_payload.stacking = "replace"
		final_mod_payload.priority = 10
		var p1_active = battle_state.get_side("P1").get_active_unit()
		if core.service("rule_mod_service").create_instance(final_mod_payload, {"scope": "unit", "id": p1_active.unit_instance_id}, battle_state, "test_direct_damage_mod", 0, p1_active.base_speed) == null:
			return {"error": "failed to create direct damage rule_mod"}

	var commands: Array = [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": direct_skill.id,
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-C",
			"skill_id": "sample_strike",
		}),
	]

	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, commands)
	var damage_event = find_actor_damage_event(core.service("battle_logger").event_log, "P1-A")
	if damage_event == null or damage_event.value_changes.is_empty():
		return {"error": "missing direct damage event"}
	return {
		"damage": abs(int(damage_event.value_changes[0].delta)),
		"type_effectiveness": damage_event.type_effectiveness,
	}

func run_formula_skill_case(harness, core, sample_factory) -> Dictionary:
	var content_index = harness.build_loaded_content_index(sample_factory)

	var payload = DamagePayloadScript.new()
	payload.payload_type = "damage"
	payload.amount = 30
	payload.use_formula = true
	payload.damage_kind = "special"

	var effect = EffectDefinitionScript.new()
	effect.id = "test_formula_fire_effect"
	effect.display_name = "Formula Fire Effect"
	effect.scope = "target"
	effect.trigger_names = PackedStringArray(["on_cast"])
	effect.duration_mode = "permanent"
	effect.payloads.clear()
	effect.payloads.append(payload)
	content_index.register_resource(effect)

	var skill = SkillDefinitionScript.new()
	skill.id = "test_formula_fire_skill"
	skill.display_name = "Formula Fire Skill"
	skill.damage_kind = "none"
	skill.power = 0
	skill.accuracy = 100
	skill.mp_cost = 0
	skill.priority = 0
	skill.targeting = "enemy_active_slot"
	skill.combat_type_id = "fire"
	skill.effects_on_cast_ids = PackedStringArray([effect.id])
	content_index.register_resource(skill)
	content_index.units["sample_pyron"].skill_ids[0] = skill.id

	var harmless_skill = SkillDefinitionScript.new()
	harmless_skill.id = "test_harmless_wait"
	harmless_skill.display_name = "Harmless Wait"
	harmless_skill.damage_kind = "none"
	harmless_skill.power = 0
	harmless_skill.accuracy = 100
	harmless_skill.mp_cost = 0
	harmless_skill.priority = 0
	harmless_skill.targeting = "self"
	content_index.register_resource(harmless_skill)
	content_index.units["sample_mossaur"].skill_ids[0] = harmless_skill.id

	var battle_setup = harness.build_sample_setup(sample_factory)
	battle_setup.sides[1].starting_index = 2
	var battle_state = build_initialized_battle(core, content_index, battle_setup, 551)
	var commands: Array = [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": skill.id,
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-C",
			"skill_id": harmless_skill.id,
		}),
	]
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, commands)
	var effect_damage_event = find_effect_damage_event(core.service("battle_logger").event_log)
	if effect_damage_event == null:
		return {"error": "missing formula damage event"}
	return {"type_effectiveness": effect_damage_event.type_effectiveness}

func run_non_skill_formula_case(harness, core, sample_factory) -> Dictionary:
	var content_index = harness.build_loaded_content_index(sample_factory)

	var payload = DamagePayloadScript.new()
	payload.payload_type = "damage"
	payload.amount = 20
	payload.use_formula = true
	payload.damage_kind = "special"

	var effect = EffectDefinitionScript.new()
	effect.id = "test_enter_formula_damage_effect"
	effect.display_name = "Enter Formula Damage Effect"
	effect.scope = "self"
	effect.trigger_names = PackedStringArray(["on_enter"])
	effect.duration_mode = "permanent"
	effect.payloads.clear()
	effect.payloads.append(payload)
	content_index.register_resource(effect)

	var passive = PassiveSkillDefinitionScript.new()
	passive.id = "test_enter_formula_damage_passive"
	passive.display_name = "Enter Formula Damage Passive"
	passive.trigger_names = PackedStringArray(["on_enter"])
	passive.effect_ids = PackedStringArray([effect.id])
	content_index.register_resource(passive)
	content_index.units["sample_pyron"].passive_skill_id = passive.id

	var battle_setup = harness.build_sample_setup(sample_factory)
	var battle_state = build_initialized_battle(core, content_index, battle_setup, 601)
	var effect_damage_event = find_effect_damage_event(core.service("battle_logger").event_log)
	if effect_damage_event == null:
		return {"error": "missing non-skill formula damage event"}
	if battle_state.battle_result != null and battle_state.battle_result.finished:
		return {"error": "non-skill formula damage should not invalidate initialization"}
	return {"type_effectiveness": effect_damage_event.type_effectiveness}

func build_initialized_battle(core, content_index, battle_setup, seed: int):
	core.service("rng_service").reset(seed)
	core.service("id_factory").reset()
	var battle_state = BattleStateScript.new()
	battle_state.battle_id = core.service("id_factory").next_id("battle")
	battle_state.seed = seed
	battle_state.rng_stream_index = core.service("rng_service").get_stream_index()
	core.service("battle_initializer").initialize_battle(battle_state, content_index, battle_setup)
	return battle_state

func find_actor_damage_event(event_log: Array, actor_public_id: String):
	for ev in event_log:
		if ev.event_type == EventTypesScript.EFFECT_DAMAGE and String(ev.payload_summary).begins_with("%s dealt " % actor_public_id):
			return ev
	return null

func find_effect_damage_event(event_log: Array):
	for ev in event_log:
		if ev.event_type == EventTypesScript.EFFECT_DAMAGE and String(ev.payload_summary).find("dealt") == -1 and String(ev.payload_summary).find("recoil") == -1:
			return ev
	return null

func errors_contain(errors: Array, expected_fragment: String) -> bool:
	for error_msg in errors:
		if String(error_msg).find(expected_fragment) != -1:
			return true
	return false
