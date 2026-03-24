# 战斗系统规则总表（迁移说明）

本文件已退役，不再作为当前生效规则的承载文件。

注意：

- 本文件和 `docs/records/archive/` 内的旧文档都可能包含已废弃术语与旧机制口径。
- 当前开发、评审、实现一律只看 `docs/rules/`；若全局搜索命中这里，不得直接据此实现。

## 当前生效规则位置

请改读：

- `docs/rules/README.md`
- `docs/rules/00_rule_baseline.md`
- `docs/rules/01_battle_format_and_visibility.md`
- `docs/rules/02_turn_flow_and_action_resolution.md`
- `docs/rules/03_stats_resources_and_damage.md`
- `docs/rules/04_status_switch_and_lifecycle.md`
- `docs/rules/05_items_field_ai_and_logging.md`
- `docs/rules/06_effect_schema_and_extension.md`

## 文档职责

|路径|职责|
|---|---|
|`docs/rules/`|当前生效规则与模块权威文档|
|`docs/records/decisions.md`|记录为何这样定|
|`docs/records/tasks.md`|记录任务过程、验收与回归要点|

## 迁移说明

自 `v0.5` 起，战斗规则不再集中写在 `docs/records/` 下的单一大表里，而改为：

1. `docs/rules/00_rule_baseline.md` 作为规则总则。
2. `docs/rules/01~06` 作为模块化权威文档。
3. `docs/records/` 只保留记录属性，不再承载当前生效细则。
