extends RefCounted
class_name SandboxViewPalette

const COLOR_CARD := Color(0.13, 0.145, 0.168)
const COLOR_CARD_HOVER := Color(0.18, 0.195, 0.22)
const COLOR_BUTTON_PRESSED := Color(0.23, 0.21, 0.16)
const COLOR_LINE := Color(0.38, 0.38, 0.34, 0.75)
const COLOR_TEXT := Color(0.91, 0.89, 0.84)
const COLOR_MUTED := Color(0.67, 0.67, 0.62)
const COLOR_ACCENT := Color(0.77, 0.66, 0.43)
const DEFAULT_CARD_COLORS := [
	Color(0.62, 0.9, 0.96),
	Color(0.9, 0.18, 0.13),
	Color(0.95, 0.82, 0.18),
	Color(0.58, 0.45, 0.9),
	Color(0.45, 0.82, 0.55),
	Color(0.9, 0.58, 0.33),
]

static func make_stylebox(color: Color) -> StyleBoxFlat:
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
	box.content_margin_left = 10
	box.content_margin_top = 8
	box.content_margin_right = 10
	box.content_margin_bottom = 8
	return box
