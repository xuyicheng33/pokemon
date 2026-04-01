extends RefCounted
class_name ContentValidationCoreSuite

const BattleContentIndexScript := preload("res://src/battle_core/content/battle_content_index.gd")
const PassiveItemDefinitionScript := preload("res://src/battle_core/content/passive_item_definition.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const UnitDefinitionScript := preload("res://src/battle_core/content/unit_definition.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
const ResourceModPayloadScript := preload("res://src/battle_core/content/resource_mod_payload.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("content_validation_failures", failures, Callable(self, "_test_content_validation_failures").bind(harness))
	runner.run_test("content_validation_new_constraints", failures, Callable(self, "_test_content_validation_new_constraints").bind(harness))
	runner.run_test("formal_character_shared_fire_burst_validation", failures, Callable(self, "_test_formal_character_shared_fire_burst_validation").bind(harness))
	runner.run_test("unsupported_resource_snapshot_fails_fast", failures, Callable(self, "_test_unsupported_resource_snapshot_fails_fast").bind(harness))
	runner.run_test("on_receive_forbidden_in_content", failures, Callable(self, "_test_on_receive_forbidden_in_content").bind(harness))

func _test_content_validation_failures(harness) -> Dictionary:
	var content_index = BattleContentIndexScript.new()
	var bad_skill = SkillDefinitionScript.new()
	bad_skill.id = "bad_skill"
	bad_skill.display_name = "Bad Skill"
	bad_skill.damage_kind = "bad_kind"
	bad_skill.accuracy = 120
	bad_skill.mp_cost = -1
	bad_skill.targeting = "bad_target"
	bad_skill.priority = 9
	content_index.register_resource(bad_skill)
	var duplicate_skill_a = SkillDefinitionScript.new()
	duplicate_skill_a.id = "duplicate_skill"
	duplicate_skill_a.display_name = "Duplicate Skill A"
	duplicate_skill_a.targeting = ContentSchemaScript.TARGET_ENEMY_ACTIVE
	content_index.register_resource(duplicate_skill_a)
	var duplicate_skill_b = SkillDefinitionScript.new()
	duplicate_skill_b.id = "duplicate_skill"
	duplicate_skill_b.display_name = "Duplicate Skill B"
	duplicate_skill_b.targeting = ContentSchemaScript.TARGET_ENEMY_ACTIVE
	content_index.register_resource(duplicate_skill_b)
	var bad_unit = UnitDefinitionScript.new()
	bad_unit.id = "bad_unit"
	bad_unit.display_name = "Bad Unit"
	bad_unit.skill_ids = PackedStringArray(["missing_skill"])
	bad_unit.ultimate_skill_id = "missing_ultimate"
	content_index.register_resource(bad_unit)
	var bad_rule_mod = RuleModPayloadScript.new()
	bad_rule_mod.payload_type = "rule_mod"
	bad_rule_mod.mod_kind = "bad_kind"
	bad_rule_mod.mod_op = "bad_op"
	bad_rule_mod.scope = "self"
	bad_rule_mod.duration_mode = "turns"
	bad_rule_mod.duration = 1
	bad_rule_mod.decrement_on = "turn_start"
	bad_rule_mod.stacking = "none"
	bad_rule_mod.priority = 0
	var bad_effect = EffectDefinitionScript.new()
	bad_effect.id = "bad_effect"
	bad_effect.display_name = "Bad Effect"
	bad_effect.scope = "self"
	bad_effect.duration_mode = "permanent"
	bad_effect.trigger_names = PackedStringArray(["on_cast"])
	bad_effect.payloads.clear()
	bad_effect.payloads.append(bad_rule_mod)
	content_index.register_resource(bad_effect)
	var bad_resource_payload = ResourceModPayloadScript.new()
	bad_resource_payload.payload_type = "resource_mod"
	bad_resource_payload.resource_key = "energy"
	bad_resource_payload.amount = 2
	var bad_resource_effect = EffectDefinitionScript.new()
	bad_resource_effect.id = "bad_resource_effect"
	bad_resource_effect.display_name = "Bad Resource Effect"
	bad_resource_effect.scope = "self"
	bad_resource_effect.duration_mode = "permanent"
	bad_resource_effect.trigger_names = PackedStringArray(["on_cast"])
	bad_resource_effect.payloads.clear()
	bad_resource_effect.payloads.append(bad_resource_payload)
	content_index.register_resource(bad_resource_effect)
	var bad_stat_payload = StatModPayloadScript.new()
	bad_stat_payload.payload_type = "stat_mod"
	bad_stat_payload.stat_name = "luck"
	bad_stat_payload.stage_delta = 1
	var bad_stat_effect = EffectDefinitionScript.new()
	bad_stat_effect.id = "bad_stat_effect"
	bad_stat_effect.display_name = "Bad Stat Effect"
	bad_stat_effect.scope = "self"
	bad_stat_effect.duration_mode = "permanent"
	bad_stat_effect.trigger_names = PackedStringArray(["on_cast"])
	bad_stat_effect.payloads.clear()
	bad_stat_effect.payloads.append(bad_stat_payload)
	content_index.register_resource(bad_stat_effect)
	var errors: Array = content_index.validate_snapshot()
	if errors.is_empty():
		return harness.fail_result("content validator did not report failures")
	var has_priority_error := false
	var has_rule_mod_error := false
	var has_missing_ref := false
	var has_accuracy_error := false
	var has_mp_cost_error := false
	var has_duplicate_id_error := false
	var has_resource_key_error := false
	var has_stat_name_error := false
	for error_msg in errors:
		var msg := str(error_msg)
		if msg.find("priority out of range") != -1:
			has_priority_error = true
		if msg.find("rule_mod invalid") != -1:
			has_rule_mod_error = true
		if msg.find("missing skill") != -1:
			has_missing_ref = true
		if msg.find("accuracy out of range") != -1:
			has_accuracy_error = true
		if msg.find("mp_cost must be >= 0") != -1:
			has_mp_cost_error = true
		if msg.find("duplicated id") != -1:
			has_duplicate_id_error = true
		if msg.find("invalid resource_key") != -1:
			has_resource_key_error = true
		if msg.find("invalid stat_name") != -1:
			has_stat_name_error = true
	if not (has_priority_error and has_rule_mod_error and has_missing_ref and has_accuracy_error and has_mp_cost_error and has_duplicate_id_error and has_resource_key_error and has_stat_name_error):
		return harness.fail_result("content validation errors missing expected categories")
	return harness.pass_result()

func _test_content_validation_new_constraints(harness) -> Dictionary:
	var content_index = BattleContentIndexScript.new()
	var regular_ok = SkillDefinitionScript.new()
	regular_ok.id = "regular_ok"
	regular_ok.display_name = "Regular OK"
	regular_ok.targeting = ContentSchemaScript.TARGET_ENEMY_ACTIVE
	regular_ok.priority = 0
	content_index.register_resource(regular_ok)
	var regular_bad = SkillDefinitionScript.new()
	regular_bad.id = "regular_bad_priority"
	regular_bad.display_name = "Regular Bad Priority"
	regular_bad.targeting = ContentSchemaScript.TARGET_ENEMY_ACTIVE
	regular_bad.priority = 5
	content_index.register_resource(regular_bad)
	var ultimate_bad = SkillDefinitionScript.new()
	ultimate_bad.id = "ultimate_bad_priority"
	ultimate_bad.display_name = "Ultimate Bad Priority"
	ultimate_bad.targeting = ContentSchemaScript.TARGET_ENEMY_ACTIVE
	ultimate_bad.priority = 0
	content_index.register_resource(ultimate_bad)
	var slot_bad_unit = UnitDefinitionScript.new()
	slot_bad_unit.id = "slot_bad_unit"
	slot_bad_unit.display_name = "Slot Bad Unit"
	slot_bad_unit.skill_ids = PackedStringArray(["regular_ok", "regular_bad_priority"])
	slot_bad_unit.ultimate_skill_id = "ultimate_bad_priority"
	content_index.register_resource(slot_bad_unit)
	var regular_priority_bad_unit = UnitDefinitionScript.new()
	regular_priority_bad_unit.id = "regular_priority_bad_unit"
	regular_priority_bad_unit.display_name = "Regular Priority Bad Unit"
	regular_priority_bad_unit.skill_ids = PackedStringArray(["regular_bad_priority", "regular_ok", "regular_ok"])
	regular_priority_bad_unit.ultimate_skill_id = ""
	content_index.register_resource(regular_priority_bad_unit)
	var ultimate_duplicate_unit = UnitDefinitionScript.new()
	ultimate_duplicate_unit.id = "ultimate_duplicate_unit"
	ultimate_duplicate_unit.display_name = "Ultimate Duplicate Unit"
	ultimate_duplicate_unit.skill_ids = PackedStringArray(["ultimate_bad_priority", "regular_ok", "regular_ok"])
	ultimate_duplicate_unit.ultimate_skill_id = "ultimate_bad_priority"
	content_index.register_resource(ultimate_duplicate_unit)
	content_index.register_resource(_build_dynamic_formula_effect("invalid_dynamic_formula_effect", "self", PackedInt32Array([20, 10]), PackedFloat32Array([5.0])))
	content_index.register_resource(_build_dynamic_formula_effect("invalid_field_dynamic_formula_effect", "field", PackedInt32Array([20]), PackedFloat32Array([5.0])))
	var snapshot_errors: Array = content_index.validate_snapshot()
	if snapshot_errors.is_empty():
		return harness.fail_result("new content constraints should report validation failures")
	var has_regular_priority_error := false
	var has_ultimate_priority_error := false
	var has_slot_error := false
	var has_ultimate_in_regular_error := false
	var has_dynamic_formula_error := false
	var has_dynamic_formula_scope_error := false
	for error_msg in snapshot_errors:
		var msg := str(error_msg)
		has_regular_priority_error = has_regular_priority_error or msg.find("used in unit.skill_ids must have priority in -2..2") != -1
		has_ultimate_priority_error = has_ultimate_priority_error or msg.find("used as ultimate must have priority +5 or -5") != -1
		has_slot_error = has_slot_error or msg.find("skill_ids must contain exactly 3 entries") != -1
		has_ultimate_in_regular_error = has_ultimate_in_regular_error or msg.find("used as ultimate must not appear in any unit.skill_ids") != -1
		has_dynamic_formula_error = has_dynamic_formula_error or msg.find("dynamic_value_thresholds/dynamic_value_outputs size mismatch") != -1 or msg.find("dynamic_value_thresholds must be strictly ascending") != -1
		has_dynamic_formula_scope_error = has_dynamic_formula_scope_error or msg.find("dynamic value formula is not allowed for field scope") != -1
	if not (has_regular_priority_error and has_ultimate_priority_error and has_slot_error and has_ultimate_in_regular_error and has_dynamic_formula_error and has_dynamic_formula_scope_error):
		return harness.fail_result("new content validation constraints missing expected failures")
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var runtime_content = harness.build_loaded_content_index(sample_factory)
	var duplicate_item = PassiveItemDefinitionScript.new()
	duplicate_item.id = "duplicate_item_for_setup_validation"
	duplicate_item.display_name = "Duplicate Item"
	runtime_content.register_resource(duplicate_item)
	runtime_content.units["sample_pyron"].passive_item_id = duplicate_item.id
	runtime_content.units["sample_mossaur"].passive_item_id = duplicate_item.id
	var battle_setup = sample_factory.build_sample_setup()
	var setup_errors: Array = runtime_content.validate_setup(battle_setup)
	var has_duplicate_item_error := false
	for error_msg in setup_errors:
		if str(error_msg).find("duplicated passive_item_id") != -1:
			has_duplicate_item_error = true
			break
	if not has_duplicate_item_error:
		return harness.fail_result("battle setup should reject duplicate passive items on same side")
	return harness.pass_result()

func _test_formal_character_shared_fire_burst_validation(harness) -> Dictionary:
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var kamado_mark = content_index.effects.get("sukuna_kamado_mark", null)
	if kamado_mark == null or kamado_mark.payloads.is_empty():
		return harness.fail_result("missing sukuna_kamado_mark damage payload")
	kamado_mark.payloads[0].amount = 21
	var errors: Array = content_index.validate_snapshot()
	for error_msg in errors:
		if str(error_msg).find("formal[sukuna].shared_fire_burst payload mismatch") != -1:
			return harness.pass_result()
	return harness.fail_result("formal shared fire burst validation should fail when Sukuna payloads drift")

func _test_unsupported_resource_snapshot_fails_fast(_harness) -> Dictionary:
	var content_index = BattleContentIndexScript.new()
	var ok: bool = content_index.load_snapshot(PackedStringArray([
		"res://tests/fixtures/unsupported_resource.tres",
	]))
	if ok:
		return _harness.fail_result("unsupported snapshot resource should fail-fast")
	if content_index.last_error_code != ErrorCodesScript.INVALID_CONTENT_SNAPSHOT:
		return _harness.fail_result("unsupported snapshot should report invalid_content_snapshot, got %s" % str(content_index.last_error_code))
	if content_index.last_error_message.find("unsupported content resource") == -1:
		return _harness.fail_result("unsupported snapshot should report explicit unsupported content resource message")
	return _harness.pass_result()

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

func _build_dynamic_formula_effect(effect_id: String, scope: String, thresholds: PackedInt32Array, outputs: PackedFloat32Array):
	var payload = RuleModPayloadScript.new()
	payload.mod_kind = "mp_regen"
	payload.mod_op = "set"
	payload.scope = scope
	payload.duration_mode = "turns"
	payload.duration = 1
	payload.decrement_on = "turn_start"
	payload.stacking = "replace"
	payload.dynamic_value_formula = ContentSchemaScript.RULE_MOD_VALUE_FORMULA_MATCHUP_BST_GAP_BAND
	payload.dynamic_value_thresholds = thresholds
	payload.dynamic_value_outputs = outputs
	var effect = EffectDefinitionScript.new()
	effect.id = effect_id
	effect.scope = scope
	effect.trigger_names = PackedStringArray(["on_cast"])
	effect.payloads.clear()
	effect.payloads.append(payload)
	return effect
