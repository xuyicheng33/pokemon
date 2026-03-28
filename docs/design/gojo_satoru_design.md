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

- 本场装配通过 `SideSetup.regular_skill_loadout_overrides` 决定（该字段属于 `SideSetup`，不属于 `UnitDefinition`）。
- 当 `candidate_skill_ids` 非空时，允许赛前从候选池选 3 个写入运行时配招。

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

- EffectDefinition：`scope=target`, `duration_mode=permanent`, `decrement_on=""`, `stacking=none`, `trigger_names=[]`
- `required_target_effects = ["gojo_ao_mark", "gojo_aka_mark"]`
- payload 顺序：
1. `damage(use_formula=true, amount=32, damage_kind=special)`（条件追加一段伤害；`amount` 在 `use_formula=true` 下作为公式威力）
2. `remove_effect(gojo_ao_mark)`
3. `remove_effect(gojo_aka_mark)`

补充说明：

- 此处不额外写 `combat_type_id`：`DamagePayload.use_formula=true` 且处于技能链中时，类型继承链技能 `gojo_murasaki` 的 `combat_type_id=space`。

语义：

- 条件满足：追加爆发并消耗双标记。
- 条件不满足：只结算茈本体伤害，不做额外动作。
- **不做任何反噬/自伤**。
- 边界：若追加伤害把目标直接打到 `hp<=0`，后续 `remove_effect` 会因目标不再满足 `ACTIVE && hp>0` 被静默跳过，不会报错；这属于预期行为。

### 2.6 标记 Effect 明细（避免实现歧义）

`gojo_ao_mark_apply` / `gojo_aka_mark_apply`（施加标记）：

- EffectDefinition：`scope=target`, `duration_mode=permanent`, `decrement_on=""`, `stacking=none`, `trigger_names=[]`
- payload：`apply_effect(gojo_ao_mark)` 或 `apply_effect(gojo_aka_mark)`

`gojo_ao_mark` / `gojo_aka_mark`（纯标记本体）：

- EffectDefinition：`scope=self`, `duration_mode=turns`, `duration=3`, `decrement_on=turn_end`, `stacking=refresh`, `trigger_names=[]`, `payloads=[]`, `persists_on_switch=false`
- 说明：纯标记 effect 无 payload，不直接产生数值结算；仅用于条件判定。
- 玩法语义：`persists_on_switch=false` 代表“换人会清标记”，不能通过换手跨单位保留苍/赫铺垫。

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

- `gojo_domain_action_lock` 资源口径：
1. EffectDefinition：`scope=target`, `duration_mode=permanent`, `decrement_on=""`, `stacking=none`
2. payload：`rule_mod(mod_kind=action_legality, mod_op=deny, value=all, scope=target, duration_mode=turns, duration=1, decrement_on=turn_end, stacking=replace)`

- `gojo_domain_expire_seal` 资源口径：
1. EffectDefinition：`scope=self`, `duration_mode=permanent`, `decrement_on=""`, `stacking=none`
2. payload（3 条）：`rule_mod(mod_kind=action_legality, mod_op=deny, value=gojo_ao/gojo_aka/gojo_murasaki, scope=self, duration_mode=turns, duration=2, decrement_on=turn_end, stacking=replace)`

- `gojo_domain_rollback` 资源口径：
1. EffectDefinition：`scope=self`, `duration_mode=permanent`, `decrement_on=""`, `stacking=none`
2. payload（3 条）：与 `gojo_domain_expire_seal` 相同，仅事件来源为 `on_break`

- 本版明确**不**添加 `stat_mod(sp_attack, -1)` 回退；`gojo_domain_cast_buff(+1)` 作为独立收益，不和 field break 绑定反向回滚。
- 过期与打破在当前 field 生命周期实现中互斥，不会同一实例同时触发两条链。

时间线（`gojo_domain_expire_seal`，`duration=2, decrement_on=turn_end`）：

1. `T` 回合 `turn_end`：field 到期，触发封印 effect，3 条 `rule_mod` 创建时 `remaining=2`。
2. 同一个 `T` 回合 `turn_end`：`rule_mod` 扣减节点执行，`remaining: 2 -> 1`。
3. `T+1` 回合整轮（选择 + 执行）：封印仍然生效（玩家体感“被封 1 回合”）。
4. `T+1` 回合 `turn_end`：再次扣减，`remaining: 1 -> 0`，实例移除。

待决策（本版不强行拍板）：

- `gojo_domain_rollback` 在“creator 已离场/倒下导致 field_break”场景下是否仍应处罚，目前不在本版可施工口径内；后续单独冻结语义后再落实现。

---

## 3. 被动技能：无下限（Mugen）

### 3.1 玩法语义

- 当敌方对五条悟发动技能或奥义时：
1. 先按现有流程得到 `resolved_accuracy`（技能精度 + 领域覆盖等）。
2. 若 `resolved_accuracy >= 100`，视为必中，**无下限不生效**。
3. 若 `resolved_accuracy < 100`，且目标是五条悟，则本次命中率再减 `10` 后再 roll。

### 3.2 资源定义

`gojo_mugen`（PassiveSkillDefinition）：

- `trigger_names = ["on_enter"]`
- `effect_ids = ["gojo_mugen_incoming_accuracy_down"]`

`gojo_mugen_incoming_accuracy_down`（EffectDefinition）：

- EffectDefinition：`scope=self`, `duration_mode=permanent`, `decrement_on=""`, `stacking=none`, `trigger_names=[]`
- payload：`rule_mod(mod_kind="incoming_accuracy", mod_op="add", value=-10, scope="self", duration_mode="permanent", decrement_on="turn_end", stacking="none")`

说明：

- 无下限改成稳定干扰命中，不再使用概率触发，也不再改写伤害值。
- 字段约束是**双层**的：EffectDefinition 层（permanent）要求 `decrement_on=""`；RuleModPayload 层仍要求显式 `turn_start/turn_end`，因此 payload 内保留 `decrement_on="turn_end"`。
- `LeaveService` 会在单位离场时清空 `rule_mod_instances`，所以无下限必须挂在 `on_enter`，确保每次入场都重新施加。
- 运行时语义补充：对 `duration_mode=permanent` 的 RuleModPayload，`decrement_on` 不参与扣减（`remaining=-1` 不会递减）；该字段仅用于满足 payload 校验约束。

---

## 4. 引擎改动范围（可施工）

### 4.1 `action_legality`（替代 `skill_legality`）

`rule_mod.mod_kind` 从 `skill_legality` 迁到 `action_legality`，`mod_op` 仍为 `allow / deny`，`value` 支持：

- `"all"` / `"skill"` / `"ultimate"` / `"switch"` / 具体 `skill_id`

补充：

- `allow` 与 `deny` 使用同一套 `value` 取值范围。
- `value="all"` 仅作用于技能/奥义/换人，不作用于 `wait`。

迁移策略（避免一次性硬切导致旧内容失效）：

1. **阶段 A（兼容期）**：新增 `action_legality` 并保留 `skill_legality` 兼容读取；
2. **阶段 B（迁移期）**：迁移 `content/effects/sukuna_domain_expire_seal.tres` 和相关测试；
3. **阶段 C（收口期）**：移除 `skill_legality` 常量、校验与读取路径。

实现清单（阶段 A 起步）：

- `content_schema.gd`：新增 `RULE_MOD_ACTION_LEGALITY`
- `content_payload_validator.gd`：`_validate_rule_mod_payload()` 新增 `action_legality` 白名单与 `mod_op` 校验
- `rule_mod_service.gd`：
1. `STACKING_KEY_SCHEMA_BY_KIND` 增加 `RULE_MOD_ACTION_LEGALITY`
2. `_validate_rule_mod_payload()` 增加 `action_legality`
3. 新增 `is_action_allowed(battle_state, owner_id, action_type, skill_id="")`
- `legal_action_service.gd`：技能、奥义、换人都改读 `is_action_allowed`
- `action_executor.gd`：`_can_start_action()` 执行前复检 `is_action_allowed`，覆盖排队后中途上锁场景
- `content/effects/sukuna_domain_expire_seal.tres` 与相关测试：迁移为 `action_legality`

兼容期读取策略（必须写死）：

- `is_action_allowed` 在阶段 A 同时读取两类实例：`action_legality` 与旧 `skill_legality`。
- 混合实例统一按现有 rule_mod 排序链处理（`priority -> source_order_speed_snapshot -> source_kind_order -> source_instance_id -> instance_id`），避免新旧规则并存时顺序漂移。

`action_legality` stacking key schema：

- `["mod_kind", "scope", "owner_scope", "owner_id", "mod_op", "value"]`
- 说明：`value=all`、`value=switch`、`value=具体skill_id` 必须是不同 key，避免互相覆盖。

匹配矩阵（必须写死）：

| 当前动作 | 命中的 `value` |
|---|---|
| `skill(skill_id=X)` | `all`、`skill`、`X` |
| `ultimate(skill_id=Y)` | `all`、`ultimate`、`Y` |
| `switch` | `all`、`switch` |
| `wait` | 不命中任何 `action_legality`（恒合法） |

最终判定顺序（必须写死）：

1. 默认 `allowed = true`。
2. 兼容期统一收集 `action_legality + skill_legality` 两类实例，并走同一排序链（`priority -> source_order_speed_snapshot -> source_kind_order -> source_instance_id -> instance_id`）。
3. 逐条判断是否命中当前动作；命中则按 `deny => allowed=false`、`allow => allowed=true` 覆盖。
4. 最终结果以“最后一条命中的 rule_mod”状态为准（last-write-wins）。
5. `skill_legality` 兼容读取只参与 `skill/ultimate` 两类动作；`switch/wait` 不读取旧 `skill_legality`。

### 4.2 `required_target_effects`

`effect_definition.gd` 新增：

```gdscript
@export var required_target_effects: PackedStringArray = PackedStringArray()
```

执行规则：

- `PayloadExecutor.execute_effect_event()` 在 payload 循环前做 effect 级前置检查。
- 目标固定取 `effect_event.chain_context.target_unit_id` 对应单位；若为空、单位不存在、或缺少任一 required effect，则整条 effect 跳过。
- 不满足则跳过该 effect，不报错。
- 安全前提：只要前置检查实现正确，`remove_effect` 不会走到“目标标记不存在”分支，自然不会触发 `INVALID_EFFECT_REMOVE_AMBIGUOUS`。

加载期 fail-fast（必须补齐）：

- `content_snapshot_validator.gd` 必须校验 `required_target_effects`：每个 effect id 非空、不得重复、且必须命中 `content_index.effects`。
- 任一引用非法时，内容加载期直接失败；禁止把错误引用留到运行期再“静默跳过”。
- `content schema / rules` 文档必须同步增加该字段定义，避免实现与规范分叉。
- 测试必须包含“坏引用触发加载期失败”的坏例用例。

该能力仅用于茈的条件追加爆发，不引入 `action_tags`。

### 4.3 `incoming_accuracy`（无下限命中干扰）

新增 rule_mod kind：

- `incoming_accuracy`

实现点：

- `content_schema.gd`：新增 `RULE_MOD_INCOMING_ACCURACY`
- `content_payload_validator.gd`：`_validate_rule_mod_payload()` 增加 `incoming_accuracy` 白名单与 `mod_op=add/set` 约束
- `rule_mod_service.gd`：
1. `STACKING_KEY_SCHEMA_BY_KIND` 增加 `RULE_MOD_INCOMING_ACCURACY`
2. `_validate_rule_mod_payload()` 增加 `incoming_accuracy`
3. 新增 `resolve_incoming_accuracy(battle_state, target_owner_id, base_accuracy)`
- `action_cast_service.gd`：`resolve_hit` 在 field 覆盖后、`roll_hit` 前读取目标侧 `incoming_accuracy`
- `action_executor.gd`：调用 `resolve_hit` 时补传目标（建议签名改为 `resolve_hit(command, skill_definition, target, battle_state, content_index)`）

约束：

- 只在 `resolved_accuracy < 100` 时读取（必中不受影响）。
- 最终命中率 clamp 到 `0~99`。
- `0~99` 是刻意设计：`incoming_accuracy` 不得把命中改成“硬必中”；`100` 只由技能本体或 field 覆盖产生。
- 读取范围必须收紧为“敌方来袭技能/奥义”：
1. 仅当 `command_type in {skill, ultimate}` 且技能 `targeting=enemy_active_slot` 时才可读取。
2. 仅当 `target` 为敌方 active 单位时读取；`self/field/none` 与无目标动作一律跳过。
3. `switch / wait / resource_forced_default` 一律不读取 `incoming_accuracy`。

`incoming_accuracy` stacking key schema：

- `["mod_kind", "scope", "owner_scope", "owner_id", "mod_op"]`
- 说明：不按 `value` 分键，沿用 `final_mod/mp_regen` 的同类 schema。

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
| 2 | 赛前换装 | `SideSetup.regular_skill_loadout_overrides` 可将 `reverse_ritual` 装入 |
| 3 | 苍命中后效果 | 自身 speed +1；目标挂 `gojo_ao_mark` |
| 4 | 赫命中后效果 | 目标 speed -1；目标挂 `gojo_aka_mark` |
| 5 | 茈无双标记 | 只有本体伤害；标记不被误清 |
| 6 | 茈双标记触发 | 追加伤害生效，并清除苍/赫标记 |
| 7 | 茈触发后无自伤 | 施法者 HP 不因反噬扣减 |
| 8 | 反转术式 | 回复 25% max_hp |
| 9 | MP 回复 | 每回合回复 14 |
| 10 | 无下限重入场 | 五条悟离场再入场后，`incoming_accuracy -10` 仍生效 |
| 11 | 无量空处 action_lock | 当回合敌方已排队技能/换人被 `cancelled_pre_start` |
| 12 | action_legality + wait | `deny all` 时 `wait` 仍可选 |
| 13 | 领域内必中 | `creator_accuracy_override=100` 生效 |
| 14 | 领域过期封印 | 下一回合苍/赫/茈被封印 1 回合体感 |
| 15 | 领域打破回滚 | 与过期封印同链 |
| 16 | 无下限非必中减命中 | 仅当 `resolved_accuracy < 100` 时生效；敌方 95 命中技能打五条悟按 85 判定 |
| 17 | 无下限不影响必中 | 敌方 100 命中技能（或领域覆盖必中）不降命中 |
| 18 | 标记随换人清除 | 目标换下后 `gojo_ao_mark/gojo_aka_mark` 被移除（`persists_on_switch=false`） |
| 19 | 茈追加击杀边界 | 追加段把目标打到 `hp<=0` 时，后续 `remove_effect` 静默跳过且不产生 `invalid_battle` |
| 20 | required_target_effects 坏引用 | `required_target_effects` 指向不存在 effect 时内容加载期直接失败 |
| 21 | incoming_accuracy 作用域收紧 | `self/field/none` 目标技能、`switch/wait/resource_forced_default` 不读取 `incoming_accuracy` |
| 22 | action_legality 匹配矩阵 | `deny all + allow switch`、`deny skill + allow gojo_ao`、`deny ultimate + allow ultimate_id` 结果与矩阵一致 |
| 23 | 兼容期双口径共读 | 阶段 A 下 `action_legality + skill_legality` 同排序链读取，不得因 mod_kind 不同而顺序漂移 |
| 24 | 领域后摇时序 | 验证“`duration=2 + turn_end` 在 field 过期当回合先挂后扣，玩家体感为下一整回合封印” |

---

## 7. 平衡性备注

| 维度 | 五条悟（本版） | 说明 |
|------|----------------|------|
| 爆发 | 中高 | 茈有条件追加，但去掉自伤摇摆链 |
| 控场 | 高 | 领域首回合锁行动 + 后续封印 |
| 生存 | 中 | 反转术式 + 稳定命中干扰，但不再“30% 改伤害为 1” |
| 资源节奏 | 中 | `init_mp=50`、`regen=14`，避免过快连续开大 |

本版目标不是最终平衡值，而是先落地“可施工、可验收、可迭代”的玩法闭环。

## 8. 待你拍板（本轮不改）

| 议题 | 说明 |
|---|---|
| rollback 在 creator 离场/倒下时是否仍处罚 | 当前文档不强行冻结该语义，等你定后再收口实现 |
| 领域后摇是否允许 `reverse_ritual` 绕开 | 当前保留为待决策项，不擅自改成“封已装配全部常规技能” |
| 领域强度是否继续下调 | 属于平衡取舍，不属于本轮“明显错误修正”范围 |
