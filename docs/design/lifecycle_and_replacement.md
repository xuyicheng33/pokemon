# Lifecycle & Replacement（离场与补位）

本文件定义离场、击倒窗口、补位与对应触发批次的职责边界。

## 1. 文件清单

|文件|职责|
|---|---|
|`leave_service.gd`|统一执行离场状态清理并写 `state:exit`|
|`faint_resolver.gd`|处理 `fainted_pending_leave` 窗口与触发批次|
|`replacement_service.gd`|处理强制换下/补位目标合法性并执行入场|
|`replacement_selector.gd`|系统替补选择接口，返回合法 bench 目标|

## 2. LeaveService

职责：

- 清空 active 槽位。
- 按离场原因重置单位状态（能力阶段、临时标记、rule_mod 等）。
- 对非倒下离场保留 `persists_on_switch` 的效果实例。
- 写 `state:exit` 日志。

说明：

- `LeaveService` 只做状态清理和日志，不负责触发批次调度。

## 3. FaintResolver

击倒窗口固定顺序：

1. 把 `HP <= 0` 且仍在场单位标记为 `fainted_pending_leave`，写 `state:faint`。
2. 执行 `on_faint` 批次。
3. 若可归属击杀来源，执行 `on_kill` 批次。
4. 调用 `leave_service.leave_unit(..., "faint")` 执行离场清理。
5. 执行 `on_exit` 批次。
6. 若 active 为空，调用 `ReplacementService` 立刻补位。
7. 对新上场单位执行 `on_enter` 批次。
8. 若补位或触发链引发新倒下，递归处理到窗口稳定。
9. 若替补选择接口返回空值、非法目标或超时，返回 `invalid_replacement_selection` 并终止。

fail-fast：任一批次产生 invalid code，立即返回上层终止战斗。

## 4. ReplacementService

|场景|说明|
|---|---|
|击倒补位|只在击倒窗口内触发，不进入行动队列|
|补位来源|先计算合法 bench 候选；候选数 > 1 时调用 `ReplacementSelector`，候选数 = 1 自动锁定|
|失败语义|系统选择返回空值/非法/超时 -> `invalid_replacement_selection`|
|入场日志|补位时写 `state:replace`，随后写 `state:enter`|

实现状态说明（2026-03-25）：

- `forced_replace` 生命周期链（`on_switch -> on_exit -> leave -> replace -> on_enter`）已接入 payload 执行路径。

## 5. 约束

- `fainted_pending_leave` 单位不再作为普通 payload 合法目标。
- 击倒窗口里的触发点按批次顺序执行，不与其他触发点混排。
- 回合节点触发范围仍是 active + field；离场单位与 bench 不参与。
