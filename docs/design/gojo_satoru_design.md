# 五条悟（Gojo Satoru）设计方案（审计收口版 v4.2）

## 0. 审计后冻结结论（2026-03-29）

| 项目 | 结论 |
|------|------|
| 茈 | 保留“苍+赫双标记”条件爆发，**不做自伤** |
| 无下限 | 改为“敌方技能或奥义攻击五条悟时，若该次不是必中，则命中率 -10” |
| 奥义点 | `required=3 / cap=3 / regular_skill_cast +1` |
| 无量空处锁人条件 | 只有领域**成功立住**时，才通过 `on_success_effect_ids -> field_apply_success` 施加 `gojo_domain_action_lock` |
| 领域增幅归属 | `sp_attack +1` 改为 field 绑定效果；成功立场时生效，领域自然结束/提前打断时移除，对拼失败时不成立 |
| 领域后摇 | **删除**（不再追加封印/回滚） |
| 施工顺序 | **第 4 节扩展、第 5 节资源、第 6 节 `gojo_suite` 均已落地；本轮新增奥义点 / 领域对拼 / field 绑定增幅专项回归** |
| 苍/赫标记归属 | 标记挂在**目标**身上；换人清除只发生在**标记持有者**离场时 |
| 苍/赫标记消耗语义 | 引擎层当前只检查目标是否同时持有双标记，不校验施加者；但**同队重复角色已禁止**，正式玩法不包含“双五条悟接力消耗”场景 |
| 已接线引擎扩展 | `action_legality`、`required_target_effects`、`incoming_accuracy` 已进入当前主线；若要收紧为“必须同一施法者本人消耗标记”，仍需**第 4 块扩展** |
| 明确不做 | `effects_pre_damage_ids`、`on_before_damage`、`damage_override`、`action_tags`、`last_dealt_damage`、反噬链路 |

---

## 1. 角色基础属性

### 1.1 UnitDefinition

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `gojo_satoru` | |
| display_name | `五条悟` | |
| combat_type_ids | `["space", "psychic"]` | 空间 + 超能力 |
| base_hp | **124** | 略高于旧稿，补一点稳定性 |
| base_attack | **56** | 非体术主攻 |
| base_defense | **60** | 由旧稿上调，避免过脆 |
| base_sp_attack | **88** | 术式主输出 |
| base_sp_defense | **68** | 中等抗性 |
| base_speed | **86** | 高速定位 |
| BST | **482** | 低于宿傩（486） |

### 1.2 MP 系统

| 字段 | 值 | 说明 |
|------|-----|------|
| max_mp | **100** | |
| init_mp | **50** | 首回合可规划一轮爆发，但不再过宽 |
| regen_per_turn | **14** | 从旧稿 16 下调，压缩连续压制 |

补充语义：

- 按当前 main 的固定回合时序，`turn_start` MP 回复发生在第 1 回合选指前；因此五条悟首个可操作回合的实战可用 MP 是 `64`，不是 `50`。

### 1.3 技能组与赛前装配

**内容层（UnitDefinition）**

- 默认配招（`skill_ids`，3 个）：`gojo_ao`、`gojo_aka`、`gojo_murasaki`
- 奥义（`ultimate_skill_id`）：`gojo_unlimited_void`
- 候选技能池（`candidate_skill_ids`，4 个）：`gojo_ao`、`gojo_aka`、`gojo_murasaki`、`gojo_reverse_ritual`

**赛前层（SideSetup）**

- 本场装配通过 `SideSetup.regular_skill_loadout_overrides` 决定（该字段属于 `SideSetup`，不属于 `UnitDefinition`）。
- 当 `candidate_skill_ids` 非空时，允许赛前从候选池选 3 个写入运行时配招。

### 1.4 被动

| 类型 | 值 |
|------|-----|
| passive_skill_id | `gojo_mugen` |
| passive_item_id | `` |

---

## 2. 技能详细设计

> 领域公共模板见 `docs/design/domain_field_template.md`。本稿只写五条悟在该模板下的角色差异。

### 2.1 苍（Ao）

| 字段 | 值 |
|------|-----|
| id | `gojo_ao` |
| display_name | `苍` |
| damage_kind | `special` |
| power | **44** |
| accuracy | **95** |
| mp_cost | **14** |
| priority | **0** |
| combat_type_id | `space` |
| targeting | `enemy_active_slot` |
| effects_on_cast_ids | `[]` |
| effects_on_hit_ids | `["gojo_ao_speed_up", "gojo_ao_mark_apply"]` |
| effects_on_miss_ids | `[]` |
| effects_on_kill_ids | `[]` |

命中后效果：

- `gojo_ao_speed_up`：`scope=self`，`stat_mod(speed, +1)`
- `gojo_ao_mark_apply`：`scope=target`，`apply_effect(gojo_ao_mark)`

### 2.2 赫（Aka）

| 字段 | 值 |
|------|-----|
| id | `gojo_aka` |
| display_name | `赫` |
| damage_kind | `special` |
| power | **44** |
| accuracy | **95** |
| mp_cost | **14** |
| priority | **0** |
| combat_type_id | `psychic` |
| targeting | `enemy_active_slot` |
| effects_on_cast_ids | `[]` |
| effects_on_hit_ids | `["gojo_aka_slow_down", "gojo_aka_mark_apply"]` |
| effects_on_miss_ids | `[]` |
| effects_on_kill_ids | `[]` |

命中后效果：

- `gojo_aka_slow_down`：`scope=target`，`stat_mod(speed, -1)`
- `gojo_aka_mark_apply`：`scope=target`，`apply_effect(gojo_aka_mark)`

顺序约束：

- 苍 / 赫的两个 `effects_on_hit_ids` 当前不依赖声明顺序；在现有效果队列模型下，同批次同来源 effect 若排序键完全一致，默认会进入随机打平。
- 因此本设计不允许“先加速后上标记”或“先减速后上标记”这种先后差异影响玩法正确性；若未来要引入跨 effect 先后依赖，必须显式拉开 `priority`。

### 2.3 苍 / 赫标记 Effect 明细

`gojo_ao_mark_apply` / `gojo_aka_mark_apply`（施加标记）：

- EffectDefinition：`scope=target`, `duration_mode=permanent`, `decrement_on=""`, `stacking=none`, `trigger_names=["on_hit"]`
- payload：`apply_effect(gojo_ao_mark)` 或 `apply_effect(gojo_aka_mark)`

`gojo_ao_mark` / `gojo_aka_mark`（纯标记本体）：

- EffectDefinition：`scope=self`, `duration_mode=turns`, `duration=3`, `decrement_on=turn_end`, `stacking=refresh`, `trigger_names=[]`, `payloads=[]`, `persists_on_switch=false`
- 说明：纯标记 effect 无 payload，不直接产生数值结算；仅用于条件判定。
- owner 语义：标记实例挂在**目标本人**身上，不挂在五条悟身上。
- 换人语义：`persists_on_switch=false` 代表“**标记持有者**离场会清标记”；若五条悟自己离场，目标身上的标记不会因此自动消失。
- 当前正式玩法语义：只要目标身上同时存在 `gojo_ao_mark + gojo_aka_mark`，当前出战的这名五条悟就能触发 `gojo_murasaki` 追加段；由于队伍构筑规则已禁止同队重复角色，正式对局里不会出现“双五条悟接力消耗同一目标标记”的验收场景。
- 时间语义：`duration=3 + decrement_on=turn_end` 按当前引擎表示“从施加当回合开始，连续经过 3 次 `turn_end` 节点后到期”。例如第 1 回合中途施加，则会在第 1/2/3 回合的 `turn_end` 各扣 1 次，并在第 3 次后移除。

### 2.4 茈（Murasaki）—— 条件追加爆发（无自伤）

| 字段 | 值 |
|------|-----|
| id | `gojo_murasaki` |
| display_name | `茈` |
| damage_kind | `special` |
| power | **64** |
| accuracy | **90** |
| mp_cost | **24** |
| priority | **-1** |
| combat_type_id | `space` |
| targeting | `enemy_active_slot` |
| effects_on_cast_ids | `[]` |
| effects_on_hit_ids | `["gojo_murasaki_conditional_burst"]` |
| effects_on_miss_ids | `[]` |
| effects_on_kill_ids | `[]` |

`gojo_murasaki_conditional_burst`（单 effect 完成条件爆发 + 清标记）：

- EffectDefinition：`scope=target`, `duration_mode=permanent`, `decrement_on=""`, `stacking=none`, `trigger_names=["on_hit"]`
- `required_target_effects = ["gojo_ao_mark", "gojo_aka_mark"]`
- payload 顺序：
1. `damage(use_formula=true, amount=32, damage_kind=special)`（条件追加一段伤害；`amount` 在 `use_formula=true` 下作为公式威力）
2. `remove_effect(gojo_ao_mark)`
3. `remove_effect(gojo_aka_mark)`

补充说明：

- 此处不额外写 `combat_type_id`：`DamagePayload.use_formula=true` 且处于技能链中时，类型继承链技能 `gojo_murasaki` 的 `combat_type_id=space`。
- `required_target_effects` 当前只检查“目标身上是否同时存在双标记”，**不检查标记施加者是谁**。在“同队重复角色禁止”的当前规则下，这已经足够支撑 Gojo 的正式玩法闭环。
- `required_target_effects` 的设计目标是“effect 级前置守卫”，不是 payload 级条件分支；前置不满足时，整条 effect 直接退出，payload 循环不会开始，因此也不会写出任何由该 effect 产生的 payload 日志。
- 若未来要改成“只有同一个五条悟本人打上的双标记，才允许该五条悟自己触发茈追加段”，则仅靠 `required_target_effects` 不够，必须新增第 4 块扩展能力来校验标记来源。

语义：

- 条件满足：追加爆发并消耗双标记。
- 条件不满足：只结算茈本体伤害，不做额外动作。
- **不做任何反噬 / 自伤**。

边界：

- 若茈本体伤害已经把目标打到 `hp <= 0`，则 `on_hit` 追加 effect 在当前执行模型里会因为目标已无效而整条跳过，不会再打追加段，也不会清标记。
- 若追加伤害把目标打到 `hp <= 0`，后续 `remove_effect` 会因目标不再满足 `ACTIVE && hp > 0` 被静默跳过，不会报错；这属于当前 payload 有效性模型下的预期行为。
- 若目标在五条悟行动前通过换人离开 active 槽位，则 `enemy_active_slot` 的茈会命中当时站在该槽位的新 active；而原目标作为标记持有者离场时会按 `persists_on_switch=false` 清掉双标记，因此这类“被换下后由替补吃到茈”的场景默认不会触发追加段。

### 2.5 反转术式（Reverse Ritual）

| 字段 | 值 |
|------|-----|
| id | `gojo_reverse_ritual` |
| display_name | `反转术式` |
| damage_kind | `none` |
| power | **0** |
| accuracy | **100** |
| mp_cost | **14** |
| priority | **0** |
| combat_type_id | `` |
| targeting | `self` |
| effects_on_cast_ids | `["gojo_reverse_heal"]` |
| effects_on_hit_ids | `[]` |
| effects_on_miss_ids | `[]` |
| effects_on_kill_ids | `[]` |

效果：

- `gojo_reverse_heal`：`heal(use_percent=true, percent=25)`

### 2.6 无量空处（Unlimited Void）—— 奥义

| 字段 | 值 |
|------|-----|
| id | `gojo_unlimited_void` |
| display_name | `无量空处` |
| damage_kind | `special` |
| power | **48** |
| accuracy | **100** |
| mp_cost | **50** |
| priority | **+5** |
| combat_type_id | `space` |
| targeting | `enemy_active_slot` |
| effects_on_cast_ids | `[]` |
| effects_on_hit_ids | `["gojo_apply_domain_field"]` |
| effects_on_miss_ids | `[]` |
| effects_on_kill_ids | `[]` |

**FieldDefinition: `gojo_unlimited_void_field`**

| 字段 | 值 |
|------|-----|
| id | `gojo_unlimited_void_field` |
| display_name | `无量空处` |
| creator_accuracy_override | **100** |
| effect_ids | `["gojo_domain_cast_buff"]` |
| on_expire_effect_ids | `["gojo_domain_buff_remove"]` |
| on_break_effect_ids | `["gojo_domain_buff_remove"]` |

**展开效果链**

1. `gojo_apply_domain_field`：`apply_field(gojo_unlimited_void_field, duration=3, decrement_on=turn_end, on_success_effect_ids=["gojo_domain_action_lock"])`
2. `gojo_unlimited_void_field.effect_ids`：`gojo_domain_cast_buff` 在 `field_apply` 触发点给五条悟 `sp_attack +1`
3. `gojo_unlimited_void_field.on_expire_effect_ids / on_break_effect_ids`：`gojo_domain_buff_remove` 在领域结束或打断时回收增幅
4. `gojo_domain_action_lock`：只有在 `gojo_apply_domain_field` 成功落地后，才作为 follow-up 生效

补充语义（领域公共规则仍以 `docs/design/domain_field_template.md` 为准）：

- 五条悟当前奥义点配置固定为：`ultimate_points_required = 3`、`ultimate_points_cap = 3`、`ultimate_point_gain_on_regular_skill_cast = 1`。
- 奥义合法性必须同时满足：`current_mp >= 50` 且 `ultimate_points >= 3`；开始施放无量空处时，奥义点立即清零；换下后点数保留。
- 若场上已有领域，`gojo_apply_domain_field` 进入领域对拼：比较双方**扣费后的当前 MP**；MP 高者留场；平 MP 随机决定胜者，并把随机值写入 `effect:field_clash.effect_roll`，保证 replay 可复现。
- 若五条悟在领域对拼中失败，则无量空处**不落地、不加 `sp_attack +1`、也不锁人**；只有领域真正成功立住后，才会继续跑 `field_apply` 增幅和 `on_success_effect_ids`（`field_apply_success`）锁人。
- 由于 `gojo_domain_cast_buff` 已改成 field 绑定效果，所以不会再出现“领域已经没了，但 `sp_attack +1` 还残留在五条悟身上”的状态。

顺序约束：

- `gojo_domain_action_lock` 不再和 `gojo_apply_domain_field` 平级并排挂在 `effects_on_hit_ids`；它固定通过 `ApplyFieldPayload.on_success_effect_ids` 触发，语义就是“领域成功后才锁人”。
- `gojo_domain_cast_buff` 固定挂在 field 的 `effect_ids` 上，通过 `field_apply` 触发；后续若要改动这条增幅语义，只允许在 field 生命周期内调整，不能再改回独立常驻 `stat_stage`。

`action_legality deny all` 的口径：

- 仅封禁技能 / 奥义 / 换人。
- 不封禁 `wait`。
- 若 Gojo **先于目标行动并且成功命中**，而目标本回合尚未开始执行，则目标已排队的技能 / 奥义 / 换人会在轮到它时按 `cancelled_pre_start` 跳过。
- 这不是“领域展开后无条件首回合锁到对方”的硬保证：若对手已经更早行动，或在同优先级竞争里先于 Gojo 执行，则本回合不会被这条锁追溯性拦下。

`gojo_domain_action_lock` 资源口径：

1. EffectDefinition：`scope=target`, `duration_mode=permanent`, `decrement_on=""`, `stacking=none`, `trigger_names=["field_apply_success"]`
2. payload：`rule_mod(mod_kind=action_legality, mod_op=deny, value=all, scope=target, duration_mode=turns, duration=1, decrement_on=turn_end, stacking=replace)`

时间语义：

- field 的 `duration=3 + decrement_on=turn_end` 与标记同口径：从施放当回合开始，连续经过 3 次 `turn_end` 节点后自然到期。
- 因此文档里写“持续 3 回合”时，指的是“3 次 `turn_end` 扣减窗口”，不是“额外再经历 3 个完整后续回合”。

本版删除领域后摇：不再追加 `expire_seal / rollback`，领域结束或被打破后不对五条悟追加封印处罚。

---

## 3. 被动技能：无下限（Mugen）

### 3.1 玩法语义

- 当敌方对五条悟发动技能或奥义时：
1. 先按现有流程得到 `resolved_accuracy`（技能精度 + 领域覆盖等）。
2. 若 `resolved_accuracy >= 100`，视为必中，**无下限不生效**。
3. 若 `resolved_accuracy < 100`，且目标是五条悟，则本次命中率再减 `10` 后再 roll。

### 3.2 资源定义

`gojo_mugen`（PassiveSkillDefinition）：

- `trigger_names = ["on_enter"]`
- `effect_ids = ["gojo_mugen_incoming_accuracy_down"]`

`gojo_mugen_incoming_accuracy_down`（EffectDefinition）：

- EffectDefinition：`scope=self`, `duration_mode=permanent`, `decrement_on=""`, `stacking=none`, `trigger_names=["on_enter"]`
- payload：`rule_mod(mod_kind="incoming_accuracy", mod_op="add", value=-10, scope="self", duration_mode="permanent", decrement_on="turn_end", stacking="none")`

说明：

- 无下限改成稳定干扰命中，不再使用概率触发，也不再改写伤害值。
- 字段约束是**双层**的：EffectDefinition 层（permanent）要求 `decrement_on=""`；RuleModPayload 层仍要求显式 `turn_start/turn_end`，因此 payload 内保留 `decrement_on="turn_end"`。
- `LeaveService` 会在单位离场时清空 `rule_mod_instances`，所以无下限必须挂在 `on_enter`，确保每次入场都重新施加。
- 运行时语义补充：对 `duration_mode=permanent` 的 RuleModPayload，`decrement_on` 不参与扣减（`remaining=-1` 不会递减）；该字段仅用于满足 payload 校验约束。

---

## 4. Gojo 依赖的引擎扩展（2026-03-29 已接线）

口径说明：

- `docs/rules/*`、`docs/design/battle_content_schema.md`、`docs/design/effect_engine.md`、`docs/design/battle_runtime_model.md`、`docs/design/battle_core_architecture_constraints.md` 当前已与这三块扩展同步。
- 本节记录 Gojo 方案依赖的当前正式 contract，以及若玩法继续收紧时还需要追加的后续扩展。
- 按本文当前冻结的“单角色正式玩法”方案，`action_legality / required_target_effects / incoming_accuracy` 已可直接用于 Gojo 资源。

### 4.1 `action_legality`（新增并逐步替代 `skill_legality`）

`rule_mod.mod_kind` 从“只支持 `skill_legality`”扩展为同时支持 `action_legality`；`mod_op` 仍为 `allow / deny`，`value` 支持：

- `"all"` / `"skill"` / `"ultimate"` / `"switch"` / 具体 `skill_id`

补充：

- `allow` 与 `deny` 使用同一套 `value` 取值范围。
- `value="all"` 仅作用于技能 / 奥义 / 换人，不作用于 `wait`。
- `action_legality.value` 必须在加载期 fail-fast 校验为：`all / skill / ultimate / switch / 已注册 skill_id` 之一；空串、拼写错误或未知 `skill_id` 都不得留到运行期。
- `dynamic_value_formula` 对 `action_legality` 明确禁止；该读取点只接受静态 `value`。

迁移策略（避免一次性硬切导致旧内容失效）：

1. **阶段 A（兼容期）**：新增 `action_legality` 并保留 `skill_legality` 兼容读取。
2. **阶段 B（迁移期）**：现存主线资源无强制迁移动作；新内容一律只用 `action_legality`。
3. **阶段 C（收口期）**：移除 `skill_legality` 常量、校验与读取路径。

实现清单（阶段 A 起步）：

- `content_schema.gd`：新增 `RULE_MOD_ACTION_LEGALITY`
- `content_payload_validator.gd`：`_validate_rule_mod_payload()` 新增 `action_legality` 白名单、`mod_op` 校验、`value` 白名单校验，并明确禁止 `dynamic_value_formula`
- `rule_mod_service.gd + rule_mod_read_service.gd + rule_mod_write_service.gd`：
1. `STACKING_KEY_SCHEMA_BY_KIND` 增加 `RULE_MOD_ACTION_LEGALITY`
2. 写路径负责 `create / replace / decrement`
3. 读路径负责 `is_action_allowed(battle_state, owner_id, action_type, skill_id="")`
- `legal_action_service.gd`：技能、奥义、换人都改读 `is_action_allowed`；`wait_allowed / forced_command_type` 也必须把“换人被 rule_mod 封禁”视为**非 MP 阻断**
- `turn_selection_resolver.gd`：提交通道继续只认 legal set；不得把“是否在 legal set 内”这层语义偷偷下沉到 `command_validator.gd`
- `command_validator.gd`：继续负责结构、运行时 ID 回填、奥义入口、MP 等硬非法；不要复制一套独立的 `action_legality` 语义
- `action_executor.gd`：执行前新增 `is_action_allowed` 复检（可保留在 `action_executor.gd`，也可抽 helper），覆盖排队后中途上锁场景

真正接线时的文档同步清单（必须补齐）：

- `docs/design/command_and_legality.md`
- `docs/rules/02_turn_flow_and_action_resolution.md`
- `docs/records/decisions.md`

兼容期读取策略（必须写死）：

- `is_action_allowed` 在阶段 A 同时读取两类实例：`action_legality` 与旧 `skill_legality`
- 混合实例统一按现有 rule_mod 排序链处理（`priority -> source_order_speed_snapshot -> source_kind_order -> source_instance_id -> instance_id`），避免新旧规则并存时顺序漂移

`action_legality` stacking key schema：

- `["mod_kind", "scope", "owner_scope", "owner_id", "mod_op", "value"]`
- 说明：`value=all`、`value=switch`、`value=具体skill_id` 必须是不同 key，避免互相覆盖
- 额外冻结：按当前 `RuleModService` 设计，同 key 实例若用 `replace` 被新实例覆盖，旧实例会被直接移除；**后来的锁到期后，旧锁不会“复活”**。若未来玩法需要“多来源同 key 并存、后过期的那条消失后恢复更早来源”的语义，必须另改 stacking key 或实例模型，不能把恢复行为当成默认存在。

匹配矩阵（必须写死）：

| 当前动作 | 命中的 `value` |
|---|---|
| `skill(skill_id=X)` | `all`、`skill`、`X` |
| `ultimate(skill_id=Y)` | `all`、`ultimate`、`Y` |
| `switch` | `all`、`switch` |
| `wait` | 不命中任何 `action_legality`（恒合法） |

最终判定顺序（必须写死）：

1. 默认 `allowed = true`
2. 兼容期统一收集 `action_legality + skill_legality` 两类实例，并走同一排序链（`priority -> source_order_speed_snapshot -> source_kind_order -> source_instance_id -> instance_id`）
3. 逐条判断是否命中当前动作；命中则按 `deny => allowed=false`、`allow => allowed=true` 覆盖
4. 最终结果以“最后一条命中的 rule_mod”状态为准（last-write-wins）
5. `skill_legality` 兼容读取只参与 `skill/ultimate` 两类动作；`switch/wait` 不读取旧 `skill_legality`

### 4.2 `required_target_effects`

`effect_definition.gd` 新增：

```gdscript
@export var required_target_effects: PackedStringArray = PackedStringArray()
```

执行规则：

- `PayloadExecutor.execute_effect_event()` 在 payload 循环前做 effect 级前置检查
- `required_target_effects` 只允许出现在 `scope=target` 的 effect 上；`scope=self/field` 一律视为 schema 非法并在加载期 fail-fast
- 目标固定取 `effect_event.chain_context.target_unit_id` 对应单位；若为空、单位不存在、目标已不满足 `ACTIVE && hp>0`、或缺少任一 required effect，则整条 effect 跳过
- 不满足则跳过该 effect，不报错，也不写任何由该 effect 产生的 payload 日志
- 安全前提：只要前置检查实现正确，`remove_effect` 不会走到“目标标记不存在”分支，自然不会触发 `INVALID_EFFECT_REMOVE_AMBIGUOUS`

加载期 fail-fast（必须补齐）：

- `content_snapshot_validator.gd` 必须校验 `required_target_effects`：每个 effect id 非空、不得重复、且必须命中 `content_index.effects`
- `content_snapshot_validator.gd` 还必须校验：凡 `required_target_effects` 非空的 effect，`scope` 必须等于 `target`
- 任一引用非法时，内容加载期直接失败；禁止把错误引用留到运行期再“静默跳过”
- 真正接线时，需同步更新 `docs/rules/06_effect_schema_and_extension.md`、`docs/design/battle_content_schema.md`、`docs/design/effect_engine.md`、`docs/design/battle_runtime_model.md`、`docs/design/battle_core_architecture_constraints.md` 与 `docs/records/decisions.md`
- 测试必须包含“坏引用触发加载期失败”的坏例用例

该能力仅用于茈的条件追加爆发，不引入 `action_tags`

### 4.3 `incoming_accuracy`（无下限命中干扰）

新增 rule_mod kind：

- `incoming_accuracy`

实现点：

- `content_schema.gd`：新增 `RULE_MOD_INCOMING_ACCURACY`
- `content_payload_validator.gd`：`_validate_rule_mod_payload()` 增加 `incoming_accuracy` 白名单、`mod_op=add/set` 约束、数值 `value` 校验，并明确禁止 `dynamic_value_formula`
- `rule_mod_service.gd + rule_mod_read_service.gd + rule_mod_write_service.gd`：
1. `STACKING_KEY_SCHEMA_BY_KIND` 增加 `RULE_MOD_INCOMING_ACCURACY`
2. 写路径继续负责实例创建与扣减
3. 读路径新增 `resolve_incoming_accuracy(battle_state, target_owner_id, base_accuracy)`
- `action_cast_service.gd`：`resolve_hit` 在 field 覆盖后、`roll_hit` 前读取目标侧 `incoming_accuracy`
- `action_executor.gd`：调用 `resolve_hit` 时补传目标（建议签名改为 `resolve_hit(command, skill_definition, target, battle_state, content_index)`）

约束：

- 只在 `resolved_accuracy < 100` 时读取（必中不受影响）
- 最终命中率 clamp 到 `0~99`
- `0~99` 是刻意设计：`incoming_accuracy` 不得把命中改成“硬必中”；`100` 只由技能本体或 field 覆盖产生
- `incoming_accuracy.value` 必须是数值；非数值或 NaN 口径在内容加载期直接失败
- 多个 `incoming_accuracy` 实例的合成顺序，必须**完全复用**现有 `RuleModService` 读取顺序（`priority -> source_order_speed_snapshot -> source_kind_order -> source_instance_id -> instance_id`）；读取时 `add` 叠到当前命中值上，`set` 覆盖当前命中值，整轮读完后再统一 clamp 到 `0~99`
- 读取范围必须收紧为“敌方来袭技能 / 奥义”：
1. 仅当 `command_type in {skill, ultimate}` 且技能 `targeting=enemy_active_slot` 时才可读取
2. 仅当 `target` 为敌方 active 单位时读取；`self/field/none` 与无目标动作一律跳过
3. `switch / wait / resource_forced_default` 一律不读取 `incoming_accuracy`

`incoming_accuracy` stacking key schema：

- `["mod_kind", "scope", "owner_scope", "owner_id", "mod_op"]`
- 说明：不按 `value` 分键，沿用 `final_mod/mp_regen` 的同类 schema

真正接线时的文档同步清单（必须补齐）：

- `docs/rules/03_stats_resources_and_damage.md`
- `docs/design/effect_engine.md`
- `docs/design/battle_runtime_model.md`
- `docs/design/battle_content_schema.md`
- `docs/design/battle_core_architecture_constraints.md`
- `docs/records/decisions.md`

### 4.4 可选第 4 块扩展（仅当未来重新开放同队重复角色，且要限制为“同一施法者本人消耗标记”时）

当前“同队重复角色禁止”的正式规则**不需要**这一块；但若未来重新开放同队重复角色，并且要把语义收紧为“只有打出苍/赫的那一名五条悟本人，才能用茈吃掉自己铺的双标记”，则必须补一个来源绑定能力，最小要求至少包括：

- 标记实例需要记录可校验的施加者身份（不能只看 `def_id`）
- 茈的前置检查必须能同时检查“目标持有双标记 + 标记来源匹配当前施法者”
- 该能力需要明确是扩在 `EffectInstance.meta`、新 schema 字段，还是新增专用条件机制；在拍板前，不得把它伪装成现有 `required_target_effects` 已能解决的问题
- 若未来真要走“本人专属消耗”路线，推荐补一个明确的来源写入扩展，再把 `source_unit_id` 之类的标识落进 `EffectInstance.meta`；**当前仓库还没有这条写入链路**，不能把它当成已经可直接使用的现成能力。

### 4.5 本版明确不纳入实现

| 机制 | 状态 |
|------|------|
| `effects_pre_damage_ids` | 不做 |
| `on_before_damage` | 不做 |
| `damage_override` payload | 不做 |
| `trigger_chance`（用于无下限） | 不做 |
| `action_tags` / `last_dealt_damage` | 不做 |
| 茈反噬自伤 | 不做 |

---

## 5. 资源文件清单

以下清单是 **Gojo 当前主线资源面**。截至 2026-03-29，底层扩展、Gojo 内容资源、`SampleBattleFactory` 快照注册与 `gojo_suite` 均已接线完成。

补充施工边界：

- 下列 `.tres` 已落盘，并已进入 `SampleBattleFactory.content_snapshot_paths()`。
- 统一闸门当前已注册 `gojo_suite`；后续新增角色应沿用同一“资源清单 + SampleFactory 接线 + suite 注册”模板。

### 5.1 `content/units/`

- `gojo_satoru.tres`

### 5.2 `content/skills/`

- `gojo_ao.tres`
- `gojo_aka.tres`
- `gojo_murasaki.tres`
- `gojo_reverse_ritual.tres`
- `gojo_unlimited_void.tres`

### 5.3 `content/effects/`

- `gojo_ao_speed_up.tres`
- `gojo_ao_mark_apply.tres`
- `gojo_ao_mark.tres`
- `gojo_aka_slow_down.tres`
- `gojo_aka_mark_apply.tres`
- `gojo_aka_mark.tres`
- `gojo_murasaki_conditional_burst.tres`
- `gojo_reverse_heal.tres`
- `gojo_domain_cast_buff.tres`
- `gojo_domain_buff_remove.tres`
- `gojo_apply_domain_field.tres`
- `gojo_domain_action_lock.tres`
- `gojo_mugen_incoming_accuracy_down.tres`

### 5.4 `content/fields/`

- `gojo_unlimited_void_field.tres`

### 5.5 `content/passive_skills/`

- `gojo_mugen.tres`

### 5.6 已存在资源（无需新建）

- `content/combat_types/space.tres`
- `content/combat_types/psychic.tres`

---

## 6. 测试计划（gojo_suite，当前主线已接线）

| 编号 | 用例 | 验证点 |
|------|------|--------|
| 1 | 默认配招与候选池契约 | `skill_ids=[ao,aka,murasaki]`；`candidate_skill_ids` 含 `reverse_ritual` |
| 2 | 赛前换装 | `SideSetup.regular_skill_loadout_overrides` 可将 `reverse_ritual` 装入 |
| 3 | 苍命中后效果 | 自身 speed +1；目标挂 `gojo_ao_mark` |
| 4 | 赫命中后效果 | 目标 speed -1；目标挂 `gojo_aka_mark` |
| 5 | 茈无双标记 | 只有本体伤害；标记不被误清 |
| 6 | 茈双标记触发 | 追加伤害生效，并清除苍 / 赫标记 |
| 7 | 茈触发后无自伤 | 施法者 HP 不因反噬扣减 |
| 8 | 反转术式 | 回复 25% max_hp |
| 9 | MP 回复 | 每回合回复 14 |
| 10 | 首回合可操作 MP | 按当前 `turn_start -> selection` 时序，Gojo 第 1 回合进入选指时 `current_mp = 64` |
| 11 | 无下限重入场 | 五条悟离场再入场后，`incoming_accuracy -10` 仍生效 |
| 12 | 无量空处 action_lock 生效时机 | 只有 `gojo_apply_domain_field` 成功落地后，才会通过 `on_success_effect_ids -> field_apply_success` 施加 `gojo_domain_action_lock`；若 Gojo 先于目标行动且对手尚未开始，本回合已排队技能 / 换人会被 `cancelled_pre_start` |
| 13 | action_legality + wait | `deny all` 时 `wait` 仍可选 |
| 14 | action_legality 阻断换人也算非 MP 阻断 | 当技能 / 奥义仅因 MP 不足不可用、换人被 `deny switch/all` 封禁时，legal set 只保留 `wait`，不得回落到 `resource_forced_default` |
| 15 | 领域内必中 | `creator_accuracy_override=100` 只在无量空处领域成功立住后生效 |
| 16 | 无下限非必中减命中 | 仅当 `resolved_accuracy < 100` 时生效；敌方 95 命中技能打五条悟按 85 判定 |
| 17 | 无下限不影响必中 | 敌方 100 命中技能（或领域覆盖必中）不降命中 |
| 18 | 标记持有者离场清除 | 目标换下后 `gojo_ao_mark/gojo_aka_mark` 被移除（`persists_on_switch=false`） |
| 19 | 五条悟离场不清目标标记 | 五条悟自己换下时，敌方身上的苍 / 赫标记仍保留 |
| 20 | 同队重复角色禁止 | 同一 side 若出现两个 `gojo_satoru`，BattleSetup 校验应直接失败 |
| 21 | 茈追加击杀边界 | 追加段把目标打到 `hp<=0` 时，后续 `remove_effect` 静默跳过且不产生 `invalid_battle` |
| 22 | 茈本体先击杀边界 | 若茈本体伤害已击杀目标，则 `gojo_murasaki_conditional_burst` 整条跳过，不再打追加段 |
| 23 | 茈对位槽位重定向边界 | 目标在 Gojo 行动前换下时，`enemy_active_slot` 茈命中新 active；若新 active 不持双标记，则不触发追加段 |
| 24 | required_target_effects 坏引用 | `required_target_effects` 指向不存在 effect 时内容加载期直接失败 |
| 25 | incoming_accuracy 作用域收紧 | `self/field/none` 目标技能、`switch/wait/resource_forced_default` 不读取 `incoming_accuracy` |
| 26 | action_legality 匹配矩阵 | `deny all + allow switch`、`deny skill + allow gojo_ao`、`deny ultimate + allow ultimate_id` 结果与矩阵一致 |
| 27 | 兼容期双口径共读 | 阶段 A 下 `action_legality + skill_legality` 同排序链读取，不得因 mod_kind 不同而顺序漂移 |
| 28 | 双 `+5` 先后手竞争 | 对手也使用 `+5` 奥义时，若对手先动，则 Gojo 本回合不得被文档误写成“仍然锁到对方” |
| 29 | 标记 / 领域时间线 | `duration=3 + decrement_on=turn_end` 必须按“施放当回合起连续 3 次 `turn_end` 扣减”验证 |
| 30 | 领域对拼失败边界 | 五条悟在领域对拼中输掉时，不落领域、不加 `sp_attack +1`、也不锁人 |
| 31 | required_target_effects 跳过无日志 | 前置条件不满足时，`gojo_murasaki_conditional_burst` 不执行 payload，也不得写出该 effect 产生的 payload 日志 |
| 32 | incoming_accuracy 多实例顺序 | `add/set` 混用时，必须按统一 rule_mod 读取顺序求值，再统一 clamp 到 `0~99` |
| 33 | action_legality 同 key 覆盖语义 | 同 key `replace` 覆盖后，后实例到期不得把旧实例“复活”；若要支持恢复，必须另扩实例模型 |
| 34 | 标记 refresh 续时语义 | `gojo_ao_mark / gojo_aka_mark` 再次命中施加时，应刷新持续时间，不得额外并行出第二层同名标记 |
| 35 | 奥义点 3/3/1 contract | 常规技能开始施放即 +1，miss 也加；上限 3；奥义开始施放清零；换下保留 |
| 36 | 领域 buff 生命周期 | `gojo_domain_cast_buff` 只在 `field_apply` 成立时生效；自然到期与提前打断都必须通过 `gojo_domain_buff_remove` 回收 |

---

## 7. 平衡性备注

| 维度 | 五条悟（本版） | 说明 |
|------|----------------|------|
| 爆发 | 中高 | 茈双标记连段在当前公式下可打出明显高于单发技能的爆发 |
| 控场 | 很高 | 领域命中后能锁未开始行动的对手，并让 creator 技能必中；但不是所有先手竞争场景都能保证首回合锁到人 |
| 生存 | 中高 | 反转术式 + 稳定命中干扰，让它比“纯高速脆皮法师”更难处理 |
| 资源节奏 | 中高 | 按当前主线时序首个可操作回合实战可用 MP 为 `64`，配合 `regen=14` 能较早形成压制，但还没到“无脑连开奥义”的程度 |

补充说明：

- 按当前 main 的 50 级简化公式与现有时序，五条悟更接近“偏强压制型角色”，不是单纯的“中性强度高速术师”。
- 但“宿傩基线”不是严格中性参照：当前样例属性表里 `psychic -> demon = 0.5`、`demon -> psychic = 2.0`，因此 Gojo 对宿傩的实战表现不能直接代表它在中性对位下的最终强度。

本版目标不是最终平衡值，而是先落地“可施工、可验收、可迭代”的玩法闭环；最终强度仍需等 Gojo 落地后再用实战数据回调。

## 8. 当前冻结

| 项目 | 说明 |
|---|---|
| 标记来源校验 | 当前不做；双标记默认是团队共享资源 |
| 奥义点 | `required=3 / cap=3 / regular_skill_cast +1` |
| 锁人条件 | 只有领域成功立住才锁人 |
| 领域增幅归属 | `sp_attack +1` 跟 `gojo_unlimited_void_field` 生命周期走 |
| 领域后摇 | 已删除（Gojo / Sukuna 同口径） |
| 平衡结论 | 保留苍 / 赫 / 茈现有机制、保留无下限现有机制；奥义改为 3 点可开 |
| 领域强度 | 暂不下调，后续按实战数据再调 |
