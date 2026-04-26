extends "res://tests/support/gdunit_suite_bridge.gd"

const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const ForcedReplacePayloadScript := preload("res://src/battle_core/content/forced_replace_payload.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

class TestReplacementSelector:
	extends "res://src/battle_core/lifecycle/replacement_selector.gd"

	var next_selection: Variant = null

	func select_replacement(_battle_state, _side_id: String, _legal_bench_ids: PackedStringArray, _reason: String, _chain_context):
		return next_selection


func test_forced_replace_invalid_selection() -> void:
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

	var forced_payload = ForcedReplacePayloadScript.new()
	forced_payload.payload_type = "forced_replace"
	forced_payload.scope = "target"
	forced_payload.selector_reason = "forced_replace"
	var forced_effect = EffectDefinitionScript.new()
	forced_effect.id = "test_forced_replace_invalid_effect"
	forced_effect.display_name = "Forced Replace Invalid Selection Effect"
	forced_effect.scope = "target"
	forced_effect.trigger_names = PackedStringArray(["on_cast"])
	forced_effect.payloads.clear()
	forced_effect.payloads.append(forced_payload)
	content_index.register_resource(forced_effect)

	var forced_skill = SkillDefinitionScript.new()
	forced_skill.id = "test_forced_replace_invalid_skill"
	forced_skill.display_name = "Forced Replace Invalid Selection Skill"
	forced_skill.damage_kind = "none"
	forced_skill.power = 0
	forced_skill.accuracy = 100
	forced_skill.mp_cost = 0
	forced_skill.priority = 0
	forced_skill.targeting = "enemy_active_slot"
	forced_skill.effects_on_cast_ids = PackedStringArray([forced_effect.id])
	content_index.register_resource(forced_skill)
	if not content_index.units["sample_pyron"].skill_ids.has(forced_skill.id):
		content_index.units["sample_pyron"].skill_ids[0] = forced_skill.id

	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 221)
	var p1_active = battle_state.get_side("P1").get_active_unit()
	if p1_active == null:
		fail("missing P1 active unit for forced_replace invalid test")
		return
	p1_active.base_speed = 999

	var selector := TestReplacementSelector.new()
	selector.next_selection = "unit_not_in_bench"
	core.service("replacement_service").replacement_selector = selector

	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": forced_skill.id,
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
			"skill_id": "sample_whiff",
		}),
	])
	if not battle_state.battle_result.finished:
		fail("invalid replacement selection should end battle immediately")
		return
	if battle_state.battle_result.reason != ErrorCodesScript.INVALID_REPLACEMENT_SELECTION:
		fail("expected invalid_replacement_selection, got %s" % str(battle_state.battle_result.reason))
		return
	for ev in core.service("battle_logger").event_log:
		if ev.event_type == EventTypesScript.SYSTEM_INVALID_BATTLE and ev.invalid_battle_code == ErrorCodesScript.INVALID_REPLACEMENT_SELECTION:
			return
	fail("missing invalid_battle log for invalid replacement selection")
