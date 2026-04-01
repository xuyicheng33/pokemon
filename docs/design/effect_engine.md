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
|`rule_mod_service.gd`|`rule_mod` facade，对外维持单入口|
|`rule_mod_read_service.gd`|`rule_mod` 读取查询（合法性、命中、最终倍率、回蓝）|
|`rule_mod_write_service.gd`|`rule_mod` 写路径（create / stacking / decrement / remove）|
|`rule_mod_value_resolver.gd`|对动态 `rule_mod` 值做运行时求值，不回写共享内容资源|

补充说明：

- 被动技能、被动持有物与 field 作为 trigger source 的接入与归属，统一见 [passive_and_field.md](./passive_and_field.md)。

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

当前完整触发点全集与扩展约束，以 `docs/rules/06_effect_schema_and_extension.md` 第 4 节为权威；本文件不重复维护一份独立触发点清单，避免文档漂移。

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

effect 级前置约束：

- 当前 `required_target_effects` 已接线到 `PayloadExecutor`。
- 该前置只允许挂在 `scope=target` 的 effect 上；目标固定读取 `chain_context.target_unit_id`。
- 前置不满足时整条 effect 直接跳过，不报错，也不写任何由该 effect 产生的 payload 日志。

## 5. RuleMod 子域

### 5.1 结构

- `RuleModService` 现在只保留 facade 职责，对外继续暴露稳定入口。
- `RuleModReadService` 固定承接读路径，避免新查询再继续堆回旧热点。
- `RuleModWriteService` 固定承接写路径，负责实例创建、stacking 语义与回合节点扣减。

### 5.2 读取点

- `final_mod`：伤害最终倍率。
- `mp_regen`：`turn_start` MP 回复值。
- `action_legality`：技能 / 奥义 / 换人合法性正式读取点；`wait` 不受影响。
- `incoming_accuracy`：目标侧命中干扰读取点；在 field 覆盖后、命中 roll 前参与计算。

### 5.3 生命周期

- `RuleModWriteService.create_instance()` 支持 `none / refresh / replace`。
- `decrement_for_trigger()` 只在 `turn_start` 或 `turn_end` 扣减。
- 过期实例必须移除并写 `effect:rule_mod_remove` 日志。

### 5.4 排序

读取顺序固定：

`priority -> source_order_speed_snapshot -> source_kind_order -> source_instance_id -> instance_id`

## 6. Field apply 主路径

- `apply_field` 的唯一主入口是 `field_apply_service.gd`，不能把领域对拼散在 payload、角色资源和 lifecycle 分支里各写一份。
- 场上已有 field 时，按 `field_kind` 冲突矩阵处理：`domain vs domain` 进入对拼并写 `effect:field_clash`；`normal vs domain` 被阻断并写 `effect:field_blocked`；`domain vs normal` 直接替换。
- 只有 field 真正落地成功后，才允许继续执行 `field_apply` 触发，并以 `field_apply_success` 派发 `ApplyFieldPayload.on_success_effect_ids`。
- 因此“领域成功才成立的附带效果”与“领域 buff 跟着 field 生命周期走”都收口在同一条 apply 路径里。

## 7. 约束

- `rule_mod` 只允许改写已开放读取点，不可绕开核心流程。
- `EffectInstanceService.create_instance()` 支持 `stack`，每层 effect instance 独立扣减 `remaining`。
- 回合节点触发范围固定为 active + field；bench 不触发。
- `rule_mod` 不进入第二效果队列，不参与二次排序。
- 持续效果实例在 `turn_start / turn_end` 触发后按 `decrement_on` 扣减，`remaining <= 0` 立即移除并写 `effect:remove_effect`。
- 核心依赖缺失（如 `effect_instance_dispatcher`、`rule_mod_service`）不允许静默跳过，必须在启动或执行起点直接失败。
- 若未来新增 `rule_mod` 读取点，必须先更新 `docs/rules/06_effect_schema_and_extension.md` 与架构约束文档，再补实现。
