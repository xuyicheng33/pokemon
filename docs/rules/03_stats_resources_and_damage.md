# 模块 03：数值、资源、技能、命中与伤害

本文件定义“角色有哪些战斗属性、技能怎么消费、命中怎么判、伤害怎么算”。

## 1. 角色数值体系

|属性|说明|
|---|---|
|HP|生命值上限与当前生命|
|攻击|物理伤害用攻击值|
|防御|物理承伤用防御值|
|特攻|特殊伤害用特攻值|
|特防|特殊承伤用特防值|
|速度|行动排序用速度值|

## 2. 等级与能力阶段

|项|规则|
|---|---|
|战斗等级|固定 `Lv = 50`|
|能力阶段范围|`-2 ~ +2`|
|阶段换算|`n >= 0` 时为 `(2 + n) / 2`；`n < 0` 时为 `2 / (2 - n)`|
|超上限 / 下限|直接截断到边界值|
|日志|必须记录实际变化量|

补充规则：

1. 当前能力阶段只作用于 `攻击 / 防御 / 特攻 / 特防 / 速度`。
2. 若未来要让技能直接改命中或闪避，需要先补规则，不得直接实现。

## 3. 资源系统（MP / 奥义点）

### 3.1 字段

|字段|说明|
|---|---|
|`max_mp`|MP 上限|
|`mp`|当前 MP|
|`init_mp`|战斗开始时 MP 初始值|
|`regen_per_turn`|每回合自动回复 MP 数值|

### 3.2 规则

|项|规则|
|---|---|
|回复时点|固定在 `turn_start`|
|上限截断|任何回复后 `mp <= max_mp`|
|下限截断|任何扣减后 `mp >= 0`|
|MP 不足|对应技能非法，必须在选择阶段拦截|
|资源消耗时点|行动到达自己的执行起点时先扣 MP，再做命中或其他后续判定；若后续 miss，MP 不返还|

补充规则：

1. `turn_start` 的 MP 回复只读取“本回合开始前已经生效”的常驻状态：当前在场单位面板、已存在的被动持有物常驻效果、已存在的 field、以及上一结算窗口已经落地的规则修正。
2. 同一个 `turn_start` 节点里新触发的 `apply_field`、`apply_effect`、`rule_mod`，不回头改写本次 MP 回复结果，只影响后续节点或下一次对应节点。
3. 对技能、奥义和两类默认动作，执行起点固定顺序为：`has_acted = true -> 扣 MP -> 触发 on_cast / effects_on_cast_ids -> 命中判定 -> 后续 payload / on_hit / on_miss`。
4. 当前 manager 建局后会按同一 `turn_start` 规则为第 1 回合选指预先应用一次 MP 回复；首个 `run_turn` 不得重复回这一次蓝。

### 3.3 奥义点

|字段|说明|
|---|---|
|`ultimate_points`|当前奥义点|
|`ultimate_points_required`|该角色施放奥义所需点数|
|`ultimate_points_cap`|该角色奥义点上限|
|`ultimate_point_gain_on_regular_skill_cast`|每次开始施放常规技能时获得的点数|

规则冻结：

1. 只有常规技能开始施放时才加奥义点；命中与 miss 都加。
2. `wait / switch / ultimate / resource_forced_default / surrender` 都不加奥义点。
3. 奥义合法性必须同时满足：`current_mp >= mp_cost` 且 `ultimate_points >= ultimate_points_required`。
4. 奥义开始施放时立即清空奥义点；后续无论命中、miss 还是 post-start 失败，都不返还。
5. 奥义点属于单位运行态，换下后保留。
6. 奥义点必须进入公开快照与日志；至少要能看到加点、清零和变化后的当前点数。

### 3.4 动态对位面板差公式补充

- `dynamic_value_formula = matchup_bst_gap_band` 当前固定按双方 `max_hp + attack + defense + sp_attack + sp_defense + speed + max_mp` 的绝对差求值。
- `max_mp` 当前视为正式第七维；宿傩的对位追加回蓝与相关回归都依赖这个口径。
- 该公式当前只允许用于单位 owner 的数值型 `rule_mod`，目标对位固定取当前敌方 active。

## 4. 技能系统

### 4.1 技能分类

|大类|说明|
|---|---|
|物理技能|用攻击打防御|
|特殊技能|用特攻打特防|
|效果技能|不直接造成伤害，主要用于回复、改数值、展开 field、施加当前规则已写清的持续效果|
|奥义|特殊主动技能；`priority` 只能是 `+5` 或 `-5`|

补充规则：

1. 奥义不另立第二套资源或命中体系；继续使用 `mp_cost / accuracy / targeting / effects_on_cast_ids` 等通用技能字段。
2. 奥义可承载当前基线已允许的 payload 类型；不得绕开模块 06 另写专用 payload。
3. 奥义的基础资源体系仍复用技能通用字段，但额外受角色级奥义点约束。

### 4.2 技能基础字段

|字段|说明|
|---|---|
|`id`|技能唯一标识|
|`display_name`|技能名|
|`damage_kind`|`physical / special / none`|
|`power`|技能威力；伤害技能必填|
|`accuracy`|命中率，百分比口径 `0 ~ 100`，默认 `100`|
|`mp_cost`|MP 消耗|
|`priority`|优先级；普通技能允许 `-2 ~ +2`，奥义只能是 `+5` 或 `-5`|
|`combat_type_id`|战斗属性；空串表示无属性技能|
|`damage_segments`|可选；多段主动伤害定义。整招仍只有一次命中判定，命中后再按段依次结算|
|`execute_target_hp_ratio_lte / execute_required_total_stacks / execute_self_effect_ids / execute_target_effect_ids`|可选；命中后、常规伤害前的技能级处决 contract|
|`targeting`|`enemy_active_slot / self / field`|
|`effects_on_cast_ids / effects_on_hit_ids / effects_on_miss_ids / effects_on_kill_ids`|见模块 06|

### 4.3 `combat_type` 战斗属性字段

|对象|规则|
|---|---|
|单位|`combat_type_ids` 允许 `0..2` 个|
|技能|`combat_type_id` 允许 `0..1` 个；空串表示无属性|
|系统边界|`combat_type` 只参与属性克制，不替代 `damage_kind`|

补充规则：

1. `damage_kind = physical / special / none` 仍只决定攻防取值，不决定属性克制。
2. 单位无属性或技能无属性时，该次伤害的属性倍率固定为 `1.0`。
3. 当前不做战中改属性；运行时只镜像定义层的 `combat_type_ids`。

## 5. 默认动作

### 5.1 资源型默认动作触发条件

当且仅当以下条件同时满足时，当前单位自动改用 `resource_forced_default`：

1. 本回合所有主动技能都非法。
2. 没有合法手动换人。
3. 奥义非法或当前无可用奥义。

### 5.2 超时替代动作触发条件

当选择阶段超时且该方尚未提交合法指令时：

1. 若满足 5.1（强制资源型默认动作 `resource_forced_default`）则自动改用 `resource_forced_default`。
2. 否则自动改用 `wait`，并写入 `command_source = timeout_auto`。
3. `select_timeout` 由 `command_source == timeout_auto` 判定，不依赖动作类型名。

### 5.3 默认动作定义

|项|规则|
|---|---|
|`damage_kind`|`physical`|
|`power`|`50`|
|`accuracy`|`100`|
|`priority`|`0`|
|`mp_cost`|`0`|
|目标|敌方在场位置|
|附加效果|无|
|反伤|对自己造成 `floor(max_hp * BattleFormatConfig.default_recoil_ratio)` 反伤，至少 1；当前样例默认 `0.25`|

## 6. 命中判定

|项|规则|
|---|---|
|命中来源|先取技能自身 `accuracy`，再按当前已接线读取点修正|
|内部换算|`hit_rate = clamp(accuracy / 100, 0, 1)`|
|判定方式|抽 `hit_roll`；若 `hit_roll < hit_rate` 则命中|
|`accuracy = 100`|视为必中，不需要再判 miss|
|闪避率|当前没有该属性|
|field 命中覆盖|若当前 field 的 `creator_accuracy_override >= 0`，且行动者正是该 field creator，则本次命中直接改用这个覆盖值|
|目标侧命中干扰|若 `resolved_accuracy < 100`，且本次是敌方来袭 `skill / ultimate`、`targeting = enemy_active_slot`、目标为敌方 active，则再读取目标侧 `incoming_accuracy`，整轮结束后 clamp 到 `0..99`|

补充规则：

1. 当前没有命中阶段、闪避阶段、`ignore_evasion`、`allow_full_evasion` 这类机制。
2. 命中失败时只记 `miss`，不要混成“目标免疫”或“被闪避”。
3. 命中成立后，行动本体的伤害或效果 payload 按模块 06 的声明顺序执行；全部完成后再进入 `effects_on_hit_ids`。未命中则不执行命中侧 payload，直接进入 `effects_on_miss_ids`。
4. `incoming_accuracy` 不得把命中改成硬必中；`100` 只由技能本体或 field 覆盖产生。

## 7. RNG 契约

|项|规则|
|---|---|
|统一 RNG|整场战斗只使用同一确定性 RNG|
|日志头|必须记录 `battle_seed` 与 `battle_rng_profile`|
|消费序号|每次随机都必须记录 `rng_stream_index`|
|当前最小随机集合|`speed_tie_roll -> hit_roll -> effect_roll`|

补充规则：

1. 当前没有 `crit_roll`、`damage_roll`。
2. 若以后某个技能带额外概率效果，统一走 `effect_roll`。

## 8. 简化伤害公式

### 8.1 基础公式

参考官方骨架，但去掉暴击、随机伤害、同属性加成、真伤与护盾。

|步骤|公式|
|---|---|
|基础伤害 `base_damage`|`floor(floor(((2 * Lv / 5 + 2) * Power * A / max(1, D))) / 50) + 2`|
|固定等级 50 的等价写法|`floor(floor(22 * Power * A / max(1, D)) / 50) + 2`|
|最终伤害 `final_damage`|`max(1, floor(base_damage * final_mod))`|

### 8.2 攻防取值

|伤害类型|`A`|`D`|
|---|---|---|
|物理|阶段修正后的攻击|阶段修正后的防御|
|特殊|阶段修正后的特攻|阶段修正后的特防|

### 8.3 最终倍率 `final_mod`

当前只允许以下来源进入 `final_mod`：

|来源|说明|
|---|---|
|技能自身倍率|技能描述写清楚时可用|
|被动持有物倍率|被动持有物可加减伤|
|field 倍率|当前 field 可按技能描述改伤害|
|`rule_mod`|只允许通过 `final_mod` 白名单读取点进入|
|`type_effectiveness`|按 `combat_type_chart` 查表得到的属性克制倍率|

默认：

`final_mod = skill_mod * item_mod * field_mod * rule_mod * type_effectiveness`

未声明时各项都按 `1.0`。

### 8.4 属性克制规则

|项|规则|
|---|---|
|查表来源|`BattleFormatConfig.combat_type_chart`|
|表项粒度|只认显式 `(atk, def) -> mul` 条目|
|缺失 pair|默认 `1.0`|
|单位双属性|对目标 `combat_type_ids` 逐项查表并连乘|
|合法倍率|单条表项只允许 `2.0 / 1.0 / 0.5`|
|STAB|当前不做|
|免疫|当前不做 `0.0`|

补充规则：

1. 当前不做“反向自动推导”；chart 里写什么就按什么算，没有就是中立。
2. `DamagePayload.use_formula = true` 且存在 `chain_context.skill_id` 时，也继承该技能的 `combat_type_id` 参与克制。
3. `DamagePayload.use_formula = true` 时，若链技能自身 `damage_kind` 已声明为 `physical / special`，则公式伤害继承该攻防路径与对应阶段修正；若链技能为 `none`，则回退到 payload 自身的 `damage_kind`。
4. 非技能链公式伤害使用 `DamagePayload.damage_kind` 决定 `A / D` 与阶段修正；这类路径固定 `type_effectiveness = 1.0`。
5. 默认动作与反伤一律按 `type_effectiveness = 1.0` 处理。

## 9. 当前明确不做的伤害机制

|机制|口径|
|---|---|
|暴击|当前不做|
|伤害随机浮动|当前不做|
|真实伤害|当前不做|
|护盾吸收|当前不做|
|同属性加成|当前不做|

## 10. 伤害边界

|项|规则|
|---|---|
|防御下限|分母 `D` 至少为 1|
|命中失败|直接 `damage = 0`|
|伤害下限|成功命中的伤害技能，最终至少造成 1 点伤害|
|负值保护|任何倍率链计算后若 `< 0`，先按 0 处理，再套最小伤害规则|
|HP 下限|扣血后 `hp >= 0`|

边界顺序固定如下：

1. 先判是否命中。
2. 命中后计算 `base_damage`。
3. 乘上 `final_mod`，做负值保护。
4. 对伤害技能应用最小伤害 `1`。
5. 再扣 HP。

## 11. 回复、反伤与复活

|项|规则|
|---|---|
|治疗|治疗后 `hp <= max_hp`|
|倒下单位治疗|默认不可治疗|
|反伤|按独立伤害事件处理，必须写明来源归属|
|复活|当前关闭|

补充规则：

1. `HealPayload.use_percent = true` 时，当前正式支持两种百分比基准：
   - `percent_base = max_hp`
   - `percent_base = missing_hp`
2. `percent_base = missing_hp` 时，基数固定为 `target.max_hp - target.current_hp`。
3. 只要目标当前 `missing_hp > 0` 且本次百分比治疗合法，最终治疗值至少为 `1`。
4. 目标侧 `incoming_heal_final_mod` 在基础治疗量解出后、最终 HP clamp 前参与结算；若最终治疗值 `<= 0`，本次不写 `effect:heal`。

## 12. 多段主动伤害与技能级处决

|项|规则|
|---|---|
|多段主动伤害|`SkillDefinition.damage_segments` 已正式支持；命中后按段展开并逐段结算|
|命中判定|整招仍只有一次命中判定；miss 时整组分段都不进入伤害结算|
|逐段结算|每段独立计算威力、属性克制、`incoming_action_final_mod` 与 HP 变化|
|逐段日志|每段继续写现有 `effect:damage`，并在 `payload_summary` 标明 `segment i/n`|
|逐段触发|每个成功结算段后都会派发 `on_receive_action_damage_segment`；`on_receive_action_hit` 仍然只表示整次来袭行动一次|
|中途终止|目标在中途倒下或离开 active 后，剩余段数立即停止|
|技能级处决|`execute_*` 当前在“命中后、常规伤害前”判定；成功后直接把目标 HP 置 `0` 并写 `[execute]` 伤害日志|

## 13. 首个可玩基线的技能复杂度

|内容|口径|
|---|---|
|多段攻击|当前已作为共享主线能力接入，但新增角色仍应优先复用 `damage_segments`，不做角色专用多段分支|
|复杂连锁倍率|当前不建议做得太深，避免首版实现失控|
|持续效果|若技能需要持续效果，当前只允许“按回合”或“永久”两种持续方式；并必须写清触发点、离场是否清除|
