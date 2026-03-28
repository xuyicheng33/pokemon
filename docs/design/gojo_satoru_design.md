# 五条悟（Gojo Satoru）完整设计方案

## 1. 角色基础属性

### 1.1 UnitDefinition

| 字段 | 值 | 说明 |
|------|-----|------|
| id | `gojo_satoru` | |
| display_name | `五条悟` | |
| combat_type_ids | `["space", "psychic"]` | 空间 + 超能力 |
| base_hp | **120** | 中等偏上，但低于宿傩(126) |
| base_attack | **58** | 最低项，非体术型 |
| base_defense | **56** | 低防御，玻璃炮 |
| base_sp_attack | **90** | 最高项，术式输出型 |
| base_sp_defense | **66** | 中等，精神韧性 |
| base_speed | **88** | 第二高项，速度型定位 |
| **BST** | **478** | 略低于宿傩(486)，靠 MP 效率弥补 |

### 1.2 MP 系统

| 字段 | 值 | 宿傩对照 | 说明 |
|------|-----|---------|------|
| max_mp | **100** | 100 | 持平 |
| init_mp | **55** | 45 | 更高初始咒力 |
| regen_per_turn | **16** | 12 | 面板回复稳定，续航依赖高初始 MP + 技能节奏 |

### 1.3 技能组

默认配招（regular_skill_ids, 3 个）：
1. `gojo_ao`（苍）
2. `gojo_aka`（赫）
3. `gojo_murasaki`（茈）

奥义（ultimate_skill_id）：
- `gojo_unlimited_void`（无量空处）

候选技能池（candidate_skill_ids, 4 个）：
- `gojo_ao`, `gojo_aka`, `gojo_murasaki`, `gojo_reverse_ritual`

赛前配招覆盖（regular_skill_loadout_overrides）：
- 允许将 `gojo_reverse_ritual`（反转术式）换入替换茈

### 1.4 被动

| 类型 | 值 | 说明 |
|------|-----|------|
| passive_skill_id | `gojo_mugen` | 无下限 |
| passive_item_id | `` | 不携带被动持有物 |

---

## 2. 技能详细设计

### 2.1 苍（Ao）

| 字段 | 值 |
|------|-----|
| id | `gojo_ao` |
| display_name | `苍` |
| damage_kind | `special` |
| power | **45** |
| accuracy | **95** |
| mp_cost | **14** |
| priority | **0** |
| combat_type_id | `space` |
| targeting | `enemy_active_slot` |
| effects_on_cast_ids | `[]` |
| effects_on_hit_ids | `["gojo_ao_speed_up", "gojo_ao_mark_apply"]` |
| effects_on_miss_ids | `[]` |

命中后效果：
- `gojo_ao_speed_up`：scope=self, stat_mod(speed, +1)
- `gojo_ao_mark_apply`：scope=target, apply_effect → `gojo_ao_mark`（纯标记，无 payload，duration=3 turns，stacking=refresh，decrement_on=turn_end）

### 2.2 赫（Aka）

| 字段 | 值 |
|------|-----|
| id | `gojo_aka` |
| display_name | `赫` |
| damage_kind | `special` |
| power | **45** |
| accuracy | **95** |
| mp_cost | **14** |
| priority | **0** |
| combat_type_id | `psychic` |
| targeting | `enemy_active_slot` |
| effects_on_cast_ids | `[]` |
| effects_on_hit_ids | `["gojo_aka_slow_down", "gojo_aka_mark_apply"]` |
| effects_on_miss_ids | `[]` |

命中后效果：
- `gojo_aka_slow_down`：scope=target, stat_mod(speed, -1)
- `gojo_aka_mark_apply`：scope=target, apply_effect → `gojo_aka_mark`（纯标记，无 payload，duration=3 turns，stacking=refresh，decrement_on=turn_end）

### 2.3 茈（Murasaki）—— 条件增幅技能

| 字段 | 值 |
|------|-----|
| id | `gojo_murasaki` |
| display_name | `茈` |
| damage_kind | `special` |
| power | **75** |
| accuracy | **85** |
| mp_cost | **28** |
| priority | **-1** |
| combat_type_id | `space` |
| targeting | `enemy_active_slot` |
| effects_on_cast_ids | `[]` |
| effects_pre_damage_ids | `["gojo_murasaki_conditional_boost"]` |
| effects_on_hit_ids | `["gojo_murasaki_conditional_cleanup"]` |
| effects_on_miss_ids | `[]` |

条件增幅效果（`gojo_murasaki_conditional_boost`）：
- **前置条件**：目标身上同时存在 `gojo_ao_mark` 和 `gojo_aka_mark`
- **条件满足时执行**：
  1. `chain_context.pre_damage_final_mul *= 2.0`（仅影响本次直伤，不写入 rule_mod）
  2. `chain_context.action_tags["murasaki_boost_applied"] = true`（供 on_hit 清理阶段复用）
- **条件不满足时**：不执行任何附加效果，茈仍造成基础伤害(power=75)

#### 茈的条件伤害实现方案

**核心问题**：effects_on_hit 在伤害计算**之后**执行，无法回溯修改已造成的伤害。

**解决方案：`effects_pre_damage_ids`（新增技能阶段）**

在 ActionExecutor 的执行流程中，在命中判定成功后、`apply_direct_damage` 之前，插入一个新的效果执行阶段：

```
现有流程:
  on_cast → 命中判定 → apply_direct_damage → on_hit

新流程:
  on_cast → 命中判定 → effects_pre_damage → apply_direct_damage → on_hit
```

`effects_pre_damage_ids` 中的效果在伤害计算前执行，写入“行动内伤害上下文（`pre_damage_final_mul/pre_damage_final_add`）”来影响本次伤害。

茈的 `effects_pre_damage_ids`:
- `gojo_murasaki_conditional_boost`：检查条件 → 满足时将本次伤害倍率改为 x2，并设置 `murasaki_boost_applied=true`

茈的 `effects_on_hit_ids`（伤害后执行）:
- `gojo_murasaki_conditional_cleanup`：读取 `murasaki_boost_applied`，为 true 时执行 remove_effect × 2（清除标记）+ 反噬伤害

**反噬伤害的实现**：引擎记录本次行动的实际直伤到 `chain_context.last_dealt_damage`，on_hit 阶段按 `50%` 计算自伤。

---

### 2.4 反转术式（Reverse Ritual）

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

效果：
- `gojo_reverse_heal`：scope=self, heal(use_percent=true, percent=25)

完全复用宿傩的反转术式设计模式。

### 2.5 无量空处（Unlimited Void）—— 奥义

| 字段 | 值 |
|------|-----|
| id | `gojo_unlimited_void` |
| display_name | `无量空処` |
| damage_kind | `special` |
| power | **60** |
| accuracy | **100** |
| mp_cost | **45** |
| priority | **+5** |
| combat_type_id | `space` |
| targeting | `enemy_active_slot` |
| effects_on_cast_ids | `["gojo_domain_cast_buff"]` |
| effects_on_hit_ids | `["gojo_apply_domain_field", "gojo_domain_action_lock"]` |

#### 领域展开机制

**FieldDefinition: `gojo_unlimited_void_field`**

| 字段 | 值 |
|------|-----|
| id | `gojo_unlimited_void_field` |
| display_name | `無量空処` |
| creator_accuracy_override | **100** |
| effect_ids | `[]` |
| on_expire_effect_ids | `["gojo_domain_expire_seal"]` |
| on_break_effect_ids | `["gojo_domain_rollback"]` |

**展开效果链**：

1. `gojo_domain_cast_buff`（on_cast, scope=self）：
   - stat_mod: sp_attack +1

2. `gojo_apply_domain_field`（on_hit, scope=field）：
   - apply_field: `gojo_unlimited_void_field`, duration=3, decrement_on=turn_end

3. `gojo_domain_action_lock`（on_hit, scope=target）：
   - **action_legality: deny, value="all"**, duration=1, decrement_on=turn_end
   - 效果：敌方当回合的已选指令被作废，且当回合无法行动

**action_lock 时序**：
```
T(展开): 五条悟先手(+5) → 展开领域 → 造成伤害 → action_lock 挂到敌方
         → 敌方行动检查 → action_legality deny all → 指令作废 → 强制 WAIT
T+1: 领域存在，五条悟术式必中，敌方正常行动
T+2: 领域存在，五条悟术式必中，敌方正常行动
T+2 turn_end: 领域过期 → on_expire 触发
```

**领域过期封印**（`gojo_domain_expire_seal`）：
- rule_mod: action_legality deny, value=`gojo_ao`, duration=2, decrement_on=turn_end
- rule_mod: action_legality deny, value=`gojo_aka`, duration=2, decrement_on=turn_end
- rule_mod: action_legality deny, value=`gojo_murasaki`, duration=2, decrement_on=turn_end
- 语义：在领域过期/打破触发时挂载，覆盖“下一回合选择 + 执行窗口”后于该回合 `turn_end` 清除（对玩家体感为封印 1 回合）

**领域被打破回滚**（`gojo_domain_rollback`）：
- 与过期封印相同的效果链（和宿傩的 domain_rollback 设计一致）

---

## 3. 被动技能：无下限（Mugen）

| 字段 | 值 |
|------|-----|
| id | `gojo_mugen` |
| display_name | `无下限` |
| trigger_names | `["on_before_damage"]` |
| effect_ids | `["gojo_mugen_damage_override"]` |

效果 `gojo_mugen_damage_override`：
- scope=self
- trigger_chance=0.3（每次受到伤害独立判定）
- damage_override: set_to=1（将本次即将受到的伤害改写为 1）

实际 MP 回复：**16/turn**（无额外被动回蓝）

---

## 4. 需要新增的引擎能力

### 4.1 `action_legality` —— 替代 `skill_legality`（规则文档 06 §5.2 扩展）

**Schema 变更**：

`content_schema.gd` 新增：
```gdscript
const RULE_MOD_ACTION_LEGALITY := "action_legality"
```

`rule_mod_payload.gd` 的 `mod_kind` 新增合法值：`"action_legality"`
- `mod_op`: `"deny"` / `"allow"`
- `value`: `"all"` / `"skill"` / `"switch"` / `"ultimate"` / 具体 skill_id

**迁移**：所有现有 `skill_legality` 的 .tres 文件和代码引用 → 重命名为 `action_legality`。语义完全兼容（`value=具体skill_id` 等价于原 skill_legality deny）。

**代码改动**：

| 文件 | 改动 |
|------|------|
| `content_schema.gd` | 新增 `RULE_MOD_ACTION_LEGALITY`，删除 `RULE_MOD_SKILL_LEGALITY` |
| `rule_mod_service.gd` | 重命名 `is_skill_allowed()` → `is_action_allowed()`，新增 switch/ultimate/all 判断 |
| `legal_action_service.gd` | 调用新接口，switch 合法性增加 action_legality 检查 |
| `content_snapshot_validator.gd` | 更新校验 |
| `content_payload_validator.gd` | 更新校验 |
| `docs/rules/06_effect_schema_and_extension.md` | 更新 §5.2 白名单 |
| 宿傩 `.tres` 文件(3个封印效果) | `skill_legality` → `action_legality` |
| 宿傩测试用例 | 同步更新 |

**`legal_action_service.gd` 新增逻辑**：

```gdscript
# 在 switch 合法性检查前增加
func _is_switch_allowed(battle_state, actor_id: String) -> bool:
    return rule_mod_service.is_action_allowed(battle_state, actor_id, "switch")

# 在 get_legal_actions 中
if _is_switch_allowed(battle_state, actor.unit_instance_id):
    # 现有 switch target 逻辑
```

**`rule_mod_service.gd` 新增逻辑**：

```gdscript
func is_action_allowed(battle_state, owner_id: String, action_type: String, skill_id: String = "") -> bool:
    # action_type: "skill", "switch", "ultimate", "all"
    # skill_id: 当 action_type="skill" 时传入具体 skill_id
    var allowed: bool = true
    var ordered_instances: Array = _sorted_active_instances_for_read(battle_state, owner_id)
    for rule_mod_instance in ordered_instances:
        if rule_mod_instance.mod_kind != RULE_MOD_ACTION_LEGALITY:
            continue
        var affects: bool = _does_action_legality_affect(rule_mod_instance.value, action_type, skill_id)
        if not affects:
            continue
        match rule_mod_instance.mod_op:
            "deny": allowed = false
            "allow": allowed = true
    return allowed

func _does_action_legality_affect(mod_value: String, action_type: String, skill_id: String) -> bool:
    if mod_value == "all":
        return true
    if mod_value == action_type:
        return true
    # 具体 skill_id 匹配
    if action_type == "skill" and not skill_id.is_empty() and mod_value == skill_id:
        return true
    # 空值 = 全局技能（向后兼容 skill_legality 的行为）
    if mod_value.is_empty() and (action_type == "skill" or action_type == "ultimate"):
        return true
    return false
```

**action_lock 作废已选指令**：在 `ActionExecutor._can_start_action` 中新增检查：

```gdscript
func _can_start_action(actor, command, battle_state) -> bool:
    if actor == null or actor.current_hp <= 0 or actor.leave_state != LeaveStatesScript.ACTIVE:
        return false
    # 新增：action_legality deny all 检查
    if not rule_mod_service.is_action_allowed(battle_state, actor.unit_instance_id, _command_to_action_type(command), command.skill_id if command.has("skill_id") else ""):
        return false
    var side_state = battle_state.get_side(command.side_id)
    return side_state != null and side_state.get_active_unit() != null and side_state.get_active_unit().unit_instance_id == actor.unit_instance_id
```

### 4.2 `effects_pre_damage_ids` —— 新增技能效果阶段

**Schema 变更**：

`skill_definition.gd` 新增：
```gdscript
@export var effects_pre_damage_ids: PackedStringArray = PackedStringArray()
```

`chain_context.gd` 新增（行动内临时上下文）：
```gdscript
var pre_damage_final_mul: float = 1.0
var pre_damage_final_add: float = 0.0
var action_tags: Dictionary = {}
```

**代码改动**：

| 文件 | 改动 |
|------|------|
| `skill_definition.gd` | 新增字段 |
| `action_executor.gd` | 在命中后、`apply_direct_damage` 前插入 `dispatch_skill_effects(effects_pre_damage_ids, "pre_damage", ...)` |
| `action_cast_service.gd` | 伤害计算读取 `pre_damage_final_mul/pre_damage_final_add`，仅影响本次直伤 |
| `chain_context.gd` | 新增行动内上下文字段 |
| `content_snapshot_validator.gd` | 新增校验 |
| `docs/rules/06_effect_schema_and_extension.md` | §4 新增 `pre_damage` 触发点，§10.1 新增字段说明 |

**`action_executor.gd` 改动位置**（约 L106-L114）：

```gdscript
    # 现有: log_action_hit
    var action_hit_cause_event_id: String = action_log_service.log_action_hit(...)

    # 新增: effects_pre_damage 阶段
    action_cast_service.dispatch_skill_effects(
        skill_definition.effects_pre_damage_ids if skill_definition != null else PackedStringArray(),
        "pre_damage",
        queued_action, actor, battle_state, content_index, result
    )
    if result.invalid_battle_code != null:
        return result

    # 现有: apply_direct_damage
    if action_cast_service.is_damage_action(command, skill_definition):
        action_cast_service.apply_direct_damage(...)
```

关键约束：
- `pre_damage` 只能改写“本次行动直伤上下文”，不能写入 `rule_mod`。
- `pre_damage` 上下文在每次 `execute_action` 开始时重置，行动结束即失效，不跨行动泄漏。

### 4.3 条件效果（`required_target_effects`）

**Schema 变更**：

`effect_definition.gd` 新增：
```gdscript
@export var required_target_effects: PackedStringArray = PackedStringArray()
```

当 `required_target_effects` 非空时，PayloadExecutor 在执行该效果前检查目标身上是否同时存在所列的所有效果实例（按 def_id 匹配）。不满足则跳过该效果。

**代码改动**：

| 文件 | 改动 |
|------|------|
| `effect_definition.gd` | 新增字段 |
| `payload_executor.gd` | `execute_effect_event` 前增加条件检查 |
| `content_snapshot_validator.gd` | 新增校验（引用的 effect_id 必须在内容索引中存在） |
| `docs/rules/06_effect_schema_and_extension.md` | §2 新增字段说明 |

**`payload_executor.gd` 改动逻辑**：

```gdscript
func _check_required_target_effects(effect_definition, target_unit) -> bool:
    if effect_definition.required_target_effects.is_empty():
        return true
    if target_unit == null:
        return false
    for required_def_id in effect_definition.required_target_effects:
        var found: bool = false
        for effect_instance in target_unit.effect_instances:
            if effect_instance.def_id == required_def_id:
                found = true
                break
        if not found:
            return false
    return true
```

建议用法：
- `gojo_murasaki_conditional_boost` 使用 `required_target_effects=["gojo_ao_mark", "gojo_aka_mark"]` 做前置判定。
- `gojo_murasaki_conditional_cleanup` 不再重复查目标标记，而是读取 `chain_context.action_tags["murasaki_boost_applied"]`，避免目标濒死/离场导致清理与反噬被跳过。

### 4.4 反噬伤害（`recoil_percent_of_dealt`）

**机制**：对施法者造成"本次实际伤害值 × 百分比"的自伤。

**Schema 变更**：

`chain_context.gd` 新增：
```gdscript
var last_dealt_damage: int = 0
```

`damage_payload.gd` 新增自伤模式，或新增一个专用 payload：

方案选择：在 `DamagePayload` 上新增 `recoil_percent_of_dealt` 字段更简洁：

```gdscript
# damage_payload.gd 新增
@export var recoil_percent_of_dealt: float = 0.0  # 0.0 表示不触发，0.5 表示 50%
@export var recoil_target: String = "self"         # 固定为 self
```

**代码改动**：

| 文件 | 改动 |
|------|------|
| `chain_context.gd` | 新增 `last_dealt_damage` |
| `action_executor.gd` | 每次 `execute_action` 开始先重置 `last_dealt_damage=0` |
| `action_cast_service.gd` | `apply_direct_damage` 扣血前确定最终伤害并写入 `chain_context.last_dealt_damage` |
| `payload_numeric_handler.gd` | 处理 `recoil_percent_of_dealt` payload |
| `content_payload_validator.gd` | 校验新字段 |

**时序约束**：
- `last_dealt_damage` 只记录“本次行动直伤最终值”（已包含属性克制、`pre_damage`、`on_before_damage`）。
- `effect damage` 不覆盖 `last_dealt_damage`，保证反噬读取稳定。

**`action_executor.gd` + `action_cast_service.gd` 改动要点**：

```gdscript
# execute_action 开始
battle_state.chain_context.last_dealt_damage = 0
battle_state.chain_context.pre_damage_final_mul = 1.0
battle_state.chain_context.pre_damage_final_add = 0.0
battle_state.chain_context.action_tags.clear()

# apply_direct_damage 内部（扣血前）
battle_state.chain_context.last_dealt_damage = damage_amount
```

### 4.5 概率触发（`trigger_chance`）+ 伤害拦截管道（`on_before_damage`）

**用于**：无下限被动——受到伤害时 30% 概率将伤害变为 1。

#### 4.5.1 trigger_chance

`effect_definition.gd` 新增：
```gdscript
@export var trigger_chance: float = 1.0  # 默认 100% 触发
```

`passive_skill_service.gd` 改动：在收集被动事件时读取每个 effect 的 `trigger_chance`，逐个 roll。roll 值 >= trigger_chance 则该 effect 不入队。

日志要求：`effect_roll` 必须包含 roll 值和阈值（例如 `0.27<0.30`），确保回放与调试可复现。

#### 4.5.2 伤害拦截管道

**新增触发点**：`on_before_damage`

时序位于 `apply_direct_damage` 内部，在伤害值计算完成后、实际扣 HP 前：

```
apply_direct_damage 内部:
  1. calc_base_damage → 基础伤害
  2. 属性克制倍率
  3. final_multiplier
  4. damage_amount 确定
  5. 【新增】trigger on_before_damage → 防御方被动可修改 damage_amount
  6. 扣 HP
```

**代码改动**：

| 文件 | 改动 |
|------|------|
| `effect_definition.gd` | 新增 `trigger_chance` 字段 |
| `passive_skill_service.gd` | 新增概率判定逻辑（按 effect 判定） |
| `action_cast_service.gd` | `apply_direct_damage` 中插入 `on_before_damage` hook |
| `effect_event.gd` | 新增概率判定元信息字段（roll/threshold） |
| `content_schema.gd` | 新增 trigger 常量 |
| `docs/rules/06_effect_schema_and_extension.md` | §4 新增 `on_before_damage` 触发点 |
| `docs/rules/03_stats_resources_and_damage.md` | §8.1 更新伤害流程步骤 |

**`action_cast_service.gd` 改动**（`apply_direct_damage` 内部）：

```gdscript
    # 现有: damage_amount 计算完成后
    var damage_amount: int = damage_service.apply_final_mod(...)

    # 新增: 伤害拦截
    damage_amount = _apply_before_damage_passives(target, damage_amount, battle_state, content_index)

    # 现有: 扣 HP
    var before_hp: int = target.current_hp
    target.current_hp = clamp(target.current_hp - damage_amount, 0, target.max_hp)
```

`_apply_before_damage_passives` 遍历目标的被动技能，检查是否有 `on_before_damage` 触发器。如果有且 roll 成功（30%），将 `damage_amount` 改为 1。

**无下限被动的 EffectDefinition**：
- 被动技能 `gojo_mugen` 的 trigger_names 包含 `on_before_damage`
- `gojo_mugen_damage_override.trigger_chance = 0.3`
- payload: `damage_override(override_value=1)`

**新增 payload 类型 `damage_override`**：
```gdscript
# damage_override_payload.gd
@export var override_value: int = 1  # 将伤害覆盖为此值
```

---

## 5. 完整资源文件清单

### 5.1 content/units/

| 文件 | 说明 |
|------|------|
| `gojo_satoru.tres` | UnitDefinition |

### 5.2 content/skills/ (5 个)

| 文件 | 说明 |
|------|------|
| `gojo_ao.tres` | 苍 |
| `gojo_aka.tres` | 赫 |
| `gojo_murasaki.tres` | 茈 |
| `gojo_reverse_ritual.tres` | 反转术式 |
| `gojo_unlimited_void.tres` | 无量空处 |

### 5.3 content/effects/ (约 15 个)

| 文件 | 说明 |
|------|------|
| `gojo_ao_speed_up.tres` | 苍命中 → self speed +1 |
| `gojo_ao_mark_apply.tres` | 苍命中 → target 挂苍标记 |
| `gojo_ao_mark.tres` | 苍标记(纯标记,无payload) |
| `gojo_aka_slow_down.tres` | 赫命中 → target speed -1 |
| `gojo_aka_mark_apply.tres` | 赫命中 → target 挂赫标记 |
| `gojo_aka_mark.tres` | 赫标记(纯标记,无payload) |
| `gojo_murasaki_conditional_boost.tres` | 茈 pre_damage 条件倍率 |
| `gojo_murasaki_conditional_cleanup.tres` | 茈 on_hit 条件清理+反噬 |
| `gojo_reverse_heal.tres` | 反转术式回复 |
| `gojo_domain_cast_buff.tres` | 领域展开自身 buff |
| `gojo_apply_domain_field.tres` | 展开领域 field |
| `gojo_domain_action_lock.tres` | 当回合敌方 action_lock |
| `gojo_domain_expire_seal.tres` | 领域过期封印(苍赫茈) |
| `gojo_domain_rollback.tres` | 领域被打破封印 |
| `gojo_mugen_damage_override.tres` | 无下限：伤害覆盖为 1 |

### 5.4 content/fields/ (1 个)

| 文件 | 说明 |
|------|------|
| `gojo_unlimited_void.tres` | 无量空处领域 |

### 5.5 content/passive_skills/ (1 个)

| 文件 | 说明 |
|------|------|
| `gojo_mugen.tres` | 无下限 |

### 5.6 content/combat_types/ (2 个，如果不存在)

| 文件 | 说明 |
|------|------|
| `space.tres` | 空间属性（检查是否已存在） |
| `psychic.tres` | 超能力属性（检查是否已存在） |

---

## 6. 引擎改动汇总

### 6.1 新增文件

| 文件 | 说明 |
|------|------|
| `src/battle_core/content/damage_override_payload.gd` | 伤害覆盖 payload |

### 6.2 修改文件

| 文件 | 改动类型 | 说明 |
|------|---------|------|
| **content_schema.gd** | 新增常量 | `RULE_MOD_ACTION_LEGALITY`, 删除 `RULE_MOD_SKILL_LEGALITY` |
| **rule_mod_service.gd** | 重构 | `is_skill_allowed` → `is_action_allowed`，新增 switch/all 逻辑 |
| **legal_action_service.gd** | 新增 | switch 合法性检查增加 action_legality |
| **action_executor.gd** | 新增 | `_can_start_action` 增加 action_legality 检查；`effects_pre_damage` 阶段 |
| **action_cast_service.gd** | 新增 | `apply_direct_damage` 中记录 `last_dealt_damage`；插入 `on_before_damage` hook |
| **skill_definition.gd** | 新增字段 | `effects_pre_damage_ids` |
| **effect_definition.gd** | 新增字段 | `required_target_effects`, `trigger_chance` |
| **chain_context.gd** | 新增字段 | `last_dealt_damage`, `pre_damage_final_mul`, `pre_damage_final_add`, `action_tags` |
| **payload_executor.gd** | 新增 | 条件检查 + damage_override handler |
| **payload_numeric_handler.gd** | 新增 | recoil_percent_of_dealt 处理 |
| **passive_skill_service.gd** | 新增 | 按 effect 的概率判定逻辑 |
| **effect_event.gd** | 新增字段 | 概率判定元信息（roll/threshold） |
| **content_snapshot_validator.gd** | 更新 | 新字段校验 |
| **content_payload_validator.gd** | 更新 | 新 payload/mod_kind 校验 |
| **composition/battle_core_composer.gd** | 更新 | 新依赖注入 |

### 6.3 宿傩迁移

| 文件 | 改动 |
|------|------|
| `content/effects/sukuna_domain_expire_seal.tres` | `skill_legality` → `action_legality` |
| `content/effects/sukuna_domain_rollback.tres` | 同上 |
| `tests/suites/sukuna_suite.gd` | 更新引用 |

### 6.4 文档更新

| 文件 | 改动 |
|------|------|
| `docs/rules/06_effect_schema_and_extension.md` | §4 新增 `pre_damage`, `on_before_damage`；§5.2 action_legality 替代 skill_legality |
| `docs/rules/03_stats_resources_and_damage.md` | §8.1 伤害流程新增拦截步骤 |
| `README.md` | 更新代码行数、角色列表、新机制说明 |
| `docs/records/decisions.md` | 记录设计决策 |

### 6.5 sample_battle_format.tres 更新

`combat_type_chart` 中确认 `space` 和 `psychic` 的克制关系已存在（如果缺失需补充）。

---

## 7. 测试计划

新增 `tests/suites/gojo_suite.gd`，测试用例：

| 编号 | 用例 | 验证点 |
|------|------|--------|
| 1 | 默认配招契约 | regular_skill_ids = [ao, aka, murasaki] |
| 2 | 苍命中后自身加速 | speed stage +1 |
| 3 | 苍命中后挂苍标记 | 目标有 gojo_ao_mark |
| 4 | 赫命中后敌方减速 | 目标 speed stage -1 |
| 5 | 赫命中后挂赫标记 | 目标有 gojo_aka_mark |
| 6 | 茈基础伤害（无标记） | 正常伤害，无倍率 |
| 7 | 茈条件增幅（双标记） | 伤害翻倍 + 标记消耗 + 反噬自伤 |
| 8 | 茈条件不满足（只有一个标记） | 基础伤害，标记保留 |
| 9 | 反转术式回复 | heal 25% max_hp |
| 10 | 基础 MP 回复 | regen = 16 |
| 11 | 无量空处展开 → 当回合敌方无法行动 | action_lock 生效 |
| 12 | 无量空处领域内必中 | accuracy override |
| 13 | 无量空处领域过期 → 封印苍赫茈 1 回合 | action_legality deny |
| 14 | 无量空处领域被打破 → 封印回滚 | 同上 |
| 15 | 无下限触发（概率固定 seed 测试） | 伤害变为 1 |
| 16 | 无下限未触发 | 正常伤害 |
| 17 | action_legality deny all → switch 被禁止 | 换人不可用 |
| 18 | action_legality deny all → 所有技能被禁止 | forced WAIT |

---

## 8. 平衡性分析

### 五条悟 vs 宿傩 对比

| 维度 | 五条悟 | 宿傩 |
|------|--------|------|
| BST | 478 | 486 |
| 优势属性 | 速度(88)、特攻(90) | HP(126)、特攻(84) |
| MP 效率 | 16/turn（稳定） | 12~22/turn (动态被动) |
| 爆发节奏 | 苍+赫铺垫 → 茈双倍(但有反噬) | 开(灶标记堆叠) → 领域爆炸 |
| 领域效果 | 1 回合 action_lock + 2 回合必中 | 3 回合必中 |
| 领域代价 | 封印 1 回合（配置为 duration=2, turn_end 扣减） | 封印 1 回合 |
| 生存能力 | 低(HP120/DEF56) + 无下限概率保命 | 高(HP126/DEF62) + 被动动态回蓝 |
| 配招灵活性 | 反转术式可换入 | 反转术式可换入 |

**设计差异化**：
- 宿傩是**耐久型高压输出**：HP 厚、被动按对位回蓝、灶标记缓慢叠加
- 五条悟是**速度型爆发**：先手拉开速度差、苍赫铺垫茈双倍、但茈有反噬代价、领域更暴力(action_lock)但更短
