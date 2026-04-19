# 任务清单（活跃）

本文件只保留当前仍直接影响交付、门禁或下一步开发节奏的任务入口。

更早且已关闭的完整记录见：

- `docs/records/archive/tasks_2026-04-19_engineering_overhaul.md`
- `docs/records/archive/tasks_2026-04-10_to_2026-04-18_refactor_wave.md`
- `docs/records/archive/tasks_pre_2026-04-05_repair_wave.md`
- `docs/records/archive/tasks_pre_v0.6.4.md`
- `docs/records/archive/tasks_pre_v0.6.3.md`

当前生效规则以 `docs/rules/` 为准；工程结构与交付模板以 `docs/design/` 为准。
带日期的已完成阶段只保留当前仍有引用价值的摘要；完整流水统一看 archive。

## 最近完成：长期工程化重构波次（2026-04-19）

- 状态：已完成
- 总体目标：项目定位从"原型期"升级为长期工程，清理过度工程化的形式噪声，保留工程严谨性
- 分阶段结果：

| Stage | 内容 | 状态 |
|---|---|---|
| 0 | 统一定位与活跃规则基线 | 已完成 |
| 1 | composition 盘点 + 目标图冻结 + 错误体系设计 + payload dispatch 决策 | 已完成 |
| 2 | composition 主链路收缩（81→65 slot, 16 helper 下沉） | 已完成 |
| 3 | 错误体系统一（B/C 类内联/重命名） | 已完成 |
| 4 | 测试修复 + 死代码清理 | 已完成 |
| 5 | 测试结构评估（降级保留） | 已完成 |
| 6 | 文档 + gate 合并（降级保留） | 已完成 |
| 7 | 核心类型标注 | 已完成 |

- 验证：`bash tests/run_with_gate.sh` 全通过
- 详细子阶段记录见 `docs/records/archive/tasks_2026-04-19_engineering_overhaul.md`

## 最近完成：代码审阅修复（2026-04-19）

- 状态：已完成
- 目标：审阅当前实现并修复发现的问题
- 修复内容：
  1. `battle_core → composition` 逆向依赖：文档标注为受控例外 + architecture gate 增加白名单校验
  2. 核心函数参数类型标注：`battle_core` 119 个文件补齐 `BattleState / BattleContentIndex / ChainContext / QueuedAction / EffectEvent / Command` 的显式类型
  3. 冗余 `.gitkeep` 清理：移除 `content/` 下 7 个已有实际内容的目录中的 `.gitkeep`
- 验证：全部 gate 通过

## 最近完成：gate 修复收口（2026-04-19）

- 状态：已完成
- 目标：修复本轮类型标注后遗留的 gate 失败，恢复主线验证基线
- 修复内容：
  1. 强类型测试替身补齐：`sukuna_setup_skill_runtime_suite`、`field_lifecycle_contract_suite`、`manager_log_and_runtime_contract/replay_guard_failure_suite` 改为继承真实 service / resolver / dispatcher 类型，不再向强类型字段写入裸 `RefCounted`
  2. 期望伤害辅助同步 fake resolver：`tests/support/sukuna_setup_regen_test_support.gd` 新增可注入 `PowerBonusResolver`，保证 delegation contract 测试和运行时走同一套口径
  3. gdUnit warning 清零：`effect_precondition_service`、`payload_executor`、`action_chain_context_builder` 的 ternary 类型不兼容改成显式分支
  4. README 代码规模统计回写到当前真值，修复 repo consistency surface gate
- 验证：
  - `TEST_PATH=res://test/suites/sukuna_setup_skill_runtime_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/field_lifecycle_contract_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/manager_log_and_runtime_contract/replay_guard_failure_suite.gd bash tests/run_gdunit.sh`
  - `bash tests/check_gdunit_gate.sh`
  - `bash tests/run_with_gate.sh`

## 最近完成：审阅问题补齐（2026-04-20）

- 状态：已完成
- 目标：把 2026-04-19 全部提交复查后确认的问题补齐到代码、gate 和文档
- 修复内容：
  1. manager replay 容器依赖补校验：`BattleCoreManagerContainerService.run_replay_result()` 现在显式校验 `replay_runner`，缺失时返回 `invalid_composition` 并释放临时容器；补了对应 contract suite
  2. sandbox smoke 合同对齐真实 battle contract：`winner_side_id` 只在 `result_type=win` 时要求非空，`draw / no_winner` 必须保持为空
  3. `manual/manual` 主路径补成真实整局回归：`tests/check_sandbox_smoke_matrix.sh` 新增 `gojo_vs_sample + manual/manual` 覆盖，README 与当前阶段基线同步回写
- 验证：
  - `TEST_PATH=res://test/suites/manager_log_and_runtime_contract/replay_guard_summary_suite.gd bash tests/run_gdunit.sh`
  - `bash tests/check_sandbox_smoke_matrix.sh`
  - `bash tests/run_with_gate.sh`

## 当前验证基线

- 最小可玩性检查：
  - 可启动：能进入 `BattleSandbox` 主流程
  - 可操作：`manual/policy` 至少能完整跑完一局
  - 无阻断错误：没有崩溃、卡死或 invalid runtime 漂移
- 当前总验收入口：
  - `bash tests/check_repo_consistency.sh`
  - `bash tests/run_with_gate.sh`
