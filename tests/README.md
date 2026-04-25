# Tests Skeleton

本目录承载当前静态门禁、诊断脚本、共享辅助资源，以及 `gdUnit4` 的命令行入口。

当前日常研发顺序、Sandbox 试玩路径和文档更新要求，统一见 `docs/design/current_development_workflow.md`。
当前推荐复查命令和最小可玩性检查，统一见 `docs/design/current_stage_regression_baseline.md`。

## 1. 主要入口

- `tests/sync_formal_registry.sh`：formal source descriptor -> committed manifest/catalog 的唯一人工同步入口
- `tests/run_gdunit.sh`：`gdUnit4` CLI 入口；默认跑 quick profile，显式 `TEST_PROFILE=extended|full` 跑 `res://test`，并输出 `JUnit XML` 与 `HTML`
- `tests/check_gdunit_gate.sh`：`gdUnit4` + 引擎日志扫描；供总 gate 与 CI 复用
- `tests/check_boot_smoke.sh`：headless 启动 smoke；供总 gate 与 CI 复用
- `tests/run_with_gate.sh`：默认 quick 总入口；按固定顺序串起 quick `gdUnit4`、boot smoke、suite reachability、架构 gate、repo consistency gate、Python lint、quick sandbox smoke matrix
- `tests/run_extended_gate.sh`：显式 extended 入口；覆盖 extended `gdUnit4`、full sandbox smoke 和静态门禁
- `tests/check_suite_reachability.sh`：suite 可达性闸门
- `tests/check_architecture_constraints.sh`：分层与大文件架构闸门
- `tests/check_repo_consistency.sh`：仓库一致性闸门总入口
- `tests/check_sandbox_smoke_matrix.sh`：`BattleSandbox` 研发主路径 smoke matrix
- `tests/cleanup_local_artifacts.sh`：清理废弃本地报告目录与 scratch 目录；保留 `reports/gdunit`

## 2. 目录职责

- `test/suites/`：Godot 业务回归 suite 唯一目录；`gdUnit4` 会直接发现 `test/` 下的业务 suite
- `test/support/`：`gdUnit4` suite 公共基类与少量桥接资源
- `tests/support/`：共享 harness、构局 helper、固定案例 support；供 `gdUnit4` suite、导出脚本与诊断 runner 复用
- `tests/helpers/`：辅助脚本目录
- `tests/gates/`：仓库一致性细分 gate；当前按 `surface / formal_character / docs` 三类拆开维护
- `tests/fixtures/`：样例输入与内容快照
- `tests/replay_cases/`：固定 replay 案例与说明

## 3. 测试分类口径

测试分类口径：

- `sandbox`：BattleSandbox 场景、launch-config、试玩主路径
- `characters/<role>`：角色私有 runtime / snapshot / smoke
- `engine_core`：回合、行动、生命周期、内容快照与核心合同
- `extensions`：payload、rule_mod、targeting、shared extension
- `manager_contract`：manager facade、公开快照、事件日志、session guard
- `replay`：replay input / summary / determinism / 浏览回归

gdUnit 直接发现 `test/suites/` 下的具体 suite；大型主题可拆到同名子目录，但不再用 `register_tests` wrapper 聚合。
默认测试分层为 `quick -> extended -> full`：quick 保留开发门禁主路径，extended 保留长尾边界和历史回归，full 在 extended 基础上使用 `SANDBOX_SMOKE_SCOPE=full`。
GDScript 前导缩进固定只允许 tab；`test/**/shared*.gd`、`test/**/*_shared.gd`、`tests/support/**/*.gd` 当前统一纳入 support helper 体量门禁。

## 4. formal 单源约定

- `config/formal_character_sources/` 是 formal 角色元数据的唯一人工真源
- `config/formal_character_manifest.json` 与 `config/formal_character_capability_catalog.json` 是 committed 生成产物
- source descriptor 改动后，先执行 `bash tests/sync_formal_registry.sh`
- runtime、tests 与 gate 都只消费同步后的 manifest / capability catalog

formal 交付细节统一看：

- `docs/design/formal_character_delivery_checklist.md`
- `docs/design/formal_character_capability_catalog.md`

## 5. 日常推荐命令

- 快跑单 suite：`TEST_PATH=res://test/suites/<suite>.gd bash tests/run_gdunit.sh`
- BattleSandbox 手动主路径回归：`TEST_PATH=res://test/suites/manual_battle_scene/manual_flow_suite.gd bash tests/run_gdunit.sh`
- BattleSandbox demo 回放浏览回归：`TEST_PATH=res://test/suites/manual_battle_scene/demo_replay_suite.gd bash tests/run_gdunit.sh`
- BattleSandbox launch-config 回归：`TEST_PATH=res://test/suites/battle_sandbox_launch_config_contract_suite.gd bash tests/run_gdunit.sh`
- BattleSandbox boot smoke：`bash tests/check_boot_smoke.sh`
- BattleSandbox 主路径 smoke：`bash tests/check_sandbox_smoke_matrix.sh`
- BattleSandbox 全量可见 matchup smoke：`SANDBOX_SMOKE_SCOPE=full bash tests/check_sandbox_smoke_matrix.sh`
- BattleSandbox headless 整局复查：`godot --headless --path . --script tests/helpers/manual_battle_full_run.gd`
- BattleSandbox headless 真实提交流程复查：`godot --headless --path . --script tests/helpers/manual_battle_submit_full_run.gd`
- demo replay headless 复查：`DEMO_PROFILE=legacy godot --headless --path . --script tests/helpers/demo_replay_full_run.gd`
- 日常 quick 验收：`bash tests/run_with_gate.sh`
- 阶段 extended 验收：`bash tests/run_extended_gate.sh`
- 完整 full 验收：`TEST_PROFILE=full bash tests/run_with_gate.sh`
- 清理本地废弃报告与 scratch：`bash tests/cleanup_local_artifacts.sh`

闸门脚本当前显式依赖 `godot`、`python3` 与 `rg`；缺少任一工具时必须直接 fail-fast，不做隐式 fallback。
.gd.uid 当前也纳入仓库治理：有效 `.gd.uid` 必须随同对应 `.gd` 提交，孤儿 `.gd.uid` 会被 repo consistency gate 直接拦下。
