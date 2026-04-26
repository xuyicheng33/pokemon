extends RefCounted
class_name PlayerContentLexicon

# 玩家前端中文内容索引器
# 启动期一次性扫描 content/**/*.tres，建立 O(1) 查询索引。
# 所有查询都 fail-fast：缺 id 直接 push_error，不做静默降级。

const CONTENT_ROOT := "res://content"
const SUPPORTED_EXTENSION := "tres"

# 18 属性 id → 中文 fallback（display_name 缺失时兜底）
const COMBAT_TYPE_NAME_FALLBACK := {
	"fire": "火",
	"water": "水",
	"wood": "木",
	"earth": "土",
	"wind": "风",
	"thunder": "雷",
	"ice": "冰",
	"steel": "钢",
	"light": "光",
	"dark": "暗",
	"space": "空间",
	"psychic": "超能力",
	"spirit": "灵",
	"demon": "恶魔",
	"holy": "圣",
	"fighting": "格斗",
	"dragon": "龙",
	"poison": "毒",
}

# 18 属性 id → 颜色映射（每属性独立色）
const COMBAT_TYPE_COLOR_MAP := {
	"fire": Color(0.86, 0.22, 0.18),       # 红
	"water": Color(0.20, 0.45, 0.85),      # 蓝
	"grass": Color(0.30, 0.70, 0.30),      # 绿（保留兼容）
	"wood": Color(0.30, 0.70, 0.30),       # 绿（与 grass 同义，对应"木"）
	"electric": Color(0.95, 0.85, 0.20),   # 黄（保留兼容）
	"thunder": Color(0.95, 0.85, 0.20),    # 黄（与 electric 同义，对应"雷"）
	"ice": Color(0.55, 0.85, 0.95),        # 浅蓝
	"fighting": Color(0.65, 0.18, 0.20),   # 暗红
	"poison": Color(0.62, 0.30, 0.78),     # 紫
	"ground": Color(0.85, 0.75, 0.45),     # 沙黄（保留兼容）
	"earth": Color(0.85, 0.75, 0.45),      # 沙黄（与 ground 同义，对应"土"）
	"flying": Color(0.78, 0.70, 0.95),     # 浅紫（保留兼容）
	"wind": Color(0.78, 0.70, 0.95),       # 浅紫（与 flying 同义，对应"风"）
	"psychic": Color(0.95, 0.55, 0.75),    # 粉
	"bug": Color(0.70, 0.78, 0.20),        # 黄绿
	"rock": Color(0.65, 0.45, 0.30),       # 棕
	"ghost": Color(0.40, 0.25, 0.55),      # 深紫
	"spirit": Color(0.40, 0.25, 0.55),     # 深紫（与 ghost 同义，对应"灵"）
	"dragon": Color(0.30, 0.30, 0.65),     # 靛蓝
	"dark": Color(0.30, 0.30, 0.32),       # 深灰
	"steel": Color(0.75, 0.75, 0.80),      # 银
	"fairy": Color(0.98, 0.80, 0.88),      # 浅粉
	"normal": Color(0.78, 0.78, 0.72),     # 浅灰
	"space": Color(0.25, 0.20, 0.45),      # 暗紫蓝（空间）
	"demon": Color(0.55, 0.10, 0.30),      # 暗红紫（恶魔）
	"holy": Color(0.98, 0.95, 0.70),       # 金白（圣）
	"light": Color(0.98, 0.92, 0.55),      # 浅金（光）
}

const NEUTRAL_COLOR := Color(0.6, 0.6, 0.6)

# 4 个正式角色 id → 中文 fallback
const CHARACTER_NAME_FALLBACK := {
	"gojo_satoru": "五条悟",
	"sukuna": "宿傩",
	"kashimo_hajime": "鹿紫云一",
	"obito_juubi_jinchuriki": "宇智波带土·十尾人柱力",
}

var skills: Dictionary = {}
var effects: Dictionary = {}
var fields: Dictionary = {}
var combat_types: Dictionary = {}
var characters: Dictionary = {}
var units: Dictionary = {}

var _loaded: bool = false

func load_all() -> bool:
	skills.clear()
	effects.clear()
	fields.clear()
	combat_types.clear()
	characters.clear()
	units.clear()
	_loaded = false
	var paths: Array[String] = []
	if not _collect_tres_paths_recursive(CONTENT_ROOT, paths):
		push_error("[PlayerContentLexicon] failed to scan content root: %s" % CONTENT_ROOT)
		return false
	for path in paths:
		var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
		if resource == null:
			push_error("[PlayerContentLexicon] failed to load resource: %s" % path)
			return false
		if not _index_resource(resource):
			push_error("[PlayerContentLexicon] failed to index resource: %s" % path)
			return false
	_loaded = true
	return true

func is_loaded() -> bool:
	return _loaded

# --- 整体查询 ---

func skill(skill_id: String) -> Dictionary:
	var entry: Variant = skills.get(skill_id, null)
	if entry == null:
		push_error("[PlayerContentLexicon] unknown skill_id: %s" % skill_id)
		return {}
	return entry

func effect(effect_definition_id: String) -> Dictionary:
	var entry: Variant = effects.get(effect_definition_id, null)
	if entry == null:
		push_error("[PlayerContentLexicon] unknown effect_definition_id: %s" % effect_definition_id)
		return {}
	return entry

func field(field_definition_id: String) -> Dictionary:
	var entry: Variant = fields.get(field_definition_id, null)
	if entry == null:
		push_error("[PlayerContentLexicon] unknown field_definition_id: %s" % field_definition_id)
		return {}
	return entry

func combat_type(type_id: String) -> Dictionary:
	var entry: Variant = combat_types.get(type_id, null)
	if entry == null:
		push_error("[PlayerContentLexicon] unknown combat_type_id: %s" % type_id)
		return {}
	return entry

func character(character_id: String) -> Dictionary:
	var entry: Variant = characters.get(character_id, null)
	if entry == null:
		push_error("[PlayerContentLexicon] unknown character_id: %s" % character_id)
		return {}
	return entry

func unit(unit_class_id: String) -> Dictionary:
	var entry: Variant = units.get(unit_class_id, null)
	if entry == null:
		push_error("[PlayerContentLexicon] unknown unit_class_id: %s" % unit_class_id)
		return {}
	return entry

# --- 字段级查询 ---

func skill_display_name(skill_id: String) -> String:
	var entry := skill(skill_id)
	if entry.is_empty():
		return ""
	return String(entry.get("display_name", ""))

func skill_mp_cost(skill_id: String) -> int:
	var entry := skill(skill_id)
	if entry.is_empty():
		return 0
	return int(entry.get("mp_cost", 0))

func skill_power(skill_id: String) -> int:
	var entry := skill(skill_id)
	if entry.is_empty():
		return 0
	return int(entry.get("power", 0))

func skill_accuracy(skill_id: String) -> int:
	var entry := skill(skill_id)
	if entry.is_empty():
		return 0
	return int(entry.get("accuracy", 0))

func effect_display_name(effect_definition_id: String) -> String:
	var entry := effect(effect_definition_id)
	if entry.is_empty():
		return ""
	return String(entry.get("display_name", ""))

func field_display_name(field_definition_id: String) -> String:
	var entry := field(field_definition_id)
	if entry.is_empty():
		return ""
	return String(entry.get("display_name", ""))

func combat_type_display_name(type_id: String) -> String:
	var entry: Variant = combat_types.get(type_id, null)
	if entry == null:
		push_error("[PlayerContentLexicon] unknown combat_type_id: %s" % type_id)
		return ""
	var display_name := String(entry.get("display_name", ""))
	if display_name.is_empty():
		# fallback：tres 没填 display_name 时按内置中文映射兜底
		return String(COMBAT_TYPE_NAME_FALLBACK.get(type_id, ""))
	return display_name

func combat_type_color(type_id: String) -> Color:
	if not combat_types.has(type_id):
		push_error("[PlayerContentLexicon] unknown combat_type_id: %s" % type_id)
		return NEUTRAL_COLOR
	if COMBAT_TYPE_COLOR_MAP.has(type_id):
		return COMBAT_TYPE_COLOR_MAP[type_id]
	return NEUTRAL_COLOR

# --- 内部：扫描与索引 ---

func _collect_tres_paths_recursive(dir_path: String, out_paths: Array[String]) -> bool:
	var dir_access := DirAccess.open(dir_path)
	if dir_access == null:
		return false
	for raw_subdir in dir_access.get_directories():
		var subdir_name := String(raw_subdir).strip_edges()
		if subdir_name.is_empty() or subdir_name.begins_with("."):
			continue
		var sub_path := "%s/%s" % [dir_path, subdir_name]
		if not _collect_tres_paths_recursive(sub_path, out_paths):
			return false
	for raw_file in dir_access.get_files():
		var file_name := String(raw_file).strip_edges()
		# Godot 导出后 .tres 可能带 .remap 后缀；这里只接受真实 .tres 字面量
		if file_name.get_extension() != SUPPORTED_EXTENSION:
			continue
		out_paths.append("%s/%s" % [dir_path, file_name])
	return true

func _index_resource(resource: Resource) -> bool:
	if resource == null:
		return false
	# 用 script_class 名字判断类型，避免对所有类型逐一硬编码 preload
	var script: Script = resource.get_script() as Script
	var class_label := ""
	if script != null:
		class_label = String(script.get_global_name())
		if class_label.is_empty():
			class_label = String(script.resource_path).get_file().get_basename()
	match class_label:
		"SkillDefinition", "skill_definition":
			return _index_skill(resource)
		"EffectDefinition", "effect_definition":
			return _index_effect(resource)
		"FieldDefinition", "field_definition":
			return _index_field(resource)
		"CombatTypeDefinition", "combat_type_definition":
			return _index_combat_type(resource)
		"UnitDefinition", "unit_definition":
			return _index_unit(resource)
		_:
			# 非目标类型（battle_format / passive_skill / passive_item 等）静默跳过——不阻塞索引
			return true

func _index_skill(resource: Resource) -> bool:
	var skill_id := String(resource.id)
	if skill_id.is_empty():
		return true
	skills[skill_id] = {
		"display_name": String(resource.display_name),
		"description": "",
		"mp_cost": int(resource.mp_cost),
		"power": int(resource.power),
		"accuracy": int(resource.accuracy),
		"combat_type_id": String(resource.combat_type_id),
		"damage_kind": String(resource.damage_kind),
		"priority": int(resource.priority),
		"segment_count": _resolve_segment_count(resource),
	}
	return true

func _resolve_segment_count(skill_resource: Resource) -> int:
	# 没有 damage_segments 时，单段（1）；有则按 repeat_count 累加
	var segments: Array = skill_resource.damage_segments
	if segments.is_empty():
		return 1
	var total := 0
	for segment in segments:
		if segment == null:
			continue
		total += int(segment.repeat_count)
	if total <= 0:
		return 1
	return total

func _index_effect(resource: Resource) -> bool:
	var effect_id := String(resource.id)
	if effect_id.is_empty():
		return true
	effects[effect_id] = {
		"display_name": String(resource.display_name),
		"description": "",
		"default_remaining": int(resource.duration),
		"default_stack_count": int(resource.max_stacks),
	}
	return true

func _index_field(resource: Resource) -> bool:
	var field_id := String(resource.id)
	if field_id.is_empty():
		return true
	fields[field_id] = {
		"display_name": String(resource.display_name),
		"description": "",
		# field 自身没有 duration（由施加它的 effect 决定），这里固定 0；上层若需要应读取施加 effect。
		"default_remaining": 0,
	}
	return true

func _index_combat_type(resource: Resource) -> bool:
	var type_id := String(resource.id)
	if type_id.is_empty():
		return true
	var display_name := String(resource.display_name)
	if display_name.is_empty():
		display_name = String(COMBAT_TYPE_NAME_FALLBACK.get(type_id, ""))
	combat_types[type_id] = {
		"display_name": display_name,
		"description": "",
	}
	return true

func _index_unit(resource: Resource) -> bool:
	var unit_id := String(resource.id)
	if unit_id.is_empty():
		return true
	var display_name := String(resource.display_name)
	if display_name.is_empty():
		display_name = String(CHARACTER_NAME_FALLBACK.get(unit_id, ""))
	# units 与 characters 在当前内容形态下是 1:1 的（每个 unit 即一个角色档）
	units[unit_id] = {
		"display_name": display_name,
		"character_id": unit_id,
	}
	characters[unit_id] = {
		"display_name": display_name,
		"description": "",
	}
	return true
