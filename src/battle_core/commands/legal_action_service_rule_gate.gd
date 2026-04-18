extends RefCounted
class_name LegalActionServiceRuleGate

const ServiceDependencyContractHelperScript := preload("res://src/composition/service_dependency_contract_helper.gd")

const COMPOSE_DEPS := [
	{
		"field": "rule_mod_service",
		"source": "rule_mod_service",
		"nested": true,
	},
	{
		"field": "domain_legality_service",
		"source": "domain_legality_service",
		"nested": true,
	},
]

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var rule_mod_service
var domain_legality_service

func resolve_missing_dependency() -> String:
	return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)


func side_domain_recast_blocked_result(battle_state, side_id: String, content_index) -> Dictionary:
	if domain_legality_service == null:
		return _error_result(
			ErrorCodesScript.INVALID_STATE_CORRUPTION,
			"LegalActionService.domain_legality_service is required"
		)
	var side_domain_recast_blocked: bool = domain_legality_service.is_side_domain_recast_blocked(
		battle_state,
		side_id,
		content_index
	)
	if domain_legality_service.invalid_battle_code() != null:
		return _error_result(
			ErrorCodesScript.INVALID_STATE_CORRUPTION,
			"LegalActionService detected invalid active field runtime while resolving domain legality"
		)
	return _ok_result(side_domain_recast_blocked)

func action_allowed_result(
	battle_state,
	actor_id: String,
	action_type: String,
	skill_id: String = ""
) -> Dictionary:
	if rule_mod_service == null:
		return _error_result(
			ErrorCodesScript.INVALID_STATE_CORRUPTION,
			"LegalActionService.rule_mod_service is required"
		)
	var is_allowed = rule_mod_service.is_action_allowed(battle_state, actor_id, action_type, skill_id)
	if rule_mod_service != null and rule_mod_service.has_method("error_state"):
		var error_state: Dictionary = rule_mod_service.error_state()
		var error_code = error_state.get("code", null)
		if error_code != null:
			var error_message := String(error_state.get("message", ""))
			return _error_result(
				str(error_code),
				error_message if not error_message.is_empty() else "LegalActionService failed to resolve rule mod action legality"
			)
	return _ok_result(is_allowed)

func _ok_result(data) -> Dictionary:
	return {
		"ok": true,
		"data": data,
		"error_code": null,
		"error_message": null,
	}

func _error_result(error_code: String, error_message: String) -> Dictionary:
	return {
		"ok": false,
		"data": null,
		"error_code": error_code,
		"error_message": error_message,
	}
