# 新手玩家手册（v2）

欢迎来到这个类宝可梦的回合制对战项目。本手册按"先讲玩法、再讲角色"的顺序展开，所有数值都直接照 `.tres` 资源给出，不再让你跳到别的文档去翻。读完这一份，你就可以坐下来打第一场。

---

# 第一部分：游戏基本玩法介绍

## 1. 战斗规则速览

### 1.1 战斗形式

- **对战规模**：1v1 单打（同一时刻每方场上只有 1 个单位）。
- **队伍规模**：每方 3 个单位组成一支队伍。
- **等级**：固定 `Lv = 50`（没有练级系统，所有单位入场就是满级）。
- **首发**：战斗开始前每方从自家 3 个单位中选 1 个先上场，剩下 2 个进后备位（bench）。
- **可见性**：当前是 `prototype_full_open` 模式，开局时双方完整队伍战斗信息都互相公开。包括：每个单位的身份、属性、面板、技能列表、奥义、被动技能、被动持有物。
- **回合上限**：`max_turn = 40`。第 40 回合走完之后还没分胜负，进超时比较。
- **选指限时**：每方每回合 `30 秒`（`selection_deadline_ms = 30000`）。
- **触发链深限**：单条结算链最多 `32` 层（`max_chain_depth = 32`），超出立刻 `invalid_battle`。

### 1.2 胜负条件

- **常规胜利**：对方没有可上场单位（3 名都被打倒）。
- **常规失败**：你自己没有可上场单位。
- **同窗双空**：同一结算窗口里双方都倒空 → 平局。
- **投降**：随时可以；点了立即判该方负。
- **回合上限**：第 40 回合结束时按下面的顺序比较：
  1. 剩余可上场单位数；
  2. 全队当前 HP / 全队最大 HP 占比（用整数交叉相乘比较，不直接比浮点）；
  3. 全队当前 HP 总和；
  4. 还相同就判平。

### 1.3 一回合的流程

每一回合按下面这条流水线推进：

1. **回合开始**：当前在场单位先回 MP（具体规则见 §2），再处理 `turn_start` 事件（如某些被动、某些持续效果）。
2. **选择指令**：双方同时在 30 秒内交一份合法指令；超时按规则自动替代。
3. **队列锁定**：双方都交完合法指令后，按统一排序链生成本回合行动队列。锁定后本回合不再重排。
4. **执行行动**：按队列顺序逐个结算（命中、伤害、效果）。
5. **行动后击倒窗口**：每个行动结算完后立即检查击倒；有人 HP 归 0 就当场清理 + 强制补位。
6. **回合末结算**：处理 `turn_end` 事件、扣减 field 剩余回合。
7. **回合末击倒窗口**：再扫一次有没有刚倒的。
8. **胜负判定 / 进入下一回合**。

### 1.4 三类指令

每方每回合必须从下面这套指令里选 1 个交进来：

| 指令名 | 含义 | 进入行动队列吗 |
|---|---|---|
| `cast`（技能 / 奥义） | 放一个技能（常规技能 / 奥义都属于这里）。 | 是 |
| `switch`（手动换人） | 把当前出战单位换成你 bench 上的某个单位。 | 是（priority 固定 +4） |
| `wait`（等待） | 这回合不行动，但占用一个回合。 | 是（priority 固定 0） |

另外还有两类特殊行为：

- **`resource_forced_default`（资源型默认动作）**：当你这回合所有技能都不合法、奥义不合法、也没合法换人时，引擎会自动改成它。一招固定属性的物理攻击：威力 `50`、命中 `100`、不消耗 MP，但会对自己造 `floor(max_hp * 0.25)` 的反伤（默认 `default_recoil_ratio = 0.25`，下限 1）。
- **超时替代**：30 秒没交合法指令时，如果不满足"强制资源型默认动作"的条件，引擎会自动改成 `wait`，并打上 `command_source = timeout_auto` 的标记。
- **投降**：即时结束，不进队列。

---

## 2. 单位的数值与资源

### 2.1 六维面板

每个单位都有 6 个基础属性（基础值，未受能力阶段修饰前）：

| 字段 | 含义 |
|---|---|
| `base_hp` | 生命值上限。 |
| `base_attack` | 物理攻击力（用来打物理技）。 |
| `base_defense` | 物理防御力（受到物理技时用）。 |
| `base_sp_attack` | 特殊攻击力（用来打特殊技）。 |
| `base_sp_defense` | 特殊防御力（受到特殊技时用）。 |
| `base_speed` | 速度（决定行动顺序）。 |

战斗内固定按 `Lv = 50` 计算，没有等级浮动。

### 2.2 BST（六维和）

`BST` 就是 `HP + 攻 + 防 + 特攻 + 特防 + 速` 的加和，用来快速比较六维总量。当前正式四角色：

- 五条悟：`124 + 56 + 60 + 88 + 68 + 86 = 482`
- 宿傩：`126 + 78 + 62 + 84 + 60 + 76 = 486`
- 鹿紫云一：`118 + 82 + 58 + 72 + 54 + 90 = 474`
- 带土：`128 + 58 + 78 + 88 + 80 + 64 = 496`

注意：宿傩被动里那个 `matchup_bst_gap_band` 用的是另一套口径——它把 `max_mp` 也算进去（`HP + 攻 + 防 + 特攻 + 特防 + 速 + max_mp` 的差值），叫"对位 7 维差"。两套口径不一样，本手册写"BST"特指六维，写"对位差"才会动 `max_mp`。

### 2.3 MP（蓝量）

| 字段 | 含义 |
|---|---|
| `max_mp` | MP 上限（当前所有正式角色都是 `100`）。 |
| `init_mp` | 战斗开始时初始 MP。 |
| `regen_per_turn` | 每回合 `turn_start` 自动回复的 MP。 |

规则要点：

- **回复时点**：固定在每回合的 `turn_start`。当前在场单位才能在回合开始时回 MP；bench 单位不回。
- **上下限**：回完不超过 `max_mp`，扣完不低于 0。
- **首回合预回蓝**：引擎会在 `create_session()` 时按 `turn_start` 规则预回一次蓝。所以你看到选指界面时显示的"当前 MP"已经是 `init_mp + regen_per_turn`。这一次预回蓝**不重复写进首个 `run_turn` 的日志**，是 contract 不是 bug。
- **MP 不足**：对应技能直接非法，选择阶段就会被引擎拦下来。
- **扣蓝时点**：行动到达执行起点时**先扣 MP，再判命中**。后续 miss 也不退 MP。
- **奥义同理**：必须同时满足 `current_mp >= mp_cost` 才能开。

宿傩还有"对位追加回蓝"的特例（详见 §宿傩部分）：他每回合的真实回蓝 = `12 + 对位差档位加值`。其余角色都按面板上的 `regen_per_turn` 直接结算。

### 2.4 奥义点（ultimate_points）

奥义点是开奥义的额外硬门槛——除了 MP，还得攒够"奥义点"才能放奥义。

| 字段 | 含义 |
|---|---|
| `ultimate_points` | 当前积累的奥义点。 |
| `ultimate_points_required` | 释放奥义所需点数。当前正式四角色都是 `3`。 |
| `ultimate_points_cap` | 奥义点上限。当前正式四角色都是 `3`。 |
| `ultimate_point_gain_on_regular_skill_cast` | 每次开始施放常规技能时获得的点数。当前都是 `+1`。 |

关键规则：

1. **谁加点**：常规技能（不是奥义、不是换人、不是 wait、不是默认动作、不是投降）开始施放时 `+1`。命中和 miss 都加。
2. **谁清零**：奥义开始施放时立即清空，无论后续命中、miss 还是开始后失败都不返还。
3. **谁不加**：`wait / switch / ultimate / resource_forced_default / surrender` 都不加奥义点。
4. **跨换下保留**：奥义点属于单位运行态，换下场后**保留**，再上场还在。
5. **公开**：奥义点会进公开快照与日志，对手能看到你攒了多少。

所以正式四角色的实战节奏都是："连出 3 个常规技能 → 攒到 3 点 → 才有资格开大"。

### 2.5 状态阶段（stat stage）

打牌时各家会喊"-2 / -1 / 0 / +1 / +2"那种东西，就是这里说的 stat stage。

- **作用维度**：`攻击 / 防御 / 特攻 / 特防 / 速度`，5 个维度都有自己的阶段。HP 没有 stat stage 概念。
- **取值范围**：`-2 ~ +2`。超出直接截断到边界值。
- **阶段换算公式**：
  - `n >= 0` 时：实际倍率 = `(2 + n) / 2`
  - `n < 0` 时：实际倍率 = `2 / (2 - n)`

具体折算如下表：

| 阶段 n | 倍率 |
|---|---|
| `+2` | `4 / 2 = 2.0` |
| `+1` | `3 / 2 = 1.5` |
| `0` | `2 / 2 = 1.0` |
| `-1` | `2 / 3 ≈ 0.667` |
| `-2` | `2 / 4 = 0.5` |

举例：基础攻击 `78` 在 `+1` 阶段时，有效攻击 = `78 × 1.5 = 117`；`-2` 阶段时 = `78 × 0.5 = 39`。

- **离场清理**：阶段在常规离场（手动换人 / 强制换下 / 倒下）时统一清空——除非显式声明 `retention_mode = persist_on_switch`（这是鹿紫云琥珀状态用到的"持久阶段"）。
- **不做**：当前没有"命中阶段 / 闪避阶段"。stat stage 不会改命中。

---

## 3. 战斗属性系统（combat_type）

### 3.1 18 种属性全列

`/content/combat_types/` 下注册了 **18 种** `combat_type`：

| ID | 中文名 |
|---|---|
| `fire` | 火 |
| `water` | 水 |
| `wood` | 木 |
| `earth` | 土 |
| `wind` | 风 |
| `thunder` | 雷 |
| `ice` | 冰 |
| `steel` | 钢 |
| `light` | 光 |
| `dark` | 暗 |
| `space` | 空间 |
| `psychic` | 超能力 |
| `spirit` | 灵 |
| `demon` | 恶魔 |
| `holy` | 圣 |
| `fighting` | 格斗 |
| `dragon` | 龙 |
| `poison` | 毒 |

### 3.2 属性挂多少个

- **单位**：`combat_type_ids` 允许 `0..2` 个。可以无属性、单属性、双属性。
- **技能**：`combat_type_id` 允许 `0..1` 个。空串 = 无属性技能。

### 3.3 克制表怎么读

`BattleFormatConfig.combat_type_chart` 是显式表，写了 `(atk, def) -> mul`：

- 表里写了的：按写的算，只允许 `2.0 / 1.0 / 0.5`。
- 表里没写的：默认 `1.0`（中立，不吃克制也不吃减伤）。
- 单位双属性：对每个属性逐项查表，结果**连乘**。比如打"火 + 木"双属性目标，技能是水：水 → 火 = `2.0`，水 → 木 = `0.5`，最终 = `1.0`。
- **不做** STAB（同属性加成），**不做**属性免疫（`0.0`）。

#### 完整克制表（共 106 条）

下面把全部 106 条克制条目按方便查阅的顺序列出来。要查"X 打 Y"的倍率，直接看"攻 X"那一栏：表里没写的就是 `1.0`。

**火（fire）作为攻方**：
- 火 → 木：`2.0`
- 火 → 冰：`2.0`
- 火 → 钢：`2.0`
- 火 → 毒：`2.0`
- 火 → 水：`0.5`
- 火 → 土：`0.5`
- 火 → 龙：`0.5`

**水（water）作为攻方**：
- 水 → 火：`2.0`
- 水 → 土：`2.0`
- 水 → 木：`0.5`
- 水 → 雷：`0.5`
- 水 → 龙：`0.5`
- 水 → 毒：`0.5`

**木（wood）作为攻方**：
- 木 → 水：`2.0`
- 木 → 土：`2.0`
- 木 → 火：`0.5`
- 木 → 风：`0.5`
- 木 → 冰：`0.5`
- 木 → 毒：`0.5`

**土（earth）作为攻方**：
- 土 → 火：`2.0`
- 土 → 雷：`2.0`
- 土 → 钢：`2.0`
- 土 → 毒：`2.0`
- 土 → 水：`0.5`
- 土 → 木：`0.5`

**风（wind）作为攻方**：
- 风 → 木：`2.0`
- 风 → 格斗：`2.0`
- 风 → 雷：`0.5`
- 风 → 冰：`0.5`
- 风 → 龙：`0.5`

**雷（thunder）作为攻方**：
- 雷 → 水：`2.0`
- 雷 → 风：`2.0`
- 雷 → 土：`0.5`
- 雷 → 龙：`0.5`

**冰（ice）作为攻方**：
- 冰 → 风：`2.0`
- 冰 → 木：`2.0`
- 冰 → 龙：`2.0`
- 冰 → 火：`0.5`
- 冰 → 钢：`0.5`

**钢（steel）作为攻方**：
- 钢 → 冰：`2.0`
- 钢 → 光：`2.0`
- 钢 → 圣：`2.0`
- 钢 → 龙：`2.0`
- 钢 → 毒：`2.0`
- 钢 → 火：`0.5`
- 钢 → 土：`0.5`
- 钢 → 格斗：`0.5`

**光（light）作为攻方**：
- 光 → 暗：`2.0`
- 光 → 灵：`2.0`
- 光 → 恶魔：`2.0`
- 光 → 钢：`0.5`
- 光 → 空间：`0.5`

**暗（dark）作为攻方**：
- 暗 → 超能力：`2.0`
- 暗 → 灵：`2.0`
- 暗 → 光：`0.5`
- 暗 → 圣：`0.5`
- 暗 → 格斗：`0.5`

**空间（space）作为攻方**：
- 空间 → 光：`2.0`
- 空间 → 圣：`2.0`
- 空间 → 格斗：`2.0`
- 空间 → 灵：`0.5`
- 空间 → 超能力：`0.5`

**超能力（psychic）作为攻方**：
- 超能力 → 格斗：`2.0`
- 超能力 → 空间：`2.0`
- 超能力 → 暗：`0.5`
- 超能力 → 恶魔：`0.5`
- 超能力 → 灵：`0.5`

**灵（spirit）作为攻方**：
- 灵 → 超能力：`2.0`
- 灵 → 空间：`2.0`
- 灵 → 光：`0.5`
- 灵 → 暗：`0.5`
- 灵 → 恶魔：`0.5`
- 灵 → 毒：`0.5`

**恶魔（demon）作为攻方**：
- 恶魔 → 灵：`2.0`
- 恶魔 → 超能力：`2.0`
- 恶魔 → 光：`0.5`
- 恶魔 → 圣：`0.5`
- 恶魔 → 格斗：`0.5`

**圣（holy）作为攻方**：
- 圣 → 恶魔：`2.0`
- 圣 → 暗：`2.0`
- 圣 → 龙：`2.0`
- 圣 → 毒：`2.0`
- 圣 → 钢：`0.5`
- 圣 → 空间：`0.5`

**格斗（fighting）作为攻方**：
- 格斗 → 钢：`2.0`
- 格斗 → 暗：`2.0`
- 格斗 → 恶魔：`2.0`
- 格斗 → 风：`0.5`
- 格斗 → 超能力：`0.5`
- 格斗 → 空间：`0.5`
- 格斗 → 毒：`0.5`

**龙（dragon）作为攻方**：
- 龙 → 火：`2.0`
- 龙 → 水：`2.0`
- 龙 → 雷：`2.0`
- 龙 → 风：`2.0`
- 龙 → 冰：`0.5`
- 龙 → 钢：`0.5`
- 龙 → 圣：`0.5`

**毒（poison）作为攻方**：
- 毒 → 水：`2.0`
- 毒 → 木：`2.0`
- 毒 → 格斗：`2.0`
- 毒 → 灵：`2.0`
- 毒 → 火：`0.5`
- 毒 → 土：`0.5`
- 毒 → 钢：`0.5`
- 毒 → 圣：`0.5`

#### 关键对位

为了好读，列几个直接和正式四角色相关的对位：

- 五条悟（空间 + 超能力）受到的克制：
  - 暗 → 超能力 = `2.0`，恶魔 → 超能力 = `2.0`，灵 → 超能力 = `2.0`：所以宿傩的「伏魔御厨子」（恶魔属性）打五条悟会乘 `2.0`。
  - 超能力 → 暗 = `0.5`：五条悟的「赫」（超能力属性）打恶魔系会乘 `0.5`。所以五条悟 → 宿傩的赫只有 `0.5`。
  - 光 → 空间 = `0.5`，圣 → 空间 = `0.5`，格斗 → 空间 = `0.5`，超能力 → 空间 = `2.0`：五条悟的"空间"被超能力克。
- 宿傩（火 + 恶魔）受到的克制：
  - 水 → 火 = `2.0`，土 → 火 = `2.0`：火属性单位本身怕水和土。
  - 光 → 恶魔 = `2.0`，圣 → 恶魔 = `2.0`，格斗 → 恶魔 = `2.0`，超能力 → 恶魔 = `0.5`：宿傩对超能力（五条悟）有 `0.5` 减伤。
  - 火 → 火 = `1.0`（默认），恶魔 → 恶魔 = `1.0`：互打无事。
- 鹿紫云一（雷 + 格斗）受到的克制：
  - 土 → 雷 = `2.0`，土 → 格斗 = `1.0`：吃土系亏。
  - 风 → 格斗 = `2.0`，钢 → 格斗 = `0.5`：风对它强、钢对它弱。
  - 雷 → 雷 = `1.0`：单看克制表雷打雷是中立。但鹿紫云的被动「电荷分离」额外加了角色级"雷属性主动技 / 奥义对自己最终伤害 ×0.5"的减伤，**这是被动效果不是克制表，注意区分**。
- 带土（光 + 暗）受到的克制：
  - 钢 → 光 = `2.0`：钢系打光属性较强。
  - 光 → 暗 = `2.0`、暗 → 光 = `0.5`：自家两属性互克。
  - 钢 → 光 = `2.0`，暗 → 光 = `0.5`，圣 → 暗 = `2.0`，格斗 → 暗 = `2.0`，光 → 暗 = `2.0`：带土同时身怀两侧弱点。

### 3.4 damage_kind 与 combat_type 的区别

很多新人会搞混这两个：

- **`damage_kind`**：决定用什么攻防来算伤害。只能是 `physical / special / none` 三选一。
  - `physical` → 用攻方的攻击 vs 防守方的防御。
  - `special` → 用攻方的特攻 vs 防守方的特防。
  - `none` → 这一招不算伤害，常用于自我治疗、自我加 buff、展开 field 这种。
- **`combat_type`**：决定属性克制倍率。和 `damage_kind` **完全独立**。
  - 一个特殊招（`damage_kind = special`）可以是 `space` 属性，也可以是无属性。
  - 一个物理招（`damage_kind = physical`）可以是 `thunder` 属性，也可以是无属性。

举例：
- 五条悟「苍」：`damage_kind = special`、`combat_type_id = space` → 用特攻打特防、走空间属性克制。
- 鹿紫云「雷拳」：`damage_kind = physical`、`combat_type_id = thunder` → 用攻击打防御、走雷属性克制。
- 宿傩「解」：`damage_kind = physical`、`combat_type_id = ""` → 用攻击打防御、无属性克制（中立 1.0）。

---

## 4. 命中与伤害计算

### 4.1 命中公式

```
hit_rate = clamp(accuracy / 100, 0, 1)
若 hit_roll < hit_rate 则命中
```

- **`accuracy`**：技能自带的命中值（0~100）。
- **`accuracy = 100`**：必中，不再 roll。
- **field 命中覆盖**：如果当前 field 有 `creator_accuracy_override >= 0`，且行动者就是这个 field 的创建者（creator），那本次命中直接改用覆盖值（一般是 `100`）。这就是"领域内必中"。
- **目标侧命中干扰（incoming_accuracy）**：如果 `resolved_accuracy < 100`、本次又是敌方对你方 active 来袭的 `skill / ultimate`，那目标身上挂着的 `incoming_accuracy` rule_mod 会再叠加进去。整轮叠完后 clamp 到 `0..99`（不能逆叠成必中）。
- **`nullify_field_accuracy`**：是个 bool 类型 rule_mod，设为 `true` 时，会把"field 加的必中覆盖"屏蔽掉，但不影响技能原本就写死的 `accuracy = 100`。鹿紫云的「弥虚葛笼」就是用它来反制对手领域的必中。

具体例子：

- 一个 `accuracy = 95` 的敌方技能打五条悟（五条悟挂着「无下限」的 `incoming_accuracy add -10`）：实际命中 = `95 - 10 = 85`，再 roll。
- 一个 `accuracy = 100` 的敌方技能打五条悟：必中，「无下限」不生效（已经是 100，不再读 incoming_accuracy）。
- 鹿紫云开了「弥虚葛笼」（`nullify_field_accuracy = true`），对面在领域里打他：领域附加的必中失效，对面回到技能原本的 `accuracy`，再 roll。

### 4.2 伤害公式

```
base_damage = floor(floor(((2 * Lv / 5 + 2) * Power * A / max(1, D))) / 50) + 2
```

`Lv = 50`（固定），所以可以化简为：

```
base_damage = floor(floor(22 * Power * A / max(1, D)) / 50) + 2
```

各变量含义：

- **`Lv`**：固定 `50`。
- **`Power`**：技能威力（本体威力 + 加成威力，比如鹿紫云回授电击的 `30 + 12 × 层数`）。
- **`A`**：攻方的有效攻击 / 特攻（基础值已乘以 stat stage 倍率）。
  - `damage_kind = physical` → 取攻方的攻击。
  - `damage_kind = special` → 取攻方的特攻。
- **`D`**：守方的有效防御 / 特防（也乘 stat stage 倍率）。
  - `damage_kind = physical` → 取守方的防御。
  - `damage_kind = special` → 取守方的特防。
  - 分母最少 1（`max(1, D)`）。

最终伤害：

```
final_damage = max(1, floor(base_damage * final_mod))
```

- **`final_mod`**：所有最终倍率连乘。默认每项 `1.0`。
  ```
  final_mod = skill_mod * item_mod * field_mod * rule_mod * type_effectiveness
  ```
  - `skill_mod`：技能自身写的最终倍率（当前角色资源里没用，多数都是 1.0）。
  - `item_mod`：被动持有物给的减伤 / 加伤（当前正式四角色都没装持有物，所以都是 1.0）。
  - `field_mod`：当前 field 给的伤害修正（当前 field 都没改伤害，1.0）。
  - `rule_mod`：白名单读取点（含 `incoming_action_final_mod / incoming_heal_final_mod` 等）的连乘结果。
  - `type_effectiveness`：属性克制倍率，按 §3.3 的克制表查表。

### 4.3 伤害示例

**例 1：五条悟用「苍」打宿傩**

- 苍：`damage_kind = special`、`power = 44`、`combat_type_id = space`。
- 攻方有效特攻：五条悟基础特攻 `88`，假设无 stat stage 修饰，`A = 88`。
- 守方有效特防：宿傩基础特防 `60`，假设无 stat stage 修饰，`D = 60`。
- 属性克制：space → fire = 1.0（表里没写），space → demon = 1.0（表里没写），所以 `type_effectiveness = 1.0`。
- 没有别的 final_mod 来源，`final_mod = 1.0`。

计算：
```
base_damage = floor(floor(22 × 44 × 88 / 60) / 50) + 2
            = floor(floor(85184 / 60) / 50) + 2
            = floor(floor(1419.7) / 50) + 2
            = floor(1419 / 50) + 2
            = floor(28.38) + 2
            = 28 + 2
            = 30
final_damage = max(1, floor(30 × 1.0)) = 30
```

宿傩吃 30 点伤害。

**例 2：宿傩用「伏魔御厨子」打五条悟**

- 奥义伏魔御厨子：`damage_kind = special`、`power = 68`、`combat_type_id = demon`。
- 假设宿傩刚开了领域，领域绑定 `attack +1 / sp_attack +1`，特攻有效值 = `84 × 1.5 = 126`。
- 五条悟特防 `68`，无修正，`D = 68`。
- 属性克制：demon → space = 1.0（表里没写），demon → psychic = 2.0（暗、灵、超能力被恶魔克），所以 `type_effectiveness = 1.0 × 2.0 = 2.0`。

计算：
```
base_damage = floor(floor(22 × 68 × 126 / 68) / 50) + 2
            = floor(floor(188496 / 68) / 50) + 2
            = floor(floor(2772.0) / 50) + 2
            = floor(2772 / 50) + 2
            = floor(55.44) + 2
            = 55 + 2
            = 57
final_damage = max(1, floor(57 × 2.0)) = max(1, 114) = 114
```

五条悟吃 114 点伤害。可以看到属性克制 + 领域增幅一上来直接打掉一半多血。

**例 3：默认动作反伤**

默认动作的反伤 = `floor(max_hp * 0.25)`，至少 1。

- 五条悟（`max_hp = 124`）：反伤 = `floor(124 × 0.25) = 31`。
- 鹿紫云（`max_hp = 118`）：反伤 = `floor(118 × 0.25) = 29`（实际为 `29.5` 向下取整 = `29`）。
- 默认动作走 `damage_kind = physical`、`power = 50`、`combat_type` 中立（克制倍率固定 1.0），打完之后自己再吃这一刀反伤。

### 4.4 damage_segments 多段伤害

技能可以声明 `damage_segments`，写一组分段；命中后按段依次结算。例如带土的「十尾尾兽玉」：

- 整招命中判定只有 1 次（`accuracy = 100` → 必中）。
- 命中后展开两段定义：
  - 段 1：`repeat_count = 2`、`power = 12`、`combat_type_id = dark`、`damage_kind = special`。共结算 2 次。
  - 段 2：`repeat_count = 8`、`power = 12`、`combat_type_id = light`、`damage_kind = special`。共结算 8 次。
  - 顶层 `power = 0`，不再额外打主体伤害；伤害完全由 `damage_segments` 承担。
- 每段独立结算：独立查属性克制、独立读 `incoming_action_final_mod`、独立写日志。
- 中途目标倒下（`hp <= 0`）后续段立即停止。
- 每段成功结算后会派发 `on_receive_action_damage_segment` 触发点（可被防反类 effect 监听）。
- 整招总威力 = 暗段 `12 × 2` + 光段 `12 × 8` = `24 + 96 = 120`，但不是一次结算，是 10 次小的（每次都吃一次属性克制乘法、可能被减伤等）。

---

## 5. 效果（effect）、领域（field）与被动

### 5.1 effect 是什么

`effect` 是引擎里所有"会发生事情"的统一抽象。技能命中后挂的标记、奥义触发的 buff、被动给你加的 rule_mod、persistent 的能力阶段——全都是 effect。

每个 EffectDefinition 有这些关键字段：

| 字段 | 含义 |
|---|---|
| `id` | 唯一 ID。 |
| `scope` | 挂哪——`self / target / field / action_actor` 之一。 |
| `duration_mode` | `turns`（按回合）/ `permanent`（永久）。 |
| `duration` | turns 模式下持续多少个 `turn_end` / `turn_start` 节点。 |
| `decrement_on` | 在哪个节点扣减剩余回合（`turn_end` / `turn_start`）。 |
| `stacking` | 叠加策略：`none / refresh / replace / stack`。 |
| `max_stacks` | 仅 `stack` 时使用，叠层硬上限。`-1` 表示不封顶。 |
| `trigger_names` | 这个 effect 监听哪些触发点（`on_hit / on_cast / turn_end` 等）。 |
| `payloads` | 触发时执行的 payload 列表（伤害、治疗、加蓝、stat_mod、apply_field、rule_mod 等）。 |
| `persists_on_switch` | 换人后是否保留。默认 `false`（换下就清）。`true` 时会跟着单位下场继续倒计时。 |
| `on_expire_effect_ids` | 自然到期时追加跑这些 effect。 |
| `required_target_effects` | effect 级前置守卫：目标必须挂着这些 effect 才生效。 |
| `required_target_same_owner` | 加了 = `true` 时，必须是当前 owner 自己挂的才算。 |
| `required_incoming_command_types / required_incoming_combat_type_ids` | 受击型 effect 用的过滤：只对指定动作类型 / 属性来袭生效。 |

**叠加策略对照表**：

| stacking | 行为 |
|---|---|
| `none` | 已有同名实例时，再施加无效。 |
| `refresh` | 已有同名实例时，刷新剩余回合（不开新的）。 |
| `replace` | 用新实例替换旧实例。 |
| `stack` | 创建并行的新实例，每层独立倒计时、独立结算。 |

### 5.2 field（领域 / 场地）

field 是"全场只有 1 个"的全局效果。

| 字段 | 含义 |
|---|---|
| `id` | 唯一 ID。 |
| `field_kind` | `domain`（领域）/ `normal`（普通 field）。 |
| `effect_ids` | field 落地后在 `field_apply` 触发的 effect。 |
| `on_break_effect_ids` | field 被打断时跑的 effect（不写到期日志）。 |
| `on_expire_effect_ids` | field 自然到期时跑的 effect。 |
| `creator_accuracy_override` | 行动者是 creator 时本次命中的覆盖值。`-1` = 不覆盖。 |

**生命周期** field 的持续回合不写在 `FieldDefinition` 里，而是由施加它的 `EffectDefinition.duration / decrement_on` 决定（一般是 `duration = 3 / decrement_on = turn_end`，意思是连续 3 次 `turn_end` 后到期）。

**冲突矩阵**：

| 场上没有 field | 直接落地 |
| 场上是普通 field，新 field 是普通 | 直接替换 |
| 场上是普通 field，新 field 是领域 | 领域直接替换普通 field |
| 场上是领域，新 field 是普通 | 普通 field 被阻断（写 `effect:field_blocked`） |
| 场上是领域，新 field 也是领域 | **进入领域对拼**，写 `effect:field_clash` |

**领域对拼（domain clash）**：

- 比较双方的 **当前 MP（扣完本次奥义 MP 之后）**。
- MP 高的一方留场。
- MP 相等时，按 `BattleFormatConfig.domain_clash_tie_threshold = 0.5` 决定是不是 challenger 胜出。这个值是个 0~1 的阈值，引擎抽个随机数 `r ∈ [0,1)`，若 `r < 0.5` challenger 胜，反之 defender 胜。结果会写进日志保证回放可复现。
- 失败方：field 不落地，连"成功后才生效的附带效果"也不生效。
- 胜利方：field 落地，跑 `field_apply` 链。

**creator 离场就打断**：如果 field creator 离场（手动换人 / 强制换下 / 倒下），field 立即被打断（`field_break`）。普通 field 也是这样。

**自然到期和提前打断的差异**：

| 路径 | 走哪些 effect |
|---|---|
| 自然到期 | `on_expire_effect_ids` → 写 `effect:field_expire` 日志 |
| 提前打断 | `on_break_effect_ids` → 不写 `field_expire`，不跑 `on_expire_effect_ids` |

**自家领域不能续开**：当前如果场上的领域是你方创建的，那你方所有 `is_domain_skill = true` 的技能在合法性阶段会被禁掉，避免"自己续开自己领域"。

### 5.3 被动技能 vs 被动持有物

| | 被动技能（PassiveSkillDefinition） | 被动持有物（PassiveItemDefinition） |
|---|---|---|
| 字段 | `trigger_names + effect_ids` | `always_on_effect_ids + on_turn_effect_ids + (deprecated) on_receive_effect_ids` |
| 数量上限 | 每单位 1 个被动技能。 | 每单位最多 1 个；同队不可重复。 |
| 是否进行动队列 | 否。 | 否。 |
| 是否参与回合节点触发 | 仅当前在场单位才触发。 | 仅当前在场单位才触发。 |
| 当前正式四角色 | Gojo / Sukuna / Kashimo / Obito 都用了。 | 当前 4 角色都没装。 |

注意：`on_receive_effect_ids` 是禁用迁移字段。资源里允许保留这个字段名，但**值必须为空**；非空在加载期直接 fail-fast。新角色不要再用它。

### 5.4 on_matchup_changed 触发时机

`on_matchup_changed` 是"对位变化"触发点。指什么情况下"对位变了"？答：当前在场的双方组合（你方 active 是谁、对方 active 是谁）发生变化时就触发。

具体来说：

- 战斗开始：先跑 `on_enter`、补位稳定后跑 `battle_init`，最后再触发一次 `on_matchup_changed`（如果 battle_init 又导致补位形成新对位的话）。
- 任一方手动换人 / 被强制换下 / 被打倒后补位，导致 active 组合变化 → 触发 `on_matchup_changed`。
- 重点：不是每回合都触发，是"对位真的变了"才触发。

宿傩的「教会你爱的是...」就挂在这个触发点：每次对位变化时按双方"7 维差"重算回蓝档位，然后用 `stacking = replace` 替换掉旧的 mp_regen rule_mod。

---

## 6. 回合排序

### 6.1 行动排序链

行动队列用统一三元组排：

```
priority -> speed -> random
```

- **`priority`**：数值越大越先。统一 `-5 ~ +5` 数轴。
- **`speed`**：priority 相同才看速度。读取的是行动者当前的有效速度（吃 stat stage）。
- **`random`**：speed 也相同才抽 `speed_tie_roll`。

行动侧 priority 取值约束：

| 行动类型 | priority |
|---|---|
| 绝对先手奥义 | 固定 `+5` |
| 手动换人 | 固定 `+4` |
| 普通技能 | `-2 ~ +2`，默认 `0` |
| 资源型默认动作 | 固定 `0` |
| `wait` | 固定 `0` |
| 绝对后手奥义 | 固定 `-5` |

注意：奥义只能 `+5` 或 `-5`，不能用 `+4` `0` `+2` 这类中间值；普通技能不能用 `+5` `+4` `-5`。

### 6.2 当前正式技能 priority 列表

| 技能 | priority |
|---|---|
| 五条悟·苍 | `0` |
| 五条悟·赫 | `0` |
| 五条悟·茈 | `-1` |
| 五条悟·反转术式 | `0` |
| 五条悟·无量空处（奥义） | `+5` |
| 宿傩·解 | `+1` |
| 宿傩·捌 | `-1` |
| 宿傩·开 | `-2` |
| 宿傩·反转术式 | `0` |
| 宿傩·伏魔御厨子（奥义） | `+5` |
| 鹿紫云·雷拳 | `+1` |
| 鹿紫云·蓄电 | `0` |
| 鹿紫云·回授电击 | `0` |
| 鹿紫云·弥虚葛笼 | `+2` |
| 鹿紫云·幻兽琥珀（奥义） | `+5` |
| 带土·求道焦土 | `0` |
| 带土·阴阳遁 | `+2` |
| 带土·求道玉 | `0` |
| 带土·六道十字奉火 | `-1` |
| 带土·十尾尾兽玉（奥义） | `+5` |

### 6.3 效果排序链

同一触发点同一批次里多个 effect 同时待结算，统一按这个排：

```
priority -> source_order_speed_snapshot -> source_kind_order -> source_instance_id -> random
```

- **`priority`**：effect 自带的 priority（默认 0）。
- **`source_order_speed_snapshot`**：effect 入队时固化的速度快照（不读运行态最新速度）。
- **`source_kind_order`**：来源类型枚举，越小越先：`0 = system, 1 = field, 2 = active_skill, 3 = passive_skill, 4 = passive_item`。
- **`source_instance_id`**：稳定的来源实例 ID。
- **`random`**：前面全相同才抽。

### 6.4 forced_replace（强制换人）插入时机

- 强制换人是 effect payload，不进行动队列。
- 触发时机：作为某个 effect 的 payload，在该 effect 的执行起点直接执行。
- 顺序：检查目标是否有合法替补 → 旧单位触发 `on_switch`（带 `leave_reason = forced_replace`）→ `on_exit` → 离场重置 → 替补入场 → `on_enter`。
- **没有合法替补时**：`forced_replace` 直接失效（不报错也不算成功），`on_switch / on_exit` 都不触发。

### 6.5 击倒补位时机

倒下是另一条链路。当某个行动结算后或回合末结算后，引擎扫到有人 HP = 0：

1. 标记 `fainted_pending_leave`。
2. 跑 `on_faint`、`on_kill`（来源归属）、`on_exit`。
3. 离场重置（清 stat stage 等）。
4. 若是 field creator → 立即 `field_break`。
5. 若该方还有后备 → 立即强制补位（不进行动队列）。
6. 新单位入场 → 跑 `on_enter`。
7. 若补位引发新的 KO，继续在当前窗口处理直到稳定。

---

# 第二部分：角色详情

下面四节按"基本数据 → 技能详情 → 奥义详情 → 被动详情 → 对局风格"展开。所有数值都是从 `.tres` 文件直接抠出来的。

---

## 五条悟（Gojo Satoru）

### A. 基本数据

| 项 | 值 |
|---|---|
| 单位 ID | `gojo_satoru` |
| 显示名 | 五条悟 |
| 战斗属性 | `space`（空间）+ `psychic`（超能力） |
| HP | `124` |
| 攻击 | `56` |
| 防御 | `60` |
| 特攻 | `88` |
| 特防 | `68` |
| 速度 | `86` |
| BST（六维） | `482` |
| `max_mp` | `100` |
| `init_mp` | `50` |
| `regen_per_turn` | `14` |
| `ultimate_points_required` | `3` |
| `ultimate_points_cap` | `3` |
| `ultimate_point_gain_on_regular_skill_cast` | `+1` |
| 奥义 | 无量空处（`gojo_unlimited_void`） |
| 被动技能 | 无下限（`gojo_mugen`） |
| 被动持有物 | 无 |
| 默认装配技能 `skill_ids` | `gojo_ao`、`gojo_aka`、`gojo_murasaki` |
| 候选技能池 `candidate_skill_ids` | `gojo_ao`、`gojo_aka`、`gojo_murasaki`、`gojo_reverse_ritual` |

首回合预回蓝后实战可用 MP：`50 + 14 = 64`。

### B. 技能详情

#### 苍（Ao）

| 字段 | 值 |
|---|---|
| 技能 ID | `gojo_ao` |
| 显示名 | 苍 |
| `damage_kind` | `special` |
| `combat_type_id` | `space` |
| `power` | `44` |
| `accuracy` | `95` |
| `mp_cost` | `14` |
| `priority` | `0` |
| `targeting` | `enemy_active_slot` |
| `effects_on_hit_ids` | `gojo_ao_speed_up`、`gojo_ao_mark_apply` |

**命中后效果**：
- `gojo_ao_speed_up`：自身（`scope = self`）速度阶段 `+1`。`stacking = none` 永久（直到离场清空）。
- `gojo_ao_mark_apply`：在目标（`scope = target`）身上施加 `gojo_ao_mark`（苍标记）。
  - `gojo_ao_mark`：持续 `3` 次 `turn_end`，`stacking = refresh`，`persists_on_switch = false`（标记持有者下场清掉）。本身没有 payload，纯标记。

**用途**：低消耗特殊技 + 自加速 + 给目标挂"苍标记"。配合「赫」凑双标记后，下次再用「茈」会触发条件爆发。

#### 赫（Aka）

| 字段 | 值 |
|---|---|
| 技能 ID | `gojo_aka` |
| 显示名 | 赫 |
| `damage_kind` | `special` |
| `combat_type_id` | `psychic` |
| `power` | `44` |
| `accuracy` | `95` |
| `mp_cost` | `14` |
| `priority` | `0` |
| `targeting` | `enemy_active_slot` |
| `effects_on_hit_ids` | `gojo_aka_slow_down`、`gojo_aka_mark_apply` |

**命中后效果**：
- `gojo_aka_slow_down`：目标（`scope = target`）速度阶段 `-1`。
- `gojo_aka_mark_apply`：在目标身上施加 `gojo_aka_mark`（赫标记）。同样持续 `3` 次 `turn_end`，`stacking = refresh`，`persists_on_switch = false`。

**用途**：低消耗特殊技 + 减对方速度 + 给目标挂"赫标记"。和「苍」一起用凑双标记。

#### 茈（Murasaki）

| 字段 | 值 |
|---|---|
| 技能 ID | `gojo_murasaki` |
| 显示名 | 茈 |
| `damage_kind` | `special` |
| `combat_type_id` | `space` |
| `power` | `64` |
| `accuracy` | `90` |
| `mp_cost` | `24` |
| `priority` | `-1` |
| `targeting` | `enemy_active_slot` |
| `effects_on_hit_ids` | `gojo_murasaki_conditional_burst` |

**命中后条件爆发**（`gojo_murasaki_conditional_burst`）：
- `scope = target`，`duration_mode = permanent`，`stacking = none`，`trigger_names = ["on_hit"]`。
- **前置守卫**：`required_target_effects = ["gojo_ao_mark", "gojo_aka_mark"]`、`required_target_same_owner = true`。也就是说，目标必须身上同时持有"苍标记 + 赫标记"，且这两枚标记都是**当前这名五条悟本人**挂的。
- payload 顺序：
  1. `damage(use_formula = true, amount = 32, damage_kind = special)`：追加一段公式伤害，威力 `32`。`use_formula = true` 时继承链技能（茈本身）的 `combat_type_id = space`。
  2. `remove_effect(gojo_ao_mark)`：清掉苍标记。
  3. `remove_effect(gojo_aka_mark)`：清掉赫标记。
- **没有自伤 / 反噬**。
- 边界：若茈本体伤害先把目标打到 0 血 → 追加段整条跳过；若追加段先把目标打到 0 血 → 后续两个 `remove_effect` 静默跳过。

**用途**：双标记触发时一次连段（`64` 本体 + `32` 追加 = 等效高伤害单回合爆发），用来收尾。

#### 反转术式（Reverse Ritual）

| 字段 | 值 |
|---|---|
| 技能 ID | `gojo_reverse_ritual` |
| 显示名 | 反转术式 |
| `damage_kind` | `none` |
| `combat_type_id` | `""`（无属性） |
| `power` | `0` |
| `accuracy` | `100` |
| `mp_cost` | `14` |
| `priority` | `0` |
| `targeting` | `self` |
| `effects_on_cast_ids` | `gojo_reverse_heal` |

**`gojo_reverse_heal`**：`heal(use_percent = true, percent = 25)`，回复自身 `25%` 最大 HP（即 `floor(124 × 0.25) = 31` 点）。

**注意**：这是候选技能池里的技能，默认装配里**没有**。需要赛前用 `SideSetup.regular_skill_loadout_overrides` 把它换进 3 个常规技能槽之一。

**用途**：续航。把苍 / 赫 / 茈 中替掉一个换它进来，可以让五条悟更耐打但失去一部分 burst。

### C. 奥义详情：无量空处（Unlimited Void）

| 字段 | 值 |
|---|---|
| 技能 ID | `gojo_unlimited_void` |
| 显示名 | 无量空处 |
| `damage_kind` | `special` |
| `combat_type_id` | `space` |
| `power` | `48` |
| `accuracy` | `100` |
| `mp_cost` | `50` |
| `priority` | `+5`（绝对先手） |
| `is_domain_skill` | `true` |
| `targeting` | `enemy_active_slot` |
| `effects_on_hit_ids` | `gojo_apply_domain_field` |
| 奥义点要求 | `ultimate_points >= 3` |

**奥义合法性**：必须同时满足 `current_mp >= 50` 和 `ultimate_points >= 3`。开始施放时奥义点立即清零。

**field：`gojo_unlimited_void_field`（无量空处）**

| 字段 | 值 |
|---|---|
| `field_kind` | `domain`（领域） |
| `creator_accuracy_override` | `100`（领域内五条悟自己的技能必中） |
| `effect_ids` | `gojo_domain_cast_buff` |
| `on_expire_effect_ids` | `gojo_domain_buff_remove` |
| `on_break_effect_ids` | `gojo_domain_buff_remove` |

**展开链**：

1. 命中目标后跑 `gojo_apply_domain_field`：`apply_field(gojo_unlimited_void_field, duration = 3, decrement_on = turn_end, on_success_effect_ids = ["gojo_domain_action_lock"])`。
2. **领域对拼判定**：如果场上已有领域，进对拼。MP 高的赢。
3. 领域真的立住后：
   - 跑 `gojo_domain_cast_buff`（`field_apply` 触发）：给五条悟 `sp_attack +1`。
   - 跑 `gojo_domain_action_lock`（`field_apply_success` 触发，`scope = target`）：给对手挂 `action_legality deny all` rule_mod，持续 `1` 次 `turn_end`（即本回合）。但 `wait` 不被禁。
4. 领域生命周期：`duration = 3` + `decrement_on = turn_end`。从展开当回合起，连续 3 次 `turn_end` 后自然到期。
5. 自然到期：跑 `on_expire_effect_ids = gojo_domain_buff_remove`（移除 `sp_attack +1`），写 `effect:field_expire`。
6. 提前打断（creator 离场 / 被新 field 覆盖）：跑 `on_break_effect_ids = gojo_domain_buff_remove`（移除 `sp_attack +1`），不写 `field_expire`。

**领域对拼失败时**：领域不落地，`sp_attack +1` 不生效，`gojo_domain_action_lock` 不生效。

**`gojo_domain_action_lock`**：
- `scope = target`，`duration_mode = permanent`，`trigger_names = ["field_apply_success"]`。
- payload：`rule_mod(mod_kind = action_legality, mod_op = deny, value = "all", scope = target, duration_mode = turns, duration = 1, decrement_on = turn_end, stacking = replace)`。
- 效果：禁掉对手当前回合的所有技能 / 奥义 / 换人。但 `wait` 仍然可选。
- 限制：只能锁住"还没轮到执行"的对手；若对手已经先于五条悟行动过了，那次行动不会被回溯取消。

**总结**：五条悟开领域 = 必中 + sp_attack +1 + 锁对手当回合行动。3 回合窗口内压制力很强。

### D. 被动详情：无下限（Mugen）

| 字段 | 值 |
|---|---|
| 被动 ID | `gojo_mugen` |
| 显示名 | 无下限 |
| `trigger_names` | `on_enter` |
| `effect_ids` | `gojo_mugen_incoming_accuracy_down` |

**`gojo_mugen_incoming_accuracy_down`**：
- `scope = self`，`duration_mode = permanent`，`stacking = none`，`trigger_names = on_enter`。
- payload：`rule_mod(mod_kind = incoming_accuracy, mod_op = add, value = -10, scope = self, duration_mode = permanent, decrement_on = turn_end, stacking = none)`。

**实际效果**：
- 敌方对五条悟发动 `skill / ultimate` 时，先按现有流程得到 `resolved_accuracy`。
- 如果 `resolved_accuracy >= 100`（必中）：**无下限不生效**。
- 如果 `resolved_accuracy < 100`：本次命中再 `-10`。
- 例：敌方 `accuracy = 95` 的技能打五条悟 → 实际命中 `85`。
- 例：敌方 `accuracy = 100` 的技能打五条悟 → 实际命中 `100`，无下限不削。
- 例：领域内必中（`creator_accuracy_override = 100`）→ 必中，无下限不削。
- 注意：`switch / wait / resource_forced_default`、`self / field / none` 这些不属于"敌方主动技能命中五条悟"的路径，都不读取 `incoming_accuracy`。

**重新入场也生效**：每次五条悟入场（`on_enter`）都会重新挂这条 rule_mod，所以即使前面被换下又再上，效果也一直在。

### E. 简述对局风格

五条悟是高速控场型术师。开局靠苍 / 赫高频压血 + 攒奥义点 + 给对手贴标记，3 回合左右就能够开「无量空处」拉一波必中 + 锁人窗口；窗口内可以 sp_attack +1 倍率打出爆发。怕慢节奏长期消耗（特防 68 不算高），怕 BST 接近的对手在领域对拼里翻盘他。换装反转术式可以变成续航流，但放弃了双标记爆发节奏。

---

## 宿傩（Sukuna）

### A. 基本数据

| 项 | 值 |
|---|---|
| 单位 ID | `sukuna` |
| 显示名 | 宿傩 |
| 战斗属性 | `fire`（火）+ `demon`（恶魔） |
| HP | `126` |
| 攻击 | `78` |
| 防御 | `62` |
| 特攻 | `84` |
| 特防 | `60` |
| 速度 | `76` |
| BST（六维） | `486` |
| `max_mp` | `100` |
| `init_mp` | `45` |
| `regen_per_turn` | `12`（基础值；最终回蓝 = `12 + 对位差档位加值`） |
| `ultimate_points_required` | `3` |
| `ultimate_points_cap` | `3` |
| `ultimate_point_gain_on_regular_skill_cast` | `+1` |
| 奥义 | 伏魔御厨子（`sukuna_fukuma_mizushi`） |
| 被动技能 | 教会你爱的是...（`sukuna_teach_love`） |
| 被动持有物 | 无 |
| 默认装配技能 `skill_ids` | `sukuna_kai`、`sukuna_hatsu`、`sukuna_hiraku` |
| 候选技能池 `candidate_skill_ids` | `sukuna_kai`、`sukuna_hatsu`、`sukuna_hiraku`、`sukuna_reverse_ritual` |

### B. 技能详情

#### 解（Kai）

| 字段 | 值 |
|---|---|
| 技能 ID | `sukuna_kai` |
| 显示名 | 解 |
| `damage_kind` | `physical` |
| `combat_type_id` | `""`（无属性） |
| `power` | `42` |
| `accuracy` | `100` |
| `mp_cost` | `10` |
| `priority` | `+1` |
| `targeting` | `enemy_active_slot` |
| 命中后效果 | 无 |

**用途**：低消耗、`+1` 先制的稳定斩击。MP 经济好、命中 100 必中、用来压血和攒奥义点。无属性技不吃克制也不吃减伤，伤害稳定。

#### 捌（Hatsu）

| 字段 | 值 |
|---|---|
| 技能 ID | `sukuna_hatsu` |
| 显示名 | 捌 |
| `damage_kind` | `special` |
| `combat_type_id` | `""`（无属性） |
| `power` | `46`（基础威力） |
| `accuracy` | `95` |
| `mp_cost` | `18` |
| `priority` | `-1` |
| `power_bonus_source` | `mp_diff_clamped` |
| `targeting` | `enemy_active_slot` |
| 命中后效果 | 无 |

**威力公式**：`46 + max(0, actor.current_mp_after_cost - target.current_mp_now)`。

也就是先扣自己这次 18 MP，然后用扣完后的剩余 MP 减对方当前 MP，正数才加进威力。差越大威力越高。例：自己扣完还剩 80 MP，对手 30 MP → 实际威力 = `46 + 50 = 96`。

**用途**：后手重斩；自己蓝多对手蓝少时打得很疼。无属性 + 特殊伤害，配合 sp_attack 84 输出。

#### 开（Hiraku）

| 字段 | 值 |
|---|---|
| 技能 ID | `sukuna_hiraku` |
| 显示名 | 开 |
| `damage_kind` | `special` |
| `combat_type_id` | `fire` |
| `power` | `48` |
| `accuracy` | `90` |
| `mp_cost` | `22` |
| `priority` | `-2` |
| `targeting` | `enemy_active_slot` |
| `effects_on_hit_ids` | `sukuna_apply_kamado` |

**命中后挂"灶"**：
- `sukuna_apply_kamado`：对目标 `apply_effect(sukuna_kamado_mark)`。
- `sukuna_kamado_mark`（灶）：
  - `scope = self`（挂在目标自己身上），`duration_mode = turns`，`duration = 3`，`decrement_on = turn_end`。
  - `stacking = stack`，`max_stacks = 3`（最多 3 层并行）。
  - `trigger_names = ["on_exit"]`：目标离场时（`on_exit`）每层独立触发。
  - `payloads`：`damage(amount = 20, use_formula = false, combat_type_id = "fire")`（共享资源 `sukuna_shared_fire_burst_damage`）—— 20 点固定火属性伤害，**仍然吃属性克制**。
  - `on_expire_effect_ids = ["sukuna_kamado_explode"]`：自然到期时再爆一次。
  - `persists_on_switch = false`：目标换下时清掉。
- `sukuna_kamado_explode`：自然到期时跑的爆炸，同样 20 点火属性固定伤害。
- **3 层硬上限**：已经 3 层时再命中开 → 不新增层、不刷新现有层、不顶旧层、不写特殊日志。

**用途**：火属性 -2 后手重炮 + 持续压力。命中后逼对手"换人吃 on_exit 伤害"或"留在场上吃 turn_end 自然到期 + 终爆"。每层独立结算（双层 = 离场两次伤害 / 自然到期两次伤害）。

#### 反转术式（Reverse Ritual）

| 字段 | 值 |
|---|---|
| 技能 ID | `sukuna_reverse_ritual` |
| 显示名 | 反转术式 |
| `damage_kind` | `none` |
| `combat_type_id` | `""` |
| `power` | `0` |
| `accuracy` | `100` |
| `mp_cost` | `14` |
| `priority` | `0` |
| `targeting` | `self` |
| `effects_on_cast_ids` | `sukuna_reverse_heal` |

**`sukuna_reverse_heal`**：`heal(use_percent = true, percent = 25)`，回复 `25% × 126 = 31` 点（向下取整）。

**注意**：这是候选技能池里的；默认不装。要赛前覆盖把它换进来。

### C. 奥义详情：伏魔御厨子（Fukuma Mizushi）

| 字段 | 值 |
|---|---|
| 技能 ID | `sukuna_fukuma_mizushi` |
| 显示名 | 伏魔御厨子 |
| `damage_kind` | `special` |
| `combat_type_id` | `demon` |
| `power` | `68` |
| `accuracy` | `100` |
| `mp_cost` | `50` |
| `priority` | `+5`（绝对先手） |
| `is_domain_skill` | `true` |
| `targeting` | `enemy_active_slot` |
| `effects_on_hit_ids` | `sukuna_apply_domain_field` |

**奥义合法性**：`current_mp >= 50` 且 `ultimate_points >= 3`。

**field：`sukuna_malevolent_shrine_field`（伏魔御厨子·领域）**

| 字段 | 值 |
|---|---|
| `field_kind` | `domain` |
| `creator_accuracy_override` | `100` |
| `effect_ids` | `sukuna_domain_cast_buff` |
| `on_expire_effect_ids` | `sukuna_domain_buff_remove`、`sukuna_domain_expire_burst` |
| `on_break_effect_ids` | `sukuna_domain_buff_remove` |

**展开链**：

1. 命中后跑 `sukuna_apply_domain_field`：`apply_field(sukuna_malevolent_shrine_field, duration = 3, decrement_on = turn_end)`。
2. 领域对拼判定（同五条悟）。
3. 领域立住后：
   - `sukuna_domain_cast_buff`（`field_apply` 触发）：给宿傩同时挂 `attack +1` 和 `sp_attack +1`。
4. 生命周期：3 次 `turn_end` 自然到期。
5. **自然到期**：跑 `on_expire_effect_ids`：
   - `sukuna_domain_buff_remove`：移除 `attack -1` 和 `sp_attack -1`（即清掉之前的双攻 +1）。
   - `sukuna_domain_expire_burst`（`scope = target`，`trigger_names = field_expire`）：对当前敌方 active 造 `20` 点火属性固定伤害（吃属性克制）。**这就是"领域终爆"**。
6. **提前打断**（creator 离场 / 被新 field 覆盖）：只跑 `on_break_effect_ids = sukuna_domain_buff_remove`，**没有终爆**。
7. 领域对拼失败：什么都不发生。

**总结**：宿傩开领域 = 必中 + 双攻 +1 + 自然到期送一发 20 火固定伤害。3 回合内压力极强，但终爆只有"自然结束"才有。

### D. 被动详情：教会你爱的是...

| 字段 | 值 |
|---|---|
| 被动 ID | `sukuna_teach_love` |
| 显示名 | 教会你爱的是... |
| `trigger_names` | `on_matchup_changed` |
| `effect_ids` | `sukuna_refresh_love_regen` |

**`sukuna_refresh_love_regen`**：
- `scope = self`，`duration_mode = permanent`，`stacking = none`，`trigger_names = on_matchup_changed`。
- payload：`rule_mod(mod_kind = mp_regen, mod_op = add, value = 0, scope = self, duration_mode = permanent, decrement_on = turn_start, stacking = replace, dynamic_value_formula = matchup_bst_gap_band, dynamic_value_thresholds = [20, 40, 70, 110, 160], dynamic_value_outputs = [9, 8, 7, 6, 5], dynamic_value_default = 0)`。

**动态值口径**（按双方"7 维差" `gap = abs(各项 max_hp + atk + def + sp_atk + sp_def + speed + max_mp 之和)`）：

| `gap` | 额外回蓝 |
|---|---|
| `gap <= 20` | `+9` |
| `gap <= 40` | `+8` |
| `gap <= 70` | `+7` |
| `gap <= 110` | `+6` |
| `gap <= 160` | `+5` |
| `gap > 160` | `+0` |

**举例**：宿傩对位五条悟时，"7 维和"差距怎么算？
- 五条悟：`124 + 56 + 60 + 88 + 68 + 86 + 100 = 582`
- 宿傩：`126 + 78 + 62 + 84 + 60 + 76 + 100 = 586`
- `gap = |582 - 586| = 4 → 落在 gap <= 20 档 → +9`。
- 所以宿傩对五条悟时每回合回蓝 = `12 + 9 = 21`。

**其他规则**：
- `on_matchup_changed` 触发：每次对位变化（你方或对方换 active）时重新求值，用 `stacking = replace` 把旧的长期 mp_regen rule_mod 换成新档位。
- 对位差越接近 → 回蓝越多。这设计是"打势均力敌的对手时宿傩更能持续作战"。
- **多来源不互相冲撞**：如果未来宿傩还装个回蓝持有物，那是另一个来源组（`stacking_source_key` 不同），两组叠加。当前没有装持有物，只有这一条。

### E. 简述对局风格

宿傩是中速高压破阵手。靠"解 / 捌 / 开"组合压血、靠灶滚动逼对手换人或吃终爆、靠领域 3 回合双攻 +1 + 必中暴力推进。打势均力敌对手时被动回蓝档位高，资源节奏稳定；打 BST 差距大的对手反而回蓝低（反讽设计）。怕被快速领域翻盘（领域对拼输了什么都没有），怕特防压制（特防 60 偏低）。

---

## 鹿紫云一（Kashimo Hajime）

### A. 基本数据

| 项 | 值 |
|---|---|
| 单位 ID | `kashimo_hajime` |
| 显示名 | 鹿紫云一 |
| 战斗属性 | `thunder`（雷）+ `fighting`（格斗） |
| HP | `118` |
| 攻击 | `82` |
| 防御 | `58` |
| 特攻 | `72` |
| 特防 | `54` |
| 速度 | `90` |
| BST（六维） | `474` |
| `max_mp` | `100` |
| `init_mp` | `40` |
| `regen_per_turn` | `10` |
| `ultimate_points_required` | `3` |
| `ultimate_points_cap` | `3` |
| `ultimate_point_gain_on_regular_skill_cast` | `+1` |
| 奥义 | 幻兽琥珀（`kashimo_phantom_beast_amber`） |
| 被动技能 | 电荷分离（`kashimo_charge_separation`） |
| 被动持有物 | 无 |
| 默认装配技能 `skill_ids` | `kashimo_raiken`、`kashimo_charge`、`kashimo_feedback_strike` |
| 候选技能池 `candidate_skill_ids` | `kashimo_raiken`、`kashimo_charge`、`kashimo_feedback_strike`、`kashimo_kyokyo_katsura` |

首回合预回蓝后实战可用 MP：`40 + 10 = 50`。

### B. 技能详情

#### 雷拳（Raiken）

| 字段 | 值 |
|---|---|
| 技能 ID | `kashimo_raiken` |
| 显示名 | 雷拳 |
| `damage_kind` | `physical` |
| `combat_type_id` | `thunder` |
| `power` | `45` |
| `accuracy` | `100` |
| `mp_cost` | `12` |
| `priority` | `+1` |
| `targeting` | `enemy_active_slot` |
| `effects_on_hit_ids` | `kashimo_apply_negative_charge` |

**命中后挂"负电荷"**：
- `kashimo_apply_negative_charge`：对目标 `apply_effect(kashimo_negative_charge_mark)`。
- `kashimo_negative_charge_mark`（负电荷）：
  - `scope = self`（挂目标），`duration_mode = turns`，`duration = 4`，`decrement_on = turn_end`。
  - `stacking = stack`，`max_stacks = 3`。
  - `trigger_names = ["turn_end"]`：每层在每个 `turn_end` 各结算一次。
  - payload：`damage(amount = 8, use_formula = false, combat_type_id = "thunder")` —— 8 点雷属性固定伤害（仍吃属性克制）。
  - `persists_on_switch = false`：目标换下清掉。

**叠层时序**：
- 第 1 回合命中 → 1 层负电荷 → 回合末打 8 点。
- 第 2 回合命中 → 2 层 → 回合末 2 × 8 = 16 点。
- 第 3 回合命中 → 3 层 → 回合末 3 × 8 = 24 点。
- 第 4 回合再命中也只维持 3 层（不超）；回合末第 1 层到期掉回 2 层。

**用途**：`+1` 先制雷拳，命中必中、连续 3 回合可以叠满负电荷 → 持续掉血压力。

#### 蓄电（Charge）

| 字段 | 值 |
|---|---|
| 技能 ID | `kashimo_charge` |
| 显示名 | 蓄电 |
| `damage_kind` | `none` |
| `combat_type_id` | `""` |
| `power` | `0` |
| `accuracy` | `100` |
| `mp_cost` | `8` |
| `priority` | `0` |
| `targeting` | `self` |
| `effects_on_cast_ids` | `kashimo_apply_positive_charge` |

**`on_cast` 时挂"正电荷"**：
- `kashimo_apply_positive_charge`：对自身 `apply_effect(kashimo_positive_charge_mark)`。
- `kashimo_positive_charge_mark`（正电荷）：
  - `scope = self`，`duration_mode = turns`，`duration = 4`，`decrement_on = turn_end`。
  - `stacking = stack`，`max_stacks = 3`。
  - `trigger_names = ["turn_start"]`：每层在每个 `turn_start` 各结算一次。
  - payload：`resource_mod(resource_key = mp, amount = 5)` —— 每层每回合开始回 5 MP。
  - `persists_on_switch = false`：自己换下清掉。

**用途**：低消耗自身蓄力。叠 3 层后每回合回蓝 = 基础 10 + 3 层 × 5 = 25。鹿紫云的资源节奏全靠它。

#### 回授电击（Feedback Strike）

| 字段 | 值 |
|---|---|
| 技能 ID | `kashimo_feedback_strike` |
| 显示名 | 回授电击 |
| `damage_kind` | `special` |
| `combat_type_id` | `thunder` |
| `power` | `30`（基础威力） |
| `accuracy` | `100` |
| `mp_cost` | `15` |
| `priority` | `0` |
| `power_bonus_source` | `effect_stack_sum` |
| `power_bonus_self_effect_ids` | `kashimo_positive_charge_mark` |
| `power_bonus_target_effect_ids` | `kashimo_negative_charge_mark` |
| `power_bonus_per_stack` | `+12` |
| `targeting` | `enemy_active_slot` |
| `effects_on_hit_ids` | `kashimo_consume_positive_charges`、`kashimo_consume_negative_charges` |

**威力公式**：`30 + 12 × (自身正电荷层数 + 目标负电荷层数)`。

| 总层数 | 威力 |
|---|---|
| 0 层 | `30` |
| 2 层 | `54` |
| 4 层 | `78` |
| 6 层（满，3+3） | `102` |

**命中后清空双方电荷**：
- `kashimo_consume_positive_charges`：自身 `remove_effect(kashimo_positive_charge_mark, remove_mode = "all")`。
- `kashimo_consume_negative_charges`：目标 `remove_effect(kashimo_negative_charge_mark, remove_mode = "all")`。

**用途**：把双方累积的电荷一次拉爆。爆发完两边电荷归零，再重新积累。

#### 弥虚葛笼（Kyokyo Katsura）

| 字段 | 值 |
|---|---|
| 技能 ID | `kashimo_kyokyo_katsura` |
| 显示名 | 弥虚葛笼 |
| `damage_kind` | `none` |
| `combat_type_id` | `""` |
| `power` | `0` |
| `accuracy` | `100` |
| `mp_cost` | `20` |
| `priority` | `+2` |
| `targeting` | `self` |
| `effects_on_cast_ids` | `kashimo_kyokyo_nullify` |

**`kashimo_kyokyo_nullify`**：
- `scope = self`，`duration_mode = turns`，`duration = 3`，`decrement_on = turn_end`。
- payload：`rule_mod(mod_kind = nullify_field_accuracy, mod_op = set, value = true, scope = self, duration_mode = turns, duration = 3, decrement_on = turn_end, stacking = refresh, priority = 10)`。
- 效果：3 回合内忽略对手领域附加的"必中"，但**不影响**技能原本写死的 `accuracy = 100`，也不影响领域其他效果（加伤、锁技、终爆）。
- 持续中再放一次：按 `stacking = refresh` 刷新回完整 3 回合。

**注意**：这是候选技能池里的；默认不装。需要赛前覆盖把它换进来（一般针对领域型对手时）。

**用途**：反领域工具。把 Gojo / Sukuna 领域里"必中"那一项削掉，让原本 95 命中的技能回到 95（可以 miss）。但不会拆掉对手的领域。

### C. 奥义详情：幻兽琥珀（Phantom Beast Amber）

| 字段 | 值 |
|---|---|
| 技能 ID | `kashimo_phantom_beast_amber` |
| 显示名 | 幻兽琥珀 |
| `damage_kind` | `special` |
| `combat_type_id` | `thunder` |
| `power` | `60` |
| `accuracy` | `100` |
| `mp_cost` | `35`（注意：比其他奥义低！） |
| `priority` | `+5`（绝对先手） |
| `is_domain_skill` | `false`（不是领域） |
| `once_per_battle` | `true`（**整场只能开一次**） |
| `targeting` | `enemy_active_slot` |
| `effects_on_cast_ids` | `kashimo_amber_self_transform` |

**奥义合法性**：`current_mp >= 35` 且 `ultimate_points >= 3` 且本场未开过琥珀。

**`kashimo_amber_self_transform`（在 `on_cast` 时执行）**：
- `scope = self`，`duration_mode = permanent`，`stacking = none`，`trigger_names = on_cast`。
- 5 个 payload 顺序执行：
  1. `stat_mod(attack, +2, retention_mode = persist_on_switch)`：攻击 `+2` 阶段（持久）。
  2. `stat_mod(sp_attack, +2, retention_mode = persist_on_switch)`：特攻 `+2` 阶段（持久）。
  3. `stat_mod(speed, +1, retention_mode = persist_on_switch)`：速度 `+1` 阶段（持久）。
  4. `apply_effect(kashimo_amber_bleed)`：挂自伤 effect。
  5. `rule_mod(mod_kind = action_legality, mod_op = deny, value = "ultimate", scope = self, duration_mode = permanent, decrement_on = turn_end, stacking = none, priority = 10, persists_on_switch = true)`：禁掉自己后续奥义（防止重开）。

**`kashimo_amber_bleed`（自毁）**：
- `scope = self`，`duration_mode = permanent`，`stacking = none`，`trigger_names = ["turn_end"]`。
- payload：`damage(amount = 20, use_formula = false, combat_type_id = "")` —— 每回合 `turn_end` 扣 20 HP（无属性，自残）。
- `persists_on_switch = true`：跨换人保留。

**自毁时序**（118 HP 起算）：

| 回合 | 回合末剩余 HP |
|---|---|
| 释放当回合 | 118 |
| 第 1 回合末 | 98 |
| 第 2 回合末 | 78 |
| 第 3 回合末 | 58 |
| 第 4 回合末 | 38 |
| 第 5 回合末 | 18 |
| 第 6 回合末 | 死亡（如果未在战斗中被治疗或换人） |

**核心特点**：
- **强化、自伤、奥义封锁全部 `persists_on_switch = true`**：换人不清。
- `persistent_stat_stages` 让攻 / 特攻 / 速度阶段也跨换人保留（普通 stat_stage 离场会清，琥珀的不会）。
- **同回合重上场暂停回合触发**：如果琥珀状态下被换下、又在同一回合中途重上场，那一回合里 `turn_end` 自伤会暂停；从下一整回合的 `turn_end` 起恢复。
- **整场一次**：`once_per_battle = true` + battle-scoped 使用记录。即使死亡复活（虽然当前不做复活）也无法二次开启。
- **on_cast 阶段就生效**：所以即使本次伤害 miss（但 `accuracy = 100` 必中所以不会 miss），强化和自伤也已经生效。

### D. 被动详情：电荷分离（Charge Separation）

| 字段 | 值 |
|---|---|
| 被动 ID | `kashimo_charge_separation` |
| 显示名 | 电荷分离 |
| `trigger_names` | `on_enter` |
| `effect_ids` | `kashimo_thunder_resist`、`kashimo_apply_water_leak_listeners` |

**两条 effect 同时挂上**：

#### 抗雷（kashimo_thunder_resist）

- `scope = self`，`duration_mode = permanent`，`stacking = none`，`trigger_names = on_enter`。
- payload：`rule_mod(mod_kind = incoming_action_final_mod, mod_op = mul, value = 0.5, scope = self, duration_mode = permanent, decrement_on = turn_end, stacking = none, priority = 10, required_incoming_command_types = ["skill", "ultimate"], required_incoming_combat_type_ids = ["thunder"])`。
- 效果：**雷属性**主动技 / 奥义命中鹿紫云时，本次最终伤害 ×0.5。
- 注意：这是角色个人减伤，不进全局克制表。其他雷属性单位不会自动获得这个特性。

#### 水属性导电（漏蓝 + 毒返）

- `kashimo_apply_water_leak_listeners`（`on_enter` 一次性挂上下面两条监听）：
  - `kashimo_water_leak_self_listener`：`scope = self`，`trigger_names = on_receive_action_hit`，过滤 `required_incoming_command_types = ["skill", "ultimate"]` + `required_incoming_combat_type_ids = ["water"]`。payload：`resource_mod(resource_key = mp, amount = -15)` —— 自身扣 15 MP。
  - `kashimo_water_leak_counter_listener`：`scope = action_actor`（即攻击者），同样过滤水属性主动来袭。payload：`damage(amount = 15, use_formula = false, combat_type_id = "poison")` —— 对攻击者打 1 次基础值 15 的毒属性固定伤害（吃毒属性克制）。

**触发条件汇总**：
- 仅对 `skill / ultimate`（不含默认动作、field、被动、持续伤害、effect 连锁伤害）触发。
- 来袭属性必须是 `water`。
- 即使该次命中已经把鹿紫云打死，反击也照样结算。

**`scope = action_actor`** 的 effect 只允许挂在 `on_receive_action_hit` 上；触发时它的"目标"是当前来袭行动的发起者（`chain_context.action_actor_id`）。

### E. 简述对局风格

鹿紫云是高速近战爆发型。靠雷拳给对手贴负电荷叠持续伤害、靠蓄电给自己叠正电荷攒蓝、看准时机用回授电击一次拉爆所有电荷（满层 102 威力雷属性特殊技）。打雷属性主动技敌人时被动减伤特别强，打水属性主动技敌人时反而会被抽蓝（但能毒返）。"幻兽琥珀"是终极赌注按钮——开了就攻 +2、特攻 +2、速度 +1，但每回合自损 20 HP，必须用快节奏推完。怕慢节奏（资源起不来 + 特防 54 也低），怕领域型对手把"必中"叠上来（虽然弥虚葛笼可以反制）。

---

## 宇智波带土·十尾人柱力（Obito Juubi Jinchuriki）

### A. 基本数据

| 项 | 值 |
|---|---|
| 单位 ID | `obito_juubi_jinchuriki` |
| 显示名 | 宇智波带土·十尾人柱力 |
| 战斗属性 | `light`（光）+ `dark`（暗） |
| HP | `128`（当前正式四角色最高） |
| 攻击 | `58` |
| 防御 | `78` |
| 特攻 | `88` |
| 特防 | `80` |
| 速度 | `64` |
| BST（六维） | `496`（当前正式四角色最高） |
| `max_mp` | `100` |
| `init_mp` | `48` |
| `regen_per_turn` | `12` |
| `ultimate_points_required` | `3` |
| `ultimate_points_cap` | `3` |
| `ultimate_point_gain_on_regular_skill_cast` | `+1` |
| 奥义 | 十尾尾兽玉（`obito_shiwei_weishouyu`） |
| 被动技能 | 仙人之力（`obito_xianren_zhili`） |
| 被动持有物 | 无 |
| 默认装配技能 `skill_ids` | `obito_qiudao_jiaotu`、`obito_yinyang_dun`、`obito_qiudao_yu` |
| 候选技能池 `candidate_skill_ids` | `obito_qiudao_jiaotu`、`obito_yinyang_dun`、`obito_qiudao_yu`、`obito_liudao_shizi_fenghuo` |

### B. 技能详情

#### 求道焦土（Qiudao Jiaotu）

| 字段 | 值 |
|---|---|
| 技能 ID | `obito_qiudao_jiaotu` |
| 显示名 | 求道焦土 |
| `damage_kind` | `special` |
| `combat_type_id` | `dark` |
| `power` | `42` |
| `accuracy` | `100` |
| `mp_cost` | `10` |
| `priority` | `0` |
| `targeting` | `enemy_active_slot` |
| `effects_on_hit_ids` | `obito_qiudao_jiaotu_heal_block_apply`、`obito_qiudao_jiaotu_heal_block_rule_mod` |

**命中后挂禁疗双 effect**：
- `obito_qiudao_jiaotu_heal_block_apply`：对目标 `apply_effect(obito_qiudao_jiaotu_heal_block_mark)`。
  - `obito_qiudao_jiaotu_heal_block_mark`：`scope = self`，`duration_mode = turns`，`duration = 2`，`decrement_on = turn_end`，`stacking = refresh`，`persists_on_switch = true`。这是"公开禁疗标记"，本身没有 payload，纯标记。
- `obito_qiudao_jiaotu_heal_block_rule_mod`：对目标挂 rule_mod。
  - 内部 payload：`rule_mod(mod_kind = incoming_heal_final_mod, mod_op = set, value = 0.0, scope = target, duration_mode = turns, duration = 2, decrement_on = turn_end, stacking = refresh, priority = 10, persists_on_switch = true)`。
  - 效果：目标在 2 个 `turn_end` 内收到的所有治疗最终倍率 = `0`（治疗失效）。
  - `persists_on_switch = true`：换人不清；但只阻断 HP 治疗，不影响 MP 回复。

**用途**：稳定压血技 + 禁疗入口。打反转术式 / 仙人之力 / 治疗类对手时，能让对方 2 回合内疗效归零。

#### 阴阳遁（Yinyang Dun）

| 字段 | 值 |
|---|---|
| 技能 ID | `obito_yinyang_dun` |
| 显示名 | 阴阳遁 |
| `damage_kind` | `none` |
| `combat_type_id` | `""` |
| `power` | `0` |
| `accuracy` | `100` |
| `mp_cost` | `16` |
| `priority` | `+2` |
| `targeting` | `self` |
| `effects_on_cast_ids` | `obito_yinyang_dun_boost_and_charge`、`obito_yinyang_dun_guard_rule_mod`、`obito_yinyang_dun_guard_stack_listener` |

**3 个 effect 顺序执行**：

1. **`obito_yinyang_dun_boost_and_charge`**（`on_cast` 触发，`scope = self`）：
   - `apply_effect(obito_yinyang_zhili)`：自己叠 1 层"阴阳之力"。
   - `stat_mod(defense, +1, retention_mode = normal)`：防御 `+1` 阶段（非持久，离场清）。
   - `stat_mod(sp_defense, +1, retention_mode = normal)`：特防 `+1` 阶段。

2. **`obito_yinyang_dun_guard_rule_mod`**（`on_cast` 触发，`scope = self`，持续 1 次 `turn_end`）：
   - payload：`rule_mod(mod_kind = incoming_action_final_mod, mod_op = mul, value = 0.5, scope = self, duration_mode = turns, duration = 1, decrement_on = turn_end, stacking = refresh, priority = 10, required_incoming_command_types = ["skill", "ultimate"])`。
   - 效果：本回合内，敌方 `skill / ultimate` 来袭的每段最终伤害 ×0.5。

3. **`obito_yinyang_dun_guard_stack_listener`**（`on_cast` 触发，`scope = self`）：
   - payload：`apply_effect(obito_yinyang_dun_guard_stack_listener_state)`。
   - **`obito_yinyang_dun_guard_stack_listener_state`**：`scope = self`，`duration_mode = turns`，`duration = 1`，`decrement_on = turn_end`，`trigger_names = on_receive_action_damage_segment`，过滤 `required_incoming_command_types = ["skill", "ultimate"]`。payload：`apply_effect(obito_yinyang_zhili)`。
   - 效果：本回合每承受 1 段敌方 `skill / ultimate` 直接伤害，再补 1 层阴阳之力。

**`obito_yinyang_zhili`（阴阳之力，被叠的目标）**：
- `scope = self`，`duration_mode = permanent`，`stacking = stack`，`max_stacks = 5`，`persists_on_switch = false`。
- 本身没有 payload，纯标记，给「求道玉」威力加成 + 处决条件用。
- 离场清空。

**满层后**：阴阳之力到 5 层就不再加。但本回合的双防 +1 和减伤 ×0.5 仍正常生效。

**用途**：高优先级（`+2`）防反站场技。叠"阴阳之力"层数（最多 5 层）+ 拉双防 +1 + 一回合减伤 +1 + 被打后逐段补层。

#### 求道玉（Qiudao Yu）

| 字段 | 值 |
|---|---|
| 技能 ID | `obito_qiudao_yu` |
| 显示名 | 求道玉 |
| `damage_kind` | `special` |
| `combat_type_id` | `light` |
| `power` | `24`（基础威力） |
| `accuracy` | `100` |
| `mp_cost` | `18` |
| `priority` | `0` |
| `power_bonus_source` | `effect_stack_sum` |
| `power_bonus_self_effect_ids` | `obito_yinyang_zhili` |
| `power_bonus_per_stack` | `+12` |
| `execute_target_hp_ratio_lte` | `0.3` |
| `execute_required_total_stacks` | `5` |
| `execute_self_effect_ids` | `obito_yinyang_zhili` |
| `targeting` | `enemy_active_slot` |
| `effects_on_hit_ids` | `obito_qiudao_yu_clear_yinyang` |
| `effects_on_miss_ids` | `obito_qiudao_yu_clear_yinyang` |

**威力公式**：`24 + 12 × 自身阴阳之力层数`。

| 层数 | 威力 |
|---|---|
| 0 层 | `24` |
| 1 层 | `36` |
| 2 层 | `48` |
| 3 层 | `60` |
| 4 层 | `72` |
| 5 层 | `84` |

**处决（`execute_*`）**：
- 满足 `target.hp / target.max_hp <= 0.3` 且自身阴阳之力 `>= 5` 层时，命中后、常规伤害前直接处决（写 `[execute]` 日志），目标 HP 直接置 0。
- 处决成功后**不再走常规公式伤害**。

**清层**：
- `obito_qiudao_yu_clear_yinyang`：`scope = self`，`trigger_names = on_hit, on_miss`。payload：`remove_effect(obito_yinyang_zhili, remove_mode = "all")`。
- 命中和 miss 都清空全部阴阳之力层数。

**用途**：主收头技。攒满 5 层后基础威力 84 已经很疼；目标残血时可以直接处决。但注意：用一次就清光所有层，要慎用。

#### 六道十字奉火（Liudao Shizi Fenghuo）

| 字段 | 值 |
|---|---|
| 技能 ID | `obito_liudao_shizi_fenghuo` |
| 显示名 | 六道十字奉火 |
| `damage_kind` | `special` |
| `combat_type_id` | `fire` |
| `power` | `62` |
| `accuracy` | `90` |
| `mp_cost` | `24` |
| `priority` | `-1` |
| `targeting` | `enemy_active_slot` |
| 命中后效果 | 无 |

**用途**：候选位的纯火系重炮。不带额外效果，纯粹换装专用。打火属性弱点（如宿傩 fire / demon 中的 demon 不被火克但 fire 中立、只对木 / 冰 / 钢 / 毒 翻倍）的对手时换上。

**注意**：默认不装。需要赛前覆盖换进来。

### C. 奥义详情：十尾尾兽玉（Shiwei Weishouyu）

| 字段 | 值 |
|---|---|
| 技能 ID | `obito_shiwei_weishouyu` |
| 显示名 | 十尾尾兽玉 |
| `damage_kind` | `special` |
| `combat_type_id` | `""`（顶层无属性，分段内才有） |
| `power` | `0`（顶层无伤害） |
| `accuracy` | `100`（必中） |
| `mp_cost` | `50` |
| `priority` | `+5`（绝对先手） |
| `targeting` | `enemy_active_slot` |
| `damage_segments` | 见下 |

**`damage_segments` 配置**（**总 10 段**）：

| 段编号 | repeat_count | power | combat_type | damage_kind |
|---|---|---|---|---|
| 段 1（暗段） | `2` | `12` | `dark` | `special` |
| 段 2（光段） | `8` | `12` | `light` | `special` |

也就是连续打 2 次暗属性 12 威力 + 8 次光属性 12 威力，共 10 段。

**奥义合法性**：`current_mp >= 50` 且 `ultimate_points >= 3`。

**关键规则**：
- 整招命中判定只有 1 次。`accuracy = 100` 必中，命中后展开 10 段。
- 每段独立结算：独立查属性克制（`dark` 段查目标对暗的反应，`light` 段查目标对光的反应）；独立读 `incoming_action_final_mod`；独立写日志（带 `payload_summary: segment i/n`）。
- 中途目标倒下后续段立即停止。
- 每段成功结算后派发 `on_receive_action_damage_segment` 触发点（带 `chain_context.action_segment_index / action_segment_total / action_combat_type_id`）。

**总威力估算**（中立打：`type_effectiveness = 1.0`，无 final_mod）：
- 假设带土特攻 `88`（无修饰），目标特防 `60`：
- 每段 `base_damage = floor(floor(22 × 12 × 88 / 60) / 50) + 2 = floor(floor(23232 / 60) / 50) + 2 = floor(floor(387.2) / 50) + 2 = floor(387 / 50) + 2 = floor(7.74) + 2 = 7 + 2 = 9`。
- 10 段总伤害 ≈ 90 点（每段 9）。这是"中立 + 无加成"的最低值；如果光段或暗段命中弱点，会逐段乘 ×2。
- 例：打恶魔属性目标（demon）：light → demon = 2.0，所以 8 段光段乘 2 → 8 段每段 18，2 段暗段每段 9 → 总 = `18 × 8 + 9 × 2 = 144 + 18 = 162`。

### D. 被动详情：仙人之力（Xianren Zhili）

| 字段 | 值 |
|---|---|
| 被动 ID | `obito_xianren_zhili` |
| 显示名 | 仙人之力 |
| `trigger_names` | `turn_start` |
| `effect_ids` | `obito_xianren_zhili_heal` |

**`obito_xianren_zhili_heal`**：
- `scope = self`，`duration_mode = permanent`，`stacking = none`，`trigger_names = turn_start`。
- payload：`heal(use_percent = true, percent = 10, percent_base = "missing_hp")`。

**实际效果**：
- 每回合 `turn_start` 时，按"已损生命值"（`max_hp - current_hp`）的 `10%` 回血。
- 满血时 `missing_hp = 0`，不回。
- 缺血时按缺失向下取整；只要 `missing_hp > 0`，最少回 `1`。
- 例：HP 从 128 掉到 28（损 100）→ 回 `floor(100 × 0.1) = 10`。
- 例：HP 从 128 掉到 78（损 50）→ 回 `floor(50 × 0.1) = 5`。
- 例：HP 从 128 掉到 8（损 120）→ 回 `floor(120 × 0.1) = 12`。

**注意**：被「求道焦土」禁疗的目标如果是带土自己（被对手叠过禁疗），仙人之力的 heal 会被 `incoming_heal_final_mod = 0` 直接归零（带土被禁疗就不能自回）。

### E. 简述对局风格

带土是肉盾叠层处决型。最厚的 HP（128）+ 最高的 BST（496）+ 双防都不低，靠"阴阳遁"高优先级蓄力 + 防反逐段补层 + 双防 +1 + 减伤 ×0.5；用"求道焦土"压血并禁疗 2 回合；攒满 5 层"阴阳之力"后用"求道玉"打 84 威力光属性收头，残血时直接处决。「十尾尾兽玉」是 50 MP 必中的 10 段终爆。怕领域速攻型对手抢先开领域锁住自己的"阴阳遁"窗口，怕被快速秒杀（速度 64 排在最后，几乎所有人都先动），怕没法叠层的时候只剩单纯压血。换装六道十字奉火可以打火属性中立威力，但牺牲处决线。

---

# 总结

读到这里，你应该可以：

1. 看懂战斗界面里那些"HP / MP / 奥义点"显示。
2. 知道为什么有些技能是"绝对先手"，知道行动队列的排序原则。
3. 估算自己出招的伤害（用 §4.2 那个公式套）。
4. 看懂角色技能描述里"挂标记 / 累积层数 / 领域 / 必中"是什么意思。
5. 了解四个正式角色各自的玩法节奏：
   - 五条悟：高速 + 双标记爆发 + 必中锁人领域。
   - 宿傩：稳压 + 灶滚动 + 双攻领域 + 终爆。
   - 鹿紫云：高速电荷主循环 + 一次性琥珀大招。
   - 带土：肉盾叠层 + 满层处决 + 10 段奥义。

祝你打得开心。
