extends GdUnitTestSuite

# 入口 wrapper；断言本体下沉到 content_validation_core/ 子目录。
const ContentValidationBaseSnapshotSuiteScript := preload("res://test/suites/content_validation_core/snapshot_constraints_suite.gd")
const ContentValidationSetupSuiteScript := preload("res://test/suites/content_validation_core/setup_runtime_suite.gd")
const ContentValidationFormalRegistrySuiteScript := preload("res://test/suites/content_validation_core/formal_registry_suite.gd")
const ContentValidationPayloadDispatchSuiteScript := preload("res://test/suites/content_validation_core/payload_dispatch_suite.gd")

