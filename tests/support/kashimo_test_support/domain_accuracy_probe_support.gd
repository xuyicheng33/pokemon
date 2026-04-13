extends RefCounted
class_name KashimoDomainAccuracyProbeSupport

var _seed_cache: Dictionary = {}

@warning_ignore("shadowed_global_identifier")
func run_domain_accuracy_case_for_matchup(
	support,
	harness,
	sample_factory,
	use_kyokyo: bool,
	seed: int,
	matchup_id: String,
	domain_skill_id: String,
	attack_skill_id: String,
	expected_field_id: String,
	config: Dictionary = {}
) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return {"ok": false, "error": str(core_payload["error"])}
	var core = core_payload["core"]
	var protected_side_id := String(config.get("protected_side_id", "P1")).strip_edges()
	var domain_side_id := String(config.get("domain_side_id", "P2")).strip_edges()
	var attack_side_id := String(config.get("attack_side_id", domain_side_id)).strip_edges()
	var override_side_id := String(config.get("override_side_id", protected_side_id)).strip_edges()
	var protected_public_id := String(config.get("protected_public_id", "%s-A" % protected_side_id)).strip_edges()
	var domain_public_id := String(config.get("domain_public_id", "%s-A" % domain_side_id)).strip_edges()
	var attack_public_id := String(config.get("attack_public_id", "%s-A" % attack_side_id)).strip_edges()
	var kyokyo_skill_id := String(config.get("kyokyo_skill_id", "kashimo_kyokyo_katsura")).strip_edges()
	var side_overrides: Dictionary = {}
	if use_kyokyo:
		side_overrides[override_side_id] = {0: PackedStringArray(["kashimo_raiken", "kashimo_charge", kyokyo_skill_id])}
	var battle_setup_result: Dictionary = support.build_matchup_setup_result(sample_factory, matchup_id, side_overrides)
	if not bool(battle_setup_result.get("ok", false)):
		return {"ok": false, "error": "failed to build domain accuracy setup: %s" % String(battle_setup_result.get("error_message", "unknown error"))}
	var battle_setup = battle_setup_result.get("data", null)
	var content_index = harness.build_loaded_content_index_for_setup(sample_factory, battle_setup)
	var battle_state = support.build_battle_state(core, content_index, battle_setup, seed)
	var protected_unit = battle_state.get_side(protected_side_id).get_active_unit()
	var domain_unit = battle_state.get_side(domain_side_id).get_active_unit()
	if protected_unit == null or domain_unit == null:
		return {"ok": false, "error": "missing active units for domain accuracy case"}
	domain_unit.current_mp = domain_unit.max_mp
	domain_unit.ultimate_points = domain_unit.ultimate_points_cap
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		support.build_manual_wait_command(core, 1, protected_side_id, protected_public_id),
		support.build_manual_ultimate_command(core, 1, domain_side_id, domain_public_id, domain_skill_id),
	])
	if battle_state.field_state == null or battle_state.field_state.field_def_id != expected_field_id:
		return {"ok": false, "error": "expected active field %s before domain accuracy probe" % expected_field_id}
	var hp_before: int = protected_unit.current_hp
	core.service("battle_logger").reset()
	var protected_command = support.build_manual_skill_command(core, 2, protected_side_id, protected_public_id, kyokyo_skill_id) if use_kyokyo else support.build_manual_wait_command(core, 2, protected_side_id, protected_public_id)
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		protected_command,
		support.build_manual_skill_command(core, 2, attack_side_id, attack_public_id, attack_skill_id),
	])
	return {
		"ok": true,
		"damage": hp_before - protected_unit.current_hp,
		"nullify_active": support.has_rule_mod(protected_unit, "nullify_field_accuracy"),
		"field_id": String(battle_state.field_state.field_def_id) if battle_state.field_state != null else "",
		"log_size": core.service("battle_logger").event_log.size(),
	}

func find_domain_accuracy_probe_seed_for_matchup(
	support,
	harness,
	sample_factory,
	seed_start: int,
	search_window: int,
	matchup_id: String,
	domain_skill_id: String,
	attack_skill_id: String,
	expected_field_id: String,
	config: Dictionary = {}
) -> Dictionary:
	var cache_key := "%s|%s|%d|%d" % [matchup_id, attack_skill_id, seed_start, search_window]
	if _seed_cache.has(cache_key):
		return {"ok": true, "seed": int(_seed_cache[cache_key])}
	@warning_ignore("shadowed_global_identifier")
	for seed in range(seed_start, seed_start + search_window):
		var protected_result := run_domain_accuracy_case_for_matchup(
			support,
			harness,
			sample_factory,
			true,
			seed,
			matchup_id,
			domain_skill_id,
			attack_skill_id,
			expected_field_id,
			config
		)
		if not bool(protected_result.get("ok", false)):
			return protected_result
		if int(protected_result.get("damage", -1)) != 0 or not bool(protected_result.get("nullify_active", false)):
			continue
		var baseline_result := run_domain_accuracy_case_for_matchup(
			support,
			harness,
			sample_factory,
			false,
			seed,
			matchup_id,
			domain_skill_id,
			attack_skill_id,
			expected_field_id,
			config
		)
		if not bool(baseline_result.get("ok", false)):
			return baseline_result
		if int(baseline_result.get("damage", 0)) <= 0:
			continue
		_seed_cache[cache_key] = seed
		return {"ok": true, "seed": seed}
	return {
		"ok": false,
		"error": "failed to find domain accuracy probe seed for %s/%s in [%d, %d)" % [
			matchup_id,
			attack_skill_id,
			seed_start,
			seed_start + search_window,
		],
	}
