# Effect Engine（效果系统）

本文件定义效果触发、排序、payload 执行与实例管理。

## 1. 文件清单

|文件|职责|
|---|---|
|`trigger_dispatcher.gd`|根据触发点收集 `EffectEvent`|
|`effect_queue_service.gd`|对效果事件排序并出队|
|`payload_executor.gd`|执行 payload|
|`effect_instance_service.gd`|管理持续效果实例|
|`rule_mod_service.gd`|管理规则修正实例与查询|

## 2. Contract

### 2.1 EffectEvent

|字段|类型|说明|
|---|---|---|
|`event_id`|`String`|效果事件 ID|
|`trigger_name`|`String`|触发点|
|`source_instance_id`|`String`|根来源实例|
|`source_kind_order`|`int`|来源类型枚举|
|`source_order_speed_snapshot`|`int`|排序速度快照|
|`effect_definition_id`|`String`|效果定义 ID|
|`owner_id`|`String`|挂载者/施放者|
|`chain_context`|`ChainContext`|链上下文|

## 3. 排序链

`priority -> source_order_speed_snapshot -> source_kind_order -> source_instance_id -> random`

## 4. PayloadExecutor

当前只支持最小 payload 类型：

- `damage`
- `heal`
- `resource_mod`
- `stat_mod`
- `apply_effect`
- `remove_effect`
- `apply_field`
- `rule_mod`

## 5. EffectInstanceService

|动作|说明|
|---|---|
|`create`|创建实例|
|`refresh`|刷新持续时间|
|`replace`|替换旧实例|
|`remove`|移除实例|

## 6. RuleModService

职责：

- 创建/刷新 `RuleModInstance`
- 在 `final_mod`、MP 回复与技能合法性查询时返回有效修正

约束：

- `rule_mod` 不进入独立第二队列。
- 只允许作用于规则文档明确开放的读取点。
