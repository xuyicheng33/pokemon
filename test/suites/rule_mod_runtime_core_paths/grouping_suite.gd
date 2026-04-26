extends "res://tests/support/gdunit_suite_bridge.gd"

const SharedScript := preload("res://test/suites/rule_mod_runtime_core_paths/shared.gd")

var _shared = SharedScript.new()


func test_rule_mod_multi_source_grouping_paths() -> void:
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
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 119)
	var p1_active = battle_state.get_side("P1").get_active_unit()
	var p2_active = battle_state.get_side("P2").get_active_unit()
	if p1_active == null or p2_active == null:
		fail("missing active units for multi-source rule_mod contract")
		return
	var regen_payload_a = _shared.build_numeric_rule_mod_payload("mp_regen", "add", 2, "regen:passive")
	if core.service("rule_mod_service").create_instance(regen_payload_a, {"scope": "unit", "id": p1_active.unit_instance_id}, battle_state, "regen_source_a", 0, p1_active.base_speed, null, "effect_regen_a") == null:
		fail("failed to create first mp_regen grouped rule_mod")
		return
	var regen_payload_b = _shared.build_numeric_rule_mod_payload("mp_regen", "add", 3, "regen:item")
	if core.service("rule_mod_service").create_instance(regen_payload_b, {"scope": "unit", "id": p1_active.unit_instance_id}, battle_state, "regen_source_b", 0, p1_active.base_speed, null, "effect_regen_b") == null:
		fail("failed to create second mp_regen grouped rule_mod")
		return
	if _shared.count_rule_mod_instances(p1_active, "mp_regen") != 2:
		fail("different mp_regen source groups should coexist at runtime")
		return
	if core.service("rule_mod_service").resolve_mp_regen_value(battle_state, p1_active.unit_instance_id, 0) != 5:
		fail("different mp_regen source groups should add together")
		return
	var regen_payload_replace = _shared.build_numeric_rule_mod_payload("mp_regen", "add", 4, "regen:passive")
	if core.service("rule_mod_service").create_instance(regen_payload_replace, {"scope": "unit", "id": p1_active.unit_instance_id}, battle_state, "regen_source_a_replace", 0, p1_active.base_speed, null, "effect_regen_c") == null:
		fail("failed to replace grouped mp_regen rule_mod")
		return
	if _shared.count_rule_mod_instances(p1_active, "mp_regen") != 2:
		fail("same mp_regen source group should replace instead of growing instance count")
		return
	if core.service("rule_mod_service").resolve_mp_regen_value(battle_state, p1_active.unit_instance_id, 0) != 7:
		fail("same mp_regen source group should replace old value while other groups keep stacking")
		return
	var regen_payload_none = _shared.build_numeric_rule_mod_payload("mp_regen", "add", 99, "regen:passive")
	regen_payload_none.stacking = "none"
	if core.service("rule_mod_service").create_instance(regen_payload_none, {"scope": "unit", "id": p1_active.unit_instance_id}, battle_state, "regen_source_none", 0, p1_active.base_speed, null, "effect_regen_d") == null:
		fail("stacking=none grouped mp_regen should return existing instance instead of null")
		return
	if _shared.count_rule_mod_instances(p1_active, "mp_regen") != 2 or core.service("rule_mod_service").resolve_mp_regen_value(battle_state, p1_active.unit_instance_id, 0) != 7:
		fail("stacking=none should not duplicate grouped mp_regen instances")
		return
	if not _shared.unit_rule_mods_have_source_keys(p1_active, "mp_regen", PackedStringArray(["regen:passive", "regen:item"])):
		fail("mp_regen grouped instances should expose source_stacking_key at runtime")
		return
	var incoming_payload_a = _shared.build_numeric_rule_mod_payload("incoming_accuracy", "add", -10, "accuracy:passive")
	if core.service("rule_mod_service").create_instance(incoming_payload_a, {"scope": "unit", "id": p2_active.unit_instance_id}, battle_state, "accuracy_source_a", 0, p2_active.base_speed, null, "effect_accuracy_a") == null:
		fail("failed to create first incoming_accuracy grouped rule_mod")
		return
	var incoming_payload_b = _shared.build_numeric_rule_mod_payload("incoming_accuracy", "add", -5, "accuracy:field")
	if core.service("rule_mod_service").create_instance(incoming_payload_b, {"scope": "unit", "id": p2_active.unit_instance_id}, battle_state, "accuracy_source_b", 0, p2_active.base_speed, null, "effect_accuracy_b") == null:
		fail("failed to create second incoming_accuracy grouped rule_mod")
		return
	if _shared.count_rule_mod_instances(p2_active, "incoming_accuracy") != 2:
		fail("different incoming_accuracy source groups should coexist at runtime")
		return
	if core.service("rule_mod_service").resolve_incoming_accuracy(battle_state, p2_active.unit_instance_id, 95) != 80:
		fail("different incoming_accuracy source groups should add together")
		return
	var incoming_payload_replace = _shared.build_numeric_rule_mod_payload("incoming_accuracy", "add", -12, "accuracy:passive")
	if core.service("rule_mod_service").create_instance(incoming_payload_replace, {"scope": "unit", "id": p2_active.unit_instance_id}, battle_state, "accuracy_source_replace", 0, p2_active.base_speed, null, "effect_accuracy_c") == null:
		fail("failed to replace grouped incoming_accuracy rule_mod")
		return
	if _shared.count_rule_mod_instances(p2_active, "incoming_accuracy") != 2:
		fail("same incoming_accuracy source group should replace instead of growing instance count")
		return
	if core.service("rule_mod_service").resolve_incoming_accuracy(battle_state, p2_active.unit_instance_id, 95) != 78:
		fail("same incoming_accuracy source group should replace old value while other groups keep stacking")
		return
