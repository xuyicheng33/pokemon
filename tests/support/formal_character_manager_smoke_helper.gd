extends RefCounted
class_name FormalCharacterManagerSmokeHelper

const ManagerContractTestHelperScript := preload("res://tests/support/manager_contract_test_helper.gd")

var _helper = ManagerContractTestHelperScript.new()

func contracts() -> Variant:
	return _helper

func build_context(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return {"error": str(manager_payload["error"])}
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return {"error": "SampleBattleFactory init failed"}
	return {
		"manager": manager_payload["manager"],
		"sample_factory": sample_factory,
	}

func create_session(manager, sample_factory, battle_seed: int, battle_setup, label: String = "create_session") -> Dictionary:
	var snapshot_paths_result: Dictionary = sample_factory.content_snapshot_paths_result()
	if not bool(snapshot_paths_result.get("ok", false)):
		return {"ok": false, "error": str(snapshot_paths_result.get("error_message", "content snapshot path build failed"))}
	return _helper.unwrap_ok(manager.create_session({
		"battle_seed": battle_seed,
		"content_snapshot_paths": snapshot_paths_result.get("data", PackedStringArray()),
		"battle_setup": battle_setup,
	}), label)

func close_session(manager, session_id: String, label: String = "close_session") -> Dictionary:
	return _helper.unwrap_ok(manager.close_session(session_id), label)
