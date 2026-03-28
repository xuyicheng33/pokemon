# Battle Runtime Model（运行时模型）

本文件定义战斗运行态结构。运行态对象必须是强类型对象，不以裸 `Dictionary` 作为正式跨模块接口。

## 1. 核心原则

- `BattleState` 是一场战斗的唯一真相。
- 所有服务都读写同一个 `BattleState` 实例，不自行缓存分叉副本。
- 运行态字段分为“持久字段”和“回合临时字段”；临时字段必须在明确节点重置。

## 2. Runtime 文件清单

|文件|职责|
|---|---|
|`battle_state.gd`|整场战斗运行态根对象|
|`side_state.gd`|单边队伍运行态|
|`unit_state.gd`|单单位运行态|
|`field_state.gd`|全场 field 运行态|
|`effect_instance.gd`|持续效果实例|
|`rule_mod_instance.gd`|规则修正实例|

## 3. 枚举与常量

|常量类|用途|
|---|---|
|`BattlePhases`|`battle_init / turn_start / selection / queue_lock / execution / turn_end / victory_check / finished`|
|`LeaveStates`|`active / fainted_pending_leave / left`|

## 4. BattleState

|字段|类型|说明|
|---|---|---|
|`battle_id`|`String`|本场战斗唯一 ID|
|`seed`|`int`|随机种子|
|`rng_profile`|`String`|随机策略配置 ID（用于区分 RNG 规则）|
|`format_id`|`String`|战斗格式定义 ID|
|`visibility_mode`|`String`|当前战斗可见性模式（由 `BattleFormatConfig.visibility_mode` 初始化）|
|`max_turn`|`int`|回合上限|
|`max_chain_depth`|`int`|事件链最大深度|
|`battle_level`|`int`|本场统一等级快照|
|`selection_deadline_ms`|`int`|选择阶段超时阈值（毫秒）|
|`turn_index`|`int`|当前回合号，初始化后从 `1` 开始|
|`phase`|`String`|当前阶段，必须取自 `BattlePhases`|
|`sides`|`Array[SideState]`|双方运行态|
|`field_state`|`FieldState` 或 `null`|当前生效的 field|
|`pending_effect_queue`|`Array[EffectEvent]`|当前待处理效果队列|
|`chain_context`|`ChainContext`|当前链上下文|
|`battle_result`|`BattleResult`|战斗结果|
|`rng_stream_index`|`int`|当前随机消费序号快照|
|`fatal_damage_records_by_target`|`Dictionary`|目标维度的致命伤害归因记录（击倒链读取）|
|`field_rule_mod_instances`|`Array[RuleModInstance]`|挂载在全场作用域的规则修正实例|
|`last_matchup_signature`|`String`|最近一次已结算 `on_matchup_changed` 的对位签名，用于去重|
|`pre_applied_turn_start_regen_turn_index`|`int`|建局后为首回合选指预先应用过 `turn_start` 回蓝时写入对应回合号；首个 `run_turn` 用它避免重复回蓝|

## 5. SideState

|字段|类型|说明|
|---|---|---|
|`side_id`|`String`|`P1 / P2`|
|`team_units`|`Array[UnitState]`|全部队伍成员|
|`active_slots`|`Dictionary`|当前在场槽位映射（当前基线仅使用 `active_0`）|
|`bench_order`|`Array[String]`|bench 顺序|
|`public_labels`|`Dictionary`|稳定公开标签映射|
|`selection_state`|`SelectionState`|本回合选择态|

## 6. UnitState

|字段|类型|说明|
|---|---|---|
|`unit_instance_id`|`String`|实例 ID|
|`public_id`|`String`|公开编号|
|`definition_id`|`String`|内容定义 ID|
|`display_name`|`String`|展示名|
|`max_hp`|`int`|最大 HP|
|`current_hp`|`int`|当前 HP|
|`max_mp`|`int`|最大 MP|
|`current_mp`|`int`|当前 MP|
|`regen_per_turn`|`int`|每回合 MP 回复基值|
|`regular_skill_ids`|`PackedStringArray`|本场实际已装备的 3 个常规技能；初始化时从默认装配或 setup override 解析得到|
|`combat_type_ids`|`PackedStringArray`|运行态战斗属性镜像，初始化时从 `UnitDefinition` 复制|
|`base_attack`|`int`|基础攻击|
|`base_defense`|`int`|基础防御|
|`base_sp_attack`|`int`|基础特攻|
|`base_sp_defense`|`int`|基础特防|
|`base_speed`|`int`|基础速度|
|`stat_stages`|`Dictionary`|能力阶段|
|`effect_instances`|`Array[EffectInstance]`|挂载的持续效果实例|
|`rule_mod_instances`|`Array[RuleModInstance]`|挂载的规则修正实例|
|`has_acted`|`bool`|本回合是否已开始行动|
|`action_window_passed`|`bool`|本回合行动机会是否已过|
|`leave_state`|`String`|必须取自 `LeaveStates`|
|`leave_reason`|`Variant`|离场原因快照（如击倒、替换、投降链）|
|`last_effective_speed`|`int`|最近一次用于排序的有效速度快照|

## 7. FieldState

|字段|类型|说明|
|---|---|---|
|`field_def_id`|`String`|field 定义 ID|
|`instance_id`|`String`|field 实例 ID|
|`creator`|`String`|来源单位或系统名|
|`remaining_turns`|`int`|剩余回合|
|`source_instance_id`|`String`|触发源实例|
|`source_kind_order`|`int`|来源类型枚举值|
|`source_order_speed_snapshot`|`int`|速度快照|

## 8. EffectInstance

|字段|类型|说明|
|---|---|---|
|`instance_id`|`String`|实例 ID|
|`def_id`|`String`|效果定义 ID|
|`owner`|`String`|挂载对象实例 ID|
|`remaining`|`int`|剩余回合|
|`created_turn`|`int`|创建时回合号|
|`source_instance_id`|`String`|根来源实例|
|`source_kind_order`|`int`|根来源类型|
|`source_order_speed_snapshot`|`int`|根来源速度快照|
|`persists_on_switch`|`bool`|非击倒离场时是否保留该持续效果|
|`meta`|`Dictionary`|仅用于明确允许的扩展字段|

## 9. RuleModInstance

|字段|类型|说明|
|---|---|---|
|`instance_id`|`String`|实例 ID|
|`mod_kind`|`String`|`final_mod / mp_regen / skill_legality / action_legality / incoming_accuracy`|
|`mod_op`|`String`|`mul / add / set / allow / deny`|
|`value`|`Variant`|运算值|
|`scope`|`String`|生效域（如 `self / field`）|
|`duration_mode`|`String`|`turns / permanent`|
|`owner_scope`|`String`|挂载域（`unit / field`）|
|`owner_id`|`String`|挂载对象 ID（单位实例或 `field`）|
|`stacking_key`|`String`|叠加判定键|
|`remaining`|`int`|剩余回合|
|`created_turn`|`int`|创建回合|
|`decrement_on`|`String`|`turn_start / turn_end`|
|`source_instance_id`|`String`|来源实例|
|`source_kind_order`|`int`|来源类型|
|`source_order_speed_snapshot`|`int`|速度快照|
|`priority`|`int`|读取顺序优先级|

补充说明：

- `skill_legality` 仍保留为兼容读取口径，但只参与 `skill / ultimate` 两类动作。
- `action_legality` 与 `incoming_accuracy` 已是当前运行态 contract 的正式组成部分。

## 10. 临时状态重置点

|字段|重置节点|
|---|---|
|`has_acted`|每个 `turn_start` 前重置|
|`action_window_passed`|回合结算结束后重置|
|`selection_state`|进入新回合选择阶段前重置|
|`pending_effect_queue`|每个触发批次结束后清空|

补充说明：

- `UnitDefinition.skill_ids` 不再直接承担“本场实际装配”语义；运行时、合法性、公开快照统一读取 `UnitState.regular_skill_ids`。
- `candidate_skill_ids` 只存在于内容定义层；运行态当前不额外镜像候选池。

## 11. 禁止事项

- 不允许在模块间传递 `Dictionary` 来替代这些 runtime 对象。
- 不允许在 UI/AI 层缓存 `UnitState` 的私有副本后自行修改。
- 不允许由 `math` 模块直接改运行态。
