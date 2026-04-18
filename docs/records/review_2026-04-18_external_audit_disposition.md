# 2026-04-18 外部审查处置记录

本记录用于正式收口 2026-04-18 外部审查提出的 15 项问题，后续复查统一引用本文件，不再回查聊天记录。

状态说明：

- 本轮已改完：本轮代码或记录已落地，并已纳入验证
- 之前已解决：本轮不重复改 runtime，只补回归、模板或 gate
- 冻结合同：确认当前不是要改成单接口的问题，本轮只把边界写清楚并纳入 gate/文档

## 1. `SandboxSessionCoordinator` 已经是外围层热点

- 状态：本轮已改完
- 处置：
  - 保留 `SandboxSessionCoordinator` 公开 facade，不改 controller 调用面
  - 内部固定拆成 `sandbox_session_bootstrap_service.gd`、`sandbox_session_demo_service.gd`、`sandbox_session_command_service.gd`
- 验证：
  - `TEST_PATH=res://test/suites/manual_battle_scene_suite.gd bash tests/run_gdunit.sh`
  - `bash tests/check_sandbox_smoke_matrix.sh`

## 2. `SampleBattleFactory` 本体已是 facade，但内部仍偏厚

- 状态：本轮已改完
- 处置：
  - `SampleBattleFactory` 继续保持现有公开方法集
  - 可用 matchup 聚合下沉到 `sample_battle_factory_available_matchups_service.gd`
  - content snapshot path 逻辑拆成 `sample_battle_factory_base_snapshot_paths_service.gd` 与 `sample_battle_factory_formal_snapshot_paths_service.gd`
- 验证：
  - `TEST_PATH=res://test/suites/sample_battle_factory_contract_suite.gd bash tests/run_gdunit.sh`

## 3. `TurnResolutionService` 编排密度过高

- 状态：本轮已改完
- 处置：
  - 删除 `turn_resolution_service.gd`
  - `TurnLoopController` 直接依赖 `turn_selection_resolver.gd`、`turn_start_phase_service.gd`、`turn_end_phase_service.gd`、`turn_field_lifecycle_service.gd`
- 验证：
  - `TEST_PATH=res://test/suites/action_guard_invalid_runtime_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/forced_replace_lifecycle_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/field_lifecycle_contract_suite.gd bash tests/run_gdunit.sh`

## 4. `BattleInitializer` 仍然偏重

- 状态：本轮已改完
- 处置：
  - 新增 `battle_initializer_setup_validator.gd`
  - `BattleInitializer` 只保留 setup validate -> side build -> init phases 顺序调度
- 验证：
  - `TEST_PATH=res://test/suites/init_matchup_lifecycle_suite.gd bash tests/run_gdunit.sh`

## 5. `resolve_missing_dependency()` 样板重复

- 状态：本轮已改完
- 处置：
  - 统一改为 `COMPOSE_DEPS / COMPOSE_RESET_FIELDS`
  - `service_dependency_contract_helper.gd` 负责 compose 依赖读取、递归缺依赖检查与 reset spec 导出
- 验证：
  - `python3 tests/gates/architecture_composition_consistency_gate.py`
  - `python3 tests/gates/architecture_wiring_graph_gate.py`

## 6. `invalid_battle_code` 与 `error_state()` 看起来不统一

- 状态：冻结合同
- 处置：
  - 不强行合并
  - 继续保留“运行时硬错误走 `invalid_battle_code()`、builder/loader/facade 组合错误走 `error_state()`”双通道语义
  - 本轮通过文档与 gate 明确边界，避免同类 service 双挂

## 7. `BattleState` 的查找仍是线性扫描

- 状态：本轮已改完
- 处置：
  - `BattleState` 已补 `_side_by_id / _unit_by_id / _unit_by_public_id`
  - 新增 `append_side()` 与 `rebuild_indexes()`
  - 查询路径改成 cache-first + fallback rebuild/update
- 验证：
  - `TEST_PATH=res://test/suites/battle_state_index_cache_suite.gd bash tests/run_gdunit.sh`

## 8. `persists_on_switch` 与 nested `rule_mod` 语义未收口

- 状态：之前已解决
- 处置：
  - 当前规则文档和坏例测试已经锁住“effect 自身 `persists_on_switch=true` 时，其内嵌 `rule_mod` 也必须显式声明 `persists_on_switch=true`”
  - 本轮不重复改 runtime，只在本文件正式标记关闭

## 9. `mp_regen` / `incoming_accuracy` stacking key 会静默折叠

- 状态：之前已解决
- 处置：
  - `rule_mod_schema.gd` 已把 `source_stacking_key` 纳入 `mp_regen` 和 `incoming_accuracy` 的 stacking schema
  - 本轮以 schema regression 与正式记录继续加锁

## 10. Gojo 缺 formal validator

- 状态：之前已解决
- 处置：
  - Gojo validator 已存在
  - 本轮把“所有正式角色都必须有 `content_validator_script_path`”提升成 formal 角色硬约束，并纳入 formal gate

## 11. 角色级 manager smoke 覆盖不均

- 状态：之前已解决
- 处置：
  - 四个正式角色的 manager smoke suite 已齐
  - 本轮改成 shared runner + case spec 模板，降低后续扩角重复成本
- 验证：
  - 四角色 `manager smoke/blackbox` 共 8 个 suite 全通过

## 12. 测试代码体量已经接近业务代码体量，部分 suite 偏厚

- 状态：本轮已改完
- 处置：
  - `catalog_factory_suite.gd` 拆成 `setup / delivery_alignment / surface`
  - `replay_guard_suite.gd` 拆成 `input / summary / failure`
  - 跨域断言下沉到 shared support
- 验证：
  - 新拆 suite 已逐个通过

## 13. 正式角色交付面偏重，扩角成本高

- 状态：本轮已改完
- 处置：
  - 新增 `config/formal_character_sources/`
  - `formal_character_manifest.json` 与 `formal_character_capability_catalog.json` 改成生成并提交的产物
  - `required_content_paths` 从 `content_roots` 自动展开
- 验证：
  - `python3 tests/gates/repo_consistency_formal_character_gate.py`
  - `godot --headless --script tests/helpers/export_formal_registry_views.gd -- <tmp> config/formal_character_sources` 连续两次输出一致

## 14. `decisions.md` / `tasks.md` 仍然过长

- 状态：本轮已改完
- 处置：
  - 新增 `docs/records/archive/tasks_2026-04-10_to_2026-04-18_refactor_wave.md`
  - 新增 `docs/records/archive/decisions_2026-04-10_to_2026-04-18_refactor_wave.md`
  - 活跃 `tasks.md / decisions.md` 只保留长期规则、最近两轮关键决策、当前阶段状态与 archive 索引
- 验证：
  - `python3 tests/gates/repo_consistency_docs_gate.py`

## 15. composition root 仍偏字符串驱动

- 状态：本轮已改完
- 处置：
  - `BattleCoreServiceSpecs.SERVICE_DESCRIPTORS` 继续保留为 slot -> script 唯一真相
  - 依赖与 reset 真相已下沉到各 script 的 `COMPOSE_DEPS / COMPOSE_RESET_FIELDS`
  - `battle_core_wiring_specs/` 已删除
- 验证：
  - `python3 tests/gates/architecture_composition_consistency_gate.py`
  - `python3 tests/gates/architecture_wiring_graph_gate.py`

## 总结

- 本轮真正改 runtime/结构的问题：1 / 2 / 3 / 4 / 5 / 7 / 12 / 13 / 14 / 15
- 之前已解决、这轮只补模板或 gate 的问题：8 / 9 / 10 / 11
- 不做接口合并、只冻结合同的问题：6
