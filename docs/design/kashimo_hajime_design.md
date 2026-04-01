# 鹿紫云一（Kashimo Hajime）设计方案 v1.1

## 0. 冻结结论（2026-04-01）

| 项目 | 结论 |
|------|------|
| 角色定位 | 雷属性近战爆发手；靠负电荷压血、正电荷回蓝、回授电击收割，再用一次性的幻兽琥珀赌爆发上限 |
| 被动主轴 | 电荷分离——雷属性攻击打到鹿紫云时伤害降低；若被水属性技能命中，自身流失 15 MP，并立刻对攻击者返还 15 点毒属性固定伤害 |
| 核心技能主轴 | 雷拳叠负电荷持续掉血 -> 蓄电叠正电荷持续回蓝 -> 回授电击消耗全部电荷爆发 -> 弥虚葛笼只中和领域必中 |
| 奥义主轴 | 幻兽琥珀一整场只能开一次；开启后攻击 +2、特攻 +2、速度 +1，并且每回合扣 20 HP，直到死亡 |
| 奥义点配置 | `required=3 / cap=3 / regular_skill_cast +1` |
| 领域 | 无领域。弥虚葛笼是反领域工具，不是自己的领域 |
| 当前格式约束 | 讨论稿是“4 个常规技能 + 1 个奥义”；但当前战斗格式固定只有 3 个常规技能槽，所以正式内容先按“4 选 3”落地 |
| 明确不做 | 反转术式；弥虚葛笼作为领域展开；当前版本不扩成 4 常规技能同时上阵 |

---

## 0.1 角色稿范围

- 本稿按 `docs/design/formal_character_design_template.md` 收口，只保留鹿紫云一自己的玩法、资源语义、验收矩阵与平衡备注。
- 共享战斗规则统一引用：
  - 生命周期与换人保留：`docs/rules/04_status_switch_and_lifecycle.md`
  - 伤害、属性克制、奥义点：`docs/rules/03_stats_resources_and_damage.md`
  - effect / rule_mod schema：`docs/rules/06_effect_schema_and_extension.md`
  - 内容资源字段与加载期校验：`docs/design/battle_content_schema.md`

---

## 1. 角色基础属性

### 1.1 角色定位

- 面向玩家：
  - 鹿紫云一是一个“越打越急”的近战雷系角色。
  - 他先用雷拳给敌人挂负电荷，让对手持续掉血；再给自己蓄正电荷，保证 MP 不断；看准时机后用回授电击把场上的电荷一次性引爆。
  - 如果对面是领域角色，可以把弥虚葛笼装进这场的技能组，用来把领域附加的必中打回原始命中。
  - 奥义「幻兽琥珀」是彻底翻桌的按钮。按下去以后鹿紫云会进入不可逆强化状态，但也会开始走向自灭。
- 面向实现：
  - `thunder + fighting` 属性的物理偏向角色。
  - 玩法核心是“目标负电荷 + 自身正电荷”的双侧标记体系。
  - 当前格式固定 3 个常规技能槽，所以“雷拳 / 蓄电 / 回授电击 / 弥虚葛笼”这 4 个常规技能，先按候选池 `4 选 3` 落地。

### 1.2 UnitDefinition

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `kashimo_hajime` | |
| display_name | `鹿紫云一` | |
| combat_type_ids | `["thunder", "fighting"]` | 雷 + 格斗 |
| base_hp | **118** | 三人最低，短命爆发手 |
| base_attack | **82** | 三人最高，物理主力 |
| base_defense | **58** | 中等偏低 |
| base_sp_attack | **72** | 次要输出轴，主要给回授电击与琥珀后的雷系爆发用 |
| base_sp_defense | **54** | 三人最低，脆皮 |
| base_speed | **90** | 三人最高 |
| BST（6 维面板） | **474** | 只统计 HP / 双攻 / 双防 / 速度，不含 `max_mp` |

### 1.3 MP / 奥义点系统

| 字段 | 值 | 说明 |
|------|-----|------|
| max_mp | **100** | |
| init_mp | **40** | 偏低，依赖正电荷补经济 |
| regen_per_turn | **10** | 三人最低 |
| ultimate_points_required | **3** | 统一 |
| ultimate_points_cap | **3** | 统一 |
| ultimate_point_gain_on_regular_skill_cast | **1** | 统一 |

补充语义：

- 按当前主线时序，第 1 回合选指前会先结算一次 `turn_start` MP 回复，所以鹿紫云首个可操作回合的实战可用 MP 是 `50`，不是 `40`。
- 鹿紫云的资源节奏不是“基础回蓝强”，而是“蓄电以后才开始转起来”。没叠正电荷时，他的 MP 压力是三人里最大的。

### 1.4 技能组与赛前装配

**内容层（UnitDefinition）**

- 默认配招（`skill_ids`，3 个）：`kashimo_raiken`、`kashimo_charge`、`kashimo_feedback_strike`
- 奥义（`ultimate_skill_id`）：`kashimo_phantom_beast_amber`
- 候选技能池（`candidate_skill_ids`，4 个）：`kashimo_raiken`、`kashimo_charge`、`kashimo_feedback_strike`、`kashimo_kyokyo_katsura`

**赛前层（SideSetup）**

- 本场常规三技能装配通过 `SideSetup.regular_skill_loadout_overrides` 决定。
- 正式口径明确为：
  - 讨论里的“4 个常规技”概念先按“4 选 3”表达。
  - 默认三技能保留完整电荷主循环。
  - `弥虚葛笼` 作为对领域对局的换装位，不占奥义槽。
- 当前不支持赛前覆盖奥义、被动或持有物。

### 1.5 被动

| 类型 | 值 |
|------|-----|
| passive_skill_id | `kashimo_charge_separation` |
| passive_item_id | `` |

---

## 2. 技能详细设计

### 2.1 雷拳

| 字段 | 值 |
|------|-----|
| id | `kashimo_raiken` |
| display_name | `雷拳` |
| damage_kind | `physical` |
| power | **45** |
| accuracy | **100** |
| mp_cost | **12** |
| priority | **+1** |
| combat_type_id | `thunder` |
| targeting | `enemy_active_slot` |
| effects_on_hit_ids | `["kashimo_apply_negative_charge"]` |

- 玩家说明：
  - 鹿紫云一用带电的拳头先手出击。
  - 命中后给对手挂 1 层「负电荷」。
  - 负电荷每层都会在回合结束时额外电一下对手。
- 机制说明：
  - 先制 +1 的雷属性物理技。
  - 命中后通过 `kashimo_apply_negative_charge` 给目标施加 `kashimo_negative_charge_mark`。
  - 负电荷每层在 `turn_end` 造成 8 点雷属性固定伤害。
- 冻结值：
  - 最多 3 层。
  - 每层持续 4 次 `turn_end`。
  - 目标换人时清空。

**负电荷相关资源**

| 资源 | 语义 |
|------|------|
| `kashimo_apply_negative_charge` | `on_hit` 时对目标施加 `kashimo_negative_charge_mark` |
| `kashimo_negative_charge_mark` | `stacking=stack`；`max_stacks=3`；持续 4 次 `turn_end`；每层每次 `turn_end` 造成 8 点雷属性固定伤害 |

**叠层时序**

```text
回合1：雷拳命中 -> 第1层负电荷
回合1结束：造成 8 点伤害，在场 1 层

回合2：雷拳命中 -> 第2层负电荷
回合2结束：两层各结算一次，在场 2 层，共 16 点

回合3：雷拳命中 -> 第3层负电荷
回合3结束：三层各结算一次，在场 3 层，共 24 点

回合4：再打雷拳也不会长到第4层，只会维持 3 层上限
回合4结束：最早那层到期，场上掉回 2 层
```

结论：`max_stacks=3 + duration=4` 的节奏是合理的，3 回合能叠满，之后在 2 到 3 层之间滚动。

### 2.2 蓄电

| 字段 | 值 |
|------|-----|
| id | `kashimo_charge` |
| display_name | `蓄电` |
| damage_kind | `none` |
| power | **0** |
| accuracy | **100** |
| mp_cost | **8** |
| priority | **0** |
| combat_type_id | `` |
| targeting | `self` |
| effects_on_cast_ids | `["kashimo_apply_positive_charge"]` |

- 玩家说明：
  - 鹿紫云一把电荷往自己身上收。
  - 使用后给自己叠 1 层「正电荷」。
  - 正电荷每层都会在回合开始时回 5 点 MP。
- 机制说明：
  - 自身技能，不造成伤害。
  - `on_cast` 通过 `kashimo_apply_positive_charge` 给自己施加 `kashimo_positive_charge_mark`。
- 冻结值：
  - 最多 3 层。
  - 每层持续 4 次 `turn_end`。
  - 自己换人时清空。

**正电荷相关资源**

| 资源 | 语义 |
|------|------|
| `kashimo_apply_positive_charge` | `on_cast` 时对自身施加 `kashimo_positive_charge_mark` |
| `kashimo_positive_charge_mark` | `stacking=stack`；`max_stacks=3`；持续 4 次 `turn_end`；每层每次 `turn_start` 恢复 5 MP |

### 2.3 回授电击

| 字段 | 值 |
|------|-----|
| id | `kashimo_feedback_strike` |
| display_name | `回授电击` |
| damage_kind | `special` |
| power | **30**（基础） |
| accuracy | **100** |
| mp_cost | **15** |
| priority | **0** |
| combat_type_id | `thunder` |
| targeting | `enemy_active_slot` |
| power_bonus_source | `charge_mark_count`（需引擎扩展） |
| effects_on_cast_ids | `["kashimo_consume_positive_charges"]` |
| effects_on_hit_ids | `["kashimo_consume_negative_charges"]` |

- 玩家说明：
  - 鹿紫云一把自己和敌人之间积起来的所有电荷一起拉爆。
  - 自己的正电荷越多、敌人的负电荷越多，这一下越疼。
- 机制说明：
  - 威力 = `30 + 12 × 消耗的总层数`
  - 自身正电荷在 `on_cast` 时消耗。
  - 目标负电荷在 `on_hit` 时消耗。
  - miss 时只会亏掉自己的正电荷，不会帮对手清负电荷。

| 消耗标记数 | 威力 |
|-----------|------|
| 0 层 | 30 |
| 2 层 | 54 |
| 4 层 | 78 |
| 6 层（满） | 102 |

**消耗标记相关资源**

| 资源 | 语义 |
|------|------|
| `kashimo_consume_positive_charges` | `on_cast` 时移除自身全部 `kashimo_positive_charge_mark` |
| `kashimo_consume_negative_charges` | `on_hit` 时移除目标全部 `kashimo_negative_charge_mark` |

### 2.4 弥虚葛笼

| 字段 | 值 |
|------|-----|
| id | `kashimo_kyokyo_katsura` |
| display_name | `弥虚葛笼` |
| damage_kind | `none` |
| power | **0** |
| accuracy | **100** |
| mp_cost | **20** |
| priority | **+2** |
| combat_type_id | `` |
| targeting | `self` |
| effects_on_cast_ids | `["kashimo_kyokyo_nullify"]` |

- 玩家说明：
  - 鹿紫云一展开简易领域中和结界。
  - 它不拆对面的领域，只把领域额外送的必中抹掉，让对手回到技能原本命中率。
- 机制说明：
  - 自身状态，持续 3 回合。
  - 只影响 `creator_accuracy_override=100` 带来的领域必中。
  - 不影响技能本来就写死的 `accuracy=100`。
  - 不影响领域的其他效果，比如加攻、锁技、到期爆炸。

**相关资源**

| 资源 | 语义 |
|------|------|
| `kashimo_kyokyo_nullify` | `scope=self`；持续 3 次 `turn_end`；`stacking=refresh`；语义为“忽略领域附加必中，只读技能原始命中率” |

### 2.5 幻兽琥珀（奥义）

| 字段 | 值 |
|------|-----|
| id | `kashimo_phantom_beast_amber` |
| display_name | `幻兽琥珀` |
| damage_kind | `special` |
| power | **60** |
| accuracy | **100** |
| mp_cost | **35** |
| priority | **+5** |
| combat_type_id | `thunder` |
| targeting | `enemy_active_slot` |
| is_domain_skill | `false` |
| effects_on_cast_ids | `["kashimo_amber_self_transform"]` |
| effects_on_hit_ids | `[]` |

- 玩家说明：
  - 一生只能开一次的肉体改造。
  - 释放瞬间对目标打一发雷属性特殊伤害。
  - 从这一刻起，鹿紫云进入不可逆的强化形态：攻击 +2、特攻 +2、速度 +1。
  - 代价是每回合结束扣 20 HP，直到死亡。
- 正式语义：
  - 这是“形态切换”，不是短暂状态。
  - 一旦开启，强化、自伤、奥义封锁都应该跟着换人保留。
  - 不允许把它偷偷降级成“换人后只留自伤、不留强化”的半残版本；如果实现阶段不得不降级，必须单独写进 adjustment 文档，而不是改动主稿语义。
- 机制说明：
  - 奥义合法性仍同时要求 `current_mp >= 35` 与 `ultimate_points >= 3`。
  - 开始施放时立刻清空奥义点。
  - `on_cast` 阶段就进入琥珀状态，所以就算这次攻击 miss，强化与自伤也照样生效。

**琥珀相关资源**

| 资源 | 语义 |
|------|------|
| `kashimo_amber_self_transform` | `on_cast` 时施加琥珀形态相关效果 |
| `kashimo_amber_attack_up` | 攻击 +2 级语义；应跨换人保留 |
| `kashimo_amber_sp_attack_up` | 特攻 +2 级语义；应跨换人保留 |
| `kashimo_amber_speed_up` | 速度 +1 级语义；应跨换人保留 |
| `kashimo_amber_bleed` | `turn_end` 每回合扣 20 HP；`persists_on_switch=true` |
| `kashimo_amber_ult_lock` | 整场禁止再次使用奥义；`persists_on_switch=true` |

**自毁时序**

| 回合 | 回合结束后剩余 HP | 状态 |
|------|-------------------|------|
| 琥珀释放 | 118 | 攻击 +2 / 特攻 +2 / 速度 +1 |
| 第1回合结束 | 98 | 爆发开始 |
| 第2回合结束 | 78 | 仍在强势期 |
| 第3回合结束 | 58 | 进入危险区 |
| 第4回合结束 | 38 | 濒死 |
| 第5回合结束 | 18 | 最后一波 |
| 第6回合结束 | 死亡 | 结束 |

### 2.6 被动技能：电荷分离

#### 玩家语义

- 鹿紫云一的咒力性质和电一样。
- 雷属性技能打到他时，伤害会明显降低。
- 但如果被水属性技能命中，他会立刻漏出 15 点 MP，同时把同等强度的毒性伤害返给攻击者。

#### 正式实现口径

- 这一版不再把“雷电抗性”写成 `incoming_accuracy -15`。
- 正式语义改为两段：
  1. **抗雷**：走属性克制表，而不是走命中干扰。应在 `combat_type_chart` 中补上 `thunder -> thunder = 0.5`，让雷属性打到雷属性鹿紫云时天然减伤。
  2. **导电弱点**：由被动负责。当鹿紫云被 `water` 技能命中时：
     - 自身立刻失去 15 MP
     - 攻击者立刻受到 15 点 `poison` 固定伤害
- 这样改完以后，角色味道就回到“抗雷，但怕在水里漏咒力”的原设上，而不是莫名其妙变成闪避型角色。

#### 资源语义

| 资源 | 语义 |
|------|------|
| `kashimo_charge_separation` | 被动入口；负责水属性命中后的导电分支 |
| `kashimo_water_leak_self` | 鹿紫云自身 `resource_mod(mp, -15)` |
| `kashimo_water_leak_counter` | 对攻击者造成 15 点 `poison` 固定伤害 |

---

## 3. 角色特有验收矩阵

正式交付面说明：

- `kashimo_suite.gd` 承担玩法与行为回归。
- `kashimo_snapshot_suite.gd` 锁死鹿紫云的单位、技能、effect 与被动资源。

| 编号 | 场景 | 断言 |
|------|------|------|
| 1 | 默认配招与候选池契约 | 默认三技能固定为 `雷拳 / 蓄电 / 回授电击`；`弥虚葛笼` 只在 `candidate_skill_ids` 中 |
| 2 | 四技能概念的格式落地 | 当前格式固定 3 槽，因此正式行为是“4 选 3”，而不是隐式扩成 4 常规技能上阵 |
| 3 | 负电荷叠层与持续伤害 | 雷拳命中后目标获得负电荷；3 次命中叠满 3 层；每层 `turn_end` 造成 8 点雷属性固定伤害 |
| 4 | 正电荷叠层与回蓝 | 蓄电使用后自身获得正电荷；3 次使用叠满 3 层；每层 `turn_start` 恢复 5 MP |
| 5 | 回授电击消耗标记 | `on_cast` 清掉自身全部正电荷；`on_hit` 清掉目标全部负电荷 |
| 6 | 回授电击动态威力 | 消耗 N 层标记时威力 = `30 + 12N` |
| 7 | 回授电击 miss 边界 | miss 时只消耗自身正电荷，不消耗目标负电荷 |
| 8 | 弥虚葛笼反必中 | 对手领域在场时，弥虚葛笼使其命中率恢复为技能原始值 |
| 9 | 弥虚葛笼不摧毁领域 | 领域其他效果仍然存在 |
| 10 | 幻兽琥珀一次性 | 使用后整场不能再开第二次 |
| 11 | 幻兽琥珀强化 | 开启后获得攻击 +2、特攻 +2、速度 +1 |
| 12 | 幻兽琥珀自伤 | 开启后每回合 `turn_end` 扣 20 HP，直到死亡 |
| 13 | 幻兽琥珀换人语义 | 强化、自伤、奥义封锁都应在换人后继续保留 |
| 14 | 雷属性抗性 | `thunder -> thunder = 0.5` 进入格式表后，雷属性技能打鹿紫云时倍率为 0.5 |
| 15 | 水属性导电弱点 | 鹿紫云被 `water` 技能命中后，自身立刻 -15 MP |
| 16 | 水属性导电反击 | 同一次命中后，攻击者立刻受到 15 点 `poison` 固定伤害 |
| 17 | 毒属性注册 | `poison` combat type 已注册，且没有显式克制表项时默认按 1.0 中立处理 |
| 18 | 奥义点 3/3/1 contract | 常规技能开始施放即 +1；上限 3；奥义开始施放清零；换下保留 |

---

## 4. 平衡备注

| 维度 | 鹿紫云一（本版） | 说明 |
|------|------------------|------|
| 即时爆发 | 高 | 琥珀后双攻拉满，再接回授电击，单回合爆发极高 |
| 持续压制 | 中高 | 负电荷会逼对手持续吃固定伤害，不处理就会一直掉血 |
| 控场 | 低 | 没有自己的领域，也没有硬控；弥虚葛笼是防御工具 |
| 生存 | 中低 | 不再靠闪避保命；非雷属性对局更脆，但对雷属性对局更硬 |
| 资源节奏 | 中 | 基础回蓝最低，但正电荷叠起来以后会突然变富 |
| 对局极化 | 高 | 打雷系对手更舒服，遇到水系打点则会被额外抽 MP |

### 4.1 当前冻结值

| 项目 | 值 |
|------|-----|
| 雷拳威力 | 45 |
| 蓄电消耗 | 8 MP |
| 负电荷每层伤害 | 8 |
| 正电荷每层回蓝 | 5 |
| 正负电荷上限 | 各 3 层 |
| 正负电荷持续 | 各 4 回合 |
| 回授电击基础威力 | 30 |
| 回授电击每层加成 | +12 |
| 弥虚葛笼持续 | 3 回合 |
| 幻兽琥珀自伤 | 20 / 回合 |
| 幻兽琥珀增幅 | 攻击 +2、特攻 +2、速度 +1 |
| 水中外泄值 | 自身 -15 MP，攻击者吃 15 点毒属性固定伤害 |

### 4.2 已知平衡风险

- 对雷属性对局的克制度会明显上升，因为这版把“抗雷”从命中干扰改成了真实减伤。
- 水属性导电反制如果做成“只要命中就触发”，会让所有水技能天然自带额外博弈压力，需要实战确认是否过重。
- 幻兽琥珀如果按正式语义做成“强化可跨换人保留”，它的强度会比当前未提交草稿更高，必须用实战回放再看。
- 回授电击满层 102 威力在琥珀后会被进一步放大，仍然是本角色最危险的超量点。

### 4.3 后续调优入口

1. `水中外泄值`：15 -> 10 或 20
2. `负电荷每层伤害`：8 -> 6 或 10
3. `回授电击每层加成`：12 -> 10 或 15
4. `正电荷每层回蓝`：5 -> 4 或 6
5. `幻兽琥珀自伤`：20 -> 15 或 25
6. `弥虚葛笼消耗`：20 -> 15 或 25

### 4.4 当前冻结

| 项目 | 说明 |
|------|------|
| 常规技能槽 | 仍然固定 3 槽 |
| 四技能概念 | 先按 `candidate_skill_ids` 的 4 选 3 表达 |
| 标记体系 | 负电荷挂对手、正电荷挂自己，各 3 层，各 4 回合 |
| 幻兽琥珀 | 语义上是不可逆强化形态，不是一次性临时 buff |
| 被动语义 | 抗雷用减伤，不再用降命中；水属性命中时漏 MP 并毒返 |
| 交付原则 | 主稿先和讨论方向对齐；如果实现层需要临时降级，必须写进 adjustment 文档，不得直接偷改主稿 |

---

## 附录 A. 引擎 / 内容扩展需求

| 扩展项 | 优先级 | 难度 | 说明 |
|--------|--------|------|------|
| `charge_mark_count` power_bonus_source | P0 | 中 | 回授电击按“自身正电荷 + 目标负电荷”的总层数加威力 |
| `remove_all_by_def_id` payload 语义 | P0 | 小 | 当前 `RemoveEffectPayload` 只能移除单个实例；回授电击需要一口气清全部叠层 |
| `nullify_field_accuracy` 读取点 | P0 | 小 | 弥虚葛笼要把领域附加必中还原成技能原始命中率 |
| 来袭技能属性触发条件 | P1 | 中 | 被动需要知道“这次命中的技能是不是 `water`” |
| `poison` combat type | P1 | 极小 | 新增 `content/combat_types/poison.tres`，首版可先不补额外克制表项 |
| `thunder -> thunder = 0.5` chart 条目 | P1 | 极小 | 抗雷不再写成闪避，被类型表接管 |
| 琥珀跨换人强化载体 | P1 | 中 | 需要一个能在换人后继续保留攻击 / 特攻 / 速度强化的正式表达，不能继续只靠离场就清零的 `stat_stage` |

**补充说明**

- 如果后续真的决定把战斗格式改成“4 个常规技能同时上阵”，那是战斗格式层扩展，不属于鹿紫云一角色稿本身。
- 这份主稿不再接受“为了省扩展，直接把角色味道改掉”的静默修改。需要降级时，单独写 adjustment 文档。
