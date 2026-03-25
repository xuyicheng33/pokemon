# Turn Orchestrator（回合编排）

本文件定义战斗初始化与整回合推进的驱动边界。

## 1. 文件清单

|文件|职责|
|---|---|
|`battle_initializer.gd`|初始化运行态与首发流程|
|`turn_loop_controller.gd`|驱动整回合生命周期|
|`action_queue_builder.gd`|根据锁定指令排序出队列|

## 2. BattleInitializer

初始化固定步骤：

1. 读取 `BattleFormatConfig` 与队伍输入。
2. 生成单位实例 ID、公开编号、初始 HP/MP。
3. 确定双方首发。
4. 触发首发 `on_enter` 批次。
5. 处理由 `on_enter` 引发的击倒窗口与补位链。
6. 场面稳定后统一触发 `battle_init`。
7. 设置 `turn_index = 1`，`phase = selection` 前置态。

禁止事项：

- 不允许把 `on_enter` 与 `battle_init` 混排。
- 不允许在 initializer 内直接写 UI 或日志展示逻辑。

## 3. TurnLoopController

固定阶段：

|阶段|说明|
|---|---|
|`turn_start`|回合开始 MP 回复与 `turn_start` 触发|
|`selection`|收集并锁定双方指令|
|`queue_lock`|构建 `QueuedAction` 队列|
|`execution`|按序执行行动|
|`turn_end`|处理 `turn_end` 触发与 field 扣减|
|`victory_check`|比较胜负或回合上限|

## 4. ActionQueueBuilder

输入：`Array[Command]`  
输出：`Array[QueuedAction]`

排序链固定为：

`priority -> speed -> random`

`QueuedAction` 必须在这里记录排序快照，后续执行阶段不再回头重排。

## 5. 失败口径

- 初始化失败：直接 `invalid_battle`。
- 队列构建失败：直接 `invalid_battle`。
- 回合推进中若发现硬状态损坏：直接 `invalid_battle`。
