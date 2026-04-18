extends GdUnitTestSuite

# 入口 wrapper；断言本体下沉到 action_guard_action_flow/ 子目录。
const ActionGuardActionEffectChainSuiteScript := preload("res://test/suites/action_guard_action_flow/action_effect_chain_suite.gd")
const ActionGuardBattleEndSuiteScript := preload("res://test/suites/action_guard_action_flow/battle_end_suite.gd")
