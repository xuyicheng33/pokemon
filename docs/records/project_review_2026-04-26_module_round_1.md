# 模块化复审记录（2026-04-26，第一轮）

## 范围

- 本轮按模块复审以下区域：
  - `src/composition/`
  - `src/adapters/`
  - `src/shared/`
  - `test/`、`tests/`、`docs/`
- 重点关注：
  - fail-fast 漏洞
  - 错误传播与错误可见性
  - 测试 / gate 重复覆盖
  - 可继续瘦身的 helper 与重复入口
- 本轮只做审查与记录，不改业务逻辑。

## 模块概览

- `src/battle_core/`：176 个 `.gd` 文件。上一轮稳定性修复后，本轮没有再抓到新的阻断级运行时问题。
- `src/composition/ + src/adapters/ + src/shared/`：66 个 `.gd` 文件。当前风险主要集中在 `SampleBattleFactory` 的 catalog 错误传播，以及 Sandbox 选择页/配置页的静默规范化。
- `test/ + tests/`：约 505 个测试 / gate / helper 文件。当前主要问题不是覆盖不足，而是入口约束、重复覆盖和文档 gate 的维护面继续变重。

## 主要问题

### 1. 重要：trigger 同速并列没有真正走随机决胜

- 文件：
  - `src/battle_core/effects/effect_queue_service.gd`
- 现状：
  - `sort_events()` 先把 `source_instance_id` 放进分组键。
  - 比较器也会在读取随机数之前，先按 `source_instance_id` 排序。
  - 结果是只有同一 source 的事件才会吃到 `sort_random_roll`，不同 source 的同速并列会稳定按实例 ID 顺序执行。
- 影响：
  - 不同单位发出的同优先级、同速度触发事件不会随机决胜，会直接改写真实对局结果。
- 建议：
  - 随机 tie-break 必须覆盖“跨 source 的完全同档事件”，而不是只覆盖同 source 内部。
  - 增加跨来源同速触发排序回归。

### 2. 重要：field 生命周期在事件收集阶段失败时，没有把 invalid 往上传

- 文件：
  - `src/battle_core/passives/field_service.gd`
  - `src/battle_core/turn/turn_field_lifecycle_service.gd`
- 现状：
  - `collect_lifecycle_effect_events()` 返回 `{events, invalid_code}`。
  - `field_break` 与 `field_expire` 路径现在只看 `events`，没有继续传播 `invalid_code`。
- 影响：
  - 领域生命周期如果在“收集阶段”就已经坏掉，会被当成“没有事件”继续清场，battle 不能及时 fail-fast。
- 建议：
  - 把 field 相关 trigger 收集结果收口成统一结构化返回，禁止调用侧只读 `events`。
  - 增加 on_break / on_expire 收集期失败回归。

### 3. 重要：替换流程后半段失败会留下半提交状态

- 文件：
  - `src/battle_core/lifecycle/replacement_service.gd`
- 现状：
  - 替换流程在 bench_order、active slot、leave_state 已改动后，后续 `leave_unit()`、field break、`on_enter` 仍可能失败。
  - 当前失败时没有回滚这些中途状态。
- 影响：
  - battle 会被标成 invalid，但运行态不再对应“最后一个合法帧”，后续快照和诊断日志会带着半完成替换状态。
- 建议：
  - 替换流程要么采用 staged commit，要么在 roster / active slot 变更后提供最小回滚。
  - 增加“开始改 roster 之后再失败”的替换回归。

### 4. 阻断：`SampleBattleFactory` 的 matchup 路由还会吞掉 catalog 加载错误

- 文件：
  - `src/composition/sample_battle_factory_setup_access.gd`
  - `src/composition/sample_battle_factory_matchup_catalog.gd`
  - `src/composition/sample_battle_factory_baseline_matchup_catalog.gd`
- 现状：
  - `build_setup_by_matchup_id_result()` 先调用 baseline/formal 两边的 `has_matchup()`。
  - 两边的 `has_matchup()` 在 catalog 加载失败时都直接返回 `false`。
  - 结果是 formal catalog / baseline catalog 坏掉时，setup 路由会把“真实的 catalog 错误”降格成“unknown matchup_id”或错误落到另一侧 catalog。
- 影响：
  - 违反当前 fail-fast 方向，错误定位会漂移。
  - formal matchup、pair interaction 和 demo replay 这类依赖 matchup 路由的路径，会更难从返回值里看出真正坏的是 manifest / catalog。
- 建议：
  - `has_matchup()` 不应继续承担“错误时返回 false”的语义。
  - 路由层应改成结构化查询结果，例如 `find_matchup_owner_result()` 或 `load_matchups_result()` 后再判断 owner。
  - 增加回归：formal catalog fixture 坏掉时，`build_setup_by_matchup_id_result()` 必须直接暴露 catalog 错误，而不是回成 unknown matchup。

### 5. 重要：demo replay 启动仍被 manual matchup 预加载链提前卡死

- 文件：
  - `src/adapters/sandbox_session_bootstrap_service.gd`
  - `src/adapters/battle_sandbox_launch_config.gd`
- 现状：
  - `prepare_scene()` 在判断 `state.is_demo_mode` 之前，先强制执行 `_load_available_matchups()`。
  - `normalize_config_result()` 在 `demo_profile_id` 已经切到 demo 模式后，仍继续对 `matchup_id` 做 strict 校验。
- 影响：
  - formal manifest / matchup catalog 一坏，Sandbox 连只读 demo replay 都可能起不来。
  - CLI `demo=...` 的失败信息还会被误导成 `unknown sandbox matchup_id`，排查方向会跑偏。
- 建议：
  - 把 demo replay 的启动分流提前到可见 matchup 加载之前。
  - demo 模式下跳过无关的 `matchup_id` strict 校验，只校验 replay profile 自身。
  - 增加回归：formal catalog 坏掉时，demo replay 仍可启动；strict demo config 不得因无关 `matchup_id` 失败。

### 6. 一般：公式伤害在 owner 丢失时会被静默跳过

- 文件：
  - `src/battle_core/effects/payload_handlers/payload_damage_runtime_service.gd`
- 现状：
  - `use_formula` 分支找不到 `effect_event.owner_id` 对应单位时直接 `return`，没有设置 invalid code。
- 影响：
  - 公式伤害会静默消失，上层也拿不到 fail-fast 信号。
- 建议：
  - 缺失 owner 应转成 `invalid_battle_code`，而不是安静跳过。
  - 增加缺失 owner 的公式伤害负路径测试。

### 7. 重要：`FormalCharacterCapabilityCatalog` 的缓存没有按 `catalog_path` 分桶

- 文件：
  - `src/shared/formal_character_capability_catalog.gd`
- 现状：
  - 实例级缓存一旦命中，后续传入其他 `catalog_path` 或改 `catalog_path_override` 仍直接返回第一次的结果。
- 影响：
  - 同一个实例复用到第二个 catalog 时，会静默串目录、读错能力定义。
  - 这种错误不会直接爆红，fixture / 多目录工具更容易被前一次结果污染。
- 建议：
  - 按 resolved path 做缓存分桶，或者干脆移除实例级缓存，改成调用方显式持有。
  - 增加多 path / override 重读契约测试。

### 8. 重要：suite reachability 还允许“空壳 suite 入口”混过 gate

- 文件：
  - `tests/check_suite_reachability.sh`
  - `tests/gates/repo_consistency_formal_character_gate_characters.py`
  - `tests/gates/repo_consistency_formal_character_suite_needle_support.py`
  - `docs/records/decisions.md`
- 现状：
  - `suite_path` / `required_suite_paths` 目前只要求文件存在。
  - formal gate 再通过 preload / extends 递归去找真正包含 `test_*` 的文件。
- 影响：
  - 这和“manifest、文档和 gate 必须引用真实 suite 路径”的现行决策已经不一致。
  - 未来如果有人把 manifest 指回 wrapper / 空壳入口，门禁仍可能假绿。
- 建议：
  - 收紧为：`suite_path` 与 `required_suite_paths` 本文件就必须是可发现的真实 gdUnit suite，且自身包含 `func test_*`。
  - preload / extends 递归只保留给 shared/base 依赖树，不再替代 suite 真身校验。

### 9. 重要：docs gate / surface gate 对同一套测试事实做了多点硬编码

- 文件：
  - `tests/gates/repo_consistency_docs_gate.py`
  - `tests/gates/repo_consistency_surface_gate.py`
  - `docs/design/current_development_workflow.md`
  - `tests/README.md`
  - `README.md`
- 现状：
  - quick / extended / full 入口命令、README 文案、workflow 顺序、回归锚点、测试树职责，在多个 gate 与文档里同时写死。
- 影响：
  - 一次入口重命名、流程顺序调整或 suite 迁移，容易触发一串行为无关的假红。
  - 文档 gate 会逐步从“防漂移”变成“高同步成本”。
- 建议：
  - 入口流程只保留一个权威文档，其余文档改为引用。
  - surface/docs gate 只校验“是否指向权威源”和最小关键锚点，不再重复写整段事实。

### 10. 一般：BattleSandbox 控制器边界还有 live object 泄露与 close 失败不可见

- 文件：
  - `src/adapters/battle_sandbox_controller.gd`
  - `src/adapters/sandbox_session_coordinator.gd`
  - `src/adapters/sandbox_view_character_cards_renderer.gd`
- 现状：
  - `get_state_snapshot()` 直接把 live `battle_setup` 暴露给外部。
  - `bootstrap_scene()` / `_exit_tree()` 不检查 `close_runtime()` 结果，close 失败会被后续 reset 覆盖。
  - `SandboxViewCharacterCardsRenderer` 在视图层直接写 `state.error_message`。
- 影响：
  - 调试工具、测试或 UI 辅助层可以无意间污染控制器内部状态。
  - 旧 session 清理失败时，真正的错误会在下一步被吞掉。
  - 视图层和 session 状态的耦合继续偏重。
- 建议：
  - `get_state_snapshot()` 只返回只读 DTO，不再暴露 live `BattleSetup`。
  - close 失败要么直接中止重启，要么至少显式保留并上抛错误。
  - 视图层只返回 render result / error payload，由 coordinator 决定是否写入 session 状态。

### 11. 一般：BattleSandbox quick 主路径存在重复覆盖

- 文件：
  - `test/suites/manual_battle_scene/manual_flow_suite.gd`
  - `test/suites/manual_battle_scene/demo_replay_suite.gd`
  - `tests/check_sandbox_smoke_matrix.sh`
  - `tests/helpers/manual_battle_full_run.gd`
  - `tests/helpers/demo_replay_full_run.gd`
- 现状：
  - gdUnit suite 已覆盖默认 manual/policy、policy/policy、demo replay 主路径。
  - quick / full gate 里的 smoke matrix 又把其中一部分主路径再跑一遍。
- 影响：
  - 日常 gate 时间和失败噪声都会被放大。
  - 两层同时报同一类“能否打完一局”的 summary 失败，可读性一般。
- 建议：
  - 保留两层，但拆职责：
    - gdUnit suite 只守 UI/交互 contract
    - smoke script 只守“能启动、能跑完、summary 完整”
  - 或把 `manual_flow_suite` 中只做 summary 校验的两条主路径移到 extended。

## 可继续瘦身的重复点

### 1. `manual_battle_scene` support 还有一层纯转发壳

- 文件：
  - `tests/support/manual_battle_scene_support.gd`
  - `tests/support/manual_battle_scene_context_support.gd`
  - `tests/support/manual_battle_scene_drive_support.gd`
- 现状：
  - `manual_battle_scene_support.gd` 基本只是 context / drive 两个 helper 的薄转发层。
  - `run_to_battle_end()` 现在又只是 `run_to_battle_end_via_submit()` 的别名。
- 建议：
  - 这组最适合先合并，减少 headless helper 与 suite 之间的跳转层级。

### 2. headless manual battle helper 基本重复

- 文件：
  - `tests/helpers/manual_battle_full_run.gd`
  - `tests/helpers/manual_battle_submit_full_run.gd`
- 现状：
  - 两个脚本只有 3 处语义差异：错误文案、`run_to_battle_end` / `run_to_battle_end_via_submit` 调用点。
- 建议：
  - 合并成一个脚本，用环境变量或参数切换 `drive_mode`。

### 3. 路径规范化 helper 已经开始散开

- 文件：
  - `src/shared/resource_path_helper.gd`
  - `src/composition/sample_battle_factory_formal_access.gd`
  - `src/composition/sample_battle_factory_base_snapshot_paths_service.gd`
- 现状：
  - 路径规范化至少已经有 3 份相近实现。
- 建议：
  - 下一轮修复 `SampleBattleFactory` 边界时，一并把路径规范化收回单一 helper，避免 override / fixture 路径逻辑继续漂。

## 本轮建议的修复顺序

1. 先修 `SampleBattleFactory` matchup owner 查询，堵住 catalog 错误被吞的问题。
2. 再补 `effect_queue_service` 的跨来源 tie-break，避免真实结果漂移。
3. 接着修 field 生命周期收集期错误传播与 replacement 半提交问题。
4. 然后拆开 demo replay 启动链，避免被 matchup 预加载和 strict matchup 校验误伤。
5. 再修 capability catalog 的 path 缓存污染。
6. 接着收紧 suite reachability / formal suite gate，让 manifest 指向真实 suite。
7. 然后瘦 docs gate / surface gate 的多点硬编码。
8. 最后再合并 BattleSandbox quick 路径和 manual battle helper 的重复覆盖。
