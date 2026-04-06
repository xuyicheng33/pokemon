extends RefCounted
class_name ContentValidationFormalRegistrySuite

const RuntimeRegistrySuiteScript := preload("res://tests/suites/content_validation_core/formal_registry/runtime_registry_suite.gd")
const DeliveryRegistrySuiteScript := preload("res://tests/suites/content_validation_core/formal_registry/delivery_registry_suite.gd")
const ScopedValidatorSuiteScript := preload("res://tests/suites/content_validation_core/formal_registry/scoped_validator_suite.gd")
const CatalogFactorySuiteScript := preload("res://tests/suites/content_validation_core/formal_registry/catalog_factory_suite.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
	RuntimeRegistrySuiteScript.new().register_tests(runner, failures, harness)
	DeliveryRegistrySuiteScript.new().register_tests(runner, failures, harness)
	ScopedValidatorSuiteScript.new().register_tests(runner, failures, harness)
	CatalogFactorySuiteScript.new().register_tests(runner, failures, harness)
