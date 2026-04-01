extends RefCounted
class_name SukunaSetupRegenTestSupport

const PowerBonusResolverScript := preload("res://src/battle_core/actions/power_bonus_resolver.gd")

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const SukunaTestSupportScript := preload("res://tests/support/sukuna_test_support.gd")

var _support = SukunaTestSupportScript.new()

func build_sukuna_setup(sample_factory, p1_regular_skill_overrides: Dictionary = {}):
	return _support.build_sukuna_setup(sample_factory, p1_regular_skill_overrides)

func build_battle_state(core, content_index, battle_setup, seed: int):
	return _support.build_battle_state(core, content_index, battle_setup, seed)

func resolve_matchup_gap_value(owner_total: int, opponent_total: int, thresholds: PackedInt32Array, outputs: PackedInt32Array, default_value: int) -> int:
	return _support.resolve_matchup_gap_value(owner_total, opponent_total, thresholds, outputs, default_value)

func sum_unit_bst(unit_state) -> int:
	return _support.sum_unit_bst(unit_state)

func build_manual_skill_command(core, turn_index: int, side_id: String, actor_public_id: String, skill_id: String):
	return _support.build_manual_skill_command(core, turn_index, side_id, actor_public_id, skill_id)

func build_manual_wait_command(core, turn_index: int, side_id: String, actor_public_id: String):
	return _support.build_manual_wait_command(core, turn_index, side_id, actor_public_id)

func run_sukuna_hatsu_damage_case(harness, seed: int, actor_mp_before_cast: int, target_mp_before_cast: int) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return {"error": str(core_payload["error"])}
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return {"error": "SampleBattleFactory init failed"}
	var content_index = harness.build_loaded_content_index(sample_factory)
	content_index.skills["sukuna_hatsu"].accuracy = 100
	var battle_state = build_battle_state(core, content_index, build_sukuna_setup(sample_factory), seed)
	var sukuna_unit = battle_state.get_side("P1").get_active_unit()
	var target_unit = battle_state.get_side("P2").get_active_unit()
	sukuna_unit.current_mp = actor_mp_before_cast
	target_unit.current_mp = target_mp_before_cast
	var skill_definition = content_index.skills["sukuna_hatsu"]
	var actor_mp_after_cost: int = actor_mp_before_cast - skill_definition.mp_cost
	var power_bonus: int = max(0, actor_mp_after_cost - target_mp_before_cast)
	var expected_damage = calc_expected_damage(core, battle_state, sukuna_unit, target_unit, skill_definition, actor_mp_after_cost, target_mp_before_cast)
	core.turn_loop_controller.run_turn(battle_state, content_index, [
		build_manual_skill_command(core, 1, "P1", "P1-A", "sukuna_hatsu"),
		build_manual_wait_command(core, 1, "P2", "P2-A"),
	])
	return {
		"damage": target_unit.max_hp - target_unit.current_hp,
		"expected_damage": expected_damage,
		"power_bonus": power_bonus,
	}

func calc_expected_damage(core, battle_state, actor, target, skill_definition, actor_mp_after_cost: int, target_mp_before_cast: int) -> int:
	var resolver = core.power_bonus_resolver if core != null and core.power_bonus_resolver != null else PowerBonusResolverScript.new()
	var power_bonus := int(resolver.resolve_power_bonus(
		skill_definition,
		actor,
		target,
		actor_mp_after_cost,
		target_mp_before_cast
	))
	var power: int = int(skill_definition.power) + power_bonus
	var attack_value: int = core.stat_calculator.calc_effective_stat(actor.base_sp_attack, int(actor.stat_stages.get("sp_attack", 0))) if String(skill_definition.damage_kind) == "special" else core.stat_calculator.calc_effective_stat(actor.base_attack, int(actor.stat_stages.get("attack", 0)))
	var defense_value: int = core.stat_calculator.calc_effective_stat(target.base_sp_defense, int(target.stat_stages.get("sp_defense", 0))) if String(skill_definition.damage_kind) == "special" else core.stat_calculator.calc_effective_stat(target.base_defense, int(target.stat_stages.get("defense", 0)))
	var type_effectiveness: float = core.combat_type_service.calc_effectiveness(String(skill_definition.combat_type_id), target.combat_type_ids)
	var final_multiplier: float = core.rule_mod_service.get_final_multiplier(battle_state, actor.unit_instance_id)
	return core.damage_service.apply_final_mod(
		core.damage_service.calc_base_damage(
			battle_state.battle_level,
			power,
			attack_value,
			defense_value
		),
		final_multiplier * type_effectiveness
	)

func simulate_until_ultimate_window(core, content_index, battle_state, command_factory: Callable) -> int:
	for turn_index in range(1, 10):
		var legal_action_set = core.legal_action_service.get_legal_actions(battle_state, "P1", content_index)
		if legal_action_set.legal_ultimate_ids.has("sukuna_fukuma_mizushi"):
			return turn_index
		core.turn_loop_controller.run_turn(battle_state, content_index, [
			command_factory.call(turn_index),
			build_manual_wait_command(core, turn_index, "P2", "P2-A"),
		])
		if battle_state.battle_result.finished:
			return -1
	return -1
