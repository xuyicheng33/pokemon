extends "res://tests/support/gdunit_suite_bridge.gd"

const BattleContentIndexScript := preload("res://src/battle_core/content/battle_content_index.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const RemoveEffectPayloadScript := preload("res://src/battle_core/content/remove_effect_payload.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const PowerBonusResolverScript := preload("res://src/battle_core/actions/power_bonus_resolver.gd")
const PowerBonusSourceRegistryScript := preload("res://src/battle_core/content/power_bonus_source_registry.gd")


func test_power_bonus_registered_source_coverage_contract() -> void:
	var unresolved_sources := PowerBonusResolverScript.unresolved_registered_sources()
	if not unresolved_sources.is_empty():
		fail(
			"PowerBonusResolver missing registered source coverage: %s" % ", ".join(unresolved_sources)
		)
		return
	var unresolved_validator_sources := PowerBonusSourceRegistryScript.unresolved_validator_sources()
	if not unresolved_validator_sources.is_empty():
		fail(
			"PowerBonusSourceRegistry missing validator coverage: %s" % ", ".join(unresolved_validator_sources)
		)
		return

func test_power_bonus_contract_validator_dispatch_contract() -> void:
	var content_index = BattleContentIndexScript.new()
	var bad_skill = SkillDefinitionScript.new()
	bad_skill.id = "power_bonus_dispatch_bad_skill"
	bad_skill.display_name = "Power Bonus Dispatch Bad Skill"
	bad_skill.power_bonus_source = PowerBonusSourceRegistryScript.EFFECT_STACK_SUM
	bad_skill.power_bonus_self_effect_ids = PackedStringArray(["missing_effect"])
	bad_skill.power_bonus_per_stack = 0
	var errors: Array = []
	PowerBonusSourceRegistryScript.validate_skill_contract(errors, bad_skill.id, bad_skill, content_index)
	var has_missing_effect_error := false
	var has_per_stack_error := false
	for error_msg in errors:
		var msg := str(error_msg)
		has_missing_effect_error = has_missing_effect_error or msg.find("power_bonus_self_effect_ids missing effect") != -1
		has_per_stack_error = has_per_stack_error or msg.find("power_bonus_per_stack must be > 0") != -1
	if not (has_missing_effect_error and has_per_stack_error):
		fail("PowerBonusSourceRegistry validator dispatch drifted")
		return

func test_effect_stack_sum_and_remove_all_runtime_contract() -> void:
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

	var self_mark = EffectDefinitionScript.new()
	self_mark.id = "test_effect_stack_sum_self_mark"
	self_mark.display_name = "Effect Stack Sum Self Mark"
	self_mark.scope = "self"
	self_mark.duration_mode = "permanent"
	self_mark.stacking = "stack"
	self_mark.max_stacks = 8
	content_index.register_resource(self_mark)

	var target_mark = EffectDefinitionScript.new()
	target_mark.id = "test_effect_stack_sum_target_mark"
	target_mark.display_name = "Effect Stack Sum Target Mark"
	target_mark.scope = "target"
	target_mark.duration_mode = "permanent"
	target_mark.stacking = "stack"
	target_mark.max_stacks = 8
	content_index.register_resource(target_mark)

	var clear_self_payload = RemoveEffectPayloadScript.new()
	clear_self_payload.payload_type = "remove_effect"
	clear_self_payload.effect_definition_id = self_mark.id
	clear_self_payload.remove_mode = "all"
	var clear_self_effect = EffectDefinitionScript.new()
	clear_self_effect.id = "test_effect_stack_sum_clear_self"
	clear_self_effect.display_name = "Effect Stack Sum Clear Self"
	clear_self_effect.scope = "self"
	clear_self_effect.trigger_names = PackedStringArray(["on_hit"])
	clear_self_effect.duration_mode = "permanent"
	clear_self_effect.payloads.append(clear_self_payload)
	content_index.register_resource(clear_self_effect)

	var clear_target_payload = RemoveEffectPayloadScript.new()
	clear_target_payload.payload_type = "remove_effect"
	clear_target_payload.effect_definition_id = target_mark.id
	clear_target_payload.remove_mode = "all"
	var clear_target_effect = EffectDefinitionScript.new()
	clear_target_effect.id = "test_effect_stack_sum_clear_target"
	clear_target_effect.display_name = "Effect Stack Sum Clear Target"
	clear_target_effect.scope = "target"
	clear_target_effect.trigger_names = PackedStringArray(["on_hit"])
	clear_target_effect.duration_mode = "permanent"
	clear_target_effect.payloads.append(clear_target_payload)
	content_index.register_resource(clear_target_effect)

	var skill = SkillDefinitionScript.new()
	skill.id = "test_effect_stack_sum_skill"
	skill.display_name = "Effect Stack Sum Skill"
	skill.damage_kind = "special"
	skill.power = 30
	skill.accuracy = 100
	skill.mp_cost = 0
	skill.priority = 0
	skill.targeting = "enemy_active_slot"
	skill.power_bonus_source = "effect_stack_sum"
	skill.power_bonus_self_effect_ids = PackedStringArray([self_mark.id])
	skill.power_bonus_target_effect_ids = PackedStringArray([target_mark.id])
	skill.power_bonus_per_stack = 12
	skill.effects_on_hit_ids = PackedStringArray([clear_self_effect.id, clear_target_effect.id])
	content_index.register_resource(skill)
	content_index.units["sample_pyron"].skill_ids[0] = skill.id

	var harmless_skill = SkillDefinitionScript.new()
	harmless_skill.id = "test_effect_stack_sum_harmless"
	harmless_skill.display_name = "Effect Stack Sum Harmless"
	harmless_skill.damage_kind = "none"
	harmless_skill.accuracy = 100
	harmless_skill.mp_cost = 0
	harmless_skill.priority = 0
	harmless_skill.targeting = "self"
	content_index.register_resource(harmless_skill)
	content_index.units["sample_tidekit"].skill_ids[0] = harmless_skill.id

	var battle_setup = _harness.build_sample_setup(sample_factory)
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 710, battle_setup)
	var actor = battle_state.get_side("P1").get_active_unit()
	var target = battle_state.get_side("P2").get_active_unit()
	if actor == null or target == null:
		fail("missing active units for effect_stack_sum runtime contract")
		return

	for _i in range(2):
		if core.service("effect_instance_service").create_instance(self_mark, actor.unit_instance_id, battle_state, "test_self_mark", 0, actor.base_speed) == null:
			fail("failed to create self mark instance")
			return
	for _i in range(3):
		if core.service("effect_instance_service").create_instance(target_mark, target.unit_instance_id, battle_state, "test_target_mark", 0, actor.base_speed) == null:
			fail("failed to create target mark instance")
			return

	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
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
			"actor_public_id": "P2-A",
			"skill_id": harmless_skill.id,
		}),
	])

	var expected_damage: int = core.service("damage_service").apply_final_mod(
		core.service("damage_service").calc_base_damage(
			battle_state.battle_level,
			90,
			actor.base_sp_attack,
			target.base_sp_defense
		),
		1.0
	)
	var actual_damage: int = _harness.extract_damage_from_log(core.service("battle_logger").event_log, "P1-A")
	if actual_damage != expected_damage:
		fail("effect_stack_sum damage mismatch: expected=%d actual=%d" % [expected_damage, actual_damage])
		return
	if _count_effect_instances(actor, self_mark.id) != 0:
		fail("remove_mode=all should clear all self marks on hit")
		return
	if _count_effect_instances(target, target_mark.id) != 0:
		fail("remove_mode=all should clear all target marks on hit")
		return


func _count_effect_instances(unit_state, effect_id: String) -> int:
	var count := 0
	for effect_instance in unit_state.effect_instances:
		if String(effect_instance.def_id) == effect_id:
			count += 1
	return count
