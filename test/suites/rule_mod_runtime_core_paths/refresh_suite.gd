extends "res://test/support/gdunit_suite_bridge.gd"

const SharedScript := preload("res://test/suites/rule_mod_runtime_core_paths/shared.gd")

var _shared = SharedScript.new()



func test_rule_mod_refresh_updates_source_metadata_contract() -> void:
	_assert_legacy_result(_test_rule_mod_refresh_updates_source_metadata_contract(_harness))
func _test_rule_mod_refresh_updates_source_metadata_contract(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 120)
	var actor = battle_state.get_side("P1").get_active_unit()
	if actor == null:
		return harness.fail_result("missing active unit for rule_mod refresh metadata contract")

	var regen_payload = _shared.build_numeric_rule_mod_payload("mp_regen", "add", 2, "regen:refresh_contract")
	regen_payload.stacking = "refresh"
	regen_payload.persists_on_switch = false
	var first_instance = core.service("rule_mod_service").create_instance(
		regen_payload,
		{"scope": "unit", "id": actor.unit_instance_id},
		battle_state,
		"refresh_source_first",
		1,
		50,
		null,
		"shared_refresh_group"
	)
	if first_instance == null:
		return harness.fail_result("failed to create first refreshable rule_mod")
	first_instance.remaining = 1

	var refreshed_payload = _shared.build_numeric_rule_mod_payload("mp_regen", "add", 7, "regen:refresh_contract")
	refreshed_payload.stacking = "refresh"
	refreshed_payload.persists_on_switch = true
	var refreshed_instance = core.service("rule_mod_service").create_instance(
		refreshed_payload,
		{"scope": "unit", "id": actor.unit_instance_id},
		battle_state,
		"refresh_source_second",
		2,
		90,
		null,
		"shared_refresh_group"
	)
	if refreshed_instance == null:
		return harness.fail_result("failed to refresh rule_mod instance")
	if refreshed_instance != first_instance:
		return harness.fail_result("rule_mod refresh should keep the same runtime instance")
	if core.service("rule_mod_service").last_apply_skipped:
		return harness.fail_result("rule_mod refresh should not be marked as skipped")
	if refreshed_instance.remaining != 2 or int(refreshed_instance.value) != 7:
		return harness.fail_result("rule_mod refresh should reset remaining turns and update value")
	if refreshed_instance.source_instance_id != "refresh_source_second" or refreshed_instance.source_kind_order != 2 or refreshed_instance.source_order_speed_snapshot != 90:
		return harness.fail_result("rule_mod refresh should update source identity and order metadata")
	if refreshed_instance.persists_on_switch != true:
		return harness.fail_result("rule_mod refresh should keep persists_on_switch updated on refresh")
	if refreshed_instance.source_stacking_key != "regen:refresh_contract":
		return harness.fail_result(
			"rule_mod refresh should preserve source_stacking_key on refresh: expected=regen:refresh_contract actual=%s"
			% str(refreshed_instance.source_stacking_key)
		)
	return harness.pass_result()
