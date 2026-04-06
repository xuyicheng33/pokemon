# Lifecycle & Replacement（离场与补位）

本文件定义离场、击倒窗口、补位与对应触发批次的职责边界。

## 1. 文件清单

|文件|职责|
|---|---|
|`leave_service.gd`|统一执行离场状态清理并写 `state:exit`|
|`lifecycle_retention_policy.gd`|统一回答 effect / rule_mod 在不同离场原因下是否保留|
|`faint_resolver.gd`|处理 `fainted_pending_leave` 窗口与触发批次|
|`faint_killer_attribution_service.gd`|记录致死来源、解析击杀归属并收集行动链 `on_kill` 事件|
|`faint_leave_replacement_service.gd`|收口击倒离场、creator 打断与补位主链的 helper|
|`replacement_service.gd`|处理强制换下/补位目标合法性并执行入场；递归 trigger batch 通过显式 runner callable 透传|
|`replacement_selector.gd`|系统替补选择接口，返回合法 bench 目标的 `unit_instance_id`|
|`default_replacement_selector.gd`|默认系统替补策略实现（从合法候选中确定目标）|
|`field_service.gd`|field 子域服务；本文件只引用其 creator 离场后的提前打断辅助|

## 2. LeaveService

职责：

- 清空 active 槽位。
- 按离场原因重置单位状态（能力阶段、临时标记、rule_mod 等）。
- 通过 `LifecycleRetentionPolicy` 决定 effect / rule_mod 是否保留；当前正式口径仍是“非击倒离场只保留 `persists_on_switch=true`，`faint` 一律清空”。
- 写 `state:exit` 日志。

说明：

- `LeaveService` 只做状态清理和日志，不负责触发批次调度。

## 3. FaintResolver

击倒窗口固定顺序：

1. 把 `HP <= 0` 且仍在场单位标记为 `fainted_pending_leave`，写 `state:faint`。
2. 执行 `on_faint` 批次。
3. 若可归属击杀来源，执行 `on_kill` 批次。
4. 执行 `on_exit` 批次。
5. 调用 `leave_service.leave_unit(..., "faint")` 执行离场清理。
6. 若离场单位是当前 field creator，则在任何补位前立刻执行 `field_break`，只跑 `on_break_effect_ids`。
7. 若 active 为空，调用 `ReplacementService` 立刻补位。
8. 对新上场单位执行 `on_enter` 批次。
9. 若补位或触发链引发新倒下，递归处理到窗口稳定。
10. 若替补选择接口返回空值、非法目标或超时，返回 `invalid_replacement_selection` 并终止。

fail-fast：任一批次产生 invalid code，立即返回上层终止战斗。

## 4. ReplacementService

|场景|说明|
|---|---|
|击倒补位|只在击倒窗口内触发，不进入行动队列|
|补位来源|先计算合法 bench 候选；候选数 > 1 时调用 `ReplacementSelector` 返回 `unit_instance_id`，候选数 = 1 自动锁定|
|失败语义|系统选择返回空值/非法/超时 -> `invalid_replacement_selection`|
|入场日志|补位时写 `state:replace`，随后写 `state:enter`|
|提前打断|旧 active 完成离场清理后，若其是 field creator，必须先 `field_break`，再允许 `replace / on_enter`|

实现状态说明（2026-03-25）：

- `forced_replace` 生命周期链已收口为 `on_switch -> on_exit -> leave -> field_break(若 creator 离场) -> replace -> on_enter`。
- 其中递归 `on_switch / on_exit / field_break / on_enter` batch 不再靠属性注入持有 `trigger_batch_runner`，而是由外层显式透传执行权。
- `FaintResolver` 当前也显式持有 `field_service`，不再通过 `trigger_batch_runner.field_service` 读取隐藏依赖。

## 4.1 手动换人与强制换下顺序

- 手动换人固定顺序：`on_switch -> on_exit -> leave -> field_break(若 creator 离场) -> replace -> on_enter`
- 强制换下固定顺序：`on_switch -> on_exit -> leave -> field_break(若 creator 离场) -> replace -> on_enter`
- 手动换人、强制换下、击倒补位的入场状态当前统一为：
  - `reentered_turn_index = battle_state.turn_index`
  - `has_acted = false`
  - `action_window_passed = false`
- 提前打断只执行 `on_break_effect_ids`，不执行 `on_expire_effect_ids`，也不写自然到期日志。

## 5. 约束

- `fainted_pending_leave` 单位不再作为普通 payload 合法目标。
- 击倒窗口里的触发点按批次顺序执行，不与其他触发点混排。
- 回合节点触发范围仍是 active + field；离场单位与 bench 不参与。
- 新入场单位、`on_enter`、`on_matchup_changed` 与回合节点，都不得读取一个按规则已被提前打断的旧 field。
