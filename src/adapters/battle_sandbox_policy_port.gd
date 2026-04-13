extends RefCounted
class_name BattleSandboxPolicyPort

func select_action_result(_legal_actions, _public_snapshot: Dictionary = {}, _controller_context: Dictionary = {}) -> Dictionary:
	return {
		"ok": false,
		"error": "BattleSandboxPolicyPort.select_action_result must be implemented",
	}
