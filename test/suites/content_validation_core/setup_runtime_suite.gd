extends "res://test/suites/content_validation_core/base.gd"

func test_unsupported_resource_snapshot_fails_fast() -> void:
	var content_index = BattleContentIndexScript.new()
	var ok: bool = content_index.load_snapshot(PackedStringArray([
		"res://tests/fixtures/unsupported_resource.tres",
	]))
	if ok:
		fail("unsupported snapshot resource should fail-fast")
		return
	if content_index.last_error_code != ErrorCodesScript.INVALID_CONTENT_SNAPSHOT:
		fail("unsupported snapshot should report invalid_content_snapshot, got %s" % str(content_index.last_error_code))
		return
	if content_index.last_error_message.find("unsupported content resource") == -1:
		fail("unsupported snapshot should report explicit unsupported content resource message")
		return

func test_on_receive_forbidden_in_content() -> void:
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
		fail("on_receive_effect_ids should fail-fast at content validation")
		return
	for error_msg in errors:
		if str(error_msg).find("on_receive_effect_ids is disabled") != -1:
			return
	fail("missing disabled on_receive_effect_ids validation error")

func test_battle_format_runtime_constant_validation() -> void:
	var content_index = BattleContentIndexScript.new()
	var format_config = BattleFormatConfigScript.new()
	format_config.format_id = "test_bad_runtime_constants"
	format_config.visibility_mode = "prototype_full_open"
	format_config.default_recoil_ratio = 1.2
	format_config.domain_clash_tie_threshold = -0.1
	content_index.register_resource(format_config)
	var errors: Array = content_index.validate_snapshot()
	if errors.is_empty():
		fail("battle format runtime constants should fail content validation when out of range")
		return
	var has_recoil_error := false
	var has_tie_threshold_error := false
	for error_msg in errors:
		var msg := str(error_msg)
		has_recoil_error = has_recoil_error or msg.find("default_recoil_ratio out of range") != -1
		has_tie_threshold_error = has_tie_threshold_error or msg.find("domain_clash_tie_threshold out of range") != -1
	if not (has_recoil_error and has_tie_threshold_error):
		fail("battle format runtime constant validation should report both range errors")
		return

