# 模块 06：效果系统数据模型与扩展规范

本文件定义“效果怎么建模、谁触发谁、谁算来源、怎么防循环”。

## 1. 设计目标

|目标|说明|
|---|---|
|统一建模|技能、状态、持有物、被动、field 尽量共用一套效果系统|
|高扩展性|保留触发点与 payload 扩展能力|
|可复现|每条触发链都要能完整回放|
|防失控|必须有去重和链深保护|

## 2. EffectDefinition

|字段|说明|
|---|---|
|`id`|唯一标识|
|`name`|效果名|
|`scope`|`self / target / team / field`|
|`duration_mode`|`turns / triggers / permanent`|
|`duration`|持续值|
|`stacking`|`none / refresh / stack / replace`|
|`max_stacks`|最大层数，默认 3|
|`trigger`|触发点列表|
|`priority`|同触发点排序优先级|
|`tags`|驱散、筛选、识别用标签|
|`exclusive_group`|互斥组|
|`conditions`|触发条件过滤器|
|`payloads`|效果行为列表|
|`replace_existing`|施加同互斥组状态时是否允许替换旧效果|
|`damage_layer`|若 payload 改伤害，必须声明作用层|

## 3. EffectInstance

|字段|说明|
|---|---|
|`instance_id`|效果实例唯一 ID|
|`def_id`|引用定义|
|`source`|效果来源|
|`owner`|当前持有者/承载者|
|`remaining`|剩余回合数或触发次数|
|`stacks`|当前层数|
|`created_turn`|创建回合|
|`snapshot`|创建时快照，可用于锁定来源属性|
|`meta`|扩展字段|

## 4. 触发点

### 4.1 基础触发点

|类别|触发点|
|---|---|
|回合|`turn_start`, `turn_end`|
|行动|`before_action`, `after_action`|
|命中|`on_hit`, `on_miss`, `on_crit`|
|状态|`on_apply`, `on_remove`|
|换人|`on_enter`, `on_exit`, `on_switch`|
|倒下|`on_faint`, `on_kill`|
|资源|`on_resource_change`|
|自定义|`custom:*`|

### 4.2 首个可玩里程碑要求

|触发点|要求|
|---|---|
|基础触发点|必须支持|
|`custom:*`|接口允许，首个可玩里程碑可先少量实现|

## 5. payload 类型

|类型|用途|首个可玩里程碑|
|---|---|---|
|`damage`|造成伤害|必须|
|`heal`|回复|必须|
|`stat_mod`|阶段/数值修改|必须|
|`resource_mod`|MP 等资源变化|必须|
|`status_apply`|附加状态|必须|
|`status_remove`|移除状态|必须|
|`rule_mod`|临时规则修改|必须|
|`swap`|强制换人/交换|必须|
|`apply_global`|施加 field|必须|
|`cleanse`|按标签清除效果|必须|
|`summon`|召唤物 / 替身|接口保留，可后做|

## 6. 叠加与互斥

|模式|说明|
|---|---|
|`none`|重复无效|
|`refresh`|刷新持续时间|
|`stack`|叠层|
|`replace`|新实例替换旧实例|

|场景|规则|
|---|---|
|同 `effect_id`|按 `stacking` 处理|
|同 `exclusive_group` 不同 `effect_id`|默认新效果施加失败；若 `replace_existing = true`，则替换旧效果|
|field 同组冲突|见模块 05，采用“后结算覆盖前结算”|

优先级说明：

- 当冲突对象是 `field` 时，优先按模块 05 的 field 特例处理；不走“默认施加失败”的通用分支。

## 7. 事件归属

### 7.1 统一字段含义

|字段|定义|
|---|---|
|`source`|“谁造成了这次效果”|
|`owner`|“这个效果实例现在挂在谁身上/由谁承载”|
|`target`|“这次 payload 直接作用到谁”|
|`killer`|“谁被认定击倒了目标”|
|`creator`|“是谁创建了这个 field / 持续效果实例”|
|`source_instance_id`|同触发点排序时使用的稳定源实例 ID|

`on_kill` 仲裁补充：

1. 默认取“最后一次让目标 HP 降到 0 的伤害事件”对应来源作为 `killer`。
2. 若同窗存在并列候选，则按统一排序键 `effect.priority -> source_speed -> source_kind_order -> source_instance_id -> random` 选最终 `killer`。
3. 若最终来源为系统伤害，则 `killer = null`，且不触发 `on_kill`。

### 7.2 常见归属表

|场景|`source`|`owner`|`target`|`killer` 口径|
|---|---|---|---|---|
|直接技能伤害|行动者|行动者或技能产生的效果实例|目标单位|若目标因此倒下，则通常为行动者|
|附带状态|施加者|状态持有者|目标单位|DOT 击杀时通常归给原施加者|
|被动技能反击|被动拥有者|被动拥有者|来袭者或定义目标|若反击致死，归给被动拥有者|
|被动持有物反击|持有物拥有者|持有物拥有者|来袭者或定义目标|若致死，归给持有物拥有者|
|field DOT|field 创建者|field 实例|在场受影响单位|若致死，归给 field 创建者；无创建者则系统伤害|
|默认动作反伤|自己|自己|自己|不归给对手|
|系统取消/非法指令|无|无|无|无|

## 8. 持续时间与扣减

|模式|规则|
|---|---|
|`turns`|回合末结算后扣减；新施加效果当回合不扣减|
|`triggers`|每次成功触发并完成结算后扣减 1|
|`permanent`|不自动扣减，只能显式移除|
|移除时机|扣减后 `remaining <= 0` 立即移除|

## 9. 防循环与安全保护

|项|规则|
|---|---|
|`event_chain_id`|每次独立结算链建立一个链路 ID，贯穿其引发的所有连锁触发|
|`chain_origin`|链路来源固定为 `battle_init / action / turn_start / turn_end / timeout / system_replace` 之一|
|去重键|同一链路内使用 `instance_id + trigger + event_step_id`|
|链深限制|使用可配置项 `max_chain_depth`；原型默认 16，超过立即报错并中断当前链|
|资源递归保护|`on_resource_change` 仍受去重与链深限制约束|
|fail-fast|触发链保护命中时，立即报错，不做静默吞掉|

补充终止语义：

- 任何链深超限、去重保护命中、或关键效果实例不合法的情况，都会把本场战斗立即标记为 `invalid_battle`。
- 一旦进入 `invalid_battle`，本场战斗立刻终止，不继续后续结算、不补位、不再推进回合。
- `invalid_battle` 的对局结果统一记为 `no_winner`（无胜者），并写入 `end_reason = invalid_battle`。
- 完整日志必须保留到报错点，方便回放与定位。

## 10. 技能、被动、持有物对接字段

### 10.1 技能

|字段|说明|
|---|---|
|`effects_on_cast`|施放时触发|
|`effects_on_hit`|命中后触发|
|`effects_on_miss`|未命中触发|
|`effects_on_crit`|暴击触发|
|`effects_on_kill`|击倒触发|
|`effects_on_enter`|入场触发|
|`effects_on_switch`|换人触发|

### 10.2 被动

|字段|说明|
|---|---|
|`triggers`|监听的触发点列表|
|`effects`|触发后施加的效果|
|`conditions`|触发条件|
|`targeting`|目标选择|

### 10.3 持有物

|字段|说明|
|---|---|
|`effects_on_receive`|持有物受击时触发|
|`effects_on_turn`|持有物在回合节点触发|
|`effects_always_on`|持有物常驻效果|

补充说明：

- `effects_on_use` 只为未来非标准模式的主动道具扩展预留，当前标准战斗基线不启用。

## 11. 扩展纪律

|项|规则|
|---|---|
|新增触发点|必须先写入本文件，再落实现|
|新增 payload|必须写清作用时机、归属、伤害层或状态层|
|跨模块副作用|若 payload 会影响换人、日志、公开信息，必须同步更新对应模块文档|
