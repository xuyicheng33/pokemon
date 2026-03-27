# Battle Content

本目录只放战斗定义资源，不放美术资源。

- 正式格式：Godot `Resource` / `.tres`
- 资源类型定义：`src/battle_core/content/`
- 当前同时包含：
  - `content/samples/` 下的最小样例资源
  - `sukuna` 原型内容包（单位、技能、被动、effect、field）
- 内容资源以规则文档和加载期校验为准；非法定义会在 `BattleContentIndex` 加载时直接 fail-fast
