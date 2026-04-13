extends "res://test/support/gdunit_suite_bridge.gd"

const BattleContentIndexScript := preload("res://src/battle_core/content/battle_content_index.gd")
const BattleFormatConfigScript := preload("res://src/battle_core/content/battle_format_config.gd")
const PassiveItemDefinitionScript := preload("res://src/battle_core/content/passive_item_definition.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const UnitDefinitionScript := preload("res://src/battle_core/content/unit_definition.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
const ResourceModPayloadScript := preload("res://src/battle_core/content/resource_mod_payload.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const FormalCharacterValidatorRegistryScript := preload("res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_registry.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

func _build_dynamic_formula_effect(effect_id: String, scope: String, thresholds: PackedInt32Array, outputs: PackedFloat32Array, dynamic_default: float = 0.0):
    var payload = RuleModPayloadScript.new()
    payload.mod_kind = "mp_regen"
    payload.mod_op = "set"
    payload.scope = scope
    payload.duration_mode = "turns"
    payload.duration = 1
    payload.decrement_on = "turn_start"
    payload.stacking = "replace"
    payload.dynamic_value_formula = ContentSchemaScript.RULE_MOD_VALUE_FORMULA_MATCHUP_BST_GAP_BAND
    payload.dynamic_value_thresholds = thresholds
    payload.dynamic_value_outputs = outputs
    payload.dynamic_value_default = dynamic_default
    var effect = EffectDefinitionScript.new()
    effect.id = effect_id
    effect.scope = scope
    effect.trigger_names = PackedStringArray(["on_cast"])
    effect.payloads.clear()
    effect.payloads.append(payload)
    return effect

func _build_filtered_snapshot_paths(harness, sample_factory, excluded_tokens: PackedStringArray) -> Variant:
    var snapshot_paths_payload: Dictionary = harness.build_content_snapshot_paths(sample_factory)
    if snapshot_paths_payload.has("error"):
        return {"error": str(snapshot_paths_payload.get("error", "content snapshot path build failed"))}
    var filtered_paths: PackedStringArray = PackedStringArray()
    for raw_path in snapshot_paths_payload.get("paths", PackedStringArray()):
        var path := String(raw_path)
        var should_exclude := false
        for raw_token in excluded_tokens:
            if path.find(String(raw_token)) != -1:
                should_exclude = true
                break
        if should_exclude:
            continue
        filtered_paths.append(path)
    return filtered_paths
