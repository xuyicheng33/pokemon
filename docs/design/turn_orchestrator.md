# Turn Orchestrator（回合编排）

本文件定义初始化与整回合推进的编排边界，重点约束触发批次、系统链路和 fail-fast 终止语义。

## 1. 文件清单

|文件|职责|
|---|---|
|`battle_initializer.gd`|初始化运行态、首发入场与 `battle_init` 批次|
|`turn_loop_controller.gd`|驱动 `turn_start -> selection -> queue_lock -> execution -> turn_end -> victory_check`|
|`action_queue_builder.gd`|按统一排序链生成 `QueuedAction`|

## 2. BattleInitializer

固定顺序：

1. 按 `BattleSetup` 构建双方运行态与首发。
2. 写首发 `state:enter` 日志。
3. 执行首发 `on_enter` 批次（仅当前 active + field）。
4. 立即处理由 `on_enter` 引发的击倒窗口与补位链，直到战场稳定。
5. 执行一次 `battle_init` 批次（仅当前 active + field）。
6. 再次处理击倒窗口；若已结束则直接终局。
7. 进入 `selection`。

约束：

- `on_enter` 与 `battle_init` 不能混排到同一排序池。
- 任一批次命中 `invalid_battle_*`，立即终止并写 `system:invalid_battle`。

## 3. TurnLoopController

### 3.1 固定阶段

|阶段|说明|
|---|---|
|`turn_start`|写 `system:turn_start`、执行 MP 回复、触发 `turn_start` 批次、按 `decrement_on=turn_start` 扣减 `rule_mod`|
|`selection`|解析提交指令；无提交走 `timeout_default`；无合法主动方案走 `resource_forced_default`|
|`queue_lock`|按 `priority -> speed -> random` 锁定行动队列|
|`execution`|逐个执行行动；每个行动后立即处理击倒窗口|
|`turn_end`|触发 `turn_end` 批次、field 扣减与到期移除、按 `decrement_on=turn_end` 扣减 `rule_mod`、写 `system:turn_end`|
|`victory_check`|胜负判定或回合上限判定|

### 3.2 触发范围

- `turn_start / turn_end` 触发批次只收集“当前 active + 当前 field”。
- bench 单位不参与回合节点触发。

### 3.3 终止语义

- 选择非法、执行期 invalid code、效果执行 invalid code 都走 fail-fast。
- 终止后 `battle_result = no_winner`，并记录 `invalid_battle_code`。

## 4. ActionQueueBuilder

输入：`Array[Command]`  
输出：`Array[QueuedAction]`

排序链固定：

`priority -> speed -> random`

`QueuedAction` 只保存排序快照，执行阶段不重排。
