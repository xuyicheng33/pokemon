extends RefCounted
class_name ContentSnapshotFormalKashimoContracts

const ApplyEffectPayloadScript := preload("res://src/battle_core/content/apply_effect_payload.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const ResourceModPayloadScript := preload("res://src/battle_core/content/resource_mod_payload.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")

func validate_unit_contract(validator, content_index, errors: Array) -> void:
	var label := "formal[kashimo].unit"
	var unit_definition = validator._require_unit(content_index, errors, label, "kashimo_hajime")
	if unit_definition == null:
		return
	validator._expect_string(errors, "%s display_name" % label, unit_definition.display_name, "鹿紫云一")
	validator._expect_int(errors, "%s base_hp" % label, unit_definition.base_hp, 118)
	validator._expect_int(errors, "%s base_attack" % label, unit_definition.base_attack, 82)
	validator._expect_int(errors, "%s base_defense" % label, unit_definition.base_defense, 58)
	validator._expect_int(errors, "%s base_sp_attack" % label, unit_definition.base_sp_attack, 72)
	validator._expect_int(errors, "%s base_sp_defense" % label, unit_definition.base_sp_defense, 54)
	validator._expect_int(errors, "%s base_speed" % label, unit_definition.base_speed, 90)
	validator._expect_int(errors, "%s max_mp" % label, unit_definition.max_mp, 100)
	validator._expect_int(errors, "%s init_mp" % label, unit_definition.init_mp, 40)
	validator._expect_int(errors, "%s regen_per_turn" % label, unit_definition.regen_per_turn, 10)
	validator._expect_int(errors, "%s ultimate_points_required" % label, unit_definition.ultimate_points_required, 3)
	validator._expect_int(errors, "%s ultimate_points_cap" % label, unit_definition.ultimate_points_cap, 3)
	validator._expect_int(errors, "%s ultimate_point_gain_on_regular_skill_cast" % label, unit_definition.ultimate_point_gain_on_regular_skill_cast, 1)
	validator._expect_packed_string_array(errors, "%s combat_type_ids" % label, unit_definition.combat_type_ids, PackedStringArray(["thunder", "fighting"]))
	validator._expect_packed_string_array(errors, "%s skill_ids" % label, unit_definition.skill_ids, PackedStringArray(["kashimo_raiken", "kashimo_charge", "kashimo_feedback_strike"]))
	validator._expect_packed_string_array(errors, "%s candidate_skill_ids" % label, unit_definition.candidate_skill_ids, PackedStringArray(["kashimo_raiken", "kashimo_charge", "kashimo_feedback_strike", "kashimo_kyokyo_katsura"]))
	validator._expect_string(errors, "%s ultimate_skill_id" % label, unit_definition.ultimate_skill_id, "kashimo_phantom_beast_amber")
	validator._expect_string(errors, "%s passive_skill_id" % label, unit_definition.passive_skill_id, "kashimo_charge_separation")
func validate_core_skill_contract(validator, content_index, errors: Array) -> void:
	_validate_skill_contract(
		validator,
		content_index,
		errors,
		"formal[kashimo].raiken",
		"kashimo_raiken",
		{
			"display_name": "雷拳",
			"damage_kind": "physical",
			"power": 45,
			"accuracy": 100,
			"mp_cost": 12,
			"priority": 1,
			"combat_type_id": "thunder",
			"targeting": "enemy_active_slot",
			"effects_on_hit_ids": PackedStringArray(["kashimo_apply_negative_charge"]),
		}
	)
	_validate_skill_contract(validator, content_index, errors, "formal[kashimo].charge", "kashimo_charge", {
		"display_name": "蓄电", "damage_kind": "none", "power": 0, "accuracy": 100,
		"mp_cost": 8, "priority": 0, "combat_type_id": "", "targeting": "self",
		"effects_on_cast_ids": PackedStringArray(["kashimo_apply_positive_charge"]),
	})
	_validate_skill_contract(validator, content_index, errors, "formal[kashimo].feedback_strike", "kashimo_feedback_strike", {
		"display_name": "回授电击", "damage_kind": "special", "power": 30, "accuracy": 100,
		"mp_cost": 15, "priority": 0, "combat_type_id": "thunder", "targeting": "enemy_active_slot",
		"power_bonus_source": "effect_stack_sum",
		"effects_on_hit_ids": PackedStringArray(["kashimo_consume_positive_charges", "kashimo_consume_negative_charges"]),
	})
	_validate_skill_contract(validator, content_index, errors, "formal[kashimo].kyokyo", "kashimo_kyokyo_katsura", {
		"display_name": "弥虚葛笼", "damage_kind": "none", "power": 0, "accuracy": 100,
		"mp_cost": 20, "priority": 2, "combat_type_id": "", "targeting": "self",
		"effects_on_cast_ids": PackedStringArray(["kashimo_kyokyo_nullify"]),
	})
	_validate_skill_contract(
		validator,
		content_index,
		errors,
		"formal[kashimo].amber",
		"kashimo_phantom_beast_amber",
		{
			"display_name": "幻兽琥珀",
			"damage_kind": "special",
			"power": 60,
			"accuracy": 100,
			"mp_cost": 35,
			"priority": 5,
			"combat_type_id": "thunder",
			"targeting": "enemy_active_slot",
			"is_domain_skill": false,
			"effects_on_cast_ids": PackedStringArray(["kashimo_amber_self_transform"]),
		}
	)
func validate_charge_separation_contract(validator, content_index, errors: Array) -> void:
	var label := "formal[kashimo].charge_separation"
	var passive_definition = validator._require_passive_skill(content_index, errors, label, "kashimo_charge_separation")
	if passive_definition != null:
		validator._expect_packed_string_array(errors, "%s passive.trigger_names" % label, passive_definition.trigger_names, PackedStringArray(["on_enter"]))
		validator._expect_packed_string_array(errors, "%s passive.effect_ids" % label, passive_definition.effect_ids, PackedStringArray(["kashimo_thunder_resist", "kashimo_apply_water_leak_listeners"]))
func validate_feedback_strike_contract(validator, content_index, errors: Array) -> void:
	var label := "formal[kashimo].feedback_strike"
	var skill_definition = validator._require_skill(content_index, errors, label, "kashimo_feedback_strike")
	if skill_definition == null:
		return
	validator._expect_string(errors, "%s power_bonus_source" % label, skill_definition.power_bonus_source, "effect_stack_sum")
	validator._expect_packed_string_array(errors, "%s power_bonus_self_effect_ids" % label, skill_definition.power_bonus_self_effect_ids, PackedStringArray(["kashimo_positive_charge_mark"]))
	validator._expect_packed_string_array(errors, "%s power_bonus_target_effect_ids" % label, skill_definition.power_bonus_target_effect_ids, PackedStringArray(["kashimo_negative_charge_mark"]))
	validator._expect_int(errors, "%s power_bonus_per_stack" % label, skill_definition.power_bonus_per_stack, 12)
func validate_kyokyo_contract(validator, content_index, errors: Array) -> void:
	var label := "formal[kashimo].kyokyo"
	var effect_definition = validator._require_effect(content_index, errors, label, "kashimo_kyokyo_nullify")
	if effect_definition == null:
		return
	validator._expect_string(errors, "%s effect.scope" % label, effect_definition.scope, "self")
	validator._expect_string(errors, "%s effect.duration_mode" % label, effect_definition.duration_mode, "turns")
	validator._expect_int(errors, "%s effect.duration" % label, effect_definition.duration, 3)
	validator._expect_string(errors, "%s effect.decrement_on" % label, effect_definition.decrement_on, "turn_end")
	validator._expect_string(errors, "%s effect.stacking" % label, effect_definition.stacking, "none")
	validator._expect_packed_string_array(errors, "%s effect.trigger_names" % label, effect_definition.trigger_names, PackedStringArray(["on_cast"]))
	var payload = validator._extract_single_payload(errors, label, "kashimo_kyokyo_nullify", effect_definition, RuleModPayloadScript, "rule_mod")
	validator._expect_payload_shape(
		errors,
		"%s effect" % label,
		payload,
		{
			"mod_kind": "nullify_field_accuracy",
			"mod_op": "set",
			"value": true,
			"scope": "self",
			"duration_mode": "turns",
			"duration": 3,
			"decrement_on": "turn_end",
			"stacking": "refresh",
			"priority": 10,
		}
	)
func validate_charge_separation_effects(validator, content_index, errors: Array) -> void:
	_validate_apply_water_leak_listeners(validator, content_index, errors)
	_validate_thunder_resist(validator, content_index, errors)
	_validate_water_leak_self(validator, content_index, errors)
	_validate_water_leak_counter(validator, content_index, errors)

func _validate_skill_contract(
	validator,
	content_index,
	errors: Array,
	label: String,
	skill_id: String,
	expected_fields: Dictionary
) -> void:
	var skill_definition = validator._require_skill(content_index, errors, label, skill_id)
	if skill_definition == null:
		return
	validator._expect_string(errors, "%s display_name" % label, skill_definition.display_name, String(expected_fields.get("display_name", "")))
	validator._expect_string(errors, "%s damage_kind" % label, skill_definition.damage_kind, String(expected_fields.get("damage_kind", "")))
	validator._expect_int(errors, "%s power" % label, skill_definition.power, int(expected_fields.get("power", 0)))
	validator._expect_int(errors, "%s accuracy" % label, skill_definition.accuracy, int(expected_fields.get("accuracy", 0)))
	validator._expect_int(errors, "%s mp_cost" % label, skill_definition.mp_cost, int(expected_fields.get("mp_cost", 0)))
	validator._expect_int(errors, "%s priority" % label, skill_definition.priority, int(expected_fields.get("priority", 0)))
	validator._expect_string(errors, "%s combat_type_id" % label, skill_definition.combat_type_id, String(expected_fields.get("combat_type_id", "")))
	validator._expect_string(errors, "%s targeting" % label, skill_definition.targeting, String(expected_fields.get("targeting", "")))
	if expected_fields.has("power_bonus_source"):
		validator._expect_string(errors, "%s power_bonus_source" % label, skill_definition.power_bonus_source, String(expected_fields.get("power_bonus_source", "")))
	if expected_fields.has("is_domain_skill"):
		validator._expect_bool(errors, "%s is_domain_skill" % label, skill_definition.is_domain_skill, bool(expected_fields.get("is_domain_skill", false)))
	if expected_fields.has("effects_on_cast_ids"):
		validator._expect_packed_string_array(errors, "%s effects_on_cast_ids" % label, skill_definition.effects_on_cast_ids, expected_fields.get("effects_on_cast_ids", PackedStringArray()))
	if expected_fields.has("effects_on_hit_ids"):
		validator._expect_packed_string_array(errors, "%s effects_on_hit_ids" % label, skill_definition.effects_on_hit_ids, expected_fields.get("effects_on_hit_ids", PackedStringArray()))

func _validate_thunder_resist(validator, content_index, errors: Array) -> void:
	var label := "formal[kashimo].thunder_resist"
	var effect_definition = validator._require_effect(content_index, errors, label, "kashimo_thunder_resist")
	if effect_definition == null:
		return
	var payload = validator._extract_single_payload(errors, label, "kashimo_thunder_resist", effect_definition, RuleModPayloadScript, "rule_mod")
	if payload == null:
		return
	validator._expect_string(errors, "%s mod_kind" % label, payload.mod_kind, "incoming_action_final_mod")
	validator._expect_string(errors, "%s mod_op" % label, payload.mod_op, "mul")
	if float(payload.value) != 0.5:
		errors.append("%s value mismatch: expected 0.5 got %s" % [label, var_to_str(payload.value)])
	validator._expect_packed_string_array(errors, "%s required_incoming_command_types" % label, payload.required_incoming_command_types, PackedStringArray(["skill", "ultimate"]))
	validator._expect_packed_string_array(errors, "%s required_incoming_combat_type_ids" % label, payload.required_incoming_combat_type_ids, PackedStringArray(["thunder"]))

func _validate_apply_water_leak_listeners(validator, content_index, errors: Array) -> void:
	var label := "formal[kashimo].water_leak_listeners"
	var effect_definition = validator._require_effect(content_index, errors, label, "kashimo_apply_water_leak_listeners")
	if effect_definition == null:
		return
	validator._expect_string(errors, "%s scope" % label, effect_definition.scope, "self")
	validator._expect_packed_string_array(errors, "%s trigger_names" % label, effect_definition.trigger_names, PackedStringArray(["on_enter"]))
	if effect_definition.payloads.size() != 2:
		errors.append("%s payload count mismatch: expected 2 got %d" % [label, effect_definition.payloads.size()])
		return
	var expected_effect_ids := PackedStringArray(["kashimo_water_leak_self_listener", "kashimo_water_leak_counter_listener"])
	for payload_index in range(expected_effect_ids.size()):
		var payload = effect_definition.payloads[payload_index]
		if payload == null or payload.get_script() != ApplyEffectPayloadScript:
			errors.append("%s payload[%d] must be apply_effect" % [label, payload_index])
			continue
		validator._expect_payload_shape(errors, "%s payload[%d]" % [label, payload_index], payload, {"effect_definition_id": expected_effect_ids[payload_index]})

func _validate_water_leak_self(validator, content_index, errors: Array) -> void:
	var label := "formal[kashimo].water_leak_self"
	var effect_definition = validator._require_effect(content_index, errors, label, "kashimo_water_leak_self_listener")
	if effect_definition == null:
		return
	validator._expect_string(errors, "%s scope" % label, effect_definition.scope, "self")
	validator._expect_packed_string_array(errors, "%s trigger_names" % label, effect_definition.trigger_names, PackedStringArray(["on_receive_action_hit"]))
	validator._expect_packed_string_array(errors, "%s required_incoming_command_types" % label, effect_definition.required_incoming_command_types, PackedStringArray(["skill", "ultimate"]))
	validator._expect_packed_string_array(errors, "%s required_incoming_combat_type_ids" % label, effect_definition.required_incoming_combat_type_ids, PackedStringArray(["water"]))
	var payload = validator._extract_single_payload(errors, label, "kashimo_water_leak_self_listener", effect_definition, ResourceModPayloadScript, "resource_mod")
	validator._expect_payload_shape(errors, "%s effect" % label, payload, {"resource_key": "mp", "amount": -15})

func _validate_water_leak_counter(validator, content_index, errors: Array) -> void:
	var label := "formal[kashimo].water_leak_counter"
	var effect_definition = validator._require_effect(content_index, errors, label, "kashimo_water_leak_counter_listener")
	if effect_definition == null:
		return
	var payload = validator._extract_single_payload(errors, label, "kashimo_water_leak_counter_listener", effect_definition, DamagePayloadScript, "damage")
	if payload == null:
		return
	validator._expect_string(errors, "%s scope" % label, effect_definition.scope, "action_actor")
	validator._expect_packed_string_array(errors, "%s trigger_names" % label, effect_definition.trigger_names, PackedStringArray(["on_receive_action_hit"]))
	validator._expect_packed_string_array(errors, "%s required_incoming_command_types" % label, effect_definition.required_incoming_command_types, PackedStringArray(["skill", "ultimate"]))
	validator._expect_packed_string_array(errors, "%s required_incoming_combat_type_ids" % label, effect_definition.required_incoming_combat_type_ids, PackedStringArray(["water"]))
	validator._expect_int(errors, "%s amount" % label, payload.amount, 15)
	validator._expect_string(errors, "%s combat_type_id" % label, payload.combat_type_id, "poison")
