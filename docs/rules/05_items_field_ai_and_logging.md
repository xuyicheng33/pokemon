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
|常见触发路径|常驻、受击、回合节点、命中后等|

## 2. field（全局效果）

### 2.1 当前基线

|项|规则|
|---|---|
|作用域|全场唯一 `field`|
|同一时刻生效数量|最多 1 个|
|典型来源|技能、奥义、被动持有物、被动技能|
|覆盖规则|新 field 成功生效后，直接替换旧 field|
|持续方式|按回合计时|
|具体效果|必须写在技能或效果描述里，不靠口头解释|

补充规则：

1. 当前 field 可以改伤害倍率、资源回复或技能可用性等，但必须由具体技能描述写死。
2. 现在不做“多个 field 共存”“同组 field”“team field”这类更复杂分层。
3. 已经存在于场上的 field，会参与本回合开始时的 MP 回复计算。
4. 在本次 `turn_start` 里才新建、替换或移除的 field，不回头改写本次 MP 回复，只从后续节点或下一次对应节点开始生效。

### 2.2 field 结算与替换

|场景|规则|
|---|---|
|场上没有 field|新 field 直接生效|
|场上已有 field，新的后结算|旧 field 被替换|
|同一窗口里多个 field 同时待生效|先进入统一效果队列，后结算完成的那个最终留下|
|剩余回合扣减|固定在 `turn_end` 效果全部结算完成后；`remaining <= 0` 时立即移除|
|field 到期|在约定节点移除，并写日志|

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

|项|规则|
|---|---|
|AI 可读取|所有公开信息、当前战场状态、己方运行态|
|AI 禁止读取|内部随机值、未来未发生的抽样结果、仅供调试的缓存|
|合法性职责|引擎先完成合法性判断：要么给出可选的技能 / 手动换人 / 奥义列表，要么直接替代为默认动作；AI 只从可执行结果中选一个|
|空列表处理|当前不把“空合法列表”交给 AI；若技能、手动换人、奥义都不合法，引擎在选择阶段直接生成 `resource_forced_default`|
|超时处理|AI 若在截止时间前未返回，引擎直接走 `timeout_default`|

## 5. 战斗日志

### 5.1 必记字段

|字段|说明|
|---|---|
|`battle_seed`|整场战斗随机种子|
|`battle_rng_profile`|RNG 配置（算法、参数、版本）|
|`turn_index`|当前回合序号|
|`event_chain_id`|触发链路 ID|
|`event_step_id`|链路步骤 ID|
|`action_id`|当前根行动唯一 ID；同一行动链内的衍生效果事件继承该值；非行动系统链为 `null`|
|`action_queue_index`|当前根行动在本回合队列中的执行序位；非行动系统链为 `null`|
|`actor_id`|当前根行动的行动者；非行动系统链为 `null`|
|`source_instance_id`|当前触发源的稳定实例 ID；纯行动日志可与 `action_id` 相同|
|`command_type`|当前根链的动作类型：技能 / 换人 / 奥义 / `resource_forced_default` / `timeout_default` / `system:*`|
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
|超时型默认动作|固定写 `command_type = timeout_default`、`command_source = timeout_auto`|
|`command_type / command_source`|非行动系统链固定写 `system:*` 与 `system`，例如 `system:battle_init`、`system:turn_start`、`system:turn_end`、`system:replace`|
|`select_timeout`|`timeout_default` 所属整条行动链都写 `true`；其他行动链写 `false`；非行动系统链写 `null`|
|`select_deadline_ms`|整条行动链都写本回合截止时间；非行动系统链写 `null`|

### 5.3 日志分层

|层级|用途|
|---|---|
|公开摘要日志|给玩家看，强调发生了什么|
|完整战斗日志|给调试、回放、回归测试用，必须可复现|
|调试扩展日志|可以更详细，但不能替代完整战斗日志|

## 6. 当前模块回归点

1. 标准模式下不存在主动道具指令入口。
2. 被动持有物会在战前随完整队伍信息正确公开。
3. field 始终只有 1 个生效实例，新 field 会替换旧 field。
4. 效果排序统一走 `priority -> source_order_speed_snapshot -> source_kind_order -> source_instance_id -> random`。
5. AI 不会自己死循环试指令，而是从引擎给出的合法列表里选。
6. `resource_forced_default / resource_auto / timeout_default / timeout_auto` 命名在规则和日志里只有这一套口径。
7. 非适用日志字段一律写 `null`，不会混用 `0` 或省略。
8. 完整日志能还原命中、同速打平、field 替换、触发源实例与每次随机消费。
