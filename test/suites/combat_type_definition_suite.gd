extends "res://tests/support/gdunit_suite_bridge.gd"

const CombatTypeChartEntryScript := preload("res://src/battle_core/content/combat_type_chart_entry.gd")
const CombatTypeServiceScript := preload("res://src/battle_core/math/combat_type_service.gd")
const CombatTypeTestHelperScript := preload("res://tests/support/combat_type_test_helper.gd")

var _helper = CombatTypeTestHelperScript.new()


func test_combat_type_content_validation() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return

	var unknown_skill_errors = _validate_with_sample_mutation(_harness, sample_factory, func(content_index):
		content_index.skills["sample_strike"].combat_type_id = "unknown_type"
	)
	if not _errors_contain(unknown_skill_errors, "skill[sample_strike].combat_type_id missing combat type: unknown_type"):
		fail("missing unknown skill combat_type validation")
		return

	var too_many_unit_errors = _validate_with_sample_mutation(_harness, sample_factory, func(content_index):
		content_index.units["sample_pyron"].combat_type_ids = PackedStringArray(["fire", "water", "wood"])
	)
	if not _errors_contain(too_many_unit_errors, "unit[sample_pyron].combat_type_ids must contain at most 2 entries"):
		fail("missing unit max 2 combat types validation")
		return

	var duplicate_unit_errors = _validate_with_sample_mutation(_harness, sample_factory, func(content_index):
		content_index.units["sample_pyron"].combat_type_ids = PackedStringArray(["fire", "fire"])
	)
	if not _errors_contain(duplicate_unit_errors, "unit[sample_pyron].combat_type_ids duplicated type: fire"):
		fail("missing duplicated unit combat type validation")
		return

	var empty_unit_errors = _validate_with_sample_mutation(_harness, sample_factory, func(content_index):
		content_index.units["sample_pyron"].combat_type_ids = PackedStringArray(["fire", ""])
	)
	if not _errors_contain(empty_unit_errors, "unit[sample_pyron].combat_type_ids must not contain empty entry"):
		fail("missing empty unit combat type validation")
		return

	var unknown_chart_errors = _validate_with_sample_mutation(_harness, sample_factory, func(content_index):
		var entry = CombatTypeChartEntryScript.new()
		entry.atk = "fire"
		entry.def = "unknown_type"
		entry.mul = 2.0
		content_index.battle_formats["prototype_full_open"].combat_type_chart.append(entry)
	)
	if not _errors_contain(unknown_chart_errors, "battle_format[prototype_full_open].combat_type_chart unknown def: unknown_type"):
		fail("missing chart unknown type validation")
		return

	var missing_chart_field_errors = _validate_with_sample_mutation(_harness, sample_factory, func(content_index):
		var entry = CombatTypeChartEntryScript.new()
		entry.mul = 2.0
		content_index.battle_formats["prototype_full_open"].combat_type_chart.append(entry)
	)
	if not _errors_contain(missing_chart_field_errors, "battle_format[prototype_full_open].combat_type_chart missing atk") \
	or not _errors_contain(missing_chart_field_errors, "battle_format[prototype_full_open].combat_type_chart missing def"):
		fail("missing chart required field validation")
		return

	var duplicate_pair_errors = _validate_with_sample_mutation(_harness, sample_factory, func(content_index):
		var entry = CombatTypeChartEntryScript.new()
		entry.atk = "fire"
		entry.def = "wood"
		entry.mul = 2.0
		content_index.battle_formats["prototype_full_open"].combat_type_chart.append(entry)
	)
	if not _errors_contain(duplicate_pair_errors, "battle_format[prototype_full_open].combat_type_chart duplicated pair: fire|wood"):
		fail("missing chart duplicated pair validation")
		return

	var invalid_mul_errors = _validate_with_sample_mutation(_harness, sample_factory, func(content_index):
		var entry = CombatTypeChartEntryScript.new()
		entry.atk = "fire"
		entry.def = "wood"
		entry.mul = 1.5
		content_index.battle_formats["prototype_full_open"].combat_type_chart.append(entry)
	)
	if not _errors_contain(invalid_mul_errors, "battle_format[prototype_full_open].combat_type_chart invalid mul: 1.5"):
		fail("missing chart multiplier validation")
		return

	var zero_mul_errors = _validate_with_sample_mutation(_harness, sample_factory, func(content_index):
		var entry = CombatTypeChartEntryScript.new()
		entry.atk = "fire"
		entry.def = "water"
		entry.mul = 0.0
		content_index.battle_formats["prototype_full_open"].combat_type_chart.append(entry)
	)
	if not _errors_contain(zero_mul_errors, "battle_format[prototype_full_open].combat_type_chart invalid mul: 0"):
		fail("missing zero multiplier validation")
		return

	var oversized_mul_errors = _validate_with_sample_mutation(_harness, sample_factory, func(content_index):
		var entry = CombatTypeChartEntryScript.new()
		entry.atk = "water"
		entry.def = "fire"
		entry.mul = 3.0
		content_index.battle_formats["prototype_full_open"].combat_type_chart.append(entry)
	)
	if not _errors_contain(oversized_mul_errors, "battle_format[prototype_full_open].combat_type_chart invalid mul: 3"):
		fail("missing oversized multiplier validation")
		return

func test_combat_type_chart_math() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var content_index = _harness.build_loaded_content_index(sample_factory)
	var format_config = content_index.battle_formats.get("prototype_full_open", null)
	if format_config == null:
		fail("missing sample battle format")
		return

	var service = CombatTypeServiceScript.new()
	service.build_chart(format_config.combat_type_chart)

	if not is_equal_approx(service.calc_effectiveness("fire", PackedStringArray(["wood"])), 2.0):
		fail("fire -> wood should be 2.0")
		return
	if not is_equal_approx(service.calc_effectiveness("wood", PackedStringArray(["fire"])), 0.5):
		fail("wood -> fire should be 0.5")
		return
	if not is_equal_approx(service.calc_effectiveness("light", PackedStringArray(["water"])), 1.0):
		fail("unconfigured pair should default to 1.0")
		return
	if not is_equal_approx(service.calc_effectiveness("fire", PackedStringArray(["wood", "ice"])), 4.0):
		fail("fire -> wood+ice should multiply to 4.0")
		return
	if not is_equal_approx(service.calc_effectiveness("fire", PackedStringArray(["wood", "water"])), 1.0):
		fail("fire -> wood+water should multiply to 1.0")
		return
	if not is_equal_approx(service.calc_effectiveness("fire", PackedStringArray(["water", "dragon"])), 0.25):
		fail("fire -> water+dragon should multiply to 0.25")
		return
	if not is_equal_approx(service.calc_effectiveness("poison", PackedStringArray(["water"])), 2.0):
		fail("poison -> water should be 2.0")
		return
	if not is_equal_approx(service.calc_effectiveness("poison", PackedStringArray(["steel"])), 0.5):
		fail("poison -> steel should be 0.5")
		return
	if not is_equal_approx(service.calc_effectiveness("fire", PackedStringArray(["poison"])), 2.0):
		fail("fire -> poison should be 2.0")
		return
	if not is_equal_approx(service.calc_effectiveness("", PackedStringArray(["wood"])), 1.0):
		fail("empty skill type should be neutral")
		return


func _validate_with_sample_mutation(harness, sample_factory, mutate: Callable) -> Array:
	return _helper.validate_with_sample_mutation(harness, sample_factory, mutate)

func _errors_contain(errors: Array, expected_fragment: String) -> bool:
	return _helper.errors_contain(errors, expected_fragment)
