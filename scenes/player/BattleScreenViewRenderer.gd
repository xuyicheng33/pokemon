extends RefCounted
class_name PlayerBattleScreenViewRenderer

const CN_SMALL: int = 14
const CN_MEDIUM: int = 18

const STAT_STAGE_LABELS := {
	"attack": "攻",
	"defense": "防",
	"sp_attack": "特攻",
	"sp_defense": "特防",
	"speed": "速",
}

var _lexicon: Object = null

func set_lexicon(lexicon: Object) -> void:
	_lexicon = lexicon

func refresh_card(
	side: Dictionary,
	name_label: Label,
	combat_type_row: HBoxContainer,
	hp_bar: ProgressBar,
	hp_label: Label,
	mp_bar: ProgressBar,
	mp_label: Label,
	ultimate_dots: HBoxContainer,
	stat_stages_row: HBoxContainer,
	effects_box: VBoxContainer,
	sprite: ColorRect
) -> void:
	var active: Dictionary = _resolve_active_unit(side)
	var public_id := str(active.get("public_id", ""))
	var definition_id := str(active.get("definition_id", ""))
	var display_name := str(active.get("display_name", "")).strip_edges()
	if display_name == "" and definition_id != "":
		display_name = resolve_unit_display_name_from_lexicon(definition_id)
	if display_name == "":
		display_name = public_id
	name_label.text = display_name if display_name != "" else "（空）"

	clear_children(combat_type_row)
	for ct in active.get("combat_type_ids", []):
		var ct_id := str(ct).strip_edges()
		if ct_id == "":
			continue
		var badge := Label.new()
		badge.text = resolve_combat_type_display_name(ct_id)
		badge.add_theme_font_size_override("font_size", CN_SMALL)
		badge.add_theme_color_override("font_color", resolve_combat_type_color(ct_id))
		combat_type_row.add_child(badge)

	var current_hp := int(active.get("current_hp", 0))
	var max_hp: int = maxi(1, int(active.get("max_hp", 1)))
	hp_bar.max_value = 100.0
	hp_bar.value = clamp(float(current_hp) / float(max_hp) * 100.0, 0.0, 100.0)
	hp_label.text = "%d/%d" % [current_hp, max_hp]

	var current_mp := int(active.get("current_mp", 0))
	var max_mp: int = maxi(1, int(active.get("max_mp", 1)))
	mp_bar.max_value = 100.0
	mp_bar.value = clamp(float(current_mp) / float(max_mp) * 100.0, 0.0, 100.0)
	mp_label.text = "%d/%d" % [current_mp, max_mp]

	var points := int(active.get("ultimate_points", 0))
	var required := int(active.get("ultimate_points_required", 0))
	var cap := int(active.get("ultimate_points_cap", required))
	render_ultimate_dots(ultimate_dots, points, required, cap)

	clear_children(stat_stages_row)
	var stat_stages: Dictionary = active.get("stat_stages", {}) if active.get("stat_stages", null) is Dictionary else {}
	var keys := STAT_STAGE_LABELS.keys()
	for stat_key in keys:
		var stage := int(stat_stages.get(stat_key, 0))
		if stage == 0:
			continue
		var label := Label.new()
		label.text = "%s %s%d" % [STAT_STAGE_LABELS[stat_key], "+" if stage > 0 else "", stage]
		label.add_theme_font_size_override("font_size", CN_SMALL)
		stat_stages_row.add_child(label)

	clear_children(effects_box)
	for raw_effect in active.get("effect_instances", []):
		if not (raw_effect is Dictionary):
			continue
		var effect: Dictionary = raw_effect
		var def_id := str(effect.get("effect_definition_id", "")).strip_edges()
		if def_id == "":
			continue
		var remaining := int(effect.get("remaining", -1))
		var effect_name := resolve_effect_display_name(def_id)
		var line := Label.new()
		if remaining > 0:
			line.text = "%s（剩 %d 回合）" % [effect_name, remaining]
		else:
			line.text = effect_name
		line.add_theme_font_size_override("font_size", CN_SMALL)
		effects_box.add_child(line)

	var primary_type := ""
	var combat_type_ids: Array = active.get("combat_type_ids", [])
	if not combat_type_ids.is_empty():
		primary_type = str(combat_type_ids[0])
	if sprite != null and primary_type != "":
		sprite.color = resolve_combat_type_color(primary_type)

func refresh_bench(bench_row: HBoxContainer, side: Dictionary) -> void:
	clear_children(bench_row)
	var bench_public_ids: Array = side.get("bench_public_ids", []) if side.get("bench_public_ids", null) is Array else []
	for raw_id in bench_public_ids:
		var public_id := str(raw_id)
		var unit: Dictionary = find_unit_by_public_id(side, public_id)
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(140, 56)
		bench_row.add_child(slot)
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)
		slot.add_child(vbox)
		if unit.is_empty():
			var x_label := Label.new()
			x_label.text = "X"
			x_label.add_theme_font_size_override("font_size", CN_MEDIUM)
			vbox.add_child(x_label)
			continue
		var current_hp := int(unit.get("current_hp", 0))
		var max_hp: int = maxi(1, int(unit.get("max_hp", 1)))
		var leave_state := str(unit.get("leave_state", "")).strip_edges().to_lower()
		var fainted := current_hp <= 0 or leave_state.find("fainted") >= 0
		var name_label := Label.new()
		var display_name := str(unit.get("display_name", "")).strip_edges()
		if display_name == "":
			display_name = public_id
		name_label.text = "%s（%s）" % [display_name, public_id] if display_name != public_id else public_id
		name_label.add_theme_font_size_override("font_size", CN_SMALL)
		vbox.add_child(name_label)
		if fainted:
			var x_label2 := Label.new()
			x_label2.text = "X 倒下"
			x_label2.add_theme_font_size_override("font_size", CN_SMALL)
			vbox.add_child(x_label2)
		else:
			var hp_bar := ProgressBar.new()
			hp_bar.max_value = 100.0
			hp_bar.value = clamp(float(current_hp) / float(max_hp) * 100.0, 0.0, 100.0)
			hp_bar.show_percentage = false
			hp_bar.custom_minimum_size = Vector2(120, 8)
			vbox.add_child(hp_bar)
			var hp_label := Label.new()
			hp_label.text = "%d/%d" % [current_hp, max_hp]
			hp_label.add_theme_font_size_override("font_size", CN_SMALL)
			vbox.add_child(hp_label)

func render_ultimate_dots(container: HBoxContainer, points: int, required: int, cap: int) -> void:
	clear_children(container)
	var total: int = maxi(cap, maxi(required, 1))
	for i in total:
		if required > 0 and i == required:
			var sep := VSeparator.new()
			container.add_child(sep)
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(12, 12)
		dot.color = Color(0.95, 0.85, 0.25) if i < points else Color(0.25, 0.25, 0.30)
		container.add_child(dot)

func clear_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		child.queue_free()

func find_unit_by_public_id(side: Dictionary, public_id: String) -> Dictionary:
	if public_id == "" or side.is_empty():
		return {}
	for raw_unit in side.get("team_units", []):
		if raw_unit is Dictionary and str(raw_unit.get("public_id", "")) == public_id:
			return raw_unit
	return {}

func resolve_unit_display_name_from_lexicon(definition_id: String) -> String:
	if _lexicon == null or definition_id == "":
		return ""
	var entry: Dictionary = _lexicon.unit(definition_id)
	if entry.is_empty():
		return ""
	return String(entry.get("display_name", ""))

func resolve_skill_display_name(skill_id: String) -> String:
	if _lexicon == null:
		return skill_id
	var skill_name: String = _lexicon.skill_display_name(skill_id)
	if skill_name != "":
		return skill_name
	return skill_id

func resolve_skill_mp_cost(skill_id: String) -> int:
	if _lexicon == null:
		return 0
	return _lexicon.skill_mp_cost(skill_id)

func resolve_effect_display_name(def_id: String) -> String:
	if _lexicon == null:
		return def_id
	var effect_name: String = _lexicon.effect_display_name(def_id)
	if effect_name != "":
		return effect_name
	return def_id

func resolve_field_display_name(field_id: String) -> String:
	if field_id == "":
		return "无"
	if _lexicon == null:
		return field_id
	var field_name: String = _lexicon.field_display_name(field_id)
	if field_name != "":
		return field_name
	return field_id

func resolve_combat_type_display_name(combat_type_id: String) -> String:
	if combat_type_id == "":
		return ""
	if _lexicon == null:
		return combat_type_id
	var combat_type_name: String = _lexicon.combat_type_display_name(combat_type_id)
	if combat_type_name != "":
		return combat_type_name
	return combat_type_id

func resolve_combat_type_color(combat_type_id: String) -> Color:
	if _lexicon == null:
		return _hash_color(combat_type_id)
	if not _lexicon.combat_types.has(combat_type_id):
		return _hash_color(combat_type_id)
	return _lexicon.combat_type_color(combat_type_id)

func _resolve_active_unit(side: Dictionary) -> Dictionary:
	var active_public_id: String = str(side.get("active_public_id", "")).strip_edges()
	if active_public_id == "":
		return {}
	return find_unit_by_public_id(side, active_public_id)

func _hash_color(seed_str: String) -> Color:
	if seed_str == "":
		return Color(0.45, 0.45, 0.50)
	var palette := [
		Color(0.85, 0.30, 0.25),
		Color(0.25, 0.55, 0.85),
		Color(0.40, 0.75, 0.35),
		Color(0.85, 0.70, 0.25),
		Color(0.65, 0.40, 0.85),
		Color(0.35, 0.75, 0.85),
	]
	var idx := absi(seed_str.hash()) % palette.size()
	return palette[idx]
