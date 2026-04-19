extends RefCounted
class_name ActionSkillEffectService

var action_cast_service: ActionCastService


func dispatch_trigger(trigger_name: String, skill_definition, queued_action: QueuedAction, actor, battle_state: BattleState, content_index: BattleContentIndex, result) -> void:
	action_cast_service.dispatch_skill_effects(
		_resolve_effect_ids(trigger_name, skill_definition),
		trigger_name,
		queued_action,
		actor,
		battle_state,
		content_index,
		result
	)

func _resolve_effect_ids(trigger_name: String, skill_definition) -> PackedStringArray:
	if skill_definition == null:
		return PackedStringArray()
	match trigger_name:
		"on_cast":
			return skill_definition.effects_on_cast_ids
		"on_miss":
			return skill_definition.effects_on_miss_ids
		"on_hit":
			return skill_definition.effects_on_hit_ids
	return PackedStringArray()
