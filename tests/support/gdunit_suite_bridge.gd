extends GdUnitTestSuite

const BattleCoreTestHarnessScript := preload("res://tests/support/battle_core_test_harness.gd")

var _harness = BattleCoreTestHarnessScript.new()

func after_test() -> void:
	_harness.dispose_sample_factories()
	_harness.dispose_core_pool()

# Build the standard fixture used by the majority of suites: composer core +
# sample factory + loaded content index + initialized battle. Each call returns
# fresh state so tests stay isolated; the helper exists purely to collapse the
# 5-call boilerplate that previously appeared at the top of nearly every test.
# On any failure the suite-level `fail()` is invoked and the returned dict
# carries `ok=false`; callers should `return` if `ok` is not true.
# Bridge for legacy Dictionary-protocol helpers that have not been migrated to
# the native gdunit fail() form. Pass the dict returned by harness.fail_result
# / harness.pass_result; this method calls fail() with the embedded error
# message when ok is false.
func _assert_legacy_result(result) -> void:
	if typeof(result) != TYPE_DICTIONARY:
		fail("legacy result must be a Dictionary, got %s" % typeof(result))
		return
	if not bool(result.get("ok", false)):
		fail(str(result.get("error", "unknown legacy failure")))

func _setup_default_battle(battle_seed: int = 1) -> Dictionary:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return {"ok": false}
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return {"ok": false}
	var content_index = _harness.build_loaded_content_index(sample_factory)
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, battle_seed)
	return {
		"ok": true,
		"core": core,
		"sample_factory": sample_factory,
		"content_index": content_index,
		"battle_state": battle_state,
	}
