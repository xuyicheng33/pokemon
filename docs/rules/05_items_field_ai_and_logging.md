# 模块 05：持有物、field、AI、统一触发排序与日志

本文件定义“被动持有物怎么工作、field 怎么落地、效果怎么排序、AI 能看什么、日志要记什么”。

## 1. 标准模式道具口径

### 1.1 当前标准模式

|项|规则|
|---|---|
|主动道具|标准模式不启用|
|战斗指令中的道具项|不存在|
|当前保留的道具形态|仅保留被动持有物|
|未来扩展|若未来新增主动道具模式，必须单独立规则，不得默认并回当前标准模式|

### 1.2 被动持有物

|项|规则|
|---|---|
|装备方式|战前装备|
|每单位上限|最多 1 个|
|同队同名限制|不可重复|
|是否进入行动队列|否|
|公开时机|战前随完整队伍信息一并公开|
|常见触发路径|常驻、回合节点、命中后等|
|回合节点触发范围|仅当前在场单位触发；bench 不触发|

补充规则：

1. `on_receive_effect_ids` 当前为禁用迁移字段：资源中允许保留字段，但值必须为空；非空按内容加载期校验直接失败。

## 2. field（全局效果）

### 2.1 当前基线

|项|规则|
|---|---|
|作用域|全场唯一 `field`|
|同一时刻生效数量|最多 1 个|
|典型来源|技能、奥义、被动持有物、被动技能|
|覆盖规则|普通 field 按覆盖规则替换；领域与领域才进入对拼|
|持续方式|按回合计时|
|具体效果|必须写在技能或效果描述里，不靠口头解释|
|命中覆盖|可通过 `creator_accuracy_override` 只覆盖 field creator 的技能命中；`-1` 表示不覆盖|

补充规则：

1. 当前 field 可以改伤害倍率、资源回复或技能可用性等，但必须由具体技能描述写死。
2. 现在不做“多个 field 共存”“同组 field”“team field”这类更复杂分层。
3. 已经存在于场上的 field，会参与本回合开始时的 MP 回复计算。
4. 在本次 `turn_start` 里才新建、替换或移除的 field，不回头改写本次 MP 回复，只从后续节点或下一次对应节点开始生效。
5. field 的持续时间不写在 `FieldDefinition`；持续回合与扣减节点由施加该 field 的 `EffectDefinition.duration / decrement_on` 决定。
6. 领域和普通 field 必须可区分；普通 field 不参与“领域对拼”。

### 2.2 field 结算与替换

|场景|规则|
|---|---|
|场上没有 field|新 field 直接生效|
|场上已有普通 field，新普通 field 生效|直接替换旧普通 field|
|场上已有普通 field，新领域生效|新领域直接替换旧普通 field，不进入对拼|
|场上已有领域，新普通 field 生效|新普通 field 不生效，写 `effect:field_blocked`，旧领域保留|
|场上已有领域，新领域生效|进入领域对拼，并写 `effect:field_clash`|
|领域对拼比较值|比较双方在各自动作扣费后的当前 MP|
|领域对拼胜负|MP 更高者保留领域；若 MP 相等，按 RNG 随机决定|
|领域对拼失败方|field 不落地，且“只有领域成功立住后才成立”的附带效果一律不生效|
|剩余回合扣减|固定在 `turn_end` 效果全部结算完成后；`remaining <= 0` 时立即移除|
|剩余回合起算|field 生效后，遇到的第一个 `turn_end` 结算节点即为首次扣减点；若本回合 `turn_end` 尚未执行，则本回合末立即扣减|
|field 到期|在约定节点移除，并写日志|
|field 提前打断|creator 离场/倒下或被新 field 覆盖时立即打断；只执行 `on_break_effect_ids`，不写自然到期日志|

补充规则：

1. field 自然到期顺序固定为：`tick -> on_expire_effect_ids -> effect:field_expire -> 清空 field 运行态`。
2. field 提前打断不会触发 `effect:field_expire`，也不会执行 `on_expire_effect_ids`。
3. creator 离场、倒下、被强制换下或手动换下时，`field_break` 必须发生在补位与新单位 `on_enter` 之前。
4. 新入场单位、`on_enter`、`on_matchup_changed`、`battle_init` 与回合节点，都不得读取一个按规则已被提前打断的旧 field。
5. 领域对拼的随机结果必须写入日志，保证同 seed 回放可复现。
6. field 绑定 buff 必须跟 field 生命周期一起成立与消失，不允许出现“field 没了但 buff 还残留”的状态。
7. 己方领域在场时，己方不能再次施放领域技能；该限制不作用于对手，也不作用于普通 field 技能。
8. 领域创建者离场会立即打断领域；非创建者离场不打断领域。
9. 同回合双方都已排队施放领域时，后手领域动作不得被中途合法性锁回溯取消，必须进入 `domain vs domain` 对拼。
10. `field_break / field_expire` 链上，`scope=self` 的 effect 允许命中“已离场但仍存活”的领域创建者运行态（用于离场打断与到期清理）。
11. field 绑定的能力阶段回滚必须按“field 生效期间实际写入的净增量”执行；若期间被其他效果抵消或触发 clamp，只回滚已记录部分，禁止过量回滚。
12. 只要存在 active field，`field_state.creator` 就必须非空且能解析到当前运行态中的现存单位；否则统一视为坏状态，直接 `invalid_state_corruption`。
13. 若“己方领域在场时不可重开”的前置合法性意外漏掉，同侧领域重开一旦落进 `field clash` 主路径，也必须直接 `invalid_state_corruption`，禁止静默走 `same_creator` 刷新。

## 3. 统一效果排序

被动持有物、被动技能、field 效果、主动技能衍生效果、系统效果若在同一触发点同时待结算，统一进入同一效果队列，排序链固定为：

`priority -> source_order_speed_snapshot -> source_kind_order -> source_instance_id -> random`

### 3.1 排序字段说明

|字段|规则|
|---|---|
|`priority`|统一使用 `-5 ~ +5` 数轴；数值越大越先；效果默认 `0`；内容层建议只使用 `-2 ~ +2`|
|`source_order_speed_snapshot`|效果入队时固化；排序只读快照，不再读运行态速度|
|`source_kind_order`|固定枚举，用于最后稳定打平；枚举值越小越先|
|`source_instance_id`|稳定实例 ID，用于完全相同来源的最终打平|
|`random`|前面全相同时才消耗 RNG|

补充规则：

1. `source_instance_id` 必须是当前触发源在本场战斗内稳定不变的实例标识，不能临时按显示文案或数组下标现拼。
2. 主动技能或奥义衍生效果的 `source_instance_id` 固定等于当前 `action_id`。
3. 被动技能、被动持有物、field 都必须各自有独立实例 ID；刷新持续时间不会换 ID，替换为新实例时才换新 ID。
4. 纯系统来源使用稳定系统实例 ID，例如 `system:turn_start`、`system:replace`，不得留空。
5. `apply_effect` 产生的持续效果实例不额外新开 `source_kind_order` 桶，而是继承创建它的根来源类型。
6. 统一效果排序只在“同一触发点、同一结算批次”内使用；不同触发点必须按模块 01 / 02 / 04 写死的时序先后执行，不跨触发点混排。

### 3.2 `source_kind_order` 固定枚举

|枚举值|来源类型|
|---|---|
|`0`|`system`|
|`1`|`field`|
|`2`|`active_skill`|
|`3`|`passive_skill`|
|`4`|`passive_item`|

### 3.3 速度快照取值规则

|来源|`source_order_speed_snapshot` 取值|
|---|---|
|当前在场单位来源|取入队时的当前有效速度|
|已离场单位来源|取该来源离场瞬间最后记录的有效速度|
|field 来源|取创建该 field 的来源速度；若无来源则取 `0`|
|纯系统来源|固定 `0`|

## 4. AI 读取边界

### 4.1 对外 ID 契约

|项|规则|
|---|---|
|`unit_id`|只用于内容定义与队伍构筑|
|`public_id`|玩家输入、AI 输入、合法性列表、公开快照、换人目标、回放输入的唯一外层标识|
|`unit_instance_id`|只允许留在核心内部运行态、内部日志归因、内部排序与系统自动动作中|
|`LegalActionSet`|对外固定暴露 `actor_public_id / legal_skill_ids / legal_switch_target_public_ids / legal_ultimate_ids / wait_allowed / forced_command_type`；其中 `legal_skill_ids` 只表示本场实际已装备的常规技能|
|外层 `Command`|默认只提交 `actor_public_id / target_public_id`；`actor_id / target_unit_id` 仅保留给核心内部或系统自动注入路径|

|项|规则|
|---|---|
|AI 可读取|所有公开信息、当前战场状态、己方运行态|
|AI 禁止读取|内部随机值、未来未发生的抽样结果、仅供调试的缓存|
|候选技能池|当前不进入公开快照，也不是 AI 对外 contract 的一部分|
|合法性职责|引擎先完成合法性判断：要么给出可选的技能 / 手动换人 / 奥义列表，要么直接替代为默认动作；AI 只从可执行结果中选一个|
|强制动作注入职责|`forced_command_type` 只由合法性层给出，`TurnSelectionResolver` 统一注入 `resource_forced_default`；AI adapter 在“无可选动作且 `wait_allowed=false`”时返回空命令，不再自行拼强制动作|
|空列表处理|若技能、手动换人、奥义都不合法：仅在“全部仅因 MP 不足”时强制 `resource_forced_default`；存在任一非 MP 阻断时允许 `wait`|
|超时处理|AI 若在截止时间前未返回：当前应强制资源型默认动作 `resource_forced_default` 则走 `resource_forced_default`；否则走 `wait`（`command_source = timeout_auto`）|

补充规则：

1. `BattleAIPolicyService` 只保留共通调度，不再长期承载角色专用分支。
2. 正式角色若接入 heuristic AI，必须显式补 `policy catalog` 配置与 `AI decision regression`；未配置的角色固定退回 `naive`，不允许半接入。

## 5. 战斗日志

### 5.1 必记字段

|字段|说明|
|---|---|
|`battle_seed`|整场战斗随机种子|
|`battle_rng_profile`|RNG 配置（算法、参数、版本）|
|`log_schema_version`|日志契约版本号；当前固定为 `3`|
|`turn_index`|当前回合序号|
|`event_chain_id`|触发链路 ID|
|`event_step_id`|链路步骤 ID|
|`event_type`|事件类型枚举（见 5.4）|
|`header_snapshot`|仅 `system:battle_header` 事件填写；字段固定为 `visibility_mode / prebattle_public_teams / initial_active_public_ids_by_side / initial_field`|
|`chain_origin`|链路来源：`battle_init / action / turn_start / turn_end / system_replace`|
|`trigger_name`|触发点名；仅 effect 类事件必须填写|
|`cause_event_id`|真实上游触发事件 ID；仅 effect 类事件必须填写，且不得指向当前日志事件自己|
|`killer_id`|击杀归属的单位实例 ID；无归属则为 `null`|
|`action_id`|当前根行动唯一 ID；同一行动链内的衍生效果事件继承该值；非行动系统链为 `null`|
|`action_queue_index`|当前根行动在本回合队列中的执行序位；非行动系统链为 `null`|
|`actor_id`|当前根行动的行动者；非行动系统链为 `null`|
|`source_instance_id`|当前触发源的稳定实例 ID；纯行动日志可与 `action_id` 相同|
|`command_type`|当前根链的动作类型：技能 / 换人 / 奥义 / `wait` / `resource_forced_default` / `system:*`（含 `system:battle_header`）|
|`command_source`|当前根链的指令来源：`manual / ai / resource_auto / timeout_auto / system`|
|`priority`|本次行动或效果使用的优先级|
|`target_slot`|目标位置|
|`action_window_passed`|行动机会是否已过去|
|`has_acted`|是否正式开始执行|
|`leave_reason`|离场原因|
|`speed_tie_roll`|同速决胜随机值|
|`hit_roll`|命中随机值|
|`effect_roll`|额外效果随机值|
|`rng_stream_index`|本次随机在 RNG 流中的消费序号|
|`select_deadline_ms`|本回合选指令截止时间|
|`select_timeout`|是否触发超时自动替代|
|`invalid_battle_code`|仅 `system:invalid_battle` 时填写错误码；其他事件写 `null`|
|HP/MP 变化|谁变了多少、变化前后数值|
|field 变化|创建、覆盖、剩余回合变化、移除|

### 5.2 空值与自动来源口径

|项|规则|
|---|---|
|非适用字段|一律写 `null`；不得混用 `0`、空串或省略|
|`action_id / action_queue_index / actor_id`|非行动系统链写 `null`；行动链内的衍生效果事件继承根行动字段|
|`target_slot`|无直接目标时写 `null`|
|`speed_tie_roll / hit_roll / effect_roll`|本事件未消费对应 RNG 时写 `null`|
|资源型默认动作|固定写 `command_type = resource_forced_default`、`command_source = resource_auto`|
|超时替代等待|固定写 `command_type = wait`、`command_source = timeout_auto`|
|`command_type / command_source`|非行动系统链固定写 `system:*` 与 `system`，例如 `system:battle_header`、`system:battle_init`、`system:turn_start`、`system:turn_end`、`system:replace`|
|`select_timeout`|`command_source = timeout_auto` 的整条行动链写 `true`；其他行动链写 `false`；非行动系统链写 `null`|
|`select_deadline_ms`|整条行动链都写本回合截止时间；非行动系统链写 `null`|
|`header_snapshot`|仅 `system:battle_header` 事件写入；其余事件写 `null`；且字段内禁止出现私有实例 ID（如 `unit_instance_id`）|
|`trigger_name / cause_event_id / killer_id`|effect 事件必须填 `trigger_name / cause_event_id`；其中 `cause_event_id` 固定指向真实上游触发事件：直接伤害/反伤指向 `action:hit`，effect payload 指向内部 `effect_event_*`，`turn_start / turn_end` 的回复与到期链指向对应系统锚点，离场清理指向 `state:exit`；系统锚点事件（如 `system:battle_init / system:turn_start / system:turn_end`）允许填写对应节点名作为 `trigger_name`；其他非 effect 事件 `cause_event_id` 写 `null`；`killer_id` 没有归属则写 `null`|

实现状态说明（2026-03-28）：

1. 当前实现已移除 `system:orphan` 临时补链逻辑；`chain_context` 缺失直接失败，不再静默兜底。

### 5.3 日志分层

|层级|用途|
|---|---|
|公开摘要日志|给玩家看，强调发生了什么|
|完整战斗日志|给调试、回放校验、回归测试用，必须可复现；不是单独的回放输入|
|调试扩展日志|可以更详细，但不能替代完整战斗日志|

对外快照规则：

1. `BattleCoreManager.get_event_log_snapshot()` 对外固定返回公开安全投影，不再直接透传内部 `LogEvent.to_stable_dict()`。
2. manager 出口禁止暴露 `actor_id / source_instance_id / target_instance_id / killer_id` 与 `value_changes[].entity_id`。
3. 对外事件快照必须改用公开语义：`actor_public_id / actor_definition_id / target_public_id / target_definition_id / killer_public_id / killer_definition_id`。
4. 对外 `value_changes` 只允许公开实体标识：`entity_public_id / entity_definition_id / resource_name / before_value / after_value / delta`。

### 5.4 `event_type` 枚举（最小集）

|`event_type`|说明|
|---|---|
|`system:battle_init`|战斗开始统一检查|
|`system:battle_header`|初始化日志头（结构化公开快照）|
|`system:turn_start`|回合开始系统结算|
|`system:turn_end`|回合末系统结算|
|`system:turn_limit`|回合上限比较|
|`system:invalid_battle`|非法终止|
|`action:cast`|行动开始执行|
|`action:cancelled_pre_start`|行动轮到前被取消|
|`action:failed_post_start`|行动执行起点失败|
|`action:hit`|命中成功|
|`action:miss`|命中失败|
|`effect:damage`|伤害结算|
|`effect:heal`|治疗结算|
|`effect:resource_mod`|资源变更结算|
|`effect:stat_mod`|能力阶段变更|
|`effect:apply_effect`|施加持续效果实例|
|`effect:remove_effect`|移除持续效果实例|
|`effect:apply_field`|创建或替换 field|
|`effect:field_clash`|`domain vs domain` 对拼结果（含平 MP tie-break）|
|`effect:field_blocked`|普通 field 被在场领域阻断|
|`effect:field_expire`|field 到期移除|
|`effect:rule_mod_apply`|规则修正生效|
|`effect:rule_mod_remove`|规则修正移除|
|`state:enter`|入场|
|`state:exit`|离场|
|`state:switch`|换人|
|`state:faint`|倒下|
|`state:replace`|强制补位|
|`result:battle_end`|战斗结束|

## 6. 当前模块回归点

1. 标准模式下不存在主动道具指令入口。
2. 被动持有物会在战前随完整队伍信息正确公开。
3. field 始终只有 1 个生效实例；冲突按 `field_kind` 矩阵处理（`domain` 可替换 `normal`，`normal` 不得覆盖 `domain`）。
4. 效果排序统一走 `priority -> source_order_speed_snapshot -> source_kind_order -> source_instance_id -> random`。
5. AI 不会自己死循环试指令，而是从引擎给出的合法列表里选。
6. `resource_forced_default / resource_auto / wait / timeout_auto` 命名在规则和日志里只有这一套口径。
7. `create_session()` 返回的是“已预回首回合 MP 后的初始公开快照”；这次预回蓝不补写进初始 `event_log`，属于正式 contract，不是缺日志。
7. 非适用日志字段一律写 `null`，不会混用 `0` 或省略。
8. 完整日志能还原命中、同速打平、field 替换、触发源实例与每次随机消费。
