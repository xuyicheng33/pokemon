extends RefCounted
class_name PayloadExecutor

const DependencyContractHelperScript := preload("res://src/shared/dependency_contract_helper.gd")

const COMPOSE_DEPS := [
	{
		"field": "effect_precondition_service",
		"source": "effect_precondition_service",
		"nested": true,
	},
	{
		"field": "payload_handler_registry",
		"source": "payload_handler_registry",
		"nested": true,
	},
]

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var effect_precondition_service: EffectPreconditionService
var payload_handler_registry: PayloadHandlerRegistry

var last_invalid_battle_code: Variant = null

func invalid_battle_code() -> Variant:
	return last_invalid_battle_code

func resolve_missing_dependency() -> String:
	return DependencyContractHelperScript.resolve_missing_dependency(self)


func execute_effect_event(
	effect_event: EffectEvent,
	battle_state: BattleState,
	content_index: BattleContentIndex,
	execute_trigger_batch: Callable = Callable()
) -> void:
	last_invalid_battle_code = null
	var missing_dependency := resolve_missing_dependency()
	if not missing_dependency.is_empty():
		last_invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
		return
	if not _enter_effect_guard(effect_event, battle_state):
		return
	var effect_definition = content_index.effects.get(effect_event.effect_definition_id)
	if effect_definition == null:
		last_invalid_battle_code = ErrorCodesScript.INVALID_EFFECT_DEFINITION
		_leave_effect_guard(battle_state)
		return
	if not effect_precondition_service.passes_effect_preconditions(effect_definition, effect_event, battle_state):
		_capture_handler_invalid_code(effect_precondition_service)
		_leave_effect_guard(battle_state)
		return
	for payload in effect_definition.payloads:
		execute_payload(
			payload,
			effect_definition,
			effect_event,
			battle_state,
			content_index,
			execute_trigger_batch
		)
		if last_invalid_battle_code != null:
			_leave_effect_guard(battle_state)
			return
	_leave_effect_guard(battle_state)

func execute_payload(
	payload,
	effect_definition,
	effect_event: EffectEvent,
	battle_state: BattleState,
	content_index: BattleContentIndex,
	execute_trigger_batch: Callable = Callable()
) -> void:
	var handler = payload_handler_registry.handler_for(payload)
	if handler == null:
		last_invalid_battle_code = ErrorCodesScript.INVALID_EFFECT_DEFINITION
		return
	handler.execute(
		payload,
		effect_definition,
		effect_event,
		battle_state,
		content_index,
		execute_trigger_batch
	)
	_capture_handler_invalid_code(handler)
	if last_invalid_battle_code != null:
		return

func _capture_handler_invalid_code(handler) -> void:
	if handler == null:
		return
	var invalid_code = handler.invalid_battle_code()
	if invalid_code != null:
		last_invalid_battle_code = invalid_code

func _resolve_handler_missing(handler) -> String:
	if handler == null:
		return ""
	if handler.has_method("resolve_missing_dependency"):
		return str(handler.resolve_missing_dependency())
	return ""

func _enter_effect_guard(effect_event: EffectEvent, battle_state: BattleState) -> bool:
	var chain_context = battle_state.current_chain_context()
	if chain_context == null or battle_state.max_chain_depth <= 0:
		last_invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
		return false
	var dedupe_key := _build_dedupe_key(effect_event)
	if chain_context.effect_dedupe_keys.has(dedupe_key):
		last_invalid_battle_code = ErrorCodesScript.INVALID_CHAIN_DEPTH
		return false
	chain_context.effect_dedupe_keys[dedupe_key] = true
	chain_context.chain_depth += 1
	if chain_context.chain_depth > battle_state.max_chain_depth:
		chain_context.chain_depth -= 1
		chain_context.effect_dedupe_keys.erase(dedupe_key)
		last_invalid_battle_code = ErrorCodesScript.INVALID_CHAIN_DEPTH
		return false
	return true

# `effect_dedupe_keys` 实现的是“单链单实例”去重，不是链深限制：同一条主链中，每个完整
# dedupe key（source_instance_id / effect_instance_id / trigger_name / effect_definition_id /
# owner_id / dedupe_discriminator / target_unit_id / action_segment_index）只允许进入一次。
# 去重表的生命周期与 `chain_context` 绑定——主链结束时 `chain_context` 被重置或置 null，
# 去重表随之出栈，因此 `_leave_effect_guard` 不需要显式 erase 任何 key；只回退 `chain_depth`。
# 链深限制由 `chain_depth ≤ max_chain_depth` 单独守卫，不要把这两条混成一回事。
func _leave_effect_guard(battle_state: BattleState) -> void:
	var chain_context = battle_state.current_chain_context()
	if chain_context == null:
		return
	if chain_context.chain_depth > 0:
		chain_context.chain_depth -= 1

# Key fields are joined by "|". No field value may contain "|"; all current
# id / trigger_name / discriminator values are plain identifiers guaranteed
# to be pipe-free by content validation.
func _build_dedupe_key(effect_event: EffectEvent) -> String:
	var source_instance_id := ""
	var effect_instance_id := ""
	var trigger_name := ""
	var effect_definition_id := ""
	var owner_id := ""
	var dedupe_discriminator := ""
	var target_unit_id := ""
	var action_segment_index := 0
	if effect_event != null:
		source_instance_id = _string_or_empty(effect_event.source_instance_id)
		effect_instance_id = _string_or_empty(effect_event.effect_instance_id)
		trigger_name = _string_or_empty(effect_event.trigger_name)
		effect_definition_id = _string_or_empty(effect_event.effect_definition_id)
		owner_id = _string_or_empty(effect_event.owner_id)
		dedupe_discriminator = _string_or_empty(effect_event.dedupe_discriminator)
		if effect_event.chain_context != null:
			target_unit_id = _string_or_empty(effect_event.chain_context.target_unit_id)
			action_segment_index = int(effect_event.chain_context.action_segment_index)
	return "%s|%s|%s|%s|%s|%s|%s|%d" % [
		source_instance_id,
		effect_instance_id,
		trigger_name,
		effect_definition_id,
		owner_id,
		dedupe_discriminator,
		target_unit_id,
		action_segment_index,
	]

func _string_or_empty(value) -> String:
	return "" if value == null else str(value)
