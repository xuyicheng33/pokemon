# 模块 04：换人、离场与生命周期

本文件定义“当前版本有哪些生命周期规则、离场清什么、补位怎么走”。
当前极简基线不内置通用状态包；若以后某个技能需要持续效果，按本文件的生命周期规则单独定义。

实现状态说明（2026-03-25）：

- `forced_replace` 已接入 payload 执行路径，并按本文件顺序执行完整生命周期链。

## 1. 当前状态口径

|项|规则|
|---|---|
|通用状态包|当前不内置|
|中毒 / 灼伤 / 麻痹 / 睡眠 / 畏缩|当前都不属于标准基线|
|未来扩展方式|由具体技能或效果单独定义其持续时间、触发点、离场去留、日志字段|

补充规则：

1. 现在不允许代码里偷偷先写一套默认状态框架，再说“以后会用”。
2. 若后续要恢复通用状态，必须先改文档，再实现。

## 2. 离场原因

|`leave_reason`|定义|
|---|---|
|`manual_switch`|玩家主动换人|
|`forced_replace`|被技能或效果强制换下，但单位未倒下|
|`faint`|HP 归 0 导致离场|

### 2.1 强制换下 vs 强制补位

|项|强制换下（`forced_replace`）|强制补位（faint 后 replace）|
|---|---|---|
|触发来源|技能/效果把在场存活单位强制换下|击倒窗口里 active 为空后的系统补位|
|是否进入行动队列|否|否|
|是否触发 `on_switch`|是|否|
|是否触发 `on_exit`|是|是（由倒下离场链触发）|
|替补选择契约|候选 > 1 时走系统替补选择接口；候选 = 1 自动锁定|候选 > 1 时走系统替补选择接口；候选 = 1 自动锁定|
|选择失败语义|接口返回空值/非法/超时 -> `invalid_battle`|接口返回空值/非法/超时 -> `invalid_battle`|

## 3. 离场重置表

|战斗态|`manual_switch`|`forced_replace`|`faint`|说明|
|---|---|---|---|---|
|当前 HP / MP|保留|保留|HP = 0；不再继续参与结算|存活单位的 HP/MP 带下场|
|能力阶段|移除|移除|移除|当前不允许跨离场保留|
|单位级 effect 实例|仅保留 `persists_on_switch=true` 的 unit effect；其余移除|仅保留 `persists_on_switch=true` 的 unit effect；其余移除|全部移除|板凳上的持久 effect 只继续倒计时，不跑普通每回合触发|
|单位级 rule_mod 实例|仅保留 `persists_on_switch=true` 的 unit rule mod；其余移除|仅保留 `persists_on_switch=true` 的 unit rule mod；其余移除|全部移除|`field` scope 不允许声明 `persists_on_switch=true`|
|锁定目标 / 蓄力标记 / 本行动临时标记|移除|移除|移除|不得跨离场保留|
|当前回合队列项|若尚未轮到则取消|若尚未轮到则取消|取消|见模块 02|
|被动持有物|保留|保留|随单位失效|装备关系不变|
|field|若离场者不是 creator 则保留；若离场者是 creator，则离场清理完成后立即提前打断|若离场者不是 creator 则保留；若离场者是 creator，则离场清理完成后立即提前打断|若离场者不是 creator 则保留；若离场者是 creator，则离场清理完成后立即提前打断|field 属于全场，但 creator 离场会触发提前打断|
|已公开信息|保留为公开|保留为公开|保留为公开|日志与回放需要稳定信息|

## 4. 主动换人顺序

|步骤|规则|
|---|---|
|1|手动换人行动开始执行|
|2|旧单位触发 `on_switch`，并带 `leave_reason = manual_switch`|
|3|旧单位触发 `on_exit`|
|4|按离场重置表清理旧单位战斗态|
|5|若旧单位是当前 field creator，则立刻执行 `field_break`；只跑 `on_break_effect_ids`|
|6|新单位入场|
|7|新单位触发 `on_enter`|
|8|由入场触发的被动 / 持有物 / field 效果进入统一效果队列|

补充规则：

1. 手动换人指令在选择阶段必须指定唯一 bench 目标 `public_id`；校验通过后再映射到运行时 `unit_instance_id`，队列锁定后不再改选。
2. 若行动轮到前行动者已离场或倒下，该换人行动按模块 02 的 `cancelled_pre_start` 处理，不再另行补选。
3. 若行动已经开始执行，却发现所选目标不在合法 bench，视为运行态破坏规则，按 `invalid_battle` 处理。
4. 新入场单位、其 `on_enter`、以及后续 `on_matchup_changed` 不得读取一个按本规则已被打断的旧 field。
5. 若旧单位保留了 `persists_on_switch=true` 的 effect / rule mod，它们跟着单位下场保留，但不会让该单位继续以“在场单位”身份参与普通回合批次。

## 5. 强制换下顺序

|步骤|规则|
|---|---|
|1|强制换下效果到达执行起点，先检查是否存在合法替补|
|2|若存在合法替补，旧单位触发 `on_switch`，并带 `leave_reason = forced_replace`|
|3|旧单位触发 `on_exit`|
|4|按离场重置表清理旧单位战斗态|
|5|若旧单位是当前 field creator，则立刻执行 `field_break`；只跑 `on_break_effect_ids`|
|6|替补立刻入场并触发 `on_enter`|

补充规则：

1. 强制换下的替补选择必须走系统接口：合法 bench 候选 > 1 时返回目标 `unit_instance_id`；若只剩 1 名则自动锁定。
2. 若系统接口返回空值、返回不在合法候选列表、或超时，按 `invalid_replacement_selection` 立即终止战斗。
3. 若当前没有合法 bench，强制换下效果直接失效；不触发 `on_switch / on_exit`，也不改写当前 active。
4. 提前打断不会触发 `effect:field_expire`，也不会执行 `on_expire_effect_ids`。
5. `forced_replace` 与 `manual_switch` 的保留口径一致：只保留显式声明 `persists_on_switch=true` 的 unit effect / unit rule mod。

## 6. 倒下离场顺序

|步骤|规则|
|---|---|
|1|当单位 HP 归 0，立刻标记为 `fainted_pending_leave`|
|2|从这一刻起，该单位失去在场资格，但保留到当前击倒窗口里统一处理离场|
|3|倒下单位触发 `on_faint`|
|4|若本次倒下存在可归属来源，则对来源触发 `on_kill`|
|5|倒下单位触发 `on_exit`，并带 `leave_reason = faint`|
|6|按离场重置表清理战斗态|
|7|若离场单位是当前 field creator，则立刻执行 `field_break`；只跑 `on_break_effect_ids`|
|8|若该方仍有后备单位，则立即执行强制补位|
|9|新单位入场并触发 `on_enter` 及其相关效果|

补充规则：

1. 倒下不是主动换人，不触发 `on_switch`。
2. 强制补位不是普通行动，不进入行动排序。
3. 当前基线没有“可作用于倒下单位”的特例；治疗、资源变化与普通持续效果都不能再对 `fainted_pending_leave` 生效。
4. 强制补位的替补选择必须走系统接口：合法 bench 候选 > 1 时返回目标 `unit_instance_id`；若只剩 1 名则自动锁定。
5. 若系统接口返回空值、返回不在合法候选列表、或超时，按 `invalid_replacement_selection` 立即终止战斗。
6. 旧 field 被提前打断后，补位链和新单位 `on_enter` 不得再读取它。

## 7. 同窗双倒下处理

若同一结算窗口内双方同时倒下，固定按以下顺序处理：

1. 先把本窗内所有倒下单位都标记为 `fainted_pending_leave`。
2. 再处理这些单位的 `on_faint`、`on_kill`、`on_exit`。
3. 完成本窗全部离场清理后，再统一检查双方是否还有可上场单位。
4. 若双方都有后备，则双方替补先同时进入 active。
5. 双方新单位都站稳后，再统一处理 `on_enter` 与入场衍生效果。
6. 若双方都没有后备，则本窗直接判平局。

补充规则：

1. 当前运行态判定只使用 `fainted_pending_leave` 作为“已倒下、待离场”的状态名；`fainted` 只允许作为摘要文案，不作为规则判定态。

## 8. 回合节点与生命周期

|节点|规则|
|---|---|
|`turn_start`|普通 trigger batch 只处理当前在场单位与全场 field|
|`turn_end`|普通 trigger batch 只处理当前在场单位与全场 field|
|bench 持久 effect|若单位持有 `persists_on_switch=true` 的 effect，则该 effect 在 bench 上继续扣 `remaining`|
|bench 持久 effect 到期|只做正常移除与移除日志；不派发 `on_expire_effect_ids`|
|bench 单位普通回合行为|不参与 `turn_start / turn_end` 普通触发、被动结算或其他在场限定批次|
|重新上场后|重新以在场单位身份参与后续回合，并继续带着未到期的持久 effect / rule mod|

## 9. 未来持续效果的接入纪律

后续若某个技能要加持续效果，至少必须补清以下字段：

|项|必须写清|
|---|---|
|持续时间|当前只允许按回合或永久；若以后要做按触发次数，必须先改模块 06|
|触发点|`turn_start`、`turn_end`、`on_hit` 等哪个节点生效|
|离场去留|换人后清除还是保留|
|归属|来源是谁，挂在谁身上|
|日志|施加、刷新、移除、结算都怎么记|

补充规则：

1. 若 effect 要跨非击倒离场保留，必须显式声明 `persists_on_switch=true`；未声明就按默认离场清除。
2. 若 `persists_on_switch=true` 的 effect 自身携带 `rule_mod` payload，这些 payload 也必须显式声明 `persists_on_switch=true`。
3. 板凳持续效果当前只支持“时间继续流动”；若以后要支持板凳上继续跑普通 `turn_start / turn_end` 结算，必须单开规则，不得默认放开。
