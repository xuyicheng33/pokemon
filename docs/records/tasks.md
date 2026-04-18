# 任务清单（活跃）

本文件只保留仍会直接影响扩角决策、交付验收或回归节奏的现行任务信息。

更早且已关闭的完整记录见：

- `docs/records/archive/tasks_pre_2026-04-05_repair_wave.md`
- `docs/records/archive/tasks_pre_v0.6.4.md`
- `docs/records/archive/tasks_pre_v0.6.3.md`

当前生效规则以 `docs/rules/` 为准；工程落点与交付模板以 `docs/design/` 为准。
带日期的已完成阶段只记录当时口径；当前默认入口、验证路径与治理要求以后面的最新阶段条目和 `docs/design/current_development_workflow.md` 为准。

## 当前阶段：SampleBattleFactory facade 继续瘦身（2026-04-18）

- 状态：已完成
- 目标：
  - 保持 `SampleBattleFactory` 公开方法集不变，把可用 matchup 聚合和 content snapshot path 厚逻辑继续下沉到独立 service。
- 范围：
  - `src/composition/sample_battle_factory.gd`
  - `src/composition/sample_battle_factory_available_matchups_service.gd`
  - `src/composition/sample_battle_factory_base_snapshot_paths_service.gd`
  - `src/composition/sample_battle_factory_formal_snapshot_paths_service.gd`
  - `src/composition/sample_battle_factory_content_paths_helper.gd`
  - `test/suites/sample_battle_factory_contract_suite.gd`
  - `docs/records/tasks.md`
- 验收标准：
  - `SampleBattleFactory.available_matchups_result()` 只保留 facade 转发，不再内联 baseline/formal descriptor 拼装
  - base content dirs 收集与 formal registry snapshot 追加分拆到独立 owner，`content_snapshot_paths_result()` 与 `content_snapshot_paths_for_setup_result()` 对外行为不变
  - 旧 `sample_battle_factory_content_paths_helper.gd` 如继续保留，只承担薄转发职责
  - sample factory 合同测试补上 facade 聚合、formal catalog 失败传递、baseline-only setup snapshot 忽略 formal runtime registry 失败
- 结果：
  - 已新增 `SampleBattleFactoryAvailableMatchupsService`，baseline/formal matchup descriptor 聚合从 factory 本体移出
  - 已新增 `SampleBattleFactoryBaseSnapshotPathsService` 与 `SampleBattleFactoryFormalSnapshotPathsService`，把基础目录扫描、formal registry 追加和 setup-scoped 过滤拆开
  - `sample_battle_factory_content_paths_helper.gd` 已改成兼容旧注入面的薄转发层，供 demo builder 与 override router 继续复用
  - sample factory 合同测试已补 facade 成功面、formal catalog 失败面和 baseline-only setup snapshot 合同
- 验证：
  - `TEST_PATH=res://test/suites/sample_battle_factory_contract_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/battle_sandbox_launch_config_contract_suite.gd bash tests/run_gdunit.sh`

## 当前阶段：BattleState 索引缓存与构造路径预热（2026-04-18）

- 状态：已完成
- 目标：
  - 在不改 `battle_state.sides` 结构的前提下，为 `BattleState` 增加 side/unit 索引缓存，并让直接改数组后的查询结果仍保持正确。
- 范围：
  - `src/battle_core/runtime/battle_state.gd`
  - `src/battle_core/turn/battle_initializer.gd`
  - `src/battle_core/turn/battle_initializer_setup_validator.gd`
  - `src/battle_core/logging/replay_runner_execution_context_builder.gd`
  - 常用 runtime test harness / support 的初始化入口
  - 直接相关测试与 `docs/records/tasks.md`
- 验收标准：
  - `BattleState` 新增 `_side_by_id / _unit_by_id / _unit_by_public_id / append_side() / rebuild_indexes()`
  - `get_side / get_unit / get_unit_by_public_id` 改为 cache-first，并在缓存失配时按当前数组重建索引
  - 初始化、回放和常用 support 的建局路径在 `sides` 建好后显式 `rebuild_indexes()`
  - 增加直接覆盖“手改 `sides` / `team_units` 后仍不会返回旧对象”的测试
- 结果：
  - `BattleState` 已补 side/unit/public_id 三张索引表，`append_side()` 会增量入索引，`rebuild_indexes()` 会按当前数组全量重建
  - 三个查询入口现在都会先走缓存，再用当前数组校验缓存是否仍指向线性遍历下的真实命中；失配时立即 `rebuild_indexes()`
  - `BattleInitializer` 已切到 `append_side()`，并在 side 构建完成后显式 `rebuild_indexes()`；setup validator 清空 `sides` 时也会同步清空索引
  - replay builder 和常用 support 的 `build_initialized_battle()` 路径已补显式 `rebuild_indexes()` 预热
  - 已新增 battle_state 索引缓存回归测试，并把一个手工拼装 side 的 public snapshot 测试切到 `append_side()`
- 验证：
  - `TEST_PATH=res://test/suites/battle_state_index_cache_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/manager_snapshot_public_contract/effect_instance_order_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/replay_determinism_suite.gd bash tests/run_gdunit.sh`

## 当前阶段：composition 依赖声明收口（2026-04-18）

- 状态：已完成
- 目标：
  - 把 battle core 的服务依赖、reset 字段与缺依赖检查统一收口到各 script 自声明，删除 split wiring specs 目录这份重复真相。
- 范围：
  - `src/composition/*`
  - `src/battle_core/**/*` 中参与 compose 的 service / payload handler / payload runtime service
  - `tests/gates/architecture_composition_consistency_gate*.py`
  - `tests/gates/architecture_wiring_graph_gate.py`
  - `docs/design/battle_core_architecture_constraints.md`
  - `docs/design/architecture_overview.md`
  - `docs/design/project_folder_structure.md`
  - `README.md`
  - `docs/records/tasks.md`
  - `docs/records/decisions.md`
- 验收标准：
  - `COMPOSE_DEPS / COMPOSE_RESET_FIELDS` 成为 compose 依赖与 reset 的唯一运行时声明
  - `BattleCoreComposer`、runtime 缺依赖检查与两条 architecture gate 都直接读取这份声明
  - `src/composition/battle_core_wiring_specs.gd` 与 `src/composition/battle_core_wiring_specs/` 目录删除
  - `BattleCoreManager.resolve_missing_dependency()` 对外行为不变
  - `python3 tests/gates/architecture_composition_consistency_gate.py`
  - `python3 tests/gates/architecture_wiring_graph_gate.py`
  - `bash tests/check_architecture_constraints.sh` 全部通过
- 结果：
  - 已新增 `src/composition/service_dependency_contract_helper.gd`，统一提供 compose 依赖读取、递归缺依赖检查与 reset spec 导出
  - 已把 battle core 参与 compose 的 service / payload handler / payload runtime service 切到 `COMPOSE_DEPS`，`RuleModValueResolver` 也已补 `COMPOSE_RESET_FIELDS`
  - `BattleCoreComposer`、`RuntimeGuardService` 与 `TurnLoopController` 的缺依赖路径已改为直接复用 helper，不再继续手抄 wiring 递归链
  - 两条 architecture gate 已改成直接解析 script 自声明；payload handler -> runtime service 这条边也已纳入 DAG 校验
  - legacy wiring spec 聚合文件与 split 目录已从 `src/composition/` 删除
- 验证：
  - `python3 tests/gates/architecture_composition_consistency_gate.py`
  - `python3 tests/gates/architecture_wiring_graph_gate.py`
  - `bash tests/check_architecture_constraints.sh`

## 当前阶段：turn / init 编排 owner 拆分（2026-04-18）

- 状态：已完成
- 目标：
  - 拆掉 `turn_resolution_service` 这个回合热点，并把 `BattleInitializer` 的 setup 校验从 owner 本体里继续下沉。
- 范围：
  - `src/battle_core/turn/*`
  - `src/composition/battle_core_service_specs.gd`
  - `test/suites/action_guard_invalid_runtime_suite.gd`
  - `tests/support/obito_runtime_contract_support_heal_block.gd`
  - `docs/design/turn_orchestrator.md`
  - `docs/records/tasks.md`
  - `docs/records/decisions.md`
- 验收标准：
  - `turn_resolution_service.gd` 删除
  - `TurnLoopController` 直接依赖 `turn_selection_resolver / turn_start_phase_service / turn_end_phase_service / turn_field_lifecycle_service`
  - `BattleInitializer` 只保留顺序调度、错误传递与依赖同步；setup 校验下沉到独立 owner
  - turn/init 主回归继续通过，至少覆盖 invalid runtime、初始化链路、domain clash、forced replace、field lifecycle
- 结果：
  - 已新增 `turn_start_phase_service.gd`、`turn_end_phase_service.gd` 与 `battle_initializer_setup_validator.gd`
  - `TurnLoopController` 已从旧 `turn_resolution_service` 切到四个单责 owner；命令锁定、turn_start、turn_end 与 field lifecycle 的职责边界已拆开
  - `BattleInitializer` 已把 format / setup / base runtime field 准备下沉到 `battle_initializer_setup_validator.gd`
  - `turn_resolution_service.gd` 与对应 service slot 已删除
  - 测试/support 对旧 `turn_resolution_service` 的直接引用已切到 `turn_selection_resolver` 或新的缺依赖破坏点
- 验证：
  - `TEST_PATH=res://test/suites/action_guard_invalid_runtime_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/init_matchup_lifecycle_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/domain_clash_guard_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/forced_replace_lifecycle_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/forced_replace_field_break_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/field_lifecycle_contract_suite.gd bash tests/run_gdunit.sh`
  - `bash tests/check_architecture_constraints.sh`

## 当前阶段：README surface 合同修复与 demo replay 回归补齐（2026-04-18）

- 状态：已完成
- 目标：
  - 把 4 月 18 日整理提交带出的 README surface 漂移修回主线，并把 `demo replay` 从“保留入口但无人回归”补成固定 smoke 覆盖。
- 范围：
  - `README.md`
  - `tests/README.md`
  - `docs/design/current_stage_regression_baseline.md`
  - `docs/records/tasks.md`
  - `docs/records/decisions.md`
  - `src/composition/sample_battle_factory.gd`
  - `src/adapters/sandbox_session_coordinator.gd`
  - `tests/check_sandbox_smoke_matrix.sh`
  - `tests/helpers/demo_replay_full_run.gd`
- 验收标准：
  - `bash tests/check_repo_consistency.sh` 与 `bash tests/run_with_gate.sh` 不再因为 README 表面合同失败
  - README 继续显式写明 `content_snapshot_paths_result()` 的基础覆盖面，并同步最新 GDScript 行数
  - `demo=<profile>` 的 `battle_summary` 使用真实 profile 的 `matchup_id / battle_seed`
  - `tests/check_sandbox_smoke_matrix.sh` 固定覆盖 `legacy` 与 `kashimo` 两个 demo profile
  - 活跃任务与决策记录补回这轮 4 月 18 日的整理与修复落点
- 结果：
  - README 已补回 `content_snapshot_paths_result()` 覆盖说明，并同步到当前代码规模统计
  - `SampleBattleFactory` 已开放 `demo_profile_result()`；`SandboxSessionCoordinator` 在 demo replay 路径上已改为按 profile 真值生成摘要上下文
  - 新增 `tests/helpers/demo_replay_full_run.gd`，固定输出 demo profile 对应的 `battle_summary` JSON
  - `tests/check_sandbox_smoke_matrix.sh` 已补进 `legacy demo` 与 `kashimo demo` 两条 smoke
  - `tests/README.md`、阶段回归基线与活跃记录已同步到新的 demo replay 验证面
- 验证：
  - `bash tests/check_repo_consistency.sh`
  - `bash tests/check_sandbox_smoke_matrix.sh`
  - `DEMO_PROFILE=legacy godot --headless --path . --script tests/helpers/demo_replay_full_run.gd`
  - `DEMO_PROFILE=kashimo godot --headless --path . --script tests/helpers/demo_replay_full_run.gd`
  - `bash tests/run_with_gate.sh`

## 当前阶段：BattleSandbox 研发试玩打磨（2026-04-13）

- 状态：已完成
- 目标：
  - 把 `BattleSandbox` 的默认研发试玩路径收口到更适合单人复查的 `manual/policy`，并把 HUD / headless 输出统一到稳定摘要结构。
- 范围：
  - `src/adapters/battle_sandbox_launch_config.gd`
  - `src/adapters/battle_sandbox_controller.gd`
  - `src/adapters/sandbox_session_coordinator.gd`
  - `src/adapters/sandbox_event_log_buffer.gd`
  - `src/adapters/sandbox_view_presenter.gd`
  - `tests/support/manual_battle_scene_drive_support.gd`
  - `tests/helpers/manual_battle_full_run.gd`
  - `test/suites/manual_battle_scene_suite.gd`
  - `README.md`
  - `tests/README.md`
  - `docs/design/current_development_workflow.md`
  - `docs/records/tasks.md`
  - `docs/records/decisions.md`
- 验收标准：
  - 默认启动行为调整为 `gojo_vs_sample + 9101 + manual/policy`
  - 可见 preset matchup 固定按 `gojo_vs_sample / kashimo_vs_sample / sukuna_setup / sample_default / 其余可见项` 推荐排序
  - HUD 固定补出配置摘要、当前待选边与 policy 状态、已提交指令摘要、稳定 `battle_summary` 和按回合分隔的最近日志
  - `battle_summary` 至少稳定包含 `matchup_id / battle_seed / p1_control_mode / p2_control_mode / winner_side_id / reason / result_type / turn_index / event_log_cursor / command_steps`
  - `manual/manual`、`manual/policy`、`policy/policy` 三条主路径都能跑到终局，并输出同一套摘要结构
- 结果：
  - `BattleSandboxLaunchConfig` 默认已改成 `manual/policy`，可见 matchup 列表已在 adapter 层固定推荐顺序
  - `BattleSandboxController + SandboxSessionCoordinator` 现在统一累计 `command_steps`，并把它并入 `get_state_snapshot()` 与 `battle_summary`
  - `SandboxEventLogBuffer` 已把最近日志改成按回合分隔的可读窗口，并为未终局/终局统一维护同一份摘要 shape
  - `SandboxViewPresenter` 已把 HUD 状态收口到配置摘要、当前待选边、policy 状态、已提交指令摘要和稳定终局摘要文案
  - `manual_battle_full_run.gd` 已改成直接输出统一 `battle_summary` JSON；`manual_battle_scene_suite` 也已同步到新的默认路径和摘要 contract
- 验证：
  - `TEST_PATH=res://test/suites/manual_battle_scene_suite.gd bash tests/run_gdunit.sh`
  - `godot --headless --path . --script tests/helpers/manual_battle_full_run.gd`
  - `MATCHUP_ID=kashimo_vs_sample P1_MODE=manual P2_MODE=policy godot --headless --path . --script tests/helpers/manual_battle_full_run.gd`
  - `P1_MODE=policy P2_MODE=policy godot --headless --path . --script tests/helpers/manual_battle_full_run.gd`

## 当前阶段：验证体系硬化（2026-04-13）

- 状态：已完成
- 目标：
  - 把 `BattleSandbox` 的默认启动 contract、推荐排序 contract、docs-gate 聚合完整性和三条主路径 smoke 一起接进唯一总 gate。
- 范围：
  - `test/suites/battle_sandbox_launch_config_contract_suite.gd`
  - `tests/check_sandbox_smoke_matrix.sh`
  - `tests/run_with_gate.sh`
  - `tests/gates/repo_consistency_docs_gate.py`
  - `tests/gates/repo_consistency_docs_gate_module_self_check.py`
  - `tests/gates/repo_consistency_docs_gate_sandbox_testing_surface.py`
  - `tests/gates/repo_consistency_docs_gate_shared.py`
  - `README.md`
  - `tests/README.md`
  - `docs/design/current_development_workflow.md`
  - `docs/design/current_stage_regression_baseline.md`
  - `docs/records/tasks.md`
  - `docs/records/decisions.md`
- 验收标准：
  - `tests/run_with_gate.sh` 继续通过，且内部顺序固定为 `gdUnit4 -> boot smoke -> suite reachability -> architecture constraints -> repo consistency -> sandbox smoke matrix`
  - 新增 `battle_sandbox_launch_config_contract_suite.gd`，锁住默认 launch config、归一化和推荐排序
  - 新增 `tests/check_sandbox_smoke_matrix.sh`，固定覆盖默认 `manual/policy`、`kashimo_vs_sample + manual/policy`、`gojo_vs_sample + policy/policy`
  - docs gate 聚合入口新增模块自检，防止 docs 子模块漏接
  - 新增“当前阶段回归基线”文档，只保留推荐复查命令、主 smoke matchup 和最小可玩性检查
- 结果：
  - `battle_sandbox_launch_config_contract_suite.gd` 已落地，默认 launch config、归一化 contract 与推荐排序都已单独锁住
  - `tests/check_sandbox_smoke_matrix.sh` 已接入三条研发主路径，并直接校验统一 `battle_summary` JSON 的稳定字段
  - `tests/run_with_gate.sh` 已固定到 `gdUnit4 -> boot smoke -> suite reachability -> architecture constraints -> repo consistency -> sandbox smoke matrix`
  - docs gate 聚合入口已新增 `repo_consistency_docs_gate_module_self_check.py`，用 preflight 方式自检子模块接线完整性
  - `docs/design/current_stage_regression_baseline.md` 已成为当前推荐复查命令、主 smoke matchup 和最小可玩性检查的单一设计落点
- 验证：
  - `TEST_PATH=res://test/suites/battle_sandbox_launch_config_contract_suite.gd bash tests/run_gdunit.sh`
  - `bash tests/check_sandbox_smoke_matrix.sh`
  - `bash tests/check_repo_consistency.sh`
  - `bash tests/run_with_gate.sh`

## 当前阶段：外围重构与热点文件拆分（2026-04-13）

- 状态：已完成
- 目标：
  - 把 `BattleSandboxController` 收成薄 orchestrator，拆出 session / policy / view / event log 四个协作者，并把测试 support 调用面统一迁到 6 个正式入口。
- 范围：
  - `src/adapters/battle_sandbox_controller.gd`
  - `src/adapters/sandbox_session_coordinator.gd`
  - `src/adapters/sandbox_policy_driver.gd`
  - `src/adapters/sandbox_view_presenter.gd`
  - `src/adapters/sandbox_event_log_buffer.gd`
  - `tests/support/manual_battle_scene_support.gd`
  - `tests/support/manual_battle_scene_context_support.gd`
  - `tests/support/manual_battle_scene_drive_support.gd`
  - `tests/helpers/manual_battle_full_run.gd`
  - `docs/records/tasks.md`
  - `docs/records/decisions.md`
- 验收标准：
  - `BattleSandboxController` 只保留场景生命周期入口、UI 事件转发和状态刷新总编排
  - `SandboxSessionCoordinator / SandboxPolicyDriver / SandboxViewPresenter / SandboxEventLogBuffer` 四个协作者已落地，旧职责不再堆回 controller
  - 历史 wrapper `bootstrap_manual_mode()`、`restart_manual_session()`、`submit_selected_action()` 已删除
  - `ManualBattleSceneSupport` 已拆成 facade + context/drive 两块，测试与 helper 统一走正式入口
  - `manual_battle_scene_suite` 与 headless helper 三条主路径全部通过
- 结果：
  - `battle_sandbox_controller.gd` 已降到薄 orchestrator，主要逻辑固定委托给四个 sandbox 协作者
  - `SandboxSessionCoordinator` 已收口 session 生命周期、snapshot/log/legal actions 刷新和 command 提交流程
  - `SandboxPolicyDriver` 已独立收口 policy 自动推进与停止条件；`SandboxViewPresenter` 已接管 view model 和 HUD 渲染；`SandboxEventLogBuffer` 已接管事件增量与最近日志缓存
  - `ManualBattleSceneSupport` 已改成 facade，内部拆为 `ManualBattleSceneContextSupport + ManualBattleSceneDriveSupport`
  - `tests/helpers/manual_battle_full_run.gd` 继续复用 `ManualBattleSceneSupport`，但底层已经只依赖正式入口 `submit_action`
- 验证：
  - `TEST_PATH=res://test/suites/manual_battle_scene_suite.gd bash tests/run_gdunit.sh`
  - `godot --headless --path . --script tests/helpers/manual_battle_full_run.gd`
  - `MATCHUP_ID=kashimo_vs_sample P1_MODE=manual P2_MODE=policy godot --headless --path . --script tests/helpers/manual_battle_full_run.gd`
  - `P1_MODE=policy P2_MODE=policy godot --headless --path . --script tests/helpers/manual_battle_full_run.gd`

## 当前阶段：文档治理收口（2026-04-13）

- 状态：已完成
- 目标：
  - 固定 `docs/rules / docs/design / docs/records` 的职责边界，补一份当前研发工作流设计文档，并把 docs gate / formal support 热点拆回可持续维护的结构。
- 范围：
  - `docs/design/current_development_workflow.md`
  - `README.md`
  - `tests/README.md`
  - `docs/design/project_folder_structure.md`
  - `docs/rules/README.md`
  - `tests/gates/repo_consistency_docs_gate.py`
  - `tests/gates/repo_consistency_docs_gate_*.py`
  - `tests/gates/repo_consistency_formal_character_gate_support.py`
  - `tests/gates/repo_consistency_formal_character_*_support.py`
  - `docs/records/tasks.md`
  - `docs/records/decisions.md`
- 验收标准：
  - `docs/rules/` 只保留规则权威；`docs/design/` 明确承接工程结构、测试矩阵、Sandbox 用法和治理规则；`docs/records/` 明确承接活跃记录与归档索引
  - 新增一份固定格式的当前研发工作流文档，写清代码分层边界、Sandbox 日常路径、测试入口与文档更新顺序
  - `repo_consistency_docs_gate.py` 收回到薄聚合入口，docs gate 按 `runtime/contracts`、`content/formal delivery`、`sandbox/testing surface`、`records/archive wording` 四块拆开
  - `repo_consistency_formal_character_gate_support.py` 收回到薄 facade，manifest 读取、suite/needle 校验、pair/capability 派生辅助分别拆开
  - README、tests README、design 文档与 records 口径统一到 `BattleSandbox`、`tests/run_with_gate.sh`、`gdUnit4 + test/`
- 结果：
  - `docs/design/current_development_workflow.md` 已成为当前研发路径的单一设计入口，统一收口代码边界、Sandbox 日常复查、测试入口和文档更新顺序
  - `README.md`、`tests/README.md`、`docs/design/project_folder_structure.md` 与 `docs/rules/README.md` 已同步到新的文档治理基线，并显式引用 workflow 文档
  - docs gate 已拆成 `runtime_contracts / content_formal_delivery / sandbox_testing_surface / records_archive_wording` 四块，顶层只负责聚合
  - formal character gate support 已拆成 `manifest_io / suite_needle / pair_capability` 三块，原 support 文件只保留薄转发
- 验证：
  - `bash tests/check_repo_consistency.sh`
  - `bash tests/check_architecture_constraints.sh`
  - `bash tests/run_gdunit.sh`
  - `bash tests/run_with_gate.sh`

## 历史阶段：BattleSandbox V1 收口 + V2 单人试玩增强（2026-04-13，当时口径）

- 状态：已完成
- 目标：
  - 把 `BattleSandbox` 的手动热座基线收成稳定 launch-config 入口，并补齐单人高频试玩所需的配置化重开、sandbox-local policy 与终局摘要。
- 范围：
  - `scenes/sandbox/BattleSandbox.tscn`
  - `src/adapters/battle_sandbox_controller.gd`
  - `src/adapters/battle_sandbox_launch_config.gd`
  - `src/adapters/battle_sandbox_policy_port.gd`
  - `src/adapters/battle_sandbox_first_legal_policy.gd`
  - `src/adapters/battle_ui_view_model_builder.gd`
  - `src/composition/sample_battle_factory.gd`
  - `src/composition/sample_battle_factory_matchup_catalog.gd`
  - `test/suites/manual_battle_scene_suite.gd`
  - `tests/support/manual_battle_scene_support.gd`
  - `tests/helpers/manual_battle_full_run.gd`
  - `README.md`
  - `tests/README.md`
  - `docs/design/architecture_overview.md`
  - `docs/design/formal_character_delivery_checklist.md`
  - `tests/replay_cases/*.md`
  - `docs/records/tasks.md`
  - `docs/records/decisions.md`
- 验收标准：
  - （当时口径）默认启动行为继续保持 `gojo_vs_sample + seed=9101 + manual/manual`
  - `BattleSandboxController` 固定补出 `bootstrap_with_config(config)`、`restart_session_with_config(config)`、`submit_action(selected_action)`、`fetch_legal_actions_for_side(side_id)`、`get_state_snapshot()` 与 `build_view_model()`
  - （当时口径）`SampleBattleFactory.available_matchups_result()` 能提供 baseline 在前、formal 在后的 preset matchup facade，UI 默认只展示非 `test_only`
  - `manual/policy` 与 `policy/policy` 都能稳定打到终局，并补出 `battle_summary`
  - README、design、tasks、replay case 的现行口径不再把 `run_all.gd` 或 `BattleSandboxRunner` 当活入口
- 结果：
  - `BattleSandbox` 当时已固定走 launch config 驱动，默认基线保持 `manual/manual`，并补出 `matchup / battle_seed / P1 mode / P2 mode` 配置化重开
  - sandbox-local policy 已通过独立 port 接入 `adapters` 层，默认策略顺序固定为 `forced_command_type > 第一个 ultimate > 第一个 skill > 第一个 switch > wait`
  - `get_state_snapshot()` 与 `build_view_model()` 已固定补出 `launch_config / side_control_modes / available_matchups / battle_summary`
  - `manual_battle_full_run.gd` 已扩成参数化 headless 入口，支持 `MATCHUP_ID / BATTLE_SEED / P1_MODE / P2_MODE`
  - README、tests README、architecture overview、formal delivery checklist 与 replay case 已同步到当前 sandbox 入口和验证口径
- 验证：
  - `TEST_PATH=res://test/suites/manual_battle_scene_suite.gd bash tests/run_gdunit.sh`
  - `godot --headless --path . --script tests/helpers/manual_battle_full_run.gd`
  - `MATCHUP_ID=kashimo_vs_sample P1_MODE=manual P2_MODE=policy godot --headless --path . --script tests/helpers/manual_battle_full_run.gd`
  - `P1_MODE=policy P2_MODE=policy godot --headless --path . --script tests/helpers/manual_battle_full_run.gd`
  - `bash tests/run_with_gate.sh`

## 当前实施：gdUnit4 全面切换（2026-04-13）

- 状态：已完成
- 目标：
  - 把 Godot 业务测试唯一切到 `gdUnit4`，下线旧的 `run_all.gd + register_tests` 入口，并让 `BattleSandbox` 的手动热座场景验证固定回到 gdUnit 门禁里。
- 范围：
  - `addons/gdUnit4`
  - `project.godot`
  - `test/**/*.gd`
  - `tests/run_gdunit.sh`
  - `tests/run_with_gate.sh`
  - `tests/check_suite_reachability.sh`
  - `tests/gates/*.py`
  - `README.md`
  - `tests/README.md`
  - `docs/design/project_folder_structure.md`
  - `docs/design/log_and_replay_contract.md`
  - `docs/records/tasks.md`
  - `docs/records/decisions.md`
- 验收标准：
  - `test/` 成为唯一 Godot 业务测试目录，`tests/run_all.gd` 与 `tests/suites/` 下线
  - `tests/run_with_gate.sh` 继续作为唯一总入口，并改为调用 `gdUnit4` CLI
  - `BattleSandbox` 手动热座场景 suite 继续纳入总门禁
  - 本地总门禁稳定通过，并产出 `JUnit XML + HTML` 报告
- 结果：
  - `gdUnit4` 已正式 vendor 到仓库，并在 `project.godot` 里启用插件
  - `tests/run_gdunit.sh` 已成为统一 CLI 入口，支持 `TEST_PATH` / `REPORT_DIR`
  - `test/` 下的 suite 已作为正式业务测试树接管执行，旧 `tests/run_all.gd` 与 `tests/suites/` 已删除
  - `repo consistency`、`suite reachability`、README 与测试文档都已切到 `gdUnit4 + test/ + func test_*()` 新口径
  - `BattleSandbox` 的 gdUnit 场景验证继续保留在全量门禁内，并随总门禁一起复核通过
- 验证：
  - `bash tests/run_with_gate.sh`

## 当前优化：手动热座场景收尾与整局验证（2026-04-13）

- 状态：已完成
- 目标：
  - 把 `BattleSandbox` 的手动热座入口再补一层可视化 smoke 和整局跑完验证，同时顺手清掉当前 Godot debug 启动时最显眼的一批 warning。
- 范围：
  - `src/adapters/battle_sandbox_controller.gd`
  - `src/composition/battle_core_container.gd`
  - `src/battle_core/facades/battle_core_manager_contract_helper.gd`
  - `src/battle_core/facades/battle_core_manager_session_service.gd`
  - `src/composition/battle_core_payload_runtime_service_registry.gd`
  - `src/battle_core/turn/turn_selection_resolver.gd`
  - `src/composition/sample_battle_factory_demo_catalog.gd`
  - `src/battle_core/content/formal_validators/kashimo/content_snapshot_formal_kashimo_ultimate_domain_contracts.gd`
  - `tests/support/manual_battle_scene_support.gd`
  - `test/suites/manual_battle_scene_suite.gd`
  - `tests/helpers/manual_battle_full_run.gd`
  - `docs/records/tasks.md`
- 验收标准：
  - 手动热座场景的 HUD 节点结构与首屏状态文案可稳定检查
  - 手动热座支持固定策略自动跑到 `battle_result`
  - 本轮确认到的 Godot debug 启动 warning 不再继续由同名局部变量 / 参数和三元表达式类型不兼容触发
  - 完整 `tests/run_with_gate.sh` 继续通过
- 结果：
  - `ManualBattleSceneSupport` 已新增 `run_to_battle_end()`，用于固定策略整局跑完
  - `manual_battle_scene_suite` 已补 `manual_scene_hud_node_graph_smoke` 与 `manual_scene_auto_battle_reaches_battle_result`
  - 新增 `tests/helpers/manual_battle_full_run.gd`，可直接 headless 跑完一局并输出最终 `battle_result`
  - 本轮 Godot debug 输出里已确认的局部命名 shadowing 和三元表达式类型 warning 已清掉对应触发点
- 验证：
  - `godot --headless --path . --script tests/helpers/manual_battle_full_run.gd`
  - `TEST_PATH=res://test/suites/manual_battle_scene_suite.gd bash tests/run_gdunit.sh`
  - `bash tests/run_with_gate.sh`

## 当前实现：手动热座战斗场景 v1（2026-04-13）

- 状态：已完成
- 目标：
  - 把 `BattleSandbox` 默认入口从自动 demo 回放切到可手动打完一局的双边热座场景，固定先做 `gojo_vs_sample`，并继续只走现有 `BattleCoreManager` 会话流。
- 范围：
  - `scenes/sandbox/BattleSandbox.tscn`
  - `src/adapters/battle_sandbox_controller.gd`
  - `src/adapters/player_selection_adapter.gd`
  - `src/adapters/battle_ui_view_model_builder.gd`
  - `test/suites/manual_battle_scene_suite.gd`
  - `tests/support/manual_battle_scene_support.gd`
  - `tests/run_gdunit.sh`
  - `README.md`
  - `docs/records/tasks.md`
- 验收标准：
  - 默认启动 `BattleSandbox` 时固定创建 `gojo_vs_sample` 会话，并停在人工选指界面，不再自动推进 demo
  - `demo=<profile>` 仍可触发旧自动回放路径
  - 热座流程固定为 `P1 -> P2 -> run_turn`
  - view model 至少稳定暴露回合/阶段/field、双方 active/bench/全队、当前待选边、待提交指令摘要和最近日志
  - 新增 `manual_battle_scene_suite`，覆盖固定 session 启动、初始快照可渲染、一回合热座、switch、wait/surrender、event_log_cursor 递增和最终 `battle_result`
  - 完整 `tests/run_with_gate.sh` 通过
- 结果：
  - `BattleSandbox` 已切到新的 `BattleSandboxController`，根节点改为调试可玩的 `Control` HUD，默认直接进入固定 `gojo_vs_sample` 手动热座
  - 场景控制器当前公开 `bootstrap_with_config()`、`restart_session_with_config()`、`submit_action()`、`fetch_legal_actions_for_side()`、`build_view_model()`、`get_state_snapshot()`，内部继续维护 `session_id / public_snapshot / event_log_cursor / legal_actions_by_side / pending_commands / current_side_to_select / recent_event_lines`
  - `PlayerSelectionAdapter` 已扩成完整命令输入适配器；`BattleUIViewModelBuilder` 已能把 `public_snapshot + controller context` 变成稳定可渲染结构
  - `BattleSandbox` 现在只有显式传 `demo=<profile>` 时才会走旧自动回放；默认 headless 启动会安静等待玩家输入，不会因为“没人选指”报 `BATTLE_SANDBOX_FAILED`
  - `manual_battle_scene_suite` 已改为直接驱动真实场景控制器，覆盖固定 session 启动、热座回合推进、switch、wait/surrender、event log 游标与结算态
- 验证：
  - `godot --headless --path . --quit-after 2`
  - `godot --headless --path . --quit-after 2 -- demo=legacy`
  - `TEST_PATH=res://test/suites/manual_battle_scene_suite.gd bash tests/run_gdunit.sh`
  - `bash tests/run_with_gate.sh`

## 当前优化：payload validator 分发继续收口（2026-04-11）

- 状态：已完成
- 目标：
  - 继续压缩新增 payload 时的中心改动面，去掉 `ContentPayloadValidator` 里手写 `validator_key -> 校验函数` 分发表，避免 payload 合同已经登记但内容校验分发仍靠另一份中心 `match` 维护。
- 范围：
  - `src/battle_core/content/payload_contract_registry.gd`
  - `src/battle_core/content/content_payload_validator.gd`
  - `tests/gates/architecture_composition_consistency_gate.py`
  - `test/suites/content_validation_core_suite.gd`
  - `test/suites/content_validation_core/payload_dispatch_suite.gd`
  - `docs/records/tasks.md`
  - `docs/records/decisions.md`
- 验收标准：
  - `ContentPayloadValidator` 固定按 `validator_key -> _validate_<validator_key>_payload` 命名约定派发
  - registry 新增 `validator_key` 但 `ContentPayloadValidator` 缺少对应 dispatcher 方法时，architecture gate 直接失败
  - content validation contract 补一条回归，覆盖“已登记 validator_key 都能派发到实现”
  - 完整 `tests/run_with_gate.sh` 通过
- 结果：
  - `PayloadContractRegistry` 已新增 `registered_validator_keys()`，payload validator key 现在可从 registry 单点派生
  - `ContentPayloadValidator` 已改成动态拼接 dispatcher 方法名，不再维护手写 `match` 分发表
  - architecture composition consistency gate 已补 `validator_key <-> _validate_<key>_payload` 一一对应检查
  - content validation core 已新增 `content_payload_validator_registry_dispatch_contract`，覆盖 dispatcher 覆盖率与动态分发主路径
- 验证：
  - `bash tests/check_architecture_constraints.sh`
  - `TEST_PATH=res://test/suites/content_validation_core_suite.gd bash tests/run_gdunit.sh`
  - `bash tests/run_with_gate.sh`

## 当前修补：Kashimo 设计稿角色数量口径纠正（2026-04-11）

- 状态：已完成
- 目标：
  - 修正文档里仍沿用“三人”阶段口径的描述，避免四角色阶段继续误导数值比较与平衡复查。
- 范围：
  - `docs/design/kashimo_hajime_design.md`
  - `docs/records/tasks.md`
- 验收标准：
  - Kashimo 设计稿里涉及角色横向比较的描述统一改成当前四角色口径
  - 仓库一致性检查继续通过
- 结果：
  - `base_hp / base_attack / base_sp_defense / base_speed / regen_per_turn` 的比较描述已统一改成“当前四名正式角色”
  - MP 压力说明也已同步改成当前四角色口径，避免继续混入旧阶段语义
- 验证：
  - `bash tests/check_repo_consistency.sh`

## 当前优化：payload handler script 去掉独立映射表（2026-04-11）

- 状态：已完成
- 目标：
  - 继续压缩 payload 扩展链的中心维护点，去掉 `BattleCorePayloadServiceSpecs` 里独立的 handler script 映射表，避免新增 payload 时还要再补一份 slot -> script 常量。
- 范围：
  - `src/composition/battle_core_payload_service_specs.gd`
  - `tests/gates/architecture_composition_consistency_gate.py`
  - `tests/gates/architecture_wiring_graph_gate.py`
  - `docs/design/effect_engine.md`
  - `docs/design/battle_core_architecture_constraints.md`
  - `docs/records/decisions.md`
  - `docs/records/tasks.md`
- 验收标准：
  - payload handler script 固定按 `handler_slot -> src/battle_core/effects/payload_handlers/<handler_slot>.gd` 命名约定解析
  - `BattleCorePayloadServiceSpecs` 不再维护独立 `HANDLER_SCRIPTS_BY_SLOT`
  - 两个 architecture gate 都能直接拦下“registry 有 slot 但缺 handler 文件”以及“目录里有残留 handler 文件但 registry 没登记”
  - 完整 gate 通过
- 结果：
  - payload handler script 已改为由 composition helper 按 slot 命名约定动态解析，不再手抄 slot -> script 映射表
  - composition consistency gate 与 wiring DAG gate 已从“比对映射表”改成“比对 registry slot 与目录实际 handler 文件”
  - effect engine 与 architecture 约束文档已同步到新的单点维护口径
- 验证：
  - `bash tests/check_architecture_constraints.sh`
  - `bash tests/check_repo_consistency.sh`
  - `bash tests/run_with_gate.sh`

## 当前修补：payload handler 静态 gate 补齐旧映射校验（2026-04-11）

- 状态：已完成
- 目标：
  - 在当时仍保留独立 handler script 映射表的前提下，把 payload handler 扩展链里最后一处静态漏检补上，避免 `handler_slot` 已登记但旧映射漏配时仍能通过 architecture gate。
- 范围：
  - `tests/gates/architecture_composition_consistency_gate.py`
  - `tests/gates/architecture_wiring_graph_gate.py`
  - `docs/design/battle_core_architecture_constraints.md`
  - `docs/records/decisions.md`
- 验收标准：
  - payload registry 新增 `handler_slot` 但没有对应旧 handler script 映射时，两个 architecture gate 都会直接失败
  - 旧的 `HANDLER_SCRIPTS_BY_SLOT` 出现残留映射时，两个 architecture gate 也会直接失败
  - 架构约束文档明确写出这条一一对应要求
  - 完整 gate 通过
- 结果：
  - composition consistency gate 当时已改为显式比对 `handler_slot` 与旧的 `HANDLER_SCRIPTS_BY_SLOT`，不再把 registry slot 直接当成已存在 script
  - wiring DAG gate 也同步补齐了那一版映射漂移校验，避免漏配 handler script 时继续把 wiring 图算成“合法”
  - 架构约束与决策记录已先补齐“payload handler script 漂移必须 fail-fast”的底线；本轮再把旧映射表彻底去掉
- 验证：
  - `bash tests/check_architecture_constraints.sh`
  - `bash tests/run_with_gate.sh`

## 当前优化：shared baseline 入口继续瘦身（2026-04-11）

- 状态：已完成
- 目标：
  - 把 `FormalCharacterBaselines` 里已经稳定的“manifest 读取 + baseline 脚本定位/实例化”职责下沉到独立 helper，避免共享 baseline 入口重新长回体量预警区。
- 范围：
  - `src/shared/formal_character_baselines.gd`
  - `src/shared/formal_character_baselines/formal_character_baseline_loader.gd`
  - 活跃任务/决策记录
- 验收标准：
  - `FormalCharacterBaselines` 对外 facade API 不变
  - manifest 驱动的角色 ID 读取与 baseline fail-fast 路径仍保持原语义
  - `src/shared/formal_character_baselines.gd` 不再落在 architecture warning 区间
  - 完整 gate 通过
- 结果：
  - `FormalCharacterBaselines` 现在只保留 descriptor facade 与错误描述符处理；manifest 读取和 baseline 脚本装载已固定下沉到 `formal_character_baseline_loader.gd`
  - 共享 baseline 的 manifest-order ID、缺脚本、不可实例化与缺 descriptor 路径语义保持不变
  - baseline 主入口已脱离当前 architecture warning 观察名单
- 验证：
  - `bash tests/check_architecture_constraints.sh`
  - `bash tests/check_repo_consistency.sh`
  - `bash tests/run_with_gate.sh`

## 当前修补：formal baseline fail-fast 与 payload 装配文档对齐（2026-04-11）

- 状态：已完成
- 目标：
  - 修掉 formal baseline 在正式 content validation 链路里仍靠 `assert()` 报错的问题，并把 payload 装配接缝的设计文档补到当前实现口径。
- 范围：
  - `FormalCharacterBaselines` 错误路径
  - formal validator shared helper 的错误传播
  - baseline 错误描述符回归
  - architecture 设计文档对齐
- 验收标准：
  - baseline 脚本缺失或 descriptor 漂移时，不再靠 raw `assert()` 中断正式快照校验
  - formal validator helper 能把 baseline 错误转成结构化 validation error
  - `architecture_overview` / `battle_core_architecture_constraints` 明确写出 payload service specs 的当前接缝
  - 完整 gate 通过
- 结果：
  - `FormalCharacterBaselines` 已改为结果式内部解析 + 错误描述符输出；缺 baseline 脚本、manifest 漂移或 descriptor 缺失时会回到 formal validator 的正常错误列表
  - formal validator shared helper 已统一消费 baseline 错误描述符，不再把这类问题降级成缺字段噪音或脚本断言
  - `runtime_registry_suite` 已补 baseline 错误描述符回归，覆盖“缺 baseline 脚本”和“缺 skill descriptor”两条路径
  - architecture 设计文档已补齐 `BattleCorePayloadServiceSpecs` 与 `payload_service_descriptors()` 的当前装配语义
- 验证：
  - `bash tests/run_gdunit.sh`
  - `bash tests/check_architecture_constraints.sh`
  - `bash tests/check_repo_consistency.sh`
  - `bash tests/run_with_gate.sh`

## 当前优化：shared 扩展注册继续收口（2026-04-11）

- 状态：进行中
- 目标：
  - 继续压缩 shared 扩展点的重复维护面，把 `power_bonus_source`、payload 装配链、formal pair 约束和 capability 证据校验都往更稳定的单点收。
- 范围：
  - `power_bonus_source` 真单点化
  - payload handler 扩展链去中心化
  - formal matchup 的测试专用标记
  - pair interaction 约束数据化
  - capability 证据改为结构化语义校验
- 验收标准：
  - 新增 `power_bonus_source` 时，source 列表与内容合同只改 registry，运行时解析只改 resolver
  - payload 扩展链的中心维护点继续减少
  - `obito_mirror` 这类测试专用 matchup 有显式身份
  - pair interaction gate 不再依赖代码里的手写必备案例常量
  - capability gate 不再靠角色内容/文档的纯文本扫描判断共享能力使用证据
- 当前进展：
  - 已完成 `power_bonus_source` 接缝收口：source 列表与 schema 校验固定留在 `power_bonus_source_registry.gd`，runtime 分发固定留在 `PowerBonusResolver`
  - 已完成 payload handler 扩展链第一轮收口：handler 直接依赖 wiring facts 收回 `payload_contract_registry.gd`，`payload_handler_registry.gd` 不再手抄整排 handler 槽位声明
  - 已完成 formal matchup 测试身份显式化：`matchups[*].test_only` 现在是正式元数据，`obito_mirror` 已显式打标，surface smoke 生成与 shared gate 会跳过这类 matchup
  - 已完成 pair interaction 约束数据化：shared gate 现在直接按 manifest 中非 `test_only` 的 directed matchup 推导必备 interaction 覆盖，不再额外维护 Python 常量表
  - 已完成 capability 证据语义化：`coverage_needles` 现在表示 formal 角色内容导出的语义事实 ID，shared gate 不再拼接全文做文本扫描

## 当前修补：审查发现对齐（2026-04-11）

- 状态：已完成
- 目标：
  - 修掉本轮完整审查确认的三处真实问题，避免文档继续落后于运行态合同，也避免 formal delivery suite 派生规则在 gate 和 GDScript 间各维护一份。
- 范围：
  - `BattleState.runtime_fault_*` 运行时模型文档补齐
  - `project_folder_structure` 中 `config/` 与 `src/shared` 职责口径修正
  - repo consistency gate 改为直接读取 GDScript 导出的 delivery 视图，不再在 Python 里重复推导 `required_suite_paths`
- 验收标准：
  - `docs/design/battle_runtime_model.md` 明确写出 runtime fault 字段及其 guard 语义
  - `docs/design/project_folder_structure.md` 能准确反映 formal registry/contracts 的当前落点
  - formal delivery suite 派生规则在仓库里只保留一套正式实现；repo consistency gate 只消费导出的 delivery 视图结果
  - 完整 gate 通过
- 结果：
  - 运行时模型已补齐 `runtime_fault_code / runtime_fault_message`
  - 目录文档已补 `formal_registry_contracts.json`，并把 `src/shared` 改成当前正式治理职责描述
  - repo consistency gate 现在会先导出 delivery 视图，再用导出结果校验 `required_suite_paths / required_test_names / suite reachability`
- 验证：
  - `bash tests/check_repo_consistency.sh`
  - `bash tests/check_architecture_constraints.sh`
  - `bash tests/check_suite_reachability.sh`
  - `bash tests/run_with_gate.sh`

## 当前修补：formal 角色接入面继续去中心化（2026-04-11）

- 状态：已完成
- 目标：
  - 继续压缩新增角色时的重复维护面，避免“manifest 已登记，但还要去改 baseline 总表、capability 消费者清单、共享 suite 回挂”。
- 范围：
  - `FormalCharacterBaselines` 改为 manifest + 命名约定自动发现
  - capability catalog 消费者从 manifest 派生
  - delivery/test 视图自动并入 capability/validator 派生 suite
  - 当前 manifest 冗余共享 suite 回挂清理
- 验收标准：
  - 新增角色时不再需要额外修改 baseline 中心分发表
  - 复用已有共享 capability 时，不再需要再改 capability catalog 的 `consumer_character_ids`
  - validator suite 与 capability suite 不再要求逐角色重复写进 manifest `required_suite_paths`
  - 完整 gate 通过
- 结果：
  - `FormalCharacterBaselines` 已改为从 manifest 读取正式角色 ID，并按目录约定自动加载 baseline 脚本
  - `config/formal_character_capability_catalog.json` 已移除 `consumer_character_ids`；共享入口消费者统一从 manifest `shared_capability_ids` 派生
  - delivery/test 视图已自动并入 capability `required_suite_paths` 与 validator suite，当前 manifest 已删掉一批重复共享 suite 回挂
- 验证：
  - `bash tests/check_repo_consistency.sh`
  - `bash tests/check_architecture_constraints.sh`
  - `bash tests/run_with_gate.sh`

## 当前修补：边界 fail-fast 与扩角治理补强（2026-04-11）

- 状态：已完成
- 目标：
  - 修掉项目全景审查里确认的剩余边界问题，避免公共输入坏类型或坏 setup 继续漏到更深层才失败。
  - 再补一层扩角治理约束，防止 `pair interaction` case 被重名遮蔽，或新增 `power_bonus_source` 时只改注册表不改 resolver。
- 范围：
  - `BattleInputContractHelper` 的错误类型保护
  - `SampleBattleFactory.content_snapshot_paths_for_setup_result()` 的 setup-scoped 失败语义
  - `formal pair interaction` 的 `test_name` 唯一性校验
  - `power bonus` 注册表与 resolver 覆盖回归
  - README 代码规模统计与活跃任务记录
- 验收标准：
  - manager/replay 对坏输入继续返回结构化错误，不再因为错误类型触发脚本错误
  - setup-scoped content snapshot 对坏 `battle_setup` 直接结果式失败，不再静默回退 baseline 路径
  - pair interaction case 若出现重复 `test_name`，suite 与 repo consistency gate 至少有一层会直接拦下
  - 新增 `power_bonus_source` 若没补 resolver 覆盖，会被测试直接拦下
  - 完整 gate 通过并保持工作区干净
- 结果：
  - `BattleInputContractHelper` 现在会先拦非 `Object/Dictionary` 输入，坏类型不再直接触发属性访问脚本错误
  - `SampleBattleFactory.content_snapshot_paths_for_setup_result()` 已统一复用 battle_setup 合同校验，并对缺失 `unit_definition_ids` 的 side 直接返回错误
  - formal pair interaction 现在会校验 `test_name` 非空且唯一；repo consistency gate 也同步补了重复名检查
  - `PowerBonusResolver` 已新增注册表覆盖回归，后续新增 source 若未补 resolver，会被 suite 直接拦下
- 验证：
  - `bash tests/run_gdunit.sh`
  - `bash tests/check_repo_consistency.sh`
  - `bash tests/run_with_gate.sh`

## 当前修补：输入合同收口与 power bonus 层级纠偏（2026-04-11）

- 状态：已完成
- 目标：
  - 修掉项目全景审查里确认的剩余问题：共享输入合同重复维护、`power bonus` runtime 逻辑越层，以及 README/审计文档口径超前于当前实现。
- 范围：
  - `battle_setup / replay_input / content_snapshot_paths / command_stream` 的共享输入合同
  - `PowerBonusSourceRegistry / PowerBonusResolver` 的职责边界
  - README、设计文档、审计记录与活跃决策/任务记录
- 验收标准：
  - side_id 与 replay 输入形状校验不再分别散落在 manager/replay/sandbox/setup 多处手写循环里
  - `content` 层不再直接承担 power bonus 的运行态求值
  - 文档不再把 `SampleBattleFactory`、manifest 单真相与 power bonus 注册表的现状写得比实现更绝对
  - 完整 gate 通过并保持工作区干净
- 结果：
  - 已新增 `src/battle_core/contracts/battle_input_contract_helper.gd`，并由 manager/replay/sandbox/setup 统一复用
  - `PowerBonusSourceRegistry` 已回退为 source 列表与内容侧合同 owner；运行时求值已回到 `PowerBonusResolver`
  - README、设计文档、审计记录、决策记录已同步到当前实现口径
- 验证：
  - `bash tests/check_architecture_constraints.sh`
  - `bash tests/check_repo_consistency.sh`
  - `bash tests/check_suite_reachability.sh`
  - `bash tests/run_with_gate.sh`

## 当前修补：pair interaction 合同与 power bonus 真收边（2026-04-11）

- 状态：已完成
- 目标：
  - 把最近这轮管理修复里还剩的三处真实漂移收平：pair interaction 派生合同、`power bonus` 的分层边界、活跃说明文档口径。
- 范围：
  - `SampleBattleFactoryFormalMatchupCatalogLoader`
  - `PowerBonusSourceRegistry / PowerBonusResolver`
  - formal registry/catalog 回归坏例
  - tests README、设计文档、活跃复查记录、任务/决策记录
- 验收标准：
  - 派生后的 directed interaction case 在运行时 loader 与 shared gate 都按 matchup opener 方向校验
  - 派生后的 directed interaction case 在运行时 loader 与 shared gate 都禁止引用 `test_only` matchup
  - `content` 层不再直接承担 power bonus 的运行时求值
  - capability 证据说明统一改成“从 `required_content_paths` 导出的语义事实”
  - 完整 gate 通过
- 结果：
  - formal matchup catalog loader 已从“无序配对一致”改成“必须匹配 matchup opener 方向”，并直接拒绝 `test_only` matchup
  - formal registry/catalog suite 已补反向 `character_ids` 与引用 `test_only` matchup 的 fail-fast 坏例
  - `PowerBonusResolver` 已重新承接 `mp_diff_clamped / effect_stack_sum` 的 runtime 求值与覆盖检查；`PowerBonusSourceRegistry` 只保留 source 常量、source 列表与内容合同校验
  - tests README、设计文档、复查记录、任务/决策记录已统一到当前语义事实与分层边界口径
- 验证：
  - `bash tests/check_repo_consistency.sh`
  - `bash tests/run_with_gate.sh`

## 当前复查：项目实现全景审查（2026-04-10）

- 状态：已完成
- 目标：
  - 复查当前主线的架构实现、设计文档对齐、四角色交付链和最近几次管理修复方向，并核验外部 Claude 审查结论里哪些还能成立。
- 范围：
  - `docs/design/` 与核心实现抽查
  - 最近提交 `14580aa / 445bdb5 / 9d1bd03 / ac3383e / d9cc721 / 0e7c60e / 7f501bd / fff2e62`
  - 四角色 formal 角色合同、validator、suite、shared capability catalog 与 gate 状态
  - 外部 Claude 审查里关于 `assert()`、architecture gate、manifest/交付清单口径的结论
- 验收标准：
  - 给出当前主线是否存在阻断或重要实现问题的明确结论
  - 明确判断最近管理修复方向是否继续成立
  - 至少完成一次完整 gate 验证
- 结果：
  - 当前未发现阻断或重要实现问题
  - 最近这轮管理修复方向成立，且已真实落到代码、gate 和文档
  - 外部 Claude 审查中关于 `assert()` 违规、architecture gate 未执行、manifest 合同口径的结论已不适合作为现行依据
- 记录：
  - 详细结论见 `docs/records/review_2026-04-10_current_project_full_check.md`
- 验证：
  - `bash tests/check_suite_reachability.sh`
  - `bash tests/check_architecture_constraints.sh`
  - `bash tests/check_repo_consistency.sh`
  - `bash tests/run_with_gate.sh`

## 当前修补：battle_setup side_id 输入校验（2026-04-10）

- 状态：已完成
- 目标：
  - 把 `battle_setup.sides[*].side_id` 的非空和唯一性校验补回公开入口、初始化校验和回放入口，避免坏输入漏到运行态 `assert()` 或公开快照。
- 范围：
  - `BattleCoreManager` 的 create/replay 入参校验
  - `BattleSetupValidator` 的运行前校验
  - manager/setup 相关回归测试
  - 设计文档与活跃任务记录对齐
- 验收标准：
  - 空 side_id 和重复 side_id 在 `create_session / run_replay / validate_setup` 上都会 fail-fast
  - 不再出现“公开返回成功但内部打印 assertion”的路径
  - 相关测试与完整 gate 通过
- 结果：
  - `battle_setup.side_id` 现在会在 facade 入口和 setup validator 上同时校验
  - manager create/replay 与 setup 校验已补回归
  - 设计文档和任务记录已同步到当前口径
- 验证：
  - `bash tests/run_gdunit.sh`
  - `bash tests/run_with_gate.sh`

## 临时复查：最近提交与扩展治理方向审查（2026-04-10）

- 状态：已完成
- 目标：
  - 复查最近几次围绕 formal 角色交付链、shared capability catalog、wiring specs、manifest helper 与共享注册表的修补，确认架构、实现和设计文档是否仍然对齐，并判断修复方向是否正确。
- 范围：
  - 审查最近提交 `f077b8b / d9cc721 / 0e7c60e / 49109b1 / e7a336b / 7f501bd`
  - 核对 `docs/design/`、核心实现、formal 角色交付链与 gate/test 状态
- 验收标准：
  - 给出明确结论：是否存在阻断问题，当前修复方向是否继续成立
  - 至少完成一次静态 gate 与一次全量回归验证
- 结果：
  - 本轮未发现新的阻断或重要实现问题
  - 共享治理修复方向成立，且已真实落到代码与 gate
  - 遗留风险主要仍在“新增机制还需要改几个中心文件”，不是 battle core 主循环或四角色语义失控
- 记录：
  - 详细复查结论见 `docs/records/review_2026-04-10_recent_management_fix_direction_audit.md`
- 验证：
  - `bash tests/check_architecture_constraints.sh`
  - `bash tests/check_repo_consistency.sh`
  - `bash tests/check_suite_reachability.sh`
  - `bash tests/run_with_gate.sh`

## 当前波次：formal contract 扩角前硬收口（2026-04-10）

- 状态：已完成
- 目标：
  - 一次性切掉 formal baseline、角色接入链和接线层继续膨胀的根因，不改 battle core 主回合语义，不改四正式角色玩法与数值。
- 范围：
  - 第 1 阶段：formal baseline 与角色 ID 收口
  - 第 2 阶段：manifest + shared capability catalog 模板化
  - 第 3 阶段：composition / wiring specs 按子域拆分
  - 第 4 阶段：文档、gate、记录与最终验收对齐
- 非范围：
  - 不新增第 5 个正式角色
  - 不给旧短别名、旧分发路径、旧接口补兼容
  - 不改 battle core 对外 contract 与四角色主玩法语义
- 当前进度：
  - 第 1 阶段已完成：
    - `FormalCharacterBaselines` 已删掉 `gojo / kashimo / obito` 短别名分发，中心分发表只认 manifest 正式 ID：`gojo_satoru / sukuna / kashimo_hajime / obito_juubi_jinchuriki`
    - 四角色 baseline 已按“主 facade / effect contracts / ultimate-domain contracts”重切；角色主入口当前只保留 `unit / passive / regular skill / ultimate / field` 稳定 facade
    - Gojo / Kashimo / Obito 的 baseline label、snapshot label、formal validator、snapshot suite 与专项坏例回归已统一改到正式 ID
    - `tests/check_architecture_constraints.sh` 已把 `src/shared/formal_character_baselines/**` 与 `src/shared/formal_character_baselines.gd` 纳入大文件强校验
    - formal registry 专项回归已补 `formal_character_baseline_manifest_id_contract`
    - repo consistency gate 已新增：
      - baseline 分发表 key 必须与 manifest `characters[*].character_id` 顺序一致
      - baseline / validator / snapshot suite / support / gate 中不允许残留旧短别名 `gojo / kashimo / obito`
  - 第 2 阶段已完成：
    - `config/formal_character_manifest.json.characters[*]` 的 delivery/test 视图已新增 `shared_capability_ids`
    - `config/formal_character_capability_catalog.json` 已成为共享能力目录单真相；当前每个 entry 固定登记 `capability_id / rule_doc_paths / required_suite_paths / coverage_needles / stop_and_specialize_when`
    - `src/shared/formal_character_capability_catalog.gd`、formal registry contract、fixture builder 与 capability catalog suite 已落地，formal delivery 模板开始围绕 manifest + capability catalog 收口
    - repo consistency gate 已新增共享能力硬约束：
      - `shared_capability_ids` 只能引用 capability catalog 已登记入口
      - catalog 实际消费者统一从 manifest `shared_capability_ids` 派生
      - catalog `required_suite_paths` 统一由 delivery/test 视图自动并入，不再要求角色条目重复回挂
      - 角色内容 / validator / 设计稿 / 调整记录 / wrapper 必须能扫到实际消费证据
    - `README.md`、`tests/README.md`、`docs/design/formal_character_delivery_checklist.md`、`docs/design/formal_character_design_template.md`、`docs/design/battle_content_schema.md`、`docs/design/project_folder_structure.md` 已同步 capability catalog 与 `shared_capability_ids` 口径
    - 已补 `docs/design/formal_character_capability_catalog.md`，把共享能力目录职责、字段、接入顺序与 gate 硬约束收成单文档
  - 第 3 阶段已完成：
    - `src/composition/battle_core_wiring_specs.gd` 已收成聚合入口，真实 wiring spec 拆到 `src/composition/battle_core_wiring_specs/*.gd`
    - wiring spec 当前固定按子域拆分为 `commands / turn / lifecycle / passives / effects_core / payload_handlers / actions`
    - `BattleCoreComposer` 仍只走统一聚合入口装配，但 wiring / reset spec 已改为通过 `BattleCoreWiringSpecs.wiring_specs() / reset_specs()` 统一派发
    - composition consistency gate 与 wiring DAG gate 已改为直接扫描 split wiring 目录，继续锁 `SERVICE_DESCRIPTORS / container API / wiring specs / strict DAG` 一致性
    - `docs/design/project_folder_structure.md` 与 `README.md` 已同步新增 wiring specs 聚合目录与最新代码规模统计
  - 第 4 阶段已完成：
    - `docs/design/architecture_overview.md` 与 `docs/design/battle_core_architecture_constraints.md` 已同步 wiring specs 聚合目录与 `BattleCoreWiringSpecs.wiring_specs() / reset_specs()` 入口
    - `docs/records/tasks.md`、`docs/records/decisions.md` 已补齐四个阶段的目标落点、架构决定与验证结果
    - 已完成最终全量检查：当前未再发现新的 gate 漂移、回归失败、装配断裂或 README/设计文档偏差
  - 后续对齐修补已完成：
    - `pair_interaction_case` 共享合同已补 `battle_seed` 正整数约束，不再只靠 catalog loader / shared gate 各自补校验
    - `docs/records/review_2026-04-10_four_character_architecture_audit.md` 已显式标记为历史审查，不再作为现行依据
    - `FormalCharacterManifest` 已拆成 facade + `formal_character_manifest_loader/views` helper，并把入口文件与 helper 目录一起纳入 architecture size gate
    - payload script / handler slot / validator key 已收口到 `src/battle_core/content/payload_contract_registry.gd`；payload validator、handler registry、effects wiring 与 payload contract suite 统一从注册表派生
    - `power_bonus_source` 的 source 列表与 schema 校验已收口到 `src/battle_core/content/power_bonus_source_registry.gd`；运行时解析当前由 `src/battle_core/actions/power_bonus_resolver.gd` 负责
    - `docs/records/review_2026-04-10_post_refactor_alignment_audit.md` 已显式标记为历史审查，并新增修补后复查记录 `docs/records/review_2026-04-10_fix_followup_audit.md`
- 第 1 阶段验收结果：
  - 仓库中已不存在旧短别名 baseline 分发路径
  - 四角色 snapshot / validator / runtime 全量回归通过
  - baseline 目录已进入 architecture size gate
- 第 1 阶段验证：
  - `bash tests/check_architecture_constraints.sh`
  - `bash tests/check_repo_consistency.sh`
  - `bash tests/check_suite_reachability.sh`
  - `bash tests/run_gdunit.sh`
- 第 2 阶段验收结果：
  - manifest + capability catalog 已成为角色接入模板骨架，已明显减少额外中心补丁点
  - 新共享入口未登记、已登记但 suite/消费者/证据未对齐时，会被 repo consistency gate 直接拦下
  - 文档、README 与 tests README 已和 capability catalog 口径对齐
- 第 2 阶段验证：
  - `bash tests/check_architecture_constraints.sh`
  - `bash tests/check_repo_consistency.sh`
  - `bash tests/check_suite_reachability.sh`
  - `bash tests/run_gdunit.sh`
  - `git diff --check`
- 第 3 阶段验收结果：
  - wiring spec 不再继续堆在单文件里，接线层热点已按子域拆开
  - composer 装配结果不变，runtime wiring 图仍保持 strict DAG
  - battle core 主回合语义与四角色回归未受影响
- 第 3 阶段验证：
  - `bash tests/check_architecture_constraints.sh`
  - `bash tests/check_suite_reachability.sh`
  - `bash tests/run_gdunit.sh`
  - `git diff --check`
- 第 4 阶段验收结果：
  - architecture / delivery / capability catalog / composition 相关设计文档、记录与 gate 已对齐
  - 最终全量 gate、全量测试与差异检查全部通过
  - 对当前项目实现做完一轮最终检查后，未发现新的潜在阻断问题
- 第 4 阶段验证：
  - `bash tests/run_with_gate.sh`
  - `git diff --check`

## 当前波次：正式角色整合修复波次（2026-04-07）

- 状态：已完成
- 目标：
  - 在不扩第 5 个正式角色、不改四角色数值平衡的前提下，把 formal 合同源、sample/demo 基线、pair interaction 覆盖、manager 黑盒与测试 support/gate 重新收成一套稳定底座。
- 范围：
  - formal 角色元数据收口到 manifest 单真源与共享合同源
  - `SampleBattleFactory` baseline / formal flow 解耦
  - `docs/records` 从机器约束里降级为记录与归档索引
  - pair interaction 改为“每对可多 case + 当前 6 组关键 pair 双向覆盖”
  - Kashimo / Sukuna manager 黑盒补洞
  - support / gate 热点拆分并补结构性回归
- 非范围：
  - 不新增正式角色
  - 不改四角色技能数值与平衡
  - 不扩更多 demo 命令类型

## 当前波次：扩角前整合规范（2026-04-07）

- 状态：已完成
- 目标：
  - 在不新增第 5 个正式角色、不改四角色数值与平衡的前提下，把扩角前最容易持续返工的九个热点先收口：
    - manifest runtime / delivery 视图解耦
    - 角色事实重复维护面收缩
    - `SampleBattleFactory` 家族继续按职责拆分
    - `LegalActionService` 提前拆成稳定子职责
    - `BattleResultService` 收口成稳定终局 facade + 内部协作者
    - `BattleCoreManager` 收口成更薄的稳定 facade + session 内部协作者
    - formal shared contract helper 按资源族拆分
    - formal snapshot support helper 收口成薄 facade + descriptor helper
    - formal repo consistency gate 拆回主入口 + 子校验模块
- 范围：
  - 第 1 批：runtime loader 不再依赖 delivery/test 字段；manifest/runtime/delivery 合同、gate 与文档同步
  - 第 2 批：收缩 validator / snapshot 等角色事实重复维护面
  - 第 3 批：拆分 `SampleBattleFactory` 热点职责
  - 第 4 批：拆分 `LegalActionService` 热点职责
  - 第 5 批：拆分 `BattleResultService` 的终局 chain 与 outcome 判定职责
  - 第 6 批：拆分 `BattleCoreManager` 的 session 级 facade 调度职责
  - 第 7 批：拆分 `ContentSnapshotFormalCharacterContractHelper` 的资源族共享断言职责
  - 第 8 批：拆分 `FormalCharacterSnapshotTestHelper` 的 descriptor 构造职责
  - 第 9 批：拆分 `repo_consistency_formal_character_gate.py` 的 cutover / character-entry 校验职责
- 当前进度：
  - 第 1 批已完成：manifest runtime / delivery 视图解耦已落地并通过 gate
  - 第 2 批已完成：formal 角色 baseline 已收口到共享描述层，snapshot suite 与 formal validator 的基础事实开始共用同一份 descriptor
  - 第 3 批已完成：`SampleBattleFactory` owner 已拆出 `override router + setup access`，并把 snapshot 目录扫描下沉到独立 helper；path override 广播、baseline/formal setup 组装与 snapshot 扫描不再继续堆在主入口
  - 第 4 批已完成：`LegalActionService` owner 已拆出 `rule gate + cast option collector + switch option collector`，规则门、技能/奥义候选收集与换人候选收集不再继续缠在主入口
  - 追加整合批已完成：`BattleResultService` owner 已拆出 `battle_result_service_chain_builder.gd + battle_result_service_outcome_resolver.gd`；system/battle_end chain 构建与 victory/surrender/turn limit 判定不再继续和 invalid/runtime fault 落盘缠在一个入口文件里
  - 第 6 批已完成：`BattleCoreManager` owner 已拆出 `battle_core_manager_session_service.gd`；create/read/turn/close 的 session 级 facade 调度不再继续和 dependency guard、端口同步、`build_command/run_replay` 混排在同一个 owner 文件里
  - 第 7 批已完成：`ContentSnapshotFormalCharacterContractHelper` owner 已拆出 `content_snapshot_formal_character_unit_skill_contract_helper.gd + content_snapshot_formal_character_effect_field_contract_helper.gd`；`unit/skill/passive_skill` 与 `effect/field/payload shape` 的共享断言不再继续堆在一个 shared helper 文件里
  - 第 8 批已完成：`FormalCharacterSnapshotTestHelper` owner 已拆出 `formal_character_snapshot_descriptor_helper.gd`；字段顺序、descriptor 检查构造与 actual/expected 归一化不再继续和 content index 装配、断言执行混排在一个 support helper 里
  - 第 9 批已完成：`repo_consistency_formal_character_gate.py` 已拆出 `repo_consistency_formal_character_gate_cutover.py + repo_consistency_formal_character_gate_characters.py`；manifest cutover 校验与 character entry 校验不再继续堆在同一个 gate 主入口文件里
- 非范围：
  - 不改四角色玩法语义
  - 不新增正式角色
  - 不改 battle core 主循环规则

### 继续整合：Turn 热点瘦身

- `BattleResultService` 当前固定采用：
  - owner：`src/battle_core/turn/battle_result_service.gd`
  - chain helper：`src/battle_core/turn/battle_result_service_chain_builder.gd`
  - outcome helper：`src/battle_core/turn/battle_result_service_outcome_resolver.gd`
- 本批保持对外方法名与主循环语义不变：
  - `build_system_chain()`
  - `resolve_initialization_victory()`
  - `resolve_standard_victory()`
  - `resolve_surrender()`
  - `resolve_turn_limit()`
  - `terminate_invalid_battle() / hard_terminate_invalid_state()`
- 当前切分边界：
  - owner 只保留 invalid termination/runtime fault 落盘、稳定 facade 与 helper 装配
  - chain helper 只负责 `system` / `battle_end` chain 构造与 action-origin 终局链复用
  - outcome helper 只负责初始化胜利、标准胜利、投降、turn limit 的 battle result 写入与 battle end 日志

### 继续整合：Facade 热点瘦身

- `BattleCoreManager` 当前固定采用：
  - owner：`src/battle_core/facades/battle_core_manager.gd`
  - contract helper：`src/battle_core/facades/battle_core_manager_contract_helper.gd`
  - container helper：`src/battle_core/facades/battle_core_manager_container_service.gd`
  - session helper：`src/battle_core/facades/battle_core_manager_session_service.gd`
- 本批保持唯一稳定 facade 语义不变：
  - `create_session()`
  - `get_legal_actions()`
  - `build_command()`
  - `run_turn()`
  - `get_public_snapshot()`
  - `get_event_log_snapshot()`
  - `close_session()`
  - `run_replay()`
- 当前切分边界：
  - owner 只保留依赖守卫、`build_command/run_replay`、session 计数、端口同步与 dispose
  - container helper 继续只负责 session 建立与 replay 容器编排
  - session helper 只负责 create/read/turn/close 的 session 级 facade 调度与公开快照/事件日志回包

### 继续整合：Formal Shared Helper 瘦身

- `ContentSnapshotFormalCharacterContractHelper` 当前固定采用：
  - owner：`src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_contract_helper.gd`
  - unit/skill/passive helper：`src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_unit_skill_contract_helper.gd`
  - effect/field helper：`src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_effect_field_contract_helper.gd`
- 本批保持角色级 validator 调用口不变：
  - `validate_unit_contract()`
  - `validate_unit_contract_descriptor()`
  - `validate_skill_contracts()`
  - `validate_effect_contracts()`
  - `validate_field_contracts()`
  - `validate_passive_skill_contracts()`
  - `expect_single_payload_shape()`
- 当前切分边界：
  - owner 只保留稳定 facade 与资源族协作者转发
  - unit/skill/passive helper 只负责单位、技能、被动技能的共享断言
  - effect/field helper 只负责效果、领域与 payload shape 的共享断言

### 继续整合：Snapshot Support 瘦身

- `FormalCharacterSnapshotTestHelper` 当前固定采用：
  - owner：`tests/support/formal_character_snapshot_test_helper.gd`
  - descriptor helper：`tests/support/formal_character_snapshot_descriptor_helper.gd`
- 本批保持 snapshot suite 调用口不变：
  - `build_content_index()`
  - `build_content_index_for_setup()`
  - `append_*_checks()`
  - `run_checks()`
  - `run_descriptor_checks()`
  - `build_descriptor_checks()`
- 当前切分边界：
  - owner 只保留 content index 装配、断言执行与 facade 转发
  - descriptor helper 只负责字段顺序、descriptor 检查构造与 actual/expected 归一化

### 继续整合：Formal Gate 瘦身

- formal repo consistency gate 当前固定采用：
  - owner：`tests/gates/repo_consistency_formal_character_gate.py`
  - cutover helper：`tests/gates/repo_consistency_formal_character_gate_cutover.py`
  - character helper：`tests/gates/repo_consistency_formal_character_gate_characters.py`
  - pair helper：`tests/gates/repo_consistency_formal_character_gate_pairs.py`
- 本批保持入口脚本与输出语义不变：
  - `tests/check_repo_consistency.sh` 仍直接执行 `tests/gates/repo_consistency_formal_character_gate.py`
  - gate 完成语句仍保持 `formal character manifest, pair coverage, and anti-regression guards are aligned`
- 当前切分边界：
  - owner 只保留合同装载、主线串联与收尾
  - cutover helper 只负责 manifest cutover、legacy 路径回归与 formal setup 入口校验
  - character helper 只负责 formal character entry、suite reachability 与 regression anchor 校验

## 本轮交付结果

### Formal / Sample 收口

- formal registry 字段真相已统一到共享合同文件：
  - `config/formal_registry_contracts.json`
  - `src/shared/formal_registry_contracts.gd`
- `SampleBattleFactory` 当前固定采用：
  - baseline catalog：`config/sample_matchup_catalog.json`
  - baseline loader：`src/composition/sample_battle_factory_baseline_matchup_catalog.gd`
  - manifest runtime-view loader：`src/composition/sample_battle_factory_runtime_registry_loader.gd`
  - manifest delivery-view loader：`src/composition/sample_battle_factory_delivery_registry_loader.gd`
- `build_setup_by_matchup_id_result()` 现行为 baseline 优先、formal fallback。
- `build_sample_setup_result()`、legacy demo、passive item demo 已不再依赖 formal manifest 健康度。
- demo 默认 profile 已固定收口为 `kashimo`，并由 `config/demo_replay_catalog.json` 提供单一真相。

### Pair / Gate 重做

- `config/formal_character_manifest.json` 当前把 pair 身份与 pair interaction 输入都收回到角色条目：`pair_token / baseline_script_path / owned_pair_interaction_specs`。
- 当前四正式角色已按 manifest 顺序补齐完整 pair coverage；`pair_token = gojo / sukuna / kashimo / obito`，继续保持既有 12 条 directional interaction case 的外部命名稳定。
- repo consistency gate 当前固定检查：
  - `pair_token` 唯一
  - `baseline_script_path` 显式存在
  - `owned_pair_interaction_specs` 只允许后出现角色声明与更早角色的 pair
  - 每条 owned spec 恰好派生 2 条 directed case
- `docs/records/tasks.md` / `docs/records/decisions.md` 的措辞漂移不再触发机器 gate 失败。

### 黑盒 / Support 拆分

- Kashimo manager 黑盒已补：
  - `feedback_strike`
  - `kyokyo`
- Sukuna manager 黑盒已补：
  - `hatsu`
  - `teach_love`
- support 热点已拆分：
  - `battle_core_test_harness` -> facade + pool/sample helper
  - `combat_type_test_helper` -> facade + cases
  - `damage_payload_contract_test_helper` -> facade + cases
  - `obito_runtime_contract_support` -> facade + heal_block / yinyang helper

## 当前波次：正式角色稳定化三波整合（2026-04-07）

- 状态：已完成
- 目标：
  - 在不新增第 5 个正式角色、不改四角色数值平衡的前提下，把 formal manifest 单真源、pair 回归矩阵、sandbox/demo 真相、content snapshot cache freshness，以及活跃记录可信度一次收口。
- 范围：
  - Wave 1：manifest 单真源、sandbox demo catalog 化、cache freshness 扩大到 manifest 与 content/formal validator 脚本
  - Wave 2：删除手写 `pair_surface_cases`，改为 `matchups + surface_smoke_skill_id` 自动生成 directed surface smoke；interaction 保持显式场景制
  - Wave 3：补齐 Gojo / Sukuna / Kashimo / Obito 的 manager/runtime 黑盒缺口，并同步 README、tests README、design docs 与 records
- 非范围：
  - 不新增正式角色
  - 不改既有技能数值
  - 不新增 battle 规则接口或玩法机制

## 本轮交付结果

### Wave 1：硬问题收口与开发边界清理

- `config/formal_character_manifest.json` 已成为 formal 角色元数据的唯一人工维护真源；顶层固定只保留 `characters / matchups`，角色级 pair 输入统一走 `owned_pair_interaction_specs`。
- interaction catalog 当前对 `scenario_key / matchup_id / character_ids[2] / battle_seed` 走硬校验；缺字段、空值、类型错误或 `battle_seed <= 0` 直接 fail-fast。
- `BattleSandboxController` 不再写死角色专属 demo 命令流；demo profile 的单一真相固定为 `config/demo_replay_catalog.json`。
- `SampleBattleFactory` 负责根据 demo profile 构建 replay input；demo profile 缺失、非法或 builder 失败时直接失败。
- `ContentSnapshotCache` 的签名输入已扩大到：
  - snapshot 路径列表
  - 顶层资源递归外部 `.tres/.res` 依赖
  - `config/formal_character_manifest.json`
  - `src/battle_core/content/**/*.gd`
  - `src/battle_core/content/formal_validators/**/*.gd`

### Wave 2：pair surface 自动生成与回归矩阵重构

- `config/formal_character_manifest.json` 已补 `surface_smoke_skill_id` 必填字段。
- `config/formal_character_manifest.json` 已移除手写 `pair_surface_cases`，当前只保留：
  - `characters`
  - `matchups`
- `SampleBattleFactory.formal_pair_surface_cases_result()` 当前只返回运行时生成结果，不再读取手写 surface case。
- surface gate 当前固定验证：
  - formal roster 的 directed pair surface coverage 完整
  - 缺 `surface_smoke_skill_id` 或缺合法 directed matchup 时直接 fail-fast
- interaction gate 当前固定验证：
  - 6 组 unordered pair 覆盖完整
  - `scenario_registry` 与 catalog `scenario_key` 一一对应

### Wave 3：四角色黑盒补洞与记录可信度修复

- Gojo：已补 `苍 / 赫 / 茈` 双标记爆发链的 manager 黑盒路径。
- Sukuna：已补 `灶` 的离场结算 manager 黑盒路径。
- Kashimo：已补 `水中外泄` 的 manager 黑盒路径。
- Obito：已补 `六道十字奉火` 的真实 runtime/manager 回归，以及 `阴阳遁` 的 manager 黑盒路径。
- Kashimo / Obito 当前已把 `弥虚葛笼` 领域命中还原、`阴阳遁` 起手生效这类主玩法锚点收回 manager/pair 黑盒主链；runtime suite 只继续保留 probe 型边界断言。
- README / tests README / design docs 已同步：
  - `surface_smoke_skill_id`
  - pair surface 自动生成
  - interaction `battle_seed` 必填
  - demo replay catalog 化
  - cache freshness 语义扩展
- 旧审查记录中仍引用单表 formal registry 的文件已显式标记为历史审查，不再作为现行依据。

## 当前验证基线

- 已通过：
  - `bash tests/run_gdunit.sh`
  - `tests/run_with_gate.sh`
- 本轮完成标准：
  - `tests/run_with_gate.sh`
  - `godot --headless --path . --quit-after 20`
  - formal 四角色 manager smoke、pair smoke、pair interaction 全绿
  - repo consistency gate 与文档口径一致

## 下一步是否扩第 5 个角色的判断线

只有在以下条件继续保持成立时，才建议进入新角色扩充：

- formal manifest 的 `characters / matchups + characters[*].owned_pair_interaction_specs` 与 gate 保持一致，不再回退成多真源手抄或兼容口径
- pair surface 继续由 `matchups + surface_smoke_skill_id` 自动生成，不再恢复手写 surface matrix
- interaction 继续保持显式场景制，且每个 case 都显式带 `battle_seed`
- sandbox/demo 继续只改 `config/demo_replay_catalog.json`，不再把角色专属脚本塞回 `BattleSandboxController`
- content schema、formal validator、manifest 任一变化后，cache freshness 仍会触发 miss
- 新角色接入继续按 `设计稿 + 调整记录 + 内容资源 + SampleFactory 接线 + 角色 suite` 的完整交付面推进

## 最小可玩性检查

- 可启动：`godot --headless --path . --quit-after 20`
- 可操作：sandbox 默认 `manual/policy` 能启动、可操作、可跑完整局，并输出统一摘要
- 无致命错误：不得出现 `BATTLE_SANDBOX_FAILED:`、`SCRIPT ERROR:`、`Compile Error:`、`Parse Error:`

## 当前任务：payload / power bonus seam 再收口（2026-04-11）

|字段|说明|
|---|---|
|目标|继续降低新增复杂机制时的中心改动面，把 `payload` 相关 service 注册从 `BattleCoreServiceSpecs` 手抄列表里移走，并把 `power_bonus_source` 改成 descriptor 驱动|
|范围|1. 新增 `src/composition/battle_core_payload_service_specs.gd`，集中维护 payload shared service descriptor 与 shared wiring<br>2. `BattleCoreServiceSpecs` 改成基础服务 + payload 派生服务<br>3. `battle_core_wiring_specs_payload_handlers.gd` 改为复用新的 payload service specs helper<br>4. `PowerBonusSourceRegistry` 改为 source descriptor，`PowerBonusResolver` 按 resolver kind 分发<br>5. 同步 architecture gate 识别新的 payload service / wiring 派生入口|
|验收标准|1. `content/payload_contract_registry.gd` 不再反向 import `effects/*`<br>2. payload 相关 service slot 仍能被 composer 正常实例化并通过 wiring gate<br>3. `power_bonus_registered_source_coverage_contract` 继续通过<br>4. 完整 `tests/run_with_gate.sh` 通过|

### 本轮结果

- `src/composition/battle_core_payload_service_specs.gd` 已成为 payload shared service descriptor 与 shared wiring 的唯一 composition 入口。
- `src/battle_core/content/payload_contract_registry.gd` 已回到纯 payload 合同事实，只保留 `payload -> handler slot -> validator key -> handler deps`。
- `src/composition/battle_core_service_specs.gd` 当前固定采用“基础服务常量表 + `payload_service_descriptors()` 派生服务表”。
- `src/battle_core/content/power_bonus_source_registry.gd` 已把 source 真相收成 descriptor；`src/battle_core/actions/power_bonus_resolver.gd` 当前按 resolver kind 分发，不再硬编码 source 名单。
- architecture gate 已同步识别新的 payload service helper，不再把 payload 相关 service slot 误判为未知节点。

### 验证

- `bash tests/check_architecture_constraints.sh`
- `TEST_PATH=res://test/suites/power_bonus_runtime_suite.gd bash tests/run_gdunit.sh`
- `TEST_PATH=res://test/suites/payload_execution_contract_suite.gd bash tests/run_gdunit.sh`
- `bash tests/run_with_gate.sh`

## 当前任务：拆分 composition consistency gate 热点（2026-04-12）

|字段|说明|
|---|---|
|目标|把 `tests/gates/architecture_composition_consistency_gate.py` 从接近阈值的单热点拆成主入口 + helper，保持校验语义不变|
|范围|1. 新增 gate support / checks helper，承接文本装载、descriptor facts 构建与校验细节<br>2. 主入口脚本只保留异常投影与完成输出<br>3. 补任务记录与治理决策记录|
|验收标准|1. composition consistency gate 输出语义保持不变<br>2. 新增 helper 后每个 gate 文件都低于 tests/gates 的 350 行预警线<br>3. `bash tests/check_architecture_constraints.sh` 与 `bash tests/run_with_gate.sh` 通过|

### 本轮结果

- `tests/gates/architecture_composition_consistency_gate.py` 已收回到纯入口文件，只保留 `run()` 调度、失败输出与通过输出。
- `tests/gates/architecture_composition_consistency_gate_support.py` 现负责路径常量、文本装载、payload seam 解析与 descriptor facts 构建。
- `tests/gates/architecture_composition_consistency_gate_checks.py` 现负责 wiring/spec entry point、service descriptor、payload seam、container API、composer API 与 container usage 校验。
- 原先 364 行的单文件 gate 已拆成 `17 + 194 + 204` 行，后续继续扩 composition 校验时，不必再把新规则堆回一个中心脚本。

### 验证

- `python3 tests/gates/architecture_composition_consistency_gate.py`
- `bash tests/check_architecture_constraints.sh`
- `bash tests/run_with_gate.sh`

## 当前任务：正式角色接入主线文档口径收口（2026-04-12）

- 状态：已完成
- 目标：
  - 把正式角色接入主线的权威文档口径同步到当前实现，清掉旧的 pair 输入口径、`coverage_needles` 和 `content_snapshot_paths_result()` 主路径描述，避免后续扩角继续按旧入口施工。
- 范围：
  - `README.md`
  - `tests/README.md`
  - `docs/design/battle_content_schema.md`
  - `docs/design/formal_character_delivery_checklist.md`
  - `docs/design/formal_character_design_template.md`
  - `docs/design/formal_character_capability_catalog.md`
  - `docs/design/project_folder_structure.md`
  - `docs/rules/06_effect_schema_and_extension.md`
  - `tests/gates/repo_consistency_docs_gate.py`
  - `docs/records/tasks.md`
  - `docs/records/decisions.md`
- 验收标准：
  - 文档明确 `remove_effect` 正式支持 `single / all`
  - 文档明确 formal pair 输入改为 `pair_token / baseline_script_path / pair_initiator_bench_unit_ids / pair_responder_bench_unit_ids + owned_pair_interaction_specs`
  - 文档明确 pair interaction 按完整有向 coverage 执行，并锁 `scenario_key`
  - 文档明确 manager smoke、pair smoke、formal demo replay 走 setup-scoped snapshot
  - 文档明确 capability catalog 字段改为 `required_fact_ids`
  - docs gate 能拦住上述几条旧口径
- 结果：
  - README、tests README 与 formal 交付设计文档已经改成“少量原始输入 + 派生有向产物”的正式口径。
  - `docs/rules/06_effect_schema_and_extension.md` 已补 `remove_effect single / all` 规则，并写清 `invalid_effect_remove_ambiguous` 触发边界。
  - `docs/design/project_folder_structure.md` 已把 `tests/gates` 纳入正式目录结构说明。
  - docs gate 已补新字段、新 bucket、新快照入口与旧口径 absence 检查。
- 验证：
  - `python3 tests/gates/repo_consistency_docs_gate.py`
