extends RefCounted
class_name ActionSkillEffectService

const ServiceDependencyContractHelperScript := preload("res://src/composition/service_dependency_contract_helper.gd")

const COMPOSE_DEPS := [
	{
		"field": "action_cast_service",
		"source": "action_cast_service",
		"nested": true,
	},
]

var action_cast_service

func resolve_missing_dependency() -> String:
    return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)


func dispatch_trigger(trigger_name: String, skill_definition, queued_action, actor, battle_state, content_index, result) -> void:
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
