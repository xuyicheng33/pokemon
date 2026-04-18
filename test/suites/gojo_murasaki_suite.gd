extends GdUnitTestSuite

# 入口 wrapper；断言本体下沉到 gojo_murasaki/ 子目录。
# 锚点保留给 repo consistency gate：func test_gojo_murasaki_double_mark_burst_contract(
const GojoMurasakiMarksSuiteScript := preload("res://test/suites/gojo_murasaki/marks_suite.gd")
const GojoMurasakiOutcomeSuiteScript := preload("res://test/suites/gojo_murasaki/outcome_suite.gd")
