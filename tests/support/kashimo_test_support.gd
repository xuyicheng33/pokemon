extends "res://tests/support/formal_character_test_support.gd"
class_name KashimoTestSupport

func build_kashimo_setup_result(sample_factory, p1_regular_skill_overrides: Dictionary = {}, p2_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	return build_formal_character_setup_result(sample_factory, "kashimo_hajime", {
		"P1": p1_regular_skill_overrides,
		"P2": p2_regular_skill_overrides,
	})

func build_kashimo_setup(sample_factory, p1_regular_skill_overrides: Dictionary = {}, p2_regular_skill_overrides: Dictionary = {}):
	return _unwrap_setup_result(build_kashimo_setup_result(sample_factory, p1_regular_skill_overrides, p2_regular_skill_overrides))

func build_kashimo_vs_gojo_setup_result(sample_factory, p1_regular_skill_overrides: Dictionary = {}, p2_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	return build_matchup_setup_result(sample_factory, "kashimo_vs_gojo", {
		"P1": p1_regular_skill_overrides,
		"P2": p2_regular_skill_overrides,
	})

func build_kashimo_vs_gojo_setup(sample_factory, p1_regular_skill_overrides: Dictionary = {}, p2_regular_skill_overrides: Dictionary = {}):
	return _unwrap_setup_result(build_kashimo_vs_gojo_setup_result(sample_factory, p1_regular_skill_overrides, p2_regular_skill_overrides))

func run_gojo_domain_accuracy_case(harness, sample_factory, use_kyokyo: bool, seed: int) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return {"ok": false, "error": str(core_payload["error"])}
	var core = core_payload["core"]
	var p1_overrides := {0: PackedStringArray(["kashimo_raiken", "kashimo_charge", "kashimo_kyokyo_katsura"])} if use_kyokyo else {}
	var battle_setup = build_kashimo_vs_gojo_setup(sample_factory, p1_overrides)
	var content_index = harness.build_loaded_content_index_for_setup(sample_factory, battle_setup)
	var gojo_ao = content_index.skills.get("gojo_ao", null)
	if gojo_ao == null:
		return {"ok": false, "error": "missing gojo_ao for kashimo real domain accuracy case"}
	gojo_ao.accuracy = 0
	var battle_state = build_battle_state(
		core,
		content_index,
		battle_setup,
		seed
	)
	var kashimo = battle_state.get_side("P1").get_active_unit()
	var gojo = battle_state.get_side("P2").get_active_unit()
	if kashimo == null or gojo == null:
		return {"ok": false, "error": "missing active units for kashimo real gojo domain case"}
	gojo.current_mp = gojo.max_mp
	gojo.ultimate_points = gojo.ultimate_points_cap
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		build_manual_wait_command(core, 1, "P1", "P1-A"),
		build_manual_ultimate_command(core, 1, "P2", "P2-A", "gojo_unlimited_void"),
	])
	if battle_state.field_state == null or battle_state.field_state.field_def_id != "gojo_unlimited_void_field":
		return {"ok": false, "error": "gojo domain should be active before kashimo real domain accuracy case"}
	var hp_before: int = kashimo.current_hp
	core.service("battle_logger").reset()
	var p1_command = build_manual_skill_command(core, 2, "P1", "P1-A", "kashimo_kyokyo_katsura") if use_kyokyo else build_manual_wait_command(core, 2, "P1", "P1-A")
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		p1_command,
		build_manual_skill_command(core, 2, "P2", "P2-A", "gojo_ao"),
	])
	return {
		"ok": true,
		"damage": hp_before - kashimo.current_hp,
		"nullify_active": has_rule_mod(kashimo, "nullify_field_accuracy"),
		"field_id": String(battle_state.field_state.field_def_id) if battle_state.field_state != null else null,
		"log_size": core.service("battle_logger").event_log.size(),
	}

func calc_expected_fixed_effect_damage(core, content_index, effect_id: String, target_unit) -> int:
	var effect_definition = content_index.effects.get(effect_id, null)
	if effect_definition == null or effect_definition.payloads.is_empty():
		return -1
	var payload = effect_definition.payloads[0]
	var type_effectiveness := 1.0
	if not String(payload.combat_type_id).is_empty():
		type_effectiveness = core.service("combat_type_service").calc_effectiveness(String(payload.combat_type_id), target_unit.combat_type_ids)
	return core.service("damage_service").apply_final_mod(max(1, int(payload.amount)), type_effectiveness)

func collect_trigger_damage_deltas(event_log: Array, target_instance_id: String, trigger_name: String) -> Array[int]:
	var deltas: Array[int] = []
	for event in event_log:
		if event.event_type != EventTypesScript.EFFECT_DAMAGE:
			continue
		if String(event.target_instance_id) != target_instance_id:
			continue
		if String(event.trigger_name) != trigger_name:
			continue
		if event.value_changes.is_empty():
			continue
		deltas.append(abs(int(event.value_changes[0].delta)))
	return deltas

func has_rule_mod(unit_state, mod_kind: String, value: Variant = null) -> bool:
	for rule_mod_instance in unit_state.rule_mod_instances:
		if String(rule_mod_instance.mod_kind) != mod_kind:
			continue
		if value != null and String(rule_mod_instance.value) != String(value):
			continue
		return true
	return false
