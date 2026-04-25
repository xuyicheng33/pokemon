# 决策记录（活跃）

本文件只保留当前仍直接约束实现、门禁和扩角节奏的活规则；更早的完整背景与执行流水统一看 archive。

历史归档：

- `docs/records/archive/decisions_pre_2026-04-05_repair_wave.md`
- `docs/records/archive/decisions_pre_v0.6.4.md`
- `docs/records/archive/decisions_pre_v0.6.3.md`
- `docs/records/archive/decisions_2026-04-10_to_2026-04-18_refactor_wave.md`

当前生效规则以 `docs/rules/` 为准；`docs/design/` 负责结构与交付面；本文件只解释“为什么现在这样定”。

## 2026-04-19 长期工程化定位升级

- 项目定位从"概念/原型期"升级为**长期工程**：底层架构稳定规范是第一优先级，后续会长期加入新机制，基础不稳会直接传导到未来扩展。
- 整体策略为"**保留严谨性、精简形式噪声**"：
  - 保留项：6 层架构与依赖方向、单一运行态真相、确定性回放、核心 facade 合同、内容资源加载期 fail-fast、Composition Root 显式装配、对外公开 ID 边界、主测试闸门
  - 精简项：文件过度碎片化、双错误体系、formal character 治理层多余分层、测试重复覆盖、文档冗余、gate 数量
- 架构文件行数阈值放宽：
  - 核心源文件：`500..800` 行预警、`> 800` 行必须拆分
  - 测试 support：`220..250` 预警、`> 250` 必须拆分
  - 测试文件：`> 1200` 必须拆分
  - Gate py：`800..1200` 预警、`> 1200` 必须拆分
  - 理由：原 `250` 行硬线适合原型期速写，长期工程需要主 owner 与 facade 容纳稳定合同与装配编排。
- 分阶段推进：详见 `docs/records/tasks.md` 当前阶段。

### 本轮长期不动边界（2026-04-19 冻结）

以下 5 项在本轮工程化重构全程不动，任何阶段如需触碰必须先暂停说明：

1. **`BattleCoreManager` 外部 envelope 合同**：`create_session / get_legal_actions / build_command / run_turn / get_public_snapshot / get_event_log_snapshot / close_session / run_replay` 的签名与返回 envelope `{ok, data, error_code, error_message}` 不变。
2. **Deterministic replay**：同 `seed + content snapshot + command stream` 必须产出同一 `final_state_hash`。
3. **Fail-fast**：非法输入直接报错，不做静默降级。
4. **单一运行态真相**：`BattleState` 是唯一运行态对象，其他模块不得各自缓存状态副本。
5. **`tests/run_with_gate.sh` 作为默认 quick gate 总入口**：内部顺序 `gdUnit4 quick → boot smoke → suite reachability → architecture constraints → repo consistency → Python lint → sandbox smoke matrix quick` 不变；长尾回归进入显式 `tests/run_extended_gate.sh`，完整收口使用 `TEST_PROFILE=full bash tests/run_with_gate.sh`。

### 扩角前接入安全线（2026-04-24）

- 新正式角色脚手架产物在完成前只能进入 `scripts/drafts/` 镜像路径；正式目录不接收 `FORMAL_DRAFT_`、`draft_marker`、`FILL_IN`、占位 runner 或 live validator `pass`。
- `config/formal_character_sources/` 与 `scripts/drafts/` 中的 source descriptor 读取失败必须直接中止脚手架，不允许跳过坏 JSON 后继续做 collision 检查。
- Sandbox UI 可以继续把用户控件输入规范化；测试、CLI smoke 和自动化入口必须使用 strict config，非法 matchup / mode / seed / control mode 直接失败。
- Sandbox smoke matrix 默认使用 `SANDBOX_SMOKE_SCOPE=quick` 覆盖推荐与 `<pair>_vs_sample` 主路径；全量可见 matchup 只通过 `SANDBOX_SMOKE_SCOPE=full` 显式触发，避免 formal directed matchup 随角色数二次方拖慢日常 gate。
- 内容快照缓存签名的显式依赖缺失属于内容快照错误，必须失败并暴露缺失路径，不允许退到 mtime 或空依赖签名。
- `FormalCharacterManifestViews` 只保留 runtime / delivery / catalog 入口协调；pair interaction case 派生逻辑由 `FormalCharacterPairInteractionCaseBuilder` 承担，后续 manifest 派生继续按职责拆分。

### 测试入口收口（2026-04-25）

- gdUnit suite 入口以真实可发现的 `test/suites/**/*.gd` 文件为准；不再新增只负责 `register_tests` 聚合的 wrapper suite。
- manifest、文档和 gate 必须引用真实 suite 路径；大型主题直接拆成子目录下的具体 suite。
- 对同一文件内同类黑盒场景，优先保留一个公开 `test_*` 聚合入口，内部按 case 列表顺序执行原断言，减少测试面噪声。
- `tests/run_gdunit.sh` 必须把不存在路径、空 suite、缺失报告 XML 和 0 testcase XML 当失败处理，避免删除或重命名 suite 后出现假绿。
- 测试分层固定为 `quick / extended / full`：quick 是默认开发门禁；extended 保留长尾边界、角色细节组合与历史回归；full 在 extended 基础上固定启用 full sandbox smoke。
- 新正式角色脚手架不得生成 `{pair_token}_suite.gd` 空 wrapper；`suite_path` 和 `required_suite_paths` 必须指向包含 `func test_*` 的真实 suite。
- draft readiness 对列入 `content_roots` 的 `units / skills / effects / passive_skills` 要求至少存在一个 `.tres`；只有 `fields` 可为空。

### Stage 1 composition slot 收缩目标图（2026-04-19 冻结）

当前 81 slot = base 66 + payload shared 3 + payload runtime 3 + payload handler 9。

**Payload dispatch 模式决策：保留。**  
`PayloadContractRegistry → PayloadHandlerRegistry → handler slot` 动态分派模式清晰可扩展，15 个 payload 相关 slot 本轮不动。

**Base 66 → 50：下沉 16 个 slot 为 owner 私有 helper。**  
目标总 slot 数：**65**（50 base + 15 payload）。

下沉清单：

| 原 slot | 下沉到 owner |
|---|---|
| action_chain_context_builder | action_executor |
| action_start_phase_service | action_executor |
| action_skill_effect_service | action_executor |
| action_execution_resolution_service | action_executor |
| action_domain_guard | action_executor |
| action_cast_direct_damage_pipeline | action_cast_service |
| action_cast_skill_effect_dispatch_pipeline | action_cast_service |
| action_hit_resolution_service | action_cast_service |
| power_bonus_resolver | action_cast_service |
| switch_action_service | action_executor |
| battle_initializer_setup_validator | battle_initializer |
| field_apply_log_service | field_apply_service |
| field_apply_effect_runner | field_apply_service |
| lifecycle_retention_policy | leave_service |
| faint_leave_replacement_service | faint_resolver |
| replacement_selector | replacement_service |

保留 50 slot 理由：均为跨模块依赖（被 2+ 其他 service 引用）或模块入口。

### Stage 1 错误体系目标设计（2026-04-19 冻结）

**结论：维持双轨模型，不强制合并。**

- **Track A — `ErrorStateHelper`（`last_error_code` + `error_state()`）**：用于 composition / builder / content loader 的组装期错误。这类错误发生在战斗开始前。
- **Track B — `last_invalid_battle_code` + `invalid_battle_code()`**：用于运行时战斗规则违反。这类错误发生在战斗执行中。
- **对外 — `ResultEnvelopeHelper`**：manager envelope 统一 `{ok, data, error_code, error_message}`。

两者各司其职（2026-04-18 审计结论确认），不合并。

**`_ok_result`/`_error_result` 本地包装处理方案：**

| 类别 | 文件数 | 处理 |
|---|---|---|
| A：已 delegate 到 `ResultEnvelopeHelper` 的纯别名 | 18 | 保留。部分 wrapper 注入固定 error code 或 strip_edges()，内联后调用点更冗长，可读性下降 |
| B：标准 envelope 结构但未 import helper | 6 | ✅ Stage 3 已加 import 并内联 |
| C：有副作用或自定义返回结构 | 1 (replay_runner_output_helper) | ✅ Stage 3 已重命名为 `_build_error_envelope` |

详细文件清单：
- A 类（18）：sandbox_policy_driver / sample_battle_factory_* 全部 10 个 / formal_character_baselines + loader / formal_character_capability_catalog / formal_character_manifest + loader + views / formal_registry_contracts
- B 类（6）：legal_action_service_rule_gate / cast_option_collector / switch_option_collector / sandbox_session_command_service / sandbox_session_coordinator
- C 类（1）：replay_runner_output_helper

### 代码质量与样式（2026-04-19）

1. `.gd.uid` 当前固定纳入版本管理：
   - `.gitignore` 不再允许忽略 `*.uid`
   - 有效 `.gd.uid` 必须随同对应 `.gd` 一起提交
   - 孤儿 `.gd.uid` 必须删除，并由 repo consistency gate 直接失败
2. GDScript 前导缩进当前固定只允许 tab（`src/`、`test/`、`tests/`、`scenes/`），space-only 与 tab/space 混用都直接视为失败。
3. 测试 support helper 体量 gate 当前固定扩到 `test/**/shared*.gd`、`test/**/*_shared.gd`、`tests/support/**/*.gd`，落在 `220..250` 行输出预警，> `250` 直接失败。
4. `BattleState` 查询路径不保留缓存语义；`get_side / get_unit / get_unit_by_public_id` 始终返回当前 `sides / team_units` 真值；`rebuild_indexes()` 已移除。
5. `COMPOSE_DEPS` 当前固定只描述 composer 注入的外部依赖；owner 私有 helper 不再混入这份声明。
6. 共享结果式 helper 的适用边界当前扩大到 policy / adapters / facade helper；外层成功/失败结果统一只认 `ok / data / error_code / error_message`。各文件允许定义 `_ok_result` / `_error_result` 等私有包装器委托到 `ResultEnvelopeHelperScript`，这属于可接受的约定性模式，不视为冗余。
7. 本地报告目录当前固定只认 `reports/gdunit`；其余历史 `reports/gdunit_*` 目录与 `tmp / .tmp` 都视为可清理噪声。

### 核心类型标注边界（2026-04-19，更新）

- `BattleCoreManager` / `BattleCoreManagerContainerService` 这类 facade 公开入口，继续允许非法输入走运行时 envelope 校验并返回正式错误，不把 contract 失败提前变成 GDScript 解析错误。
- `session state / facade service / initializer ports` 这类核心运行态依赖字段，继续优先补成显式具体类型，不回退成大面积 `RefCounted`。
- 测试替身如果要写进这些强类型字段，固定通过继承真实类或 typed stub 适配；`shared_contract_suite` 这类 wiring 契约测试不再用裸 `RefCounted` 穿过类型边界。
- `battle_core` 核心函数参数中的高频运行态类型（`BattleState`、`BattleContentIndex`、`ChainContext`、`QueuedAction`、`EffectEvent`、`Command`）已补齐显式类型标注。GDScript 4 class-type 参数允许 null，不影响现有防御性 null 检查。

### `battle_core → composition` 受控例外（2026-04-19）

- `battle_core` 各 service 允许 preload `src/composition/service_dependency_contract_helper.gd` 用于 `resolve_missing_dependency` 自检。
- 此依赖方向是架构层面唯一的逆向白名单，由 `tests/check_architecture_constraints.sh` 显式管控。
- 除 `service_dependency_contract_helper.gd` 外，`battle_core` 不得 import `composition` 的任何其他文件。

## 2. 组合依赖与编排冻结（2026-04-18）

- compose 依赖与 reset 元数据继续只认 script 自声明：`COMPOSE_DEPS`、`COMPOSE_RESET_FIELDS`。
- `BattleCoreComposer`、runtime 缺依赖检查与两条 architecture gate 统一通过 `service_dependency_contract_helper.gd` 读取这份声明，不再恢复 split wiring specs。
- composition 当前固定只分三层：核心稳定 service slot、payload/runtime slot、owner 私有 helper 实例。
- 单 owner、无独立生命周期、无跨模块复用的 helper，默认只留在 owner 内部，不再继续晋升为 composer service slot。
- 回合编排继续固定为：`turn_selection_resolver.gd`、`turn_start_phase_service.gd`、`turn_end_phase_service.gd`、`turn_field_lifecycle_service.gd`。
- `BattleInitializer` 继续只保留顺序调度；setup 校验、side/unit 构造与初始化阶段子流程分别下沉到独立 owner。
- `SandboxSessionCoordinator` 继续只保留 facade；sandbox 会话热点固定拆成 `bootstrap / demo / command` 三个 owner。

## 3. 正式角色体系（2026-04-12 起，2026-04-18 更新）

### 基础规则

- `docs/records/` 以后只承担活跃记录、决策入口与 archive 索引，不再继续充当现行规则的机器约束层。
- formal 共享字段定义只保留一份真相：`config/formal_registry_contracts.json`、`src/shared/formal_registry_contracts.gd`。
- formal pair 覆盖模型继续固定为：每个无序正式角色对恰好 1 条 interaction spec（1 个 `scenario_key`），派生出 2 条 directed case。gate 与 checklist 不再允许同 pair 多 case。
- Kashimo / Sukuna 的 manager 黑盒继续视为正式交付面的一部分；后续扩角不得跳过 manager 级黑盒。

### Registry 单源与 validator 硬约束

- `config/formal_character_sources/` 现在是 formal 角色 registry 的唯一人工维护入口：
  - `00_shared_registry.json` 负责共享 `matchups/capabilities`
  - 每个角色一份 `0N_<character>.json` 负责 runtime + delivery + `content_roots`
- `config/formal_character_manifest.json` 与 `config/formal_character_capability_catalog.json` 继续提交到仓库，但已经退成生成产物，不再手工维护。
- `content_roots` 允许目录与单文件资源混用，导出时统一递归展开成稳定排序的 `required_content_paths`。
- `content_validator_script_path` 现在是 formal 角色 runtime 合同的必填字段，不再写成"按需"。
- formal gate 当前固定校验：source descriptors 可导出、导出结果与 committed manifest/catalog 完全一致、同一轮里不允许 source 与产物漂移。
- 人工同步 committed artifacts 的唯一入口固定为：`bash tests/sync_formal_registry.sh`。

### Manager smoke/blackbox 与 suite 模板化

- `tests/support/formal_character_manager_smoke_helper.gd` 当前固定承担 shared runner：`run_named_case / run_case`、`build_case_state`、`get_legal_actions_result / get_public_snapshot_result / get_event_log_result`、`build_command_result / run_turn_result / run_turn_sequence_result`。
- 四个正式角色的 `manager smoke/blackbox` suite 当前固定写成"case spec + 少量角色断言"，不再各自复制 session / command / close 样板。
- `catalog_factory_suite.gd` 拆成 `setup / delivery_alignment / surface`；`replay_guard_suite.gd` 拆成 `input / summary / failure`；跨域断言只允许留在 shared support。
- formal registry 的 fixture helper 当前默认会补合法 validator 路径；如果坏例不是在测 validator，就不应该先被 validator 缺失抢走失败原因。

### Pair 输入与派生 contract

- formal pair 输入继续固定挂在 `characters[*]` 的 runtime 条目：`pair_token`、`baseline_script_path`、`owned_pair_interaction_specs`。
- `pair_token` 继续作为 formal pair 身份字段；`baseline_script_path` 继续作为 formal baseline 注册字段；`owned_pair_interaction_specs` 继续是唯一手写 pair interaction 输入。
- manifest 角色顺序继续作为 pair interaction ownership 的稳定输入：新正式角色默认追加到末尾，只能声明与更早角色的 `owned_pair_interaction_specs`；重排既有正式角色属于规范变更，必须同步迁移 specs 并记录决策。
- manifest 不再恢复顶层 pair bucket；pair 覆盖与 directed case 继续从 manifest 角色条目派生。

## 4. 外层结果式与回放（2026-04-18）

- `BattleCoreManager` 的外部 envelope 继续固定为：`ok`、`data`、`error_code`、`error_message`。
- 共享结果式构造与 unwrap 当前统一只认：`src/shared/result_envelope_helper.gd`。
- 这轮触及的 adapter / composition / shared formal 访问代码，不再直接散写 `ok/data/error_*` 字典。
- `battle_core/contracts/*` 与 runtime 类契约继续保留；只有序列化边界、gate/export 边界和 manager facade 外层结果式继续使用 `Dictionary`。
- `ReplayOutput` 当前正式新增 `turn_timeline`：初始化完成后固定记录 `turn_index = 0` 的初始 frame，每个完整 turn 结束后固定追加一个 frame，final `public_snapshot` 继续与 timeline 最终 frame 对齐。
- `BattleSandbox` 的 `MODE_DEMO_REPLAY` 当前固定进入只读回放浏览态：允许浏览上一回合 / 下一回合，固定显示当前 frame 的公开快照与事件片段，replay 模式下禁止手动 action 和 policy 推进。
- 2026-04-26 起，manager 边界外的 `run_replay().data.replay_output.event_log` 固定改为公开安全投影，和 `get_event_log_snapshot()` 同口径；完整内部 `LogEvent` 只保留在核心 `ReplayRunner` 内部。
- `run_replay().data.public_snapshot` 固定与 `replay_output.turn_timeline` 最后一帧对齐，不再表述为单独从最终运行态即时重建。
- 回放命令流必须 fail-fast：战斗结束或回合上限后仍有未消费的 `command_stream` turn_index 时，按 `invalid_replay_input` 失败。
- 投降保持“即时结束、不进入行动队列”，但必须先通过 `CommandValidator` 的 side、turn_index 与当前 active actor 校验。

## 5. Sandbox 与研发入口（2026-04-13 起，2026-04-18 更新）

### 主线入口与验证矩阵

- `BattleSandboxController` 继续是当前研发试玩入口；默认路径继续固定为 `gojo_vs_sample + 9101 + manual/policy`。
- BattleSandbox 可见推荐 matchup 的正式角色段从 `config/formal_character_manifest.json` 的 `characters[*].formal_setup_matchup_id` 派生；新增角色不再手工维护 sandbox 推荐名单或 quick smoke 角色名单。
- CLI/debug 启动路径默认启用 strict launch config；非法 matchup / mode / seed / control mode 必须暴露为启动错误，只有 UI 控件内的选择归一化可以保留非 strict 行为。
- `tests/run_with_gate.sh` 继续是默认 quick 总入口，顺序保持：`gdUnit4 quick → boot smoke → suite reachability → architecture constraints → repo consistency → Python lint → sandbox smoke matrix quick`。
- `BattleSandbox`、`run_with_gate`、`run_extended_gate` 与 `gdUnit4 + test/` 继续构成当前仓库的主研发主线。
- CI 当前固定拆成 4 个并行 job（`gdunit`、`repo_and_arch_gates`、`python_lint`、`boot_and_sandbox_smoke`），并与本地总入口共用同一批子脚本。
- `tests/check_gdunit_gate.sh` 与 `tests/check_boot_smoke.sh` 当前固定作为本地与 CI 共用的子入口，不允许出现 CI / 本地分叉脚本。

### README surface 合同与 demo replay smoke

- README / `tests/README.md` 当前只继续承担入口与操作说明，不再镜像 formal 字段清单或长段 contract 正文。
- README 当前继续承担 surface gate 的一部分合同，尤其是代码规模统计与研发入口说明。
- `demo=<profile>` 继续是 CLI/debug 入口，但必须固定自动回归：`tests/check_sandbox_smoke_matrix.sh` 补跑 `legacy` 与 `kashimo` 两个 demo profile，demo replay 摘要上下文固定取 profile 真值。

### BattleSandbox 边界与 SampleBattleFactory 收口

- `BattleSandboxController` 继续保留主入口方法与场景生命周期职责，但不再作为外部可写状态袋：运行态必须下沉到显式 session state，UI 节点引用必须下沉到独立 view refs，测试与 support 层不得再直接读写 `manager / session_id / sample_factory / error_message`。
- `BattleInitializer` 的 `_setup_validator / _phase_service / _state_builder` 继续只做 owner 私有 helper，不升级成 composer service slot；但共享依赖必须通过显式 ports 配置，不再散写 `_sync_*` 赋值。
- `SampleBattleFactory` 允许合并内部 helper 以减少文件数和跳转成本；前提是：公开 facade 方法与 override 入口保持稳定，任何 owner 文件都不能突破 architecture gate 行数限制，引用到的 helper 路径必须同轮完成迁移。

### Formal Character Validator 拆分阈值

- 单个 formal character validator 文件超过 400 行时，应按验证维度（unit / skill / effect / passive / field）拆分为子 validator。
- 拆分后各子 validator 由主 validator 组合调用，保持对外接口不变。

### SampleBattleFactory formal failure 容忍边界（2026-04-26）

- `SampleBattleFactory.available_matchups_result()` 必须在 formal matchup catalog 加载失败时直接 fail-fast；这是 sandbox bootstrap 的角色选择入口，不允许静默吞错。`build_formal_character_setup_result()` / `formal_character_ids_result()` / `formal_unit_definition_ids_result()` / `content_snapshot_paths_result()` 同样 fail-fast。
- 反过来，`build_sample_setup_result()`、`build_demo_replay_input_for_profile_result("legacy")`、以及 `content_snapshot_paths_for_setup_result(baseline_setup)` 三条 baseline-only 入口固定容忍 formal runtime registry / formal matchup catalog 的加载失败。该容忍由 `test/suites/sample_battle_factory_contract_suite.gd` 的 `_test_baseline_setup_ignores_formal_runtime_registry_failure / _test_legacy_demo_ignores_formal_runtime_registry_failure / _test_baseline_flow_ignores_formal_matchup_catalog_failure / _test_baseline_setup_snapshot_ignores_formal_runtime_registry_failure` 锁定。
- 容忍边界的目的：baseline-only 自动化测试不被 formal manifest 状态拖累；formal API 的 fail-fast 仍由专门的 expectation 锁定。新增 SampleBattleFactory 公开方法时必须显式落入"baseline-only 容忍"或"覆盖 formal 必须 fail-fast"两类之一，不允许出现第三种"formal 失败时静默退化"的行为。
- Sandbox `_character_options` 在 view 层加载 `FormalCharacterManifest.build_character_entries_result()` 时也必须 fail-fast：失败时把 manifest 错误透传到 `state.error_message`，让选择页直接展示具体错误而非"当前没有可选角色"。

### SampleBattleFactory 复杂度边界

- `SampleBattleFactory` 内部 helper 文件当前为 10 个（matchup_contracts 61 行、base_snapshot_paths_service 78 行等），各自职责明确，暂不强制合并。后续如新增 matchup 类型导致 helper 继续膨胀，应引入 factory strategy 模式按 matchup 类型分发，而非继续堆叠 helper。软上限调整为 10 个。

### test/ 与 tests/ 目录约定

- `test/` 存放运行时测试套件（gdUnit suite 文件、support bridge 等，由 Godot 直接加载）。
- `tests/` 存放外部验证脚本（gate 脚本、shell runner、Python 检查器等，不由 Godot 加载）。
- 文档中引用时必须准确使用对应目录名，不得混用。

### has_method 鸭子类型使用约定

- `src/` 当前有 20+ 处 `has_method` 调用，多数为防御性 null + capability check（`dispose`、`error_state`、`validate`、`resolve_power_bonus`、`resolve_missing_dependency`、`_compose_post_wire` 等）。
- 短期保留：这些 duck type 检查是合理的防御性模式，强制替换为接口/基类约束改动面大且无直接收益。
- 长期方向：新增核心 service 间交互优先使用显式 port 声明（`COMPOSE_DEPS`），避免新增 `has_method` 调用。现有调用在涉及文件重构时顺带收窄。
- 已确认可直接收窄的低垂果实（对端是定式强类型、方法是契约成员）应一次去掉鸭子检查。2026-04-26 已收窄 `sandbox_session_bootstrap_service.dispose_manager` 中的 `state.manager.has_method("dispose")` / `state.sample_factory.has_method("dispose")` 与 `sandbox_view_presenter._current_player_ui_mode` 中的 `controller.has_method("player_ui_mode")` 三处。

### -> Variant 收窄方向

- 本轮已为 22 个无返回类型标注的函数补充 `-> Variant`。
- 热路径（`BattleState.get_unit` / `get_side`、`SideState.find_unit` 等）因 null 返回仍需保持 `-> Variant`。
- 后续新增函数优先使用具体返回类型；返回 null 场景用 `-> Variant` 并在文档注释中说明。

## 6. Archive 读取顺序

- 查当前仍生效的结构与交付规则：先看本文件，再看 `docs/design/`
- 查 2026-04-10 到 2026-04-18 这轮完整背景：看 `docs/records/archive/decisions_2026-04-10_to_2026-04-18_refactor_wave.md`
- 查更早 repair wave 或 v0.6.3/v0.6.4 背景：看对应历史 archive
