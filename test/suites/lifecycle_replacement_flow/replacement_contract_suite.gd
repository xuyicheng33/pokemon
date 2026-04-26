extends "res://test/suites/lifecycle_replacement_flow/base.gd"


func test_manual_switch_and_forced_replace_share_replacement_contract() -> void:
	var manual_payload = _run_manual_switch_replacement_trace(_harness, 310)
	if manual_payload.has("failure"):
		fail(str(manual_payload["failure"]))
		return
	var forced_payload = _run_forced_replace_replacement_trace(_harness, 311)
	if forced_payload.has("failure"):
		fail(str(forced_payload["failure"]))
		return
	var manual_sequence: Array = manual_payload.get("sequence", [])
	var forced_sequence: Array = forced_payload.get("sequence", [])
	if manual_sequence != forced_sequence:
		fail("manual_switch and forced_replace should share the same replacement lifecycle sequence")
		return
	var manual_enter_unit = manual_payload.get("entered_unit", null)
	var forced_enter_unit = forced_payload.get("entered_unit", null)
	if manual_enter_unit == null or forced_enter_unit == null:
		fail("replacement contract trace missing entered unit")
		return
	var manual_turn_index: int = int(manual_payload.get("reentry_turn_index", -1))
	var forced_turn_index: int = int(forced_payload.get("reentry_turn_index", -1))
	if manual_enter_unit.reentered_turn_index != manual_turn_index or forced_enter_unit.reentered_turn_index != forced_turn_index:
		fail("replacement contract must stamp reentered_turn_index for manual_switch and forced_replace")
		return
	if manual_enter_unit.has_acted or forced_enter_unit.has_acted:
		fail("replacement contract must reset has_acted=false for manual_switch and forced_replace")
		return
	if manual_enter_unit.action_window_passed or forced_enter_unit.action_window_passed:
		fail("replacement contract must reset action_window_passed=false for manual_switch and forced_replace")
		return
