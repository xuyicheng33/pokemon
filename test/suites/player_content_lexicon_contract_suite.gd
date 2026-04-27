extends "res://tests/support/gdunit_suite_bridge.gd"

## PlayerContentLexicon 公开 API 契约：守住 6 张索引 dict、display_name 命名、
## 18 项 combat_type 调色板、中文 fallback、unknown id push_error fail-fast。
##
## Batch G 加入 quick gate；防止 BattleScreen.gd / LogText.gd 与 lexicon 二者契约
## 再次出现 Batch D 那种 "translate_*_id vs *_display_name" 的命名漂移。

const PlayerContentLexiconScript := preload("res://src/adapters/player/player_content_lexicon.gd")


func test_player_content_lexicon_load_all_succeeds() -> void:
	var lexicon = PlayerContentLexiconScript.new()
	if not lexicon.load_all():
		fail("PlayerContentLexicon.load_all should succeed against res://content/")
		return
	if not lexicon.is_loaded():
		fail("PlayerContentLexicon.is_loaded should be true after load_all")
		return
	# 6 张 dict 必须都有内容（avoid 静默空索引）
	for label in ["skills", "effects", "combat_types", "units"]:
		var bag: Dictionary = lexicon.get(label)
		if bag.is_empty():
			fail("PlayerContentLexicon.%s should not be empty after load" % label)
			return


func test_player_content_lexicon_display_name_helpers_present() -> void:
	# 防止 Batch D 那种"translate_skill_id 不存在"的命名漂移：
	# 必须暴露 *_display_name 而不是 translate_*_id。
	var lexicon = PlayerContentLexiconScript.new()
	for method_name in ["skill_display_name", "effect_display_name", "field_display_name", "combat_type_display_name", "combat_type_color"]:
		if not lexicon.has_method(method_name):
			fail("PlayerContentLexicon should expose method %s" % method_name)
			return


func test_player_content_lexicon_combat_type_color_palette_covers_18_types() -> void:
	# Batch D-Lex 决策：18 属性 id 必须有独立色，缺一不可（玩家 UI badge 颜色一致性）。
	var palette: Dictionary = PlayerContentLexiconScript.COMBAT_TYPE_COLOR_MAP
	var expected_18 := [
		"fire", "water", "wood", "earth", "wind", "thunder",
		"ice", "steel", "light", "dark", "space", "psychic",
		"spirit", "demon", "holy", "fighting", "dragon", "poison",
	]
	for type_id in expected_18:
		if not palette.has(type_id):
			fail("COMBAT_TYPE_COLOR_MAP must cover combat_type=%s" % type_id)
			return


func test_player_content_lexicon_combat_type_chinese_fallback() -> void:
	# Batch D-Lex 决策：display_name 缺失时按 COMBAT_TYPE_NAME_FALLBACK 兜底中文。
	var fallback: Dictionary = PlayerContentLexiconScript.COMBAT_TYPE_NAME_FALLBACK
	if String(fallback.get("fire", "")) != "火":
		fail("COMBAT_TYPE_NAME_FALLBACK should map fire -> 火")
		return
	if String(fallback.get("thunder", "")) != "雷":
		fail("COMBAT_TYPE_NAME_FALLBACK should map thunder -> 雷")
		return
	if String(fallback.get("space", "")) != "空间":
		fail("COMBAT_TYPE_NAME_FALLBACK should map space -> 空间")
		return


func test_player_content_lexicon_skill_display_name_returns_chinese_for_known_skill() -> void:
	var lexicon = PlayerContentLexiconScript.new()
	if not lexicon.load_all():
		fail("PlayerContentLexicon.load_all failed")
		return
	# 任取一个角色技能（五条赤），断言 display_name 非空（具体中文不锁，允许后续改名）。
	if not lexicon.skills.has("gojo_aka"):
		fail("lexicon.skills should index gojo_aka after load_all")
		return
	var skill_name: String = String(lexicon.skill_display_name("gojo_aka"))
	if skill_name == "":
		fail("skill_display_name(gojo_aka) should not be empty")
		return
