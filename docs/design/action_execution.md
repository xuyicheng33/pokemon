# Action Execution（行动执行）

本文件定义单个行动的执行边界、目标锁定与失败语义。

## 1. 文件清单

|文件|职责|
|---|---|
|`action_executor.gd`|执行单个 `QueuedAction`|
|`target_resolver.gd`|根据 targeting 解析目标|
|`action_cast_service.gd`|编排技能 / 奥义行动主链，协调命中、直伤与技能 effect 分发|
|`action_cast_hit_service.gd`|处理命中率读取、领域必中覆盖与来袭命中修正|
|`action_cast_segment_service.gd`|处理技能本体直伤、额外威力读取与伤害公式调用，并统一 action 级 / segment 级受击 trigger 分发|
|`action_damage_segment_resolution_service.gd`|处理多段伤害的段解析、倍率读取与最终 HP 结算|
|`action_damage_log_service.gd`|统一直伤 / execute / 默认反伤日志与致死归因|
|`action_damage_segment_trigger_context_service.gd`|统一保护多段伤害逐段 trigger 的 `chain_context` 恢复|
|`power_bonus_resolver.gd`|对外暴露额外威力解析入口；实际 source 注册、合同校验与 runtime 分发统一委托给 `power_bonus_source_registry.gd`|
|`action_cast_effect_dispatch_service.gd`|按 `on_cast / on_hit / on_miss` 分发技能 effect 链|
|`action_domain_guard.gd`|行动开始前做领域重开与 `action_legality` 的二次合法性拦截|
|`switch_action_service.gd`|执行手动换人行动链|
|`action_log_service.gd`|统一写入行动链结构化日志|

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
|`speed_tie_roll`|`Variant`|同速打平随机值；非同速时为 `null`|

### 2.2 TargetSnapshot

|字段|类型|说明|
|---|---|---|
|`target_kind`|`String`|`enemy_active_slot / self / field / bench_unit`|
|`target_unit_id`|`String`|目标单位 ID，非适用为空串|
|`target_slot`|`String`|目标槽位，当前 1v1 固定为单槽|

### 2.3 ActionResult

|字段|类型|说明|
|---|---|---|
|`action_id`|`String`|根行动 ID|
|`result_type`|`String`|`resolved / cancelled_pre_start / action_failed_post_start / miss`|
|`consumed_mp`|`int`|本次消耗 MP|
|`generated_effects`|`Array[EffectEvent]`|生成的效果事件|
|`invalid_battle_code`|`Variant`|无效对局终止码；非适用为 `null`|

## 3. 固定执行顺序

1. pre-start 合法性复核：检查行动者仍可行动，且领域 / `action_legality` 没有把该行动变成非法
2. 标记 `has_acted = true`
3. 扣 MP，并处理常规技能加奥义点 / 奥义清奥义点
4. 触发 `on_cast`
5. 命中判定
6. 命中成功时，先走技能本体直伤与额外威力 pipeline
7. 资源型/超时型默认动作在命中后追加默认反伤
8. 触发 `effects_on_hit_ids` 或 `effects_on_miss_ids`

共享直伤补充：

- `damage_segments`、`execute_*`、`effect_stack_sum` 现已正式属于共享主线。
- `execute_*` 判定命中后、常规直伤前执行；命中时短路后续多段伤害链，不再继续派发段级 trigger。
- 多段主动伤害当前固定走：
  - 段解析与倍率读取
  - 段日志与致死归因
  - 段级 `on_receive_action_damage_segment` 上下文保护
- `on_receive_action_hit` 旧语义保持不变，仍只表示“整次来袭命中一次”；多段不自动改成“每段一次”。

## 4. TargetResolver

|目标类型|规则|
|---|---|
|`enemy_active_slot`|锁定敌方当前在场槽位|
|`self`|锁定行动者自身|
|`field`|锁定全场 field|
|`bench_unit`|手动换人时锁定已通过合法性校验的 bench `unit_instance_id`|

## 5. 失败语义

|类别|说明|
|---|---|
|`cancelled_pre_start`|行动轮到前行动者已无资格执行|
|`action_failed_post_start`|执行起点目标无效或硬条件不满足|
|`miss`|命中失败|

后续 payload 若因前序效果导致目标无效，只跳过该 payload，不回头改写根行动状态。

默认动作补充：

- 默认反伤在命中后执行，按 `BattleState.default_recoil_ratio` 计算，最少 `1`；当前样例默认仍为 `0.25`。
- 默认反伤日志写 `event_type = effect:damage`、`trigger_name = recoil`。
- 若施法者因此 HP 归 0，不提前中断当前行动链；击倒窗口在该行动结束后统一处理。
