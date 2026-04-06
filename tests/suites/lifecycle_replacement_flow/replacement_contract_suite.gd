extends "res://tests/suites/lifecycle_replacement_flow/base.gd"

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("manual_switch_and_forced_replace_share_replacement_contract", failures, Callable(self, "_test_manual_switch_and_forced_replace_share_replacement_contract").bind(harness))

func _test_manual_switch_and_forced_replace_share_replacement_contract(harness) -> Dictionary:
    var manual_payload = _run_manual_switch_replacement_trace(harness, 310)
    if manual_payload.has("failure"):
        return harness.fail_result(str(manual_payload["failure"]))
    var forced_payload = _run_forced_replace_replacement_trace(harness, 311)
    if forced_payload.has("failure"):
        return harness.fail_result(str(forced_payload["failure"]))
    var manual_sequence: Array = manual_payload.get("sequence", [])
    var forced_sequence: Array = forced_payload.get("sequence", [])
    if manual_sequence != forced_sequence:
        return harness.fail_result("manual_switch and forced_replace should share the same replacement lifecycle sequence")
    var manual_enter_unit = manual_payload.get("entered_unit", null)
    var forced_enter_unit = forced_payload.get("entered_unit", null)
    if manual_enter_unit == null or forced_enter_unit == null:
        return harness.fail_result("replacement contract trace missing entered unit")
    var manual_turn_index: int = int(manual_payload.get("reentry_turn_index", -1))
    var forced_turn_index: int = int(forced_payload.get("reentry_turn_index", -1))
    if manual_enter_unit.reentered_turn_index != manual_turn_index or forced_enter_unit.reentered_turn_index != forced_turn_index:
        return harness.fail_result("replacement contract must stamp reentered_turn_index for manual_switch and forced_replace")
    if manual_enter_unit.has_acted or forced_enter_unit.has_acted:
        return harness.fail_result("replacement contract must reset has_acted=false for manual_switch and forced_replace")
    if manual_enter_unit.action_window_passed or forced_enter_unit.action_window_passed:
        return harness.fail_result("replacement contract must reset action_window_passed=false for manual_switch and forced_replace")
    return harness.pass_result()
