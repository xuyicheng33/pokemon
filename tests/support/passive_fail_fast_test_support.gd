extends RefCounted
class_name PassiveFailFastTestSupport

const PassiveSkillDefinitionScript := preload("res://src/battle_core/content/passive_skill_definition.gd")
const PassiveItemDefinitionScript := preload("res://src/battle_core/content/passive_item_definition.gd")

func register_invalid_passive_skill(
	content_index,
	unit_definition_id: String,
	passive_id: String = "test_invalid_passive_skill",
	trigger_name: String = "turn_start"
) -> void:
	var passive_definition = PassiveSkillDefinitionScript.new()
	passive_definition.id = passive_id
	passive_definition.display_name = "Invalid Passive Skill"
	passive_definition.trigger_names = PackedStringArray([trigger_name])
	passive_definition.effect_ids = PackedStringArray(["missing_%s_effect" % passive_id])
	content_index.register_resource(passive_definition)
	var unit_definition = content_index.units.get(unit_definition_id, null)
	if unit_definition != null:
		unit_definition.passive_skill_id = passive_id

func register_invalid_passive_item(
	content_index,
	unit_definition_id: String,
	passive_id: String = "test_invalid_passive_item"
) -> void:
	var passive_definition = PassiveItemDefinitionScript.new()
	passive_definition.id = passive_id
	passive_definition.display_name = "Invalid Passive Item"
	passive_definition.on_turn_effect_ids = PackedStringArray(["missing_%s_effect" % passive_id])
	content_index.register_resource(passive_definition)
	var unit_definition = content_index.units.get(unit_definition_id, null)
	if unit_definition != null:
		unit_definition.passive_item_id = passive_id
