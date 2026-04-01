extends RefCounted
class_name ActionGuardStateIntegrityTestSupport

const ChainContextScript := preload("res://src/battle_core/contracts/chain_context.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const RemoveEffectPayloadScript := preload("res://src/battle_core/content/remove_effect_payload.gd")
const FieldDefinitionScript := preload("res://src/battle_core/content/field_definition.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")

func build_chain_context(chain_id: String, actor_id: String, target_id: String):
	var chain_context = ChainContextScript.new()
	chain_context.event_chain_id = chain_id
	chain_context.chain_origin = "action"
	chain_context.command_type = CommandTypesScript.SKILL
	chain_context.command_source = "manual"
	chain_context.actor_id = actor_id
	chain_context.target_unit_id = target_id
	return chain_context

func register_ambiguous_remove_content(content_index, prefix: String, trigger_name: String) -> void:
	var marker_effect = EffectDefinitionScript.new()
	marker_effect.id = "%s_marker" % prefix
	marker_effect.display_name = "%s Marker" % prefix
	marker_effect.scope = "self"
	marker_effect.stacking = "stack"
	content_index.register_resource(marker_effect)

	var remove_payload = RemoveEffectPayloadScript.new()
	remove_payload.payload_type = "remove_effect"
	remove_payload.effect_definition_id = marker_effect.id
	var invalid_remove_effect = EffectDefinitionScript.new()
	invalid_remove_effect.id = "%s_remove" % prefix
	invalid_remove_effect.display_name = "%s Remove" % prefix
	invalid_remove_effect.scope = "target"
	invalid_remove_effect.trigger_names = PackedStringArray([trigger_name])
	invalid_remove_effect.payloads.clear()
	invalid_remove_effect.payloads.append(remove_payload)
	content_index.register_resource(invalid_remove_effect)

	if trigger_name == "on_expire":
		var parent_effect = EffectDefinitionScript.new()
		parent_effect.id = "%s_parent" % prefix
		parent_effect.display_name = "%s Parent" % prefix
		parent_effect.scope = "self"
		parent_effect.duration_mode = "turns"
		parent_effect.duration = 1
		parent_effect.decrement_on = "turn_start"
		parent_effect.on_expire_effect_ids = PackedStringArray([invalid_remove_effect.id])
		content_index.register_resource(parent_effect)
		return

	var invalid_field = FieldDefinitionScript.new()
	invalid_field.id = "%s_field" % prefix
	invalid_field.display_name = "%s Field" % prefix
	invalid_field.on_expire_effect_ids = PackedStringArray([invalid_remove_effect.id])
	content_index.register_resource(invalid_field)
