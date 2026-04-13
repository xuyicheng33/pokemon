extends GdUnitTestSuite

# 入口 wrapper；断言本体下沉到 manager_snapshot_public_contract/ 子目录。
const ManagerSnapshotShapeSuiteScript := preload("res://test/suites/manager_snapshot_public_contract/snapshot_shape_suite.gd")
const ManagerSnapshotDetachSuiteScript := preload("res://test/suites/manager_snapshot_public_contract/visibility_runtime_suite.gd")
const ManagerSnapshotPublicBoundarySuiteScript := preload("res://test/suites/manager_snapshot_public_contract/public_id_suite.gd")
const ManagerSnapshotEffectInstanceOrderSuiteScript := preload("res://test/suites/manager_snapshot_public_contract/effect_instance_order_suite.gd")

