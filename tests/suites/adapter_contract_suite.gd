extends RefCounted
class_name AdapterContractSuite

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("manager_replay_output_runtime_boundary", failures, Callable(self, "_test_manager_replay_output_runtime_boundary").bind(harness))

func _test_manager_replay_output_runtime_boundary(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var replay_unwrap = _unwrap_ok(manager.run_replay(harness.build_demo_replay_input(sample_factory, manager)), "run_replay")
	if not bool(replay_unwrap.get("ok", false)):
		return harness.fail_result(str(replay_unwrap.get("error", "manager run_replay failed")))
	var replay_result: Dictionary = replay_unwrap.get("data", {})
	var replay_output = replay_result.get("replay_output", null)
	if replay_output == null:
		return harness.fail_result("run_replay should return replay_output")
	if replay_output.final_battle_state != null:
		return harness.fail_result("manager.run_replay must not expose internal final_battle_state")
	if typeof(replay_result.get("public_snapshot", null)) != TYPE_DICTIONARY:
		return harness.fail_result("manager.run_replay should still expose public_snapshot")
	return harness.pass_result()

func _unwrap_ok(envelope: Dictionary, label: String) -> Dictionary:
	if envelope == null:
		return {"ok": false, "error": "%s returned null envelope" % label}
	var required_keys := ["ok", "data", "error_code", "error_message"]
	for key in required_keys:
		if not envelope.has(key):
			return {"ok": false, "error": "%s missing envelope key: %s" % [label, key]}
	if bool(envelope.get("ok", false)):
		return {"ok": true, "data": envelope.get("data", null)}
	if envelope.get("data", null) != null:
		return {"ok": false, "error": "%s failure envelope must set data=null" % label}
	return {"ok": false, "error": "%s failed: %s (%s)" % [label, str(envelope.get("error_message", "")), str(envelope.get("error_code", ""))]}
