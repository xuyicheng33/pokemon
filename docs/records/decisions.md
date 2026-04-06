# 决策记录（活跃）

本文件只保留 2026-04-06 repair wave 后仍会直接约束实现、测试或扩角流程的活规则。

更早且已关闭的完整记录见：

- `docs/records/archive/decisions_pre_2026-04-05_repair_wave.md`
- `docs/records/archive/decisions_pre_v0.6.4.md`
- `docs/records/archive/decisions_pre_v0.6.3.md`

当前生效规则以 `docs/rules/` 为准；本文件只记录仍需要被人和 gate 同时记住的“为什么这样定”。

## 目录锚点

- 职责分层
- formal validator 与 registry
- SampleFactory 快照装配
- damage-segment 过滤
- once-per-battle
- Sukuna 常驻回蓝
- 记录归档规则

## 当前有效决策

### 1. `docs/rules / docs/design / docs/records` 的职责继续分层

- `docs/rules/` 仍是当前生效规则的权威。
- `docs/design/` 负责实现落点、架构形状、角色设计与交付模板。
- `docs/records/` 只保留决策背景、任务入口与归档索引，不再承载会持续膨胀的长篇“现行真相”正文。
- 原因：
  - 扩角前如果继续把活规则、历史讨论与执行流水堆在同一文件里，后续 gate 和人工复查都会越来越不可靠。

### 2. 正式角色 formal validator 固定采用三桶模板，并继续以 config registry 为单一登记源（2026-04-06）

- `config/formal_character_registry.json` 继续作为正式角色交付面的单一登记源。
- entry validator 固定采用三桶模板：
  - `unit_passive_contracts`
  - `skill_effect_contracts`
  - `ultimate_domain_contracts`
- entry validator 只负责 preload 与串联三桶，不再自由追加角色私有编排逻辑。
- runtime formal validator 继续只校验当前 snapshot 实际出现的正式角色。
- 只要角色登记了 `content_validator_script_path`，就必须把 `tests/suites/extension_validation_contract_suite.gd` 与至少一个对应角色的 validator 坏例锚点回挂进 registry。
- 原因：
  - 角色数量继续增长后，如果每个 formal validator 继续自由分桶，结构会先于玩法复杂度失控。
  - config registry、runtime loader、formal gate 必须盯同一份角色交付面，不能再出现第二套 descriptor 真相。

### 3. `SampleBattleFactory.content_snapshot_paths_result()` 改为“顶层样例资源 + formal registry.required_content_paths”显式收口（2026-04-06）

- `SampleBattleFactory.content_snapshot_paths_result()` 不再递归扫描整个 `content/` 树。
- 当前正式口径固定为两段：
  - 基础目录顶层样例资源：`battle_formats / combat_types / units / skills / passive_items / effects / fields / passive_skills / samples`
  - `config/formal_character_registry.json` 显式登记的 `required_content_paths`
- 缺目录、缺资源或 registry 漂移时统一返回结构化错误 `{ ok, data, error_code, error_message }`。
- 旧的 `content_snapshot_paths()` 只保留为内部薄封装，不再承担正式失败语义。
- 当前补充 setup-scoped 入口：`content_snapshot_paths_for_setup_result(battle_setup)` 只为当前对局里实际出现的正式角色补 `required_content_paths`，manager smoke、pair smoke 与 demo replay 统一走这条窄入口。
- 原因：
  - 递归全扫会把“只供引用的 helper 资源”和“尚未正式挂回交付面的角色资源”一起带进快照，容易掩盖接线遗漏。
  - 现阶段更需要显式交付面，而不是“只要丢进 content 子目录就被顺手加载”的宽松行为。
  - 当正式角色继续增加时，默认把整套正式角色内容全带进每个对局，只会让 cache、加载期校验和黑盒 smoke 成本线性放大。

### 4. formal validator 迁到独立子目录，content/ 顶层不再继续堆角色 validator（2026-04-06）

- 正式角色 formal validator 当前统一迁到 `src/battle_core/content/formal_validators/`。
- 固定目录结构为：
  - `shared/`：base、registry loader、共享 helper
  - `gojo/`
  - `sukuna/`
  - `kashimo/`
  - `obito/`
- 不保留旧路径兼容 wrapper；仓库内 preload、registry、gate 与文档统一一次改到新路径。
- 原因：
  - `src/battle_core/content/` 顶层继续混放角色 validator，会让内容 Resource 类型与角色 formal 交付面快速失衡。

### 5. `400+` 行 suite 统一改成“稳定 wrapper + 子 suite”组织（2026-04-06）

- `extension_validation_contract_suite.gd`
- `multihit_skill_runtime_suite.gd`
- `manager_snapshot_public_contract_suite.gd`
- `extension_targeting_accuracy_suite.gd`
- `content_validation_core_suite.gd`
- `kashimo_runtime_suite.gd`

当前统一规则：

- 原 wrapper 文件路径、suite 名与测试名保持稳定。
- 真实断言下沉到 `tests/suites/<wrapper_name_without_.gd>/`。
- `run_all.gd`、registry `required_suite_paths` 与 `required_test_names` 继续锚定 wrapper，不因为拆分漂移。
- suite reachability / formal registry gate 必须按 wrapper 子树递归检查，不再只盯顶层 `tests/suites/*.gd`。
- 原因：
  - 共享 suite 与角色 suite 都已经进入“继续加测试会线性膨胀”的阶段，继续堆在单文件里只会把新增角色的边界回归成本推高。

### 6. `on_receive_action_damage_segment` 继续复用现有 `required_incoming_*` 过滤，不新增角色私有字段（2026-04-06）

- `required_incoming_command_types / required_incoming_combat_type_ids` 不再只服务 `on_receive_action_hit`；当前已正式扩到 `on_receive_action_damage_segment`。
- 本轮不新增新的 effect schema 字段；角色若要限制“只吃敌方 `skill / ultimate` 的逐段直接伤害”，必须复用这组共享过滤字段。
- Obito `阴阳遁` 当前作为主线范例：减伤 rule mod 与叠层监听必须共享同一过滤口径。
- 原因：
  - 逐段触发本来就属于共享战斗 contract；若继续为单角色发明额外字段，会马上把 schema 拉回角色专用分支。

### 7. `once_per_battle` 是共享技能字段，但真正的一次性约束固定由 battle-scoped 使用记录承接（2026-04-06）

- `SkillDefinition.once_per_battle` 当前正式加入共享 schema，默认 `false`。
- 本轮先只给 `kashimo_phantom_beast_amber` 使用。
- 真正的一次性约束固定由 `UnitState.used_once_per_battle_skill_ids` 这类 battle-scoped 内部记录承接。
- 该记录只供合法性与执行链读取，不对 manager public snapshot、外部输入或公开回放 contract 暴露。
- 原因：
  - 只靠 effect / rule_mod 锁“当前活着时别再用一次”不够稳；后续只要出现复活、状态重建或更复杂 replay 装配，就会被误放宽。

### 8. 宿傩动态回蓝正式写成长期规则：`duration_mode = permanent` + 对位变化时 `replace`（2026-04-06）

- `sukuna_refresh_love_regen` 不再把 `duration=999` 当成常驻替身。
- 当前正式语义固定为：
  - `duration_mode = permanent`
  - `mod_kind = mp_regen`
  - `mod_op = add`
  - `on_matchup_changed` 时按同来源组 `stacking=replace` 把旧档位替换成新的长期回蓝值
- 玩家口径仍是“基础 12 + 对位追加”；本轮只修语义与 contract，不改档位表。
- 原因：
  - `999` 属于实现期 magic number，不该继续被 formal contract、设计稿与 gate 误读成真正权威。

### 9. 活跃记录与 repair-wave archive 分离，后续扩角继续沿这个切口维护（2026-04-06）

- `tasks.md / decisions.md` 当前只保留：
  - 当前整合波次
  - 下一角色扩充准备项
  - 仍直接生效的活规则
- 2026-04-05 之前且已关闭的历史条目统一归档到：
  - `docs/records/archive/tasks_pre_2026-04-05_repair_wave.md`
  - `docs/records/archive/decisions_pre_2026-04-05_repair_wave.md`
- docs gate 允许在 active + repair-wave archive 中共同检索旧决策锚点，避免“为了瘦身 active 文件”把历史约束从门禁视野里误删。
- 原因：
  - 当前 active 文件的职责是给下一轮开发和扩角提供可维护的入口，而不是继续充当整段项目史的唯一正文。

### 10. 对外公开 contract 继续只暴露稳定 facade 与 `public_id`

- 外层输入与公开快照继续只使用 `public_id`。
- `BattleCoreManager` 继续是外围唯一稳定 facade。
- 本轮新增的 `once_per_battle` battle-scoped 记录、角色专有 filter 细节与 formal validator 结构都属于核心内部 contract，不外抛到 manager public 面。
- 原因：
  - 扩角前的整合修复要优先消化内部复杂度，而不是把内部修补再扩散成新的外围接口面。

### 11. 正式角色跨配对 smoke 继续作为 registry 必备锚点，当前四角色已补到完整两两组合（2026-04-06）

- `tests/suites/formal_character_pair_smoke_suite.gd` 继续作为正式角色 pair smoke 的统一入口。
- formal registry 当前要求每个正式角色都显式挂上：
  - `tests/suites/formal_character_pair_smoke_suite.gd`
  - 至少一个 `formal_pair_*_manager_smoke_contract` 锚点
- 当前四名正式角色的 pair smoke 已补到完整两两组合，不再保留 Gojo 例外口径。
- 原因：
  - 若只让部分角色通过 pair smoke 进入交付面，后续扩角会把跨角色回归再次打散回专项 case 和记忆型补测。

### 12. `ContentSnapshotCache` 的签名必须继续递归覆盖外部 `.tres/.res` 依赖（2026-04-06）

- cache 签名不只看顶层 snapshot 路径本身，也必须递归覆盖这些资源通过 `ext_resource` 引进来的外部 `.tres/.res` 依赖。
- `content/shared/` 虽然不参与顶层 snapshot 注册，但只要它被正式资源引用，它的文件内容变化也必须触发 cache miss。
- 原因：
  - 否则共享 payload 的调参会出现“文件改了，但同一路径 cache 继续命中旧内容”的脏缓存风险。

### 13. formal validator 对关键 effect 继续同时锁 effect surface 和 payload surface（2026-04-06）

- 对正式角色关键 effect，不再只锁 payload 形状；top-level `display_name / scope / duration_mode / stacking / trigger_names` 这类 effect surface 也必须一并锁死。
- 当前已补进正式坏例的代表路径：
  - Gojo `gojo_domain_action_lock`
  - Sukuna `sukuna_refresh_love_regen`
  - Kashimo `kashimo_thunder_resist`
- 原因：
  - 只锁 payload 不锁 effect surface，会让资源仍然“长得像同一个玩法”，但实际触发点、作用域或生命周期已经漂移。
