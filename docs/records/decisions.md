# 决策记录（活跃）

本文件只保留仍直接约束当前实现、门禁和扩角节奏的活规则；更早的完整背景与执行流水已归档。

历史归档：

- `docs/records/archive/decisions_pre_2026-04-05_repair_wave.md`
- `docs/records/archive/decisions_pre_v0.6.4.md`
- `docs/records/archive/decisions_pre_v0.6.3.md`

当前生效规则以 `docs/rules/` 为准；`docs/design/` 负责结构与交付面；本文件只解释“为什么现在这样定”。

## 0. 正式角色整合修复波次的新固定决定

- `docs/records/` 以后只承担记录、决策入口与归档索引，不再继续承担现行规则机器约束。
- formal 共享字段定义只保留一份真相：
  - `config/formal_registry_contracts.json`
  - `src/shared/formal_registry_contracts.gd`
- `SampleBattleFactory` 继续保留现有结果式公开 API，但内部固定拆成：
  - baseline flow：只服务 `sample_default`、`passive_item_vs_sample` 与 legacy/sample demo
  - formal flow：只服务 formal setup、formal pair smoke、formal pair interaction、formal demo
- demo 默认 profile 的单一真相固定为 `kashimo`，并且只能从 `config/demo_replay_catalog.json` 读取。
- pair interaction 覆盖模型固定改为：
  - 每个无序正式角色对至少 1 条 interaction case
  - 允许同 pair 多 case
  - 当前四角色必须保留 6 组关键 pair 的双向 directional case
- Kashimo / Sukuna 的 manager 黑盒当前视为正式交付面的一部分；后续角色扩充不得再跳过 manager 级黑盒。

## 0A. manifest 运行时视图与交付视图正式拆开（2026-04-07）

- `config/formal_registry_contracts.json` 当前固定拆成：
  - `manifest_character_runtime`
  - `manifest_character_delivery`
  - `pair_interaction_case`
- `FormalCharacterManifest.load_manifest_result()` 与 runtime loader 现在只强校验 runtime 视图；delivery/test 字段漂移不得再拖死 runtime loader。
- delivery loader、repo consistency gate 与交付文档继续强校验 delivery/test 视图，保证正式交付面没有降级。
- `pair_interaction_cases[*]` 的正式合同补记 `test_name` 必填，避免文档继续落后于 catalog loader 与 gate。
- 这么定的原因：
  - 扩角前当前最容易反复返工的不是 battle core 主循环，而是 formal 角色交付链
  - runtime 被 `suite_path / design_doc / required_test_names` 这类 delivery 字段绑住，会把“文档漂移”升级成“运行时阻塞”
  - 单真源仍保留在同一个 manifest 上，但消费视图必须拆开，否则 loader 边界名义上分层、实际上仍耦合

## 0B. formal 角色基础事实收口到共享 baseline descriptor（2026-04-07）

- `src/shared/formal_character_baselines.gd` 与 `src/shared/formal_character_baselines/*.gd` 现在作为四正式角色基础事实的共享 descriptor 层。
- unit、skill、passive、部分 effect / field 的基础字段，snapshot suite 与 formal validator 必须优先复用这层 descriptor，不再两边各写一套字面量。
- payload shape、segment 细节、运行时链路这类“基础字段之外”的断言，继续留在各角色专属 validator / suite helper 里，不强行抽成一张大表。
- 这么定的原因：
  - 这轮反复返工里，最容易漂移的是“角色基础事实”而不是 payload 细节
  - snapshot suite 与 validator 之前双写同一套字段，任何一次数值或 id 微调都要改两到三处
  - 先把基础事实抽成共享 descriptor，可以明显降低扩第 5 个角色前的维护面，同时不把复杂 payload helper 过度抽象成新的屎山

## 0C. SampleBattleFactory owner 继续瘦身为稳定 facade（2026-04-07）

- `SampleBattleFactory` owner 现在只保留 helper 装配、稳定 facade 与错误状态投影。
- baseline/formal setup 与 matchup 组装固定下沉到 `src/composition/sample_battle_factory_setup_access.gd`。
- manifest/demo override 广播固定下沉到 `src/composition/sample_battle_factory_override_router.gd`。
- `SampleBattleFactoryDemoInputBuilder` 不再反向持有 owner 并回调 `build_setup_by_matchup_id_result()`；它现在直接依赖 setup access。
- 这么定的原因：
  - 第 3 批的真实热点不是功能缺失，而是 owner 继续同时承担装配、override 广播、setup/matchup facade 与 demo helper 反向回调入口
  - demo builder 直接回调 owner，会让 helper 边界继续虚化，后面再加 demo profile 或 baseline/formal 分支时又会长回去
  - 先把 owner 缩回“稳定 facade + 错误投影”边界，后续扩第 5 个角色时，新增 matchup / demo / manifest 逻辑才更容易落到已有 helper，而不是继续堆回大文件

## 0D. LegalActionService owner 继续瘦身为稳定合法性 facade（2026-04-07）

- `LegalActionService` owner 现在只保留运行态上下文校验、结果汇总、`wait/resource_forced_default` 收尾与错误状态投影。
- `rule_mod_service / domain_legality_service` 的依赖读取与 structured failure 投影固定下沉到 `src/battle_core/commands/legal_action_service_rule_gate.gd`。
- 常规技能与奥义候选收集固定下沉到 `src/battle_core/commands/legal_action_service_cast_option_collector.gd`。
- 换人候选收集固定下沉到 `src/battle_core/commands/legal_action_service_switch_option_collector.gd`。
- 这么定的原因：
  - 继续扩角色或扩更多 rule mod 时，最容易膨胀的不是 facade 接口，而是 `LegalActionService` 内部三段职责一起增长
  - 如果 helper 继续反向读取 owner 私有状态，文件虽然分开了，边界其实还是假拆分；后面再补规则很快又会长回另一坨屎山
  - 先把依赖门、cast collector、switch collector 变成稳定内部协作者，可以明显降低继续扩角时对 `get_legal_actions()` 主入口的反复返工

## 1. 文档与活跃记录职责继续分层

- `docs/rules/` 是当前规则权威。
- `docs/design/` 负责架构落点、角色设计、交付模板与运行时模型。
- `docs/records/` 只保留决策、任务入口与归档索引，不再继续承担长篇“现行真相全集”。
- 历史审查若仍保留在根目录，必须显式注明“历史审查，不再作为现行依据”，避免旧口径继续误导扩角判断。

## 2. formal manifest 单真源继续固定

- 正式角色元数据的唯一人工维护配置固定为 `config/formal_character_manifest.json`。
- manifest 顶层固定三桶：
  - `characters`
  - `matchups`
  - `pair_interaction_cases`
- `characters[*]` 同时收口 runtime 必需字段、可选 `content_validator_script_path`、测试/文档/suite 元数据与回归锚点。
- entry validator 固定采用三桶模板：
  - `unit_passive_contracts`
  - `skill_effect_contracts`
  - `ultimate_domain_contracts`
- formal validator 继续只校验当前 snapshot 实际出现的正式角色；缺席角色的坏 validator 不得把无关快照一起炸掉。
- `surface_smoke_skill_id` 固定挂在 `characters[*]`，只服务 directed pair surface smoke 的默认黑盒技能选择。
- 运行时、测试、gate 与文档都只允许从 manifest domain model 派生各自视图；共享 pair surface / interaction 不再逐角色手抄进 `required_test_names`。

## 3. SampleBattleFactory、sandbox demo 与 cache freshness 统一收口

- `SampleBattleFactory` 对外只保留结果式接口；正式失败统一返回 `{ ok, data, error_code, error_message }`，不再保留另一套降级语义。
- 运行时 helper 全部统一进 composition 装配；`SampleBattleFactory`、catalog loader、surface case builder、demo catalog 与 replay builder 各自只承载单一职责。
- `SampleBattleFactory` owner 现在只保留稳定 facade、helper 装配与错误状态投影；manifest/catalog/demo override 广播固定下沉到 `src/composition/sample_battle_factory_override_router.gd`，baseline/formal setup 组装固定下沉到 `src/composition/sample_battle_factory_setup_access.gd`，snapshot 目录扫描固定下沉到 `src/composition/sample_battle_factory_snapshot_dir_collector.gd`。
- directed pair surface smoke 不再手写 `pair_surface_cases`；统一由 `matchups + characters[*].surface_smoke_skill_id` 自动生成。
- `pair_interaction_cases[*]` 固定必填 `scenario_id / matchup_id / character_ids[2] / battle_seed`，并继续与 scenario registry 做一一对应校验。
- demo replay profile 的单一真相固定为 `config/demo_replay_catalog.json`；`BattleSandboxRunner` 只负责选 profile、初始化 manager、错误投影，再把 replay input 构建委托给 builder。
- `ContentSnapshotCache` 继续采用 composer 级共享 cache + 每次 fresh index；当前 freshness 签名固定覆盖：
  - snapshot 路径列表
  - 顶层资源递归 `.tres/.res` 外部依赖
  - `config/formal_character_manifest.json`
  - `src/battle_core/content/**/*.gd`
  - `src/battle_core/content/formal_validators/**/*.gd`

## 4. 共享 runtime contract 继续只留一份真相

- `BattleCoreManager` 公开 contract 统一为严格 envelope。
- 外层输入与公开快照继续只使用 `public_id`。
- 跨模块用户可见错误读取统一走 `error_state()` / `invalid_battle_code()`，不再继续回退到脆弱的散落字符串通道。
- `on_receive_action_damage_segment` 继续复用现有 `required_incoming_*` 过滤，不新增角色私有 schema。
- `once_per_battle` 继续作为共享技能字段，但真正约束固定由 battle-scoped 使用记录承接。
- Sukuna 的对位回蓝正式固定为 `duration_mode = permanent`，并在对位变化时走 replace 语义。
- 宿傩“灶”正式写死为 3 层硬上限，满层后忽略新层。
- effect dedupe key 必须包含 effect_instance_id；合法重复只能通过显式扩展位区分，不能靠污染 effect/source identity 逃过共享防抖。
- field_break / field_expire 链上创建的 successor field 必须保留。
- Runtime wiring 图重新收口为严格 DAG；任何新增 helper / facade / service 都不得回到隐式环依赖。
- suite 可达性闸门继续作为回归可信度底线；wrapper 可以稳定，断言本体可以拆分，但 `tests/run_all.gd` 可达链不能断。

## 5. 扩第 5 个正式角色前的冻结条件

- 本轮“三波整合”已经把扩角前必须先收口的硬问题压平：
  - Wave 1：manifest 单真源、sandbox demo 边界、content snapshot cache freshness
  - Wave 2：pair surface 自动生成、interaction `battle_seed` 强校验、scenario registry 对齐
  - Wave 3：四角色 manager/runtime 黑盒补洞、活跃记录收口、README / checklist / 历史审查口径修正
- 四角色当前新增的黑盒重点固定为：
  - Gojo：`苍 / 赫 / 茈` 双标记爆发链
  - Sukuna：`灶` on-exit 路径
  - Kashimo：`水中外泄` manager 黑盒路径
  - Obito：`六道十字奉火` 与 `阴阳遁` manager 黑盒路径
- 固定可复查案例作为角色与规则复查入口；角色扩充前优先先看共享 case、pair smoke、pair interaction 和 manager 黑盒是否仍保持全绿。
- 若未来恢复自动选指，必须重新补齐规则、设计文档与接线任务，不得直接回填历史实现。
