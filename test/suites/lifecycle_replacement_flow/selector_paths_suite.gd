extends "res://test/suites/lifecycle_replacement_flow/base.gd"



func test_replacement_selector_paths() -> void:
	_assert_legacy_result(_test_replacement_selector_paths(_harness))
func _test_replacement_selector_paths(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)

	var legal_state = harness.build_initialized_battle(core, content_index, sample_factory, 215)
	var legal_side = legal_state.get_side("P1")
	if legal_side == null or legal_side.bench_order.size() < 2:
		return harness.fail_result("expected at least 2 legal bench candidates for replacement selector test")
	var legal_selector := TestReplacementSelector.new()
	var chosen_unit_id: String = legal_side.bench_order[1]
	legal_selector.next_selection = chosen_unit_id
	core.service("replacement_service").replacement_selector = legal_selector
	var legal_result: Dictionary = core.service("replacement_service").resolve_replacement(legal_state, legal_side, "forced_replace")
	if legal_result.get("invalid_code", null) != null:
		return harness.fail_result("legal replacement selection should pass")
	var entered_unit = legal_result.get("entered_unit", null)
	if entered_unit == null or entered_unit.unit_instance_id != chosen_unit_id:
		return harness.fail_result("replacement selector did not pick requested legal target")

	var invalid_state = harness.build_initialized_battle(core, content_index, sample_factory, 216)
	var invalid_side = invalid_state.get_side("P1")
	var invalid_selector := TestReplacementSelector.new()
	invalid_selector.next_selection = "unit_not_in_bench"
	core.service("replacement_service").replacement_selector = invalid_selector
	var invalid_result: Dictionary = core.service("replacement_service").resolve_replacement(invalid_state, invalid_side, "forced_replace")
	if invalid_result.get("invalid_code", null) != ErrorCodesScript.INVALID_REPLACEMENT_SELECTION:
		return harness.fail_result("invalid replacement target should fail-fast with invalid_replacement_selection")

	var empty_state = harness.build_initialized_battle(core, content_index, sample_factory, 217)
	var empty_side = empty_state.get_side("P1")
	var empty_selector := TestReplacementSelector.new()
	empty_selector.next_selection = null
	core.service("replacement_service").replacement_selector = empty_selector
	var empty_result: Dictionary = core.service("replacement_service").resolve_replacement(empty_state, empty_side, "faint")
	if empty_result.get("invalid_code", null) != ErrorCodesScript.INVALID_REPLACEMENT_SELECTION:
		return harness.fail_result("empty replacement selection should fail-fast with invalid_replacement_selection")

	return harness.pass_result()
