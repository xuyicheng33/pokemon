extends RefCounted
class_name ExtensionValidationContractSuite

# 入口 wrapper；断言本体下沉到 extension_validation_contract/ 子目录。
const SharedExtensionValidationSuiteScript := preload("res://tests/suites/extension_validation_contract/shared_extensions_suite.gd")
const GojoExtensionValidationSuiteScript := preload("res://tests/suites/extension_validation_contract/gojo_bad_cases_suite.gd")
const SukunaExtensionValidationSuiteScript := preload("res://tests/suites/extension_validation_contract/sukuna_bad_cases_suite.gd")
const KashimoExtensionValidationSuiteScript := preload("res://tests/suites/extension_validation_contract/kashimo_bad_cases_suite.gd")
const ObitoExtensionValidationSuiteScript := preload("res://tests/suites/extension_validation_contract/obito_bad_cases_suite.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    SharedExtensionValidationSuiteScript.new().register_tests(runner, failures, harness)
    GojoExtensionValidationSuiteScript.new().register_tests(runner, failures, harness)
    SukunaExtensionValidationSuiteScript.new().register_tests(runner, failures, harness)
    KashimoExtensionValidationSuiteScript.new().register_tests(runner, failures, harness)
    ObitoExtensionValidationSuiteScript.new().register_tests(runner, failures, harness)
