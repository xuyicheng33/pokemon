extends "res://tests/support/gdunit_suite_bridge.gd"

const KashimoTestSupportScript := preload("res://tests/support/kashimo_test_support.gd")

var _support = KashimoTestSupportScript.new()


func test_kashimo_phantom_beast_amber_persistent_stage_contract() -> void:
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
	var battle_state = _support.build_battle_state(core, content_index, _support.build_kashimo_setup(sample_factory), 910)
	var kashimo = battle_state.get_side("P1").get_active_unit()
	if kashimo == null:
		fail("missing kashimo active unit for amber contract")
		return
	kashimo.current_mp = kashimo.max_mp
	kashimo.ultimate_points = kashimo.ultimate_points_cap

	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_ultimate_command(core, 1, "P1", "P1-A", "kashimo_phantom_beast_amber"),
		_support.build_manual_wait_command(core, 1, "P2", _active_public_id(battle_state, "P2")),
	])
	if int(kashimo.persistent_stat_stages.get("attack", 0)) != 2 or int(kashimo.persistent_stat_stages.get("sp_attack", 0)) != 2 or int(kashimo.persistent_stat_stages.get("speed", 0)) != 1:
		fail("amber should apply persistent +2/+2/+1 stat stages")
		return
	if kashimo.current_hp != 98:
		fail("amber should deal 20 self damage at turn_end after cast: expected=98 actual=%d" % kashimo.current_hp)
		return
	if not _has_effect_instance(kashimo, "kashimo_amber_bleed"):
		fail("amber should apply persistent bleed effect")
		return
	if not _has_rule_mod(kashimo, "action_legality", "ultimate"):
		fail("amber should apply persistent ultimate lock rule_mod")
		return
	if kashimo.ultimate_points != 0:
		fail("amber cast should clear ultimate points")
		return

	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_switch_command(core, 2, "P1", "P1-A", "P1-B"),
		_support.build_manual_wait_command(core, 2, "P2", _active_public_id(battle_state, "P2")),
	])
	if int(kashimo.persistent_stat_stages.get("attack", 0)) != 2:
		fail("persistent attack stage should survive switch after amber")
		return
	if not _has_effect_instance(kashimo, "kashimo_amber_bleed") or not _has_rule_mod(kashimo, "action_legality", "ultimate"):
		fail("amber bleed and ultimate lock should survive switch")
		return
	if kashimo.current_hp != 98:
		fail("amber self damage should not disappear statefully while benched: expected hp=98 actual=%d" % kashimo.current_hp)
		return

	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_switch_command(core, 3, "P1", "P1-B", "P1-A"),
		_support.build_manual_wait_command(core, 3, "P2", _active_public_id(battle_state, "P2")),
	])
	if kashimo.current_hp != 98:
		fail("amber self damage should stay paused on the same turn the user re-enters: expected=98 actual=%d" % kashimo.current_hp)
		return
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_wait_command(core, 4, "P1", "P1-A"),
		_support.build_manual_wait_command(core, 4, "P2", _active_public_id(battle_state, "P2")),
	])
	if kashimo.current_hp != 78:
		fail("amber self damage should resume on the next full active turn after re-entry: expected=78 actual=%d" % kashimo.current_hp)
		return
	kashimo.ultimate_points = kashimo.ultimate_points_cap
	var legal_actions = core.service("legal_action_service").get_legal_actions(battle_state, "P1", content_index)
	if legal_actions.legal_ultimate_ids.has("kashimo_phantom_beast_amber"):
		fail("amber ultimate lock should deny second ultimate even after refilling points")
		return

	core.service("leave_service").leave_unit(battle_state, kashimo, "faint", content_index)
	if int(kashimo.persistent_stat_stages.get("attack", 0)) != 0 or int(kashimo.persistent_stat_stages.get("sp_attack", 0)) != 0 or int(kashimo.persistent_stat_stages.get("speed", 0)) != 0:
		fail("persistent stat stages should clear on faint")
		return
	if _has_effect_instance(kashimo, "kashimo_amber_bleed") or _has_rule_mod(kashimo, "action_legality", "ultimate"):
		fail("amber bleed and ultimate lock should clear on faint")
		return

func test_kashimo_phantom_beast_amber_once_per_battle_contract() -> void:
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
	var battle_state = _support.build_battle_state(core, content_index, _support.build_kashimo_setup(sample_factory), 911)
	var kashimo = battle_state.get_side("P1").get_active_unit()
	if kashimo == null:
		fail("missing kashimo active unit for amber once_per_battle contract")
		return
	kashimo.current_mp = kashimo.max_mp
	kashimo.ultimate_points = kashimo.ultimate_points_cap

	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_ultimate_command(core, 1, "P1", "P1-A", "kashimo_phantom_beast_amber"),
		_support.build_manual_wait_command(core, 1, "P2", _active_public_id(battle_state, "P2")),
	])
	if not kashimo.has_used_once_per_battle_skill("kashimo_phantom_beast_amber"):
		fail("amber cast should write the once_per_battle runtime usage record")
		return
	_clear_runtime_amber_markers(kashimo)
	kashimo.current_mp = kashimo.max_mp
	kashimo.ultimate_points = kashimo.ultimate_points_cap
	var legal_actions = core.service("legal_action_service").get_legal_actions(battle_state, "P1", content_index)
	if legal_actions.legal_ultimate_ids.has("kashimo_phantom_beast_amber"):
		fail("amber should stay illegal after battle-scoped consumption even without runtime lock markers")
		return


func _has_effect_instance(unit_state, effect_id: String) -> bool:
	for effect_instance in unit_state.effect_instances:
		if String(effect_instance.def_id) == effect_id:
			return true
	return false

func _has_rule_mod(unit_state, mod_kind: String, value: String) -> bool:
	for rule_mod_instance in unit_state.rule_mod_instances:
		if String(rule_mod_instance.mod_kind) == mod_kind and String(rule_mod_instance.value) == value:
			return true
	return false

func _active_public_id(battle_state, side_id: String) -> String:
	var side = battle_state.get_side(side_id)
	if side == null:
		return ""
	var active = side.get_active_unit()
	if active == null:
		return ""
	return String(active.public_id)

func _clear_runtime_amber_markers(unit_state) -> void:
	var kept_effects: Array = []
	for effect_instance in unit_state.effect_instances:
		if String(effect_instance.def_id) == "kashimo_amber_bleed":
			continue
		kept_effects.append(effect_instance)
	unit_state.effect_instances = kept_effects
	var kept_rule_mods: Array = []
	for rule_mod_instance in unit_state.rule_mod_instances:
		if String(rule_mod_instance.mod_kind) == "action_legality" and String(rule_mod_instance.value) == "ultimate":
			continue
		kept_rule_mods.append(rule_mod_instance)
	unit_state.rule_mod_instances = kept_rule_mods
