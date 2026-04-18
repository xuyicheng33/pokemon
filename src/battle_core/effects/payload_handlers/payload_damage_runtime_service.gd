extends RefCounted
class_name PayloadDamageRuntimeService

const ServiceDependencyContractHelperScript := preload("res://src/composition/service_dependency_contract_helper.gd")

const COMPOSE_DEPS := [
	{
		"field": "battle_logger",
		"source": "battle_logger",
		"nested": true,
	},
	{
		"field": "log_event_builder",
		"source": "log_event_builder",
		"nested": true,
	},
	{
		"field": "damage_service",
		"source": "damage_service",
		"nested": true,
	},
	{
		"field": "combat_type_service",
		"source": "combat_type_service",
		"nested": true,
	},
	{
		"field": "stat_calculator",
		"source": "stat_calculator",
		"nested": true,
	},
	{
		"field": "rule_mod_service",
		"source": "rule_mod_service",
		"nested": true,
	},
	{
		"field": "faint_killer_attribution_service",
		"source": "faint_killer_attribution_service",
		"nested": true,
	},
	{
		"field": "target_helper",
		"source": "payload_unit_target_helper",
		"nested": true,
	},
	{
		"field": "effect_event_helper",
		"source": "payload_effect_event_helper",
		"nested": true,
	},
]

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const ValueChangeFactoryScript := preload("res://src/battle_core/contracts/value_change_factory.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var battle_logger
var log_event_builder
var damage_service
var combat_type_service
var stat_calculator
var rule_mod_service
var faint_killer_attribution_service
var target_helper
var effect_event_helper
var last_invalid_battle_code: Variant = null

func invalid_battle_code() -> Variant:
    return last_invalid_battle_code

func resolve_missing_dependency() -> String:
    return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)


func apply_damage_payload(payload, effect_definition, effect_event, battle_state, content_index) -> void:
    last_invalid_battle_code = null
    var target_unit = target_helper.resolve_target_unit(effect_definition.scope, effect_event, battle_state)
    if not target_helper.is_effect_target_valid(target_unit, effect_definition.scope, effect_event):
        return
    var amount: int = payload.amount
    var type_effectiveness: float = 1.0
    if payload.use_formula:
        var actor_unit = battle_state.get_unit(effect_event.owner_id)
        if actor_unit == null:
            return
        var formula_skill_definition = _resolve_chain_skill_definition(effect_event, content_index)
        var damage_kind := _resolve_formula_damage_kind(payload, formula_skill_definition)
        var attack_stat_name := "attack"
        var defense_stat_name := "defense"
        var attack_value: int = actor_unit.base_attack
        var defense_value: int = target_unit.base_defense
        if damage_kind == ContentSchemaScript.DAMAGE_KIND_SPECIAL:
            attack_stat_name = "sp_attack"
            defense_stat_name = "sp_defense"
            attack_value = actor_unit.base_sp_attack
            defense_value = target_unit.base_sp_defense
        attack_value = stat_calculator.calc_effective_stat(attack_value, actor_unit.get_effective_stage(attack_stat_name))
        defense_value = stat_calculator.calc_effective_stat(defense_value, target_unit.get_effective_stage(defense_stat_name))
        type_effectiveness = combat_type_service.calc_effectiveness(
            _resolve_skill_combat_type_id(formula_skill_definition),
            _resolve_unit_combat_types(target_unit)
        )
        amount = damage_service.apply_final_mod(
            damage_service.calc_base_damage(
                battle_state.battle_level,
                max(1, amount),
                attack_value,
                defense_value
            ),
            rule_mod_service.get_final_multiplier(battle_state, effect_event.owner_id) * type_effectiveness
        )
    elif not String(payload.combat_type_id).is_empty():
        type_effectiveness = combat_type_service.calc_effectiveness(
            String(payload.combat_type_id),
            _resolve_unit_combat_types(target_unit)
        )
        amount = damage_service.apply_final_mod(max(1, amount), type_effectiveness)
    _apply_hp_change(
        battle_state,
        effect_event,
        target_unit,
        -max(1, amount),
        EventTypesScript.EFFECT_DAMAGE,
        payload.payload_type if not payload.payload_type.is_empty() else "damage",
        type_effectiveness
    )

func _apply_hp_change(battle_state, effect_event, target_unit, delta: int, event_type: String, summary_tag: String, type_effectiveness: Variant = null) -> void:
    var is_damage_event := event_type == EventTypesScript.EFFECT_DAMAGE
    if (is_damage_event and type_effectiveness == null) or (not is_damage_event and type_effectiveness != null):
        last_invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
        return
    if type_effectiveness != null and typeof(type_effectiveness) != TYPE_FLOAT:
        last_invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
        return
    var before_value: int = target_unit.current_hp
    target_unit.current_hp = clamp(target_unit.current_hp + delta, 0, target_unit.max_hp)
    if before_value == target_unit.current_hp:
        return
    var value_change = _build_value_change(target_unit.unit_instance_id, "hp", before_value, target_unit.current_hp)
    var log_event = log_event_builder.build_event(
        event_type,
        battle_state,
        {
            "source_instance_id": effect_event.source_instance_id,
            "target_instance_id": target_unit.unit_instance_id,
            "priority": effect_event.priority,
            "trigger_name": effect_event.trigger_name,
            "cause_event_id": effect_event.event_id,
            "effect_roll": effect_event_helper.resolve_effect_roll(effect_event),
            "type_effectiveness": type_effectiveness if is_damage_event else null,
            "value_changes": [value_change],
            "payload_summary": "%s %s %+d" % [target_unit.public_id, summary_tag, value_change.delta],
        }
    )
    battle_logger.append_event(log_event)
    if log_event == null:
        last_invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
        return
    if is_damage_event:
        faint_killer_attribution_service.record_fatal_damage(
            battle_state,
            target_unit.unit_instance_id,
            before_value,
            target_unit.current_hp,
            effect_event.owner_id,
            effect_event.source_instance_id,
            effect_event.source_kind_order,
            effect_event.source_order_speed_snapshot,
            effect_event.priority,
            log_event.event_step_id
        )

func _build_value_change(entity_id: String, resource_name: String, before_value: int, after_value: int) -> Variant:
    return ValueChangeFactoryScript.create(entity_id, resource_name, before_value, after_value)

func _resolve_chain_skill_definition(effect_event, content_index) -> Variant:
    if effect_event == null or effect_event.chain_context == null:
        return null
    var raw_skill_id = effect_event.chain_context.skill_id
    if raw_skill_id == null or content_index == null:
        return null
    var skill_id := str(raw_skill_id)
    if skill_id.is_empty():
        return null
    return content_index.skills.get(skill_id, null)

func _resolve_skill_combat_type_id(skill_definition) -> String:
    return "" if skill_definition == null or skill_definition.combat_type_id == null else str(skill_definition.combat_type_id)

func _resolve_formula_damage_kind(payload, skill_definition) -> String:
    if skill_definition != null:
        var skill_damage_kind := str(skill_definition.damage_kind)
        if skill_damage_kind == ContentSchemaScript.DAMAGE_KIND_PHYSICAL or skill_damage_kind == ContentSchemaScript.DAMAGE_KIND_SPECIAL:
            return skill_damage_kind
    return ContentSchemaScript.DAMAGE_KIND_SPECIAL if str(payload.damage_kind) == ContentSchemaScript.DAMAGE_KIND_SPECIAL else ContentSchemaScript.DAMAGE_KIND_PHYSICAL

func _resolve_unit_combat_types(target_unit) -> PackedStringArray:
    if target_unit == null or target_unit.combat_type_ids == null:
        return PackedStringArray()
    return target_unit.combat_type_ids
