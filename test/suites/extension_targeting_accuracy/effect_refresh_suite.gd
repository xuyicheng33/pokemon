extends "res://test/suites/extension_targeting_accuracy/base.gd"

func test_effect_refresh_updates_source_metadata_contract() -> void:
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
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 913)
	var target = battle_state.get_side("P2").get_active_unit()
	if target == null:
		fail("missing target unit for effect refresh metadata contract")
		return

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
		fail("failed to create first refreshable effect instance")
		return
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
		fail("failed to refresh effect instance")
		return
	if refreshed_instance != first_instance:
		fail("effect refresh should keep the same runtime instance")
		return
	if effect_instance_service.last_apply_skipped:
		fail("effect refresh should not be marked as skipped")
		return
	if refreshed_instance.remaining != 3:
		fail("effect refresh should reset remaining turns")
		return
	if refreshed_instance.source_instance_id != "second_source" or refreshed_instance.source_kind_order != 2 or refreshed_instance.source_order_speed_snapshot != 120:
		fail("effect refresh should update source identity and order metadata")
		return
	if String(refreshed_instance.meta.get("source_owner_id", "")) != "owner_b" or String(refreshed_instance.meta.get("tag", "")) != "second":
		fail("effect refresh should replace source owner and meta payload")
		return
