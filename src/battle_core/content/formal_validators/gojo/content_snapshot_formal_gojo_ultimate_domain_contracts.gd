extends RefCounted
class_name ContentSnapshotFormalGojoUltimateDomainContracts

const ContractHelperScript := preload("res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_contract_helper.gd")
const GojoDomainContractsScript := preload("res://src/battle_core/content/formal_validators/gojo/content_snapshot_formal_gojo_domain_contracts.gd")

var _helper = ContractHelperScript.new()
var _domain_contracts = GojoDomainContractsScript.new()

func validate(validator, content_index, errors: Array) -> void:
	_helper.validate_skill_contracts(validator, content_index, errors, [{
		"label": "formal[gojo].unlimited_void",
		"skill_id": "gojo_unlimited_void",
		"fields": {
			"display_name": "无量空处",
			"damage_kind": "special",
			"power": 48,
			"accuracy": 100,
			"mp_cost": 50,
			"priority": 5,
			"combat_type_id": "space",
			"targeting": "enemy_active_slot",
			"is_domain_skill": true,
			"effects_on_cast_ids": PackedStringArray(),
			"effects_on_hit_ids": PackedStringArray(["gojo_apply_domain_field"]),
			"effects_on_miss_ids": PackedStringArray(),
			"effects_on_kill_ids": PackedStringArray(),
		},
	}])
	_domain_contracts.validate(validator, content_index, errors)
