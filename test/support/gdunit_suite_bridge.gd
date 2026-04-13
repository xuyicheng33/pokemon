extends GdUnitTestSuite

const BattleCoreTestHarnessScript := preload("res://tests/support/battle_core_test_harness.gd")

var _harness = BattleCoreTestHarnessScript.new()

func after_test() -> void:
	_harness.dispose_core_pool()

func _assert_legacy_result(result: Dictionary) -> void:
	if typeof(result) != TYPE_DICTIONARY:
		fail("legacy suite returned malformed result")
		return
	if not bool(result.get("ok", false)):
		fail(str(result.get("error", "unknown error")))
