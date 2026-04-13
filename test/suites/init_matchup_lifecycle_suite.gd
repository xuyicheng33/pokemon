extends "res://test/support/gdunit_suite_bridge.gd"

const PassiveSkillDefinitionScript := preload("res://src/battle_core/content/passive_skill_definition.gd")
const PassiveItemDefinitionScript := preload("res://src/battle_core/content/passive_item_definition.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
const ResourceModPayloadScript := preload("res://src/battle_core/content/resource_mod_payload.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")



func test_on_matchup_changed_dedup_path() -> void:
	_assert_legacy_result(_test_on_matchup_changed_dedup_path(_harness))

func test_battle_init_replacement_retriggers_matchup_changed() -> void:
	_assert_legacy_result(_test_battle_init_replacement_retriggers_matchup_changed(_harness))

func test_init_chain_order() -> void:
	_assert_legacy_result(_test_init_chain_order(_harness))
func _test_on_matchup_changed_dedup_path(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var payload = ResourceModPayloadScript.new()
	payload.payload_type = "resource_mod"
	payload.resource_key = "mp"
	payload.amount = 1
	var effect = EffectDefinitionScript.new()
	effect.id = "test_matchup_changed_regen_effect"
	effect.display_name = "Matchup Changed Regen"
	effect.scope = "self"
	effect.trigger_names = PackedStringArray(["on_matchup_changed"])
	effect.payloads.clear()
	effect.payloads.append(payload)
	content_index.register_resource(effect)
	var passive = PassiveSkillDefinitionScript.new()
	passive.id = "test_matchup_changed_regen_passive"
	passive.display_name = "Matchup Changed Regen Passive"
	passive.trigger_names = PackedStringArray(["on_matchup_changed"])
	passive.effect_ids = PackedStringArray([effect.id])
	content_index.register_resource(passive)
	content_index.units["sample_pyron"].passive_skill_id = passive.id
	content_index.units["sample_tidekit"].passive_skill_id = passive.id
	content_index.units["sample_mossaur"].passive_skill_id = passive.id
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 37)
	var pre_turn_matchup_events: int = 0
	for ev in core.service("battle_logger").event_log:
		if ev.event_type == EventTypesScript.EFFECT_RESOURCE_MOD and ev.trigger_name == "on_matchup_changed" and str(ev.source_instance_id).begins_with("passive_skill:"):
			pre_turn_matchup_events += 1
	if pre_turn_matchup_events != 2:
		return harness.fail_result("initial matchup_changed should trigger exactly once for each active unit")
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		core.service("command_builder").build_command({"turn_index": 1, "command_type": CommandTypesScript.SWITCH, "command_source": "manual", "side_id": "P1", "actor_public_id": "P1-A", "target_public_id": "P1-B"}),
		core.service("command_builder").build_command({"turn_index": 1, "command_type": CommandTypesScript.WAIT, "command_source": "manual", "side_id": "P2", "actor_public_id": "P2-A"}),
	])
	var total_matchup_events: int = 0
	for ev in core.service("battle_logger").event_log:
		if ev.event_type == EventTypesScript.EFFECT_RESOURCE_MOD and ev.trigger_name == "on_matchup_changed" and str(ev.source_instance_id).begins_with("passive_skill:"):
			total_matchup_events += 1
	if total_matchup_events != 4:
		return harness.fail_result("matchup_changed should trigger exactly once after the stable switch matchup")
	return harness.pass_result()

func _test_battle_init_replacement_retriggers_matchup_changed(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var matchup_payload = ResourceModPayloadScript.new()
	matchup_payload.payload_type = "resource_mod"
	matchup_payload.resource_key = "mp"
	matchup_payload.amount = 1
	var matchup_effect = EffectDefinitionScript.new()
	matchup_effect.id = "test_battle_init_matchup_changed_regen_effect"
	matchup_effect.display_name = "Battle Init Matchup Changed Regen"
	matchup_effect.scope = "self"
	matchup_effect.trigger_names = PackedStringArray(["on_matchup_changed"])
	matchup_effect.payloads.clear()
	matchup_effect.payloads.append(matchup_payload)
	content_index.register_resource(matchup_effect)
	var matchup_passive = PassiveSkillDefinitionScript.new()
	matchup_passive.id = "test_battle_init_matchup_changed_regen_passive"
	matchup_passive.display_name = "Battle Init Matchup Changed Regen Passive"
	matchup_passive.trigger_names = PackedStringArray(["on_matchup_changed"])
	matchup_passive.effect_ids = PackedStringArray([matchup_effect.id])
	content_index.register_resource(matchup_passive)
	content_index.units["sample_pyron"].passive_skill_id = matchup_passive.id
	content_index.units["sample_mossaur"].passive_skill_id = matchup_passive.id
	content_index.units["sample_tidekit"].passive_skill_id = matchup_passive.id
	var self_faint_payload = DamagePayloadScript.new()
	self_faint_payload.payload_type = "damage"
	self_faint_payload.amount = 999
	self_faint_payload.use_formula = false
	var self_faint_effect = EffectDefinitionScript.new()
	self_faint_effect.id = "test_battle_init_self_faint_effect"
	self_faint_effect.display_name = "Battle Init Self Faint"
	self_faint_effect.scope = "self"
	self_faint_effect.trigger_names = PackedStringArray(["battle_init"])
	self_faint_effect.payloads.clear()
	self_faint_effect.payloads.append(self_faint_payload)
	content_index.register_resource(self_faint_effect)
	var self_faint_item = PassiveItemDefinitionScript.new()
	self_faint_item.id = "test_battle_init_self_faint_item"
	self_faint_item.display_name = "Battle Init Self Faint Item"
	self_faint_item.trigger_names = PackedStringArray(["battle_init"])
	self_faint_item.effect_ids = PackedStringArray([self_faint_effect.id])
	content_index.register_resource(self_faint_item)
	content_index.units["sample_pyron"].passive_item_id = self_faint_item.id
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 43)
	var active_unit = battle_state.get_side("P1").get_active_unit()
	if active_unit == null or active_unit.public_id != "P1-B":
		return harness.fail_result("battle_init faint window should replace P1 active with bench unit before selection")
	var matchup_events: int = 0
	for ev in core.service("battle_logger").event_log:
		if ev.event_type == EventTypesScript.EFFECT_RESOURCE_MOD and ev.trigger_name == "on_matchup_changed" and str(ev.source_instance_id).begins_with("passive_skill:"):
			matchup_events += 1
	if matchup_events != 4:
		return harness.fail_result("battle_init replacement should retrigger matchup_changed for the new stable matchup")
	return harness.pass_result()

func _test_init_chain_order(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var enter_payload = StatModPayloadScript.new()
	enter_payload.payload_type = "stat_mod"
	enter_payload.stat_name = "attack"
	enter_payload.stage_delta = 1
	var enter_effect = EffectDefinitionScript.new()
	enter_effect.id = "test_enter_stat_mod"
	enter_effect.display_name = "Test Enter Stat Mod"
	enter_effect.scope = "self"
	enter_effect.trigger_names = PackedStringArray(["on_enter"])
	enter_effect.payloads.clear()
	enter_effect.payloads.append(enter_payload)
	var enter_passive = PassiveSkillDefinitionScript.new()
	enter_passive.id = "test_passive_on_enter"
	enter_passive.display_name = "Test Passive On Enter"
	enter_passive.trigger_names = PackedStringArray(["on_enter"])
	enter_passive.effect_ids = PackedStringArray([enter_effect.id])
	content_index.register_resource(enter_effect)
	content_index.register_resource(enter_passive)
	var init_payload = ResourceModPayloadScript.new()
	init_payload.payload_type = "resource_mod"
	init_payload.resource_key = "mp"
	init_payload.amount = 3
	var init_effect = EffectDefinitionScript.new()
	init_effect.id = "test_battle_init_mp_mod"
	init_effect.display_name = "Test Battle Init MP Mod"
	init_effect.scope = "self"
	init_effect.trigger_names = PackedStringArray(["battle_init"])
	init_effect.payloads.clear()
	init_effect.payloads.append(init_payload)
	var init_item = PassiveItemDefinitionScript.new()
	init_item.id = "test_item_on_battle_init"
	init_item.display_name = "Test Item On Battle Init"
	init_item.trigger_names = PackedStringArray(["battle_init"])
	init_item.effect_ids = PackedStringArray([init_effect.id])
	content_index.register_resource(init_effect)
	content_index.register_resource(init_item)
	content_index.units["sample_pyron"].passive_skill_id = enter_passive.id
	content_index.units["sample_pyron"].passive_item_id = init_item.id
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 101)
	if battle_state.battle_result.finished:
		return harness.fail_result("battle finished during initialization")
	var enter_effect_idx := -1
	var battle_init_idx := -1
	var init_effect_idx := -1
	for i in range(core.service("battle_logger").event_log.size()):
		var ev = core.service("battle_logger").event_log[i]
		if enter_effect_idx == -1 and ev.event_type == EventTypesScript.EFFECT_STAT_MOD and str(ev.source_instance_id).begins_with("passive_skill:"):
			enter_effect_idx = i
		if battle_init_idx == -1 and ev.event_type == EventTypesScript.SYSTEM_BATTLE_INIT:
			battle_init_idx = i
		if init_effect_idx == -1 and ev.event_type == EventTypesScript.EFFECT_RESOURCE_MOD and str(ev.source_instance_id).begins_with("passive_item:"):
			init_effect_idx = i
	if enter_effect_idx == -1 or battle_init_idx == -1 or init_effect_idx == -1:
		return harness.fail_result("missing init-chain events")
	if not (enter_effect_idx < battle_init_idx and battle_init_idx < init_effect_idx):
		return harness.fail_result("on_enter -> battle_init ordering mismatch")
	return harness.pass_result()
