extends RefCounted
class_name LegalActionService

const DependencyContractHelperScript := preload("res://src/shared/dependency_contract_helper.gd")

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
	{
		"field": "_rule_gate",
		"source": "",
		"nested": false,
	},
]

const LegalActionSetScript := preload("res://src/battle_core/contracts/legal_action_set.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const CastOptionCollectorScript := preload("res://src/battle_core/commands/legal_action_service_cast_option_collector.gd")
const RuleGateScript := preload("res://src/battle_core/commands/legal_action_service_rule_gate.gd")
const SwitchOptionCollectorScript := preload("res://src/battle_core/commands/legal_action_service_switch_option_collector.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const ErrorStateHelperScript := preload("res://src/shared/error_state_helper.gd")

var rule_mod_service
var domain_legality_service
var last_error_code: Variant = null
var last_error_message: String = ""
var _cast_option_collector = CastOptionCollectorScript.new()
var _rule_gate = RuleGateScript.new()
var _switch_option_collector = SwitchOptionCollectorScript.new()

func _init() -> void:
	_cast_option_collector.rule_gate = _rule_gate
	_switch_option_collector.rule_gate = _rule_gate

func error_state() -> Dictionary:
	return ErrorStateHelperScript.error_state(self)

func resolve_missing_dependency() -> String:
	return DependencyContractHelperScript.resolve_missing_dependency(self)


func get_legal_actions(battle_state: BattleState, side_id: String, content_index: BattleContentIndex) -> Variant:
	_reset_error_state()
	_sync_rule_gate_dependencies()
	var side_state = battle_state.get_side(side_id)
	if side_state == null:
		return _fail_invalid_state("Unknown side: %s" % side_id)
	var actor = side_state.get_active_unit()
	if actor == null:
		return _fail_invalid_state("Side %s has no active unit" % side_id)
	var unit_definition = content_index.units.get(actor.definition_id)
	if unit_definition == null:
		return _fail_invalid_state("Missing unit definition: %s" % actor.definition_id)
	var legal_action_set = LegalActionSetScript.new()
	legal_action_set.actor_public_id = actor.public_id
	var has_non_mp_blocked_option: bool = false
	var has_any_skill_or_ultimate_option: bool = false
	var side_domain_recast_blocked_result: Dictionary = _rule_gate.side_domain_recast_blocked_result(
		battle_state,
		side_id,
		content_index
	)
	if not _record_result_or_fail(side_domain_recast_blocked_result):
		return null
	var side_domain_recast_blocked: bool = bool(side_domain_recast_blocked_result.get("data", false))
	var cast_flags_result: Dictionary = _cast_option_collector.collect_cast_action_flags_result(
		battle_state,
		actor,
		unit_definition,
		content_index,
		side_domain_recast_blocked,
		legal_action_set
	)
	if not _record_result_or_fail(cast_flags_result):
		return null
	var cast_flags: Dictionary = cast_flags_result.get("data", {})
	has_non_mp_blocked_option = bool(cast_flags["has_non_mp_blocked_option"])
	has_any_skill_or_ultimate_option = bool(cast_flags["has_any_skill_or_ultimate_option"])
	var switch_flags_result: Dictionary = _switch_option_collector.collect_switch_action_flags_result(
		battle_state,
		side_state,
		actor,
		legal_action_set
	)
	if not _record_result_or_fail(switch_flags_result):
		return null
	var switch_flags: Dictionary = switch_flags_result.get("data", {})
	if bool(switch_flags["has_non_mp_blocked_option"]):
		has_non_mp_blocked_option = true
	_finalize_wait_and_forced_default(
		legal_action_set,
		has_any_skill_or_ultimate_option,
		bool(switch_flags["has_legal_switch"]),
		has_non_mp_blocked_option
	)
	return legal_action_set

func _sync_rule_gate_dependencies() -> void:
	_rule_gate.rule_mod_service = rule_mod_service
	_rule_gate.domain_legality_service = domain_legality_service

func _reset_error_state() -> void:
	ErrorStateHelperScript.clear(self)

func _record_result_or_fail(result: Dictionary) -> bool:
	if bool(result.get("ok", false)):
		return true
	ErrorStateHelperScript.capture_envelope(self, result, ErrorCodesScript.INVALID_STATE_CORRUPTION)
	return false

# 触发条件以本函数为单一真相：当不存在任何合法主动出口（skill / ultimate / switch
# 三个集合全空）且也没有非 MP 阻断撑起 wait 时，统一注入 resource_forced_default。
# 既覆盖“仅 MP 不足”，也覆盖“被 rule_mod / domain / once_per_battle 完全锁死且无可
# 换人”等所有“无任何主动出口”的情形，不再按阻断原因二次分类。
func _finalize_wait_and_forced_default(
	legal_action_set,
	has_any_skill_or_ultimate_option: bool,
	has_legal_switch: bool,
	has_non_mp_blocked_option: bool
) -> void:
	var has_any_legal_manual_option: bool = has_any_skill_or_ultimate_option or has_legal_switch
	legal_action_set.wait_allowed = has_any_legal_manual_option or has_non_mp_blocked_option
	if not legal_action_set.wait_allowed \
	and legal_action_set.legal_skill_ids.is_empty() \
	and legal_action_set.legal_switch_target_public_ids.is_empty() \
	and legal_action_set.legal_ultimate_ids.is_empty():
		legal_action_set.forced_command_type = CommandTypesScript.RESOURCE_FORCED_DEFAULT

func _fail_invalid_state(message: String) -> Variant:
	ErrorStateHelperScript.fail(self, ErrorCodesScript.INVALID_STATE_CORRUPTION, message)
	return null
