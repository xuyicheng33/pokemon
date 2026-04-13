extends GdUnitTestSuite

# 入口 wrapper；断言本体下沉到 extension_validation_contract/ 子目录。
const SharedExtensionValidationSuiteScript := preload("res://test/suites/extension_validation_contract/shared_extensions_suite.gd")
const GojoExtensionValidationSuiteScript := preload("res://test/suites/extension_validation_contract/gojo_bad_cases_suite.gd")
const SukunaExtensionValidationSuiteScript := preload("res://test/suites/extension_validation_contract/sukuna_bad_cases_suite.gd")
const KashimoExtensionValidationSuiteScript := preload("res://test/suites/extension_validation_contract/kashimo_bad_cases_suite.gd")
const ObitoExtensionValidationSuiteScript := preload("res://test/suites/extension_validation_contract/obito_bad_cases_suite.gd")

