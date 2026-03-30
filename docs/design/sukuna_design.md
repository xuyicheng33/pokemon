# 两面宿傩（Sukuna）设计方案（审计收口版 v1.0）

## 0. 审计后冻结结论（2026-03-30）

| 项目 | 结论 |
|------|------|
| 角色定位 | 中速高压破阵手；靠稳定伤害、灶与领域终爆持续施压 |
| 被动“教会你爱的是...” | 保留当前 `on_matchup_changed -> mp_regen` 方案 |
| 灶 | 保留“命中后挂灶；离场触发；自然到期也会爆”的现有机制 |
| 奥义点 | `required=3 / cap=3 / regular_skill_cast +1` |
| 领域终局语义 | **领域自然到期终爆保留**；被打断时**无终爆** |
| 领域增幅归属 | `attack +1 / sp_attack +1` 改为 field 绑定效果；成功立场时生效，领域结束或打断时移除 |
| 平衡结论 | `3` 点奥义点体系下，默认装配与反转术式装配都已能稳定进入奥义窗口；但在 Gojo 对位里，宿傩领域对拼仍长期立不住 |

---

## 1. 角色基础属性

### 1.1 角色定位

- 面向玩家：宿傩是一个靠稳压、灶层数和领域终爆滚雪球的角色，不是纯瞬间爆发法师。
- 面向实现：他依赖 3 条主线资源节奏并行运转
  - 常规技压血与攒奥义点
  - `开 -> 灶` 的离场/到期连锁
  - `伏魔御厨子` 的 3 回合领域与终爆收尾

### 1.2 UnitDefinition

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `sukuna` | |
| display_name | `宿傩` | |
| combat_type_ids | `["fire", "demon"]` | 火 + 咒灵 |
| base_hp | **126** | |
| base_attack | **78** | 物理端高于五条悟 |
| base_defense | **62** | |
| base_sp_attack | **84** | 特攻也不低 |
| base_sp_defense | **60** | |
| base_speed | **76** | 中速 |
| BST | **486** | 当前样例角色中略高于五条悟 |

### 1.3 MP 系统

| 字段 | 值 | 说明 |
|------|-----|------|
| max_mp | **100** | |
| init_mp | **45** | |
| regen_per_turn | **12** | |

补充语义：

- 按当前主线固定时序，`turn_start` MP 回复发生在第 1 回合选指前，因此宿傩首个可操作回合的实战可用 MP 是 `57`。
- 被动“教会你爱的是...”会按对位差值把 `mp_regen` 覆盖到动态档位；上表的 `12` 是基础值，不是最终每回合固定回复值。

### 1.4 技能组与赛前装配

**内容层（UnitDefinition）**

- 默认配招（`skill_ids`，3 个）：`sukuna_kai`、`sukuna_hatsu`、`sukuna_hiraku`
- 奥义（`ultimate_skill_id`）：`sukuna_fukuma_mizushi`
- 候选技能池（`candidate_skill_ids`，4 个）：`sukuna_kai`、`sukuna_hatsu`、`sukuna_hiraku`、`sukuna_reverse_ritual`
- 奥义点配置：`ultimate_points_required = 3`、`ultimate_points_cap = 3`、`ultimate_point_gain_on_regular_skill_cast = 1`

**赛前层（SideSetup）**

- 本场常规三技能装配通过 `SideSetup.regular_skill_loadout_overrides` 决定。
- 当前只允许覆盖常规三技能；奥义、被动、持有物不开放赛前替换。

### 1.5 被动

| 类型 | 值 |
|------|-----|
| passive_skill_id | `sukuna_teach_love` |
| passive_item_id | `` |

---

## 2. 技能详细设计

> 领域公共模板见 `docs/design/domain_field_template.md`。本稿只写宿傩在该模板下的角色差异。

### 2.1 解（Kai）

| 字段 | 值 |
|------|-----|
| id | `sukuna_kai` |
| display_name | `解` |
| damage_kind | `physical` |
| power | **42** |
| accuracy | **100** |
| mp_cost | **10** |
| priority | **+1** |
| combat_type_id | `` |
| targeting | `enemy_active_slot` |
| effects_on_cast_ids | `[]` |
| effects_on_hit_ids | `[]` |

- 玩家说明：低消耗、带先手的稳定斩击，用来压血和攒奥义点。
- 机制说明：纯单段物理伤害；`combat_type_id=""` 表示中立属性，不吃属性克制加成或减免。
- 验收点：
  - 命中后只产出伤害事件，不挂额外 effect。
  - 作为常规技能，开始施放时会按角色配置获得 `+1` 奥义点。

### 2.2 捌（Hatsu）

| 字段 | 值 |
|------|-----|
| id | `sukuna_hatsu` |
| display_name | `捌` |
| damage_kind | `special` |
| power | **46** |
| accuracy | **95** |
| mp_cost | **18** |
| priority | **-1** |
| combat_type_id | `` |
| targeting | `enemy_active_slot` |
| power_bonus_source | `mp_diff_clamped` |
| effects_on_hit_ids | `[]` |

- 玩家说明：慢一拍的重斩，自己 MP 越多、对手 MP 越少时越痛。
- 机制说明：基础威力 `46`，再叠加 `max(0, actor.current_mp - target.current_mp)` 的威力 bonus；读取点发生在当前施法结算时，不回写内容资源。
- 验收点：
  - 额外威力只吃正向 MP 差，不会出现负 bonus。
  - 作为常规技能，开始施放时也会获得奥义点。

### 2.3 开（Hiraku）

| 字段 | 值 |
|------|-----|
| id | `sukuna_hiraku` |
| display_name | `开` |
| damage_kind | `special` |
| power | **48** |
| accuracy | **90** |
| mp_cost | **22** |
| priority | **-2** |
| combat_type_id | `fire` |
| targeting | `enemy_active_slot` |
| effects_on_hit_ids | `["sukuna_apply_kamado"]` |

**灶相关 effect**

| 资源 | 语义 |
|------|------|
| `sukuna_apply_kamado` | `on_hit` 时对目标施加 `sukuna_kamado_mark` |
| `sukuna_kamado_mark` | 持续 3 次 `turn_end`；`stacking=stack`；`on_exit` 触发 20 点火属性固定伤害；自然到期时通过 `on_expire_effect_ids` 再爆一次 |
| `sukuna_kamado_explode` | 灶的自然到期爆炸，本体为 20 点火属性固定伤害 |

- 玩家说明：慢速火术式；命中后会把“灶”挂在对手身上，逼对手换人或吃到后续爆炸。
- 机制说明（领域公共规则仍以 `docs/design/domain_field_template.md` 为准）：
  - `开` 命中后只负责施加 `sukuna_kamado_mark`。
  - 灶层数独立存在，`stacking=stack`，多层会各自扣减、各自结算。
  - `persists_on_switch=false` 表示标记持有者离场时会把灶实例带走；但在离场链上的 `on_exit` 会先结算 20 点火属性固定伤害。
  - 若目标一直不离场，灶会在第 3 次 `turn_end` 后自然到期，并通过 `sukuna_kamado_explode` 再爆一次。
- 边界行为：
  - 目标带着两层灶离场时，应触发两次 `on_exit` 伤害事件。
  - 灶的自然到期爆炸与离场爆炸是两条不同路径，不能互相吞掉。
- 验收点：
  - `double hiraku` 后，目标离场必须触发两次伤害日志。
  - 灶自然到期时仍会造成一次固定伤害。

### 2.4 反转术式（Reverse Ritual）

| 字段 | 值 |
|------|-----|
| id | `sukuna_reverse_ritual` |
| display_name | `反转术式` |
| damage_kind | `none` |
| power | **0** |
| accuracy | **100** |
| mp_cost | **14** |
| priority | **0** |
| combat_type_id | `` |
| targeting | `self` |
| effects_on_cast_ids | `["sukuna_reverse_heal"]` |

- 玩家说明：稳定续航，回复自身 25% 最大生命。
- 机制说明：`sukuna_reverse_heal` 使用 `heal(use_percent=true, percent=25)`；只在赛前把它装进当前三技能时才可用。
- 验收点：
  - setup override 换入后才会出现在合法行动里。
  - 回复值按 `max_hp * 25%` 向下取整，并受剩余可回复量上限约束。

### 2.5 伏魔御厨子（Fukuma Mizushi）—— 奥义

| 字段 | 值 |
|------|-----|
| id | `sukuna_fukuma_mizushi` |
| display_name | `伏魔御厨子` |
| damage_kind | `special` |
| power | **68** |
| accuracy | **100** |
| mp_cost | **50** |
| priority | **+5** |
| combat_type_id | `demon` |
| targeting | `enemy_active_slot` |
| effects_on_cast_ids | `[]` |
| effects_on_hit_ids | `["sukuna_apply_domain_field"]` |

**FieldDefinition: `sukuna_malevolent_shrine_field`**

| 字段 | 值 |
|------|-----|
| id | `sukuna_malevolent_shrine_field` |
| display_name | `伏魔御厨子·领域` |
| creator_accuracy_override | **100** |
| effect_ids | `["sukuna_domain_cast_buff"]` |
| on_expire_effect_ids | `["sukuna_domain_buff_remove", "sukuna_domain_expire_burst"]` |
| on_break_effect_ids | `["sukuna_domain_buff_remove"]` |

**展开效果链**

1. `sukuna_apply_domain_field`：`apply_field(sukuna_malevolent_shrine_field, duration=3, decrement_on=turn_end)`
2. `sukuna_malevolent_shrine_field.effect_ids`：通过 `field_apply` 给宿傩 `attack +1` 与 `sp_attack +1`
3. `sukuna_malevolent_shrine_field.on_break_effect_ids`：领域被打断时移除两层增幅
4. `sukuna_malevolent_shrine_field.on_expire_effect_ids`：领域自然到期时先移除两层增幅，再触发 `sukuna_domain_expire_burst`

- 玩家说明：高优先级大招，展开后提升自己双攻，并让后续技能必中；领域结束时还会补一段终爆。
- 机制说明：
  - 宿傩当前奥义点配置固定为 `required=3 / cap=3 / regular_skill_cast +1`。
  - 奥义合法性必须同时满足 `current_mp >= 50` 与 `ultimate_points >= 3`；开始施放奥义时奥义点立即清零；换下后点数保留。
  - 若场上已有领域，则进入领域对拼：比较双方扣费后的当前 MP；高者留场；平 MP 随机决定胜者，并把随机值写入 `effect:field_clash.effect_roll`。
  - 宿傩若在领域对拼中失败，则本次领域不落地；`attack +1 / sp_attack +1` 与自然到期终爆都不会成立。
  - `creator_accuracy_override=100` 只在领域成功立住后生效。
  - **领域自然到期终爆保留**：`sukuna_domain_expire_burst` 造成 20 点火属性固定伤害。
  - 领域被打断时只移除增幅，不触发终爆。
- 边界行为：
  - 领域自然到期后，宿傩双攻必须回到入场基线。
  - creator 离场、被强制换下或被击倒时，field 会先被打断，再继续补位与 `on_enter`。
- 验收点：
  - 自然到期：field 消失、双攻回收、终爆生效。
  - 提前打断：field 消失、双攻回收、无终爆。
  - 领域对拼失败：不落 field、无增幅、无后续终爆。

---

## 3. 被动技能：教会你爱的是...

### 3.1 玩法语义

- 面向玩家：宿傩会根据当前对位的强弱差异动态调整回蓝，越接近的对手越能让他持续作战。
- 面向实现：该被动在 `on_matchup_changed` 触发，把 `mp_regen` 设置为一条持续中的 `rule_mod`。

### 3.2 资源定义

`sukuna_teach_love`（PassiveSkillDefinition）：

- `trigger_names = ["on_matchup_changed"]`
- `effect_ids = ["sukuna_refresh_love_regen"]`

`sukuna_refresh_love_regen`（EffectDefinition）：

- `scope=self`
- `trigger_names=["on_matchup_changed"]`
- payload：`rule_mod(mod_kind=mp_regen, mod_op=set, dynamic_value_formula=matchup_bst_gap_band)`

动态值口径：

| 总面板差距 `gap` | 最终回蓝值 |
|---|---|
| `gap <= 20` | `9` |
| `gap <= 40` | `8` |
| `gap <= 70` | `7` |
| `gap <= 110` | `6` |
| `gap <= 160` | `5` |
| `gap > 160` | `0` |

补充说明：

- 当前 `gap` 读取的是双方 `max_hp + attack + defense + sp_attack + sp_defense + speed + max_mp` 的总和差距绝对值。
- 动态公式只会把求值结果写进运行时 `rule_mod instance`，不会回写共享 `.tres` payload。

---

## 4. 专项验收点（sukuna_suite + ultimate_field_suite）

| 编号 | 用例 | 验证点 |
|------|------|--------|
| 1 | 默认配招与候选池契约 | 默认三技能固定为 `解 / 捌 / 开`；`反转术式` 只在 `candidate_skill_ids` 中 |
| 2 | 赛前换装 | `regular_skill_loadout_overrides` 可把 `反转术式` 装入本场三技能 |
| 3 | 被动回蓝动态值 | `on_matchup_changed` 后只存在 1 条 `mp_regen` 实例，且值按差距表求出 |
| 4 | 反转术式回复 | 回复 `25% max_hp`，并写出治疗日志 |
| 5 | 开挂灶 | 命中后给目标挂 `sukuna_kamado_mark` |
| 6 | 双层灶离场 | 目标带两层灶离场时必须触发两次 `on_exit` 伤害日志 |
| 7 | 灶自然到期 | 目标不离场时，灶到第 3 次 `turn_end` 后仍会爆一次 |
| 8 | 奥义点 3/3/1 | 常规技能开始施放 +1；上限 3；奥义开始施放清零；换下保留 |
| 9 | 领域自然到期终爆 | field 消失、双攻回收、终爆生效 |
| 10 | 领域被打断无终爆 | creator 离场后 field 打断、双攻回收、无终爆 |
| 11 | 领域对拼失败 | 不落 field，不加双攻，不保留领域自然到期后效 |
| 12 | 领域内必中 | `creator_accuracy_override=100` 只在领域成功立住后生效 |

---

## 5. 平衡性备注

| 维度 | 宿傩（本版） | 说明 |
|------|--------------|------|
| 即时爆发 | 中高 | `解 / 捌 / 开` 都能稳压，但不靠单回合秒杀 |
| 持续压制 | 很高 | 灶、动态回蓝、领域终爆会逼迫对手处理时间轴 |
| 领域收益 | 高，但当前兑现率不稳 | 领域立住后有必中与双攻增幅，自然结束还有终爆；但对 Gojo 对位里当前仍常输领域对拼 |
| 资源节奏 | 中高 | 动态回蓝表与领域优先级修正后，两套常见装配都能稳定进入奥义窗口，但 clash 资源轴还要继续看 |

补充说明：

- `3 点奥义点体系下`，当前对称 `200` 场启发式批跑结果是：默认装配 Gojo `120` / 宿傩 `80`，反转术式装配 Gojo `89` / 宿傩 `111`；两套装配都已经能稳定看到奥义释放。
- 但同一批 Gojo 对位样本里，宿傩的 `domain_successes` 仍是 `0`，说明当前主线修好的是“能不能开大”，不是“领域能不能真正立住”。
- 若后续还要继续调强或回调宿傩，应优先结合 probe 观察领域对拼的资源轴，再决定是动伤害、回蓝表、奥义 MP 成本还是奥义点窗口。

## 6. 当前冻结

| 项目 | 说明 |
|---|---|
| 奥义点 | `required=3 / cap=3 / regular_skill_cast +1` |
| 灶 | 保留多层独立结算；离场触发与自然到期触发并存 |
| 领域终局 | 自然到期有终爆；被打断无终爆 |
| 领域增幅归属 | `attack +1 / sp_attack +1` 跟 `sukuna_malevolent_shrine_field` 生命周期走 |
| 平衡结论 | `3` 点奥义点体系下，两套常见装配都能稳定进入奥义窗口；若还要继续调强，应优先处理领域对拼兑现率，而不是回退到 `2` 点体系 |
