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
	var payload: Dictionary = event.get("payload", {}) if typeof(event.get("payload", {})) == TYPE_DICTIONARY else {}
	match event_type:
		"action:cast_started":
			var actor_name := _translate_unit(payload.get("actor_public_id", payload.get("actor_id", "")))
			var skill_name := _translate_skill(payload.get("skill_id", ""))
			return "[color=#88f]%s[/color] 使用了 [color=#fc8]%s[/color]" % [actor_name, skill_name]
		"action:hit":
			var damage := int(payload.get("damage", 0))
			var seg_index := int(payload.get("segment_index", 0))
			var seg_total := int(payload.get("segment_total", 0))
			var line := "命中! 造成 [color=#f88]%d[/color] 伤害" % damage
			if seg_total > 1:
				line += "（第 %d/%d 段）" % [seg_index, seg_total]
			return line
		"action:missed":
			return "[color=#888]未命中[/color]"
		"effect:apply_effect":
			var target_name := _translate_unit(payload.get("target_public_id", payload.get("target_id", "")))
			var effect_name := _translate_effect(payload.get("effect_definition_id", ""))
			return "%s 进入状态 [color=#f8f]%s[/color]" % [target_name, effect_name]
		"effect:damage":
			var target_name2 := _translate_unit(payload.get("target_public_id", payload.get("target_id", "")))
			var damage2 := int(payload.get("damage", 0))
			return "[color=#f88]%s 受到 %d 点伤害[/color]" % [target_name2, damage2]
		"state:faint":
			var unit_name := _translate_unit(payload.get("unit_public_id", payload.get("unit_id", "")))
			return "[color=#444]%s 倒下[/color]" % unit_name
		"state:replace":
			var from_name := _translate_unit(payload.get("from_public_id", payload.get("from_id", "")))
			var to_name := _translate_unit(payload.get("to_public_id", payload.get("to_id", "")))
			return "%s 撤回，%s 登场" % [from_name, to_name]
		"system:turn_start", "system:turn_end":
			var n := int(payload.get("turn_index", event.get("turn_index", 0)))
			return "—— 回合 %d ——" % n
		_:
			return "[%s] %s" % [event_type, _payload_summary(payload)]


func _payload_summary(payload: Dictionary) -> String:
	if payload.is_empty():
		return ""
	var keys := payload.keys()
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		parts.append("%s=%s" % [str(key), str(payload[key])])
	return ", ".join(parts)


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
