extends RefCounted
class_name ContentSnapshotFormalSukunaValidator

const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")

func validate(content_index, errors: Array) -> void:
    _validate_matching_damage_payloads(
        content_index,
        errors,
        "formal[sukuna].shared_fire_burst",
        PackedStringArray(["sukuna_kamado_mark", "sukuna_kamado_explode", "sukuna_domain_expire_burst"])
    )

func _validate_matching_damage_payloads(content_index, errors: Array, label: String, effect_ids: PackedStringArray) -> void:
    var baseline_fingerprint: Dictionary = {}
    var baseline_effect_id := ""
    for raw_effect_id in effect_ids:
        var effect_id := String(raw_effect_id)
        var effect_definition = content_index.effects.get(effect_id, null)
        if effect_definition == null:
            return
        var damage_payload = _extract_single_damage_payload(errors, label, effect_id, effect_definition)
        if damage_payload == null:
            continue
        var fingerprint := {
            "amount": int(damage_payload.amount),
            "use_formula": bool(damage_payload.use_formula),
            "combat_type_id": String(damage_payload.combat_type_id),
        }
        if baseline_effect_id.is_empty():
            baseline_effect_id = effect_id
            baseline_fingerprint = fingerprint
            continue
        if fingerprint != baseline_fingerprint:
            errors.append("%s payload mismatch: effect[%s]=%s expected effect[%s]=%s" % [
                label,
                effect_id,
                var_to_str(fingerprint),
                baseline_effect_id,
                var_to_str(baseline_fingerprint),
            ])

func _extract_single_damage_payload(errors: Array, label: String, effect_id: String, effect_definition):
    var damage_payload = null
    var damage_payload_count := 0
    for payload in effect_definition.payloads:
        if payload is DamagePayloadScript:
            damage_payload_count += 1
            if damage_payload == null:
                damage_payload = payload
    if damage_payload_count != 1:
        errors.append("%s effect[%s] must define exactly one damage payload, got %d" % [label, effect_id, damage_payload_count])
        return null
    return damage_payload
