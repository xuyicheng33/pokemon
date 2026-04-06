extends "res://tests/suites/content_validation_core/base.gd"
const BaseSuiteScript := preload("res://tests/suites/content_validation_core/base.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("formal_character_shared_fire_burst_validation", failures, Callable(self, "_test_formal_character_shared_fire_burst_validation").bind(harness))
    runner.run_test("formal_character_validator_registry_runtime_contract", failures, Callable(self, "_test_formal_character_validator_registry_runtime_contract").bind(harness))
    runner.run_test("formal_character_setup_registry_runtime_contract", failures, Callable(self, "_test_formal_character_setup_registry_runtime_contract").bind(harness))
    runner.run_test("formal_character_validator_partial_snapshot_contract", failures, Callable(self, "_test_formal_character_validator_partial_snapshot_contract").bind(harness))
    runner.run_test("formal_character_validator_present_character_scope_contract", failures, Callable(self, "_test_formal_character_validator_present_character_scope_contract").bind(harness))

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
        var expected_setup = sample_factory.build_setup_by_matchup_id(matchup_id)
        if expected_setup == null:
            return harness.fail_result("formal character setup matchup missing from SampleBattleFactory: %s" % matchup_id)
        var actual_setup = sample_factory.build_formal_character_setup(character_id)
        if actual_setup == null:
            return harness.fail_result("build_formal_character_setup returned null for %s" % character_id)
        if _setup_signature(actual_setup) != _setup_signature(expected_setup):
            return harness.fail_result("formal character setup drifted from registry matchup for %s" % character_id)
    if sample_factory.formal_character_ids() != expected_ids:
        return harness.fail_result("formal_character_ids should preserve registry file order")
    return harness.pass_result()

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
