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
|`default_recoil_ratio`|`float`|默认动作命中后的反伤比例快照（由 `BattleFormatConfig.default_recoil_ratio` 初始化）|
|`domain_clash_tie_threshold`|`float`|领域对拼平 MP 时 challenger 判胜阈值快照（由 `BattleFormatConfig.domain_clash_tie_threshold` 初始化）|
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

### 4.1 ChainContext

|字段|类型|说明|
|---|---|---|
|`event_chain_id`|`String`|当前链唯一 ID|
|`root_action_id`|`Variant`|根动作 ID；系统链可为空|
|`chain_origin`|`String`|当前链来源标签；区分 action / effect / system 等主链起点|
|`step_counter`|`int`|当前链内部步骤计数；日志与调试输出依赖它标定链内时序|
|`action_queue_index`|`Variant`|当前动作在本回合队列里的顺序快照|
|`actor_id`|`Variant`|当前链 actor 的运行时实例 ID|
|`command_type`|`Variant`|根动作类型|
|`command_source`|`Variant`|根动作来源（如手动、系统注入、超时）|
|`skill_id`|`Variant`|若当前链由技能或奥义触发，则记录对应 skill id|
|`select_timeout`|`Variant`|选择阶段是否由超时路径触发；用于 timeout wait / forced default 语义|
|`select_deadline_ms`|`Variant`|本链选择阶段的 deadline 快照；日志与外层超时判定可复用|
|`target_unit_id`|`Variant`|当前链锁定的目标单位实例 ID|
|`target_slot`|`Variant`|当前链目标槽位|
|`action_actor_id`|`Variant`|来袭动作的施法者实例 ID；`on_receive_action_hit` / `scope=action_actor` 读取这个字段|
|`action_combat_type_id`|`Variant`|来袭技能或奥义的 `combat_type_id` 快照；供受击前置与来袭伤害修正读取|
|`action_segment_index`|`int`|多段主动伤害的当前段序号；非多段路径固定为 `0`|
|`action_segment_total`|`int`|多段主动伤害总段数；非多段路径固定为 `0`|
|`chain_depth`|`int`|当前 effect 递归深度；超过 `max_chain_depth` 必须 fail-fast|
|`effect_dedupe_keys`|`Dictionary`|同链 effect 递归防抖键集合；当前按稳定语义键去重，避免递归重派发死循环|
|`defer_field_apply_success`|`bool`|同回合双开领域时，先手领域若仍需等待对拼结果，则先延后 `field_apply_success` 附带效果|

补充说明：

- `effect_dedupe_keys` 当前用于拦截“同链、同语义”的 effect 重复派发；它不等于全局去重，不得跨链复用。
- `action_actor_id / action_combat_type_id / action_segment_index / action_segment_total` 是受击链的正式上下文字段；`on_receive_action_hit` 读取整次来袭动作，`on_receive_action_damage_segment` 读取逐段上下文，禁止再从日志或外层命令对象反推。
- `copy_shallow()` 必须复制 `effect_dedupe_keys` 与当前链关键定位字段，保证派生链不会共享同一个可变字典实例。

## 5. SideState

|字段|类型|说明|
|---|---|---|
|`side_id`|`String`|非空 side 标识；当前基线为 `P1 / P2`，且同一场战斗内必须唯一|
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
|`ultimate_points`|`int`|当前奥义点|
|`ultimate_points_cap`|`int`|奥义点上限|
|`ultimate_points_required`|`int`|施放奥义所需点数|
|`ultimate_point_gain_on_regular_skill_cast`|`int`|每次开始施放常规技能时获得的奥义点|
|`regular_skill_ids`|`PackedStringArray`|本场实际已装备的 3 个常规技能；初始化时从默认装配或 setup override 解析得到|
|`used_once_per_battle_skill_ids`|`PackedStringArray`|内部 battle-scoped 一次性技能消耗记录；仅供合法性与执行链读取，不对 manager public contract 暴露|
|`combat_type_ids`|`PackedStringArray`|运行态战斗属性镜像，初始化时从 `UnitDefinition` 复制|
|`base_attack`|`int`|基础攻击|
|`base_defense`|`int`|基础防御|
|`base_sp_attack`|`int`|基础特攻|
|`base_sp_defense`|`int`|基础特防|
|`base_speed`|`int`|基础速度|
|`stat_stages`|`Dictionary`|能力阶段|
|`persistent_stat_stages`|`Dictionary`|跨非击倒离场保留的持久能力阶段；击倒时清空，并在有效阶段计算时与 `stat_stages` 合并|
|`effect_instances`|`Array[EffectInstance]`|挂载的持续效果实例|
|`rule_mod_instances`|`Array[RuleModInstance]`|挂载的规则修正实例|
|`has_acted`|`bool`|本回合是否已开始行动|
|`action_window_passed`|`bool`|本回合行动机会是否已过|
|`leave_state`|`String`|必须取自 `LeaveStates`|
|`leave_reason`|`Variant`|离场原因快照（如击倒、替换、投降链）|
|`reentered_turn_index`|`int`|最近一次通过 replacement / 手动换人重新入场时记录的回合号|
|`last_effective_speed`|`int`|最近一次用于排序的有效速度快照|

## 7. FieldState

|字段|类型|说明|
|---|---|---|
|`field_def_id`|`String`|field 定义 ID|
|`instance_id`|`String`|field 实例 ID|
|`creator`|`String`|当前 field creator 的 `unit_instance_id`；active field 存在时必须非空且能解析到仍在运行态里的单位|
|`remaining_turns`|`int`|剩余回合|
|`source_instance_id`|`String`|触发源实例|
|`source_kind_order`|`int`|来源类型枚举值|
|`source_order_speed_snapshot`|`int`|速度快照|
|`reversible_stat_mod_totals`|`Dictionary`|按 `owner_id|stat_name` 记录 field 期间实际生效的能力阶段净变化|
|`pending_success_effect_ids`|`PackedStringArray`|待在 `field_apply_success` 兑现的 follow-up effect 列表|
|`pending_success_source_instance_id`|`String`|`field_apply_success` follow-up 复用的来源实例|
|`pending_success_source_kind_order`|`int`|`field_apply_success` follow-up 复用的来源类型|
|`pending_success_source_order_speed_snapshot`|`int`|`field_apply_success` follow-up 复用的速度快照|
|`pending_success_chain_context`|`ChainContext|nil`|`field_apply_success` follow-up 复用的链上下文|

补充说明：

- `reversible_stat_mod_totals` 用于 field 生命周期回滚：`field_apply` 时记录实际写入增量，`field_break / field_expire` 时只消费已记录增量，避免 clamp/外部改动导致过量回滚。
- `FieldState.to_stable_dict()` 必须包含 `reversible_stat_mod_totals`，保证 replay 与 `final_state_hash` 在该语义下仍可稳定复现。
- `FieldState.creator` 当前不再接受 `system` 之类占位值；只要场上存在 active field，就必须指向仍可解析的单位实例。
- 对外 `public_snapshot.field.creator_public_id` 与 `header_snapshot.initial_field.creator_public_id` 只允许公开 `public_id` 或 `null`；creator 解析失败时禁止回退 runtime/source id。

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
|`meta`|`Dictionary`|仅用于明确允许的扩展字段；当前已包含 `source_owner_id` 以支持 same-owner 前置守卫|

补充说明：

- `persists_on_switch=true` 的 unit effect 在非击倒离场后继续挂在 owner 身上；owner 位于 bench 时，该实例只继续扣减 `remaining`，不参与普通 `turn_start / turn_end` trigger batch。
- 这类 bench 持久 effect 若在板凳上到期，当前只移除并写正常 remove log，不派发 `on_expire_effect_ids`。
- `stacking=refresh` 的 effect 当前固定保留同一 runtime instance，并同步刷新 `remaining / source_instance_id / source_kind_order / source_order_speed_snapshot / meta`。

## 9. RuleModInstance

|字段|类型|说明|
|---|---|---|
|`instance_id`|`String`|实例 ID|
|`mod_kind`|`String`|`final_mod / mp_regen / action_legality / incoming_accuracy / nullify_field_accuracy / incoming_action_final_mod / incoming_heal_final_mod`|
|`mod_op`|`String`|`mul / add / set / allow / deny`|
|`value`|`Variant`|运算值|
|`scope`|`String`|生效域（如 `self / field`）|
|`duration_mode`|`String`|`turns / permanent`|
|`owner_scope`|`String`|挂载域（`unit / field`）|
|`owner_id`|`String`|挂载对象 ID（单位实例或 `field`）|
|`field_instance_id`|`String`|若该 mod 跟随具体 field 生命周期，则记录对应 field runtime instance_id|
|`stacking_key`|`String`|叠加判定键|
|`remaining`|`int`|剩余回合|
|`created_turn`|`int`|创建回合|
|`decrement_on`|`String`|`turn_start / turn_end`|
|`source_instance_id`|`String`|来源实例|
|`source_kind_order`|`int`|来源类型|
|`source_order_speed_snapshot`|`int`|速度快照|
|`persists_on_switch`|`bool`|非击倒离场时是否保留该规则修正|
|`source_stacking_key`|`String`|多来源分组键；当前供 `mp_regen / incoming_accuracy / nullify_field_accuracy / incoming_action_final_mod / incoming_heal_final_mod` 使用|
|`required_incoming_command_types`|`PackedStringArray`|来袭动作过滤白名单；当前供 `incoming_action_final_mod` 等读取点按 `skill / ultimate` 精确过滤|
|`required_incoming_combat_type_ids`|`PackedStringArray`|来袭属性过滤白名单；与 `required_incoming_command_types` 共同收窄来袭路径|
|`priority`|`int`|读取顺序优先级|

补充说明：

- `action_legality / incoming_accuracy / nullify_field_accuracy / incoming_action_final_mod / incoming_heal_final_mod` 已是当前运行态 contract 的正式组成部分。
- `action_legality` 当前显式只管理 `skill / ultimate / switch`；`wait / resource_forced_default / surrender` 永远不进入其封禁面。
- `mp_regen / incoming_accuracy / nullify_field_accuracy / incoming_action_final_mod / incoming_heal_final_mod` 当前按“来源分组内走 stacking、不同来源组并存”的主线语义运行；`source_stacking_key` 的解析优先级为 `payload.stacking_source_key -> effect_definition_id -> source_instance_id`。
- `persists_on_switch=true` 的 unit rule mod 在非击倒离场后继续保留；`faint` 仍然清空全部 unit rule mod。
- `stacking=refresh` 的 rule mod 当前固定保留同一 runtime instance，并同步刷新 `remaining / source_instance_id / source_kind_order / source_order_speed_snapshot`。

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
- `used_once_per_battle_skill_ids` 只保留在核心内部运行态，不回写到 manager public snapshot、回放公开 contract 或外层输入结构。
- replacement / 手动换人入场后，`reentered_turn_index = 当前 battle_state.turn_index`，并统一把 `has_acted=false`、`action_window_passed=false` 作为稳定运行态口径。
- 同链 effect 递归防抖的正式扩展位是 `EffectEvent.dedupe_discriminator`；若未来需要允许“同链合法重复派发”，只能显式设置这个 discriminator，不能再靠复制 effect id 或篡改 source token 绕过去重。

## 11. 禁止事项

- 不允许在模块间传递 `Dictionary` 来替代这些 runtime 对象。
- 不允许在 UI/外层输入层缓存 `UnitState` 的私有副本后自行修改。
- 不允许由 `math` 模块直接改运行态。
