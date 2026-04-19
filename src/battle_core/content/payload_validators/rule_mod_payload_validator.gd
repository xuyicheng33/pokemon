extends RefCounted

const RuleModSchemaScript := preload("res://src/battle_core/content/rule_mod_schema.gd")

var _rule_mod_schema = RuleModSchemaScript.new()

func validate(errors: Array, effect_id: String, payload, content_index: BattleContentIndex, _dispatcher) -> void:
	var rule_mod_errors = _rule_mod_schema.validate_payload(payload, content_index)
	for error_msg in rule_mod_errors:
		errors.append("effect[%s].rule_mod invalid: %s" % [effect_id, error_msg])
