# Passive & Field（被动与场地）

本文件定义被动技能、被动持有物与 field 在当前骨架中的接入方式。

## 1. 文件清单

|文件|职责|
|---|---|
|`passive_skill_service.gd`|按触发点收集被动技能 `EffectEvent`|
|`passive_item_service.gd`|按触发点收集被动持有物 `EffectEvent`|
|`field_service.gd`|收集 field `EffectEvent`、处理自然到期扣减与 creator 离场后的提前打断|

## 2. 接入原则

- 三者都只负责产出 `EffectEvent`，不负责最终排序。
- 同批次排序统一交给 `EffectQueueService`。
- 回合节点（`turn_start / turn_end`）的 owner 范围固定为当前 active；bench 不触发。

## 3. PassiveSkillService

职责：

- 读取单位 `passive_skill_id`。
- 仅在定义包含当前触发点时产出事件。
- `source_instance_id` 固定为 `passive_skill:{unit_instance_id}:{passive_id}`。

## 4. PassiveItemService

职责：

- 读取单位 `passive_item_id`。
- 合并三类效果入口：`trigger_names`、`on_turn_effect_ids`、`always_on_effect_ids`。
- 对重复 `effect_id` 去重后再产出事件。

约束：

- `turn_start / turn_end` 只对 active 生效。
- `battle_init / on_enter` 可读取 `always_on_effect_ids`。
- `on_receive_effect_ids` 当前为禁用迁移字段：内容层允许保留该字段，但只要非空就必须在加载期 fail-fast。

## 5. FieldService

职责：

- 若场上有 field，按触发点产出 field 事件。
- `tick_turn_end()` 在回合末扣减剩余回合并返回是否到期。
- `break_field_if_creator_inactive()` 在 creator 离场、倒下或被强制换下后，负责执行提前打断。

说明：

- field 自然到期后的日志与移除由 `TurnFieldLifecycleService` 协调执行。
- creator 离场导致的提前打断已下沉到 `FieldService`，由手动换人、强制换下、击倒窗口和 field 覆盖路径复用同一逻辑。
- 当前同一时刻全场只允许 1 个 field；新 field 生效即覆盖旧 field。

## 6. 约束

- `source_instance_id` 必须稳定，不能用临时文案替代。
- 触发服务不直接修改运行态，运行态修改只能在 payload 执行阶段发生。
- bench 不参与回合节点触发（被动技能与被动持有物都一样）。
- field 提前打断只执行 `on_break_effect_ids`，不会补写自然到期日志，也不会执行 `on_expire_effect_ids`。
