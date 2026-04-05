# 正式角色设计模板

本模板用于正式角色设计稿收口。目标不是“把规则再抄一遍”，而是把**角色自己的资源定义、玩法差异、验收目标和平衡备注**写清楚，让后续接线、补资源和补回归时有单一落点。

使用方式：

1. 先按本模板写角色稿。
2. 再按 `docs/design/formal_character_delivery_checklist.md` 补齐资源、registry、suite 和记录；正式角色 registry 的单一维护入口固定为 `docs/records/formal_character_registry.json`。
3. 若角色带领域机制，只在本稿末尾追加“领域角色差异附录”，公共规则继续引用 `docs/design/domain_field_template.md`。
4. 若角色需要 `content_validator_script_path`，entry validator 固定按 `unit_passive_contracts / skill_effect_contracts / ultimate_domain_contracts` 三桶模板落地。

## 固定范围

正式角色稿固定只保留 4 类内容：

1. 角色定位与资源定义
2. 角色特有机制
3. 角色特有验收矩阵
4. 平衡备注

## 共享规则引用

下列内容一律引用公共文档，不在角色稿重复展开：

|共享主题|权威入口|
|---|---|
|换人、离场、bench 持续效果与补位|`docs/rules/04_status_switch_and_lifecycle.md`|
|effect / rule_mod schema、持久 rule_mod、来源分组叠加|`docs/rules/06_effect_schema_and_extension.md`|
|共享治疗 / 处决 / 多段主动伤害 contract|`docs/rules/03_stats_resources_and_damage.md` + `docs/rules/06_effect_schema_and_extension.md`|
|运行时模型与 `EffectInstance / RuleModInstance` 字段|`docs/design/battle_runtime_model.md`|
|内容资源字段与加载期校验|`docs/design/battle_content_schema.md`|
|正式角色交付清单与测试最低面|`docs/design/formal_character_delivery_checklist.md`|
|领域公共流程、对拼与 field_apply_success|`docs/design/domain_field_template.md`|

## 固定写法

### 0. 冻结结论

开头固定先写一张冻结结论表，列出：

- 角色定位
- 被动主轴
- 核心技能主轴
- 奥义点配置
- 若有领域：领域成功 / 失败 / 结束语义
- 当前平衡结论
- 明确不做的历史方案

### 0.1 角色稿范围

固定说明：

- 本稿按本模板收口，只保留角色自己的资源定义、角色机制、验收矩阵与平衡备注。
- 共享引擎规则统一引用公共文档，不在角色稿重复展开。

### 1. 角色定位与资源定义

本节至少包含：

- 角色定位
- `UnitDefinition` 面板
- MP 系统
- 技能组与赛前装配
- 被动 / 持有物

固定要求：

- 面板必须明确写 `combat_type_ids`、六维面板、`max_mp / init_mp / regen_per_turn`
- 若有奥义点，必须写 `required / cap / regular_skill_cast gain`
- 默认配招和候选池要分开写，避免把 `skill_ids` 和 `candidate_skill_ids` 混成一件事
- 必须点明本场装配走 `SideSetup.regular_skill_loadout_overrides`

推荐骨架：

```md
## 1. 角色基础属性

### 1.1 角色定位
- 面向玩家：
- 面向实现：

### 1.2 UnitDefinition
| 字段 | 值 | 说明 |
|---|---|---|

### 1.3 MP / 奥义点系统
| 字段 | 值 | 说明 |
|---|---|---|

补充语义：
-

### 1.4 技能组与赛前装配
- 默认配招（`skill_ids`）：
- 候选池（`candidate_skill_ids`）：
- 奥义（`ultimate_skill_id`）：
- 被动（`passive_skill_id`）：
- 持有物（`passive_item_id`）：
```

### 2. 角色特有机制

本节只写该角色独有的玩法差异、资源绑定和共享能力的角色化用法。

固定要求：

- 每个常规技能 / 奥义都要写出资源字段和玩法语义
- 若某技能依赖共享能力，只写“本角色怎么用”，不重复写完整 schema / 读写路径 / 全局排序链
- 若角色依赖 `missing_hp` 百分比治疗、`incoming_heal_final_mod`、技能级 `execute_*`、`damage_segments` 或 `on_receive_action_damage_segment`，只写“本角色怎么用”，不在角色稿里重复讲共享 runtime 细节
- 关键 effect / field / passive 资源必须显式列出，不允许把核心语义藏在“见资源文件”
- 若有“必须满足的跨资源不变量”，要在角色稿里写清，并在 checklist 阶段决定是否需要 `content_validator_script_path`；若需要，直接登记进 `docs/records/formal_character_registry.json`，runtime 会统一从这份 registry 装配

推荐骨架：

```md
## 2. 技能详细设计

### 2.1 <技能 A>
| 字段 | 值 |
|---|---|

- 玩家说明：
- 机制说明：
- 边界：
- 验收点：

### 2.2 <技能 B>
...

### 2.x <被动 / 奥义 / 关键 effect / field>
- 资源：
- 语义：
- 与公共模板的关系：
- 必须锁死的 contract：
```

### 3. 角色特有验收矩阵

固定写角色专属断言；共享 suite 可作为交付面的一部分被引用，但不在角色稿里重写公共机制全表。

固定要求：

- 至少覆盖 `snapshot / runtime / manager smoke` 三类视角
- 只列“这个角色必须长期锁死什么”，不要把通用测试说明重抄一遍
- 若共享 suite 是正式交付面的一部分，要写明“通过 formal registry 回挂”；registry 的单一维护入口仍是 `docs/records/formal_character_registry.json`

推荐骨架：

```md
## 3. 角色特有验收矩阵

| 编号 | 场景 | 断言 |
|---|---|---|
| 1 | 单位快照 | |
| 2 | 技能快照 | |
| 3 | 关键资源快照 | |
| 4 | 角色独有主路径 | |
| 5 | 公开 manager smoke | |
```

### 4. 平衡备注

固定写：

- 当前冻结值
- 已知平衡风险
- 后续调优入口

推荐骨架：

```md
## 4. 平衡备注

- 当前冻结值：
- 已知平衡风险：
- 后续调优入口：
```

## 可选附录：领域角色差异附录

只有领域角色才追加本附录；普通角色不写。

附录里只允许写：

- 领域技能本体数值与类型
- 成功立场后的差异收益
- 自然到期收益
- 被打断收益或损失
- 与公共领域模板相比的少数特化边界

推荐骨架：

```md
## 附录 A. 领域角色差异

### A.1 领域技能本体
| 字段 | 值 |
|---|---|

### A.2 成功立场后的差异收益
-

### A.3 自然到期收益
-

### A.4 被打断收益或损失
-

### A.5 特化边界
-
```

## 禁止事项

- 不把共享 effect / rule_mod schema 再抄一遍
- 不在角色稿里重新定义公共领域对拼矩阵
- 不把 manager envelope、`public_id` 契约、bench 生命周期等全局规则复制到每个角色稿
- 不把“资源清单 / registry / suite / checklist”混进玩法章节里，交付动作统一交给 `formal_character_delivery_checklist.md` 与 `docs/records/formal_character_registry.json`
