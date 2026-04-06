extends RefCounted
class_name KashimoDomainAccuracyProbeSupport

var _seed_cache: Dictionary = {}

func run_domain_accuracy_case_for_matchup(
	support,
	harness,
	sample_factory,
	use_kyokyo: bool,
	seed: int,
	matchup_id: String,
	domain_skill_id: String,
	attack_skill_id: String,
	expected_field_id: String
) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return {"ok": false, "error": str(core_payload["error"])}
	var core = core_payload["core"]
	var p1_overrides := {0: PackedStringArray(["kashimo_raiken", "kashimo_charge", "kashimo_kyokyo_katsura"])} if use_kyokyo else {}
	var battle_setup_result: Dictionary = support.build_matchup_setup_result(sample_factory, matchup_id, {"P1": p1_overrides})
	if not bool(battle_setup_result.get("ok", false)):
		return {"ok": false, "error": "failed to build domain accuracy setup: %s" % String(battle_setup_result.get("error_message", "unknown error"))}
	var battle_setup = battle_setup_result.get("data", null)
	var content_index = harness.build_loaded_content_index_for_setup(sample_factory, battle_setup)
	var battle_state = support.build_battle_state(core, content_index, battle_setup, seed)
	var kashimo = battle_state.get_side("P1").get_active_unit()
	var opponent = battle_state.get_side("P2").get_active_unit()
	if kashimo == null or opponent == null:
		return {"ok": false, "error": "missing active units for domain accuracy case"}
	opponent.current_mp = opponent.max_mp
	opponent.ultimate_points = opponent.ultimate_points_cap
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		support.build_manual_wait_command(core, 1, "P1", "P1-A"),
		support.build_manual_ultimate_command(core, 1, "P2", "P2-A", domain_skill_id),
	])
	if battle_state.field_state == null or battle_state.field_state.field_def_id != expected_field_id:
		return {"ok": false, "error": "expected active field %s before domain accuracy probe" % expected_field_id}
	var hp_before: int = kashimo.current_hp
	core.service("battle_logger").reset()
	var p1_command = support.build_manual_skill_command(core, 2, "P1", "P1-A", "kashimo_kyokyo_katsura") if use_kyokyo else support.build_manual_wait_command(core, 2, "P1", "P1-A")
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		p1_command,
		support.build_manual_skill_command(core, 2, "P2", "P2-A", attack_skill_id),
	])
	return {
		"ok": true,
		"damage": hp_before - kashimo.current_hp,
		"nullify_active": support.has_rule_mod(kashimo, "nullify_field_accuracy"),
		"field_id": String(battle_state.field_state.field_def_id) if battle_state.field_state != null else null,
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
	expected_field_id: String
) -> Dictionary:
	var cache_key := "%s|%s|%d|%d" % [matchup_id, attack_skill_id, seed_start, search_window]
	if _seed_cache.has(cache_key):
		return {"ok": true, "seed": int(_seed_cache[cache_key])}
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
			expected_field_id
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
			expected_field_id
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
