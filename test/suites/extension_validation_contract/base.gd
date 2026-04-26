extends "res://tests/support/gdunit_suite_bridge.gd"

const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const HealPayloadScript := preload("res://src/battle_core/content/heal_payload.gd")
const ResourceModPayloadScript := preload("res://src/battle_core/content/resource_mod_payload.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
const ApplyFieldPayloadScript := preload("res://src/battle_core/content/apply_field_payload.gd")
const ApplyEffectPayloadScript := preload("res://src/battle_core/content/apply_effect_payload.gd")
const RemoveEffectPayloadScript := preload("res://src/battle_core/content/remove_effect_payload.gd")

func _has_error(errors: Array, needle: String) -> bool:
	for error_msg in errors:
		if String(error_msg).find(needle) != -1:
			return true
	return false

# Run a single character formal-validator bad case. Each per-character suite
# stays as a thin shim that defines its own `func test_*` entries and routes
# them through this helper with a case-specific mutator.
#
# `mutator(content_index) -> String` returns "" on success, or a reason string
# explaining why the mutator could not run (e.g. a missing fixture) — that
# reason becomes the test failure message.
func _run_validator_bad_case(needle: String, label: String, mutator: Callable) -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var content_index = _harness.build_loaded_content_index(sample_factory)
	var mutator_error: String = String(mutator.call(content_index))
	if not mutator_error.is_empty():
		fail(mutator_error)
		return
	var errors: Array = content_index.validate_snapshot()
	if not _has_error(errors, needle):
		fail(label)
		return
