extends RefCounted
class_name ContentIndexSplitSuite

const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("content_index_split_validation_contract", failures, Callable(self, "_test_content_index_split_validation_contract").bind(harness))
    runner.run_test("content_snapshot_recursive_contract", failures, Callable(self, "_test_content_snapshot_recursive_contract").bind(harness))
    runner.run_test("content_snapshot_curated_contract", failures, Callable(self, "_test_content_snapshot_curated_contract").bind(harness))
    runner.run_test("content_snapshot_recursive_missing_dir_contract", failures, Callable(self, "_test_content_snapshot_recursive_missing_dir_contract").bind(harness))

func _test_content_index_split_validation_contract(harness) -> Dictionary:
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)

    var bad_skill = SkillDefinitionScript.new()
    bad_skill.id = "split_contract_bad_skill"
    bad_skill.display_name = "Split Contract Bad Skill"
    bad_skill.targeting = ContentSchemaScript.TARGET_ENEMY_ACTIVE
    bad_skill.priority = 9
    content_index.register_resource(bad_skill)
    var snapshot_errors: Array = content_index.validate_snapshot()
    if not _errors_contain(snapshot_errors, "skill[split_contract_bad_skill].priority out of range"):
        return harness.fail_result("snapshot validation contract changed after content index split")

    var battle_setup = sample_factory.build_sample_setup({
        "P1": {
            3: PackedStringArray(["sample_field_call", "sample_whiff", "sample_tide_surge"])
        }
    })
    var setup_errors: Array = content_index.validate_setup(battle_setup)
    if not _errors_contain(setup_errors, "regular_skill_loadout_overrides slot out of range"):
        return harness.fail_result("setup validation contract changed after content index split")
    return harness.pass_result()

func _test_content_snapshot_recursive_contract(harness) -> Dictionary:
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var discovered_paths = sample_factory.collect_tres_paths_recursive("res://tests/fixtures/content_snapshot")
    var expected_nested_path := "res://tests/fixtures/content_snapshot/nested/leaf_probe.tres"
    var expected_root_path := "res://tests/fixtures/content_snapshot/root_probe.tres"
    if discovered_paths.size() != 2:
        return harness.fail_result("expected recursive content snapshot probe to find 2 tres files, got %d" % discovered_paths.size())
    if not discovered_paths.has(expected_nested_path):
        return harness.fail_result("recursive snapshot collection missed nested tres path")
    if not discovered_paths.has(expected_root_path):
        return harness.fail_result("recursive snapshot collection missed root tres path")
    return harness.pass_result()

func _test_content_snapshot_curated_contract(harness) -> Dictionary:
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var snapshot_paths_payload: Dictionary = harness.build_content_snapshot_paths(sample_factory)
    if snapshot_paths_payload.has("error"):
        return harness.fail_result(str(snapshot_paths_payload.get("error", "content snapshot path build failed")))
    var snapshot_paths: PackedStringArray = snapshot_paths_payload.get("paths", PackedStringArray())
    var required_paths := PackedStringArray([
        "res://content/skills/sample_strike.tres",
        "res://content/units/gojo/gojo_satoru.tres",
        "res://content/skills/obito/obito_qiudao_yu.tres",
    ])
    var seen: Dictionary = {}
    for snapshot_path in snapshot_paths:
        var path := String(snapshot_path)
        if seen.has(path):
            return harness.fail_result("content snapshot path list should stay de-duplicated")
        seen[path] = true
    for required_path in required_paths:
        if not snapshot_paths.has(required_path):
            return harness.fail_result("content snapshot path list should include %s" % required_path)
    if snapshot_paths.has("res://content/shared/effects/sukuna_shared_fire_burst_damage.tres"):
        return harness.fail_result("content snapshot path list should not register content/shared helper resources directly")
    return harness.pass_result()

func _test_content_snapshot_recursive_missing_dir_contract(harness) -> Dictionary:
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var result: Dictionary = sample_factory.collect_tres_paths_recursive_result("res://tests/fixtures/content_snapshot_missing")
    if bool(result.get("ok", true)):
        return harness.fail_result("missing recursive snapshot dir should return structured error")
    if String(result.get("error_code", "")) != "invalid_content_snapshot":
        return harness.fail_result("missing recursive snapshot dir should report invalid_content_snapshot")
    if not sample_factory.collect_tres_paths_recursive("res://tests/fixtures/content_snapshot_missing").is_empty():
        return harness.fail_result("recursive snapshot wrapper should degrade to empty array on missing dir")
    return harness.pass_result()

func _errors_contain(errors: Array, needle: String) -> bool:
    for error_msg in errors:
        if String(error_msg).find(needle) != -1:
            return true
    return false
