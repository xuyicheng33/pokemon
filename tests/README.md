# Tests Skeleton

本目录承载当前业务回归闸门与测试支撑脚手架。

- `suites/`: 业务回归测试套件
- `suites/*_suite.gd`: 顶层 wrapper，只负责 `register_tests(...)` 聚合，不直接堆具体 `_test_*`
- `suites/*_contract_suite.gd` / `suites/*_runtime_suite.gd` / 角色子套件：按单一子域拆分的真实断言文件
- `suites/adapter_contract_suite.gd`: AI adapter 与 manager 输出边界契约回归
- `suites/ai_policy_decision_suite.gd`: 共享 AI 策略层纯决策回归
- `suites/trigger_validation_suite.gd`: 触发器声明一致性校验回归
- `support/`: 测试 harness、公共构造器与 suite 级共享 helper
- `run_all.gd`: Godot 原生测试入口（业务断言）
- `run_with_gate.sh`: 闸门脚本（业务断言 + 引擎级错误检查 + 架构约束 + 仓库一致性）
- `check_architecture_constraints.sh`: 分层与大文件架构闸门
- `check_repo_consistency.sh`: README/文档/关键回归一致性闸门
- `fixtures/`: 预留的样例输入与内容快照目录
- `helpers/`: 测试辅助脚本目录（已包含批量对战探针，如 `gojo_sukuna_batch_probe.gd`）
- `replay_cases/`: 固定 replay 案例与说明目录
- `helpers/domain_case_runner.gd`: 固定领域案例 runner；用于在 batch probe 统计异常时快速复查具体局面

当前约定：

- `run_all.gd` 只注册顶层 wrapper，不直接注册子套件，避免重复执行。
- 当单测试文件接近 `500` 行时，先做预拆分评估；超过 `600` 行前必须完成按子域拆分。
- 若 wrapper 内部的执行顺序带语义依赖，必须在 wrapper 文件头注明“顺序不可调换”的原因。
