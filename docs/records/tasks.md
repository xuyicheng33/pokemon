# 任务清单（活跃）

本文件只保留当前仍直接影响交付、门禁或下一步开发节奏的任务入口。

更早且已关闭的完整记录见：

- `docs/records/archive/tasks_pre_2026-04-05_repair_wave.md`
- `docs/records/archive/tasks_pre_v0.6.4.md`
- `docs/records/archive/tasks_pre_v0.6.3.md`
- `docs/records/archive/tasks_2026-04-10_to_2026-04-18_refactor_wave.md`

当前生效规则以 `docs/rules/` 为准；工程结构与交付模板以 `docs/design/` 为准。
带日期的已完成阶段只保留当前仍有引用价值的摘要；完整流水统一看 archive。

## 当前阶段：长期工程化重构波次（2026-04-19 开始）

- 状态：进行中
- 总体目标：
  - 项目定位从"原型期"升级为长期工程，底层架构必须稳定规范；本波次把当前过度工程化的形式噪声清理掉，同时保留工程严谨性
- 保留（不动）：
  - 6 层架构与依赖方向、单一运行态真相、确定性回放、核心 facade 稳定合同、内容资源加载期 fail-fast、Composition Root 显式装配、对外公开 ID 边界、主测试闸门

### 阶段 2：放宽架构阈值（已完成）

- 实际范围：
  - 架构 gate 阈值放宽：核心源文件 `500 警戒 / 800 硬线`、测试 support `400 警戒 / 600 硬线`、测试文件 `1200 硬线`、gate py `800 警戒 / 1200 硬线`
  - `docs/design/battle_core_architecture_constraints.md` 同步阈值描述
  - `docs/records/decisions.md` 正式标记项目升级为长期工程 + 阈值决策
- 存量 owner 合并（`SampleBattleFactory` / `BattleCoreManager` 外壳 / `BattleInitializer` / sandbox adapter）不再强制为阶段 2 的单独动作，而是让它们跟随后续阶段 3-5 的业务重构自然合并（为合并而合并 ROI 偏低，且容易引入回归风险）
- 验证：
  - `bash tests/check_architecture_constraints.sh` 通过
  - `bash tests/check_boot_smoke.sh` 通过
  - `bash tests/check_repo_consistency.sh` 通过

### 阶段 3：错误体系审计与 snapshot builder 合并（已完成）

- 实际范围：
  - 合并 `event_log_public_snapshot_builder.gd` 进 `public_snapshot_builder.gd`，后者同时提供战斗公开快照与事件日志公开快照构建
  - 审计两类错误机制：`last_error_code + error_state()` 用于 composition/builder/loader 组合错误、`last_invalid_battle_code + invalid_battle_code()` 用于运行时硬错误，两者各司其职（符合 2026-04-18 冻结合同），不强制合并
  - 跨边界 envelope `{ok, data, error_code, error_message}` 已是 `BattleCoreManager` 与共享 result envelope helper 的唯一公开形式
- 不做：强制为 17 个 service 引入 `ErrorReportingService` base class，避免牵动过多继承层次
- 验证：`bash tests/run_with_gate.sh` 全通过（418 tests、sandbox smoke 全绿）

### 阶段 4：formal character 治理层温和合并（已完成）

- 实际产出：
  - `baselines/` 每角色 3 → 1 文件（12 → 4），每角色 baseline 单文件含 unit/regular_skill/ultimate/passive/effect/field 全部合同
  - `validators/` 每角色 5-7 → 1 文件（25 → 4），每角色 validator 单文件直接扩展 `validator_base` 并内联所有分桶校验逻辑
  - `manifest/` 子目录 6 → 2 文件（loader + views），loader 吸收 runtime_entry_normalizer，views 吸收 pair_catalog + pair_interactions + pair_matchups
  - formal gate 支撑层减 1：删除 `repo_consistency_formal_character_gate_support.py`（纯 import aggregator），三个 gate 脚本直接 import 源 support
  - 放宽 `validate_entry_validator_structure`：只保留 base class extend + `validate(content_index, errors)` 签名检查，删除三桶 preload/var/chain 的强制要求
- 不做：进一步合并 characters/capabilities/cutover/pairs 等 gate 文件（它们按职责拆分已很清晰）
- 验证：`bash tests/run_with_gate.sh` 全通过（418 tests、sandbox smoke）

### 阶段 5：测试温和评估（降级完成）

- 原计划：测试比例 1:0.96 → 1:0.5；test/ + tests/ → tests/gdunit/ 等；配合源码合并同步瘦身
- 实际降级：考虑到 1:0.5 目标需要删除约 10k 行测试代码、损失覆盖面；test/ → tests/gdunit/ 重命名涉及 204+ suite 文件的 preload 路径 + manifest + gate 硬编码路径替换，回归风险高
- 观察：当前 test 目录下有 ~15 个"纯 preload wrapper"（7-16 行，无 test_*）仅作为 manifest `suite_path` 入口；这些 wrapper 单独删除需要改 manifest 契约 + 对应 gate，ROI 低
- 决议：保留当前测试结构，把测试优化留到未来按具体痛点（某个 suite 跑得慢 / 某个角色接入后有明显重复）时针对性做，而不是批量改
- 验证：无改动，沿用已验证的 `bash tests/run_with_gate.sh`（418 tests、sandbox smoke）

### 阶段 6：文档 + gate 温和合并（降级完成）

- 原计划：docs/design 27 → 8、decisions.md 重写、README 18KB → 3KB、24 gate py → 3-4
- 实际产出：
  - 合并 docs gate 7 个文件为 1 个：删除 `repo_consistency_docs_gate_content_formal_delivery.py`、`repo_consistency_docs_gate_module_self_check.py`、`repo_consistency_docs_gate_records_archive_wording.py`、`repo_consistency_docs_gate_runtime_contracts.py`、`repo_consistency_docs_gate_sandbox_testing_surface.py`、`repo_consistency_docs_gate_shared.py`，内容作为内部函数内联到 `repo_consistency_docs_gate.py`；同时去掉 `module_self_check` 强制拆分的形式约束
- 不做：
  - `docs/design/` 27→8：当前每个文件都有明确职责（architecture/effect/turn/log/replay/formal/角色设计等），合并会牺牲可查阅性
  - `architecture_composition_consistency_gate` 三件套：`_support` 被 `architecture_wiring_graph_gate` 共用，强行合并破坏现有解耦
  - `formal_character_gate` 分组文件：按 characters/capabilities/cutover/pairs 职责拆分清晰，已在阶段 4 删除纯 aggregator
  - README/decisions 激进瘦身：当前长度（README 320 行、decisions 179 行）是长期工程正常量，强行压到 3KB 会损失重要入口与决策溯源
- 验证：`bash tests/run_with_gate.sh` 全通过

### 阶段 7：核心类型标注（已完成）

- runtime/contracts 全字段、facade 参数/返回值、主 orchestrator/service 依赖字段加类型
- 实际产出：
  - `SandboxSessionState`、`BattleCoreSession`、`BattleCoreManager*`、`BattleInitializer*` 等核心运行态对象已补齐显式类型，减少 facade / orchestrator / ports 之间的弱引用漂移
  - `BattleCorePublicSnapshotBuilder` 继续统一承担公开快照与事件日志快照投影，并把相关调用点切到一致的类型边界
  - `run_replay` 公开合同保留运行时 envelope 校验，不把非法输入提前升级成 GDScript 解析期错误；对应契约测试与 ports 契约测试已同步改成 typed stub
- 验证：
  - `bash tests/run_with_gate.sh` 通过

## 当前阶段：BattleSandbox 边界收口与 SampleBattleFactory 减负（2026-04-18）

- 状态：已完成
- 目标：
  - 收口 BattleSandbox 可变状态外泄、统一共享属性读取和结果式边界、把 `BattleInitializer` 子 helper wiring 改成显式 ports，并明显降低 `SampleBattleFactory` 的文件碎片度。
- 范围：
  - `docs/records/tasks.md`
  - `docs/records/decisions.md`
  - `docs/records/review_2026-04-18_battlesandbox_factory_cleanup_wave.md`
  - `src/shared/property_access_helper.gd`
  - `src/shared/result_envelope_helper.gd`
  - BattleSandbox / SampleBattleFactory / BattleInitializer 相关源码与对应 suite、support、gate、CI 配置
- 验收标准：
  - `BattleSandboxController` 不再暴露可写运行态和 UI 裸引用；测试支持层改走 controller 明确入口
  - 共享属性读取统一收口到 `PropertyAccessHelper`
  - adapter / composition / shared 外层失败结果统一包含 `ok/data/error_code/error_message`
  - `BattleInitializer` 子 helper 继续私有，但必须通过显式 ports 配置依赖
  - `SampleBattleFactory` 在不改公开 API 的前提下明显减少 helper 文件数，且不触发 architecture gate 行数上限
  - `bash tests/check_architecture_constraints.sh`、`bash tests/check_repo_consistency.sh`、`bash tests/check_sandbox_smoke_matrix.sh`、`bash tests/run_with_gate.sh` 通过
- 完成结果：
  - 已补齐 `SandboxSessionState` / `SandboxViewRefs`、`PropertyAccessHelper`、`BattleInitializerPorts`，并把 BattleSandbox、共享结果式和 initializer child ports 全部收口到新边界
  - 已强力合并 `SampleBattleFactory` 内部 helper、清理旧路径针脚、抽出 CI Godot setup composite action，并拆分厚 suite
  - 已通过 `bash tests/check_architecture_constraints.sh`、`bash tests/check_repo_consistency.sh`、`bash tests/check_sandbox_smoke_matrix.sh`、`bash tests/run_with_gate.sh`

## 当前阶段：全量质量收口与仓库卫生修复（2026-04-19）

- 状态：已完成
- 目标：
  - 一次性收掉 2026-04-19 审阅确认的问题，补齐 `.gd.uid`、缩进、结果式、battle core 结构脏点、测试体量盲区和本地仓库噪声的统一规则与实现。
- 范围：
  - `docs/records/tasks.md`
  - `docs/records/decisions.md`
  - `docs/records/review_2026-04-19_quality_sweep_disposition.md`
  - `.gitignore`
  - `docs/design/current_development_workflow.md`
  - `docs/design/battle_core_architecture_constraints.md`
  - `README.md`
  - `tests/README.md`
  - `tests/check_architecture_constraints.sh`
  - `tests/check_repo_consistency.sh`
  - `tests/gates/*` 中本轮新增或调整的 gate
  - `tests/cleanup_local_artifacts.sh`
  - battle core / adapters / composition / shared formal manifest / sample factory / sandbox 相关源码
  - `test/` 与 `tests/` 中本轮拆分或更新的 suite / helper
- 验收标准：
  - 有效 `.gd.uid` 全部纳入版本管理，孤儿 `.gd.uid` 清零，repo consistency gate 会直接拦截回退
  - `src/`、`test/`、`tests/`、`scenes/` 的 GDScript 前导缩进统一为 tab，style gate 会直接拦截 space-only 与 mixed
  - 外层结果式统一到 `ok / data / error_code / error_message`
  - `BattleState` 查询逻辑不再保留假缓存
  - `COMPOSE_DEPS` 只保留外部注入依赖，battle core 结构性脏点完成收口
  - warning 档 owner 和超厚 shared helper 完成拆分，离开当前预警线
  - 本地清理入口、开发流程文档与审查处置记录同步补齐
  - `bash tests/check_architecture_constraints.sh`、`bash tests/check_repo_consistency.sh`、`bash tests/run_with_gate.sh` 通过
- 完成结果：
  - `.gd.uid` 已全部按新仓库策略纳入版本管理，孤儿 `.gd.uid` 清零，repo consistency / uid gate 会直接拦截回退
  - `src/`、`test/`、`tests/`、`scenes/` 的 GDScript 前导缩进已统一为 tab，style gate 已升为必过门禁
  - 外层结果式已统一到 `ok / data / error_code / error_message`，BattleSandbox policy / adapters / facade helper / formal manifest / sample factory 全部走共享 helper
  - `ErrorStateHelper` 已落地并接管重复的 `last_error_* + error_state()` 样板；`BattleState` 假缓存已取消；`BattleCoreManagerContainerService` 与 `BattleInitializer.COMPOSE_DEPS` 已按本轮决议收口
  - warning 档 owner 与 shared/support helper 已完成拆分并离开预警线，包括 `sandbox_view_format_helper`、`turn_start_phase_service`、`replay_runner_output_helper`、`turn_loop_controller`、`catalog_factory_shared`、`replay_guard_shared`、`formal_character_pair_smoke/shared.gd`、`formal_character_manager_smoke_helper.gd`
  - 额外补抓并处理了两处漏项：`extension_validation_contract` 共享 suite 命名误伤 gate，已改为正式 suite 路径；`tests/support/combat_type_test_helper_cases.gd` 与相关 smoke command helper 已拆薄
  - 本地仓库卫生入口、开发流程文档、README 代码规模统计、任务记录与审查处置记录已同步更新
- 验证记录：
  - `2026-04-19` 已通过 targeted suite：`battle_state_index_cache_suite.gd`、`session_guard_suite.gd`、`replay_guard_summary_suite.gd`、`replay_guard_failure_suite.gd`、`replay_guard_input_suite.gd`
  - `2026-04-19` 已通过 targeted suite：`catalog_factory_setup_suite.gd`、`catalog_factory_delivery_alignment_suite.gd`、`catalog_factory_surface_suite.gd`、`extension_validation_contract/extension_validation_contract_suite.gd`、`formal_character_pair_smoke/surface_suite.gd`、`formal_character_pair_smoke/interaction_suite.gd`
  - `2026-04-19` 已通过 targeted suite：`gojo_manager_smoke_suite.gd`、`manual_battle_scene/manual_flow_suite.gd`、`manual_battle_scene/demo_replay_suite.gd`
  - `2026-04-19` 已通过门禁：`bash tests/check_gdunit_gate.sh`、`bash tests/check_boot_smoke.sh`、`bash tests/check_suite_reachability.sh`、`bash tests/check_architecture_constraints.sh`、`bash tests/check_repo_consistency.sh`、`bash tests/check_sandbox_smoke_matrix.sh`、`bash tests/run_with_gate.sh`

## 当前阶段：原型减负与工程收口（2026-04-18）

- 状态：已完成
- 目标：
  - 在不放松 formal 单源、gate 和 `composer + slot` 稳定结构的前提下，收口人工维护面、统一边界结果式、补齐 BattleSandbox 回放浏览，并把 CI 改成并行执行。
- 范围：
  - `README.md`
  - `tests/README.md`
  - `docs/design/current_development_workflow.md`
  - `docs/design/current_stage_regression_baseline.md`
  - `docs/design/formal_character_delivery_checklist.md`
  - `docs/design/log_and_replay_contract.md`
  - `docs/design/project_folder_structure.md`
  - `docs/design/battle_core_architecture_constraints.md`
  - `docs/records/tasks.md`
  - `docs/records/decisions.md`
  - `tests/gates/repo_consistency_docs_gate*.py`
  - `tests/sync_formal_registry.sh`
  - `tests/check_gdunit_gate.sh`
  - `tests/check_boot_smoke.sh`
  - `tests/run_with_gate.sh`
  - `.github/workflows/ci.yml`
  - BattleSandbox / replay / result envelope 相关源码与对应 suite
- 验收标准：
  - formal 继续只认 `config/formal_character_sources/` 为人工真相，`manifest/catalog` 只能通过唯一同步入口回写
  - README 与 `tests/README.md` 退回入口说明，docs gate 只拦结构、来源、流程和活跃记录漂移
  - 外层触达路径改走共享 result envelope helper，`BattleCoreManager` 公共 envelope 不变
  - replay 输出新增 `turn_timeline`，BattleSandbox demo replay 可按回合只读浏览
  - suite 继续拆分但顶层 wrapper 路径保持稳定
  - 本地 `bash tests/run_with_gate.sh` 仍是唯一总入口，CI 改成 3 个并行 job 并与本地共用同一批子脚本
- 结果：
  - formal 单源、同步入口、交付 checklist 和 workflow 已统一；`tests/sync_formal_registry.sh` 成为 committed artifacts 的唯一人工同步入口
  - README / `tests/README.md` 已去掉 formal 字段镜像和大段 contract wording，docs gate 已收口为结构与流程校验
  - `src/shared/result_envelope_helper.gd` 已落地，sandbox bootstrap/replay、formal registry 读取、manager/sample factory 边界结果式已统一
  - `ReplayOutput.turn_timeline`、`ReplayRunner` frame 记录和 BattleSandbox 回放浏览态已落地；demo replay 现在支持按回合切换公开快照与事件片段，且 replay 模式禁止提交 action
  - `manual_battle_scene_suite.gd` 已继续下沉为 wrapper + 子目录结构，公共路径保持不变
  - CI 已拆成 `gdunit / repo_and_arch_gates / boot_and_sandbox_smoke` 三个并行 job；本地总入口继续复用共享子脚本
- 验证：
  - `python3 tests/gates/repo_consistency_docs_gate.py`
  - `python3 tests/gates/repo_consistency_surface_gate.py`
  - `python3 tests/gates/repo_consistency_formal_character_gate.py`
  - `bash tests/check_boot_smoke.sh`
  - `bash tests/check_sandbox_smoke_matrix.sh`
  - `bash tests/check_suite_reachability.sh`
  - `TEST_PATH=res://test/suites/replay_determinism_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/manager_replay_header_contract_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/manual_battle_scene/manual_flow_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/manual_battle_scene/demo_replay_suite.gd bash tests/run_gdunit.sh`
  - `bash tests/run_with_gate.sh`

## 当前阶段：记录归档、审查处置与最终收口（2026-04-18）

- 状态：已完成
- 目标：
  - 把 2026-04-10 到 2026-04-18 这轮重构的正式记录收成长期可引用的入口，并完成最终总验收、主线合并与分支清理。
- 范围：
  - `docs/records/tasks.md`
  - `docs/records/decisions.md`
  - `docs/records/archive/*`
  - `docs/records/review_2026-04-18_external_audit_disposition.md`
  - 必要的 `README.md / tests/README.md / docs/design/*`
  - 必要的最终 warning 清理
  - 最终 gate、分支合并与清理
- 验收标准：
  - 活跃 `tasks.md / decisions.md` 明显缩短，只保留长期规则、最近两轮关键决策、当前阶段状态与 archive 索引
  - 新增 2026-04-18 外部 15 项审查处置记录
  - `bash tests/check_repo_consistency.sh` 与 `bash tests/run_with_gate.sh` 通过
  - 当前工作分支合回 `main`，阶段分支删除，工作区保持干净
- 结果：
  - 已新增 `docs/records/archive/tasks_2026-04-10_to_2026-04-18_refactor_wave.md` 与 `docs/records/archive/decisions_2026-04-10_to_2026-04-18_refactor_wave.md`，保存这轮压缩前的完整记录快照
  - 活跃 `docs/records/tasks.md` 与 `docs/records/decisions.md` 已压缩到当前有效规则、最近阶段摘要和 archive 索引
  - 已新增 `docs/records/review_2026-04-18_external_audit_disposition.md`，正式收口 15 项外部审查处置
  - `README.md / tests/README.md / docs/design/*` 已对齐 formal source 单源、validator 硬约束与 cache freshness 新口径
  - `kashimo / obito manager smoke` suite 已顺手清掉 `_harness` 同名遮蔽 warning，保持最终总验收输出更干净
- 验证：
  - `git diff --check`
  - `python3 tests/gates/repo_consistency_docs_gate.py`
  - `bash tests/check_repo_consistency.sh`
  - `bash tests/run_with_gate.sh`

## 最近完成：formal 角色交付面减负与验证模板化（2026-04-18）

- 状态：已完成
- 目标：
  - 把 formal 角色交付面收口到 `config/formal_character_sources/` 单源，并把 manager smoke/blackbox 与超厚 suite 改成更薄的模板化结构。
- 结果：
  - 已新增 `config/formal_character_sources/00_shared_registry.json` 与四个角色 source descriptor，`config/formal_character_manifest.json` / `config/formal_character_capability_catalog.json` 现在是稳定提交的生成产物
  - `content_validator_script_path` 已升级成 formal 角色硬约束；formal gate 会直接比对 source 导出结果与 committed artifacts
  - `tests/support/formal_character_manager_smoke_helper.gd` 已统一承接 case spec 驱动；Gojo / Sukuna / Kashimo / Obito 的 `manager smoke/blackbox` 已模板化
  - `catalog_factory_suite.gd` 与 `replay_guard_suite.gd` 已拆成单域 suite + shared support，formal registry fixture 也已默认补合法 validator 路径
- 验证：
  - 四角色 `manager smoke/blackbox` 共 8 个 suite 全通过
  - `runtime_registry / delivery_registry / capability_catalog / scoped_validator` 全通过
  - `catalog_factory_setup / delivery_alignment / surface` 全通过
  - `replay_guard_input / summary / failure` 全通过
  - `formal_character_pair_smoke/surface / interaction` 全通过
  - `extension_validation_contract` 下 Gojo / Sukuna / Kashimo / Obito 坏例 suite 全通过
  - `bash tests/check_suite_reachability.sh`
  - `python3 tests/gates/repo_consistency_formal_character_gate.py`
  - `godot --headless --script tests/helpers/export_formal_registry_views.gd -- <tmp> config/formal_character_sources` 连续两次输出一致
- 阶段提交：
  - `947f74f refactor: reduce formal character delivery cost`

## 当前波次：formal contract 扩角前硬收口（2026-04-10）

- 状态：已完成
- 当前仍有效的冻结点：
  - `config/formal_character_manifest.json` 的 formal pair 身份与交互输入继续固定挂在角色条目：`pair_token / baseline_script_path / owned_pair_interaction_specs`
  - `pair_token` 继续要求唯一且稳定；`baseline_script_path` 必须显式存在；`owned_pair_interaction_specs` 继续只允许声明和更早角色的 pair
  - formal manifest 的 `characters / matchups + characters[*].owned_pair_interaction_specs` 继续和 gate 保持一致，不回退成多真源或兼容口径
- 完整背景：
  - 见 `docs/records/archive/tasks_2026-04-10_to_2026-04-18_refactor_wave.md`

## 当前验证基线

- 最小可玩性检查：
  - 可启动：能进入 `BattleSandbox` 主流程
  - 可操作：`manual/policy` 至少能完整跑完一局
  - 无阻断错误：没有崩溃、卡死或 invalid runtime 漂移
- 当前总验收入口：
  - `bash tests/check_repo_consistency.sh`
  - `bash tests/run_with_gate.sh`
