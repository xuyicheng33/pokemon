# 模块 06：效果系统数据模型与扩展规范

本文件定义“技能、被动、持有物、field 的效果怎么统一建模，后续扩展时怎么不把基线搞乱”。

补充说明：

1. 本文件是“当前极简基线需要的最小效果框架 + 扩展纪律”，不是要求首版一次把所有未来机制全部实现。
2. 当前首版必须优先支持：`damage / heal / stat_mod / apply_field / resource_mod`，以及极少量、规则已写清的持续效果。
3. 未来若要引入更复杂的持续方式、更多 payload 或更深触发链，必须先改文档，再扩实现。

## 1. 设计目标

|目标|说明|
|---|---|
|统一建模|技能、被动、持有物、field 尽量共用一套效果系统|
|最小够用|先支持当前极简基线需要的效果，不先把所有未来机制做满|
|可回放|每条触发链都能完整复盘|
|防失控|必须有链深保护与去重规则|

## 2. `EffectDefinition`

|字段|说明|
|---|---|
|`id`|唯一标识|
|`name`|效果名|
|`scope`|`self / target / field`|
|`duration_mode`|当前只允许 `turns / permanent`|
|`duration`|持续值；`turns` 模式必填|
|`decrement_on`|`turn_start / turn_end`；仅 `turns` 模式必填|
|`stacking`|`none / refresh / replace`|
|`priority`|统一优先级字段；默认 `0`；数值越大越先|
|`trigger`|触发点列表|
|`conditions`|触发条件过滤器|
|`payloads`|效果行为列表|
|`persists_on_switch`|是否跨离场保留；默认 `false`|

## 3. `EffectInstance`

|字段|说明|
|---|---|
|`instance_id`|效果实例唯一 ID|
|`def_id`|引用定义|
|`source`|效果来源|
|`owner`|当前挂载对象|
|`remaining`|剩余回合数|
|`created_turn`|创建回合|
|`source_instance_id`|当前触发源的稳定实例 ID|
|`source_kind_order`|创建它的根来源类型枚举；持续效果后续触发时继续沿用|
|`source_order_speed_snapshot`|排序速度快照，入队时固化|
|`meta`|扩展字段|

补充规则：

1. `apply_effect` 创建实例时，必须把当下根来源的 `source_instance_id / source_kind_order / source_order_speed_snapshot` 一并复制进实例。
2. 持续效果后续触发时继续沿用创建时复制下来的根来源排序元数据，不因 owner 改变而重算来源类型。

## 4. 当前基线触发点

|类别|触发点|
|---|---|
|战斗开始|`battle_init`|
|回合|`turn_start`, `turn_end`|
|行动|`on_cast`, `on_hit`, `on_miss`|
|换人|`on_enter`, `on_exit`, `on_switch`|
|倒下|`on_faint`, `on_kill`|

补充规则：

1. 当前没有 `on_crit`，因为当前不做暴击。
2. 当前不保留 `on_action_attempt / before_action / after_action / on_resource_change` 这类未落地触发点。
3. 若以后要加新触发点，必须先改本文件。
4. `battle_init` 只用于“战斗开始时统一检查一次”的来源，不因为某个单位刚入场而重复触发。
5. 首发入场仍然走 `on_enter`；同一份效果不能因为“首发入场”同时挂在 `on_enter` 和 `battle_init` 两边重复结算。
6. `battle_init` 固定发生在初始 `on_enter` 与其引发的补位链完全稳定之后；不同触发点不跨批次混排。
7. `turn_start / turn_end` 触发只对“当前在场单位”和全场 field 生效；bench 单位不参与回合节点触发。

## 5. 当前基线 payload 类型

|类型|用途|
|---|---|
|`damage`|造成物理或特殊伤害|
|`heal`|回复 HP|
|`resource_mod`|修改 MP|
|`stat_mod`|修改攻击、防御、特攻、特防、速度阶段|
|`apply_effect`|施加持续效果实例|
|`remove_effect`|移除持续效果实例|
|`apply_field`|创建或替换当前 field|
|`rule_mod`|按技能描述临时修改规则，如伤害倍率、资源回复规则|
|`forced_replace`|强制目标单位离场并立即补位（若有合法替补）|

补充规则：

1. 当前内容层不开放“任意 rule_mod”；只允许改写模块 03 / 05 已明确留口的 `final_mod` 链、MP 回复规则或技能合法性。
2. `rule_mod` 是“读取点修正器”，不是流程节点扩展口；不得修改 `priority`、行动排序、目标锁定、击倒窗口、胜负判定、回合阶段顺序、生命周期顺序、日志链路语义等核心流程。
3. `payloads` 列表严格按声明顺序执行；后一个 payload 必须读取前一个 payload 已经写回的最新运行态。
4. 每个 payload 单独适用模块 02 的目标有效性与模块 04 的生命周期规则；若前序 payload 已让目标进入 `fainted_pending_leave`，后续直接作用该目标的普通 payload 按目标无效处理。
5. 若 `on_cast` 链上的前序 payload（含默认动作反伤）让施法者 HP 归 0，本次行动链不提前终止；仍按模块 02 的“行动开始后不回滚”语义继续本次剩余步骤，并在行动结束后进入击倒窗口。
6. 当前基线的 `remove_effect` 只允许按目标 owner 上的精确 `def_id` 移除单个效果实例；若出现文档未允许的歧义匹配，按 `invalid_battle` 处理。

### 5.1 damage payload 与 `combat_type` 接口

|场景|规则|
|---|---|
|直接技能伤害|使用技能自身 `combat_type_id` 参与克制|
|`DamagePayload.use_formula = true` 且存在 `chain_context.skill_id`|继承该技能的 `combat_type_id`；若该技能已声明 `damage_kind = physical / special`，公式伤害也继承该攻防路径|
|链技能 `damage_kind = none`|公式伤害回退使用 payload 自身 `damage_kind`|
|非技能链公式伤害|使用 payload 自身 `damage_kind`；`type_effectiveness = 1.0`|
|默认动作与反伤|`type_effectiveness = 1.0`|

日志口径：

1. 只有伤害事件写 `type_effectiveness`。
2. 直接技能伤害与 effect damage 都必须带 `type_effectiveness`。
3. 非伤害事件该字段固定写 `null`。

### 5.2 `rule_mod` payload 约束（最小集）

|字段|说明|
|---|---|
|`mod_kind`|`final_mod / mp_regen / skill_legality`|
|`mod_op`|`final_mod` 允许 `mul / add / set`；`mp_regen` 允许 `add / set`；`skill_legality` 允许 `allow / deny`|
|`value`|数值或布尔含义（由 `mod_kind / mod_op` 解释）|
|`scope`|`self / target / field`，与创建时的目标一致|
|`duration_mode`|`turns / permanent`|
|`duration`|`turns` 模式必填|
|`decrement_on`|`turn_start / turn_end`，声明扣减节点|
|`stacking`|`none / refresh / replace`|
|`priority`|可选，默认 `0`，用于同一 hook 内的应用顺序|

补充规则：

1. `rule_mod` 必须显式声明 `decrement_on`；否则按 `invalid_battle` 处理。
2. `skill_legality` 只允许修改“是否可用”，不得改写 `priority / targeting / mp_cost` 等基础字段。

### 5.3 `RuleModInstance` 运行时模型

|字段|说明|
|---|---|
|`instance_id`|规则修正实例唯一 ID|
|`mod_kind / mod_op / value`|来自 payload|
|`owner`|当前挂载对象（与 `scope` 对齐）|
|`remaining`|剩余回合数|
|`created_turn`|创建回合|
|`decrement_on`|扣减节点|
|`source_instance_id`|创建它的根来源实例 ID|
|`source_kind_order`|根来源类型枚举|
|`source_order_speed_snapshot`|排序速度快照|
|`priority`|用于同一 hook 的应用排序|

应用规则：

1. `rule_mod` 在执行 payload 时创建/刷新/替换实例，不进入效果队列二次排序。
2. 需要读取规则修正的节点（`final_mod`、`turn_start` MP 回复、技能合法性）必须收集所有仍有效的 `RuleModInstance`。
3. 同一 hook 内的应用顺序固定为：`priority -> source_order_speed_snapshot -> source_kind_order -> source_instance_id -> instance_id`。
4. `stacking = none` 时遇到同键（`mod_kind + scope + owner + mod_op`）直接忽略新实例；`refresh` 刷新 `remaining` 但保留 `instance_id`；`replace` 移除旧实例并创建新实例。

### 5.4 `rule_mod` 边界冻结（架构强约束）

|项|规则|
|---|---|
|白名单读取点|固定为 `final_mod / mp_regen / skill_legality`|
|流程控制权|禁止通过 `rule_mod` 改行动排序、回合阶段顺序、击倒窗口、补位时机、胜负判定、目标模型、生命周期、日志语义|
|新增读取点流程|先改 `docs/rules/06` 与架构约束文档，再实现|
|扩展策略|若玩法长期需要更多权限，优先新建专用机制，不继续扩大 `rule_mod` 放权范围|

## 6. 叠加与替换

|模式|说明|
|---|---|
|`none`|重复施加无效|
|`refresh`|刷新持续时间|
|`replace`|新实例替换旧实例|

当前补充规则：

1. 单位级持续效果默认不允许无限叠加。
2. field 当前只有 1 个生效实例，因此 `apply_field` 的默认行为就是替换旧 field。
3. 当前不支持“按触发次数耗尽”这类持续方式；若以后需要，先补数据模型，再补生命周期规则。

## 7. 事件归属

|字段|定义|
|---|---|
|`source`|谁造成了这次效果|
|`owner`|这个效果实例现在挂在谁身上或由谁承载|
|`target`|这次 payload 直接作用到谁|
|`creator`|是谁创建了当前 field|
|`source_instance_id`|当前触发源的稳定实例 ID|
|`source_kind_order`|当前触发源继承的根来源类型枚举|

`on_kill` 补充规则：

1. 默认取“最后一次让目标 HP 归 0 的伤害事件”对应来源作为 `killer`。
2. 若同窗存在并列候选，则按统一效果排序链选最终 `killer`。
3. 若最终来源为系统伤害，则 `killer = null`，且不触发 `on_kill`。

## 8. 持续时间与扣减

|模式|规则|
|---|---|
|`turns`|在约定节点扣减；`remaining <= 0` 时立即移除|
|`permanent`|不自动扣减，只能显式移除|

补充规则：

1. 当前若某个技能要引入持续效果，必须在技能定义里写清“在哪个节点扣减”。
2. 扣减起算点：实例创建后，遇到的第一个对应扣减节点即为首次扣减点；若本回合该节点尚未结算，则本回合就会扣减。
3. 若未显式声明 `persists_on_switch = true`，则离场时移除。
4. 当前不允许只写“按触发次数移除”这种口头规则；因为现行基线还没有这套持续模型。

## 9. 防循环与安全保护

|项|规则|
|---|---|
|`event_chain_id`|每次独立结算链都要建立|
|`chain_origin`|固定为 `battle_init / action / turn_start / turn_end / system_replace` 之一|
|去重键|同一链路内使用 `source_instance_id + trigger + event_id`|
|链深限制|使用可配置项 `max_chain_depth`|
|fail-fast|链深超限、非法实例、去重保护命中时立即报错|
|终止语义|进入 `invalid_battle` 后，本场立即结束并记为 `no_winner`|

补充规则：

1. `resource_forced_default` 与 `timeout_default` 虽然是自动替代动作，但进入行动队列后仍属于 `chain_origin = action`。

## 10. 技能、被动、持有物对接字段

### 10.1 技能

|字段|说明|
|---|---|
|`effects_on_cast`|在 `on_cast` 触发；固定发生在扣 MP 之后、命中判定之前|
|`effects_on_hit`|命中侧 payload 全部完成后触发|
|`effects_on_miss`|未命中确认后触发|
|`effects_on_kill`|当前行动在本窗口被判定为 `killer` 后触发|

### 10.2 被动

|字段|说明|
|---|---|
|`triggers`|监听的触发点列表|
|`effects`|触发后施加的效果|
|`conditions`|触发条件|

### 10.3 持有物

|字段|说明|
|---|---|
|`effects_always_on`|常驻效果|
|`effects_on_receive`|禁用迁移字段（当前必须为空，非空即加载期失败）|
|`effects_on_turn`|回合节点触发|

补充规则：

1. `forced_replace` payload 当前已落地最小执行链（候选校验、系统选择、生命周期触发顺序），且只覆盖 1v1 单 active 槽位。

## 11. 扩展纪律

|项|规则|
|---|---|
|新增触发点|必须先写入本文件|
|新增 payload|必须写清作用时机、归属、排序与日志字段|
|新增持续效果|必须同步更新模块 04 的生命周期口径|
|新增属性相关机制|必须同步更新模块 03 的伤害和命中规则|
|放开更宽的作用域或目标模型|如 `side`、多目标、自定义目标；必须先同步更新模块 02 / 04 的目标与生命周期口径|
|修改核心流程语义|不得通过 `rule_mod` 绕过；必须直接改模块 01 / 02 / 04|
