extends RefCounted
class_name PlayerBattleScreenMatchupSelector

const BattleSandboxLaunchConfigScript := preload("res://src/adapters/battle_sandbox_launch_config.gd")

const DEFAULT_MATCHUP_ID := "gojo_vs_sample"

var _lexicon: PlayerContentLexicon = null

func set_lexicon(lexicon: PlayerContentLexicon) -> void:
	_lexicon = lexicon

func populate_result(matchup_select: OptionButton, session: PlayerBattleSession, preferred_matchup_id: String) -> Dictionary:
	var matchup_options: Array = []
	if matchup_select != null:
		matchup_select.clear()
	if session == null:
		_add_matchup_option(matchup_select, matchup_options, DEFAULT_MATCHUP_ID, DEFAULT_MATCHUP_ID)
		return _result(false, "missing player session", DEFAULT_MATCHUP_ID, matchup_options)
	var available_result: Dictionary = session.available_matchups_result()
	if not bool(available_result.get("ok", false)):
		_add_matchup_option(matchup_select, matchup_options, DEFAULT_MATCHUP_ID, DEFAULT_MATCHUP_ID)
		return _result(
			false,
			String(available_result.get("error_message", "unknown matchup list error")),
			DEFAULT_MATCHUP_ID,
			matchup_options
		)
	var launch_config = BattleSandboxLaunchConfigScript.new()
	var visible_matchups: Array = launch_config.visible_matchup_descriptors(available_result.get("data", []))
	for raw_descriptor in visible_matchups:
		if not (raw_descriptor is Dictionary):
			continue
		var descriptor: Dictionary = raw_descriptor
		var matchup_id := String(descriptor.get("matchup_id", "")).strip_edges()
		if matchup_id.is_empty():
			continue
		_add_matchup_option(matchup_select, matchup_options, matchup_id, _matchup_label(descriptor))
	if matchup_options.is_empty():
		_add_matchup_option(matchup_select, matchup_options, DEFAULT_MATCHUP_ID, DEFAULT_MATCHUP_ID)
	var selected_id := select_option(matchup_select, matchup_options, preferred_matchup_id)
	return _result(true, "", selected_id, matchup_options)

func select_option(matchup_select: OptionButton, matchup_options: Array, matchup_id: String) -> String:
	var normalized_matchup_id := matchup_id.strip_edges()
	var selected_index := 0
	for i in matchup_options.size():
		if String(matchup_options[i]) == normalized_matchup_id:
			selected_index = i
			break
	if matchup_select != null and matchup_select.item_count > selected_index:
		matchup_select.select(selected_index)
	return String(matchup_options[selected_index]) if not matchup_options.is_empty() else DEFAULT_MATCHUP_ID

func current_selected_matchup_id(matchup_select: OptionButton, matchup_options: Array) -> String:
	if matchup_select == null or matchup_select.selected < 0:
		return ""
	var metadata = matchup_select.get_item_metadata(matchup_select.selected)
	if metadata != null:
		return String(metadata).strip_edges()
	if matchup_select.selected < matchup_options.size():
		return String(matchup_options[matchup_select.selected]).strip_edges()
	return ""

func _add_matchup_option(matchup_select: OptionButton, matchup_options: Array, matchup_id: String, label: String) -> void:
	var normalized_matchup_id := matchup_id.strip_edges()
	if normalized_matchup_id.is_empty():
		return
	matchup_options.append(normalized_matchup_id)
	if matchup_select == null:
		return
	matchup_select.add_item(label)
	matchup_select.set_item_metadata(matchup_select.item_count - 1, normalized_matchup_id)

func _matchup_label(descriptor: Dictionary) -> String:
	var matchup_id := String(descriptor.get("matchup_id", "")).strip_edges()
	var p1_units: Array = descriptor.get("p1_units", []) if descriptor.get("p1_units", null) is Array else []
	var p2_units: Array = descriptor.get("p2_units", []) if descriptor.get("p2_units", null) is Array else []
	var p1_name := _unit_display_name(String(p1_units[0])) if not p1_units.is_empty() else "P1"
	var p2_name := _unit_display_name(String(p2_units[0])) if not p2_units.is_empty() else "P2"
	return "%s vs %s · %s" % [p1_name, p2_name, matchup_id]

func _unit_display_name(unit_id: String) -> String:
	var normalized_unit_id := unit_id.strip_edges()
	if normalized_unit_id.is_empty() or _lexicon == null or not _lexicon.units.has(normalized_unit_id):
		return normalized_unit_id
	var entry: Dictionary = _lexicon.unit(normalized_unit_id)
	var display_name := String(entry.get("display_name", "")).strip_edges()
	return display_name if not display_name.is_empty() else normalized_unit_id

func _result(ok: bool, error_message: String, selected_id: String, matchup_options: Array) -> Dictionary:
	return {
		"ok": ok,
		"error_message": error_message,
		"selected_matchup_id": selected_id,
		"matchup_options": matchup_options.duplicate(),
	}
