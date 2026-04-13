extends "res://test/suites/content_validation_core/base.gd"
const BaseSuiteScript := preload("res://test/suites/content_validation_core/base.gd")



func test_unsupported_resource_snapshot_fails_fast() -> void:
	_assert_legacy_result(_test_unsupported_resource_snapshot_fails_fast(_harness))

func test_on_receive_forbidden_in_content() -> void:
	_assert_legacy_result(_test_on_receive_forbidden_in_content(_harness))

func test_battle_format_runtime_constant_validation() -> void:
	_assert_legacy_result(_test_battle_format_runtime_constant_validation(_harness))
func _test_unsupported_resource_snapshot_fails_fast(harness) -> Dictionary:
	var content_index = BattleContentIndexScript.new()
	var ok: bool = content_index.load_snapshot(PackedStringArray([
		"res://tests/fixtures/unsupported_resource.tres",
	]))
	if ok:
		return harness.fail_result("unsupported snapshot resource should fail-fast")
	if content_index.last_error_code != ErrorCodesScript.INVALID_CONTENT_SNAPSHOT:
		return harness.fail_result("unsupported snapshot should report invalid_content_snapshot, got %s" % str(content_index.last_error_code))
	if content_index.last_error_message.find("unsupported content resource") == -1:
		return harness.fail_result("unsupported snapshot should report explicit unsupported content resource message")
	return harness.pass_result()

func _test_on_receive_forbidden_in_content(harness) -> Dictionary:
	var content_index = BattleContentIndexScript.new()
	var effect = EffectDefinitionScript.new()
	effect.id = "test_on_receive_forbidden_effect"
	effect.display_name = "On Receive Forbidden Effect"
	effect.scope = "self"
	effect.trigger_names = PackedStringArray(["on_hit"])
	content_index.register_resource(effect)
	var passive_item = PassiveItemDefinitionScript.new()
	passive_item.id = "test_on_receive_forbidden_item"
	passive_item.display_name = "On Receive Forbidden Item"
	passive_item.on_receive_effect_ids = PackedStringArray([effect.id])
	content_index.register_resource(passive_item)
	var errors: Array = content_index.validate_snapshot()
	if errors.is_empty():
		return harness.fail_result("on_receive_effect_ids should fail-fast at content validation")
	for error_msg in errors:
		if str(error_msg).find("on_receive_effect_ids is disabled") != -1:
			return harness.pass_result()
	return harness.fail_result("missing disabled on_receive_effect_ids validation error")

func _test_battle_format_runtime_constant_validation(harness) -> Dictionary:
	var content_index = BattleContentIndexScript.new()
	var format_config = BattleFormatConfigScript.new()
	format_config.format_id = "test_bad_runtime_constants"
	format_config.visibility_mode = "prototype_full_open"
	format_config.default_recoil_ratio = 1.2
	format_config.domain_clash_tie_threshold = -0.1
	content_index.register_resource(format_config)
	var errors: Array = content_index.validate_snapshot()
	if errors.is_empty():
		return harness.fail_result("battle format runtime constants should fail content validation when out of range")
	var has_recoil_error := false
	var has_tie_threshold_error := false
	for error_msg in errors:
		var msg := str(error_msg)
		has_recoil_error = has_recoil_error or msg.find("default_recoil_ratio out of range") != -1
		has_tie_threshold_error = has_tie_threshold_error or msg.find("domain_clash_tie_threshold out of range") != -1
	if not (has_recoil_error and has_tie_threshold_error):
		return harness.fail_result("battle format runtime constant validation should report both range errors")
	return harness.pass_result()
