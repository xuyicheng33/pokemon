# 五条悟（Gojo Satoru）设计方案（收敛版 v2）

## 0. 本版收敛结论（2026-03-28）

| 项目 | 结论 |
|------|------|
| 茈 | 保留“苍+赫双标记”条件爆发，**不做自伤** |
| 无下限 | 改为“敌方技能攻击五条悟时，若该次不是必中，则命中率 -10” |
| 引擎改动范围 | 仅保留 `action_legality`、`required_target_effects`、`incoming_accuracy` 三块 |
| 明确不做 | `effects_pre_damage_ids`、`on_before_damage`、`damage_override`、`action_tags`、`last_dealt_damage`、反噬链路 |

---

## 1. 角色基础属性

### 1.1 UnitDefinition

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
| base_speed | **86** | 仍是高速定位 |
| BST | **482** | 低于宿傩（486） |

### 1.2 MP 系统

| 字段 | 值 | 说明 |
|------|-----|------|
| max_mp | **100** | |
| init_mp | **50** | 首回合可规划一轮爆发，但不再过宽 |
| regen_per_turn | **14** | 从旧稿 16 下调，压缩连续压制 |

### 1.3 技能组与赛前装配

**内容层（UnitDefinition）**

- 默认配招（`skill_ids`，3 个）：`gojo_ao`、`gojo_aka`、`gojo_murasaki`
- 奥义（`ultimate_skill_id`）：`gojo_unlimited_void`
- 候选技能池（`candidate_skill_ids`，4 个）：`gojo_ao`、`gojo_aka`、`gojo_murasaki`、`gojo_reverse_ritual`

**赛前层（SideSetup）**

- 本场装配通过 `regular_skill_loadout_overrides` 决定；当 `candidate_skill_ids` 非空时，允许赛前从候选池选 3 个写入运行时配招。

### 1.4 被动

| 类型 | 值 |
|------|-----|
| passive_skill_id | `gojo_mugen` |
| passive_item_id | `` |

---

## 2. 技能详细设计

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
- `gojo_ao_mark_apply`：`scope=target`，`apply_effect(gojo_ao_mark)`（纯标记，`duration=3 turns`，`stacking=refresh`，`decrement_on=turn_end`）

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
- `gojo_aka_mark_apply`：`scope=target`，`apply_effect(gojo_aka_mark)`（纯标记，`duration=3 turns`，`stacking=refresh`，`decrement_on=turn_end`）

### 2.3 茈（Murasaki）—— 条件追加爆发（无自伤）

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

- `required_target_effects = ["gojo_ao_mark", "gojo_aka_mark"]`
- payload 顺序：
1. `damage(use_formula=true, amount=32, damage_kind=special)`（条件追加一段伤害）
2. `remove_effect(gojo_ao_mark)`
3. `remove_effect(gojo_aka_mark)`

语义：

- 条件满足：追加爆发并消耗双标记。
- 条件不满足：只结算茈本体伤害，不做额外动作。
- **不做任何反噬/自伤**。

### 2.4 反转术式（Reverse Ritual）

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

### 2.5 无量空处（Unlimited Void）—— 奥义

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
| effects_on_cast_ids | `["gojo_domain_cast_buff"]` |
| effects_on_hit_ids | `["gojo_apply_domain_field", "gojo_domain_action_lock"]` |
| effects_on_miss_ids | `[]` |
| effects_on_kill_ids | `[]` |

**FieldDefinition: `gojo_unlimited_void_field`**

| 字段 | 值 |
|------|-----|
| id | `gojo_unlimited_void_field` |
| display_name | `无量空处` |
| creator_accuracy_override | **100** |
| effect_ids | `[]` |
| on_expire_effect_ids | `["gojo_domain_expire_seal"]` |
| on_break_effect_ids | `["gojo_domain_rollback"]` |

**展开效果链**

1. `gojo_domain_cast_buff`：`stat_mod(sp_attack, +1)`（self）
2. `gojo_apply_domain_field`：`apply_field(gojo_unlimited_void_field, duration=3, decrement_on=turn_end)`（field）
3. `gojo_domain_action_lock`：`action_legality deny all, duration=1, decrement_on=turn_end`（target）

`action_legality deny all` 的口径：

- 仅封禁技能 / 奥义 / 换人。
- 不封禁 `wait`。
- 若在排队后中途上锁，执行到该动作时按 `cancelled_pre_start` 跳过。

**领域过期与打破**

- `gojo_domain_expire_seal`：3 条 `action_legality deny`（`gojo_ao` / `gojo_aka` / `gojo_murasaki`），`duration=2`, `decrement_on=turn_end`。
- `gojo_domain_rollback`：与过期封印同链，仅区分日志来源（`on_break`）。

---

## 3. 被动技能：无下限（Mugen）

### 3.1 玩法语义

- 当敌方对五条悟发动技能或奥义时：
1. 先按现有流程得到 `resolved_accuracy`（技能精度 + 领域覆盖等）。
2. 若 `resolved_accuracy >= 100`，视为必中，**无下限不生效**。
3. 若 `resolved_accuracy < 100`，且目标是五条悟，则本次命中率再减 `10` 后再 roll。

### 3.2 资源定义

`gojo_mugen`（PassiveSkillDefinition）：

- `trigger_names = ["battle_init"]`
- `effect_ids = ["gojo_mugen_incoming_accuracy_down"]`

`gojo_mugen_incoming_accuracy_down`（EffectDefinition）：

- `scope=self`
- payload：`rule_mod(mod_kind="incoming_accuracy", mod_op="add", value=-10, scope="self", duration_mode="permanent", decrement_on="turn_end", stacking="refresh")`

说明：无下限改成稳定干扰命中，不再使用概率触发，也不再改写伤害值。

---

## 4. 引擎改动范围（可施工）

### 4.1 `action_legality`（替代 `skill_legality`）

`rule_mod.mod_kind` 从 `skill_legality` 迁到 `action_legality`，`value` 支持：

- `"all"` / `"skill"` / `"ultimate"` / `"switch"` / 具体 `skill_id`

实现点：

- `rule_mod_service.gd`：`is_skill_allowed()` 收敛为 `is_action_allowed(action_type, skill_id)`
- `legal_action_service.gd`：技能、奥义、换人都要读 `action_legality`
- `action_executor.gd`：`_can_start_action()` 执行前复检 `action_legality`

### 4.2 `required_target_effects`

`effect_definition.gd` 新增：

```gdscript
@export var required_target_effects: PackedStringArray = PackedStringArray()
```

执行规则：

- `PayloadExecutor` 在执行 effect 前检查目标是否同时具备所有 required effect（按 `def_id`）。
- 不满足则跳过该 effect，不报错。

该能力仅用于茈的条件追加爆发，不引入 `action_tags`。

### 4.3 `incoming_accuracy`（无下限命中干扰）

新增 rule_mod kind：

- `incoming_accuracy`

实现点：

- `content_schema.gd`：新增 `RULE_MOD_INCOMING_ACCURACY`
- `rule_mod_service.gd`：新增命中读取接口（建议 `resolve_incoming_accuracy(base_accuracy, target_owner_id)`）
- `action_cast_service.gd`：`resolve_hit` 在 field 覆盖后、`roll_hit` 前读取目标侧 `incoming_accuracy`

约束：

- 只在 `resolved_accuracy < 100` 时读取（必中不受影响）。
- 最终命中率 clamp 到 `0~99`。

### 4.4 本版明确不纳入实现

| 机制 | 状态 |
|------|------|
| `effects_pre_damage_ids` | 不做 |
| `on_before_damage` | 不做 |
| `damage_override` payload | 不做 |
| `trigger_chance`（用于无下限） | 不做 |
| `action_tags` / `last_dealt_damage` | 不做 |
| 茈反噬自伤 | 不做 |

---

## 5. 资源文件清单

### 5.1 `content/units/`

- `gojo_satoru.tres`

### 5.2 `content/skills/`

- `gojo_ao.tres`
- `gojo_aka.tres`
- `gojo_murasaki.tres`
- `gojo_reverse_ritual.tres`
- `gojo_unlimited_void.tres`

### 5.3 `content/effects/`

- `gojo_ao_speed_up.tres`
- `gojo_ao_mark_apply.tres`
- `gojo_ao_mark.tres`
- `gojo_aka_slow_down.tres`
- `gojo_aka_mark_apply.tres`
- `gojo_aka_mark.tres`
- `gojo_murasaki_conditional_burst.tres`
- `gojo_reverse_heal.tres`
- `gojo_domain_cast_buff.tres`
- `gojo_apply_domain_field.tres`
- `gojo_domain_action_lock.tres`
- `gojo_domain_expire_seal.tres`
- `gojo_domain_rollback.tres`
- `gojo_mugen_incoming_accuracy_down.tres`

### 5.4 `content/fields/`

- `gojo_unlimited_void_field.tres`

### 5.5 `content/passive_skills/`

- `gojo_mugen.tres`

### 5.6 已存在资源（无需新建）

- `content/combat_types/space.tres`
- `content/combat_types/psychic.tres`

---

## 6. 测试计划（gojo_suite）

| 编号 | 用例 | 验证点 |
|------|------|--------|
| 1 | 默认配招与候选池契约 | `skill_ids=[ao,aka,murasaki]`；`candidate_skill_ids` 含 `reverse_ritual` |
| 2 | 赛前换装 | `regular_skill_loadout_overrides` 可将 `reverse_ritual` 装入 |
| 3 | 苍命中后效果 | 自身 speed +1；目标挂 `gojo_ao_mark` |
| 4 | 赫命中后效果 | 目标 speed -1；目标挂 `gojo_aka_mark` |
| 5 | 茈无双标记 | 只有本体伤害；标记不被误清 |
| 6 | 茈双标记触发 | 追加伤害生效，并清除苍/赫标记 |
| 7 | 茈触发后无自伤 | 施法者 HP 不因反噬扣减 |
| 8 | 反转术式 | 回复 25% max_hp |
| 9 | MP 回复 | 每回合回复 14 |
| 10 | 无量空处 action_lock | 当回合敌方已排队技能/换人被 `cancelled_pre_start` |
| 11 | action_legality + wait | `deny all` 时 `wait` 仍可选 |
| 12 | 领域内必中 | `creator_accuracy_override=100` 生效 |
| 13 | 领域过期封印 | 下一回合苍/赫/茈被封印 1 回合体感 |
| 14 | 领域打破回滚 | 与过期封印同链 |
| 15 | 无下限非必中减命中 | 敌方 95 命中技能打五条悟按 85 判定 |
| 16 | 无下限不影响必中 | 敌方 100 命中技能（或领域覆盖必中）不降命中 |

---

## 7. 平衡性备注

| 维度 | 五条悟（本版） | 说明 |
|------|----------------|------|
| 爆发 | 中高 | 茈有条件追加，但去掉自伤摇摆链 |
| 控场 | 高 | 领域首回合锁行动 + 后续封印 |
| 生存 | 中 | 反转术式 + 稳定命中干扰，但不再“30% 改伤害为 1” |
| 资源节奏 | 中 | `init_mp=50`、`regen=14`，避免过快连续开大 |

本版目标不是最终平衡值，而是先落地“可施工、可验收、可迭代”的玩法闭环。
