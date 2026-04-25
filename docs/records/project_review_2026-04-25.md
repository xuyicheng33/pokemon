# 全项目审查记录（2026-04-25）

## 范围

- 审查 `src/`、`content/`、`scenes/`、`test/`、`tests/`、`config/`、`docs/` 的当前实现、测试组织、体量与可删减点。
- 本次只做审查与记录，不改业务逻辑、不删除文件。

## 当前状态

- 主线可运行：`bash tests/run_with_gate.sh` 通过。
- 阶段验证通过：`bash tests/run_extended_gate.sh` 通过，覆盖 extended gdUnit、full sandbox smoke、suite reachability、architecture、repo consistency、Python lint。
- 体量概览：
  - tracked 文件约 1732 个，其中 `.gd` 720 个、`.gd.uid` 720 个、`.tres` 117 个。
  - GDScript 总量约 49,973 行；核心代码集中在 `src/battle_core/`，测试集中在 `test/suites/` 与 `tests/`。
  - `addons/gdUnit4/` 是 vendored 测试依赖，体量大但不属于业务冗余。

## 应保留

- `src/battle_core/` 当前分层清晰，architecture gate 已覆盖 outer/internal layering、composition descriptor、runtime wiring DAG 与文件体量阈值。
- `config/formal_character_sources/` 作为 formal 角色人工真源应保留；`config/formal_character_manifest.json` 与 `config/formal_character_capability_catalog.json` 作为生成产物仍需提交。
- `.gd.uid` 必须继续跟随 `.gd` 管理，repo consistency gate 已把孤儿 uid 作为阻断项。
- `test/` 与 `tests/` 虽容易混淆，但职责不同：`test/` 是 gdUnit 业务 suite，`tests/` 是 gate、helper、support、fixtures。
- `reports/gdunit/`、`.godot/`、`.ruff_cache/`、`__pycache__/` 当前是 ignored 本地产物，不需要提交；需要清理时走 `bash tests/cleanup_local_artifacts.sh` 或手工删 ignored 目录即可。

## 主要问题

1. Formal catalog 错误在可见 matchup 汇总路径里会被静默吃掉。
   - `src/composition/sample_battle_factory_baseline_matchup_catalog.gd:64` 的 `available_matchups_result()` 在 formal catalog 加载失败时仍返回 baseline descriptors。
   - `test/suites/sample_battle_factory_contract_suite.gd:14` 也保留了 “ignores formal ... failure” 这类合同。
   - 影响：formal manifest / matchup 损坏时，Sandbox 可能只少展示正式角色入口，而不是立即暴露配置错误；这和长期 fail-fast 方向不一致。

2. Sandbox 角色选择页缺少 manifest 错误显式呈现。
   - `src/adapters/sandbox_view_presenter.gd:213` 的 `_character_options()` 在 manifest 读取失败时直接返回空数组。
   - 影响：玩家看到的是空选择页或缺卡片，而不是明确错误；这属于前端可诊断性问题。

3. Sandbox UI 仍是桌面固定布局。
   - `src/adapters/sandbox_player_ui_builder.gd:55` 固定 4 列角色卡，`src/adapters/sandbox_player_ui_builder.gd:61` 使用固定横排战斗主体，事件面板还有 360 最小宽度。
   - 影响：当前主流程能玩，但窗口较窄时容易挤压；如果后续面向更小窗口或移动端，需要响应式列数、滚动容器和更稳定的按钮换行。

4. 测试与 gate 的维护面偏重。
   - `tests/gates/repo_consistency_surface_gate.py:20` 强制 README 中 GDScript 行数与当前行数完全一致。
   - quick profile、manifest required suite、surface gate regression needle 三处都在维护测试入口信息。
   - 影响：保护力存在，但每次拆文件/改行数都会产生文档计数噪声；后续可以把“精确行数”降为脚本输出或只在报告中展示。

5. Formal validator 与角色测试仍有重复样板。
   - 每个正式角色都有 snapshot、manager smoke、manager blackbox、runtime 私有 suite，以及 per-character validator。
   - 影响：新增角色时会继续放大测试数量和手工样板；可以逐步把“结构合同”转成 manifest/capability 驱动，只保留角色特色 runtime 用例。

6. 已有架构警告需要排期处理。
   - extended gate 报告 `test/suites/content_validation_core/formal_registry/catalog_factory_setup_shared.gd` 已到 226 行，接近 250 行 support helper split 阈值。
   - 影响：现在不阻断，但继续扩展 formal setup case 时会变成阻断。

## 可精简建议

- 短期：
  1. 修正 `available_matchups_result()` 的 formal catalog 错误处理；如仍需要 baseline-only 离线模式，应显式命名成单独 API。
  2. Sandbox 选择页为空时显示启动错误或“无可用角色”的明确状态，并把 manifest error 写入 `state.error_message`。
  3. 移除 README 精确行数强校验，改为 `tests/gates` 输出统计即可。
  4. 拆分 `catalog_factory_setup_shared.gd`，避免下一轮变成体量阻断。

- 中期：
  1. 将 snapshot / manager smoke 的 per-character suite 合并成 manifest 驱动矩阵，只保留每个角色的特色 runtime suite。
  2. 将 formal validator 中的通用 payload/effect/skill 形状校验继续下沉到 shared helper，per-character validator 只描述差异。
  3. quick profile 从硬编码列表转向“核心合同 + manifest 标记”的派生列表，减少新增角色时的多点改动。

## 不建议删除

- 不建议删除 `addons/gdUnit4/`：当前测试体系依赖它。
- 不建议删除 `.gd.uid`：Godot 4.4+ 资源引用治理需要它们，已有 gate 保护。
- 不建议删除 `config/formal_character_manifest.json` / `config/formal_character_capability_catalog.json`：虽然是生成产物，但当前 runtime、tests、gate 都消费 committed 产物。
- 不建议直接删大批角色测试；应先用 manifest 驱动 suite 替代，再删除重复用例。
