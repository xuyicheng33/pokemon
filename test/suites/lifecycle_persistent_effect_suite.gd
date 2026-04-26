extends "res://tests/support/gdunit_suite_bridge.gd"

const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")


func test_persistent_effect_and_rule_mod_survive_manual_switch_contract() -> void:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var content_index = _harness.build_loaded_content_index(sample_factory)
	var resources = _register_persistent_runtime_resources(content_index)
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 501)
	var actor = battle_state.get_side("P1").get_active_unit()
	var opponent = battle_state.get_side("P2").get_active_unit()
	if actor == null or opponent == null:
		fail("missing active units for persistent manual switch contract")
		return
	var effect_definition = resources["persistent_effect"]
	var persistent_effect = core.service("effect_instance_service").create_instance(
		effect_definition,
		actor.unit_instance_id,
		battle_state,
		"test_persistent_effect_source",
		0,
		actor.base_speed
	)
	if persistent_effect == null:
		fail("failed to create persistent effect instance")
		return
	var persistent_rule_mod = _build_persistent_rule_mod_payload("test_persistent_group")
	if core.service("rule_mod_service").create_instance(
		persistent_rule_mod,
		{"scope": "unit", "id": actor.unit_instance_id},
		battle_state,
		"test_persistent_rule_mod_source",
		0,
		actor.base_speed
	) == null:
		fail("failed to create persistent rule_mod")
		return
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SWITCH,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"target_public_id": "P1-B",
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
		}),
	])
	var switched_unit = battle_state.get_unit_by_public_id("P1-A")
	if switched_unit == null:
		fail("missing switched-out unit P1-A")
		return
	var effect_instance = _find_effect_instance(switched_unit, String(effect_definition.id))
	if effect_instance == null or int(effect_instance.remaining) != 1:
		fail("persistent effect should remain on switched-out unit and decrement on bench")
		return
	var regen_instance = _find_rule_mod_instance(switched_unit, "mp_regen")
	if regen_instance == null or int(regen_instance.remaining) != 1:
		fail("persistent rule_mod should remain on switched-out unit and decrement on bench")
		return
	if not bool(regen_instance.persists_on_switch):
		fail("persistent rule_mod should retain persists_on_switch=true at runtime")
		return
	if String(regen_instance.source_stacking_key) != "test_persistent_group":
		fail("persistent rule_mod should store source_stacking_key for grouping")
		return
	if int(switched_unit.stat_stages.get("speed", 0)) != 0:
		fail("persistent bench effect should not trigger normal turn_end payloads while off-field")
		return
	if int(opponent.current_hp) != int(opponent.max_hp):
		fail("persistent bench effect should not fire expire follow-up before duration ends")
		return
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 2,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-B",
		}),
		core.service("command_builder").build_command({
			"turn_index": 2,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
		}),
	])
	if _find_effect_instance(switched_unit, String(effect_definition.id)) != null:
		fail("persistent bench effect should expire after its remaining turns run out")
		return
	if _find_rule_mod_instance(switched_unit, "mp_regen") != null:
		fail("persistent bench rule_mod should expire after its remaining turns run out")
		return
	if int(switched_unit.stat_stages.get("speed", 0)) != 0:
		fail("persistent bench effect should never trigger normal turn_end payloads while off-field")
		return
	if int(opponent.current_hp) != int(opponent.max_hp):
		fail("persistent bench effect expiry should not run on_expire_effect_ids while off-field")
		return
	if not _has_event(core.service("battle_logger").event_log, func(ev):
		return ev.event_type == EventTypesScript.EFFECT_REMOVE_EFFECT \
			and String(ev.target_instance_id) == String(switched_unit.unit_instance_id) \
			and String(ev.payload_summary).find(String(effect_definition.id)) != -1
	):
		fail("persistent bench effect expiry should still write remove log")
		return
	if not _has_event(core.service("battle_logger").event_log, func(ev):
		return ev.event_type == EventTypesScript.EFFECT_RULE_MOD_REMOVE \
			and String(ev.target_instance_id) == String(switched_unit.unit_instance_id)
	):
		fail("persistent bench rule_mod expiry should still write remove log")
		return

func test_persistent_effect_and_rule_mod_clear_on_faint_contract() -> void:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var content_index = _harness.build_loaded_content_index(sample_factory)
	var resources = _register_persistent_runtime_resources(content_index)
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 502)
	var attacker = battle_state.get_side("P1").get_active_unit()
	var target = battle_state.get_side("P2").get_active_unit()
	if attacker == null or target == null:
		fail("missing active units for persistent faint contract")
		return
	target.current_hp = 1
	if core.service("effect_instance_service").create_instance(
		resources["persistent_effect"],
		target.unit_instance_id,
		battle_state,
		"test_persistent_faint_effect_source",
		0,
		target.base_speed
	) == null:
		fail("failed to create faint-side persistent effect instance")
		return
	var persistent_rule_mod = _build_persistent_rule_mod_payload("test_persistent_faint_group")
	if core.service("rule_mod_service").create_instance(
		persistent_rule_mod,
		{"scope": "unit", "id": target.unit_instance_id},
		battle_state,
		"test_persistent_faint_rule_mod_source",
		0,
		target.base_speed
	) == null:
		fail("failed to create faint-side persistent rule_mod")
		return
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": "sample_strike",
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
		}),
	])
	if _find_effect_instance(target, String(resources["persistent_effect"].id)) != null:
		fail("faint should still clear persistent effects")
		return
	if _find_rule_mod_instance(target, "mp_regen") != null:
		fail("faint should still clear persistent rule_mods")
		return


func _register_persistent_runtime_resources(content_index) -> Dictionary:
	var burst_payload = DamagePayloadScript.new()
	burst_payload.payload_type = "damage"
	burst_payload.amount = 9
	burst_payload.damage_kind = "special"
	var burst_effect = EffectDefinitionScript.new()
	burst_effect.id = "test_persistent_expire_burst"
	burst_effect.display_name = "Persistent Expire Burst"
	burst_effect.scope = "target"
	burst_effect.trigger_names = PackedStringArray(["on_expire"])
	burst_effect.payloads.append(burst_payload)
	content_index.register_resource(burst_effect)

	var stat_payload = StatModPayloadScript.new()
	stat_payload.payload_type = "stat_mod"
	stat_payload.stat_name = "speed"
	stat_payload.stage_delta = 1
	var persistent_effect = EffectDefinitionScript.new()
	persistent_effect.id = "test_persistent_bench_effect"
	persistent_effect.display_name = "Persistent Bench Effect"
	persistent_effect.scope = "self"
	persistent_effect.duration_mode = "turns"
	persistent_effect.duration = 2
	persistent_effect.decrement_on = "turn_end"
	persistent_effect.stacking = "replace"
	persistent_effect.trigger_names = PackedStringArray(["turn_end"])
	persistent_effect.on_expire_effect_ids = PackedStringArray([burst_effect.id])
	persistent_effect.payloads.append(stat_payload)
	persistent_effect.persists_on_switch = true
	content_index.register_resource(persistent_effect)
	return {
		"persistent_effect": persistent_effect,
		"burst_effect": burst_effect,
	}

func _build_persistent_rule_mod_payload(source_group: String):
	var payload = RuleModPayloadScript.new()
	payload.payload_type = "rule_mod"
	payload.mod_kind = "mp_regen"
	payload.mod_op = "add"
	payload.value = 4
	payload.scope = "self"
	payload.duration_mode = "turns"
	payload.duration = 2
	payload.decrement_on = "turn_end"
	payload.stacking = "replace"
	payload.priority = 3
	payload.persists_on_switch = true
	payload.stacking_source_key = source_group
	return payload

func _find_effect_instance(unit_state, effect_id: String):
	for effect_instance in unit_state.effect_instances:
		if String(effect_instance.def_id) == effect_id:
			return effect_instance
	return null

func _find_rule_mod_instance(unit_state, mod_kind: String):
	for rule_mod_instance in unit_state.rule_mod_instances:
		if String(rule_mod_instance.mod_kind) == mod_kind:
			return rule_mod_instance
	return null

func _has_event(event_log: Array, predicate: Callable) -> bool:
	for log_event in event_log:
		if bool(predicate.call(log_event)):
			return true
	return false
