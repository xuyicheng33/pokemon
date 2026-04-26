extends "res://tests/support/gdunit_suite_bridge.gd"

const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")


func test_content_index_split_validation_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var content_index = _harness.build_loaded_content_index(sample_factory)

	var bad_skill = SkillDefinitionScript.new()
	bad_skill.id = "split_contract_bad_skill"
	bad_skill.display_name = "Split Contract Bad Skill"
	bad_skill.targeting = ContentSchemaScript.TARGET_ENEMY_ACTIVE
	bad_skill.priority = 9
	content_index.register_resource(bad_skill)
	var snapshot_errors: Array = content_index.validate_snapshot()
	if not _errors_contain(snapshot_errors, "skill[split_contract_bad_skill].priority out of range"):
		fail("snapshot validation contract changed after content index split")
		return

	var battle_setup = _harness.build_sample_setup(sample_factory, {
		"P1": {
			3: PackedStringArray(["sample_field_call", "sample_whiff", "sample_tide_surge"])
		}
	})
	var setup_errors: Array = content_index.validate_setup(battle_setup)
	if not _errors_contain(setup_errors, "regular_skill_loadout_overrides slot out of range"):
		fail("setup validation contract changed after content index split")
		return

func test_content_snapshot_recursive_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var discovered_paths = _harness.collect_tres_paths_recursive(sample_factory, "res://tests/fixtures/content_snapshot")
	var expected_nested_path := "res://tests/fixtures/content_snapshot/nested/leaf_probe.tres"
	var expected_root_path := "res://tests/fixtures/content_snapshot/root_probe.tres"
	if discovered_paths.size() != 2:
		fail("expected recursive content snapshot probe to find 2 tres files, got %d" % discovered_paths.size())
		return
	if not discovered_paths.has(expected_nested_path):
		fail("recursive snapshot collection missed nested tres path")
		return
	if not discovered_paths.has(expected_root_path):
		fail("recursive snapshot collection missed root tres path")
		return

func test_content_snapshot_curated_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var snapshot_paths_payload: Dictionary = _harness.build_content_snapshot_paths(sample_factory)
	if snapshot_paths_payload.has("error"):
		fail(str(snapshot_paths_payload.get("error", "content snapshot path build failed")))
		return
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
			fail("content snapshot path list should stay de-duplicated")
			return
		seen[path] = true
	for required_path in required_paths:
		if not snapshot_paths.has(required_path):
			fail("content snapshot path list should include %s" % required_path)
			return
	if snapshot_paths.has("res://content/shared/effects/sukuna_shared_fire_burst_damage.tres"):
		fail("content snapshot path list should not register content/shared helper resources directly")
		return

func test_content_snapshot_recursive_missing_dir_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var result: Dictionary = sample_factory.collect_tres_paths_recursive_result("res://tests/fixtures/content_snapshot_missing")
	if bool(result.get("ok", true)):
		fail("missing recursive snapshot dir should return structured error")
		return
	if String(result.get("error_code", "")) != "invalid_content_snapshot":
		fail("missing recursive snapshot dir should report invalid_content_snapshot")
		return


func _errors_contain(errors: Array, needle: String) -> bool:
	for error_msg in errors:
		if String(error_msg).find(needle) != -1:
			return true
	return false
