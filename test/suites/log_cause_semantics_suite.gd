extends GdUnitTestSuite

# 入口 wrapper；断言本体下沉到 log_cause_semantics/ 子目录。
# 锚点保留给 repo consistency gate：
# direct damage cause_event_id should point to the real action:hit event
# effect event cause_event_id must not point to itself
# turn_start regen cause_event_id should point to the real system:turn_start anchor
# field expire cause_event_id should point to the real system:turn_end anchor
const LogCauseChainSemanticsSuiteScript := preload("res://test/suites/log_cause_semantics/chain_semantics_suite.gd")
const LogCauseNoneRepeatSuiteScript := preload("res://test/suites/log_cause_semantics/none_repeat_suite.gd")
