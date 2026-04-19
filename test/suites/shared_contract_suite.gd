extends GdUnitTestSuite

const PropertyAccessHelperScript := preload("res://src/shared/property_access_helper.gd")
const ResultEnvelopeHelperScript := preload("res://src/shared/result_envelope_helper.gd")
const BattleInitializerPortsScript := preload("res://src/battle_core/turn/battle_initializer_ports.gd")
const BattleInitializerSetupValidatorScript := preload("res://src/battle_core/turn/battle_initializer_setup_validator.gd")
const BattleInitializerPhaseServiceScript := preload("res://src/battle_core/turn/battle_initializer_phase_service.gd")
const IdFactoryScript := preload("res://src/shared/id_factory.gd")
const RngServiceScript := preload("res://src/shared/rng_service.gd")
const FaintResolverScript := preload("res://src/battle_core/lifecycle/faint_resolver.gd")
const TriggerBatchRunnerScript := preload("res://src/battle_core/effects/trigger_batch_runner.gd")
const BattleLoggerScript := preload("res://src/battle_core/logging/battle_logger.gd")
const LogEventBuilderScript := preload("res://src/battle_core/logging/log_event_builder.gd")
const CombatTypeServiceScript := preload("res://src/battle_core/math/combat_type_service.gd")
const MpServiceScript := preload("res://src/battle_core/math/mp_service.gd")
const RuleModServiceScript := preload("res://src/battle_core/effects/rule_mod_service.gd")
const BattleResultServiceScript := preload("res://src/battle_core/turn/battle_result_service.gd")
const TurnFieldLifecycleServiceScript := preload("res://src/battle_core/turn/turn_field_lifecycle_service.gd")

class PropertyCarrier:
	extends RefCounted

	var answer: int = 42
	var label: String = "sandbox"

class FaintResolverStub:
	extends FaintResolverScript

	func resolve_missing_dependency() -> String:
		return ""

class TriggerBatchRunnerStub:
	extends TriggerBatchRunnerScript

	func resolve_missing_dependency() -> String:
		return ""

class BattleLoggerStub:
	extends BattleLoggerScript

	func resolve_missing_dependency() -> String:
		return ""

class LogEventBuilderStub:
	extends LogEventBuilderScript

	func resolve_missing_dependency() -> String:
		return ""

class MpServiceStub:
	extends MpServiceScript

	func resolve_missing_dependency() -> String:
		return ""

class RuleModServiceStub:
	extends RuleModServiceScript

	func resolve_missing_dependency() -> String:
		return ""

class BattleResultServiceStub:
	extends BattleResultServiceScript

	func resolve_missing_dependency() -> String:
		return ""

class TurnFieldLifecycleServiceStub:
	extends TurnFieldLifecycleServiceScript

	func resolve_missing_dependency() -> String:
		return ""

func test_property_access_helper_reads_dictionary_and_object_contract() -> void:
	var carrier := PropertyCarrier.new()
	assert_bool(PropertyAccessHelperScript.has_property({"answer": 7}, "answer")).is_true()
	assert_bool(PropertyAccessHelperScript.has_property(carrier, "answer")).is_true()
	assert_int(int(PropertyAccessHelperScript.read_property({"answer": 7}, "answer", -1))).is_equal(7)
	assert_int(int(PropertyAccessHelperScript.read_property(carrier, "answer", -1))).is_equal(42)
	assert_str(String(PropertyAccessHelperScript.read_property(carrier, "missing_label", "fallback"))).is_equal("fallback")

func test_result_envelope_helper_contract_uses_four_field_shape() -> void:
	var success: Dictionary = ResultEnvelopeHelperScript.ok({"status": "ok"})
	for key_name in ["ok", "data", "error_code", "error_message"]:
		assert_bool(success.has(key_name)).is_true()
	assert_bool(success.has("error")).is_false()
	assert_bool(bool(success.get("ok", false))).is_true()
	assert_bool(success.get("error_code", "sentinel") == null).is_true()
	assert_bool(success.get("error_message", "sentinel") == null).is_true()

	var failure_unwrap: Dictionary = ResultEnvelopeHelperScript.unwrap_ok({
		"ok": false,
		"data": null,
		"error_code": "sample_error",
		"error_message": "sample failure",
	}, "shared_contract_suite")
	for key_name in ["ok", "data", "error_code", "error_message"]:
		assert_bool(failure_unwrap.has(key_name)).is_true()
	assert_bool(failure_unwrap.has("error")).is_false()
	assert_bool(bool(failure_unwrap.get("ok", true))).is_false()
	assert_str(String(failure_unwrap.get("error_message", ""))).contains("shared_contract_suite failed")
	assert_str(String(failure_unwrap.get("error_code", ""))).is_equal("sample_error")

func test_battle_initializer_child_ports_contract() -> void:
	var ports: BattleInitializerPorts = BattleInitializerPortsScript.new()
	ports.id_factory = IdFactoryScript.new()
	ports.rng_service = RngServiceScript.new()
	ports.faint_resolver = FaintResolverStub.new()
	ports.trigger_batch_runner = TriggerBatchRunnerStub.new()
	ports.battle_logger = BattleLoggerStub.new()
	ports.log_event_builder = LogEventBuilderStub.new()
	ports.combat_type_service = CombatTypeServiceScript.new()
	ports.mp_service = MpServiceStub.new()
	ports.rule_mod_service = RuleModServiceStub.new()
	ports.battle_result_service = BattleResultServiceStub.new()
	ports.field_lifecycle_service = TurnFieldLifecycleServiceStub.new()

	var setup_validator: BattleInitializerSetupValidator = BattleInitializerSetupValidatorScript.new()
	setup_validator.configure_ports(ports)
	assert_str(setup_validator.resolve_missing_dependency()).is_equal("")
	assert_bool(setup_validator.rng_service == ports.rng_service).is_true()
	assert_bool(setup_validator.battle_logger == ports.battle_logger).is_true()
	assert_bool(setup_validator.combat_type_service == ports.combat_type_service).is_true()

	var phase_service: BattleInitializerPhaseService = BattleInitializerPhaseServiceScript.new()
	phase_service.configure_ports(ports)
	assert_str(phase_service.resolve_missing_dependency()).is_equal("")
	assert_bool(phase_service.id_factory == ports.id_factory).is_true()
	assert_bool(phase_service.battle_result_service == ports.battle_result_service).is_true()
	assert_bool(phase_service.field_lifecycle_service == ports.field_lifecycle_service).is_true()
