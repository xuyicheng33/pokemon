extends "res://tests/suites/content_validation_core/base.gd"
const BaseSuiteScript := preload("res://tests/suites/content_validation_core/base.gd")
const FormalCharacterPairSmokeSharedScript := preload("res://tests/suites/formal_character_pair_smoke/shared.gd")
const ManagerContractTestHelperScript := preload("res://tests/support/manager_contract_test_helper.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("formal_character_shared_fire_burst_validation", failures, Callable(self, "_test_formal_character_shared_fire_burst_validation").bind(harness))
    runner.run_test("formal_character_validator_registry_runtime_contract", failures, Callable(self, "_test_formal_character_validator_registry_runtime_contract").bind(harness))
    runner.run_test("formal_character_setup_registry_runtime_contract", failures, Callable(self, "_test_formal_character_setup_registry_runtime_contract").bind(harness))
    runner.run_test("formal_character_registry_id_mismatch_contract", failures, Callable(self, "_test_formal_character_registry_id_mismatch_contract").bind(harness))
    runner.run_test("formal_character_validator_partial_snapshot_contract", failures, Callable(self, "_test_formal_character_validator_partial_snapshot_contract").bind(harness))
    runner.run_test("formal_character_validator_present_character_scope_contract", failures, Callable(self, "_test_formal_character_validator_present_character_scope_contract").bind(harness))
    runner.run_test("sample_battle_factory_result_error_contract", failures, Callable(self, "_test_sample_battle_factory_result_error_contract").bind(harness))

func _test_formal_character_shared_fire_burst_validation(harness) -> Dictionary:
    var shared_path := "res://content/shared/effects/sukuna_shared_fire_burst_damage.tres"
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var kamado_mark = content_index.effects.get("sukuna_kamado_mark", null)
    var kamado_explode = content_index.effects.get("sukuna_kamado_explode", null)
    var domain_expire_burst = content_index.effects.get("sukuna_domain_expire_burst", null)
    if kamado_mark == null or kamado_explode == null or domain_expire_burst == null:
        return harness.fail_result("missing Sukuna shared fire burst effects")
    if kamado_mark.payloads.is_empty() or kamado_explode.payloads.is_empty() or domain_expire_burst.payloads.is_empty():
        return harness.fail_result("missing Sukuna shared fire burst payload")
    if String(kamado_mark.payloads[0].resource_path) != shared_path or String(kamado_explode.payloads[0].resource_path) != shared_path or String(domain_expire_burst.payloads[0].resource_path) != shared_path:
        return harness.fail_result("Sukuna fire burst effects must all point to the shared payload resource")
    var drift_payload := DamagePayloadScript.new()
    drift_payload.payload_type = "damage"
    drift_payload.amount = 20
    drift_payload.use_formula = false
    drift_payload.combat_type_id = "fire"
    kamado_mark.payloads[0] = drift_payload
    var errors: Array = content_index.validate_snapshot()
    for error_msg in errors:
        if str(error_msg).find("formal[sukuna].shared_fire_burst effect[sukuna_kamado_mark] must reuse payload resource") != -1:
            return harness.pass_result()
    return harness.fail_result("formal shared fire burst validation should fail when Sukuna effects stop sharing one payload resource")

func _test_formal_character_validator_registry_runtime_contract(harness) -> Dictionary:
    var load_result: Dictionary = FormalCharacterValidatorRegistryScript.load_entries()
    var error_message := String(load_result.get("error", ""))
    if not error_message.is_empty():
        return harness.fail_result("formal character validator registry should load cleanly: %s" % error_message)
    var entries: Array = load_result.get("entries", [])
    if entries.is_empty():
        return harness.fail_result("formal character validator registry should expose at least one docs entry")
    var descriptor_result: Dictionary = FormalCharacterValidatorRegistryScript.build_validator_descriptors()
    error_message = String(descriptor_result.get("error", ""))
    if not error_message.is_empty():
        return harness.fail_result("formal character validator descriptors should build cleanly: %s" % error_message)
    var descriptors: Array = descriptor_result.get("descriptors", [])
    if descriptors.size() != entries.size():
        return harness.fail_result("formal character validator descriptors should match docs registry entry count")
    for raw_descriptor in descriptors:
        if not (raw_descriptor is Dictionary):
            return harness.fail_result("formal character validator descriptor must be Dictionary")
        var descriptor: Dictionary = raw_descriptor
        if String(descriptor.get("character_id", "")).is_empty():
            return harness.fail_result("formal character validator descriptor missing character_id")
        if String(descriptor.get("unit_definition_id", "")).is_empty():
            return harness.fail_result("formal character validator descriptor missing unit_definition_id")
        if String(descriptor.get("content_validator_script_path", "")).is_empty():
            return harness.fail_result("formal character validator descriptor missing content_validator_script_path")
        var validator = descriptor.get("validator", null)
        if validator == null or not validator.has_method("validate"):
            return harness.fail_result("formal character validator registry returned invalid validator instance")
    return harness.pass_result()

func _test_formal_character_setup_registry_runtime_contract(harness) -> Dictionary:
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var load_result: Dictionary = FormalCharacterValidatorRegistryScript.load_entries()
    var error_message := String(load_result.get("error", ""))
    if not error_message.is_empty():
        return harness.fail_result("formal character registry should load cleanly for setup contract: %s" % error_message)
    var entries: Array = load_result.get("entries", [])
    var expected_ids := PackedStringArray()
    for raw_entry in entries:
        var entry: Dictionary = raw_entry
        var character_id := String(entry.get("character_id", "")).strip_edges()
        expected_ids.append(character_id)
        var matchup_id := String(entry.get("formal_setup_matchup_id", "")).strip_edges()
        if matchup_id.is_empty():
            return harness.fail_result("formal character registry[%s] missing formal_setup_matchup_id" % character_id)
        var expected_setup_result: Dictionary = sample_factory.build_setup_by_matchup_id_result(matchup_id)
        if not bool(expected_setup_result.get("ok", false)):
            return harness.fail_result("formal character setup matchup missing from SampleBattleFactory: %s (%s)" % [
                matchup_id,
                String(expected_setup_result.get("error_message", "unknown error")),
            ])
        var expected_setup = expected_setup_result.get("data", null)
        var actual_setup_result: Dictionary = sample_factory.build_formal_character_setup_result(character_id)
        if not bool(actual_setup_result.get("ok", false)):
            return harness.fail_result("build_formal_character_setup_result failed for %s: %s" % [
                character_id,
                String(actual_setup_result.get("error_message", "unknown error")),
            ])
        var actual_setup = actual_setup_result.get("data", null)
        if _setup_signature(actual_setup) != _setup_signature(expected_setup):
            return harness.fail_result("formal character setup drifted from registry matchup for %s" % character_id)
    if sample_factory.formal_character_ids() != expected_ids:
        return harness.fail_result("formal_character_ids should preserve registry file order")
    return harness.pass_result()

func _test_formal_character_registry_id_mismatch_contract(harness) -> Dictionary:
    var registry_path := "user://formal_character_registry_mismatch_fixture.json"
    var matchup_catalog_path := "user://formal_matchup_catalog_mismatch_fixture.json"
    var registry_payload := JSON.stringify([
        {
            "character_id": "gojo_alias",
            "unit_definition_id": "gojo_satoru",
            "suite_path": "tests/suites/gojo_suite.gd",
            "design_doc": "docs/design/gojo_satoru_design.md",
            "adjustment_doc": "docs/design/gojo_satoru_adjustments.md",
            "formal_setup_matchup_id": "gojo_alias_vs_sukuna_alias",
            "required_content_paths": [],
            "required_suite_paths": ["tests/suites/formal_character_pair_smoke_suite.gd"],
            "required_test_names": [],
            "design_needles": ["placeholder:gojo_alias"],
            "adjustment_needles": ["placeholder:gojo_alias"]
        },
        {
            "character_id": "sukuna_alias",
            "unit_definition_id": "sukuna",
            "suite_path": "tests/suites/sukuna_suite.gd",
            "design_doc": "docs/design/sukuna_design.md",
            "adjustment_doc": "docs/design/sukuna_adjustments.md",
            "formal_setup_matchup_id": "sukuna_alias_vs_gojo_alias",
            "required_content_paths": [],
            "required_suite_paths": ["tests/suites/formal_character_pair_smoke_suite.gd"],
            "required_test_names": [],
            "design_needles": ["placeholder:sukuna_alias"],
            "adjustment_needles": ["placeholder:sukuna_alias"]
        }
    ], "  ")
    var catalog_payload := JSON.stringify({
        "matchups": {
            "gojo_alias_vs_sukuna_alias": {
                "p1_units": ["gojo_satoru", "sample_mossaur", "sample_pyron"],
                "p2_units": ["sukuna", "sample_tidekit", "sample_mossaur"]
            },
            "sukuna_alias_vs_gojo_alias": {
                "p1_units": ["sukuna", "sample_tidekit", "sample_mossaur"],
                "p2_units": ["gojo_satoru", "sample_mossaur", "sample_tidekit"]
            }
        },
        "pair_surface_cases": [
            {
                "test_name": "formal_pair_gojo_alias_vs_sukuna_alias_manager_smoke_contract",
                "matchup_id": "gojo_alias_vs_sukuna_alias",
                "battle_seed": 3611,
                "p1_character_id": "gojo_alias",
                "p2_character_id": "sukuna_alias",
                "p1_unit_definition_id": "gojo_satoru",
                "p2_unit_definition_id": "sukuna",
                "p1_skill_id": "gojo_ao",
                "p2_skill_id": "sukuna_kai"
            },
            {
                "test_name": "formal_pair_sukuna_alias_vs_gojo_alias_manager_smoke_contract",
                "matchup_id": "sukuna_alias_vs_gojo_alias",
                "battle_seed": 3612,
                "p1_character_id": "sukuna_alias",
                "p2_character_id": "gojo_alias",
                "p1_unit_definition_id": "sukuna",
                "p2_unit_definition_id": "gojo_satoru",
                "p1_skill_id": "sukuna_kai",
                "p2_skill_id": "gojo_ao"
            }
        ],
        "pair_interaction_cases": []
    }, "  ")
    if not _write_json_fixture(registry_path, registry_payload):
        return harness.fail_result("failed to write formal registry mismatch fixture")
    if not _write_json_fixture(matchup_catalog_path, catalog_payload):
        return harness.fail_result("failed to write formal matchup mismatch fixture")
    var override_factory = harness.build_sample_factory_with_overrides(registry_path, matchup_catalog_path)
    if override_factory == null:
        return harness.fail_result("SampleBattleFactory init failed for mismatch fixture")
    if override_factory.formal_character_ids() != PackedStringArray(["gojo_alias", "sukuna_alias"]):
        return harness.fail_result("formal_character_ids should preserve registry character ids even when they differ from unit_definition_id")
    if override_factory.formal_unit_definition_ids() != PackedStringArray(["gojo_satoru", "sukuna"]):
        return harness.fail_result("formal_unit_definition_ids should expose registry unit_definition_id order")
    var setup_result: Dictionary = override_factory.build_formal_character_setup_result("gojo_alias")
    if not bool(setup_result.get("ok", false)):
        return harness.fail_result("build_formal_character_setup_result should resolve mismatch registry character_id: %s" % String(setup_result.get("error_message", "unknown error")))
    var battle_setup = setup_result.get("data", null)
    if battle_setup == null or battle_setup.sides.is_empty() or battle_setup.sides[0].unit_definition_ids[0] != "gojo_satoru":
        return harness.fail_result("formal setup should still resolve the real unit_definition_id when character_id differs")
    var pair_shared = FormalCharacterPairSmokeSharedScript.new()
    var matrix_result = pair_shared.validate_directed_surface_matrix(harness, override_factory, override_factory.formal_pair_surface_cases())
    if not bool(matrix_result.get("ok", false)):
        return matrix_result
    var live_factory = harness.build_sample_factory()
    if live_factory == null:
        return harness.fail_result("SampleBattleFactory init failed for public snapshot mismatch contract")
    var snapshot_result: Dictionary = live_factory.content_snapshot_paths_for_setup_result(battle_setup)
    if not bool(snapshot_result.get("ok", false)):
        return harness.fail_result("live snapshot path build failed for mismatch setup: %s" % String(snapshot_result.get("error_message", "unknown error")))
    var manager_payload = harness.build_manager()
    if manager_payload.has("error"):
        return harness.fail_result(str(manager_payload["error"]))
    var manager = manager_payload["manager"]
    var create_result: Dictionary = manager.create_session({
        "battle_seed": 3613,
        "content_snapshot_paths": snapshot_result.get("data", PackedStringArray()),
        "battle_setup": battle_setup,
    })
    if not bool(create_result.get("ok", false)):
        return harness.fail_result("manager create_session should accept mismatch setup: %s" % String(create_result.get("error_message", "unknown error")))
    var public_snapshot: Dictionary = create_result.get("data", {}).get("public_snapshot", {})
    var manager_helper := ManagerContractTestHelperScript.new()
    var p1_active_snapshot := manager_helper.find_unit_snapshot(public_snapshot, "P1", "P1-A")
    if p1_active_snapshot.is_empty() or String(p1_active_snapshot.get("definition_id", "")) != "gojo_satoru":
        return harness.fail_result("public snapshot should still expose real unit definition ids when registry character_id differs")
    return harness.pass_result()

func _write_json_fixture(path: String, payload: String) -> bool:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(payload)
    return true

func _test_formal_character_validator_partial_snapshot_contract(harness) -> Dictionary:
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var sample_only_content = BattleContentIndexScript.new()
    var sample_only_paths: Variant = _build_filtered_snapshot_paths(harness, sample_factory, PackedStringArray(["/gojo/", "/sukuna/", "/kashimo/", "/obito/"]))
    if sample_only_paths is Dictionary and sample_only_paths.has("error"):
        return harness.fail_result(str(sample_only_paths.get("error", "sample-only snapshot path build failed")))
    if not sample_only_content.load_snapshot(sample_only_paths):
        return harness.fail_result("sample-only snapshot should validate without formal character assets: %s" % sample_only_content.last_error_message)
    var gojo_only_content = BattleContentIndexScript.new()
    var gojo_only_paths: Variant = _build_filtered_snapshot_paths(harness, sample_factory, PackedStringArray(["/sukuna/", "/kashimo/", "/obito/"]))
    if gojo_only_paths is Dictionary and gojo_only_paths.has("error"):
        return harness.fail_result(str(gojo_only_paths.get("error", "gojo-only snapshot path build failed")))
    if not gojo_only_content.load_snapshot(gojo_only_paths):
        return harness.fail_result("gojo-only snapshot should validate without unrelated formal characters: %s" % gojo_only_content.last_error_message)
    if not gojo_only_content.units.has("gojo_satoru") or gojo_only_content.units.has("sukuna") or gojo_only_content.units.has("kashimo_hajime") or gojo_only_content.units.has("obito_juubi_jinchuriki"):
        return harness.fail_result("gojo-only snapshot filter should keep only Gojo formal assets")
    return harness.pass_result()

func _test_formal_character_validator_present_character_scope_contract(harness) -> Dictionary:
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = BattleContentIndexScript.new()
    var gojo_only_paths: Variant = _build_filtered_snapshot_paths(harness, sample_factory, PackedStringArray(["/sukuna/", "/kashimo/", "/obito/"]))
    if gojo_only_paths is Dictionary and gojo_only_paths.has("error"):
        return harness.fail_result(str(gojo_only_paths.get("error", "gojo-only snapshot path build failed")))
    if not content_index.load_snapshot(gojo_only_paths):
        return harness.fail_result("gojo-only snapshot should load before scoped validation probe: %s" % content_index.last_error_message)
    var burst_effect = content_index.effects.get("gojo_murasaki_conditional_burst", null)
    if burst_effect == null:
        return harness.fail_result("gojo-only snapshot missing gojo_murasaki_conditional_burst")
    burst_effect.required_target_same_owner = false
    var errors: Array = content_index.validate_snapshot()
    var saw_gojo_scope_error := false
    for error_msg in errors:
        var msg := str(error_msg)
        if msg.find("formal[gojo].murasaki_burst required_target_same_owner must be true") != -1:
            saw_gojo_scope_error = true
        if msg.find("formal[sukuna]") != -1 or msg.find("formal[kashimo]") != -1:
            return harness.fail_result("scoped formal validator should not report unrelated characters when only Gojo is loaded")
    if not saw_gojo_scope_error:
        return harness.fail_result("scoped formal validator should still enforce Gojo contracts when Gojo is present")
    return harness.pass_result()

func _test_sample_battle_factory_result_error_contract(harness) -> Dictionary:
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var missing_matchup_result: Dictionary = sample_factory.build_setup_by_matchup_id_result("missing_matchup")
    if bool(missing_matchup_result.get("ok", true)):
        return harness.fail_result("missing matchup should return result-style error")
    if String(missing_matchup_result.get("error_code", "")) != "invalid_battle_setup":
        return harness.fail_result("missing matchup should report invalid_battle_setup")
    var missing_character_result: Dictionary = sample_factory.build_formal_character_setup_result("missing_character")
    if bool(missing_character_result.get("ok", true)):
        return harness.fail_result("missing formal character should return result-style error")
    if String(missing_character_result.get("error_code", "")) != "invalid_battle_setup":
        return harness.fail_result("missing formal character should report invalid_battle_setup")
    return harness.pass_result()

func _setup_signature(battle_setup) -> Array:
    var signature: Array = []
    if battle_setup == null:
        return signature
    for side_setup in battle_setup.sides:
        signature.append({
            "side_id": String(side_setup.side_id),
            "unit_definition_ids": PackedStringArray(side_setup.unit_definition_ids),
            "starting_index": int(side_setup.starting_index),
        })
    return signature
