extends "res://tests/support/gdunit_suite_bridge.gd"

const EventTypesScript := preload("res://src/shared/event_types.gd")
const GojoTestSupportScript := preload("res://tests/support/gojo_test_support.gd")

var _support = GojoTestSupportScript.new()


func test_gojo_reverse_ritual_heal_contract() -> void:
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
	var ritual_loadout: PackedStringArray = PackedStringArray(["gojo_ao", "gojo_aka", "gojo_reverse_ritual"])
	var battle_setup = _harness.build_setup_by_matchup_id(sample_factory, "gojo_vs_sample", {"P1": {0: ritual_loadout}})
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 1216, battle_setup)
	var gojo_unit = battle_state.get_side("P1").get_active_unit()
	if gojo_unit == null:
		fail("missing gojo active unit")
		return
	gojo_unit.current_hp = max(1, int(floor(float(gojo_unit.max_hp) * 0.5)))
	var before_hp: int = gojo_unit.current_hp
	var expected_gain: int = min(gojo_unit.max_hp - before_hp, max(1, int(floor(float(gojo_unit.max_hp) * 0.25))))
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_skill_command(core, 1, "P1", "P1-A", "gojo_reverse_ritual"),
		_support.build_wait_command(core, 1, "P2", "P2-A"),
	])
	if gojo_unit.current_hp - before_hp != expected_gain:
		fail("反转术式应回复 25%% max_hp")
		return

func test_gojo_plus5_competition_contract() -> void:
	var state_payload = _support.build_gojo_battle_state(_harness, 1217, true, true)
	if state_payload.has("error"):
		fail(str(state_payload["error"]))
		return
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
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_ultimate_command(core, 1, "P1", "P1-A", "gojo_unlimited_void"),
		_support.build_ultimate_command(core, 1, "P2", "P2-A", "sukuna_fukuma_mizushi"),
	])
	if not _support.has_event(core.service("battle_logger").event_log, func(ev):
		return ev.event_type == EventTypesScript.ACTION_CAST and ev.source_instance_id.find("action_") != -1 and ev.target_instance_id == gojo_unit.unit_instance_id
	):
		fail("同优先级 +5 且对手更快时，对手应先正常行动")
		return
	if _support.has_event(core.service("battle_logger").event_log, func(ev):
		return ev.event_type == EventTypesScript.ACTION_CANCELLED_PRE_START and ev.target_instance_id == sukuna_unit.unit_instance_id
	):
		fail("同优先级 +5 且对手先动时，Gojo 不应被误写成仍能首回合锁住对方")
		return

