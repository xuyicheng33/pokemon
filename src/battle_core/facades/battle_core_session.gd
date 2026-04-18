extends RefCounted

const BattleCoreManagerContractHelperScript := preload("res://src/battle_core/facades/battle_core_manager_contract_helper.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var session_id: String = ""
var _container: RefCounted = null
var _battle_state: BattleState = null
var _content_index: BattleContentIndex = null

func configure_runtime(container, battle_state, content_index) -> void:
	_container = container
	_battle_state = battle_state
	_content_index = content_index

func validate_runtime_result() -> Variant:
	if not _is_ready():
		return BattleCoreManagerContractHelperScript.error(ErrorCodesScript.INVALID_SESSION, "BattleCoreManager session is incomplete")
	if not String(_battle_state.runtime_fault_code).is_empty():
		return BattleCoreManagerContractHelperScript.error(
			String(_battle_state.runtime_fault_code),
			String(_battle_state.runtime_fault_message) if not String(_battle_state.runtime_fault_message).is_empty() else "BattleCoreManager runtime state invalid"
		)
	var runtime_guard_service = _get_container_service("runtime_guard_service")
	if runtime_guard_service == null:
		return BattleCoreManagerContractHelperScript.error(ErrorCodesScript.INVALID_COMPOSITION, "BattleCoreManager missing dependency: runtime_guard_service")
	var invalid_code = runtime_guard_service.validate_runtime_state(_battle_state, _content_index)
	if invalid_code != null:
		return BattleCoreManagerContractHelperScript.error(str(invalid_code), "BattleCoreManager runtime state invalid: %s" % str(invalid_code))
	if _battle_state.battle_result != null and bool(_battle_state.battle_result.finished):
		var reason := String(_battle_state.battle_result.reason)
		if reason.begins_with("invalid_"):
			return BattleCoreManagerContractHelperScript.error(
				reason,
				String(_battle_state.runtime_fault_message) if not String(_battle_state.runtime_fault_message).is_empty() else "BattleCoreManager runtime state invalid: %s" % reason
			)
	var battle_logger = _get_container_service("battle_logger")
	if battle_logger != null and battle_logger.has_method("error_state"):
		var logger_error_state: Dictionary = battle_logger.error_state()
		var logger_error_code = logger_error_state.get("code", null)
		var logger_error_message := String(logger_error_state.get("message", ""))
		if logger_error_code != null:
			return BattleCoreManagerContractHelperScript.error(
				str(logger_error_code),
				logger_error_message if not logger_error_message.is_empty() else "BattleCoreManager runtime log state invalid"
			)
	return null

func get_legal_actions_result(side_id: String) -> Dictionary:
	if not _is_ready():
		return BattleCoreManagerContractHelperScript.error(ErrorCodesScript.INVALID_SESSION, "BattleCoreManager session is incomplete")
	var legal_action_service = _get_container_service("legal_action_service")
	if legal_action_service == null:
		return BattleCoreManagerContractHelperScript.error(ErrorCodesScript.INVALID_COMPOSITION, "BattleCoreManager missing dependency: legal_action_service")
	var legal_actions = legal_action_service.get_legal_actions(_battle_state, side_id, _content_index)
	if legal_actions == null:
		return BattleCoreManagerContractHelperScript.service_error(
			legal_action_service,
			ErrorCodesScript.INVALID_STATE_CORRUPTION,
			"BattleCoreManager failed to build legal action set"
		)
	return BattleCoreManagerContractHelperScript.ok(legal_actions)

func run_turn_result(commands: Array) -> Dictionary:
	if not _is_ready():
		return BattleCoreManagerContractHelperScript.error(ErrorCodesScript.INVALID_SESSION, "BattleCoreManager session is incomplete")
	var turn_loop_controller = _get_container_service("turn_loop_controller")
	if turn_loop_controller == null:
		return BattleCoreManagerContractHelperScript.error(ErrorCodesScript.INVALID_COMPOSITION, "BattleCoreManager missing dependency: turn_loop_controller")
	turn_loop_controller.run_turn(_battle_state, _content_index, commands)
	return BattleCoreManagerContractHelperScript.ok(true)

func get_event_log_snapshot_result() -> Dictionary:
	if not _is_ready():
		return BattleCoreManagerContractHelperScript.error(ErrorCodesScript.INVALID_SESSION, "BattleCoreManager session is incomplete")
	var battle_logger = _get_container_service("battle_logger")
	if battle_logger == null:
		return BattleCoreManagerContractHelperScript.error(ErrorCodesScript.INVALID_COMPOSITION, "BattleCoreManager missing dependency: battle_logger")
	return BattleCoreManagerContractHelperScript.ok(battle_logger.snapshot())

func current_battle_state():
	return _battle_state

func current_content_index():
	return _content_index

func dispose() -> void:
	if _container != null and _container.has_method("dispose"):
		_container.dispose()
	_container = null
	_battle_state = null
	_content_index = null

func _is_ready() -> bool:
	return _container != null and _battle_state != null and _content_index != null

func _get_container_service(service_name: String) -> Variant:
	if _container == null:
		return null
	return _container.service(service_name)
