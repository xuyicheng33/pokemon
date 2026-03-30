# Passive & Field（被动与场地）

本文件定义被动技能、被动持有物与 field 在当前骨架中的接入方式。

## 1. 文件清单

|文件|职责|
|---|---|
|`passive_skill_service.gd`|按触发点收集被动技能 `EffectEvent`|
|`passive_item_service.gd`|按触发点收集被动持有物 `EffectEvent`|
|`field_apply_service.gd`|field 落地主路径：领域对拼、成功后附带效果（`field_apply_success`）、`field_apply` 触发|
|`field_service.gd`|收集 field `EffectEvent`、处理自然到期扣减与 creator 离场后的提前打断|

## 2. 接入原则

- 被动收集服务只负责产出 `EffectEvent`，不负责最终排序。
- `field_apply_service.gd` 是少数会直接修改 field 运行态的主路径；它不负责回合节点遍历，只负责“这次 apply 能不能成立”。
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

## 5. Field 子域

### 5.1 FieldApplyService

职责：

- 处理 `apply_field` payload 的唯一主路径。
- 根据 `field_kind` 决定是直接覆盖、领域对拼，还是阻断生效。
- field 真正落地后再执行 `field_apply` 触发，并以 `field_apply_success` 派发 `on_success_effect_ids`。

规则：

- 只有 `domain` 对 `domain` 才进入领域对拼。
- `domain` 对 `normal`：新领域直接替换旧普通 field。
- `normal` 对 `domain`：新普通 field 被阻断，旧领域保留。
- 领域对拼比较双方扣费后的当前 MP。
- MP 高者留场；平 MP 随机决定胜者，并把随机值写入日志，保证 replay 可复现。
- 对拼失败的一方：field 不落地，只有成功后才成立的附带效果也不生效。
- 若当前领域由本方创建，则本方领域技能在合法性阶段直接禁用，禁止“自己续开自己领域”。
- 同回合双方都已排队领域时，后手领域不得被中途合法性锁回溯取消，必须进入对拼。
- active field 运行态一旦存在，`field_state.creator` 必须非空且能解析到当前存活单位；否则统一 `invalid_state_corruption`。
- 若同侧领域重开意外穿过前置合法性并落到 `FieldApplyService` 主路径，也必须直接 `invalid_state_corruption`，不再存在 `same_creator` 静默刷新分支。

### 5.2 FieldService

职责：

- 若场上有 field，按触发点产出 field 事件。
- `tick_turn_end()` 在回合末扣减剩余回合并返回是否到期。
- `break_field_if_creator_inactive()` 在 creator 离场、倒下或被强制换下后，负责执行提前打断。

说明：

- field 自然到期后的日志与移除由 `TurnFieldLifecycleService` 协调执行。
- creator 离场导致的提前打断已下沉到 `FieldService`，由手动换人、强制换下、击倒窗口和 field 覆盖路径复用同一逻辑。
- 非 creator 离场不会触发领域提前打断。
- 当前同一时刻全场只允许 1 个 field；若尝试展开新 field，必须先走 `FieldApplyService` 的对拼判定。
- field buff 必须绑定 field 生命周期：`field_apply` 生效、自然到期移除、提前打断移除；不再允许靠角色离场时顺手清 stat_stage 兜底。
- `RuntimeGuardService` 负责每回合入口兜底拦 active field 坏状态，但 `FieldApplyConflictService` 也要在局部主路径上做同样的 fail-fast 防御。

## 6. 约束

- `source_instance_id` 必须稳定，不能用临时文案替代。
- 触发服务不直接修改运行态，运行态修改只能在 payload 执行阶段发生。
- bench 不参与回合节点触发（被动技能与被动持有物都一样）。
- field 提前打断只执行 `on_break_effect_ids`，不会补写自然到期日志，也不会执行 `on_expire_effect_ids`。
