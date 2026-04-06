# 五条悟（Gojo Satoru）设计方案（审计收口版 v4.2）
<!-- anchor:gojo.design.success-lock-via-on_success_effect_ids -->
<!-- anchor:gojo.design.failed-clash-no-field-buff-lock -->
<!-- anchor:gojo.design.shared-clash-rules-outsourced -->

## 0. 审计后冻结结论（2026-03-29）

| 项目 | 结论 |
|------|------|
| 茈 | 保留“苍+赫双标记”条件爆发，**不做自伤** |
| 无下限 | 改为“敌方技能或奥义攻击五条悟时，若该次不是必中，则命中率 -10” |
| 奥义点 | `required=3 / cap=3 / regular_skill_cast +1` |
| 苍 / 赫速度变化 | 保留当前简化能力阶段制：命中后分别 `speed +1 / speed -1`，阶段范围继续是 `-2..+2`，离场清空，不改成 3 回合 buff / debuff |
| 无量空处锁人条件 | 只有领域**成功立住**时，才通过 `on_success_effect_ids -> field_apply_success` 施加 `gojo_domain_action_lock` |
| 领域增幅归属 | `sp_attack +1` 改为 field 绑定效果；成功立场时生效，领域自然结束/提前打断时移除，对拼失败时不成立 |
| 领域后摇 | **删除**（不再追加封印/回滚） |
| 当前状态 | 资源、validator、suite、manager smoke 已全部接线；本轮继续做扩角前整备收口 |
| 苍/赫标记归属 | 标记挂在**目标**身上；换人清除只发生在**标记持有者**离场时 |
| 苍/赫标记消耗语义 | 茈现在要求目标同时持有双标记，且两枚标记都必须由**当前这名五条悟本人**施加 |
| 共享能力引用 | `required_target_effects`、`required_target_same_owner`、`incoming_accuracy` 全部回收到公共规则文档，本稿只写五条悟差异 |
| 明确不做 | `effects_pre_damage_ids`、`on_before_damage`、`damage_override`、`action_tags`、`last_dealt_damage`、反噬链路 |

---

## 0.1 角色稿范围

- 本稿按 `docs/design/formal_character_design_template.md` 收口，只保留五条悟自己的资源定义、角色机制、验收矩阵与平衡备注。
- 共享引擎规则统一引用：
  - 生命周期与换人保留：`docs/rules/04_status_switch_and_lifecycle.md`
  - effect / rule_mod schema：`docs/rules/06_effect_schema_and_extension.md`
  - 运行时字段：`docs/design/battle_runtime_model.md`
  - 领域公共模板：`docs/design/domain_field_template.md`

## 1. 角色基础属性

### 1.1 角色定位

- 面向玩家：五条悟是高速压制型术师，靠双标记、稳定命中干扰与领域成功收益拉开节奏。
- 面向实现：五条悟当前只依赖共享主线能力，不再额外携带角色专属 damage override / pre-damage 分支。

### 1.2 UnitDefinition

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `gojo_satoru` | |
| display_name | `五条悟` | |
| combat_type_ids | `["space", "psychic"]` | 空间 + 超能力 |
| base_hp | **124** | 略高于旧稿，补一点稳定性 |
| base_attack | **56** | 非体术主攻 |
| base_defense | **60** | 由旧稿上调，避免过脆 |
| base_sp_attack | **88** | 术式主输出 |
| base_sp_defense | **68** | 中等抗性 |
| base_speed | **86** | 高速定位 |
| BST | **482** | 低于宿傩（486） |

### 1.3 MP 系统

| 字段 | 值 | 说明 |
|------|-----|------|
| max_mp | **100** | |
| init_mp | **50** | 首回合可规划一轮爆发，但不再过宽 |
| regen_per_turn | **14** | 从旧稿 16 下调，压缩连续压制 |

补充语义：

- 按当前 main 的固定回合时序，`turn_start` MP 回复发生在第 1 回合选指前；因此五条悟首个可操作回合的实战可用 MP 是 `64`，不是 `50`。

### 1.4 技能组与赛前装配

**内容层（UnitDefinition）**

- 默认配招（`skill_ids`，3 个）：`gojo_ao`、`gojo_aka`、`gojo_murasaki`
- 奥义（`ultimate_skill_id`）：`gojo_unlimited_void`
- 候选技能池（`candidate_skill_ids`，4 个）：`gojo_ao`、`gojo_aka`、`gojo_murasaki`、`gojo_reverse_ritual`

**赛前层（SideSetup）**

- 本场装配通过 `SideSetup.regular_skill_loadout_overrides` 决定（该字段属于 `SideSetup`，不属于 `UnitDefinition`）。
- 当 `candidate_skill_ids` 非空时，允许赛前从候选池选 3 个写入运行时配招。

### 1.5 被动

| 类型 | 值 |
|------|-----|
| passive_skill_id | `gojo_mugen` |
| passive_item_id | `` |

---

## 2. 技能详细设计

> 领域公共模板见 `docs/design/domain_field_template.md`。本稿只写五条悟在该模板下的角色差异。

### 2.1 苍（Ao）

| 字段 | 值 |
|------|-----|
| id | `gojo_ao` |
| display_name | `苍` |
| damage_kind | `special` |
| power | **44** |
| accuracy | **95** |
| mp_cost | **14** |
| priority | **0** |
| combat_type_id | `space` |
| targeting | `enemy_active_slot` |
| effects_on_cast_ids | `[]` |
| effects_on_hit_ids | `["gojo_ao_speed_up", "gojo_ao_mark_apply"]` |
| effects_on_miss_ids | `[]` |
| effects_on_kill_ids | `[]` |

命中后效果：

- `gojo_ao_speed_up`：`scope=self`，`stat_mod(speed, +1)`
- `gojo_ao_mark_apply`：`scope=target`，`apply_effect(gojo_ao_mark)`
- 这是**速度能力阶段 +1**，不是“持续 3 回合的加速 buff”；当前项目的简化阶段制范围固定为 `-2..+2`，单位离场时会统一清空阶段变化。

### 2.2 赫（Aka）

| 字段 | 值 |
|------|-----|
| id | `gojo_aka` |
| display_name | `赫` |
| damage_kind | `special` |
| power | **44** |
| accuracy | **95** |
| mp_cost | **14** |
| priority | **0** |
| combat_type_id | `psychic` |
| targeting | `enemy_active_slot` |
| effects_on_cast_ids | `[]` |
| effects_on_hit_ids | `["gojo_aka_slow_down", "gojo_aka_mark_apply"]` |
| effects_on_miss_ids | `[]` |
| effects_on_kill_ids | `[]` |

命中后效果：

- `gojo_aka_slow_down`：`scope=target`，`stat_mod(speed, -1)`
- `gojo_aka_mark_apply`：`scope=target`，`apply_effect(gojo_aka_mark)`
- 这是**速度能力阶段 -1**，不是“持续 3 回合的减速 debuff”；阶段范围同样固定为 `-2..+2`，离场清空。

顺序约束：

- 苍 / 赫的两个 `effects_on_hit_ids` 当前不依赖声明顺序；在现有效果队列模型下，同批次同来源 effect 若排序键完全一致，默认会进入随机打平。
- 因此本设计不允许“先加速后上标记”或“先减速后上标记”这种先后差异影响玩法正确性；若未来要引入跨 effect 先后依赖，必须显式拉开 `priority`。

### 2.3 苍 / 赫标记 Effect 明细

`gojo_ao_mark_apply` / `gojo_aka_mark_apply`（施加标记）：

- EffectDefinition：`scope=target`, `duration_mode=permanent`, `decrement_on=""`, `stacking=none`, `trigger_names=["on_hit"]`
- payload：`apply_effect(gojo_ao_mark)` 或 `apply_effect(gojo_aka_mark)`

`gojo_ao_mark` / `gojo_aka_mark`（纯标记本体）：

- EffectDefinition：`scope=self`, `duration_mode=turns`, `duration=3`, `decrement_on=turn_end`, `stacking=refresh`, `trigger_names=[]`, `payloads=[]`, `persists_on_switch=false`
- 说明：纯标记 effect 无 payload，不直接产生数值结算；仅用于条件判定。
- owner 语义：标记实例挂在**目标本人**身上，不挂在五条悟身上。
- 换人语义：`persists_on_switch=false` 代表“**标记持有者**离场会清标记”；若五条悟自己离场，目标身上的标记不会因此自动消失。
- 当前正式玩法语义：只有目标身上同时存在 `gojo_ao_mark + gojo_aka_mark`，且这两枚标记的 `source_owner_id` 都等于当前这名五条悟本人时，`gojo_murasaki` 才能触发追加段。
- 时间语义：`duration=3 + decrement_on=turn_end` 按当前引擎表示“从施加当回合开始，连续经过 3 次 `turn_end` 节点后到期”。例如第 1 回合中途施加，则会在第 1/2/3 回合的 `turn_end` 各扣 1 次，并在第 3 次后移除。
- 这里的“持续 3 次 `turn_end`”只属于**标记**；苍 / 赫本身的速度变化不是定时效果，而是能力阶段变化。

### 2.4 茈（Murasaki）—— 条件追加爆发（无自伤）

| 字段 | 值 |
|------|-----|
| id | `gojo_murasaki` |
| display_name | `茈` |
| damage_kind | `special` |
| power | **64** |
| accuracy | **90** |
| mp_cost | **24** |
| priority | **-1** |
| combat_type_id | `space` |
| targeting | `enemy_active_slot` |
| effects_on_cast_ids | `[]` |
| effects_on_hit_ids | `["gojo_murasaki_conditional_burst"]` |
| effects_on_miss_ids | `[]` |
| effects_on_kill_ids | `[]` |

`gojo_murasaki_conditional_burst`（单 effect 完成条件爆发 + 清标记）：

- EffectDefinition：`scope=target`, `duration_mode=permanent`, `decrement_on=""`, `stacking=none`, `trigger_names=["on_hit"]`
- `required_target_effects = ["gojo_ao_mark", "gojo_aka_mark"]`
- `required_target_same_owner = true`
- payload 顺序：
1. `damage(use_formula=true, amount=32, damage_kind=special)`（条件追加一段伤害；`amount` 在 `use_formula=true` 下作为公式威力）
2. `remove_effect(gojo_ao_mark)`
3. `remove_effect(gojo_aka_mark)`

补充说明：

- 此处不额外写 `combat_type_id`：`DamagePayload.use_formula=true` 且处于技能链中时，类型继承链技能 `gojo_murasaki` 的 `combat_type_id=space`。
- 因此茈的**本体伤害**和**追加段伤害**都是“空间属性 + 特殊伤害”；区别只在公式威力分别是 `64` 与 `32`。
- `required_target_effects + required_target_same_owner` 当前共同组成茈的前置守卫：既要检查“目标身上是否同时存在双标记”，也要检查这两枚标记的 `meta.source_owner_id` 是否都等于当前 effect owner。
- `required_target_effects` 的设计目标是“effect 级前置守卫”，不是 payload 级条件分支；前置不满足时，整条 effect 直接退出，payload 循环不会开始，因此也不会写出任何由该 effect 产生的 payload 日志。
- 标记来源当前通过 `EffectInstance.meta.source_owner_id` 落盘；因此就算未来临时构造出“异来源双标记”，当前五条悟也不会误吃掉别人的标记。

语义：

- 条件满足：追加爆发并消耗双标记。
- 条件不满足：只结算茈本体伤害，不做额外动作。
- **不做任何反噬 / 自伤**。

边界：

- 若茈本体伤害已经把目标打到 `hp <= 0`，则 `on_hit` 追加 effect 在当前执行模型里会因为目标已无效而整条跳过，不会再打追加段，也不会清标记。
- 若追加伤害把目标打到 `hp <= 0`，后续 `remove_effect` 会因目标不再满足 `ACTIVE && hp > 0` 被静默跳过，不会报错；这属于当前 payload 有效性模型下的预期行为。
- 若目标在五条悟行动前通过换人离开 active 槽位，则 `enemy_active_slot` 的茈会命中当时站在该槽位的新 active；而原目标作为标记持有者离场时会按 `persists_on_switch=false` 清掉双标记，因此这类“被换下后由替补吃到茈”的场景默认不会触发追加段。

### 2.5 反转术式（Reverse Ritual）

| 字段 | 值 |
|------|-----|
| id | `gojo_reverse_ritual` |
| display_name | `反转术式` |
| damage_kind | `none` |
| power | **0** |
| accuracy | **100** |
| mp_cost | **14** |
| priority | **0** |
| combat_type_id | `` |
| targeting | `self` |
| effects_on_cast_ids | `["gojo_reverse_heal"]` |
| effects_on_hit_ids | `[]` |
| effects_on_miss_ids | `[]` |
| effects_on_kill_ids | `[]` |

效果：

- `gojo_reverse_heal`：`heal(use_percent=true, percent=25)`

### 2.6 无量空处（Unlimited Void）—— 奥义

| 字段 | 值 |
|------|-----|
| id | `gojo_unlimited_void` |
| display_name | `无量空处` |
| damage_kind | `special` |
| power | **48** |
| accuracy | **100** |
| mp_cost | **50** |
| priority | **+5** |
| combat_type_id | `space` |
| targeting | `enemy_active_slot` |
| effects_on_cast_ids | `[]` |
| effects_on_hit_ids | `["gojo_apply_domain_field"]` |
| effects_on_miss_ids | `[]` |
| effects_on_kill_ids | `[]` |

**FieldDefinition: `gojo_unlimited_void_field`**

| 字段 | 值 |
|------|-----|
| id | `gojo_unlimited_void_field` |
| display_name | `无量空处` |
| creator_accuracy_override | **100** |
| effect_ids | `["gojo_domain_cast_buff"]` |
| on_expire_effect_ids | `["gojo_domain_buff_remove"]` |
| on_break_effect_ids | `["gojo_domain_buff_remove"]` |

**展开效果链**

1. `gojo_apply_domain_field`：`apply_field(gojo_unlimited_void_field, duration=3, decrement_on=turn_end, on_success_effect_ids=["gojo_domain_action_lock"])`
2. `gojo_unlimited_void_field.effect_ids`：`gojo_domain_cast_buff` 在 `field_apply` 触发点给五条悟 `sp_attack +1`
3. `gojo_unlimited_void_field.on_expire_effect_ids / on_break_effect_ids`：`gojo_domain_buff_remove` 在领域结束或打断时回收增幅
4. `gojo_domain_action_lock`：只有在 `gojo_apply_domain_field` 成功落地后，才作为 follow-up 生效

<!-- anchor:gojo.design.success-lock-via-on_success_effect_ids -->

补充语义（领域公共规则仍以 `docs/design/domain_field_template.md` 为准）：

- 五条悟当前奥义点配置固定为：`ultimate_points_required = 3`、`ultimate_points_cap = 3`、`ultimate_point_gain_on_regular_skill_cast = 1`。
- 奥义合法性必须同时满足：`current_mp >= 50` 且 `ultimate_points >= 3`；开始施放无量空处时，奥义点立即清零；换下后点数保留。
- 若场上已有领域，领域冲突判定、对拼胜负与日志语义统一沿用 `docs/design/domain_field_template.md` 与 `docs/rules/05_items_field_input_and_logging.md`，不在角色稿重复定义。
<!-- anchor:gojo.design.shared-clash-rules-outsourced -->
- 若五条悟在领域对拼中失败，则无量空处**不落地、不加 `sp_attack +1`、也不锁人**；只有领域真正成功立住后，才会继续跑 `field_apply` 增幅和 `on_success_effect_ids`（`field_apply_success`）锁人。
<!-- anchor:gojo.design.failed-clash-no-field-buff-lock -->
- 同回合双方都已排队施放领域时，会先等待公共领域对拼结论，再兑现 `field_apply_success`；因此 `gojo_domain_action_lock` 不会先挂后残留，也不会把对手同回合已入队的领域动作回溯取消。
- 由于 `gojo_domain_cast_buff` 已改成 field 绑定效果，所以不会再出现“领域已经没了，但 `sp_attack +1` 还残留在五条悟身上”的状态。

顺序约束：

- `gojo_domain_action_lock` 不再和 `gojo_apply_domain_field` 平级并排挂在 `effects_on_hit_ids`；它固定通过 `ApplyFieldPayload.on_success_effect_ids` 触发，语义就是“领域成功后才锁人”。
- `gojo_domain_cast_buff` 固定挂在 field 的 `effect_ids` 上，通过 `field_apply` 触发；后续若要改动这条增幅语义，只允许在 field 生命周期内调整，不能再改回独立常驻 `stat_stage`。

`action_legality deny all` 的口径：

- 仅封禁技能 / 奥义 / 换人。
- 不封禁 `wait`。
- 若 Gojo **先于目标行动并且成功命中**，而目标本回合尚未开始执行，则目标已排队的技能 / 奥义 / 换人会在轮到它时按 `cancelled_pre_start` 跳过。
- 这不是“领域展开后无条件首回合锁到对方”的硬保证：若对手已经更早行动，或在同优先级竞争里先于 Gojo 执行，则本回合不会被这条锁追溯性拦下。

`gojo_domain_action_lock` 资源口径：

1. EffectDefinition：`scope=target`, `duration_mode=permanent`, `decrement_on=""`, `stacking=none`, `trigger_names=["field_apply_success"]`
2. payload：`rule_mod(mod_kind=action_legality, mod_op=deny, value=all, scope=target, duration_mode=turns, duration=1, decrement_on=turn_end, stacking=replace)`

时间语义：

- field 的 `duration=3 + decrement_on=turn_end` 与标记同口径：从施放当回合开始，连续经过 3 次 `turn_end` 节点后自然到期。
- 因此文档里写“持续 3 回合”时，指的是“3 次 `turn_end` 扣减窗口”，不是“额外再经历 3 个完整后续回合”。

本版删除领域后摇：不再追加 `expire_seal / rollback`，领域结束或被打破后不对五条悟追加封印处罚。

---

### 2.7 被动技能：无下限（Mugen）

#### 玩家与机制语义

- 当敌方对五条悟发动技能或奥义时：
1. 先按现有流程得到 `resolved_accuracy`（技能精度 + 领域覆盖等）。
2. 若 `resolved_accuracy >= 100`，视为必中，**无下限不生效**。
3. 若 `resolved_accuracy < 100`，且目标是五条悟，则本次命中率再减 `10` 后再 roll。
- 大白话例子：
  - 敌方技能原本结算命中是 `95`，打到五条悟身上会变成 `85`。
  - 敌方技能原本结算命中是 `100`，那就是必中，仍然保持 `100`，不会被削成 `90`。
  - `switch / wait / resource_forced_default`，以及 `self / field / none` 这类不属于“敌方打向五条悟”的路径，都不读取这条修正。

#### 资源定义

`gojo_mugen`（PassiveSkillDefinition）：

- `trigger_names = ["on_enter"]`
- `effect_ids = ["gojo_mugen_incoming_accuracy_down"]`

`gojo_mugen_incoming_accuracy_down`（EffectDefinition）：

- EffectDefinition：`scope=self`, `duration_mode=permanent`, `decrement_on=""`, `stacking=none`, `trigger_names=["on_enter"]`
- payload：`rule_mod(mod_kind="incoming_accuracy", mod_op="add", value=-10, scope="self", duration_mode="permanent", decrement_on="turn_end", stacking="none")`

说明：

- 无下限改成稳定干扰命中，不再使用概率触发，也不再改写伤害值。
- 字段约束是**双层**的：EffectDefinition 层（permanent）要求 `decrement_on=""`；RuleModPayload 层仍要求显式 `turn_start/turn_end`，因此 payload 内保留 `decrement_on="turn_end"`。
- `LeaveService` 会在单位离场时清空 `rule_mod_instances`，所以无下限必须挂在 `on_enter`，确保每次入场都重新施加。
- 运行时语义补充：对 `duration_mode=permanent` 的 RuleModPayload，`decrement_on` 不参与扣减（`remaining=-1` 不会递减）；该字段仅用于满足 payload 校验约束。

---

### 2.8 共享能力引用（只写五条悟差异）

- 这一节只保留“五条悟怎么用共享能力”，不再复述公共 schema、全局排序链或完整匹配矩阵。
- `required_target_effects / required_target_same_owner` 的完整 schema 与运行时语义统一引用 `docs/rules/06_effect_schema_and_extension.md`；五条悟当前只在 `gojo_murasaki_conditional_burst` 上消费“自己本人挂上的双标记”。
- `incoming_accuracy` 的完整读路径、来源分组与多实例排序统一引用 `docs/rules/03_stats_resources_and_damage.md` 与 `docs/design/battle_runtime_model.md`；五条悟当前只定义 `gojo_mugen_incoming_accuracy_down = -10` 这一条角色差异。
- `action_legality` 的完整匹配矩阵、排序链与 `wait` 例外统一引用 `docs/design/command_and_legality.md`；五条悟当前只通过 `gojo_domain_action_lock` 在领域成功立住后写入 `deny all`。
- 当前明确不纳入五条悟实现的历史方案仍然固定为：`effects_pre_damage_ids`、`on_before_damage`、`damage_override`、`trigger_chance`、`action_tags`、`last_dealt_damage` 与茈反噬链路。

---

## 附录 B. 资源文件清单

以下清单是 **Gojo 当前主线资源面**。截至 2026-03-29，底层扩展、Gojo 内容资源、`SampleBattleFactory` 快照注册与 `gojo_suite` 均已接线完成。

补充施工边界：

- 下列 `.tres` 已落盘，并已进入 `SampleBattleFactory.content_snapshot_paths_result()` 的正式收口面；旧的 `content_snapshot_paths()` 现在只作为内部薄封装存在。
- 统一闸门当前已注册 `gojo_suite`；后续新增角色应沿用同一“资源清单 + SampleFactory 接线 + suite 注册”模板。

### B.1 `content/units/`

- `gojo_satoru.tres`

### B.2 `content/skills/`

- `gojo_ao.tres`
- `gojo_aka.tres`
- `gojo_murasaki.tres`
- `gojo_reverse_ritual.tres`
- `gojo_unlimited_void.tres`

### B.3 `content/effects/`

- `gojo_ao_speed_up.tres`
- `gojo_ao_mark_apply.tres`
- `gojo_ao_mark.tres`
- `gojo_aka_slow_down.tres`
- `gojo_aka_mark_apply.tres`
- `gojo_aka_mark.tres`
- `gojo_murasaki_conditional_burst.tres`
- `gojo_reverse_heal.tres`
- `gojo_domain_cast_buff.tres`
- `gojo_domain_buff_remove.tres`
- `gojo_apply_domain_field.tres`
- `gojo_domain_action_lock.tres`
- `gojo_mugen_incoming_accuracy_down.tres`

### B.4 `content/fields/`

- `gojo_unlimited_void_field.tres`

### B.5 `content/passive_skills/`

- `gojo_mugen.tres`

### B.6 已存在资源（无需新建）

- `content/combat_types/space.tres`
- `content/combat_types/psychic.tres`

---

## 3. 角色特有验收矩阵

正式交付面说明：

- `gojo_suite.gd` 承担五条悟玩法与行为回归。
- `gojo_snapshot_suite.gd` 用字面量断言锁死五条悟单位面板、技能资源与关键 effect / field / passive 资源。
- `ultimate_field_suite.gd` 中登记到注册表的共享领域回归，同样属于五条悟正式交付面的一部分。

| 编号 | 用例 | 验证点 |
|------|------|--------|
| 1 | 默认配招与候选池契约 | `skill_ids=[ao,aka,murasaki]`；`candidate_skill_ids` 含 `reverse_ritual` |
| 1A | 单位资源快照 | 五条悟基础面板、MP、奥义点配置、默认配招、候选池、奥义、被动固定不漂移 |
| 1B | 技能资源快照 | 苍 / 赫 / 茈 / 反转术式 / 无量空处的 `damage_kind / power / accuracy / mp_cost / priority / combat_type_id / targeting` 固定不漂移 |
| 1C | 关键 effect / field / passive 快照 | 双标记时长、无量空处领域、锁行动、无下限命中修正全部固定不漂移 |
| 2 | 赛前换装 | `SideSetup.regular_skill_loadout_overrides` 可将 `reverse_ritual` 装入 |
| 3 | 苍命中后效果 | 自身 speed +1；目标挂 `gojo_ao_mark` |
| 4 | 赫命中后效果 | 目标 speed -1；目标挂 `gojo_aka_mark` |
| 5 | 茈无双标记 | 只有本体伤害；标记不被误清 |
| 6 | 茈双标记触发 | 追加伤害生效，并清除苍 / 赫标记 |
| 7 | 茈触发后无自伤 | 施法者 HP 不因反噬扣减 |
| 8 | 反转术式 | 回复 25% max_hp |
| 9 | MP 回复 | 每回合回复 14 |
| 10 | 首回合可操作 MP | 按当前 `turn_start -> selection` 时序，Gojo 第 1 回合进入选指时 `current_mp = 64` |
| 11 | 无下限重入场 | 五条悟离场再入场后，`incoming_accuracy -10` 仍生效 |
| 12 | 无量空处 action_lock 生效时机 | 只有 `gojo_apply_domain_field` 成功落地后，才会通过 `on_success_effect_ids -> field_apply_success` 施加 `gojo_domain_action_lock`；若 Gojo 先于目标行动且对手尚未开始，本回合已排队技能 / 换人会被 `cancelled_pre_start` |
| 13 | action_legality + wait | `deny all` 时 `wait` 仍可选 |
| 14 | action_legality 阻断换人也算非 MP 阻断 | 当技能 / 奥义仅因 MP 不足不可用、换人被 `deny switch/all` 封禁时，legal set 只保留 `wait`，不得回落到 `resource_forced_default` |
| 15 | 领域内必中 | `creator_accuracy_override=100` 只在无量空处领域成功立住后生效 |
| 16 | 无下限非必中减命中 | 仅当 `resolved_accuracy < 100` 时生效；敌方 95 命中技能打五条悟按 85 判定 |
| 17 | 无下限不影响必中 | 敌方 100 命中技能（或领域覆盖必中）不降命中 |
| 18 | 标记持有者离场清除 | 目标换下后 `gojo_ao_mark/gojo_aka_mark` 被移除（`persists_on_switch=false`） |
| 19 | 五条悟离场不清目标标记 | 五条悟自己换下时，敌方身上的苍 / 赫标记仍保留 |
| 20 | 同队重复角色禁止 | 同一 side 若出现两个 `gojo_satoru`，BattleSetup 校验应直接失败 |
| 21 | 茈追加击杀边界 | 追加段把目标打到 `hp<=0` 时，后续 `remove_effect` 静默跳过且不产生 `invalid_battle` |
| 22 | 茈本体先击杀边界 | 若茈本体伤害已击杀目标，则 `gojo_murasaki_conditional_burst` 整条跳过，不再打追加段 |
| 23 | 茈对位槽位重定向边界 | 目标在 Gojo 行动前换下时，`enemy_active_slot` 茈命中新 active；若新 active 不持双标记，则不触发追加段 |
| 24 | required_target_effects 坏引用 | `required_target_effects` 指向不存在 effect 时内容加载期直接失败 |
| 25 | 无量空处先手但领域对拼失败 | 若 Gojo 先手展开领域、后手领域随后翻盘，则 `gojo_domain_action_lock` 不得先挂上又残留；失败方视为“未成功立住” |
| 26 | incoming_accuracy 作用域收紧 | `self/field/none` 目标技能、`switch/wait/resource_forced_default` 不读取 `incoming_accuracy` |
| 27 | action_legality 匹配矩阵 | `deny all + allow switch`、`deny skill + allow gojo_ao`、`deny ultimate + allow ultimate_id` 结果与矩阵一致 |
| 28 | action_legality 单口径排序 | `action_legality` 必须沿统一排序链读取，不得再残留旧合法性分支或双口径漂移 |
| 29 | 双 `+5` 先后手竞争 | 对手也使用 `+5` 奥义时，若对手先动，则 Gojo 本回合不得被文档误写成“仍然锁到对方” |
| 30 | 标记 / 领域时间线 | `duration=3 + decrement_on=turn_end` 必须按“施放当回合起连续 3 次 `turn_end` 扣减”验证 |
| 31 | 领域对拼失败边界 | 五条悟在领域对拼中输掉时，不落领域、不加 `sp_attack +1`、也不锁人 |
| 32 | required_target_effects 跳过无日志 | 前置条件不满足时，`gojo_murasaki_conditional_burst` 不执行 payload，也不得写出该 effect 产生的 payload 日志 |
| 33 | incoming_accuracy 多实例顺序 | `add/set` 混用时，必须按统一 rule_mod 读取顺序求值，再统一 clamp 到 `0~99` |
| 34 | action_legality 同 key 覆盖语义 | 同 key `replace` 覆盖后，后实例到期不得把旧实例“复活”；若要支持恢复，必须另扩实例模型 |
| 35 | 标记 refresh 续时语义 | `gojo_ao_mark / gojo_aka_mark` 再次命中施加时，应刷新持续时间，不得额外并行出第二层同名标记 |
| 36 | 奥义点 3/3/1 contract | 常规技能开始施放即 +1，miss 也加；上限 3；奥义开始施放清零；换下保留 |
| 37 | 领域 buff 生命周期 | `gojo_domain_cast_buff` 只在 `field_apply` 成立时生效；自然到期与提前打断都必须通过 `gojo_domain_buff_remove` 回收 |

---

## 4. 平衡备注

| 维度 | 五条悟（本版） | 说明 |
|------|----------------|------|
| 爆发 | 中高 | 茈双标记连段在当前公式下可打出明显高于单发技能的爆发 |
| 控场 | 很高 | 领域命中后能锁未开始行动的对手，并让 creator 技能必中；但不是所有先手竞争场景都能保证首回合锁到人 |
| 生存 | 中高 | 反转术式 + 稳定命中干扰，让它比“纯高速脆皮法师”更难处理 |
| 资源节奏 | 中高 | 按当前主线时序首个可操作回合实战可用 MP 为 `64`，配合 `regen=14` 能较早形成压制，但还没到“无脑连开奥义”的程度 |

补充说明：

- 按当前 main 的 50 级简化公式与现有时序，五条悟更接近“偏强压制型角色”，不是单纯的“中性强度高速术师”。
- 但“宿傩基线”不是严格中性参照：当前样例属性表里 `psychic -> demon = 0.5`、`demon -> psychic = 2.0`，因此 Gojo 对宿傩的实战表现不能直接代表它在中性对位下的最终强度。

本版目标不是最终平衡值，而是先落地“可施工、可验收、可迭代”的玩法闭环；最终强度仍需等 Gojo 落地后再用实战数据回调。

### 4.1 当前冻结

| 项目 | 说明 |
|---|---|
| 标记来源校验 | 当前已做；茈只消费当前五条悟本人施加的双标记 |
| 奥义点 | `required=3 / cap=3 / regular_skill_cast +1` |
| 锁人条件 | 只有领域成功立住才锁人 |
| 领域增幅归属 | `sp_attack +1` 跟 `gojo_unlimited_void_field` 生命周期走 |
| 领域后摇 | 已删除（Gojo / Sukuna 同口径） |
| 平衡结论 | 保留苍 / 赫 / 茈现有机制、保留无下限现有机制；奥义改为 3 点可开 |
| 领域强度 | 暂不下调，后续按实战数据再调 |
