# Log & Replay Contract（日志与回放）

本文件定义日志与回放的工程契约。规则权威以 `docs/rules/05` 为准；本文件给出当前实现的落地点与不可变约束。

## 1. 文件清单

|文件|职责|
|---|---|
|`battle_logger.gd`|写入与快照完整 `LogEvent` 列表|
|`log_event_builder.gd`|按 `ChainContext` 统一构造 `LogEvent` 字段|
|`replay_runner.gd`|按 `ReplayInput` 还原整场对局并产出 `ReplayOutput`|
|`tests/run_with_gate.sh`|测试闸门：断言失败或引擎错误日志任一命中即失败|

## 2. LogEvent 契约

### 2.1 链路字段语义

|字段|行动链（`chain_origin = action`）|非行动系统链（`battle_init / turn_start / turn_end / system_replace`）|
|---|---|---|
|`action_id`|根行动 `action_id`，同链衍生事件继承|`null`|
|`action_queue_index`|根行动队列序位，衍生事件继承|`null`|
|`actor_id`|根行动者实例 ID，衍生事件继承|`null`|
|`command_type`|`skill / switch / ultimate / resource_forced_default / timeout_default`|固定 `system:*`，如 `system:battle_init`、`system:turn_start`、`system:turn_end`、`system:replace`|
|`command_source`|`manual / ai / resource_auto / timeout_auto`|固定 `system`|
|`select_timeout`|`timeout_default` 链为 `true`，其他行动链为 `false`|`null`|
|`select_deadline_ms`|整条行动链写本回合截止时间|`null`|

### 2.2 空值口径

- 非适用字段一律写 `null`，不写空串、不省略。
- `invalid_battle_code` 仅在 `event_type = system:invalid_battle` 时填写，其余事件写 `null`。
- 未消费随机的字段（`speed_tie_roll / hit_roll / effect_roll`）写 `null`。

### 2.3 事件类型

`event_type` 使用 `src/shared/event_types.gd` 的固定枚举（`system:* / action:* / effect:* / state:* / result:*`）。

## 3. Replay 契约

### 3.1 ReplayInput

|字段|说明|
|---|---|
|`battle_seed`|本场随机种子|
|`content_snapshot_paths`|内容快照路径列表|
|`battle_setup`|战斗初始化配置|
|`command_stream`|按回合分发的指令流|

### 3.2 ReplayOutput

|字段|说明|
|---|---|
|`event_log`|完整日志快照|
|`final_state_hash`|`BattleState.to_stable_dict()` 的 SHA-256|
|`succeeded`|回放执行是否成功完成|
|`battle_result`|终局结果对象|
|`final_battle_state`|最终运行态对象|

### 3.3 deterministic 约束

- `ReplayRunner.run_replay()` 每次执行前必须 `id_factory.reset()`。
- 每次回放都按输入 `battle_seed` 调用 `rng_service.reset(seed)`。
- 相同 `seed + content snapshot + command stream` 必须得到相同 `final_state_hash` 与等长日志。
- 命令解析允许通过 `actor_public_id/target_public_id` 重新映射运行时实例 ID，避免历史 ID 污染。

## 4. 失败语义（测试口径）

- 业务断言失败：`tests/run_all.gd` 返回非 0。
- 引擎错误失败：输出命中 `SCRIPT ERROR / Compile Error / Parse Error / Failed to load script`。
- 严格通过条件：业务断言全绿且引擎错误日志为 0。

## 5. 最小验收

1. 同输入重复回放，`final_state_hash` 一致。
2. 日志链路字段遵守“行动链继承、系统链 `null + system:*`”语义。
3. `tests/run_with_gate.sh` 返回 `GATE PASSED`。
