# Battle Content Schema（内容层）

本文件定义当前内容资源层 schema。当前正式方向是 **Godot Resource (`.tres`)**，不是 JSON。

## 1. 核心原则

- 内容层只描述静态定义，不保存运行时 HP/MP。
- 所有内容资源类都放在 `src/battle_core/content/`。
- 所有内容资源文件都放在 `content/`，不放进 `assets/`。
- 本轮不设计具体角色和技能数值，只建立资源类型和最小样例结构。

## 2. 文件与目录映射

|目录|Resource 类|
|---|---|
|`content/battle_formats/`|`BattleFormatConfig`|
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
|`stacking`|`String`|`none / refresh / replace`|
|`priority`|`int`|效果优先级|
|`trigger_names`|`PackedStringArray`|允许的触发点|
|`payloads`|`Array[Resource]`|payload 资源数组|
|`persists_on_switch`|`bool`|离场是否保留|

### 3.6 FieldDefinition

|字段|类型|说明|
|---|---|---|
|`id`|`String`|field ID|
|`display_name`|`String`|显示名|
|`effect_ids`|`PackedStringArray`|field 内含效果 ID|

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

本轮只建立统一基类与方向，不实现具体结算逻辑。

实现状态说明（2026-03-25）：

- `forced_replace` payload 将在本轮收口计划的后续批次落地；当前内容快照里不应提前引用未接线类型。

## 5. 非目标

- 本轮不建立内容编辑器工具。
- 本轮不支持 JSON 与 `.tres` 双轨并存。
- 本轮不做角色/技能平衡设计。

## 6. 运行前校验（BattleSetup）

- 同一 side 的队伍中，被动持有物 `passive_item_id` 不可重复。
- 该校验在战斗初始化前执行；失败直接 fail-fast，不进入运行态。
