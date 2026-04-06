extends "res://tests/suites/extension_targeting_accuracy/base.gd"
const BaseSuiteScript := preload("res://tests/suites/extension_targeting_accuracy/base.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("effect_refresh_updates_source_metadata_contract", failures, Callable(self, "_test_effect_refresh_updates_source_metadata_contract").bind(harness))

func _test_effect_refresh_updates_source_metadata_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 913)
    var target = battle_state.get_side("P2").get_active_unit()
    if target == null:
        return harness.fail_result("missing target unit for effect refresh metadata contract")

    var refresh_effect = EffectDefinitionScript.new()
    refresh_effect.id = "test_effect_refresh_metadata"
    refresh_effect.display_name = "Effect Refresh Metadata"
    refresh_effect.scope = "self"
    refresh_effect.duration_mode = "turns"
    refresh_effect.duration = 3
    refresh_effect.decrement_on = "turn_end"
    refresh_effect.stacking = "refresh"

    var effect_instance_service = core.service("effect_instance_service")
    var first_meta := EffectSourceMetaHelperScript.build_meta("owner_a", {"tag": "first"})
    var first_instance = effect_instance_service.create_instance(
        refresh_effect,
        target.unit_instance_id,
        battle_state,
        "first_source",
        1,
        80,
        first_meta
    )
    if first_instance == null:
        return harness.fail_result("failed to create first refreshable effect instance")
    first_instance.remaining = 1
    var refreshed_instance = effect_instance_service.create_instance(
        refresh_effect,
        target.unit_instance_id,
        battle_state,
        "second_source",
        2,
        120,
        EffectSourceMetaHelperScript.build_meta("owner_b", {"tag": "second"})
    )
    if refreshed_instance == null:
        return harness.fail_result("failed to refresh effect instance")
    if refreshed_instance != first_instance:
        return harness.fail_result("effect refresh should keep the same runtime instance")
    if effect_instance_service.last_apply_skipped:
        return harness.fail_result("effect refresh should not be marked as skipped")
    if refreshed_instance.remaining != 3:
        return harness.fail_result("effect refresh should reset remaining turns")
    if refreshed_instance.source_instance_id != "second_source" or refreshed_instance.source_kind_order != 2 or refreshed_instance.source_order_speed_snapshot != 120:
        return harness.fail_result("effect refresh should update source identity and order metadata")
    if String(refreshed_instance.meta.get("source_owner_id", "")) != "owner_b" or String(refreshed_instance.meta.get("tag", "")) != "second":
        return harness.fail_result("effect refresh should replace source owner and meta payload")
    return harness.pass_result()
