extends RefCounted
class_name CombatTypeDefinitionSuite

const CombatTypeChartEntryScript := preload("res://src/battle_core/content/combat_type_chart_entry.gd")
const CombatTypeServiceScript := preload("res://src/battle_core/math/combat_type_service.gd")
const CombatTypeTestHelperScript := preload("res://tests/support/combat_type_test_helper.gd")

var _helper = CombatTypeTestHelperScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("combat_type_content_validation", failures, Callable(self, "_test_combat_type_content_validation").bind(harness))
    runner.run_test("combat_type_chart_math", failures, Callable(self, "_test_combat_type_chart_math").bind(harness))
func _test_combat_type_content_validation(harness) -> Dictionary:
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")

    var unknown_skill_errors = _validate_with_sample_mutation(harness, sample_factory, func(content_index):
        content_index.skills["sample_strike"].combat_type_id = "unknown_type"
    )
    if not _errors_contain(unknown_skill_errors, "skill[sample_strike].combat_type_id missing combat type: unknown_type"):
        return harness.fail_result("missing unknown skill combat_type validation")

    var too_many_unit_errors = _validate_with_sample_mutation(harness, sample_factory, func(content_index):
        content_index.units["sample_pyron"].combat_type_ids = PackedStringArray(["fire", "water", "wood"])
    )
    if not _errors_contain(too_many_unit_errors, "unit[sample_pyron].combat_type_ids must contain at most 2 entries"):
        return harness.fail_result("missing unit max 2 combat types validation")

    var duplicate_unit_errors = _validate_with_sample_mutation(harness, sample_factory, func(content_index):
        content_index.units["sample_pyron"].combat_type_ids = PackedStringArray(["fire", "fire"])
    )
    if not _errors_contain(duplicate_unit_errors, "unit[sample_pyron].combat_type_ids duplicated type: fire"):
        return harness.fail_result("missing duplicated unit combat type validation")

    var empty_unit_errors = _validate_with_sample_mutation(harness, sample_factory, func(content_index):
        content_index.units["sample_pyron"].combat_type_ids = PackedStringArray(["fire", ""])
    )
    if not _errors_contain(empty_unit_errors, "unit[sample_pyron].combat_type_ids must not contain empty entry"):
        return harness.fail_result("missing empty unit combat type validation")

    var unknown_chart_errors = _validate_with_sample_mutation(harness, sample_factory, func(content_index):
        var entry = CombatTypeChartEntryScript.new()
        entry.atk = "fire"
        entry.def = "unknown_type"
        entry.mul = 2.0
        content_index.battle_formats["prototype_full_open"].combat_type_chart.append(entry)
    )
    if not _errors_contain(unknown_chart_errors, "battle_format[prototype_full_open].combat_type_chart unknown def: unknown_type"):
        return harness.fail_result("missing chart unknown type validation")

    var missing_chart_field_errors = _validate_with_sample_mutation(harness, sample_factory, func(content_index):
        var entry = CombatTypeChartEntryScript.new()
        entry.mul = 2.0
        content_index.battle_formats["prototype_full_open"].combat_type_chart.append(entry)
    )
    if not _errors_contain(missing_chart_field_errors, "battle_format[prototype_full_open].combat_type_chart missing atk") \
    or not _errors_contain(missing_chart_field_errors, "battle_format[prototype_full_open].combat_type_chart missing def"):
        return harness.fail_result("missing chart required field validation")

    var duplicate_pair_errors = _validate_with_sample_mutation(harness, sample_factory, func(content_index):
        var entry = CombatTypeChartEntryScript.new()
        entry.atk = "fire"
        entry.def = "wood"
        entry.mul = 2.0
        content_index.battle_formats["prototype_full_open"].combat_type_chart.append(entry)
    )
    if not _errors_contain(duplicate_pair_errors, "battle_format[prototype_full_open].combat_type_chart duplicated pair: fire|wood"):
        return harness.fail_result("missing chart duplicated pair validation")

    var invalid_mul_errors = _validate_with_sample_mutation(harness, sample_factory, func(content_index):
        var entry = CombatTypeChartEntryScript.new()
        entry.atk = "fire"
        entry.def = "wood"
        entry.mul = 1.5
        content_index.battle_formats["prototype_full_open"].combat_type_chart.append(entry)
    )
    if not _errors_contain(invalid_mul_errors, "battle_format[prototype_full_open].combat_type_chart invalid mul: 1.5"):
        return harness.fail_result("missing chart multiplier validation")

    var zero_mul_errors = _validate_with_sample_mutation(harness, sample_factory, func(content_index):
        var entry = CombatTypeChartEntryScript.new()
        entry.atk = "fire"
        entry.def = "water"
        entry.mul = 0.0
        content_index.battle_formats["prototype_full_open"].combat_type_chart.append(entry)
    )
    if not _errors_contain(zero_mul_errors, "battle_format[prototype_full_open].combat_type_chart invalid mul: 0"):
        return harness.fail_result("missing zero multiplier validation")

    var oversized_mul_errors = _validate_with_sample_mutation(harness, sample_factory, func(content_index):
        var entry = CombatTypeChartEntryScript.new()
        entry.atk = "water"
        entry.def = "fire"
        entry.mul = 3.0
        content_index.battle_formats["prototype_full_open"].combat_type_chart.append(entry)
    )
    if not _errors_contain(oversized_mul_errors, "battle_format[prototype_full_open].combat_type_chart invalid mul: 3"):
        return harness.fail_result("missing oversized multiplier validation")

    return harness.pass_result()

func _test_combat_type_chart_math(harness) -> Dictionary:
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var format_config = content_index.battle_formats.get("prototype_full_open", null)
    if format_config == null:
        return harness.fail_result("missing sample battle format")

    var service = CombatTypeServiceScript.new()
    service.build_chart(format_config.combat_type_chart)

    if not is_equal_approx(service.calc_effectiveness("fire", PackedStringArray(["wood"])), 2.0):
        return harness.fail_result("fire -> wood should be 2.0")
    if not is_equal_approx(service.calc_effectiveness("wood", PackedStringArray(["fire"])), 0.5):
        return harness.fail_result("wood -> fire should be 0.5")
    if not is_equal_approx(service.calc_effectiveness("light", PackedStringArray(["water"])), 1.0):
        return harness.fail_result("unconfigured pair should default to 1.0")
    if not is_equal_approx(service.calc_effectiveness("fire", PackedStringArray(["wood", "ice"])), 4.0):
        return harness.fail_result("fire -> wood+ice should multiply to 4.0")
    if not is_equal_approx(service.calc_effectiveness("fire", PackedStringArray(["wood", "water"])), 1.0):
        return harness.fail_result("fire -> wood+water should multiply to 1.0")
    if not is_equal_approx(service.calc_effectiveness("fire", PackedStringArray(["water", "dragon"])), 0.25):
        return harness.fail_result("fire -> water+dragon should multiply to 0.25")
    if not is_equal_approx(service.calc_effectiveness("", PackedStringArray(["wood"])), 1.0):
        return harness.fail_result("empty skill type should be neutral")
    if not is_equal_approx(service.calc_effectiveness("fire", PackedStringArray()), 1.0):
        return harness.fail_result("empty defender type should be neutral")
    return harness.pass_result()

func _validate_with_sample_mutation(harness, sample_factory, mutate: Callable) -> Array:
    return _helper._validate_with_sample_mutation(harness, sample_factory, mutate)

func _errors_contain(errors: Array, expected_fragment: String) -> bool:
    return _helper._errors_contain(errors, expected_fragment)
