extends GdUnitTestSuite

# 入口 wrapper；断言本体下沉到 manual_battle_scene/ 子目录。
const ManualFlowSuiteScript := preload("res://test/suites/manual_battle_scene/manual_flow_suite.gd")
const DemoReplaySuiteScript := preload("res://test/suites/manual_battle_scene/demo_replay_suite.gd")
