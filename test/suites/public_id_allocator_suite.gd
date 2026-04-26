extends "res://tests/support/gdunit_suite_bridge.gd"

const PublicIdAllocatorScript := preload("res://src/battle_core/turn/public_id_allocator.gd")


func test_public_id_allocator_label_sequence() -> void:
	var allocator = PublicIdAllocatorScript.new()
	var cases: Array[Dictionary] = [
		{"slot_index": 0, "label": "A"},
		{"slot_index": 2, "label": "C"},
		{"slot_index": 25, "label": "Z"},
		{"slot_index": 26, "label": "AA"},
	]
	for test_case in cases:
		var public_id = allocator.build_public_id("P1", int(test_case["slot_index"]))
		var expected_public_id = "P1-%s" % String(test_case["label"])
		if public_id != expected_public_id:
			fail("public_id_allocator label mismatch: expected %s got %s" % [expected_public_id, public_id])
			return

func test_public_id_allocator_runtime_contract() -> void:
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
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 407)
	var p1_side = battle_state.get_side("P1")
	var p2_side = battle_state.get_side("P2")
	if p1_side == null or p2_side == null:
		fail("public_id runtime contract missing side state")
		return
	var p1_ids: Array[String] = []
	for unit_state in p1_side.team_units:
		p1_ids.append(unit_state.public_id)
	var p2_ids: Array[String] = []
	for unit_state in p2_side.team_units:
		p2_ids.append(unit_state.public_id)
	if p1_ids != ["P1-A", "P1-B", "P1-C"]:
		fail("P1 public_id runtime contract changed: %s" % str(p1_ids))
		return
	if p2_ids != ["P2-A", "P2-B", "P2-C"]:
		fail("P2 public_id runtime contract changed: %s" % str(p2_ids))
		return

