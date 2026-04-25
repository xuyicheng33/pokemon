extends RefCounted
class_name SandboxViewCharacterCardsRenderer

const BattleSandboxLaunchConfigScript := preload("res://src/adapters/battle_sandbox_launch_config.gd")
const FormalCharacterManifestScript := preload("res://src/shared/formal_character_manifest.gd")
const PaletteScript := preload("res://src/adapters/sandbox_view_palette.gd")

var _launch_config_helper = BattleSandboxLaunchConfigScript.new()
var _manifest = FormalCharacterManifestScript.new()

func render(controller, state: SandboxSessionState, view_refs: SandboxViewRefs) -> void:
	_clear_container_children(view_refs.character_cards)
	var options := _character_options(state.available_matchups, state)
	if options.is_empty():
		var message := state.error_message.strip_edges()
		if message.is_empty():
			message = "当前没有可选角色"
		_add_select_state_card(view_refs.character_cards, message)
		return
	for option in options:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(210, 260)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", PaletteScript.make_stylebox(PaletteScript.COLOR_CARD))
		view_refs.character_cards.add_child(card)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 8)
		card.add_child(content)
		var portrait := PanelContainer.new()
		portrait.custom_minimum_size = Vector2(0, 96)
		portrait.add_theme_stylebox_override("panel", PaletteScript.make_stylebox(option.get("color", PaletteScript.COLOR_ACCENT)))
		content.add_child(portrait)
		var portrait_path := String(option.get("portrait_path", "")).strip_edges()
		var portrait_texture = load(portrait_path) if not portrait_path.is_empty() else null
		if portrait_texture is Texture2D:
			var texture_rect := TextureRect.new()
			texture_rect.texture = portrait_texture
			texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			texture_rect.custom_minimum_size = Vector2(0, 96)
			portrait.add_child(texture_rect)
		else:
			var sigil := Label.new()
			sigil.text = str(option.get("sigil", ""))
			sigil.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sigil.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			sigil.add_theme_font_size_override("font_size", 42)
			sigil.add_theme_color_override("font_color", Color(0.06, 0.06, 0.07))
			portrait.add_child(sigil)
		var name_label := _new_card_label(str(option.get("display_name", "")), 18, PaletteScript.COLOR_TEXT)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(name_label)
		var matchup_id := str(option.get("formal_setup_matchup_id", "")).strip_edges()
		var matchup_label := _new_card_label(matchup_id, 12, PaletteScript.COLOR_ACCENT)
		matchup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		matchup_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(matchup_label)
		var start_button := Button.new()
		start_button.text = "进入战斗"
		start_button.custom_minimum_size = Vector2(0, 36)
		start_button.add_theme_stylebox_override("normal", PaletteScript.make_stylebox(PaletteScript.COLOR_CARD_HOVER))
		start_button.add_theme_stylebox_override("hover", PaletteScript.make_stylebox(PaletteScript.COLOR_BUTTON_PRESSED))
		start_button.add_theme_color_override("font_color", PaletteScript.COLOR_TEXT)
		start_button.pressed.connect(func() -> void:
			controller.start_player_matchup(matchup_id)
		)
		content.add_child(start_button)

func _add_select_state_card(container: Node, message: String) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(280, 160)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", PaletteScript.make_stylebox(PaletteScript.COLOR_CARD))
	container.add_child(card)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 10)
	card.add_child(content)
	var title := _new_card_label("无法进入角色选择", 18, PaletteScript.COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var details := _new_card_label(message, 13, PaletteScript.COLOR_MUTED)
	details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(details)

func _character_options(available_matchups: Array, state: SandboxSessionState) -> Array:
	var available_ids := _available_matchup_ids(available_matchups)
	var entries_result: Dictionary = _manifest.build_character_entries_result()
	if not bool(entries_result.get("ok", false)):
		var manifest_error := String(entries_result.get("error_message", "")).strip_edges()
		if not manifest_error.is_empty() and state.error_message.strip_edges().is_empty():
			state.error_message = "Battle sandbox failed to load formal character manifest: %s" % manifest_error
		return []
	var options: Array = []
	var seen_matchup_ids: Dictionary = {}
	var color_index := 0
	for raw_entry in entries_result.get("data", []):
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		var matchup_id := String(entry.get("formal_setup_matchup_id", "")).strip_edges()
		if matchup_id.is_empty() or seen_matchup_ids.has(matchup_id) or not available_ids.has(matchup_id):
			continue
		seen_matchup_ids[matchup_id] = true
		var character_id := String(entry.get("character_id", "")).strip_edges()
		var pair_token := String(entry.get("pair_token", "")).strip_edges()
		options.append({
			"character_id": character_id,
			"pair_token": pair_token,
			"display_name": String(entry.get("display_name", character_id)).strip_edges(),
			"formal_setup_matchup_id": matchup_id,
			"sigil": _default_sigil(entry, options.size()),
			"portrait_path": _portrait_path(character_id, pair_token),
			"color": PaletteScript.DEFAULT_CARD_COLORS[color_index % PaletteScript.DEFAULT_CARD_COLORS.size()],
		})
		color_index += 1
	return options

func _portrait_path(character_id: String, pair_token: String) -> String:
	for raw_token in [pair_token, character_id]:
		var token := String(raw_token).strip_edges()
		if token.is_empty():
			continue
		var path := "res://assets/ui/portraits/%s.svg" % token
		if ResourceLoader.exists(path):
			return path
	return ""

func _default_sigil(entry: Dictionary, index: int) -> String:
	var display_name := String(entry.get("display_name", "")).strip_edges()
	if not display_name.is_empty():
		return display_name.substr(0, 1)
	var pair_token := String(entry.get("pair_token", "")).strip_edges()
	if not pair_token.is_empty():
		return pair_token.substr(0, 1).to_upper()
	return str(index + 1)

func _available_matchup_ids(available_matchups: Array) -> Dictionary:
	var ids := {}
	for raw_descriptor in _launch_config_helper.visible_matchup_descriptors(available_matchups):
		if not (raw_descriptor is Dictionary):
			continue
		var matchup_id := str(raw_descriptor.get("matchup_id", "")).strip_edges()
		if not matchup_id.is_empty():
			ids[matchup_id] = true
	return ids

func _new_card_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _clear_container_children(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()
