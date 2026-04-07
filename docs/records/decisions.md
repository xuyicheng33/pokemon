# 决策记录（活跃）

本文件只保留仍直接约束当前实现、门禁和扩角节奏的活规则；更早的完整背景与执行流水已归档。

历史归档：

- `docs/records/archive/decisions_pre_2026-04-05_repair_wave.md`
- `docs/records/archive/decisions_pre_v0.6.4.md`
- `docs/records/archive/decisions_pre_v0.6.3.md`

当前生效规则以 `docs/rules/` 为准；`docs/design/` 负责结构与交付面；本文件只解释“为什么现在这样定”。

## 1. 文档与活跃记录职责继续分层

- `docs/rules/` 是当前规则权威。
- `docs/design/` 负责架构落点、角色设计、交付模板与运行时模型。
- `docs/records/` 只保留决策、任务入口与归档索引，不再继续承担长篇“现行真相全集”。
- 历史审查若仍保留在根目录，必须显式注明“历史审查，不再作为现行依据”，避免旧口径继续误导扩角判断。

## 2. formal validator 与双表 registry 继续固定

- 正式角色继续维持 runtime / delivery 双表：
  - `config/formal_character_runtime_registry.json` 只承载 runtime 必需字段与可选 `content_validator_script_path`
  - `config/formal_character_delivery_registry.json` 只承载测试、文档、suite 与交付元数据
- entry validator 固定采用三桶模板：
  - `unit_passive_contracts`
  - `skill_effect_contracts`
  - `ultimate_domain_contracts`
- formal validator 继续只校验当前 snapshot 实际出现的正式角色；缺席角色的坏 validator 不得把无关快照一起炸掉。
- delivery registry 的正式必填面现在固定包含 `surface_smoke_skill_id`；它只服务 directed pair surface smoke 的默认黑盒技能选择，不回写 runtime registry。
- 正式角色注册表当前必须登记角色 effect 资源、wrapper 下属 suite 与关键回归测试名；共享 pair surface / interaction 不再逐角色手抄进 `required_test_names`。

## 3. SampleBattleFactory、sandbox demo 与 cache freshness 统一收口

- `SampleBattleFactory` 对外只保留结果式接口；正式失败统一返回 `{ ok, data, error_code, error_message }`，不再保留另一套降级语义。
- 运行时 helper 全部统一进 composition 装配；`SampleBattleFactory`、catalog loader、surface case builder、demo catalog 与 replay builder 各自只承载单一职责。
- `config/formal_matchup_catalog.json` 当前只保留：
  - `matchups`
  - `pair_interaction_cases`
- directed pair surface smoke 不再手写 `pair_surface_cases`；统一由 `matchups + delivery_registry.surface_smoke_skill_id` 自动生成。
- `pair_interaction_cases[*]` 固定必填 `scenario_id / matchup_id / character_ids[2] / battle_seed`，并继续与 scenario registry 做一一对应校验。
- demo replay profile 的单一真相固定为 `config/demo_replay_catalog.json`；`BattleSandboxRunner` 只负责选 profile、初始化 manager、错误投影，再把 replay input 构建委托给 builder。
- `ContentSnapshotCache` 继续采用 composer 级共享 cache + 每次 fresh index；当前 freshness 签名固定覆盖：
  - snapshot 路径列表
  - 顶层资源递归 `.tres/.res` 外部依赖
  - `config/formal_character_runtime_registry.json`
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
  - Wave 1：catalog 硬校验、sandbox demo 边界、content snapshot cache freshness
  - Wave 2：pair surface 自动生成、interaction `battle_seed` 强校验、scenario registry 对齐
  - Wave 3：四角色 manager/runtime 黑盒补洞、活跃记录收口、README / checklist / 历史审查口径修正
- 四角色当前新增的黑盒重点固定为：
  - Gojo：`苍 / 赫 / 茈` 双标记爆发链
  - Sukuna：`灶` on-exit 路径
  - Kashimo：`水中外泄` manager 黑盒路径
  - Obito：`六道十字奉火` 与 `阴阳遁` manager 黑盒路径
- 固定可复查案例作为角色与规则复查入口；角色扩充前优先先看共享 case、pair smoke、pair interaction 和 manager 黑盒是否仍保持全绿。
- 若未来恢复自动选指，必须重新补齐规则、设计文档与接线任务，不得直接回填历史实现。
