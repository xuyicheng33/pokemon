# Log & Replay Contract（日志与回放）

本文件定义日志与回放的正式 contract。

## 1. 文件清单

|文件|职责|
|---|---|
|`battle_logger.gd`|写入完整日志|
|`log_event_builder.gd`|统一构造 `LogEvent`|
|`replay_runner.gd`|根据 `ReplayInput` 重建并验证流程|

## 2. LogEvent

|字段|类型|说明|
|---|---|---|
|`event_type`|`String`|固定枚举，见规则模块 05|
|`event_chain_id`|`String`|链路 ID|
|`event_step_id`|`int`|链内步进|
|`action_id`|`String`|根行动 ID，非行动系统链为空串|
|`command_type`|`String`|行动类型，非适用为空串|
|`command_source`|`String`|指令来源，非适用为空串|
|`source_instance_id`|`String`|来源实例|
|`target_instance_id`|`String`|目标实例，非适用为空串|
|`rng_stream_index`|`int`|随机消费序号|
|`invalid_battle_code`|`String`|仅 `system:invalid_battle` 时填写|
|`payload_summary`|`String`|简短调试摘要|

## 3. ReplayInput

|字段|类型|说明|
|---|---|---|
|`battle_seed`|`int`|随机种子|
|`content_snapshot_paths`|`PackedStringArray`|内容资源路径列表|
|`command_stream`|`Array[Command]`|指令流|

## 4. ReplayOutput

|字段|类型|说明|
|---|---|---|
|`event_log`|`Array[LogEvent]`|完整日志|
|`final_state_hash`|`String`|最终状态哈希|
|`succeeded`|`bool`|是否重放成功|

## 5. 责任边界

- `BattleLogger` 负责存储，不负责决定业务字段。
- `LogEventBuilder` 负责填默认值、继承链路字段、保证 `null` 口径统一映射为空串或明确值。
- `ReplayRunner` 负责重建，不负责修补坏日志。

## 6. 最小验收

- 同一输入重复回放，`final_state_hash` 一致。
- 所有随机消费都能在日志中找到对应 `rng_stream_index`。
