extends "res://tests/support/gdunit_suite_bridge.gd"

const BattleCoreManagerContainerServiceScript := preload("res://src/battle_core/facades/battle_core_manager_container_service.gd")
const BattleCorePublicSnapshotBuilderScript := preload("res://src/battle_core/facades/public_snapshot_builder.gd")
const BattleResultScript := preload("res://src/battle_core/contracts/battle_result.gd")
const BattleStateScript := preload("res://src/battle_core/runtime/battle_state.gd")
const ChainContextScript := preload("res://src/battle_core/contracts/chain_context.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const LegalActionServiceScript := preload("res://src/battle_core/commands/legal_action_service.gd")
const CommandBuilderScript := preload("res://src/battle_core/commands/command_builder.gd")
const RuleModServiceScript := preload("res://src/battle_core/effects/rule_mod_service.gd")
const DomainLegalityServiceScript := preload("res://src/battle_core/commands/domain_legality_service.gd")
const LegalActionSetScript := preload("res://src/battle_core/contracts/legal_action_set.gd")
const LogEventBuilderScript := preload("res://src/battle_core/logging/log_event_builder.gd")
const ReplayInputScript := preload("res://src/battle_core/contracts/replay_input.gd")
const ReplayOutputScript := preload("res://src/battle_core/contracts/replay_output.gd")
const ReplayRunnerOutputHelperScript := preload("res://src/battle_core/logging/replay_runner_output_helper.gd")
const ManagerContractTestHelperScript := preload("res://tests/support/manager_contract_test_helper.gd")

var _helper = ManagerContractTestHelperScript.new()

func _shared_helper_ref() -> Variant:
	return _helper

class ReplayRunnerStub:
	var replay_result: Dictionary = {}

	func _init(next_replay_result: Dictionary) -> void:
		replay_result = next_replay_result

	func run_replay_with_context(_replay_input) -> Dictionary:
		return replay_result

class ContainerStub:
	var services: Dictionary = {}
	var disposed: bool = false

	func _init(next_services: Dictionary) -> void:
		services = next_services

	func service(slot: String):
		return services.get(slot, null)

	func dispose() -> void:
		disposed = true

class PublicSnapshotBuilderStub:
	extends BattleCorePublicSnapshotBuilderScript

	var build_calls: int = 0

	func build_public_snapshot(_battle_state: BattleState, _content_index: BattleContentIndex = null) -> Dictionary:
		build_calls += 1
		return {"public_snapshot": true}

class NullLegalActionService:
	extends LegalActionServiceScript

	func get_legal_actions(_battle_state, _side_id: String, _content_index):
		return null

	func error_state() -> Dictionary:
		return {
			"code": ErrorCodesScript.INVALID_STATE_CORRUPTION,
			"message": "forced legal action failure",
		}

class OneSideLegalActionFailureStub:
	extends LegalActionServiceScript

	var _failed_side_id: String = ""

	func _init(failed_side_id: String) -> void:
		_failed_side_id = failed_side_id

	func get_legal_actions(_battle_state, side_id: String, _content_index):
		if side_id == _failed_side_id:
			return null
		return LegalActionSetScript.new()

	func error_state() -> Dictionary:
		return {
			"code": ErrorCodesScript.INVALID_STATE_CORRUPTION,
			"message": "partial legal action failure",
		}

class NullCommandBuilder:
	extends CommandBuilderScript

	func build_command(_input_payload: Dictionary):
		return null

	func error_state() -> Dictionary:
		return {
			"code": ErrorCodesScript.INVALID_STATE_CORRUPTION,
			"message": "forced command build failure",
		}

class RuleModServiceFailureStub:
	extends RuleModServiceScript

	func is_action_allowed(_battle_state, _owner_id: String, _action_type: String, _skill_id: String = "") -> bool:
		return false

	func error_state() -> Dictionary:
		return {
			"code": ErrorCodesScript.INVALID_STATE_CORRUPTION,
			"message": "rule mod read failed",
		}

class DomainLegalityServiceClearStub:
	extends DomainLegalityServiceScript

	func is_side_domain_recast_blocked(_battle_state, _side_id: String, _content_index) -> bool:
		return false

	func invalid_battle_code() -> Variant:
		return null

func _build_failed_replay_output(finished: bool, result_type: String, reason: String, winner_side_id) -> Variant:
	var replay_output := ReplayOutputScript.new()
	replay_output.succeeded = false
	replay_output.event_log = []
	replay_output.final_state_hash = "failed"
	var battle_result := BattleResultScript.new()
	battle_result.finished = finished
	battle_result.result_type = result_type
	battle_result.reason = reason
	battle_result.winner_side_id = winner_side_id
	replay_output.battle_result = battle_result
	replay_output.final_battle_state = BattleStateScript.new()
	return replay_output

func _build_finished_battle_state() -> BattleStateScript:
	var battle_state := BattleStateScript.new()
	var battle_result := BattleResultScript.new()
	battle_result.finished = true
	battle_result.result_type = "no_winner"
	battle_result.reason = "turn_limit"
	battle_result.winner_side_id = null
	battle_state.battle_result = battle_result
	return battle_state
