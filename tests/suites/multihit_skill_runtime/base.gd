extends RefCounted

const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const SkillDamageSegmentScript := preload("res://src/battle_core/content/skill_damage_segment.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const ResourceModPayloadScript := preload("res://src/battle_core/content/resource_mod_payload.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

func _build_multihit_skill(skill_id: String, segments: Array):
    var skill = SkillDefinitionScript.new()
    skill.id = skill_id
    skill.display_name = skill_id
    skill.damage_kind = "special"
    skill.power = 0
    skill.accuracy = 100
    skill.mp_cost = 0
    skill.priority = 0
    skill.targeting = "enemy_active_slot"
    var built_segments: Array[Resource] = []
    for segment_data in segments:
        var segment = SkillDamageSegmentScript.new()
        segment.repeat_count = int(segment_data.get("repeat_count", 1))
        segment.power = int(segment_data.get("power", 0))
        segment.combat_type_id = String(segment_data.get("combat_type_id", ""))
        segment.damage_kind = String(segment_data.get("damage_kind", "special"))
        built_segments.append(segment)
    skill.damage_segments = built_segments
    return skill

func _build_mp_loss_effect(effect_id: String, trigger_name: String, mp_delta: int):
    var effect = EffectDefinitionScript.new()
    effect.id = effect_id
    effect.display_name = effect_id
    effect.scope = "self"
    effect.duration_mode = "permanent"
    effect.trigger_names = PackedStringArray([trigger_name])
    var payload = ResourceModPayloadScript.new()
    payload.payload_type = "resource_mod"
    payload.resource_key = "mp"
    payload.amount = mp_delta
    effect.payloads.append(payload)
    return effect

func _build_filtered_on_hit_mp_loss_effect(effect_id: String, combat_type_id: String, mp_delta: int):
    var effect = _build_mp_loss_effect(effect_id, "on_receive_action_hit", mp_delta)
    effect.required_incoming_command_types = PackedStringArray(["skill"])
    effect.required_incoming_combat_type_ids = PackedStringArray([combat_type_id])
    return effect

func _build_filtered_on_segment_mp_loss_effect(effect_id: String, command_type: String, combat_type_id: String, mp_delta: int):
    var effect = _build_mp_loss_effect(effect_id, "on_receive_action_damage_segment", mp_delta)
    effect.required_incoming_command_types = PackedStringArray([command_type])
    effect.required_incoming_combat_type_ids = PackedStringArray([combat_type_id])
    return effect

func _collect_actor_damage_events(event_log: Array, actor_public_id: String) -> Array:
    var matched: Array = []
    for log_event in event_log:
        if log_event.event_type != EventTypesScript.EFFECT_DAMAGE:
            continue
        if String(log_event.payload_summary).begins_with("%s dealt " % actor_public_id):
            matched.append(log_event)
    return matched

func _calc_expected_damage(core, battle_state, actor, target, power: int, combat_type_id: String, incoming_multiplier: float) -> int:
    var type_effectiveness: float = core.service("combat_type_service").calc_effectiveness(combat_type_id, target.combat_type_ids)
    return core.service("damage_service").apply_final_mod(
        core.service("damage_service").calc_base_damage(
            battle_state.battle_level,
            power,
            actor.base_sp_attack,
            target.base_sp_defense
        ),
        incoming_multiplier * type_effectiveness
    )

func _has_error(errors: Array, expected_error: String) -> bool:
    for error_message in errors:
        if String(error_message) == expected_error:
            return true
    return false
