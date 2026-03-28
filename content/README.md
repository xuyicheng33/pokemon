# Battle Content

本目录只放战斗定义资源，不放美术资源。

- 正式格式：Godot `Resource` / `.tres`
- 资源类型定义：`src/battle_core/content/`
- 当前同时包含：
  - `content/samples/` 下的最小样例资源
  - `sukuna` 原型内容包（单位、技能、被动、effect、field）
- 内容资源以规则文档和加载期校验为准；非法定义会在 `BattleContentIndex` 加载时直接 fail-fast

宿傩当前内容语义已经结构化进 schema：

- 默认装配：`skill_ids = 解 / 捌 / 开`
- 候选常规技能池：`candidate_skill_ids = 解 / 捌 / 开 / 反转术式`
- 奥义：`ultimate_skill_id = 伏魔御厨子`
- 被动：`passive_skill_id = 教会你爱的是...`

赛前若要替换本场常规三技能，统一通过 `BattleSetup -> SideSetup.regular_skill_loadout_overrides`，不再通过临时改写 `UnitDefinition.skill_ids` 做测试捷径。
