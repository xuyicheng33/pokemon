# Action Execution（行动执行）

本文件定义单个行动的执行边界、目标锁定与失败语义。

## 1. 文件清单

|文件|职责|
|---|---|
|`action_executor.gd`|执行单个 `QueuedAction`|
|`target_resolver.gd`|根据 targeting 解析目标|

## 2. Contract

### 2.1 QueuedAction

|字段|类型|说明|
|---|---|---|
|`action_id`|`String`|根行动 ID|
|`queue_index`|`int`|队列顺序|
|`command`|`Command`|原始指令|
|`actor_snapshot_id`|`String`|排序时行动者实例 ID|
|`target_snapshot`|`TargetSnapshot`|锁定目标快照|
|`priority`|`int`|排序用优先级|
|`speed_snapshot`|`int`|排序用速度快照|

### 2.2 TargetSnapshot

|字段|类型|说明|
|---|---|---|
|`target_kind`|`String`|`enemy_active_slot / self / field`|
|`target_unit_id`|`String`|目标单位 ID，非适用为空串|
|`target_slot`|`String`|目标槽位，当前 1v1 固定为单槽|

### 2.3 ActionResult

|字段|类型|说明|
|---|---|---|
|`action_id`|`String`|根行动 ID|
|`result_type`|`String`|`resolved / cancelled_pre_start / action_failed_post_start / miss`|
|`consumed_mp`|`int`|本次消耗 MP|
|`generated_effects`|`Array[EffectEvent]`|生成的效果事件|

## 3. 固定执行顺序

1. 标记 `has_acted = true`
2. 扣 MP
3. 触发 `on_cast`
4. 命中判定
5. 处理命中侧 payload
6. 触发 `effects_on_hit` 或 `effects_on_miss`

## 4. TargetResolver

|目标类型|规则|
|---|---|
|`enemy_active_slot`|锁定敌方当前在场槽位|
|`self`|锁定行动者自身|
|`field`|锁定全场 field|

## 5. 失败语义

|类别|说明|
|---|---|
|`cancelled_pre_start`|行动轮到前行动者已无资格执行|
|`action_failed_post_start`|执行起点目标无效或硬条件不满足|
|`miss`|命中失败|

后续 payload 若因前序效果导致目标无效，只跳过该 payload，不回头改写根行动状态。
