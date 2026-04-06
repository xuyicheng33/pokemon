# 宇智波带土（十尾人柱力）正式角色设计稿
<!-- anchor:obito.design.incoming-heal-final-mod -->
<!-- anchor:obito.design.damage-segments -->
<!-- anchor:obito.design.execute-target-hp-ratio -->
<!-- anchor:obito.design.on-receive-damage-segment -->
<!-- anchor:obito.design.enemy-skill-ultimate-filter -->

本稿按 `docs/design/formal_character_design_template.md` 收口，只保留带土自己的资源定义、角色机制、验收矩阵与平衡备注。共享引擎规则统一引用公共文档，不在本稿重复展开。

## 0. 冻结结论

|项|冻结结论|
|---|---|
|角色定位|防反叠层型，中后期终结手|
|被动主轴|`仙人之力` 在 `turn_start` 按已损生命值 `10%` 回复|
|核心技能主轴|`阴阳遁 -> 阴阳之力 -> 求道玉`|
|禁疗入口|`求道焦土` 命中后挂公开禁疗标记；实现上沿用共享禁疗 mod（`incoming_heal_final_mod`）|
<!-- anchor:obito.design.incoming-heal-final-mod -->
|奥义主轴|`十尾尾兽玉` 走固定十段爆发；实现上用 `damage_segments` 固定为 `2 dark + 8 light`|
<!-- anchor:obito.design.damage-segments -->
|处决口径|`求道玉` 满层后具备斩杀线；实现上固定为 `execute_target_hp_ratio_lte = 0.3` + `5` 层阴阳之力|
<!-- anchor:obito.design.execute-target-hp-ratio -->
|奥义点配置|`3 / 3 / 常规技 +1`|
|当前平衡结论|首版正式接入，只冻结语义与交付面，不做平衡回调|
|明确不做|不新增 field；不新增新属性；不改 `on_receive_action_hit` 旧语义|

## 0.1 角色稿范围

- 本稿只写带土自己的资源定义、角色机制、验收矩阵与平衡备注。
- 共享 schema、effect / rule_mod 读写路径、manager envelope、bench 生命周期统一引用公共文档。

## 1. 角色定位与资源定义

### 1.1 角色定位

- 面向玩家：中速偏慢、当前正式角色里最厚的一名，通过 `阴阳遁` 站场并滚出收头线。
- 面向实现：只引用共享能力入口，不新增带土专用 runtime 分支；共享 schema 与排序细节统一回到公共规则文档。

### 1.2 UnitDefinition

|字段|值|说明|
|---|---|---|
| id | `obito_juubi_jinchuriki` | 正式角色唯一 ID |
| display_name | `宇智波带土·十尾人柱力` | 对外显示名 |
| combat_type_ids | `["light", "dark"]` | 双属性本体 |
| base_hp | `128` | 当前正式角色里最肉的身板 |
| base_attack | `58` | 非物攻主轴 |
| base_defense | `78` | 防反站场 |
| base_sp_attack | `88` | 爆发收头主轴 |
| base_sp_defense | `80` | 特耐同样偏厚 |
| base_speed | `64` | 中速偏慢 |

### 1.3 MP / 奥义点系统

|字段|值|说明|
|---|---|---|
| max_mp | `100` | 固定 100 |
| init_mp | `48` | 首回合可开核心技 |
| regen_per_turn | `12` | 中速滚资源 |
| ultimate_points_required | `3` | 奥义需要 3 点 |
| ultimate_points_cap | `3` | 上限 3 点 |
| ultimate_point_gain_on_regular_skill_cast | `1` | 常规技每次 +1 |

### 1.4 技能组与赛前装配

- 默认配招（`skill_ids`）：
  - `obito_qiudao_jiaotu`
  - `obito_yinyang_dun`
  - `obito_qiudao_yu`
- 候选池（`candidate_skill_ids`）：
  - `obito_qiudao_jiaotu`
  - `obito_yinyang_dun`
  - `obito_qiudao_yu`
  - `obito_liudao_shizi_fenghuo`
- 奥义（`ultimate_skill_id`）：
  - `obito_shiwei_weishouyu`
- 被动（`passive_skill_id`）：
  - `obito_xianren_zhili`
- 持有物（`passive_item_id`）：
  - 空
- 本场装配走 `SideSetup.regular_skill_loadout_overrides`；`六道十字奉火` 只通过赛前换装进入战斗。

## 2. 角色特有机制

### 2.1 仙人之力

|字段|值|
|---|---|
| passive_skill_id | `obito_xianren_zhili` |
| trigger_names | `["turn_start"]` |
| effect_ids | `["obito_xianren_zhili_heal"]` |

- 玩家说明：每回合开始时，带土会按当前已损生命值回复生命。
- 机制说明：`obito_xianren_zhili_heal` 固定使用 `heal(use_percent=true, percent=10, percent_base=missing_hp)`。
- 共享能力引用：沿用当前共享实现口径，只要 `missing_hp > 0`，百分比治疗至少回复 `1`。
- 验收点：满血不回复；缺血时按缺失血量向下取整；公开快照不额外隐藏。

### 2.2 阴阳之力

|字段|值|
|---|---|
| effect_id | `obito_yinyang_zhili` |
| scope | `self` |
| stacking | `stack` |
| max_stacks | `5` |
| persists_on_switch | `false` |

- 玩家说明：带土在场内通过防反和技能滚层，离场清空。
- 机制说明：该资源是公开 stack effect，不单独新增私有资源条。
- 验收点：最多 `5` 层；换人或死亡后清空；`求道玉` 命中或 miss 都清空全部层数。

### 2.3 求道焦土

|字段|值|
|---|---|
| id | `obito_qiudao_jiaotu` |
| damage_kind | `special` |
| combat_type_id | `dark` |
| power | `42` |
| accuracy | `100` |
| mp_cost | `10` |
| priority | `0` |

- 玩家说明：稳定压血技，也是带土的禁疗入口。
- 机制说明：
  - 命中后先通过内部 apply wrapper 给目标挂公开标记 `obito_qiudao_jiaotu_heal_block_mark`
  - 同时施加 `obito_qiudao_jiaotu_heal_block_rule_mod`
  - 这条 rule mod 固定写 `incoming_heal_final_mod = set 0`
- 公开语义：
  - 禁疗标记持续 `2` 回合
  - `decrement_on = turn_end`
  - `persists_on_switch = true`
  - 换人不清，只阻断 HP 治疗，不影响 MP 回复
- 验收点：公开标记与 `incoming_heal_final_mod` 生命周期必须一致。

### 2.4 阴阳遁

|字段|值|
|---|---|
| id | `obito_yinyang_dun` |
| damage_kind | `none` |
| targeting | `self` |
| mp_cost | `16` |
| priority | `2` |

- 玩家说明：自身叠一层阴阳之力，提升双防，并进入本回合防反态。
- 机制说明：
  - `obito_yinyang_dun_boost_and_charge` 在 `on_cast` 时：
    - `apply_effect(obito_yinyang_zhili)`
    - `stat_mod(defense, +1)`
    - `stat_mod(sp_defense, +1)`
  - `obito_yinyang_dun_guard_rule_mod` 在本回合内对后续敌方 `skill / ultimate` 的每段最终伤害乘 `0.5`
  <!-- anchor:obito.design.enemy-skill-ultimate-filter -->
  - `obito_yinyang_dun_guard_stack_listener` 监听 `on_receive_action_damage_segment`，并与减伤 rule mod 复用同一组过滤条件：只响应敌方 `skill / ultimate` 的成功直接伤害段；命中后每承受 1 段再补 1 层阴阳之力
  <!-- anchor:obito.design.on-receive-damage-segment -->
- 边界：
  - 满 `5` 层后不再继续加层
  - 但双防提升和本回合减伤仍照常生效
- 验收点：`on_receive_action_damage_segment` 只对敌方 `skill / ultimate` 逐段生效；`on_receive_action_hit` 旧语义不改。

### 2.5 求道玉

|字段|值|
|---|---|
| id | `obito_qiudao_yu` |
| damage_kind | `special` |
| combat_type_id | `light` |
| power | `24` |
| accuracy | `100` |
| mp_cost | `18` |
| priority | `0` |
| power_bonus_source | `effect_stack_sum` |
| power_bonus_self_effect_ids | `["obito_yinyang_zhili"]` |
| power_bonus_per_stack | `12` |

- 玩家说明：主收头技；层数越高越痛，满层时会变成处决技。
- 机制说明：
  - `0` 层也可用
  - 满足 `execute_target_hp_ratio_lte = 0.3` 且自身 `5` 层阴阳之力时，命中后、常规伤害前直接处决
  - 使用后通过 `obito_qiudao_yu_clear_yinyang` 清空全部阴阳之力
  - `on_hit / on_miss` 都清层
- 验收点：处决成功时只写一条 `[execute]` 伤害日志，不再继续走常规公式伤害。

### 2.6 六道十字奉火

|字段|值|
|---|---|
| id | `obito_liudao_shizi_fenghuo` |
| damage_kind | `special` |
| combat_type_id | `fire` |
| power | `62` |
| accuracy | `90` |
| mp_cost | `24` |
| priority | `-1` |

- 玩家说明：候选位纯火系重炮。
- 机制说明：不附带额外状态，不绑共享新能力。
- 验收点：只能通过赛前装配进入 `regular_skill_ids`。

### 2.7 十尾尾兽玉

|字段|值|
|---|---|
| id | `obito_shiwei_weishouyu` |
| damage_kind | `special` |
| targeting | `enemy_active_slot` |
| accuracy | `100` |
| mp_cost | `50` |
| priority | `5` |
| damage_segments | `2 dark + 8 light` |

- 玩家说明：整招一次命中判定，命中后连续打出十段终局伤害。
- 机制说明：
  - 通过 `damage_segments` 固定写成两段资源：
    - `repeat_count=2, power=12, combat_type_id=dark`
    - `repeat_count=8, power=12, combat_type_id=light`
  - 顶层 `power` 当前固定为 `0`；真实伤害只由 `damage_segments` 承担
  - 每段都独立结算伤害、属性克制、减伤与日志
- 验收点：日志 `payload_summary` 必须带 `segment i/n`；目标中途倒下后后续段停止。

## 3. 角色特有验收矩阵

|编号|场景|断言|
|---|---|---|
| 1 | 单位快照 | 双属性、六维、MP、奥义点、默认配招、候选池固定 |
| 2 | 技能快照 | `求道焦土 / 阴阳遁 / 求道玉 / 六道十字奉火 / 十尾尾兽玉` 字面量固定 |
| 3 | 关键资源快照 | `obito_yinyang_zhili`、禁疗标记、`incoming_heal_final_mod`、`damage_segments`、`execute_target_hp_ratio_lte` 固定 |
| 4 | 被动回复 | `仙人之力` 在 `turn_start` 按已损生命值 `10%` 回复 |
| 5 | 禁疗路径 | `求道焦土` 命中后公开标记与 heal block 同步落地，换人不清 |
| 6 | 防反叠层 | `阴阳遁` 本回合按 `on_receive_action_damage_segment` 逐段减伤并加层 |
| 7 | 收头路径 | `求道玉` 威力随层数变化，满层时按 `execute_target_hp_ratio_lte` 处决 |
| 8 | 候选装配 | `六道十字奉火` 只能通过 loadout override 进入战斗 |
| 9 | 奥义路径 | `十尾尾兽玉` 走 `damage_segments`，固定 `2 dark + 8 light` |
| 10 | manager smoke | `create_session -> get_legal_actions -> build_command -> run_turn -> get_public_snapshot / get_event_log_snapshot` 主链公开安全 |

## 4. 平衡备注

- 当前冻结值：以上数值与时长全部视为首版正式接入口径。
- 已知平衡风险：
  - 当前先不调数值；带土先以“最肉、能滚层、能处决”的原型落地。
  - `求道焦土` 的禁疗窗口和 `求道玉` 的满层处决组合会显著抬高残局压力。
- 后续调优入口：
  - `求道焦土` 的持续时间
  - `阴阳遁` 的 MP 成本与叠层速度
  - `求道玉` 的 `power_bonus_per_stack`
  - `十尾尾兽玉` 每段 `power`
