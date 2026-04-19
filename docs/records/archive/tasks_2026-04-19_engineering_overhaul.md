# 长期工程化重构波次 + 前序已完成阶段（2026-04-19 归档）

本文件为 2026-04-19 审阅后从 `tasks.md` 归档的已完成阶段全量记录。

## 长期工程化重构波次（2026-04-19）

- 状态：已完成
- 总体目标：
  - 项目定位从"原型期"升级为长期工程，底层架构必须稳定规范；本波次把当前过度工程化的形式噪声清理掉，同时保留工程严谨性
- 保留（不动）：
  - `BattleCoreManager` 外部 envelope 合同、deterministic replay、fail-fast、单一运行态真相、`tests/run_with_gate.sh` 主 gate 总入口
- 分阶段计划：

| Stage | 内容 | 对应问题 | 状态 |
|---|---|---|---|
| 0 | 统一定位与活跃规则基线 | #6, #10(部分) | 已完成 |
| 1 | composition 盘点 + 目标图冻结 + 死元数据清理 + 错误体系目标设计 + payload dispatch 决策 | #1, #2, #3, #4(设计), #12(部分) | 已完成 |
| 2 | composition 主链路收缩与装配方式改造（81→65 slot, 16 helper 下沉） | #1, #2, #3, #12(部分) | 已完成 |
| 3 | 错误体系统一（B/C 类内联/重命名，A 类保留） | #4, #12(部分) | 已完成 |
| 4 | 测试修复 + 死代码清理（BattleSandboxRunner 删除） | #7, #8 | 已完成 |
| 5 | SampleBattleFactory 审查（结构合理，无需大改） | #11 | 已完成 |
| 6 | 文档归档 + records 收口 + gate 全通 | #10, #12(剩余) | 已完成 |

### 阶段 2：放宽架构阈值

- 实际范围：
  - 架构 gate 阈值放宽：核心源文件 `500 警戒 / 800 硬线`、测试 support `400 警戒 / 600 硬线`、测试文件 `1200 硬线`、gate py `800 警戒 / 1200 硬线`
  - `docs/design/battle_core_architecture_constraints.md` 同步阈值描述
  - `docs/records/decisions.md` 正式标记项目升级为长期工程 + 阈值决策
- 存量 owner 合并（`SampleBattleFactory` / `BattleCoreManager` 外壳 / `BattleInitializer` / sandbox adapter）不再强制为阶段 2 的单独动作，而是让它们跟随后续阶段 3-5 的业务重构自然合并（为合并而合并 ROI 偏低，且容易引入回归风险）
- 验证：
  - `bash tests/check_architecture_constraints.sh` 通过
  - `bash tests/check_boot_smoke.sh` 通过
  - `bash tests/check_repo_consistency.sh` 通过

### 阶段 3：错误体系审计与 snapshot builder 合并

- 实际范围：
  - 合并 `event_log_public_snapshot_builder.gd` 进 `public_snapshot_builder.gd`，后者同时提供战斗公开快照与事件日志公开快照构建
  - 审计两类错误机制：`last_error_code + error_state()` 用于 composition/builder/loader 组合错误、`last_invalid_battle_code + invalid_battle_code()` 用于运行时硬错误，两者各司其职（符合 2026-04-18 冻结合同），不强制合并
  - 跨边界 envelope `{ok, data, error_code, error_message}` 已是 `BattleCoreManager` 与共享 result envelope helper 的唯一公开形式
- 不做：强制为 17 个 service 引入 `ErrorReportingService` base class，避免牵动过多继承层次
- 验证：`bash tests/run_with_gate.sh` 全通过（418 tests、sandbox smoke 全绿）

### 阶段 4：formal character 治理层温和合并

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
- 观察：当前 test 目录下有 37 个"纯 preload wrapper"（7-16 行，无 test_*）仅作为 manifest `suite_path` 入口；这些 wrapper 单独删除需要改 manifest 契约 + 对应 gate，ROI 低
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

### 阶段 7：核心类型标注

- runtime/contracts 全字段、facade 参数/返回值、主 orchestrator/service 依赖字段加类型
- 实际产出：
  - `SandboxSessionState`、`BattleCoreSession`、`BattleCoreManager*`、`BattleInitializer*` 等核心运行态对象已补齐显式类型，减少 facade / orchestrator / ports 之间的弱引用漂移
  - `BattleCorePublicSnapshotBuilder` 继续统一承担公开快照与事件日志快照投影，并把相关调用点切到一致的类型边界
  - `run_replay` 公开合同保留运行时 envelope 校验，不把非法输入提前升级成 GDScript 解析期错误；对应契约测试与 ports 契约测试已同步改成 typed stub
- 验证：
  - `bash tests/run_with_gate.sh` 通过

## BattleSandbox 边界收口与 SampleBattleFactory 减负（2026-04-18）

- 状态：已完成
- 目标：
  - 收口 BattleSandbox 可变状态外泄、统一共享属性读取和结果式边界、把 `BattleInitializer` 子 helper wiring 改成显式 ports，并明显降低 `SampleBattleFactory` 的文件碎片度。
- 完成结果：
  - 已补齐 `SandboxSessionState` / `SandboxViewRefs`、`PropertyAccessHelper`、`BattleInitializerPorts`，并把 BattleSandbox、共享结果式和 initializer child ports 全部收口到新边界
  - 已强力合并 `SampleBattleFactory` 内部 helper、清理旧路径针脚、抽出 CI Godot setup composite action，并拆分厚 suite
  - 已通过 `bash tests/run_with_gate.sh`

## 全量质量收口与仓库卫生修复（2026-04-19）

- 状态：已完成
- 目标：
  - 一次性收掉 2026-04-19 审阅确认的问题，补齐 `.gd.uid`、缩进、结果式、battle core 结构脏点、测试体量盲区和本地仓库噪声的统一规则与实现。
- 完成结果：
  - `.gd.uid` 已全部按新仓库策略纳入版本管理，孤儿 `.gd.uid` 清零
  - GDScript 前导缩进已统一为 tab，style gate 已升为必过门禁
  - 外层结果式已统一到 `ok / data / error_code / error_message`
  - `ErrorStateHelper` 已落地；`BattleState` 假缓存已取消；`COMPOSE_DEPS` 已收口
  - warning 档 owner 与 shared/support helper 已拆分
- 验证：`bash tests/run_with_gate.sh` 全通过

## 原型减负与工程收口（2026-04-18）

- 状态：已完成
- 目标：
  - 收口人工维护面、统一边界结果式、补齐 BattleSandbox 回放浏览，并把 CI 改成并行执行。
- 结果：
  - formal 单源、同步入口、交付 checklist 和 workflow 已统一
  - README / `tests/README.md` 已去掉 formal 字段镜像，docs gate 已收口为结构与流程校验
  - `ResultEnvelopeHelper` 已落地，边界结果式已统一
  - `ReplayOutput.turn_timeline` 和 BattleSandbox 回放浏览态已落地
  - CI 已拆成 3 个并行 job
- 验证：`bash tests/run_with_gate.sh` 全通过

## 记录归档、审查处置与最终收口（2026-04-18）

- 状态：已完成
- 目标：
  - 把 2026-04-10 到 2026-04-18 这轮重构的正式记录收成长期可引用的入口，完成最终总验收、主线合并与分支清理。
- 结果：
  - 已新增归档快照与 15 项外部审查处置记录
  - 活跃 `tasks.md / decisions.md` 已压缩
  - `kashimo / obito manager smoke` suite 已清掉 `_harness` 同名遮蔽 warning
- 验证：`bash tests/run_with_gate.sh` 全通过

## formal 角色交付面减负与验证模板化（2026-04-18）

- 状态：已完成
- 目标：
  - 把 formal 角色交付面收口到 `config/formal_character_sources/` 单源，并把 manager smoke/blackbox 与超厚 suite 改成更薄的模板化结构。
- 结果：
  - 四角色 source descriptor 单源已落地，manifest / capability catalog 现在是稳定提交的生成产物
  - `content_validator_script_path` 已升级成 formal 角色硬约束
  - 四角色 `manager smoke/blackbox` 已模板化
  - `catalog_factory_suite.gd` 与 `replay_guard_suite.gd` 已拆成单域 suite
- 验证：`bash tests/run_with_gate.sh` 全通过

## formal contract 扩角前硬收口（2026-04-10）

- 状态：已完成
- 当前仍有效的冻结点：
  - `config/formal_character_manifest.json` 的 formal pair 身份与交互输入继续固定挂在角色条目：`pair_token / baseline_script_path / owned_pair_interaction_specs`
  - `pair_token` 继续要求唯一且稳定；`baseline_script_path` 必须显式存在；`owned_pair_interaction_specs` 继续只允许声明和更早角色的 pair
  - formal manifest 的 `characters / matchups + characters[*].owned_pair_interaction_specs` 继续和 gate 保持一致，不回退成多真源或兼容口径
- 完整背景：
  - 见 `docs/records/archive/tasks_2026-04-10_to_2026-04-18_refactor_wave.md`
