# 2026-04-19 全量质量收口处置记录

本记录用于正式收口 2026-04-19 审阅确认的问题，后续复查统一引用本文件，不再回查聊天记录。

状态说明：

- 本轮已改完：本轮代码、gate 或记录已经落地
- 本轮策略：本轮已经把口径和实现方式定死，后续只允许沿用，不再回到旧写法

## 1. 孤儿 `.gd.uid`

- 状态：本轮已改完
- 处置：
  - 删除全部孤儿 `.gd.uid`
  - `.gitignore` 不再忽略 `*.uid`
  - repo consistency gate 固定校验“有效 `.gd.uid` 必须被跟踪，孤儿 `.gd.uid` 必须清零”

## 2. `.gd.uid` 未纳入版本管理

- 状态：本轮已改完
- 处置：
  - 当前仓库已有的有效 `.gd.uid` 全部纳入版本管理
  - 以后不再接受“本地有 uid、git 里看不见”的状态

## 3. GDScript 缩进风格漂移

- 状态：本轮已改完
- 处置：
  - 全仓统一到 tab 前导缩进
  - 新增 architecture style gate，直接拦截 space-only 和 tab/space 混用

## 4. 外层结果式 envelope 重复和残缺

- 状态：本轮已改完
- 处置：
  - 外层结果统一只认 `ok / data / error_code / error_message`
  - policy / adapters / facade helper / shared formal manifest / sample factory 全部收口到共享 helper

## 5. `last_error_* + error_state()` 样板重复

- 状态：本轮已改完
- 处置：
  - 新增共享 `ErrorStateHelper`
  - 触达 owner 统一改成同一套 `clear / fail / error_state` 写法

## 6. `BattleState` 假缓存

- 状态：本轮已改完
- 处置：
  - 取消 `_side_by_id / _unit_by_id / _unit_by_public_id` 这套假缓存
  - 查询路径改回线性真查找
  - `rebuild_indexes()` 只保留兼容入口，不再宣称性能语义

## 7. `BattleCoreManagerContainerService` 返回结构和缺依赖检查不统一

- 状态：本轮已改完
- 处置：
  - `create_session_result()` 改成标准 envelope
  - 固定一份 `REQUIRED_CONTAINER_SERVICES` 清单，统一校验 container service 依赖

## 8. `TurnSelectionResolver` / `ReplacementService` / `TurnLoopController` 重复局部结果字典

- 状态：本轮已改完
- 处置：
  - 分别补本地 helper，收口重复结果字典
  - 不再散写同形态局部 struct-ish 字典

## 9. `BattleInitializer.COMPOSE_DEPS` 混入 owner 私有 helper

- 状态：本轮已改完
- 处置：
  - `COMPOSE_DEPS` 只保留外部注入依赖
  - owner 私有 helper 改走独立的本地 helper 校验清单

## 10. 测试与门禁盲区

- 状态：本轮已改完
- 处置：
  - 测试体量 gate 扩到 `test/` 和 `tests/`
  - `test/**/shared*.gd`、`test/**/*_shared.gd`、`tests/support/**/*.gd` 统一按 support helper 处理

## 11. 临界大文件和超厚 shared helper

- 状态：本轮已改完
- 处置：
  - warning 档 owner 主动拆分
  - `catalog_factory_shared`、`replay_guard_shared` 按主题拆成更薄的 shared helper
  - `formal_character_pair_smoke/shared.gd`、`formal_character_manager_smoke_helper.gd`、`combat_type_test_helper_cases.gd` 也同步压出 warning 带

## 12. 本地报告、空目录与仓库噪声

- 状态：本轮已改完
- 处置：
  - 新增 `tests/cleanup_local_artifacts.sh`
  - 当前只认 `reports/gdunit`
  - 删除 `assets/.gitkeep`
  - `tmp / .tmp` 退回纯本地 scratch

## 13. 本轮门禁额外补抓的漏项

- 状态：本轮已改完
- 处置：
  - `test/suites/extension_validation_contract/shared_extensions_suite.gd` 实际是 suite，不是 shared helper；已改名为 `extension_validation_contract_suite.gd`，避免被 support helper 体量门禁误伤
  - 根级 `test/suites/extension_validation_contract_suite.gd` 的 preload 已同步改到新路径，gdUnit 全量扫描可正常发现并执行该 suite
