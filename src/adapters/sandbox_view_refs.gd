extends RefCounted
class_name SandboxViewRefs

var status_label: Label = null
var error_label: Label = null
var battle_summary_label: Label = null
var select_panel: PanelContainer = null
var character_cards: GridContainer = null
var body_row: HBoxContainer = null
var action_panel: PanelContainer = null
var result_panel: PanelContainer = null
var result_summary: RichTextLabel = null
var result_restart_button: Button = null
var return_select_button: Button = null
var p1_summary: RichTextLabel = null
var event_header_label: Label = null
var event_log_text: RichTextLabel = null
var p2_summary: RichTextLabel = null
var config_status_label: Label = null
var matchup_select: OptionButton = null
var battle_seed_input: LineEdit = null
var p1_mode_select: OptionButton = null
var p2_mode_select: OptionButton = null
var action_header_label: Label = null
var pending_label: Label = null
var primary_buttons: HBoxContainer = null
var switch_label: Label = null
var switch_buttons: HBoxContainer = null
var utility_buttons: HBoxContainer = null
var restart_button: Button = null
var replay_controls: HBoxContainer = null
var replay_prev_button: Button = null
var replay_turn_label: Label = null
var replay_next_button: Button = null

func bind(root: Control) -> void:
	status_label = root.get_node("RootMargin/MainColumn/HeaderPanel/HeaderContent/StatusLabel") as Label
	error_label = root.get_node("RootMargin/MainColumn/HeaderPanel/HeaderContent/ErrorLabel") as Label
	battle_summary_label = root.get_node("RootMargin/MainColumn/HeaderPanel/HeaderContent/BattleSummaryLabel") as Label
	select_panel = root.get_node("RootMargin/MainColumn/SelectPanel") as PanelContainer
	character_cards = root.get_node("RootMargin/MainColumn/SelectPanel/SelectContent/CharacterCards") as GridContainer
	body_row = root.get_node("RootMargin/MainColumn/BodyRow") as HBoxContainer
	action_panel = root.get_node("RootMargin/MainColumn/ActionPanel") as PanelContainer
	result_panel = root.get_node("RootMargin/MainColumn/ResultPanel") as PanelContainer
	result_summary = root.get_node("RootMargin/MainColumn/ResultPanel/ResultContent/ResultSummary") as RichTextLabel
	result_restart_button = root.get_node("RootMargin/MainColumn/ResultPanel/ResultContent/ResultButtons/ResultRestartButton") as Button
	return_select_button = root.get_node("RootMargin/MainColumn/ResultPanel/ResultContent/ResultButtons/ReturnSelectButton") as Button
	p1_summary = root.get_node("RootMargin/MainColumn/BodyRow/P1Panel/P1Content/P1Summary") as RichTextLabel
	event_header_label = root.get_node("RootMargin/MainColumn/BodyRow/EventPanel/EventContent/EventHeaderLabel") as Label
	event_log_text = root.get_node("RootMargin/MainColumn/BodyRow/EventPanel/EventContent/EventLogText") as RichTextLabel
	p2_summary = root.get_node("RootMargin/MainColumn/BodyRow/P2Panel/P2Content/P2Summary") as RichTextLabel
	config_status_label = root.get_node("RootMargin/MainColumn/ActionPanel/ActionContent/ConfigPanel/ConfigContent/ConfigStatusLabel") as Label
	matchup_select = root.get_node("RootMargin/MainColumn/ActionPanel/ActionContent/ConfigPanel/ConfigContent/ConfigGrid/MatchupSelect") as OptionButton
	battle_seed_input = root.get_node("RootMargin/MainColumn/ActionPanel/ActionContent/ConfigPanel/ConfigContent/ConfigGrid/BattleSeedInput") as LineEdit
	p1_mode_select = root.get_node("RootMargin/MainColumn/ActionPanel/ActionContent/ConfigPanel/ConfigContent/ConfigGrid/P1ModeSelect") as OptionButton
	p2_mode_select = root.get_node("RootMargin/MainColumn/ActionPanel/ActionContent/ConfigPanel/ConfigContent/ConfigGrid/P2ModeSelect") as OptionButton
	action_header_label = root.get_node("RootMargin/MainColumn/ActionPanel/ActionContent/ActionHeaderLabel") as Label
	pending_label = root.get_node("RootMargin/MainColumn/ActionPanel/ActionContent/PendingLabel") as Label
	primary_buttons = root.get_node("RootMargin/MainColumn/ActionPanel/ActionContent/PrimaryButtons") as HBoxContainer
	switch_label = root.get_node("RootMargin/MainColumn/ActionPanel/ActionContent/SwitchLabel") as Label
	switch_buttons = root.get_node("RootMargin/MainColumn/ActionPanel/ActionContent/SwitchButtons") as HBoxContainer
	utility_buttons = root.get_node("RootMargin/MainColumn/ActionPanel/ActionContent/UtilityButtons") as HBoxContainer
	restart_button = root.get_node("RootMargin/MainColumn/ActionPanel/ActionContent/ControlButtons/RestartButton") as Button
	replay_controls = root.get_node("RootMargin/MainColumn/ActionPanel/ActionContent/ControlButtons/ReplayControls") as HBoxContainer
	replay_prev_button = root.get_node("RootMargin/MainColumn/ActionPanel/ActionContent/ControlButtons/ReplayControls/ReplayPrevButton") as Button
	replay_turn_label = root.get_node("RootMargin/MainColumn/ActionPanel/ActionContent/ControlButtons/ReplayControls/ReplayTurnLabel") as Label
	replay_next_button = root.get_node("RootMargin/MainColumn/ActionPanel/ActionContent/ControlButtons/ReplayControls/ReplayNextButton") as Button

func is_bound() -> bool:
	return status_label != null
