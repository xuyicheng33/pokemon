# Combat Math（数值结算）

本文件定义纯计算层。这里的服务尽量无副作用，只返回计算结果对象。

## 1. 文件清单

|文件|职责|
|---|---|
|`stat_calculator.gd`|计算有效攻防速与阶段修正|
|`mp_service.gd`|MP 回复与消耗结果计算|
|`hit_service.gd`|命中判定|
|`damage_service.gd`|基础伤害与最终倍率计算|
|`combat_type_service.gd`|属性克制查表与连乘计算|

## 2. 接口约束

- `math` 不直接改 `BattleState`。
- `math` 可以读取内容定义和快照值。
- 需要随机的计算点必须显式接收 `RngService`。

## 3. 服务 contract

|服务|输入|输出|
|---|---|---|
|`StatCalculator`|基础数值 + 阶段|有效数值|
|`MpService.apply_turn_start_regen`|当前 MP + 修正|回复结果|
|`MpService.consume_mp`|当前 MP + cost|消耗结果|
|`HitService.roll_hit`|accuracy + rng|是否命中|
|`DamageService.calc_base_damage`|攻击/防御/威力/等级|基础伤害|
|`DamageService.apply_final_mod`|基础伤害 + rule mod|最终伤害|
|`CombatTypeService.calc_effectiveness`|技能属性 + 目标属性列表|属性倍率|

## 4. RNG 约束

当前只允许以下节点消费随机：

- 同速打平
- 命中判定
- 规则明确要求的额外概率效果

随机消费序号必须交给 logging 层记录。
