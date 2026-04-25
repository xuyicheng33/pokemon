extends RefCounted
class_name SandboxPlayerUIBuilder

const COLOR_BG := Color(0.055, 0.067, 0.082)
const COLOR_PANEL := Color(0.105, 0.118, 0.137)
const COLOR_PANEL_SOFT := Color(0.14, 0.153, 0.173)
const COLOR_LINE := Color(0.35, 0.38, 0.42, 0.72)
const COLOR_TEXT := Color(0.91, 0.89, 0.84)
const COLOR_MUTED := Color(0.67, 0.67, 0.62)
const COLOR_ACCENT := Color(0.77, 0.66, 0.43)
const COLOR_DANGER := Color(0.95, 0.35, 0.35)

func build(root: Control) -> void:
	if root.has_node("RootMargin"):
		return
	root.color = COLOR_BG
	var main_margin := _add_margin(root, "RootMargin", 18)
	main_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var main_column := _add_vbox(main_margin, "MainColumn", 12)
	_add_header(main_column)
	_add_select_panel(main_column)
	_add_battle_body(main_column)
	_add_action_panel(main_column)
	_add_result_panel(main_column)

func _add_header(parent: Node) -> void:
	var panel := _add_panel(parent, "HeaderPanel", COLOR_PANEL)
	var content := _add_vbox(panel, "HeaderContent", 6)
	var title := _add_label(content, "TitleLabel", "术式对决", 28, COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var status := _add_label(content, "StatusLabel", "选择一位角色开始战斗", 14, COLOR_MUTED)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var error := _add_label(content, "ErrorLabel", "", 14, COLOR_DANGER)
	error.visible = false
	error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var summary := _add_label(content, "BattleSummaryLabel", "对局摘要: -", 13, COLOR_MUTED)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _add_select_panel(parent: Node) -> void:
	var panel := _add_panel(parent, "SelectPanel", COLOR_PANEL)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var content := _add_vbox(panel, "SelectContent", 12)
	var title := _add_label(content, "SelectTitleLabel", "选择出战角色", 22, COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle := _add_label(content, "SelectSubtitleLabel", "P1 manual / P2 policy", 13, COLOR_MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var scroll := ScrollContainer.new()
	scroll.name = "CharacterScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	var cards := GridContainer.new()
	cards.name = "CharacterCards"
	cards.columns = 4
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("h_separation", 12)
	cards.add_theme_constant_override("v_separation", 12)
	scroll.add_child(cards)

func _add_battle_body(parent: Node) -> void:
	var body_row := HBoxContainer.new()
	body_row.name = "BodyRow"
	body_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_row.add_theme_constant_override("separation", 12)
	parent.add_child(body_row)
	_add_side_panel(body_row, "P1Panel", "P1", "P1Content", "P1Summary")
	_add_event_panel(body_row)
	_add_side_panel(body_row, "P2Panel", "P2", "P2Content", "P2Summary")

func _add_result_panel(parent: Node) -> void:
	var panel := _add_panel(parent, "ResultPanel", COLOR_PANEL)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var content := _add_vbox(panel, "ResultContent", 12)
	var title := _add_label(content, "ResultTitleLabel", "战斗结算", 26, COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var summary := RichTextLabel.new()
	summary.name = "ResultSummary"
	summary.bbcode_enabled = false
	summary.fit_content = true
	summary.scroll_active = false
	summary.selection_enabled = true
	summary.add_theme_color_override("default_color", COLOR_TEXT)
	content.add_child(summary)
	var buttons := HBoxContainer.new()
	buttons.name = "ResultButtons"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	content.add_child(buttons)
	var restart := _add_button(buttons, "ResultRestartButton", "再来一局")
	restart.custom_minimum_size = Vector2(150, 38)
	var select := _add_button(buttons, "ReturnSelectButton", "返回选择")
	select.custom_minimum_size = Vector2(150, 38)

func _add_side_panel(parent: Node, panel_name: String, title_text: String, content_name: String, summary_name: String) -> void:
	var panel := _add_panel(parent, panel_name, COLOR_PANEL)
	panel.custom_minimum_size = Vector2(240, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var content := _add_vbox(panel, content_name, 8)
	var title := _add_label(content, "%sHeaderLabel" % title_text, title_text, 18, COLOR_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var summary := RichTextLabel.new()
	summary.name = summary_name
	summary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary.bbcode_enabled = false
	summary.scroll_active = true
	summary.selection_enabled = true
	summary.add_theme_color_override("default_color", COLOR_TEXT)
	summary.add_theme_font_size_override("normal_font_size", 14)
	content.add_child(summary)

func _add_event_panel(parent: Node) -> void:
	var panel := _add_panel(parent, "EventPanel", COLOR_PANEL_SOFT)
	panel.custom_minimum_size = Vector2(320, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.25
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var content := _add_vbox(panel, "EventContent", 8)
	var header := _add_label(content, "EventHeaderLabel", "战况记录", 18, COLOR_ACCENT)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var log_text := RichTextLabel.new()
	log_text.name = "EventLogText"
	log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_text.scroll_active = true
	log_text.selection_enabled = true
	log_text.add_theme_color_override("default_color", COLOR_TEXT)
	log_text.add_theme_font_size_override("normal_font_size", 13)
	content.add_child(log_text)

func _add_action_panel(parent: Node) -> void:
	var panel := _add_panel(parent, "ActionPanel", COLOR_PANEL)
	var content := _add_vbox(panel, "ActionContent", 8)
	_add_config_panel(content)
	_add_label(content, "ActionHeaderLabel", "等待场景初始化", 16, COLOR_TEXT)
	var pending := _add_label(content, "PendingLabel", "待提交指令: -", 13, COLOR_MUTED)
	pending.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add_flowbox(content, "PrimaryButtons", 8)
	var switch_label := _add_label(content, "SwitchLabel", "换人目标", 14, COLOR_ACCENT)
	switch_label.visible = false
	_add_flowbox(content, "SwitchButtons", 8)
	_add_flowbox(content, "UtilityButtons", 8)
	var controls := _add_hbox(content, "ControlButtons", 8)
	_add_button(controls, "RestartButton", "重开当前对局")
	var replay := _add_hbox(controls, "ReplayControls", 8)
	replay.visible = false
	_add_button(replay, "ReplayPrevButton", "上一回合")
	_add_label(replay, "ReplayTurnLabel", "回合 -", 13, COLOR_MUTED)
	_add_button(replay, "ReplayNextButton", "下一回合")

func _add_config_panel(parent: Node) -> void:
	var panel := _add_panel(parent, "ConfigPanel", COLOR_PANEL_SOFT)
	var content := _add_vbox(panel, "ConfigContent", 6)
	var grid := GridContainer.new()
	grid.name = "ConfigGrid"
	grid.columns = 8
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	content.add_child(grid)
	_add_label(grid, "MatchupKeyLabel", "matchup", 12, COLOR_MUTED)
	grid.add_child(_new_option_button("MatchupSelect"))
	_add_label(grid, "BattleSeedKeyLabel", "seed", 12, COLOR_MUTED)
	var seed_input := LineEdit.new()
	seed_input.name = "BattleSeedInput"
	seed_input.placeholder_text = "9101"
	seed_input.custom_minimum_size = Vector2(90, 0)
	grid.add_child(seed_input)
	_add_label(grid, "P1ModeKeyLabel", "P1", 12, COLOR_MUTED)
	grid.add_child(_new_option_button("P1ModeSelect"))
	_add_label(grid, "P2ModeKeyLabel", "P2", 12, COLOR_MUTED)
	grid.add_child(_new_option_button("P2ModeSelect"))
	var status := _add_label(content, "ConfigStatusLabel", "当前配置: -", 12, COLOR_MUTED)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _add_margin(parent: Node, node_name: String, margin: int) -> MarginContainer:
	var node := MarginContainer.new()
	node.name = node_name
	node.add_theme_constant_override("margin_left", margin)
	node.add_theme_constant_override("margin_top", margin)
	node.add_theme_constant_override("margin_right", margin)
	node.add_theme_constant_override("margin_bottom", margin)
	parent.add_child(node)
	return node

func _add_panel(parent: Node, node_name: String, color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.add_theme_stylebox_override("panel", _stylebox(color))
	parent.add_child(panel)
	return panel

func _add_vbox(parent: Node, node_name: String, separation: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = node_name
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", separation)
	parent.add_child(box)
	return box

func _add_hbox(parent: Node, node_name: String, separation: int) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.name = node_name
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", separation)
	parent.add_child(box)
	return box

func _add_flowbox(parent: Node, node_name: String, separation: int) -> HFlowContainer:
	var box := HFlowContainer.new()
	box.name = node_name
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("h_separation", separation)
	box.add_theme_constant_override("v_separation", separation)
	parent.add_child(box)
	return box

func _add_label(parent: Node, node_name: String, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _add_button(parent: Node, node_name: String, text: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.add_theme_stylebox_override("normal", _stylebox(COLOR_PANEL_SOFT))
	button.add_theme_stylebox_override("hover", _stylebox(Color(0.18, 0.195, 0.22)))
	button.add_theme_stylebox_override("pressed", _stylebox(Color(0.22, 0.195, 0.14)))
	button.add_theme_color_override("font_color", COLOR_TEXT)
	parent.add_child(button)
	return button

func _new_option_button(node_name: String) -> OptionButton:
	var button := OptionButton.new()
	button.name = node_name
	button.custom_minimum_size = Vector2(120, 0)
	return button

func _stylebox(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = COLOR_LINE
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.corner_radius_top_left = 8
	box.corner_radius_top_right = 8
	box.corner_radius_bottom_left = 8
	box.corner_radius_bottom_right = 8
	box.content_margin_left = 12
	box.content_margin_top = 10
	box.content_margin_right = 12
	box.content_margin_bottom = 10
	return box
