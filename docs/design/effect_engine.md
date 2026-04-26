# Effect Engine（效果系统）

本文件定义触发收集、统一排序、payload 执行与规则修正读取点。

## 1. 文件清单

|文件|职责|
|---|---|
|`trigger_dispatcher.gd`|把定义资源转换为 `EffectEvent`|
|`effect_instance_dispatcher.gd`|按触发点收集持续效果实例 + 回合节点扣减|
|`trigger_batch_runner.gd`|统一执行单个触发批次（收集 -> 排序 -> 执行）|
|`effect_queue_service.gd`|对同批次 `EffectEvent` 排序|
|`payload_executor.gd`|执行 effect guard、前置守卫与 payload 分派|
|`effect_precondition_service.gd`|处理 `required_target_*` 与 incoming action 过滤前置守卫|
|`payload_handler_registry.gd`|对外暴露 payload script 到单 payload handler 的唯一映射；实际 handler 槽位声明由 `payload_contract_registry.gd` 动态派生|
|`effect_instance_service.gd`|管理持续效果实例|
|`rule_mod_service.gd`|`rule_mod` facade，对外维持单入口|
|`rule_mod_read_service.gd`|`rule_mod` 读取查询（合法性、命中、最终倍率、回蓝）|
|`rule_mod_active_instance_collector.gd`|统一收集 owner + field 生效中的 `rule_mod`，并固定读取排序|
|`rule_mod_legality_query.gd`|承接 `action_legality` 查询与共享错误文案|
|`rule_mod_numeric_query.gd`|承接倍率 / 命中 / 回蓝 / 治疗 / 来袭倍率读取|
|`rule_mod_write_service.gd`|`rule_mod` 写路径（create / stacking / decrement / remove）|
|`rule_mod_value_resolver.gd`|对动态 `rule_mod` 值做运行时求值，不回写共享内容资源|
|`field_trigger_collection_helper.gd`|统一收集 field 本体 trigger 与生命周期 effect 批次|
|`field_cleanup_helper.gd`|统一清理 field 解绑、field rule mod 清除与空场回收|

补充说明：

- 被动技能、被动持有物与 field 作为 trigger source 的接入与归属，统一见 [passive_and_field.md](./passive_and_field.md)。
- `field_apply_service / field_service / field_cleanup_helper / field_trigger_collection_helper` 虽然会被 effect 主链调用，但实现归属仍在 `src/battle_core/passives/`；它们属于被动与 field 子域，不属于 effect engine 自己的 owner。

## 2. EffectEvent 契约

|字段|说明|
|---|---|
|`event_id`|效果事件 ID|
|`trigger_name`|触发点名（如 `on_hit`）|
|`priority`|效果优先级（同批次排序第一关键字）|
|`source_instance_id`|稳定来源实例 ID|
|`source_kind_order`|来源桶（system/field/active_skill/passive_skill/passive_item）|
|`source_order_speed_snapshot`|排序速度快照|
|`effect_definition_id`|效果定义 ID|
|`owner_id`|效果归属单位|
|`chain_context`|当前链上下文，用于日志继承|
|`sort_random_roll`|同排序组随机打平值（未消费时为 `null`）|

## 3. 统一排序链

同一触发点同一批次固定排序：

`priority -> source_order_speed_snapshot -> source_kind_order -> source_instance_id -> random`

不同触发点不混排。

当前完整触发点全集与扩展约束，以 `docs/rules/06_effect_schema_and_extension.md` 第 4 节为权威；本文件不重复维护一份独立触发点清单，避免文档漂移。

## 4. Payload 执行模型

当前支持最小 payload：

- `damage`
- `heal`
- `resource_mod`
- `stat_mod`
- `apply_effect`
- `remove_effect`
- `apply_field`
- `rule_mod`
- `forced_replace`

当前执行模型：

- `PayloadExecutor` 只负责：
  - effect dedupe / chain depth / missing dependency hard-stop
  - 调用 `EffectPreconditionService`
  - 按 `PayloadHandlerRegistry` 分派到单 payload handler
- `effect_dedupe_keys` 当前是“单链单实例”去重，不是链深限制：
  - 去重粒度由 `_build_dedupe_key` 决定，覆盖 `source_instance_id / effect_instance_id / trigger_name / effect_definition_id / owner_id / dedupe_discriminator / target_unit_id / action_segment_index`。
  - 同一条主链中，同一组 key 命中的 effect_event 只允许进 `_enter_effect_guard` 一次；二次进入直接 `INVALID_CHAIN_DEPTH` fail-fast。
  - 去重表的生命周期就是 `chain_context` 自身：主链结束时 `chain_context` 被重置或置 null，`effect_dedupe_keys` 一并出栈，不需要在 `_leave_effect_guard` 显式 erase。
  - 链深限制是独立的 `chain_depth ≤ max_chain_depth` 守卫；两条守卫各管各，不能混淆。
- registry 当前固定一对一路由：
  - `damage -> PayloadDamageHandler`
  - `heal -> PayloadHealHandler`
  - `resource_mod -> PayloadResourceModHandler`
  - `stat_mod -> PayloadStatModHandler`
  - `apply_field -> PayloadApplyFieldHandler`
  - `apply_effect -> PayloadApplyEffectHandler`
  - `remove_effect -> PayloadRemoveEffectHandler`
  - `rule_mod -> PayloadRuleModHandler`
  - `forced_replace -> PayloadForcedReplaceHandler`
- `payload_contract_registry.gd` 当前同时维护：
  - `payload script -> handler slot -> validator key`
  - handler 直接依赖 wiring facts
  - `payload_handler_registry` 与 payload handler wiring 所需的 descriptor 视图
- `ContentPayloadValidator` 当前也固定从 registry 的 `validator_key` 派生 dispatcher，按 `_validate_<validator_key>_payload` 命名约定执行内容校验；新增 payload 时不再额外维护一份手写 `match` 分发表
- payload handler 的具体 script 当前不再单独维护映射表；`BattleCorePayloadServiceSpecs` 会按 `handler_slot -> src/battle_core/effects/payload_handlers/<handler_slot>.gd` 的命名约定解析，静态 gate 同时校验 registry slot 与目录下实际 handler 文件一一对应
- `payload_resource_runtime_service` 是 heal/resource_mod 共享的数值执行层（两个 handler 复用同一份 `_apply_resource_like_change` 逻辑）；damage / stat_mod 已折叠回各自 handler，handler 直接持有数值逻辑而无单独 runtime_service 文件。

fail-fast 约束：

- 缺失效果定义或 payload 类型非法：`last_invalid_battle_code = invalid_effect_definition`。
- `rule_mod` 定义非法：`last_invalid_battle_code = invalid_rule_mod_definition`。
- 上游（`battle_initializer / turn_loop_controller / action_executor / faint_resolver`）命中该错误码后必须立即终止战斗。

effect 级前置约束：

- 当前 `required_target_effects / required_target_same_owner / required_incoming_command_types / required_incoming_combat_type_ids` 已统一下沉到 `EffectPreconditionService`。
- 该前置只允许挂在 `scope=target` 的 effect 上；目标固定读取 `chain_context.target_unit_id`。
- 若 `required_target_same_owner=true`，则命中的 required effect instance 还必须记录 `meta.source_owner_id == effect_event.owner_id`。
- 前置不满足时整条 effect 直接跳过，不报错，也不写任何由该 effect 产生的 payload 日志。
- `scope=action_actor` 只允许用于 `on_receive_action_hit`；相关单位目标固定读取 `chain_context.action_actor_id`。
- `required_incoming_command_types / required_incoming_combat_type_ids` 当前统一可用于 `on_receive_action_hit / on_receive_action_damage_segment`；运行时都读取同一份 `chain_context.command_type / action_combat_type_id`。
- `on_receive_action_damage_segment` 当前由主动伤害主链在每个成功结算段后显式派发；其上下文固定补 `chain_context.action_segment_index / action_segment_total / action_combat_type_id`。
- 多段主动伤害的段级上下文当前必须走同一条保护路径：先补段索引 / 段总数 / 段属性 / target，再派发 trigger，最后恢复原始 `chain_context`；不允许在 owner 内继续手改后靠人肉恢复。

## 5. RuleMod 子域

### 5.1 结构

- `RuleModService` 现在只保留 facade 职责，对外继续暴露稳定入口。
- `RuleModReadService` 固定承接读路径 owner；其内部现已拆成实例收集 / legality 查询 / numeric 查询三块 helper，避免继续堆回旧热点。
- `RuleModWriteService` 固定承接写路径，负责实例创建、stacking 语义与回合节点扣减。

### 5.2 读取点

- `final_mod`：伤害最终倍率。
- `mp_regen`：`turn_start` MP 回复值。
- `action_legality`：技能 / 奥义 / 换人合法性正式读取点；`wait` 不受影响。
- `incoming_accuracy`：目标侧命中干扰读取点；在 field 覆盖后、命中 roll 前参与计算。
- `nullify_field_accuracy`：目标侧“忽略领域附加必中”读取点；不影响技能原生命中率。
- `incoming_action_final_mod`：目标侧来袭行动最终倍率读取点；当前支持按来袭动作类型与属性过滤。
- `incoming_heal_final_mod`：目标侧治疗末端倍率读取点；在基础治疗量解出后、最终 HP clamp 前参与计算。

这批读取点已属于共享主线，不再允许角色稿重复定义语义，只允许角色资源声明自己是否消费这些读取点。

### 5.3 生命周期

- `RuleModWriteService.create_instance()` 支持 `none / refresh / replace`。
- `decrement_for_trigger()` 只在 `turn_start` 或 `turn_end` 扣减。
- 过期实例必须移除并写 `effect:rule_mod_remove` 日志。

### 5.4 排序

读取顺序固定：

`priority -> source_order_speed_snapshot -> source_kind_order -> source_instance_id -> instance_id`

## 6. Field apply 主路径

- `apply_field` 的唯一主入口是 `field_apply_service.gd`，不能把领域对拼散在 payload、角色资源和 lifecycle 分支里各写一份。
- 场上已有 field 时，按 `field_kind` 冲突矩阵处理：`domain vs domain` 进入对拼并写 `effect:field_clash`；`normal vs domain` 被阻断并写 `effect:field_blocked`；`domain vs normal` 直接替换。
- 只有 field 真正落地成功后，才允许继续执行 `field_apply` 触发，并以 `field_apply_success` 派发 `ApplyFieldPayload.on_success_effect_ids`。
- 因此“领域成功才成立的附带效果”与“领域 buff 跟着 field 生命周期走”都收口在同一条 apply 路径里。

## 7. 约束

- `rule_mod` 只允许改写已开放读取点，不可绕开核心流程。
- `EffectInstanceService.create_instance()` 支持 `stack`，每层 effect instance 独立扣减 `remaining`。
- 回合节点触发范围固定为 active + field；bench 不触发。
- `rule_mod` 不进入第二效果队列，不参与二次排序。
- 持续效果实例在 `turn_start / turn_end` 触发后按 `decrement_on` 扣减，`remaining <= 0` 立即移除并写 `effect:remove_effect`。
- 核心依赖缺失（如 `effect_instance_dispatcher`、`rule_mod_service`）不允许静默跳过，必须在启动或执行起点直接失败。
- 若未来新增 `rule_mod` 读取点，必须先更新 `docs/rules/06_effect_schema_and_extension.md` 与架构约束文档，再补实现。
