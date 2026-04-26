extends "res://tests/support/gdunit_suite_bridge.gd"

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const PowerBonusResolverScript := preload("res://src/battle_core/actions/power_bonus_resolver.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const SukunaSetupRegenTestSupportScript := preload("res://tests/support/sukuna_setup_regen_test_support.gd")

var _support = SukunaSetupRegenTestSupportScript.new()

class FlatBonusPowerBonusResolver:
	extends PowerBonusResolverScript

	func resolve_power_bonus(skill_definition, _actor, _target, _actor_mp_after_cost: int, _target_mp_before_cast: int) -> int:
		if skill_definition == null:
			return 0
		if String(skill_definition.power_bonus_source) == "test_flat_bonus":
			return 11
		return 0


func test_sukuna_reverse_ritual_heal_path() -> void:
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
	var ritual_loadout := PackedStringArray(["sukuna_kai", "sukuna_hatsu", "sukuna_reverse_ritual"])
	var battle_state = _support.build_battle_state(core, content_index, _support.build_sukuna_setup(sample_factory, {0: ritual_loadout}), 702)
	var sukuna_unit = battle_state.get_side("P1").get_active_unit()
	if sukuna_unit == null:
		fail("missing sukuna active unit")
		return
	if sukuna_unit.regular_skill_ids != ritual_loadout:
		fail("sukuna runtime loadout should mirror setup override")
		return
	var legal_action_set = core.service("legal_action_service").get_legal_actions(battle_state, "P1", content_index)
	if not legal_action_set.legal_skill_ids.has("sukuna_reverse_ritual"):
		fail("setup override should expose 反转术式 as legal action")
		return
	if legal_action_set.legal_skill_ids.has("sukuna_hiraku"):
		fail("setup override should remove 开 from this battle loadout")
		return
	sukuna_unit.current_hp = max(1, int(floor(float(sukuna_unit.max_hp) * 0.5)))
	var before_hp: int = sukuna_unit.current_hp
	var expected_gain: int = min(sukuna_unit.max_hp - before_hp, max(1, int(floor(float(sukuna_unit.max_hp) * 0.25))))
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": "sukuna_reverse_ritual",
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
		}),
	])
	if sukuna_unit.current_hp - before_hp != expected_gain:
		fail("reverse ritual heal delta mismatch")
		return
	for log_event in core.service("battle_logger").event_log:
		if log_event.event_type == EventTypesScript.EFFECT_HEAL and String(log_event.payload_summary).find("heal") != -1:
			return
	fail("reverse ritual heal log missing")

func test_sukuna_kai_priority_damage_contract() -> void:
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
	var battle_state = _support.build_battle_state(core, content_index, _support.build_sukuna_setup(sample_factory), 707)
	var sukuna_unit = battle_state.get_side("P1").get_active_unit()
	var target_unit = battle_state.get_side("P2").get_active_unit()
	if sukuna_unit == null or target_unit == null:
		fail("missing active units for sukuna kai contract")
		return
	target_unit.base_speed = 999
	var skill_definition = content_index.skills["sukuna_kai"]
	var expected_damage = _support.calc_expected_damage(core, battle_state, sukuna_unit, target_unit, skill_definition, sukuna_unit.current_mp - skill_definition.mp_cost, target_unit.current_mp)
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_skill_command(core, 1, "P1", "P1-A", "sukuna_kai"),
		_support.build_manual_skill_command(core, 1, "P2", "P2-A", "sample_strike"),
	])
	var first_cast_actor_id := ""
	for log_event in core.service("battle_logger").event_log:
		if log_event.event_type == EventTypesScript.ACTION_CAST:
			first_cast_actor_id = String(log_event.actor_id)
			break
	if first_cast_actor_id != sukuna_unit.unit_instance_id:
		fail("解应凭 priority=1 在更慢时仍先于普通技能行动")
		return
	if target_unit.max_hp - target_unit.current_hp != expected_damage:
		fail("解的基础伤害口径漂移：expected=%d actual=%d" % [expected_damage, target_unit.max_hp - target_unit.current_hp])
		return

func test_sukuna_hatsu_mp_diff_contract() -> void:
	var low_result = _support.run_sukuna_hatsu_damage_case(_harness, 708, 40, 40)
	if low_result.has("error"):
		fail(str(low_result["error"]))
		return
	if int(low_result["damage"]) != int(low_result["expected_damage"]):
		fail("低 mp 差的 捌 伤害口径漂移：expected=%d actual=%d" % [int(low_result["expected_damage"]), int(low_result["damage"])])
		return
	if int(low_result["power_bonus"]) != 0:
		fail("低 mp 差场景下，捌不应获得额外 power bonus")
		return
	var high_result = _support.run_sukuna_hatsu_damage_case(_harness, 709, 90, 20)
	if high_result.has("error"):
		fail(str(high_result["error"]))
		return
	if int(high_result["damage"]) != int(high_result["expected_damage"]):
		fail("高 mp 差的 捌 伤害口径漂移：expected=%d actual=%d" % [int(high_result["expected_damage"]), int(high_result["damage"])])
		return
	if int(high_result["power_bonus"]) <= 0:
		fail("高 mp 差场景下，捌应获得正的 power bonus")
		return
	if int(high_result["damage"]) <= int(low_result["damage"]):
		fail("更高的 mp 差应让 捌 造成更高伤害")
		return

func test_power_bonus_resolver_delegation_contract() -> void:
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
	var battle_state = _support.build_battle_state(core, content_index, _support.build_sukuna_setup(sample_factory), 710)
	var sukuna_unit = battle_state.get_side("P1").get_active_unit()
	var target_unit = battle_state.get_side("P2").get_active_unit()
	if sukuna_unit == null or target_unit == null:
		fail("missing active units for power bonus resolver delegation contract")
		return
	var fake_resolver = FlatBonusPowerBonusResolver.new()
	core.service("action_cast_segment_service").power_bonus_resolver = fake_resolver
	var skill_definition = content_index.skills["sukuna_hatsu"]
	skill_definition.power_bonus_source = "test_flat_bonus"
	var expected_damage = _support.calc_expected_damage(
		core,
		battle_state,
		sukuna_unit,
		target_unit,
		skill_definition,
		sukuna_unit.current_mp - skill_definition.mp_cost,
		target_unit.current_mp,
		fake_resolver
	)
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_skill_command(core, 1, "P1", "P1-A", "sukuna_hatsu"),
		_support.build_manual_wait_command(core, 1, "P2", "P2-A"),
	])
	var actual_damage: int = target_unit.max_hp - target_unit.current_hp
	if actual_damage != expected_damage:
		fail("direct damage pipeline should delegate power bonus resolution: expected=%d actual=%d" % [expected_damage, actual_damage])
		return

