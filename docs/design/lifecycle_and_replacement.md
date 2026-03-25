# Lifecycle & Replacement（离场与补位）

本文件定义离场、倒下、补位职责边界。

## 1. 文件清单

|文件|职责|
|---|---|
|`leave_service.gd`|统一处理主动换人、强制换下、倒下离场|
|`faint_resolver.gd`|统一处理 `fainted_pending_leave` 窗口|
|`replacement_service.gd`|强制补位与自动锁定|

## 2. LeaveService

支持场景：

- `manual_switch`
- `forced_replace`
- `faint`

职责：

- 写离场前后状态。
- 调用 `on_exit` 相关效果入口。
- 不负责选择替补。

## 3. FaintResolver

固定步骤：

1. 标记 `fainted_pending_leave`
2. 触发 `on_faint`
3. 对击杀来源触发 `on_kill`
4. 执行离场清理
5. 把补位工作交给 `ReplacementService`

## 4. ReplacementService

|场景|说明|
|---|---|
|强制补位|击倒窗口内进行|
|自动锁定|合法候选只剩 1 个时自动选择|

## 5. 约束

- 倒下单位一旦进入 `fainted_pending_leave`，不再作为普通合法目标。
- `ReplacementService` 不进入行动队列。
- 补位后产生的新 `on_enter` 必须按规则进入对应批次，不直接插进旧批次。
