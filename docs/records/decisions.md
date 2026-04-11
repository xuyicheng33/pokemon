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

## 0E. BattleResultService owner 继续瘦身为稳定终局 facade（2026-04-07）

- `BattleResultService` owner 现在只保留 invalid termination/runtime fault 落盘、稳定公开入口与 helper 装配。
- `system` / `battle_end` chain context 构造固定下沉到 `src/battle_core/turn/battle_result_service_chain_builder.gd`。
- 初始化胜利、标准胜利、投降与 turn limit 的结果判定固定下沉到 `src/battle_core/turn/battle_result_service_outcome_resolver.gd`。
- 对外方法名与 turn 子域调用面保持不变；`BattleInitializer`、`TurnLoopController`、`TurnResolutionService`、`TurnFieldLifecycleService` 继续只依赖 `BattleResultService` 稳定入口。
- 这么定的原因：
  - 前四批收口后，turn 子域里最容易继续长回屎山的热点已经从 sample/legality 转到了终局判定 owner
  - `BattleResultService` 之前同时承担 invalid/runtime fault 落盘、chain 构造、胜负/投降/turn limit 判定与 battle end 日志，继续扩 turn 规则时最容易反复改同一文件
  - 先把 chain builder 与 outcome resolver 固化成内部协作者，可以在不改外部语义的前提下继续压缩 turn 子域返工面，并给后续是否重构 `battle_core_manager` 留出更清晰的评估边界

## 0F. BattleCoreManager owner 继续瘦身为稳定 facade（2026-04-07）

- `BattleCoreManager` owner 现在只保留依赖守卫、`build_command / run_replay`、session 计数、端口同步与 dispose。
- session 建立与 replay 容器编排继续固定留在 `src/battle_core/facades/battle_core_manager_container_service.gd`。
- `create_session / get_legal_actions / run_turn / get_public_snapshot / get_event_log_snapshot / close_session` 这类 session 级 facade 调度固定下沉到 `src/battle_core/facades/battle_core_manager_session_service.gd`。
- 这么定的原因：
  - `BattleCoreManager` 是唯一稳定 facade，不能为了降行数去拆出新的公开边界，但 owner 里继续堆 session 调度会让 facade 本体越来越像混合大文件
  - 真正重复增长的是 session 查找、runtime guard、公开快照/事件日志回包这类 session 级样板，而不是 `build_command` 或 replay 入口本身
  - 先把 session 调度固化成内部协作者，可以在不改 facade contract 的前提下压缩 owner 体积，并把后续 manager 热点评估收敛到更清楚的 container/session 两条内部边界

## 0G. formal shared contract helper 固定按资源族拆分（2026-04-07）

- `ContentSnapshotFormalCharacterContractHelper` owner 现在只保留稳定 facade 与资源族协作者转发。
- `unit / skill / passive_skill` 的共享断言固定下沉到 `src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_unit_skill_contract_helper.gd`。
- `effect / field / payload shape` 的共享断言固定下沉到 `src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_effect_field_contract_helper.gd`。
- 这么定的原因：
  - 这个 shared helper 是 formal validator 扩角链路里的公共模板，继续把所有资源族断言堆在同一文件里，会让第 5 个角色开始后的共性回归面继续集中膨胀
  - 当前角色级 validator 的调用方式天然就是按资源族在用这批断言，顺着资源族拆分，能在不改调用口的前提下压低 shared helper 体积
  - 先把 owner 收成薄 facade，后续即便再补新的 formal 资源断言，也更容易落到对应资源族 helper，而不是重新长回同一坨 shared 文件

## 0H. formal snapshot support helper 固定拆出 descriptor helper（2026-04-07）

- `FormalCharacterSnapshotTestHelper` owner 现在只保留 content index 装配、断言执行与 facade 转发。
- descriptor 字段顺序、descriptor 检查构造与 actual/expected 归一化固定下沉到 `tests/support/formal_character_snapshot_descriptor_helper.gd`。
- 这么定的原因：
  - snapshot suite 会随着 formal 角色与基线字段继续增长，字段顺序和 descriptor 构造样板如果继续和执行逻辑缠在同一个 helper 里，测试 support 很快又会回到高体量预警区
  - 这层 support helper 的公共调用口已经稳定，最适合做“owner 薄化 + descriptor 协作者”的内部拆分，而不是让各角色 snapshot suite 自己复制字段顺序与归一化逻辑
  - 先把 descriptor 逻辑单独收口，后续不论是继续扩角色还是调整 baseline 字段，都能把改动集中在 support 内部，而不是把 snapshot suite 和 support 一起拉长

## 0I. formal repo consistency gate 固定拆成主入口 + 子校验模块（2026-04-07）

- `repo_consistency_formal_character_gate.py` owner 现在只保留合同装载、主线串联与 `validate_pair_catalog(...)` 收尾。
- manifest cutover、legacy 路径与 formal setup 入口校验固定下沉到 `tests/gates/repo_consistency_formal_character_gate_cutover.py`。
- formal character entry、suite reachability 与 regression anchor 校验固定下沉到 `tests/gates/repo_consistency_formal_character_gate_characters.py`。
- 这么定的原因：
  - 这份 gate 是扩角前 formal 交付链的最后一层兜底，继续把 cutover、entry、pair coverage 全堆在同一文件里，会让后续新增角色字段或测试锚点时回归面继续集中膨胀
  - `tests/check_repo_consistency.sh` 的入口脚本和 gate 完成语义已经稳定，最适合做“主入口不变、内部模块化”的拆法
  - 先把 gate 主线拆成 cutover / character / pair 三段，后续不论是 manifest 合同变化还是 suite/regression 变化，都能在对应子模块里单点演进，不必继续把主入口拉长

## 0J. formal baseline 只认 manifest 正式 ID，并把 shared baseline 热点纳入 gate（2026-04-10）

- `src/shared/formal_character_baselines.gd` 的中心分发表当前固定只认 manifest 正式 ID：
  - `gojo_satoru`
  - `sukuna`
  - `kashimo_hajime`
  - `obito_juubi_jinchuriki`
- baseline 主入口当前固定只保留稳定 facade：
  - `unit_contract()`
  - `regular_skill_contracts()`
  - `ultimate_skill_contract()`
  - `passive_skill_contract()`
  - `field_contracts()`
- `effect_contracts()` 已固定拆到独立 helper；复杂奥义 / 领域合同也已固定拆到独立 helper，避免角色 baseline 再回到 250+ 行热点。
- `tests/check_architecture_constraints.sh` 当前固定把 `src/shared/formal_character_baselines/**` 与 `src/shared/formal_character_baselines.gd` 纳入大文件强校验。
- `tests/gates/repo_consistency_formal_character_gate.py` 当前固定新增两条硬约束：
  - baseline 分发表 key 必须和 manifest `characters[*].character_id` 顺序一致
  - baseline / validator / snapshot suite / support / gate 不允许残留旧短别名 `gojo / kashimo / obito`
- 这么定的原因：
  - 上一轮虽然把角色基础事实收口到了 shared baseline，但中心分发仍停留在短别名口径，扩第 5 个角色时仍会留下“manifest 已是正式 ID、descriptor 调用却还认旧别名”的双真相裂缝
  - baseline 真热点已经转移到 `src/shared/formal_character_baselines/**`，如果 gate 还只盯 `src/battle_core` / `src/composition`，后续最先失控的会是角色合同层，而不是 battle core owner
  - 先把正式 ID 与目录治理一起锁死，后续再做 capability catalog 与 wiring 拆分时，角色交付链的根不会继续漂

## 0K. shared capability catalog 固定成为扩角模板的一部分（2026-04-10）

- 共享能力目录的唯一人工维护配置固定为 `config/formal_character_capability_catalog.json`。
- `config/formal_character_manifest.json.characters[*]` 的 delivery/test 视图当前固定新增 `shared_capability_ids`；无共享能力也必须显式填空数组。
- capability catalog entry 当前固定包含：
  - `capability_id`
  - `rule_doc_paths`
  - `consumer_character_ids`
  - `required_suite_paths`
  - `coverage_needles`
  - `stop_and_specialize_when`
- `tests/gates/repo_consistency_formal_character_gate_capabilities.py` 当前固定执行四类硬校验：
  - manifest 的 `shared_capability_ids` 只能引用 catalog 里已有的 `capability_id`
  - catalog 的 `consumer_character_ids` 必须和 manifest 双向一致
  - catalog 的 `required_suite_paths` 必须全部回挂到角色 manifest 条目
  - 角色内容 / validator / 设计稿 / 调整记录 / wrapper 必须能扫到 capability 的实际使用证据
- 共享能力目录的设计文档固定为 `docs/design/formal_character_capability_catalog.md`；接入清单、角色模板、README 与 tests README 都必须引用同一套口径。
- 这么定的原因：
  - 角色接入链现在最容易继续返工的，不是角色条目有没有写进去，而是共享机制到底是不是“还能继续复用的正式入口”
  - 如果只靠角色稿或 `required_suite_paths` 零散补共享回归，很快又会回到“每扩一角就要到处找补丁点”的老路
  - 把 `shared_capability_ids + capability catalog + gate` 一起钉死后，新增角色时只需要先回答两件事：这是不是现有共享入口；如果是，要不要已经到 `stop_and_specialize_when` 该停的边界

## 0L. battle_core wiring specs 固定改为子域拆分 + 聚合入口（2026-04-10）

- `src/composition/battle_core_wiring_specs.gd` 当前固定只保留聚合职责；真实 wiring spec 固定下沉到 `src/composition/battle_core_wiring_specs/*.gd`。
- wiring spec 当前固定按子域拆分：
  - `commands`
  - `turn`
  - `lifecycle`
  - `passives`
  - `effects_core`
  - `payload_handlers`
  - `actions`
- `BattleCoreComposer` 当前固定继续只认一个聚合入口，但不再直接读取单个超长常量表；统一改从 `BattleCoreWiringSpecs.wiring_specs() / reset_specs()` 取装配事实。
- `tests/gates/architecture_composition_consistency_gate.py` 与 `tests/gates/architecture_wiring_graph_gate.py` 当前固定直接扫描 split wiring 目录，继续硬校验：
  - wiring owner/source 必须都落在 `SERVICE_DESCRIPTORS`
  - owner/dependency 对不得重复
  - runtime wiring 图必须保持 strict DAG
  - composer 必须继续通过聚合入口读取 wiring / reset specs
- 这么定的原因：
  - `battle_core_wiring_specs.gd` 虽然还没超 250 行，但已经明显进入“继续扩 helper 或 service 就会重新变热”的趋势
  - 这份文件承载的是装配事实，不是新抽象；最短路径就是按现有子域把 spec 表拆开，再保留一个稳定聚合入口给 composer 和 gate
  - 先把 wiring 声明结构拉回到可维护状态，后续扩 service 或拆 owner 时，改动就能落在对应子域 spec，而不是重新把所有装配事实堆回一个中心文件

## 0M. `FormalCharacterManifest` 固定改为薄 facade + helper，并纳入体量闸门（2026-04-10）

- `src/shared/formal_character_manifest.gd` 当前固定只保留公开 facade、视图入口与错误投影。
- manifest 文件读取、顶层桶校验与路径归一化固定下沉到 `src/shared/formal_character_manifest/formal_character_manifest_loader.gd`。
- runtime / delivery / pair interaction 视图校验固定下沉到 `src/shared/formal_character_manifest/formal_character_manifest_views.gd`。
- `tests/check_architecture_constraints.sh` 当前固定把 `src/shared/formal_character_manifest/**` 与入口文件一起纳入体量闸门。
- 这么定的原因：
  - `FormalCharacterManifest` 已经成为正式角色接入链新的中心热点；继续把读取、校验和多种视图投影堆在一个入口里，会很快回到旧热点模式
  - 只拆 baseline 目录、不把 manifest 入口纳入同级治理，等于把热点从一处挪到另一处
  - 先把 manifest owner 收回稳定 facade，再把 helper 纳入 size gate，后续扩角色时才不会重新把正式角色交付链堆回一个中心文件

## 0N. payload 与 power bonus 的共享注册事实固定单点收口（2026-04-10）

- payload 的 `payload script -> handler slot -> validator key` 当前固定只维护在 `src/battle_core/content/payload_contract_registry.gd`。
- `ContentPayloadValidator`、`PayloadHandlerRegistry`、`battle_core_wiring_specs_effects_core.gd` 与 payload contract suite 当前统一从这份注册表派生，不再各自手抄 payload 名单。
- `power_bonus_source` 当前固定只维护一份共享注册事实：
  - source 列表
  - 额外 schema 校验
  都统一收口到 `src/battle_core/content/power_bonus_source_registry.gd`。
  - 运行时 bonus 解析继续固定收口到 `src/battle_core/actions/power_bonus_resolver.gd`。
- 这么定的原因：
  - 这轮修补要解决的不是 battle core 主循环失控，而是“新增一个共享扩展点就要改多处中心入口”的返工面
  - payload 与 power bonus 都已经出现“名单、校验、运行时分支各写一份”的漂移风险；继续扩角色时，这类共享入口会先比玩法规则更快失控
  - 先把共享注册事实收成单点后，新增同类扩展时改动就能优先落在注册表和专属实现，而不是继续在 validator、registry、wiring 和测试里同步抄名单

## 1. 文档与活跃记录职责继续分层

- `docs/rules/` 是当前规则权威。
- `docs/design/` 负责架构落点、角色设计、交付模板与运行时模型。
- `docs/records/` 只保留决策、任务入口与归档索引，不再继续承担长篇“现行真相全集”。
- 历史审查若仍保留在根目录，必须显式注明“历史审查，不再作为现行依据”，避免旧口径继续误导扩角判断。

## 2. formal manifest 单真源继续固定

- 正式角色条目的唯一人工维护配置固定为 `config/formal_character_manifest.json`；共享字段合同继续固定在 `config/formal_registry_contracts.json`。
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

- `SampleBattleFactory` 的正式失败路径统一返回 `{ ok, data, error_code, error_message }`；便捷 helper 可以继续直接返回值，但不再承担正式失败语义。
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

## 4. battle 输入合同与 power bonus 边界继续收口（2026-04-11）

- `battle_setup.sides[*].side_id`、`content_snapshot_paths` 与 replay `command_stream` 的共享输入合同，当前统一由 `src/battle_core/contracts/battle_input_contract_helper.gd` 维护。
- `BattleCoreManagerContractHelper`、`ReplayRunnerInputHelper`、`BattleSandboxRunner` 与 `BattleSetupValidator` 只允许复用这份共享 helper，不再各自重复写 side_id 遍历和 replay 输入形状校验。
- 这么定的原因：
  - `fff2e62` 虽然补齐了输入防线，但 battle setup / replay 输入合同当时仍分散在多个入口，后续一旦再改 setup 规则，维护面会重新散开。
  - 这类校验属于共享输入 contract，不该继续同时长在 facade、logging、composition 和 content 各自的局部 helper 里。

- `PowerBonusSourceRegistry` 当前只负责 source 列表和内容侧 schema/合同校验；运行时 bonus 求值固定回到 `src/battle_core/actions/power_bonus_resolver.gd`。
- 这么定的原因：
  - `content` 层的职责是静态声明与内容合同，不该继续承载直接读取 `unit_state.effect_instances` 的运行态逻辑。
  - 保留“注册表负责声明面，resolver 负责运行时分支”这条边界后，新增 source 仍然只会改少数明确接缝，但不会再把运行态求值塞回 `content` 层。

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
