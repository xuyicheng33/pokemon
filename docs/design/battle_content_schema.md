# Battle Content Schema（内容层）

本文件定义当前内容资源层 schema。当前正式方向是 **Godot Resource (`.tres`)**，不是 JSON。

## 1. 核心原则

- 内容层只描述静态定义，不保存运行时 HP/MP。
- 所有内容资源类都放在 `src/battle_core/content/`。
- 所有内容资源文件都放在 `content/`，不放进 `assets/`。
- 当前仓库已同时承载最小样例资源和宿傩原型内容包；内容 schema 需要能直接描述正式原型角色与技能。

## 2. 文件与目录映射

|目录|Resource 类|
|---|---|
|`content/battle_formats/`|`BattleFormatConfig`|
|`content/combat_types/`|`CombatTypeDefinition`|
|`content/units/`|`UnitDefinition`|
|`content/skills/`|`SkillDefinition`|
|`content/passive_skills/`|`PassiveSkillDefinition`|
|`content/passive_items/`|`PassiveItemDefinition`|
|`content/effects/`|`EffectDefinition`|
|`content/fields/`|`FieldDefinition`|
|`content/samples/`|最小样例资源|

## 3. 资源类字段

### 3.1 BattleFormatConfig

|字段|类型|说明|
|---|---|---|
|`format_id`|`String`|规则版本标识|
|`max_turn`|`int`|回合上限|
|`team_size`|`int`|队伍规模|
|`level`|`int`|固定等级|
|`combat_type_chart`|`Array[Resource]`|战斗属性克制表，元素类型固定为 `CombatTypeChartEntry`|

### 3.2 UnitDefinition

|字段|类型|说明|
|---|---|---|
|`id`|`String`|单位定义 ID|
|`display_name`|`String`|显示名|
|`base_hp`|`int`|基础 HP|
|`base_attack`|`int`|基础攻击|
|`base_defense`|`int`|基础防御|
|`base_sp_attack`|`int`|基础特攻|
|`base_sp_defense`|`int`|基础特防|
|`base_speed`|`int`|基础速度|
|`combat_type_ids`|`PackedStringArray`|战斗属性列表，允许 `0..2` 个|
|`skill_ids`|`PackedStringArray`|常规技能列表（固定 3 槽）|
|`ultimate_skill_id`|`String`|奥义技能 ID（不得出现在 `skill_ids`）|
|`passive_skill_id`|`String`|被动技能 ID|
|`passive_item_id`|`String`|被动持有物 ID|

### 3.3 SkillDefinition

|字段|类型|说明|
|---|---|---|
|`id`|`String`|技能 ID|
|`display_name`|`String`|技能名|
|`damage_kind`|`String`|`physical / special / none`|
|`power`|`int`|威力|
|`accuracy`|`int`|命中率|
|`mp_cost`|`int`|MP 消耗|
|`priority`|`int`|行动优先级|
|`combat_type_id`|`String`|技能战斗属性；空串表示无属性|
|`power_bonus_source`|`String`|额外威力来源；当前允许空串或 `mp_diff_clamped`|
|`targeting`|`String`|`enemy_active_slot / self / field`|
|`effects_on_cast_ids`|`PackedStringArray`|施放触发效果 ID|
|`effects_on_hit_ids`|`PackedStringArray`|命中触发效果 ID|
|`effects_on_miss_ids`|`PackedStringArray`|未命中触发效果 ID|
|`effects_on_kill_ids`|`PackedStringArray`|击杀触发效果 ID|

优先级硬约束：
- 普通技能（出现在任意单位 `skill_ids`）只能是 `-2..+2`。
- 奥义（被任意单位 `ultimate_skill_id` 引用）只能是 `+5/-5`。

### 3.4 PassiveSkillDefinition / PassiveItemDefinition

|字段|类型|说明|
|---|---|---|
|`id`|`String`|定义 ID|
|`display_name`|`String`|显示名|
|`trigger_names`|`PackedStringArray`|触发点列表|
|`effect_ids`|`PackedStringArray`|关联效果 ID 列表|

被动持有物额外补充：

|字段|类型|说明|
|---|---|---|
|`always_on_effect_ids`|`PackedStringArray`|常驻效果|
|`on_receive_effect_ids`|`PackedStringArray`|禁用字段（迁移过渡保留；非空即校验失败）|
|`on_turn_effect_ids`|`PackedStringArray`|回合节点效果|

### 3.5 EffectDefinition

|字段|类型|说明|
|---|---|---|
|`id`|`String`|效果 ID|
|`display_name`|`String`|显示名|
|`scope`|`String`|`self / target / field`|
|`duration_mode`|`String`|`turns / permanent`|
|`duration`|`int`|持续值|
|`decrement_on`|`String`|`turn_start / turn_end`（仅 `turns`）|
|`stacking`|`String`|`none / refresh / replace / stack`|
|`priority`|`int`|效果优先级|
|`trigger_names`|`PackedStringArray`|允许的触发点|
|`on_expire_effect_ids`|`PackedStringArray`|实例到期时追加执行的效果 ID|
|`payloads`|`Array[Resource]`|payload 资源数组|
|`persists_on_switch`|`bool`|离场是否保留|

### 3.6 FieldDefinition

|字段|类型|说明|
|---|---|---|
|`id`|`String`|field ID|
|`display_name`|`String`|显示名|
|`effect_ids`|`PackedStringArray`|field 内含效果 ID|
|`on_expire_effect_ids`|`PackedStringArray`|自然到期时触发的效果 ID|
|`on_break_effect_ids`|`PackedStringArray`|被覆盖或 creator 离场时触发的效果 ID|
|`creator_accuracy_override`|`int`|对 creator 生效的命中覆盖值；`-1` 表示不覆盖|

### 3.7 CombatTypeDefinition

|字段|类型|说明|
|---|---|---|
|`id`|`String`|战斗属性 ID|
|`display_name`|`String`|显示名|

### 3.8 CombatTypeChartEntry

|字段|类型|说明|
|---|---|---|
|`atk`|`String`|攻击侧 `combat_type` ID|
|`def`|`String`|防御侧 `combat_type` ID|
|`mul`|`float`|倍率；当前只允许 `2.0 / 1.0 / 0.5`|

## 4. Payload 资源

当前 payload 方向也用 `Resource` 表达，最小支持类型：

- `DamagePayload`
- `HealPayload`
- `ResourceModPayload`
- `StatModPayload`
- `ApplyEffectPayload`
- `RemoveEffectPayload`
- `ApplyFieldPayload`
- `RuleModPayload`
- `ForcedReplacePayload`

当前这些 payload 已接入运行时结算链；内容层负责声明，运行时负责统一调度与执行。

### 4.1 DamagePayload

|字段|类型|说明|
|---|---|---|
|`amount`|`int`|平伤数值，或在 `use_formula = true` 时作为公式威力|
|`use_formula`|`bool`|是否走简化伤害公式|
|`damage_kind`|`String`|仅 `use_formula = true` 时生效；允许 `physical / special`|
|`combat_type_id`|`String`|仅 `use_formula = false` 时生效；用于固定属性伤害克制|

### 4.2 HealPayload

|字段|类型|说明|
|---|---|---|
|`amount`|`int`|固定治疗量|
|`use_percent`|`bool`|是否改为按目标 `max_hp` 百分比结算|
|`percent`|`float`|百分比数值；`use_percent = true` 时生效|

### 4.3 RuleModPayload

|字段|类型|说明|
|---|---|---|
|`mod_kind / mod_op / value`|`Variant`|基础 rule_mod 定义；见 `docs/rules/06`|
|`dynamic_value_formula`|`String`|运行时求值公式；当前仅开放 `matchup_bst_gap_band`|
|`dynamic_value_thresholds`|`PackedInt32Array`|运行时区间阈值|
|`dynamic_value_outputs`|`PackedFloat32Array`|每个阈值对应输出值|
|`dynamic_value_default`|`float`|未命中任何阈值时的默认值|

实现状态说明（2026-03-25）：

- `forced_replace` payload 已在本轮收口计划中落地，当前仅覆盖 1v1 单 active 槽位链路。

## 5. 非目标

- 本轮不建立内容编辑器工具。
- 本轮不支持 JSON 与 `.tres` 双轨并存。
- 本轮不承诺角色/技能数值平衡，只保证 schema、加载期校验和运行时语义清晰。

## 6. 内容快照加载期校验

- 各类资源 ID / `format_id` 不能为空，且在各自类型内必须唯一；重复注册直接视为非法内容。
- `CombatTypeDefinition.id` 必须非空且唯一；`display_name` 不得为空。
- `UnitDefinition.combat_type_ids` 最多 2 个，不能重复、不能含空串，且必须命中已注册 `combat_type`。
- `SkillDefinition.combat_type_id` 可为空；非空时必须命中已注册 `combat_type`。
- `SkillDefinition.power_bonus_source` 当前只允许空串或 `mp_diff_clamped`。
- `BattleFormatConfig.combat_type_chart` 只接受 `CombatTypeChartEntry`；`atk / def` 必填且必须命中已注册 `combat_type`；`mul` 只允许 `2.0 / 1.0 / 0.5`；同一 `(atk, def)` pair 不得重复。
- 技能校验覆盖：`damage_kind` 白名单、`targeting` 白名单、`accuracy = 0..100`、`mp_cost >= 0`、伤害技能 `power > 0`、优先级范围与普通技能 / 奥义引用约束。
- 效果校验覆盖：`scope / duration_mode / stacking / trigger_names` 白名单（含 `on_matchup_changed`、`stack`）、效果优先级范围、payload 类型与跨资源引用完整性。
- field 校验覆盖：`creator_accuracy_override >= -1`，且 `on_expire_effect_ids / on_break_effect_ids` 引用必须存在。
- payload 额外校验覆盖：`DamagePayload.amount > 0`、`DamagePayload.use_formula = true` 时 `damage_kind in {physical, special}`、固定伤害仅在非公式模式下允许 `combat_type_id`、`HealPayload.amount > 0`、百分比治疗必须给出有效 `percent`、`ResourceModPayload.resource_key = mp`、`StatModPayload.stat_name` 只能是五维战斗属性之一、`RuleModPayload` 组合合法且动态公式 schema 完整、`ForcedReplacePayload.selector_reason` 非空。
- 内容快照校验失败直接 fail-fast，不进入运行态。

## 7. 运行前校验（BattleSetup）

- 同一 side 的队伍中，被动持有物 `passive_item_id` 不可重复。
- 该校验在战斗初始化前执行；失败直接 fail-fast，不进入运行态。
