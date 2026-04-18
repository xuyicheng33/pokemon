extends RefCounted
class_name BattleSandboxPolicyPort

const ResultEnvelopeHelperScript := preload("res://src/shared/result_envelope_helper.gd")

func select_action_result(_legal_actions, _public_snapshot: Dictionary = {}, _controller_context: Dictionary = {}) -> Dictionary:
	return ResultEnvelopeHelperScript.error(null, "BattleSandboxPolicyPort.select_action_result must be implemented")
