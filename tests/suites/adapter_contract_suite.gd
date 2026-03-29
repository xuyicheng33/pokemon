extends RefCounted
class_name AdapterContractSuite

const BattleAIAdapterScript := preload("res://src/adapters/battle_ai_adapter.gd")
const LegalActionSetScript := preload("res://src/battle_core/contracts/legal_action_set.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("ai_adapter_forced_command_contract", failures, Callable(self, "_test_ai_adapter_forced_command_contract"))
    runner.run_test("manager_replay_output_runtime_boundary", failures, Callable(self, "_test_manager_replay_output_runtime_boundary").bind(harness))

func _test_ai_adapter_forced_command_contract() -> Dictionary:
    var legal_action_set = LegalActionSetScript.new()
    legal_action_set.actor_public_id = "P1-A"
    legal_action_set.wait_allowed = false
    legal_action_set.forced_command_type = "resource_forced_default"
    var ai_choice: Dictionary = BattleAIAdapterScript.new().choose_command(legal_action_set)
    if not ai_choice.is_empty():
        return {
            "ok": false,
            "error": "BattleAIAdapter must leave forced command injection to turn_selection_resolver",
        }
    return {"ok": true}

func _test_manager_replay_output_runtime_boundary(harness) -> Dictionary:
    var manager_payload = harness.build_manager()
    if manager_payload.has("error"):
        return harness.fail_result(str(manager_payload["error"]))
    var manager = manager_payload["manager"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var replay_result: Dictionary = manager.run_replay(sample_factory.build_demo_replay_input(manager))
    var replay_output = replay_result.get("replay_output", null)
    if replay_output == null:
        return harness.fail_result("run_replay should return replay_output")
    if replay_output.final_battle_state != null:
        return harness.fail_result("manager.run_replay must not expose internal final_battle_state")
    if typeof(replay_result.get("public_snapshot", null)) != TYPE_DICTIONARY:
        return harness.fail_result("manager.run_replay should still expose public_snapshot")
    return harness.pass_result()
