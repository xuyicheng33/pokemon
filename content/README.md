# Battle Content

本目录只放战斗定义资源，不放美术资源。

- 正式格式：Godot `Resource` / `.tres`
- 资源类型定义：`src/battle_core/content/`
- 当前同时包含：
  - `content/battle_formats/` 下的正式战斗格式资源
  - `content/samples/` 下的最小样例资源
  - `content/shared/` 下的非顶层辅助资源（只供其他内容资源引用，不直接注册进 content snapshot）
  - `content/{units,skills,effects,passive_skills,fields}/gojo/` 下的 Gojo 正式角色内容包
  - `content/{units,skills,effects,passive_skills,fields}/sukuna/` 下的宿傩正式角色内容包
  - `content/{units,skills,effects,passive_skills}/kashimo/` 下的鹿紫云正式角色内容包
  - `content/{units,skills,effects,passive_skills}/obito/` 下的带土正式角色内容包
- 内容资源以规则文档和加载期校验为准；非法定义会在 `BattleContentIndex` 加载时直接 fail-fast
- `SampleBattleFactory.content_snapshot_paths_result()` 当前只收两段：上述九个目录的顶层样例资源，以及 `config/formal_character_runtime_registry.json` 里显式登记的 `required_content_paths`
- `content/shared/` 不参与顶层 snapshot 扫描；若要复用 payload / 子资源，应由顶层 `EffectDefinition / FieldDefinition / SkillDefinition` 等通过外部资源引用它
- 正式角色资源按角色子目录收纳；sample / battle_format / combat_type 资源继续保持当前目录结构
- 当前额外保留一个最小正式 passive item 样例：`sample_attack_charm -> sample_attack_charm_bonus -> sample_pyron_charm`

当前正式角色资产约束：

- 每个正式角色都必须同时具备设计稿、调整记录、内容资源、SampleFactory 接线和专项 suite
- 设计稿与调整记录放在 `docs/design/`
- 内容资源继续只放 `.tres`，不把玩法口径藏在测试里

Gojo 当前内容语义已经结构化进 schema：

- 默认装配：`skill_ids = 苍 / 赫 / 茈`
- 奥义：`ultimate_skill_id = 无量空处`
- 被动：`passive_skill_id = 无下限`
- 奥义点：`ultimate_points_required = 3`，`ultimate_points_cap = 3`，`ultimate_point_gain_on_regular_skill_cast = 1`

宿傩当前内容语义已经结构化进 schema：

- 默认装配：`skill_ids = 解 / 捌 / 开`
- 候选常规技能池：`candidate_skill_ids = 解 / 捌 / 开 / 反转术式`
- 奥义：`ultimate_skill_id = 伏魔御厨子`
- 被动：`passive_skill_id = 教会你爱的是...`
- 奥义点：`ultimate_points_required = 3`，`ultimate_points_cap = 3`，`ultimate_point_gain_on_regular_skill_cast = 1`
- 动态回蓝：当前按对位差值给 `mp_regen` 追加 `9 / 8 / 7 / 6 / 5 / 0`；宿傩最终每回合回复值为 `基础 12 + 对位追加`

赛前若要替换本场常规三技能，统一通过 `BattleSetup -> SideSetup.regular_skill_loadout_overrides`，不再通过临时改写 `UnitDefinition.skill_ids` 做测试捷径。
