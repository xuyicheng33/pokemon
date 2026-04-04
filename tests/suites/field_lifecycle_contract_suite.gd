extends RefCounted
class_name FieldLifecycleContractSuite

const EventTypesScript := preload("res://src/shared/event_types.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const FieldDefinitionScript := preload("res://src/battle_core/content/field_definition.gd")
const ApplyFieldPayloadScript := preload("res://src/battle_core/content/apply_field_payload.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const FieldStateScript := preload("res://src/battle_core/runtime/field_state.gd")
const UltimateFieldTestHelperScript := preload("res://tests/support/ultimate_field_test_helper.gd")

class CaptureFieldTriggerDispatcher:
	extends RefCounted

	var captured_chain_context = null
	var last_invalid_battle_code: Variant = null

	func invalid_battle_code() -> Variant:
		return last_invalid_battle_code

	func collect_events(
		_trigger_name: String,
		_battle_state,
		_content_index,
		_effect_ids: PackedStringArray,
		_owner_id: String,
		_source_instance_id: String,
		_source_kind_order: int,
		_source_order_speed_snapshot: int,
		chain_context
	) -> Array:
		captured_chain_context = chain_context
		return [{"event_id": "captured_field_break_event"}]

class CaptureFieldTriggerBatchRunner:
	extends RefCounted

	var captured_chain_context = null

	func execute_trigger_batch(
		_trigger_name: String,
		_battle_state,
		_content_index,
		_owner_unit_ids: Array,
		chain_context,
		_extra_effect_events: Array = []
	):
		captured_chain_context = chain_context
		return null

var _helper = UltimateFieldTestHelperScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("field_bound_stat_mod_restore_contract", failures, Callable(self, "_test_field_bound_stat_mod_restore_contract").bind(harness))
	runner.run_test("field_break_self_owner_contract", failures, Callable(self, "_test_field_break_self_owner_contract").bind(harness))
	runner.run_test("field_break_uses_explicit_chain_context_contract", failures, Callable(self, "_test_field_break_uses_explicit_chain_context_contract").bind(harness))
	runner.run_test("field_break_transition_preserves_new_field_contract", failures, Callable(self, "_test_field_break_transition_preserves_new_field_contract").bind(harness))
	runner.run_test("field_expire_transition_preserves_new_field_contract", failures, Callable(self, "_test_field_expire_transition_preserves_new_field_contract").bind(harness))

func _test_field_bound_stat_mod_restore_contract(harness) -> Dictionary:
	var gojo_payload = _helper.build_gojo_vs_sample_state(harness, 2212)
	if gojo_payload.has("error"):
		return harness.fail_result(str(gojo_payload["error"]))
	var gojo_core = gojo_payload["core"]
	var gojo_content = gojo_payload["content_index"]
	var gojo_state = gojo_payload["battle_state"]
	var gojo = gojo_state.get_side("P1").get_active_unit()
	gojo.current_mp = gojo.max_mp
	gojo.ultimate_points = gojo.ultimate_points_cap
	gojo.stat_stages["sp_attack"] = 2
	_helper.run_turn(
		gojo_core,
		gojo_state,
		gojo_content,
		_helper.build_ultimate_command(gojo_core, 1, "P1", "P1-A", "gojo_unlimited_void"),
		_helper.build_wait_command(gojo_core, 1, "P2", "P2-A")
	)
	_helper.run_turn(gojo_core, gojo_state, gojo_content, _helper.build_wait_command(gojo_core, 2, "P1", "P1-A"), _helper.build_wait_command(gojo_core, 2, "P2", "P2-A"))
	_helper.run_turn(gojo_core, gojo_state, gojo_content, _helper.build_wait_command(gojo_core, 3, "P1", "P1-A"), _helper.build_wait_command(gojo_core, 3, "P2", "P2-A"))
	_helper.run_turn(gojo_core, gojo_state, gojo_content, _helper.build_wait_command(gojo_core, 4, "P1", "P1-A"), _helper.build_wait_command(gojo_core, 4, "P2", "P2-A"))
	if int(gojo.stat_stages.get("sp_attack", -99)) != 2:
		return harness.fail_result("Gojo 领域结束后必须回到开领域前的 sp_attack 阶段")

	var sukuna_payload = _helper.build_sukuna_vs_sample_state(harness, 2213)
	if sukuna_payload.has("error"):
		return harness.fail_result(str(sukuna_payload["error"]))
	var sukuna_core = sukuna_payload["core"]
	var sukuna_content = sukuna_payload["content_index"]
	var sukuna_state = sukuna_payload["battle_state"]
	var sukuna = sukuna_state.get_side("P1").get_active_unit()
	sukuna.current_mp = sukuna.max_mp
	sukuna.ultimate_points = sukuna.ultimate_points_cap
	sukuna.stat_stages["attack"] = 2
	sukuna.stat_stages["sp_attack"] = 2
	_helper.run_turn(
		sukuna_core,
		sukuna_state,
		sukuna_content,
		_helper.build_ultimate_command(sukuna_core, 1, "P1", "P1-A", "sukuna_fukuma_mizushi"),
		_helper.build_wait_command(sukuna_core, 1, "P2", "P2-A")
	)
	_helper.run_turn(sukuna_core, sukuna_state, sukuna_content, _helper.build_wait_command(sukuna_core, 2, "P1", "P1-A"), _helper.build_wait_command(sukuna_core, 2, "P2", "P2-A"))
	_helper.run_turn(sukuna_core, sukuna_state, sukuna_content, _helper.build_wait_command(sukuna_core, 3, "P1", "P1-A"), _helper.build_wait_command(sukuna_core, 3, "P2", "P2-A"))
	_helper.run_turn(sukuna_core, sukuna_state, sukuna_content, _helper.build_wait_command(sukuna_core, 4, "P1", "P1-A"), _helper.build_wait_command(sukuna_core, 4, "P2", "P2-A"))
	if int(sukuna.stat_stages.get("attack", -99)) != 2 or int(sukuna.stat_stages.get("sp_attack", -99)) != 2:
		return harness.fail_result("宿傩领域结束后必须回到开领域前的双攻阶段")
	return harness.pass_result()

func _test_field_break_self_owner_contract(harness) -> Dictionary:
	var state_payload = _helper.build_gojo_vs_sample_state(harness, 2214)
	if state_payload.has("error"):
		return harness.fail_result(str(state_payload["error"]))
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	var actor = battle_state.get_side("P1").get_active_unit()
	actor.current_mp = 40
	_helper.register_self_break_field_test_content(content_index)
	actor.regular_skill_ids[0] = "test_self_break_field_call"
	_helper.run_turn(
		core,
		battle_state,
		content_index,
		_helper.build_skill_command(core, 1, "P1", "P1-A", "test_self_break_field_call"),
		_helper.build_wait_command(core, 1, "P2", "P2-A")
	)
	if battle_state.field_state == null or battle_state.field_state.field_def_id != "test_self_break_field":
		return harness.fail_result("自定义 field 应在测试里成功立场")
	core.service("battle_logger").reset()
	_helper.run_turn(
		core,
		battle_state,
		content_index,
		_helper.build_switch_command(core, 2, "P1", "P1-A", "P1-B"),
		_helper.build_wait_command(core, 2, "P2", "P2-A")
	)
	var break_after := -1
	for log_event in core.service("battle_logger").event_log:
		if log_event.event_type != EventTypesScript.EFFECT_RESOURCE_MOD or log_event.value_changes.is_empty():
			continue
		var value_change = log_event.value_changes[0]
		if log_event.trigger_name == "field_break" and log_event.target_instance_id == actor.unit_instance_id and String(value_change.resource_name) == "mp" and int(value_change.delta) == 5:
			break_after = int(value_change.after_value)
			break
	if break_after < 0:
		return harness.fail_result("field_break 的 self 效果应能作用到已离场但仍存活的领域创建者")
	if actor.current_mp != break_after:
		return harness.fail_result("field_break 的资源变化必须真实落到已离场创建者运行态上")
	return harness.pass_result()

func _test_field_break_transition_preserves_new_field_contract(harness) -> Dictionary:
	var state_payload = _helper.build_gojo_vs_sample_state(harness, 2215)
	if state_payload.has("error"):
		return harness.fail_result(str(state_payload["error"]))
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	var actor = battle_state.get_side("P1").get_active_unit()
	var ids = _register_transition_field_test_content(content_index, "test_break_transition", "field_break")
	var old_field = FieldStateScript.new()
	old_field.field_def_id = ids["base_field_id"]
	old_field.instance_id = "test_break_transition_base_instance"
	old_field.creator = actor.unit_instance_id
	old_field.remaining_turns = 2
	battle_state.field_state = old_field
	battle_state.chain_context = core.service("battle_result_service").build_system_chain(EventTypesScript.SYSTEM_TURN_END)
	var invalid_code = core.service("field_service").break_active_field(
		battle_state,
		content_index,
		"field_break",
		battle_state.chain_context,
		Callable(core.service("trigger_batch_runner"), "execute_trigger_batch")
	)
	if invalid_code != null:
		return harness.fail_result("field_break transition should stay valid, got %s" % str(invalid_code))
	if battle_state.field_state == null or battle_state.field_state.field_def_id != ids["next_field_id"]:
		return harness.fail_result("field_break hook created field must remain active after old field cleanup")
	if battle_state.field_rule_mod_instances.size() != 1:
		return harness.fail_result("new field's field rule_mod must survive field_break cleanup")
	if String(battle_state.field_rule_mod_instances[0].field_instance_id) != String(battle_state.field_state.instance_id):
		return harness.fail_result("field_break transition should keep the new field-bound rule_mod attached to the new field instance")
	return harness.pass_result()

func _test_field_break_uses_explicit_chain_context_contract(harness) -> Dictionary:
	var state_payload = _helper.build_gojo_vs_sample_state(harness, 2217)
	if state_payload.has("error"):
		return harness.fail_result(str(state_payload["error"]))
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	var actor = battle_state.get_side("P1").get_active_unit()
	var ids = _register_transition_field_test_content(content_index, "test_break_chain_context", "field_break")
	var old_field = FieldStateScript.new()
	old_field.field_def_id = ids["base_field_id"]
	old_field.instance_id = "test_break_chain_context_base_instance"
	old_field.creator = actor.unit_instance_id
	old_field.remaining_turns = 2
	battle_state.field_state = old_field
	battle_state.chain_context = core.service("battle_result_service").build_system_chain(EventTypesScript.SYSTEM_TURN_END)
	var explicit_chain_context = core.service("battle_result_service").build_system_chain("system:test_field_break_override")
	var capture_dispatcher = CaptureFieldTriggerDispatcher.new()
	var capture_runner = CaptureFieldTriggerBatchRunner.new()
	core.service("field_service").trigger_dispatcher = capture_dispatcher
	var invalid_code = core.service("field_service").break_active_field(
		battle_state,
		content_index,
		"field_break",
		explicit_chain_context,
		Callable(capture_runner, "execute_trigger_batch")
	)
	if invalid_code != null:
		return harness.fail_result("field_break explicit chain_context should stay valid, got %s" % str(invalid_code))
	if capture_dispatcher.captured_chain_context == null:
		return harness.fail_result("field_break lifecycle collect should receive a derived lifecycle chain_context")
	if String(capture_dispatcher.captured_chain_context.event_chain_id) != String(explicit_chain_context.event_chain_id):
		return harness.fail_result("field_break lifecycle collect should inherit the explicit chain_context event_chain_id")
	if String(capture_dispatcher.captured_chain_context.actor_id) != String(actor.unit_instance_id):
		return harness.fail_result("field_break lifecycle collect should retarget actor_id to the field creator")
	if capture_runner.captured_chain_context != explicit_chain_context:
		return harness.fail_result("field_break trigger batch should use the explicit chain_context parameter")
	return harness.pass_result()

func _test_field_expire_transition_preserves_new_field_contract(harness) -> Dictionary:
	var state_payload = _helper.build_gojo_vs_sample_state(harness, 2216)
	if state_payload.has("error"):
		return harness.fail_result(str(state_payload["error"]))
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	var actor = battle_state.get_side("P1").get_active_unit()
	var ids = _register_transition_field_test_content(content_index, "test_expire_transition", "field_expire")
	var old_field = FieldStateScript.new()
	old_field.field_def_id = ids["base_field_id"]
	old_field.instance_id = "test_expire_transition_base_instance"
	old_field.creator = actor.unit_instance_id
	old_field.remaining_turns = 1
	battle_state.field_state = old_field
	battle_state.chain_context = core.service("battle_result_service").build_system_chain(EventTypesScript.SYSTEM_TURN_END)
	var field_tick_result = core.service("turn_field_lifecycle_service").apply_turn_end_field_tick(
		battle_state,
		content_index,
		"test_expire_transition_cause"
	)
	if bool(field_tick_result.get("terminated", false)):
		return harness.fail_result("field_expire transition should stay valid")
	if battle_state.field_state == null or battle_state.field_state.field_def_id != ids["next_field_id"]:
		return harness.fail_result("field_expire hook created field must remain active after old field cleanup")
	if field_tick_result.get("field_change", null) == null or String(field_tick_result["field_change"].after_field_id) != ids["next_field_id"]:
		return harness.fail_result("field_change should record the replacement field produced by field_expire")
	if battle_state.field_rule_mod_instances.size() != 1:
		return harness.fail_result("new field's field rule_mod must survive field_expire cleanup")
	if String(battle_state.field_rule_mod_instances[0].field_instance_id) != String(battle_state.field_state.instance_id):
		return harness.fail_result("field_expire transition should keep the new field-bound rule_mod attached to the new field instance")
	return harness.pass_result()

func _register_transition_field_test_content(content_index, prefix: String, trigger_name: String) -> Dictionary:
	var field_rule_mod_payload = RuleModPayloadScript.new()
	field_rule_mod_payload.payload_type = "rule_mod"
	field_rule_mod_payload.mod_kind = "mp_regen"
	field_rule_mod_payload.mod_op = "add"
	field_rule_mod_payload.value = 3
	field_rule_mod_payload.scope = "field"
	field_rule_mod_payload.duration_mode = "turns"
	field_rule_mod_payload.duration = 2
	field_rule_mod_payload.decrement_on = "turn_end"
	field_rule_mod_payload.stacking = "replace"
	var next_field_effect = EffectDefinitionScript.new()
	next_field_effect.id = "%s_next_field_effect" % prefix
	next_field_effect.display_name = "%s Next Field Effect" % prefix
	next_field_effect.scope = "field"
	next_field_effect.trigger_names = PackedStringArray(["field_apply"])
	next_field_effect.payloads.clear()
	next_field_effect.payloads.append(field_rule_mod_payload)
	content_index.register_resource(next_field_effect)

	var next_field = FieldDefinitionScript.new()
	next_field.id = "%s_next_field" % prefix
	next_field.display_name = "%s Next Field" % prefix
	next_field.effect_ids = PackedStringArray([next_field_effect.id])
	content_index.register_resource(next_field)

	var transition_payload = ApplyFieldPayloadScript.new()
	transition_payload.payload_type = "apply_field"
	transition_payload.field_definition_id = next_field.id
	var transition_effect = EffectDefinitionScript.new()
	transition_effect.id = "%s_transition_effect" % prefix
	transition_effect.display_name = "%s Transition Effect" % prefix
	transition_effect.scope = "field"
	transition_effect.duration_mode = "turns"
	transition_effect.duration = 2
	transition_effect.decrement_on = "turn_end"
	transition_effect.trigger_names = PackedStringArray([trigger_name])
	transition_effect.payloads.clear()
	transition_effect.payloads.append(transition_payload)
	content_index.register_resource(transition_effect)

	var base_field = FieldDefinitionScript.new()
	base_field.id = "%s_base_field" % prefix
	base_field.display_name = "%s Base Field" % prefix
	if trigger_name == "field_break":
		base_field.on_break_effect_ids = PackedStringArray([transition_effect.id])
	else:
		base_field.on_expire_effect_ids = PackedStringArray([transition_effect.id])
	content_index.register_resource(base_field)

	return {
		"base_field_id": base_field.id,
		"next_field_id": next_field.id,
	}
