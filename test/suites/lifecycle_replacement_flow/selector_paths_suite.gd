extends "res://test/suites/lifecycle_replacement_flow/base.gd"


func test_replacement_selector_paths() -> void:
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

	var legal_state = _harness.build_initialized_battle(core, content_index, sample_factory, 215)
	var legal_side = legal_state.get_side("P1")
	if legal_side == null or legal_side.bench_order.size() < 2:
		fail("expected at least 2 legal bench candidates for replacement selector test")
		return
	var legal_selector := TestReplacementSelector.new()
	var chosen_unit_id: String = legal_side.bench_order[1]
	legal_selector.next_selection = chosen_unit_id
	core.service("replacement_service").replacement_selector = legal_selector
	var legal_result: Dictionary = core.service("replacement_service").resolve_replacement(legal_state, legal_side, "forced_replace")
	if legal_result.get("invalid_code", null) != null:
		fail("legal replacement selection should pass")
		return
	var entered_unit = legal_result.get("entered_unit", null)
	if entered_unit == null or entered_unit.unit_instance_id != chosen_unit_id:
		fail("replacement selector did not pick requested legal target")
		return

	var invalid_state = _harness.build_initialized_battle(core, content_index, sample_factory, 216)
	var invalid_side = invalid_state.get_side("P1")
	var invalid_selector := TestReplacementSelector.new()
	invalid_selector.next_selection = "unit_not_in_bench"
	core.service("replacement_service").replacement_selector = invalid_selector
	var invalid_result: Dictionary = core.service("replacement_service").resolve_replacement(invalid_state, invalid_side, "forced_replace")
	if invalid_result.get("invalid_code", null) != ErrorCodesScript.INVALID_REPLACEMENT_SELECTION:
		fail("invalid replacement target should fail-fast with invalid_replacement_selection")
		return

	var empty_state = _harness.build_initialized_battle(core, content_index, sample_factory, 217)
	var empty_side = empty_state.get_side("P1")
	var empty_selector := TestReplacementSelector.new()
	empty_selector.next_selection = null
	core.service("replacement_service").replacement_selector = empty_selector
	var empty_result: Dictionary = core.service("replacement_service").resolve_replacement(empty_state, empty_side, "faint")
	if empty_result.get("invalid_code", null) != ErrorCodesScript.INVALID_REPLACEMENT_SELECTION:
		fail("empty replacement selection should fail-fast with invalid_replacement_selection")
		return
