extends RefCounted
class_name GojoSukunaProbeSupport

const EventTypesScript := preload("res://src/shared/event_types.gd")

func build_totals() -> Dictionary:
	return {
		"matches": 0,
		"aborted_matches": 0,
		"gojo_wins": 0,
		"sukuna_wins": 0,
		"draws": 0,
		"turn_sum": 0,
		"gojo_ult_chosen": 0,
		"sukuna_ult_chosen": 0,
		"gojo_ult_resolved": 0,
		"sukuna_ult_resolved": 0,
		"gojo_heal_chosen": 0,
		"sukuna_heal_chosen": 0,
		"gojo_heal_resolved": 0,
		"sukuna_heal_resolved": 0,
		"gojo_domain_successes": 0,
		"sukuna_domain_successes": 0,
		"gojo_ult_legal_windows": 0,
		"sukuna_ult_legal_windows": 0,
	}

func build_match_stats() -> Dictionary:
	return {
		"gojo_ult_chosen": 0,
		"sukuna_ult_chosen": 0,
		"gojo_ult_resolved": 0,
		"sukuna_ult_resolved": 0,
		"gojo_heal_chosen": 0,
		"sukuna_heal_chosen": 0,
		"gojo_heal_resolved": 0,
		"sukuna_heal_resolved": 0,
		"gojo_domain_successes": 0,
		"sukuna_domain_successes": 0,
		"gojo_ult_legal_windows": 0,
		"sukuna_ult_legal_windows": 0,
	}

func apply_loadout_mode(side_setup, loadout_mode: String) -> void:
	if loadout_mode != "reverse":
		return
	if side_setup.unit_definition_ids.is_empty():
		return
	var lead_unit_id := String(side_setup.unit_definition_ids[0])
	match lead_unit_id:
		"gojo_satoru":
			side_setup.regular_skill_loadout_overrides[0] = PackedStringArray(["gojo_ao", "gojo_aka", "gojo_reverse_ritual"])
		"sukuna":
			side_setup.regular_skill_loadout_overrides[0] = PackedStringArray(["sukuna_kai", "sukuna_hatsu", "sukuna_reverse_ritual"])

func tally_resolved_turn(event_log: Array, stats: Dictionary) -> void:
	for log_event in event_log:
		if typeof(log_event) != TYPE_DICTIONARY:
			continue
		if String(log_event.get("event_type", "")) == EventTypesScript.ACTION_CAST:
			var actor_def_id := str(log_event.get("actor_definition_id", ""))
			if actor_def_id == "gojo_satoru" and String(log_event.get("command_type", "")) == "ultimate":
				stats.gojo_ult_resolved += 1
			elif actor_def_id == "sukuna" and String(log_event.get("command_type", "")) == "ultimate":
				stats.sukuna_ult_resolved += 1
			continue
		if String(log_event.get("event_type", "")) == EventTypesScript.EFFECT_HEAL:
			var heal_target_def_id := str(log_event.get("target_definition_id", ""))
			if heal_target_def_id == "gojo_satoru":
				stats.gojo_heal_resolved += 1
			elif heal_target_def_id == "sukuna":
				stats.sukuna_heal_resolved += 1
			continue
		if String(log_event.get("event_type", "")) == EventTypesScript.EFFECT_APPLY_FIELD and typeof(log_event.get("field_change", null)) == TYPE_DICTIONARY:
			var applied_field_id := String(log_event.get("field_change", {}).get("after_field_id", ""))
			if applied_field_id == "gojo_unlimited_void_field":
				stats.gojo_domain_successes += 1
			elif applied_field_id == "sukuna_malevolent_shrine_field":
				stats.sukuna_domain_successes += 1

func tally_ultimate_legal_window(snapshot: Dictionary, side_id: String, legal_action_set, stats: Dictionary) -> void:
	if legal_action_set == null or legal_action_set.legal_ultimate_ids.is_empty():
		return
	var actor := find_active_unit(snapshot, side_id)
	var actor_def_id := str(actor.get("definition_id", ""))
	if actor_def_id == "gojo_satoru":
		stats.gojo_ult_legal_windows += 1
	elif actor_def_id == "sukuna":
		stats.sukuna_ult_legal_windows += 1

func tally_choice(snapshot: Dictionary, side_id: String, choice: Dictionary, stats: Dictionary) -> void:
	var actor := find_active_unit(snapshot, side_id)
	var actor_def_id := str(actor.get("definition_id", ""))
	var skill_id := str(choice.get("skill_id", ""))
	if actor_def_id == "gojo_satoru":
		if skill_id == "gojo_unlimited_void":
			stats.gojo_ult_chosen += 1
		elif skill_id == "gojo_reverse_ritual":
			stats.gojo_heal_chosen += 1
	elif actor_def_id == "sukuna":
		if skill_id == "sukuna_fukuma_mizushi":
			stats.sukuna_ult_chosen += 1
		elif skill_id == "sukuna_reverse_ritual":
			stats.sukuna_heal_chosen += 1

func accumulate_totals(totals: Dictionary, match_stats: Dictionary, snapshot: Dictionary, gojo_on_p1: bool) -> void:
	totals.matches += 1
	totals.turn_sum += int(snapshot.get("turn_index", 0))
	for key in match_stats.keys():
		totals[key] += int(match_stats[key])
	var winner_side_id = snapshot.get("battle_result", {}).get("winner_side_id", null)
	if winner_side_id == null:
		totals.draws += 1
	elif (gojo_on_p1 and winner_side_id == "P1") or (not gojo_on_p1 and winner_side_id == "P2"):
		totals.gojo_wins += 1
	else:
		totals.sukuna_wins += 1

func format_summary(policy: String, symmetric_only: bool, loadout_mode: String, totals: Dictionary, completed_matches: int) -> String:
	var avg_turns := float(totals.turn_sum) / float(max(1, completed_matches))
	return "policy=%s setup=%s loadout=%s matches=%d aborted_matches=%d gojo_wins=%d sukuna_wins=%d draws=%d avg_turns=%.2f gojo_ult_chosen=%d sukuna_ult_chosen=%d gojo_ult_resolved=%d sukuna_ult_resolved=%d gojo_ult_legal_windows=%d sukuna_ult_legal_windows=%d gojo_heal_chosen=%d sukuna_heal_chosen=%d gojo_heal_resolved=%d sukuna_heal_resolved=%d gojo_domain_successes=%d sukuna_domain_successes=%d" % [
		policy,
		"symmetric" if symmetric_only else "sample_factory",
		loadout_mode,
		totals.matches,
		totals.aborted_matches,
		totals.gojo_wins,
		totals.sukuna_wins,
		totals.draws,
		avg_turns,
		totals.gojo_ult_chosen,
		totals.sukuna_ult_chosen,
		totals.gojo_ult_resolved,
		totals.sukuna_ult_resolved,
		totals.gojo_ult_legal_windows,
		totals.sukuna_ult_legal_windows,
		totals.gojo_heal_chosen,
		totals.sukuna_heal_chosen,
		totals.gojo_heal_resolved,
		totals.sukuna_heal_resolved,
		totals.gojo_domain_successes,
		totals.sukuna_domain_successes,
	]

func find_side_snapshot(snapshot: Dictionary, side_id: String) -> Dictionary:
	for side_snapshot in snapshot.get("sides", []):
		if str(side_snapshot.get("side_id", "")) == side_id:
			return side_snapshot
	return {}

func find_active_unit(snapshot: Dictionary, side_id: String) -> Dictionary:
	var side_snapshot := find_side_snapshot(snapshot, side_id)
	var active_public_id := str(side_snapshot.get("active_public_id", ""))
	for unit_snapshot in side_snapshot.get("team_units", []):
		if str(unit_snapshot.get("public_id", "")) == active_public_id:
			return unit_snapshot
	return {}
