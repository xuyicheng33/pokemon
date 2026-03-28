# Effect Engine（效果系统）

本文件定义触发收集、统一排序、payload 执行与规则修正读取点。

## 1. 文件清单

|文件|职责|
|---|---|
|`trigger_dispatcher.gd`|把定义资源转换为 `EffectEvent`|
|`effect_instance_dispatcher.gd`|按触发点收集持续效果实例 + 回合节点扣减|
|`trigger_batch_runner.gd`|统一执行单个触发批次（收集 -> 排序 -> 执行）|
|`effect_queue_service.gd`|对同批次 `EffectEvent` 排序|
|`payload_executor.gd`|执行 payload 并写日志|
|`effect_instance_service.gd`|管理持续效果实例|
|`rule_mod_service.gd`|管理 `RuleModInstance` 与读取接口|
|`rule_mod_value_resolver.gd`|对动态 `rule_mod` 值做运行时求值，不回写共享内容资源|
|`passive_skill_service.gd`|按触发点收集被动技能事件|
|`passive_item_service.gd`|按触发点收集被动持有物事件|
|`field_service.gd`|按触发点收集 field 事件 + `turn_end` 扣减|

## 2. EffectEvent 契约

|字段|说明|
|---|---|
|`event_id`|效果事件 ID|
|`trigger_name`|触发点名（如 `on_hit`）|
|`priority`|效果优先级（同批次排序第一关键字）|
|`source_instance_id`|稳定来源实例 ID|
|`source_kind_order`|来源桶（system/field/active_skill/passive_skill/passive_item）|
|`source_order_speed_snapshot`|排序速度快照|
|`effect_definition_id`|效果定义 ID|
|`owner_id`|效果归属单位|
|`chain_context`|当前链上下文，用于日志继承|
|`sort_random_roll`|同排序组随机打平值（未消费时为 `null`）|

## 3. 统一排序链

同一触发点同一批次固定排序：

`priority -> source_order_speed_snapshot -> source_kind_order -> source_instance_id -> random`

不同触发点不混排。

## 4. PayloadExecutor

当前支持最小 payload：

- `damage`
- `heal`
- `resource_mod`
- `stat_mod`
- `apply_effect`
- `remove_effect`
- `apply_field`
- `rule_mod`
- `forced_replace`

实现状态说明（2026-03-25）：

- `forced_replace` payload 已接线到 `PayloadExecutor`，执行顺序固定为 `on_switch -> on_exit -> leave -> replace -> on_enter`。

fail-fast 约束：

- 缺失效果定义或 payload 类型非法：`last_invalid_battle_code = invalid_effect_definition`。
- `rule_mod` 定义非法：`last_invalid_battle_code = invalid_rule_mod_definition`。
- 上游（`battle_initializer / turn_loop_controller / action_executor / faint_resolver`）命中该错误码后必须立即终止战斗。
- `required_target_effects` 不满足时，必须在 `execute_effect_event()` 的 payload 循环前整条 effect 跳过；该分支不写 invalid code。

## 5. RuleModService

### 5.1 读取点

- `final_mod`：伤害最终倍率。
- `mp_regen`：`turn_start` MP 回复值。
- `skill_legality`：兼容期旧读取点（仅 `skill/ultimate`）。
- `action_legality`：选择阶段与执行前复检的动作合法性（`skill/ultimate/switch`，`wait` 不受影响）。
- `incoming_accuracy`：命中判定前目标侧命中修正（仅敌方来袭技能/奥义，且 `resolved_accuracy < 100` 才读取）。

实现状态说明：

- `action_legality / incoming_accuracy` 为 Gojo 扩展冻结口径；在对应代码接线完成前，主线内容资源仍按当前已实现读取点运行。

### 5.2 生命周期

- `RuleModService.create_instance()` 支持 `none / refresh / replace`。
- `decrement_for_trigger()` 只在 `turn_start` 或 `turn_end` 扣减。
- 过期实例必须移除并写 `effect:rule_mod_remove` 日志。

### 5.3 排序

读取顺序固定：

`priority -> source_order_speed_snapshot -> source_kind_order -> source_instance_id -> instance_id`

## 6. 约束

- `rule_mod` 只允许改写已开放读取点，不可绕开核心流程。
- `EffectInstanceService.create_instance()` 支持 `stack`，每层 effect instance 独立扣减 `remaining`。
- 回合节点触发范围固定为 active + field；bench 不触发。
- `rule_mod` 不进入第二效果队列，不参与二次排序。
- 持续效果实例在 `turn_start / turn_end` 触发后按 `decrement_on` 扣减，`remaining <= 0` 立即移除并写 `effect:remove_effect`。
- 核心依赖缺失（如 `effect_instance_dispatcher`、`rule_mod_service`）不允许静默跳过，必须在启动或执行起点直接失败。
- `action_legality` 兼容期读取必须把 `action_legality + skill_legality` 合并到同一排序链（`priority -> source_order_speed_snapshot -> source_kind_order -> source_instance_id -> instance_id`），禁止分两套顺序独立求值。
