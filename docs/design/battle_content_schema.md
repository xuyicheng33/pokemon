# Battle Content Schema（内容层）

本文件定义当前内容资源层 schema。当前正式方向是 **Godot Resource (`.tres`)**，不是 JSON。

## 1. 核心原则

- 内容层只描述静态定义，不保存运行时 HP/MP。
- 所有内容资源类都放在 `src/battle_core/content/`。
- 所有内容资源文件都放在 `content/`，不放进 `assets/`。
- 当前仓库已同时承载最小样例资源，以及 Gojo / Sukuna / Kashimo / Obito 四个正式角色内容包；内容 schema 需要能直接描述正式原型角色与技能。

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
|`content/samples/`|最小样例资源与样例对局资源|

## 3. 资源类字段

### 3.1 BattleFormatConfig

|字段|类型|说明|
|---|---|---|
|`format_id`|`String`|规则版本标识|
|`visibility_mode`|`String`|可见性模式标识；当前样例固定为 `prototype_full_open`|
|`max_turn`|`int`|回合上限|
|`team_size`|`int`|队伍规模|
|`level`|`int`|固定等级|
|`selection_deadline_ms`|`int`|每回合选指令截止时间（毫秒）|
|`max_chain_depth`|`int`|单条触发链允许的最大深度|
|`default_recoil_ratio`|`float`|默认动作命中后的反伤比例；当前样例默认 `0.25`|
|`domain_clash_tie_threshold`|`float`|领域对拼平 MP 时 challenger 判胜阈值；当前样例默认 `0.5`|
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
|`max_mp`|`int`|MP 上限|
|`init_mp`|`int`|战斗开始时 MP 初值|
|`regen_per_turn`|`int`|每回合 MP 回复基值|
|`ultimate_points_required`|`int`|施放奥义所需点数|
|`ultimate_points_cap`|`int`|奥义点上限|
|`ultimate_point_gain_on_regular_skill_cast`|`int`|每次开始施放常规技能时获得的奥义点|
|`combat_type_ids`|`PackedStringArray`|战斗属性列表，允许 `0..2` 个|
|`skill_ids`|`PackedStringArray`|默认装配的常规技能列表（固定 3 槽）|
|`candidate_skill_ids`|`PackedStringArray`|常规技能候选池；为空表示没有额外候选池|
|`ultimate_skill_id`|`String`|奥义技能 ID（不得出现在 `skill_ids`）|
|`passive_skill_id`|`String`|被动技能 ID|
|`passive_item_id`|`String`|被动持有物 ID|

补充语义：

- `skill_ids` 只表示默认装配的 3 个常规技能。
- `candidate_skill_ids` 只覆盖常规技能池，不包含奥义、被动、被动持有物。
- `candidate_skill_ids` 为空时，表示该单位没有额外候选池；赛前只能使用默认 `skill_ids`。
- `candidate_skill_ids` 非空时，必须完整包含默认 `skill_ids`，且不得包含 `ultimate_skill_id`。
- `ultimate_points_required / ultimate_points_cap / ultimate_point_gain_on_regular_skill_cast` 属于角色级奥义点 contract；若单位没有 `ultimate_skill_id`，这三项必须保持 `0`。
- 当前仓库里的宿傩已按正式字段落盘：默认技能组为 `解 / 捌 / 开`，`反转术式` 作为候选常规技能保留在 `candidate_skill_ids` 中。
- 当前仓库里的 Gojo 也已按正式字段落盘：默认技能组为 `苍 / 赫 / 茈`，奥义点 contract 为 `3 / 3 / 1`。
- 当前仓库里的 Kashimo 也已按正式字段落盘：默认技能组为 `雷拳 / 蓄电 / 回授电击`，`弥虚葛笼` 作为候选常规技能保留在 `candidate_skill_ids` 中，奥义点 contract 同样为 `3 / 3 / 1`。
- 当前仓库里以 Gojo / Sukuna / Kashimo 为原有正式角色基线，并已新增 Obito：默认技能组为 `求道焦土 / 阴阳遁 / 求道玉`，`六道十字奉火` 作为候选常规技能保留在 `candidate_skill_ids` 中，奥义 `十尾尾兽玉` 通过 `damage_segments` 表达十段伤害。

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
|`once_per_battle`|`bool`|是否属于整场仅能消耗一次的主动技能 / 奥义；默认 `false`|
|`power_bonus_source`|`String`|额外威力来源；当前允许空串、`mp_diff_clamped` 或 `effect_stack_sum`|
|`power_bonus_self_effect_ids`|`PackedStringArray`|`effect_stack_sum` 时统计自身 effect 层数的定义 ID 列表|
|`power_bonus_target_effect_ids`|`PackedStringArray`|`effect_stack_sum` 时统计目标 effect 层数的定义 ID 列表|
|`power_bonus_per_stack`|`int`|`effect_stack_sum` 时每层额外增加的威力|
|`execute_target_hp_ratio_lte`|`float`|可选；命中后、常规伤害前的目标血线处决阈值|
|`execute_required_total_stacks`|`int`|可选；触发处决所需的总层数门槛|
|`execute_self_effect_ids`|`PackedStringArray`|可选；处决层数统计时要读取的自身 effect 定义 ID|
|`execute_target_effect_ids`|`PackedStringArray`|可选；处决层数统计时要读取的目标 effect 定义 ID|
|`damage_segments`|`Array[Resource]`|可选；多段主动伤害定义，元素固定为 `SkillDamageSegment`|
|`targeting`|`String`|`enemy_active_slot / self / field`|
|`is_domain_skill`|`bool`|是否属于领域技能；用于合法性与领域冲突规则|
|`effects_on_cast_ids`|`PackedStringArray`|施放触发效果 ID|
|`effects_on_hit_ids`|`PackedStringArray`|命中触发效果 ID|
|`effects_on_miss_ids`|`PackedStringArray`|未命中触发效果 ID|
|`effects_on_kill_ids`|`PackedStringArray`|击杀触发效果 ID|

优先级硬约束：
- 普通技能（出现在任意单位 `skill_ids` 或 `candidate_skill_ids`）只能是 `-2..+2`。
- 奥义（被任意单位 `ultimate_skill_id` 引用）只能是 `+5/-5`。

补充语义：

- `execute_*` 当前固定表示“命中后、常规直接伤害前”的技能级处决 contract；满足时直接把目标 HP 置 `0`，并写一条追加 `[execute]` 标记的伤害日志。
- `damage_segments` 当前固定只描述“主动技能命中后的逐段直接伤害”；整招仍然只有一次命中判定与一条行动日志。
- 若 `damage_segments` 非空，顶层 `power` 必须固定为 `0`；真实伤害只读 `damage_segments`，不再把顶层 `power` 当伤害真相。
- `once_per_battle=true` 当前只属于主动技能 / 奥义内容字段；运行时使用 battle-scoped 消耗记录裁掉第二次合法性，不会额外暴露到 manager public snapshot。

### 3.3.1 SkillDamageSegment

|字段|类型|说明|
|---|---|---|
|`repeat_count`|`int`|该段重复次数；运行时会先展开成逐段伤害序列|
|`power`|`int`|该段威力|
|`combat_type_id`|`String`|该段的技能属性；空串表示无属性|
|`damage_kind`|`String`|该段攻防路径；当前只允许 `physical / special`|

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
|`scope`|`String`|`self / target / field / action_actor`|
|`duration_mode`|`String`|`turns / permanent`|
|`duration`|`int`|持续值|
|`decrement_on`|`String`|`turn_start / turn_end`（仅 `turns`）|
|`stacking`|`String`|`none / refresh / replace / stack`|
|`max_stacks`|`int`|仅 `stacking=stack` 时允许声明；`-1` 表示不封顶|
|`priority`|`int`|效果优先级|
|`trigger_names`|`PackedStringArray`|允许的触发点|
|`required_target_effects`|`PackedStringArray`|effect 级前置条件；仅 `scope=target` 允许声明|
|`required_target_same_owner`|`bool`|是否要求 `required_target_effects` 必须由当前 effect owner 本人施加；仅 `scope=target` 且 `required_target_effects` 非空时允许|
|`required_incoming_command_types`|`PackedStringArray`|仅 `trigger_names` 包含 `on_receive_action_hit / on_receive_action_damage_segment` 时允许声明；用于过滤来袭动作类型|
|`required_incoming_combat_type_ids`|`PackedStringArray`|仅 `trigger_names` 包含 `on_receive_action_hit / on_receive_action_damage_segment` 时允许声明；用于过滤来袭动作属性|
|`on_expire_effect_ids`|`PackedStringArray`|实例到期时追加执行的效果 ID|
|`payloads`|`Array[Resource]`|payload 资源数组|
|`persists_on_switch`|`bool`|离场是否保留|

补充语义：

- `required_target_effects` 只允许出现在 `scope=target` 的 effect 上。
- `required_target_same_owner=true` 时，前置检查除“目标持有这些 effect”外，还要求这些 effect instance 的 `meta.source_owner_id` 与当前 effect owner 一致；该字段当前统一通过 owner helper 生成/读取，缺失时运行时直接按 `invalid_state_corruption` 处理。
- `required_incoming_command_types / required_incoming_combat_type_ids` 只允许出现在 `trigger_names` 包含 `on_receive_action_hit / on_receive_action_damage_segment` 的 effect 上；动作类型当前只允许 `skill / ultimate`，属性过滤必须命中已注册 `combat_type`。
- `scope=action_actor` 只允许用于 `trigger_names = [on_receive_action_hit]` 的 effect；该作用域的单位目标固定读取 `ChainContext.action_actor_id`。
- `on_receive_action_damage_segment` 当前是多段主动伤害的逐段触发口；它和 `on_receive_action_hit` 并存，前者“每个成功结算段一次”，后者仍保持“整次来袭行动一次”。
- `max_stacks` 只允许和 `stacking=stack` 一起声明；`-1` 表示不封顶，正整数表示硬上限。
- `apply_field` payload requires `scope=field`；当前不允许把 `apply_field` 挂在 `self / target / action_actor` effect 上。
- `damage / heal / resource_mod / stat_mod / apply_effect / remove_effect` 只允许 `scope=self / target / action_actor`；`scope=field` 会在加载期直接判非法，避免运行时静默 no-op。
- 若目标前置或来袭动作过滤不满足，整条 effect 会在 payload 循环前直接跳过，不报错，也不写任何由该 effect 产生的 payload 日志。
- `stacking=refresh` 的正式语义固定为：保留同一 runtime instance，重置持续时间，并刷新来源元数据；effect 额外刷新 `meta`。

### 3.6 FieldDefinition

|字段|类型|说明|
|---|---|---|
|`id`|`String`|field ID|
|`display_name`|`String`|显示名|
|`field_kind`|`String`|`normal / domain`|
|`effect_ids`|`PackedStringArray`|field 内含效果 ID|
|`on_expire_effect_ids`|`PackedStringArray`|自然到期时触发的效果 ID|
|`on_break_effect_ids`|`PackedStringArray`|被覆盖或 creator 离场时触发的效果 ID|
|`creator_accuracy_override`|`int`|对 creator 生效的命中覆盖值；`-1` 表示不覆盖|

补充语义：

- field 的持续时间不写在 `FieldDefinition` 中；由施加该 field 的 `EffectDefinition.duration / decrement_on` 决定。
- `field_kind=domain` 的 field 仅与 `field_kind=domain` 触发领域对拼。
- `field_kind=domain` 可直接替换在场的 `normal` field。
- `normal` field 不得覆盖当前在场的 `domain` field。

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

`StatModPayload` 当前额外包含：

|字段|类型|说明|
|---|---|---|
|`stat_name`|`String`|能力项；当前只允许 `attack / defense / sp_attack / sp_defense / speed`|
|`stage_delta`|`int`|能力阶段变化量|
|`retention_mode`|`String`|`normal / persist_on_switch`；后者写入 `UnitState.persistent_stat_stages` 并跨非击倒离场保留|

### 4.4 ApplyFieldPayload

|字段|类型|说明|
|---|---|---|
|`field_definition_id`|`String`|要尝试施加的 field 定义 ID|
|`on_success_effect_ids`|`PackedStringArray`|只有 field 成功立住后才以 `field_apply_success` 追加执行的 effect ID|

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
|`percent_base`|`String`|百分比治疗基准；当前允许 `max_hp / missing_hp`|

### 4.3 RuleModPayload

|字段|类型|说明|
|---|---|---|
|`mod_kind / mod_op / value`|`Variant`|基础 rule_mod 定义；见 `docs/rules/06`|
|`persists_on_switch`|`bool`|非击倒离场时是否保留该 rule_mod；仅允许单位 owner 的 `self / target` 声明|
|`stacking_source_key`|`String`|`mp_regen / incoming_accuracy / nullify_field_accuracy / incoming_action_final_mod / incoming_heal_final_mod` 的来源分组键；留空时按共享兜底口径生成|
|`dynamic_value_formula`|`String`|运行时求值公式；当前仅开放 `matchup_bst_gap_band`，且只允许单位 owner 的数值 `rule_mod` 使用|
|`dynamic_value_thresholds`|`PackedInt32Array`|运行时区间阈值|
|`dynamic_value_outputs`|`PackedFloat32Array`|每个阈值对应输出值；`mp_regen` 当前要求这些值都必须是整数值|
|`dynamic_value_default`|`float`|未命中任何阈值时的默认值；`mp_regen` 当前要求该值也必须是整数值|
|`required_incoming_command_types`|`PackedStringArray`|仅 `incoming_action_final_mod` 可声明；当前只允许 `skill / ultimate`|
|`required_incoming_combat_type_ids`|`PackedStringArray`|仅 `incoming_action_final_mod` 可声明；用于过滤来袭技能/奥义属性|

补充约束：

- `mod_kind` 当前实现白名单以 `docs/rules/06_effect_schema_and_extension.md` 为准，当前包含 `final_mod / mp_regen / action_legality / incoming_accuracy / nullify_field_accuracy / incoming_action_final_mod / incoming_heal_final_mod`。
- `action_legality` 是当前覆盖技能 / 奥义 / 换人的正式合法性读取点；当前显式 managed action 白名单固定为 `skill / ultimate / switch`，`wait / resource_forced_default / surrender` 永不受其影响。
- `matchup_bst_gap_band` 当前按双方 `max_hp + attack + defense + sp_attack + sp_defense + speed + max_mp` 的绝对差求值，`max_mp` 视为正式第七维。
- `mp_regen.value` 当前要求为 `int`；若启用 `dynamic_value_formula`，其输出和默认值也必须是整数值，运行时遇到非整数结果会直接视为 `invalid_rule_mod_definition`。
- `incoming_accuracy.value` 当前要求为 `int`，并且禁止 `dynamic_value_formula`。
- `nullify_field_accuracy.value` 当前要求为 `bool`，语义固定为“忽略领域附加必中，不影响技能原生命中率”。
- `incoming_action_final_mod.value` 当前要求为数值；`required_incoming_command_types / required_incoming_combat_type_ids` 也只允许挂在这一类 rule_mod 上。
- `incoming_heal_final_mod.value` 当前要求为数值，并且禁止 `dynamic_value_formula`；目标侧治疗末端读取只允许通过这一类 rule_mod 接入。
- `persists_on_switch=true` 的 rule_mod 只允许 `scope=self/target`；`field` scope 非法。
- `mp_regen / incoming_accuracy / nullify_field_accuracy / incoming_action_final_mod / incoming_heal_final_mod` 当前正式支持多来源并存；来源分组优先级固定为 `stacking_source_key -> effect_definition_id -> source_instance_id`，同来源组内继续按 `none / refresh / replace` 处理。
- `refresh` 的正式语义固定为“同实例续命并刷新来源元数据”；当前 effect / rule_mod 两条链保持一致，不再允许出现一边只续命、一边还改来源的分叉口径。

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
- `UnitDefinition.skill_ids` 必须固定为 3 个已注册常规技能，且不得与 `ultimate_skill_id` 重叠。
- `UnitDefinition.candidate_skill_ids` 为空时表示没有额外候选池；非空时必须满足：长度至少 3、不能重复、不能含空串、必须命中已注册常规技能、必须完整包含默认 `skill_ids`、不得包含 `ultimate_skill_id`。
- `UnitDefinition.ultimate_points_required / ultimate_points_cap / ultimate_point_gain_on_regular_skill_cast` 必须 `>= 0`，且 `ultimate_points_cap >= ultimate_points_required`；没有 `ultimate_skill_id` 的单位不得声明非零奥义点配置。
- `SkillDefinition.combat_type_id` 可为空；非空时必须命中已注册 `combat_type`。
- `SkillDefinition.power_bonus_source` 当前只允许 `PowerBonusResolver` 已注册的来源；正式主线现阶段开放空串、`mp_diff_clamped` 与 `effect_stack_sum`。
- `SkillDefinition.power_bonus_source = effect_stack_sum` 时，`power_bonus_self_effect_ids / power_bonus_target_effect_ids` 至少有一侧非空，且 `power_bonus_per_stack > 0`。
- `BattleFormatConfig.default_recoil_ratio / domain_clash_tie_threshold` 必须落在 `0.0..1.0`。
- `BattleFormatConfig.combat_type_chart` 只接受 `CombatTypeChartEntry`；`atk / def` 必填且必须命中已注册 `combat_type`；`mul` 只允许 `2.0 / 1.0 / 0.5`；同一 `(atk, def)` pair 不得重复。
- 技能校验覆盖：`damage_kind` 白名单、`targeting` 白名单、`accuracy = 0..100`、`mp_cost >= 0`、伤害技能 `power > 0`、优先级范围与普通技能 / 奥义引用约束。
- `SkillDefinition.execute_*` 的加载期校验固定包含：血线阈值必须落在 `0.0..1.0`、层数门槛不得为负、层数门槛存在时必须至少声明一侧 `execute_*_effect_ids`，且技能本身必须是可对敌造成伤害的主动技能。
- `SkillDefinition.damage_segments` 的加载期校验固定包含：`targeting=enemy_active_slot`、顶层 `damage_kind != none`、顶层 `power = 0`、每段 `repeat_count > 0`、每段 `power > 0`、每段 `damage_kind in {physical, special}`、每段属性必须命中已注册 `combat_type` 或为空串。
- `SkillDefinition.is_domain_skill` 与其实际 `apply_field` 目标必须一致：领域技能必须施加 `field_kind=domain` 的 field；施加 `domain` field 的技能也必须声明 `is_domain_skill=true`。
- 效果校验覆盖：`scope / duration_mode / stacking / trigger_names` 白名单（含 `on_matchup_changed`、`on_receive_action_hit`、`on_receive_action_damage_segment`、`stack`）、效果优先级范围、`max_stacks` 合法性、payload 类型与跨资源引用完整性。
- `ApplyFieldPayload.on_success_effect_ids` 的引用必须全部存在，且被引用 effect 必须声明 `trigger_names` 包含 `field_apply_success`。
- `required_target_effects` 的加载期校验固定包含：非空项、去重、引用存在性、以及 `scope=target` 约束；若 `required_target_same_owner=true`，则同时要求 `required_target_effects` 非空且 effect `scope=target`。
- `required_incoming_command_types / required_incoming_combat_type_ids` 的加载期校验固定包含：只允许 `on_receive_action_hit / on_receive_action_damage_segment` effect 使用、不得含空项、动作类型只允许 `skill / ultimate`、属性过滤必须命中已注册 `combat_type`。
- field 校验覆盖：`field_kind in {normal, domain}`、`creator_accuracy_override >= -1`，且 `on_expire_effect_ids / on_break_effect_ids` 引用必须存在。
- payload 额外校验覆盖：`DamagePayload.amount > 0`、`DamagePayload.use_formula = true` 时 `damage_kind in {physical, special}`、固定伤害仅在非公式模式下允许 `combat_type_id`、`HealPayload.amount > 0`、百分比治疗必须给出有效 `percent` 且 `percent_base in {max_hp, missing_hp}`、`ResourceModPayload.resource_key = mp`、`StatModPayload.stat_name` 只能是五维战斗属性之一、`StatModPayload.retention_mode in {normal, persist_on_switch}`、`RuleModPayload` 组合合法且动态公式 schema 完整、`ForcedReplacePayload.selector_reason` 非空。
- 正式角色的跨资源共享不变量，当前统一由 `ContentSnapshotFormalCharacterValidator` 编排；`config/formal_character_manifest.json` 是唯一人工维护配置，顶层固定包含 `characters / matchups / pair_interaction_cases` 三桶。`characters[*]` 仍承载完整角色条目，但合同固定拆成两份视图：runtime 视图只要求 `character_id / unit_definition_id / formal_setup_matchup_id / required_content_paths`，以及按需补的 `content_validator_script_path`；delivery/test 视图固定要求 `character_id / display_name / design_doc / adjustment_doc / surface_smoke_skill_id / suite_path / required_suite_paths / required_test_names / shared_capability_ids / design_needles / adjustment_needles`。运行时、测试、gate 与文档都只从 manifest domain model 派生各自视图，不再各自拼 runtime / delivery / matchup 三份事实。directed pair surface smoke 不再手写 catalog，而是运行时按 `matchups + characters[*].surface_smoke_skill_id` 自动生成。runtime loader 由 `src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_registry.gd` 读取 manifest 角色条目，但只负责校验 runtime 视图与 validator 路径存在性；delivery/test 字段漂移不得拖死 runtime loader。真正的 validator 实例化延迟到 `ContentSnapshotFormalCharacterValidator.validate()`，并且只针对当前 snapshot 实际出现的正式角色执行。`design_needles / adjustment_needles` 固定为显式 anchor id，`required_test_names` 只保留角色私有 runtime / validator 坏例锚点，shared pair 覆盖统一交给 manifest 的 `matchups / pair_interaction_cases` + shared gate；`pair_interaction_cases[*]` 还必须显式携带 `test_name / scenario_id / matchup_id / character_ids[2] / battle_seed`。repo consistency gate 负责锁 manifest 完整性、资源/文档/suite 可达性、pair 覆盖、validator 坏例锚点与文档锚点。
- 共享能力目录的唯一人工维护配置固定为 `config/formal_character_capability_catalog.json`；每个 entry 都必须显式登记 `capability_id / rule_doc_paths / consumer_character_ids / required_suite_paths / coverage_needles / stop_and_specialize_when`。`shared_capability_ids` 只允许引用这份 catalog 已登记的入口，manifest 声明的消费者、catalog 的 `consumer_character_ids`、角色回挂的共享 suite，以及内容/validator/文档里的实际使用证据必须双向对齐；未登记就消费、或登记后没有真实使用证据，repo consistency gate 都会直接失败。
- 内容快照校验失败直接 fail-fast，不进入运行态。

## 7. 运行前校验（BattleSetup）

- `battle_setup.sides[*].side_id` 必须非空，且在同一场 battle setup 内唯一。
- 同一 side 的队伍中，被动持有物 `passive_item_id` 不可重复。
- 同一 side 的队伍中，`unit_definition_id` 不可重复；若同队出现重复角色，建局前直接 fail-fast。
- `SideSetup.regular_skill_loadout_overrides` 固定为 `Dictionary<int, PackedStringArray>`：
  - 键固定为队伍槽位下标 `0..team_size-1`；覆盖语义绑定的是“队伍槽位”，不是 `unit_definition_id`。
  - 值固定为该槽位单位本场实际装配的 3 个常规技能。
- `regular_skill_loadout_overrides` 校验规则固定为：
  - 同一 side 的 `unit_definition_ids` 不能重复。
  - 槽位键必须是 `int`，且必须命中当前队伍槽位。
  - 覆盖列表必须正好 3 个，不能重复。
  - 若该单位 `candidate_skill_ids` 为空，覆盖值必须与默认 `skill_ids` 完全相等。
  - 若该单位 `candidate_skill_ids` 非空，覆盖值必须是 `candidate_skill_ids` 的子集。
  - 当前不支持通过 setup 覆盖奥义、被动或被动持有物。
- 该校验在战斗初始化前执行；失败直接 fail-fast，不进入运行态。
