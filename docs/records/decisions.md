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
  - 测试 support：`400..600` 预警、`> 600` 必须拆分
  - 测试文件：`> 1200` 必须拆分
  - Gate py：`800..1200` 预警、`> 1200` 必须拆分
  - 理由：原 `250` 行硬线适合原型期速写，长期工程需要主 owner 与 facade 容纳稳定合同与装配编排。
- 分阶段推进：详见 `docs/records/tasks.md` 当前阶段。

## 0. 正式角色整合修复波次的新固定决定

- `docs/records/` 以后只承担活跃记录、决策入口与 archive 索引，不再继续充当现行规则的机器约束层。
- formal 共享字段定义只保留一份真相：
  - `config/formal_registry_contracts.json`
  - `src/shared/formal_registry_contracts.gd`
- formal pair 覆盖模型继续固定为：
  - 每个无序正式角色对至少 1 条 interaction case
  - 允许同 pair 多 case
- Kashimo / Sukuna 的 manager 黑盒继续视为正式交付面的一部分；后续扩角不得跳过 manager 级黑盒。

## 0V. 2026-04-19 全量质量收口规则（2026-04-19）

- `.gd.uid` 当前固定纳入版本管理：
  - `.gitignore` 不再允许忽略 `*.uid`
  - 有效 `.gd.uid` 必须随同对应 `.gd` 一起提交
  - 孤儿 `.gd.uid` 必须删除，并由 repo consistency gate 直接失败
- GDScript 前导缩进当前固定只允许 tab：
  - `src/`
  - `test/`
  - `tests/`
  - `scenes/`
  - space-only 与 tab/space 混用都直接视为失败
- 测试 support helper 体量 gate 当前固定扩到：
  - `test/**/shared*.gd`
  - `test/**/*_shared.gd`
  - `tests/support/**/*.gd`
  - 这几类文件落在 `220..250` 行输出预警，> `250` 直接失败
- `BattleState` 查询路径当前固定不再保留假缓存语义；`get_side / get_unit / get_unit_by_public_id` 只要求始终返回当前 `sides / team_units` 真值，`rebuild_indexes()` 退回兼容入口，不再承诺性能收益。
- `COMPOSE_DEPS` 当前固定只描述 composer 注入的外部依赖；owner 私有 helper 不再混入这份声明。
- 共享结果式 helper 的适用边界当前扩大到 policy / adapters / facade helper；外层成功/失败结果统一只认 `ok / data / error_code / error_message`。
- 本地报告目录当前固定只认 `reports/gdunit`；其余历史 `reports/gdunit_*` 目录与 `tmp / .tmp` 都视为可清理噪声。

## 0W. 核心类型标注边界固定为“内部强类型，对外合同仍走运行时校验”（2026-04-19）

- `BattleCoreManager` / `BattleCoreManagerContainerService` 这类 facade 公开入口，继续允许非法输入走运行时 envelope 校验并返回正式错误，不把 contract 失败提前变成 GDScript 解析错误。
- `session state / facade service / initializer ports` 这类核心运行态依赖字段，继续优先补成显式具体类型，不回退成大面积 `RefCounted`。
- 测试替身如果要写进这些强类型字段，固定通过继承真实类或 typed stub 适配；`shared_contract_suite` 这类 wiring 契约测试不再用裸 `RefCounted` 穿过类型边界。

## 0R. README surface 合同与 demo replay smoke 固定补回主线（2026-04-18）

- README / `tests/README.md` 当前只继续承担入口与操作说明，不再镜像 formal 字段清单或长段 contract 正文。
- README 当前继续承担 surface gate 的一部分合同，尤其是代码规模统计与研发入口说明。
- `demo=<profile>` 继续是 CLI/debug 入口，但必须固定自动回归：
  - `tests/check_sandbox_smoke_matrix.sh` 补跑 `legacy` 与 `kashimo` 两个 demo profile
  - demo replay 摘要上下文固定取 profile 真值，不再回退到 launch config 默认的 `matchup_id / battle_seed`

## 0S. formal character registry 改为 source descriptor 单源，validator 升级为硬约束（2026-04-18）

- `config/formal_character_sources/` 现在是 formal 角色 registry 的唯一人工维护入口：
  - `00_shared_registry.json` 负责共享 `matchups/capabilities`
  - 每个角色一份 `0N_<character>.json` 负责 runtime + delivery + `content_roots`
- `config/formal_character_manifest.json` 与 `config/formal_character_capability_catalog.json` 继续提交到仓库，但已经退成生成产物，不再手工维护。
- `content_roots` 允许目录与单文件资源混用，导出时统一递归展开成稳定排序的 `required_content_paths`。
- `content_validator_script_path` 现在是 formal 角色 runtime 合同的必填字段，不再写成“按需”。
- formal gate 当前固定校验：
  - source descriptors 可导出
  - 导出结果与 committed manifest/catalog 完全一致
  - 同一轮里不允许 source 与产物漂移
- 人工同步 committed artifacts 的唯一入口固定为：
  - `bash tests/sync_formal_registry.sh`

## 0Q. 正式角色 manager smoke/blackbox 与 formal registry 厚 suite 固定模板化（2026-04-18）

- `tests/support/formal_character_manager_smoke_helper.gd` 当前固定承担 shared runner：
  - `run_named_case / run_case`
  - `build_case_state`
  - `get_legal_actions_result / get_public_snapshot_result / get_event_log_result`
  - `build_command_result / run_turn_result / run_turn_sequence_result`
- 四个正式角色的 `manager smoke/blackbox` suite 当前固定写成“case spec + 少量角色断言”，不再各自复制 session / command / close 样板。
- `catalog_factory_suite.gd` 与 `replay_guard_suite.gd` 当前固定不再回到单大文件：
  - `catalog_factory` 拆成 `setup / delivery_alignment / surface`
  - `replay_guard` 拆成 `input / summary / failure`
  - 跨域断言只允许留在 shared support
- formal registry 的 fixture helper 当前默认会补合法 validator 路径；如果坏例不是在测 validator，就不应该先被 validator 缺失抢走失败原因。

## 0O. 组合依赖、turn/init 编排与 sandbox 外围热点继续冻结为新结构（2026-04-18）

- compose 依赖与 reset 元数据继续只认 script 自声明：
  - `COMPOSE_DEPS`
  - `COMPOSE_RESET_FIELDS`
- `BattleCoreComposer`、runtime 缺依赖检查与两条 architecture gate 统一通过 `service_dependency_contract_helper.gd` 读取这份声明，不再恢复 split wiring specs。
- composition 当前固定只分三层：
  - 核心稳定 service slot
  - payload/runtime slot
  - owner 私有 helper 实例
- 单 owner、无独立生命周期、无跨模块复用的 helper，默认只留在 owner 内部，不再继续晋升为 composer service slot。
- 回合编排继续固定为：
  - `turn_selection_resolver.gd`
  - `turn_start_phase_service.gd`
  - `turn_end_phase_service.gd`
  - `turn_field_lifecycle_service.gd`
- `BattleInitializer` 继续只保留顺序调度；setup 校验、side/unit 构造与初始化阶段子流程分别下沉到独立 owner。
- `SandboxSessionCoordinator` 继续只保留 facade；sandbox 会话热点固定拆成 `bootstrap / demo / command` 三个 owner。

## 0T. 外层结果式、回放时间线与 Sandbox 回放浏览固定收口（2026-04-18）

- `BattleCoreManager` 的外部 envelope 继续固定为：
  - `ok`
  - `data`
  - `error_code`
  - `error_message`
- 共享结果式构造与 unwrap 当前统一只认：
  - `src/shared/result_envelope_helper.gd`
- 这轮触及的 adapter / composition / shared formal 访问代码，不再直接散写 `ok/data/error_*` 字典。
- `battle_core/contracts/*` 与 runtime 类契约继续保留；只有序列化边界、gate/export 边界和 manager facade 外层结果式继续使用 `Dictionary`。
- `ReplayOutput` 当前正式新增 `turn_timeline`：
  - 初始化完成后固定记录 `turn_index = 0` 的初始 frame
  - 每个完整 turn 结束后固定追加一个 frame
  - final `public_snapshot` 继续与 timeline 最终 frame 对齐
- `BattleSandbox` 的 `MODE_DEMO_REPLAY` 当前固定进入只读回放浏览态，不再只展示最终局面：
  - 允许浏览上一回合 / 下一回合
  - 固定显示当前 frame 的公开快照与事件片段
  - replay 模式下禁止手动 action 和 policy 推进

## 0U. BattleSandbox 当前主线入口与验证矩阵固定保留（2026-04-13）

- `BattleSandboxController` 继续是当前研发试玩入口；默认路径继续固定为 `gojo_vs_sample + 9101 + manual/policy`。
- `tests/run_with_gate.sh` 继续是唯一总入口，顺序保持：
  - `gdUnit4`
  - `boot smoke`
  - `suite reachability`
  - `architecture constraints`
  - `repo consistency`
  - `sandbox smoke matrix`
- `BattleSandbox`、`run_with_gate` 与 `gdUnit4 + test/` 继续构成当前仓库的主研发主线。
- CI 当前固定拆成 3 个并行 job，并与本地总入口共用同一批子脚本：
  - `gdunit`
  - `repo_and_arch_gates`
  - `boot_and_sandbox_smoke`
- `tests/check_gdunit_gate.sh` 与 `tests/check_boot_smoke.sh` 当前固定作为本地与 CI 共用的子入口，不允许出现 CI / 本地分叉脚本。

## 0Y. formal pair 输入与派生 contract 继续冻结（2026-04-12）

- `2026-04-12` 起，formal pair 输入继续固定挂在 `characters[*]` 的 runtime 条目：
  - `pair_token`
  - `baseline_script_path`
  - `owned_pair_interaction_specs`
- `pair_token` 继续作为 formal pair 身份字段；`baseline_script_path` 继续作为 formal baseline 注册字段；`owned_pair_interaction_specs` 继续是唯一手写 pair interaction 输入。
- manifest 不再恢复顶层 pair bucket；pair 覆盖与 directed case 继续从 manifest 角色条目派生。

## 0Z. BattleSandbox 边界、initializer child ports 与 SampleBattleFactory 收口规则（2026-04-18）

- `BattleSandboxController` 继续保留主入口方法与场景生命周期职责，但不再作为外部可写状态袋：
  - 运行态必须下沉到显式 session state
  - UI 节点引用必须下沉到独立 view refs
  - 测试与 support 层不得再直接读写 `manager / session_id / sample_factory / error_message`
- `BattleInitializer` 的 `_setup_validator / _phase_service / _state_builder` 继续只做 owner 私有 helper，不升级成 composer service slot；但共享依赖必须通过显式 ports 配置，不再散写 `_sync_*` 赋值。
- `SampleBattleFactory` 本轮允许强力合并内部 helper，以减少文件数和跳转成本；前提是：
  - 公开 facade 方法与 override 入口保持稳定
  - 任何 owner 文件都不能突破现有 architecture gate 的行数限制
  - tests、gates、docs 里引用到的 helper 路径必须同轮完成迁移，不留下旧路径针脚

## 1. Archive 读取顺序

- 查当前仍生效的结构与交付规则：先看本文件，再看 `docs/design/`
- 查 2026-04-10 到 2026-04-18 这轮完整背景：看 `docs/records/archive/decisions_2026-04-10_to_2026-04-18_refactor_wave.md`
- 查更早 repair wave 或 v0.6.3/v0.6.4 背景：看对应历史 archive
