extends RichTextLabel
class_name PlayerLogText

## 把 BattleCoreManager.get_event_log_snapshot() 的 events 增量翻译成中文 BBCode 行。
##
## 用法：
##   log_text.set_lexicon(player_content_lexicon)  # 可选
##   for event in public_snapshot.events:
##       log_text.append_event(event)
##
## bbcode_enabled / scroll_following 在 _ready() 强制设为 true。

var _lexicon: Object = null


func _ready() -> void:
	bbcode_enabled = true
	scroll_following = true
	fit_content = true
	selection_enabled = true


## 注入 PlayerContentLexicon（可选）。null 时直接显示原 id。
func set_lexicon(lexicon: Object) -> void:
	_lexicon = lexicon


func clear_log() -> void:
	clear()


func append_event(event: Dictionary) -> void:
	var line := _format_event(event)
	if line == "":
		return
	append_text(line + "\n")


func _format_event(event: Dictionary) -> String:
	var event_type := str(event.get("event_type", ""))
	var actor_name := _translate_unit(event.get("actor_public_id", event.get("actor_definition_id", "")))
	var target_name := _translate_unit(event.get("target_public_id", event.get("target_definition_id", "")))
	match event_type:
		"action:cast":
			var command_name := _translate_command_type(event.get("command_type", ""))
			return "[color=#88f]%s[/color] 使用了 [color=#fc8]%s[/color]" % [actor_name, command_name]
		"action:hit":
			var line := "[color=#8f8]命中[/color]"
			if target_name != "未知单位":
				line += " %s" % target_name
			return line
		"action:miss":
			if target_name == "未知单位":
				return "[color=#888]%s 未命中[/color]" % actor_name
			return "[color=#888]%s 攻击 %s 未命中[/color]" % [actor_name, target_name]
		"effect:apply_effect":
			var effect_name := _translate_effect(_extract_effect_id(event))
			return "%s 进入状态 [color=#f8f]%s[/color]" % [target_name, effect_name]
		"effect:damage":
			var damage := _first_value_delta_abs(event, "hp")
			return "[color=#f88]%s 受到 %d 点伤害[/color]" % [target_name, damage]
		"effect:heal":
			var heal := _first_value_delta_abs(event, "hp")
			return "[color=#8f8]%s 回复 %d 点生命[/color]" % [target_name, heal]
		"effect:resource_mod":
			return _format_value_change_line(target_name, event, "资源变化")
		"effect:stat_mod":
			return _format_value_change_line(target_name, event, "能力变化")
		"state:faint":
			var unit_name := target_name
			return "[color=#444]%s 倒下[/color]" % unit_name
		"state:replace":
			return "%s 登场" % target_name
		"state:switch":
			return "%s 撤回，%s 登场" % [actor_name, target_name]
		"state:enter":
			return "%s 登场" % target_name
		"state:exit":
			return "%s 离场" % target_name
		"system:turn_start", "system:turn_end":
			var n := int(event.get("turn_index", 0))
			return "—— 回合 %d ——" % n
		"result:battle_end":
			return "[color=#fc8]战斗结束[/color]"
		_:
			return "[%s] %s" % [event_type, _event_summary(event)]


func _event_summary(event: Dictionary) -> String:
	var summary := str(event.get("payload_summary", "")).strip_edges()
	if summary != "":
		return summary
	var keys := event.keys()
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		var value = event[key]
		if value == null:
			continue
		if value is String and String(value).strip_edges() == "":
			continue
		if value is Array and value.is_empty():
			continue
		if value is Dictionary and value.is_empty():
			continue
		parts.append("%s=%s" % [str(key), str(value)])
	return ", ".join(parts)


func _first_value_delta_abs(event: Dictionary, resource_name: String = "") -> int:
	var changes_value = event.get("value_changes", [])
	if not (changes_value is Array):
		return 0
	for raw_change in changes_value:
		if not (raw_change is Dictionary):
			continue
		var change: Dictionary = raw_change
		if resource_name != "" and str(change.get("resource_name", "")) != resource_name:
			continue
		return absi(int(change.get("delta", 0)))
	return 0


func _format_value_change_line(target_name: String, event: Dictionary, label: String) -> String:
	var changes_value = event.get("value_changes", [])
	if changes_value is Array and not changes_value.is_empty():
		for raw_change in changes_value:
			if not (raw_change is Dictionary):
				continue
			var change: Dictionary = raw_change
			var resource_name := str(change.get("resource_name", "")).strip_edges()
			var delta := int(change.get("delta", 0))
			return "%s %s %s %+d" % [target_name, label, resource_name, delta]
	return "%s %s" % [target_name, _event_summary(event)]


func _extract_effect_id(event: Dictionary) -> String:
	var summary := str(event.get("payload_summary", "")).strip_edges()
	var prefix := "apply effect "
	if summary.begins_with(prefix):
		var rest := summary.substr(prefix.length()).strip_edges()
		var space_pos := rest.find(" ")
		if space_pos >= 0:
			return rest.substr(0, space_pos).strip_edges()
		return rest
	return ""


func _translate_command_type(raw_id: Variant) -> String:
	match str(raw_id).strip_edges():
		"skill":
			return "技能"
		"ultimate":
			return "奥义"
		"switch":
			return "换人"
		"wait":
			return "等待"
		"resource_forced_default":
			return "自动反伤"
		_:
			var id_str := str(raw_id).strip_edges()
			return id_str if id_str != "" else "指令"


func _translate_unit(raw_id: Variant) -> String:
	var id_str := str(raw_id)
	if id_str == "":
		return "未知单位"
	# 先按 unit_class_id（去掉可能的 "#N" 后缀）查 lexicon.units，找到 display_name；
	# 缺失时直接回 public_id 字面量。
	if _lexicon == null:
		return id_str
	var def_id := id_str
	var hash_pos := id_str.find("#")
	if hash_pos >= 0:
		def_id = id_str.substr(0, hash_pos)
	if _lexicon.units.has(def_id):
		var entry: Dictionary = _lexicon.units[def_id]
		var display_name := String(entry.get("display_name", ""))
		if display_name != "":
			return display_name
	return id_str


func _translate_skill(raw_id: Variant) -> String:
	var id_str := str(raw_id)
	if id_str == "":
		return "未知技能"
	if _lexicon == null:
		return id_str
	if not _lexicon.skills.has(id_str):
		return id_str
	var skill_name: String = String(_lexicon.skill_display_name(id_str))
	if skill_name != "":
		return skill_name
	return id_str


func _translate_effect(raw_id: Variant) -> String:
	var id_str := str(raw_id)
	if id_str == "":
		return "未知效果"
	if _lexicon == null:
		return id_str
	if not _lexicon.effects.has(id_str):
		return id_str
	var effect_name: String = String(_lexicon.effect_display_name(id_str))
	if effect_name != "":
		return effect_name
	return id_str
