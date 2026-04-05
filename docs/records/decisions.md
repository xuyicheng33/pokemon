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

### 2. 正式角色 formal validator 固定采用三桶模板，并继续以 docs registry 为单一登记源（2026-04-06）

- `docs/records/formal_character_registry.json` 继续作为正式角色交付面的单一登记源。
- entry validator 固定采用三桶模板：
  - `unit_passive_contracts`
  - `skill_effect_contracts`
  - `ultimate_domain_contracts`
- entry validator 只负责 preload 与串联三桶，不再自由追加角色私有编排逻辑。
- runtime formal validator 继续只校验当前 snapshot 实际出现的正式角色。
- 原因：
  - 角色数量继续增长后，如果每个 formal validator 继续自由分桶，结构会先于玩法复杂度失控。
  - docs registry、runtime loader、formal gate 必须盯同一份角色交付面，不能再出现第二套 descriptor 真相。

### 3. `on_receive_action_damage_segment` 继续复用现有 `required_incoming_*` 过滤，不新增角色私有字段（2026-04-06）

- `required_incoming_command_types / required_incoming_combat_type_ids` 不再只服务 `on_receive_action_hit`；当前已正式扩到 `on_receive_action_damage_segment`。
- 本轮不新增新的 effect schema 字段；角色若要限制“只吃敌方 `skill / ultimate` 的逐段直接伤害”，必须复用这组共享过滤字段。
- Obito `阴阳遁` 当前作为主线范例：减伤 rule mod 与叠层监听必须共享同一过滤口径。
- 原因：
  - 逐段触发本来就属于共享战斗 contract；若继续为单角色发明额外字段，会马上把 schema 拉回角色专用分支。

### 4. `once_per_battle` 是共享技能字段，但真正的一次性约束固定由 battle-scoped 使用记录承接（2026-04-06）

- `SkillDefinition.once_per_battle` 当前正式加入共享 schema，默认 `false`。
- 本轮先只给 `kashimo_phantom_beast_amber` 使用。
- 真正的一次性约束固定由 `UnitState.used_once_per_battle_skill_ids` 这类 battle-scoped 内部记录承接。
- 该记录只供合法性与执行链读取，不对 manager public snapshot、外部输入或公开回放 contract 暴露。
- 原因：
  - 只靠 effect / rule_mod 锁“当前活着时别再用一次”不够稳；后续只要出现复活、状态重建或更复杂 replay 装配，就会被误放宽。

### 5. 宿傩动态回蓝正式写成长期规则：`duration_mode = permanent` + 对位变化时 `replace`（2026-04-06）

- `sukuna_refresh_love_regen` 不再把 `duration=999` 当成常驻替身。
- 当前正式语义固定为：
  - `duration_mode = permanent`
  - `mod_kind = mp_regen`
  - `mod_op = add`
  - `on_matchup_changed` 时按同来源组 `stacking=replace` 把旧档位替换成新的长期回蓝值
- 玩家口径仍是“基础 12 + 对位追加”；本轮只修语义与 contract，不改档位表。
- 原因：
  - `999` 属于实现期 magic number，不该继续被 formal contract、设计稿与 gate 误读成真正权威。

### 6. 活跃记录与 repair-wave archive 分离，后续扩角继续沿这个切口维护（2026-04-06）

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

### 7. 对外公开 contract 继续只暴露稳定 facade 与 `public_id`

- 外层输入与公开快照继续只使用 `public_id`。
- `BattleCoreManager` 继续是外围唯一稳定 facade。
- 本轮新增的 `once_per_battle` battle-scoped 记录、角色专有 filter 细节与 formal validator 结构都属于核心内部 contract，不外抛到 manager public 面。
- 原因：
  - 扩角前的整合修复要优先消化内部复杂度，而不是把内部修补再扩散成新的外围接口面。
