# Turn Orchestrator（回合编排）

本文件定义初始化与整回合推进的编排边界，重点约束触发批次、系统链路和 fail-fast 终止语义。

## 1. 文件清单

|文件|职责|
|---|---|
|`battle_initializer.gd`|初始化总编排：建局、首发入场、`battle_init` 批次与首回合前预回蓝|
|`battle_initializer_state_builder.gd`|把 `BattleSetup` 展开成 side / unit 运行态，并写入本场实际常规技能装配|
|`battle_initializer_phase_service.gd`|承接初始化阶段的 battle header、`on_enter`、`battle_init` 与首回合预回蓝子流程|
|`public_id_allocator.gd`|在建局阶段分配公开 `public_id`，保证外层输入 / 输出 ID 稳定|
|`turn_loop_controller.gd`|驱动 `turn_start -> selection -> queue_lock -> execution -> turn_end -> victory_check`|
|`turn_selection_resolver.gd`|锁定本回合指令，处理 `wait / resource_forced_default / surrender` 分流|
|`turn_field_lifecycle_service.gd`|处理 field 自然到期、提前打断与 `on_matchup_changed` 对位变化钩子|
|`turn_limit_scoring_service.gd`|封装 turn limit 计分、比较与平局决策辅助|
|`action_queue_builder.gd`|按统一排序链生成 `QueuedAction`|
|`turn_resolution_service.gd`|统一回合节点触发、MP 回复、effect/rule_mod 扣减与链终止处理|
|`battle_result_service.gd`|胜负判定与终局结果落盘（含初始化阶段 invalid/startup victory）|
|`runtime_guard_service.gd`|运行时依赖完整性检查（缺失即 fail-fast）|
|`replacement_selection_helper.gd`|统一 bench 候选收集、active slot 定位与 replacement 选择|
|`replacement_entry_helper.gd`|统一 replacement 入场状态写入与公开日志|

## 2. BattleInitializer

固定顺序：

1. 按 `BattleSetup` 构建双方运行态与首发。
2. 先写 `system:battle_header`（结构化公开快照）。
3. 再写首发 `state:enter` 日志。
4. 执行首发 `on_enter` 批次（仅当前 active + field）。
5. 立即处理由 `on_enter` 引发的击倒窗口与补位链，直到战场稳定。
6. 对当前稳定对位执行一次 `on_matchup_changed`（若对位签名首次建立成功）。
7. 执行一次 `battle_init` 批次（仅当前 active + field）。
8. 再次处理击倒窗口；若已结束则直接终局。
9. 若 `battle_init` 后稳定对位发生变化，则在进入 `selection` 前补跑一次 `on_matchup_changed`。
10. 在进入 `selection` 前预应用一次首回合 `turn_start` MP 回复，但不补写日志。
11. 进入 `selection`。

约束：

- `on_enter` 与 `battle_init` 不能混排到同一排序池。
- 任一批次命中 `invalid_battle_*`，立即终止并写 `system:invalid_battle`。
- 建局时必须先完成 `SideSetup.regular_skill_loadout_overrides` 校验，再把默认装配或覆盖结果写入 `UnitState.regular_skill_ids`；后续合法性、快照与指令执行都只认这份运行态镜像。
- `BattleInitializer` 只做编排 owner；side / unit 运行态构造、初始化阶段子流程与 `public_id` 分配分别下沉到 `battle_initializer_state_builder.gd`、`battle_initializer_phase_service.gd` 与 `public_id_allocator.gd`。
- manager 对外 `create_session()` 返回的就是第 10 步完成后的公开快照；初始 `event_log` 不追补这次预回蓝事件。
- 初始化阶段的 `invalid_battle` 与 startup victory 统一由 `BattleResultService` 落盘，避免多 owner 漂移。

## 3. TurnLoopController

### 3.1 固定阶段

|阶段|说明|
|---|---|
|`turn_start`|写 `system:turn_start`、执行 MP 回复、触发 `turn_start` 批次、检查 field creator 是否失效、处理 `on_matchup_changed`、按 `decrement_on=turn_start` 扣减 effect/rule_mod|
|`selection`|解析提交指令；无提交时：若应强制资源型默认动作 `resource_forced_default` 则走 `resource_forced_default`，否则走 `wait(timeout_auto)`|
|`queue_lock`|按 `priority -> speed -> random` 锁定行动队列|
|`execution`|逐个执行行动；每个行动后立即处理击倒窗口，再检查 field break 与 `on_matchup_changed`|
|`turn_end`|触发 `turn_end` 批次、field 扣减与到期移除、按 `decrement_on=turn_end` 扣减 effect/rule_mod、写 `system:turn_end`|
|`victory_check`|胜负判定或回合上限判定|

### 3.2 触发范围

- `turn_start / turn_end` 触发批次只收集“当前 active + 当前 field”。
- bench 单位不参与回合节点触发。

### 3.3 终止语义

- 选择非法、执行期 invalid code、效果执行 invalid code 都走 fail-fast。
- 终止后 `battle_result = no_winner`，并记录 `invalid_battle_code`。

### 3.4 Replacement / Field 编排顺序

当前换人与 forced replace 相关主线顺序固定为：

1. `on_switch`
2. `on_exit`
3. leave / 离场状态写入
4. `field break` 检查与生命周期收尾
5. replacement 入场
6. `on_enter`

约束：

- `ReplacementService` 继续保留稳定入口，不新增外围稳定 API；选择与入场样板统一下沉到 helper。
- `FieldService` 继续保留稳定入口；field trigger 收集、生命周期 effect 收集和 field 清理解绑统一走共享 helper。
- `persistent_stat_stages` 属于共享运行时语义，跨换人 / 死亡保留规则不得再写回角色稿。

## 4. ActionQueueBuilder

输入：`Array[Command]`  
输出：`Array[QueuedAction]`

排序链固定：

`priority -> speed -> random`

`QueuedAction` 只保存排序快照，执行阶段不重排。
