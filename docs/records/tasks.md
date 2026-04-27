# 任务清单（活跃）

本文件只保留当前仍直接影响交付、门禁或下一步开发节奏的任务入口。

更早且已关闭的完整记录见：

- `docs/records/archive/tasks_2026-04-19_engineering_overhaul.md`
- `docs/records/archive/tasks_2026-04-10_to_2026-04-18_refactor_wave.md`
- `docs/records/archive/tasks_pre_2026-04-05_repair_wave.md`
- `docs/records/archive/tasks_pre_v0.6.4.md`
- `docs/records/archive/tasks_pre_v0.6.3.md`

当前生效规则以 `docs/rules/` 为准；工程结构与交付模板以 `docs/design/` 为准。
带日期的已完成阶段只保留当前仍有引用价值的摘要；完整流水统一看 archive。

- Batch A3: forced_command 对齐 + faint/dedupe 文档化
- Batch B1: chain_context phase-scope + runtime_fault 单写者
- Batch B2a: preload composition 下沉到 shared
- Batch B2b: SampleBattleFactory 迁出到 dev_kit + tests/support
- Batch B2c: payload_handlers 三对折叠
- Batch B3a: action_cast_service 拆分为 4 owner
- Batch B3b: EffectInstanceService 查询 API
- Batch C-A: test/suites 精简（双层桩 + before fixture + 角色参数化 + replay_guard 合并 + 命名）
- Batch C-B: gate 减负（surface 字面量删、architecture 下沉 .py、sandbox heredoc 合一、cleanup 白名单反转）
- Batch C-C: profile 重划分 + double support 合一 + 行数硬警
- Batch D-Layout: BattleScreen tscn + controller（重启）
- Batch D-Session: player_battle_session + event_log_streamer + default_policy（重启）
- Batch D-Lex: PlayerContentLexicon 中文索引器（重启）
- Batch E3: active 判定统一
- Batch E1: BattleCoreSession facade 文档对齐
- Batch E2: payload_service_specs 静态 preload 绑定
- Batch E4: battle_state 注释 + interaction 重命名 + payload 文档
- Batch F: 玩家 MVP 接线断裂修复
- Batch G: 玩家 MVP 进 gate
- Batch H: phase / battle_result 写入收口
- Batch I: legacy assert + README facade 口径
- Batch J: layering gate 动态 path 白名单 + 9 个 replay case 进 gate + Obito 案例 + Sukuna bad_cases 5 case + docs gate 减负
- Batch K: SessionFactory 抽取 + envelope helper 删除
- Review Fix 1: CI extended gate 与 smoke 文档口径同步
- Review Fix 2: 玩家 MVP visible matchup 覆盖补齐
- Review Fix 3: BattleScreen action/result owner 拆分 + scenes/adapters size gate

## 最近完成：Review Fix 3：BattleScreen action/result owner 拆分（2026-04-28）

- 状态：已完成
- 目标：降低 `BattleScreen.gd` 继续膨胀的风险，把玩家入口后续交互扩展放到更清晰的 owner 里
- 范围：
  1. 新增 `BattleScreenActionBarController.gd`，集中维护技能、奥义、换人、等待按钮状态与主动换人菜单
  2. 新增 `BattleScreenResultDialogController.gd`，集中维护胜负面板与强制换人弹窗
  3. `BattleScreen.gd` 保留 session 编排、整体刷新、错误 toast 与基础 helper
  4. `architecture_layering_gate.py` 把 `src/adapters` 与 `scenes/player` 纳入行数观察名单
- 验收标准：
  - 玩家入口按钮、强制换人、终局展示行为保持不变
  - `BattleScreen.gd` 从 662 行降到 500 行以下
  - 架构 gate 能提示 adapters / player scenes 的后续大文件风险

## 最近完成：Review Fix 2：玩家 MVP visible matchup 覆盖补齐（2026-04-28）

- 状态：已完成
- 目标：让玩家入口可选择的全部 visible matchup 都进入 PlayerBattleSession + PlayerDefaultPolicy 路径回归
- 范围：
  1. `tests/check_sandbox_smoke_matrix.sh` 新增 `RUN_PLAYER_MVP_OTHER_VISIBLE`
  2. extended / full 在 quick anchors 之外补跑其余 visible matchup 的 `tests/helpers/player_mvp_full_run.gd`
  3. README 与当前阶段回归基线同步玩家 MVP 覆盖口径
- 验收标准：
  - quick 仍保留默认玩家 MVP smoke，保持日常反馈速度
  - extended / full 覆盖 BattleScreen 下拉框可见的全部 matchup 玩家路径
  - smoke summary 仍统一走 `validate-summary`

## 最近完成：Review Fix 1：CI extended gate 与 smoke 文档口径同步（2026-04-28）

- 状态：已完成
- 目标：修复 CI 只自动守 quick、README 误写 quick smoke 覆盖范围的问题
- 范围：
  1. `.github/workflows/ci.yml` 增加 `workflow_dispatch` 与每周定时入口，并新增 `extended_gate` job 跑 `tests/run_extended_gate.sh`
  2. `README.md` 把 quick / extended / full smoke 覆盖范围改成与 `tests/check_sandbox_smoke_matrix.sh` 一致
  3. `docs/design/current_stage_regression_baseline.md` 同步 CI 手动/定时 extended 口径
- 验收标准：
  - push / PR 仍默认跑 quick，不拉长日常反馈
  - 手动或定时 workflow 能跑 extended gate
  - README 不再把 extended 覆盖项写成 quick 默认覆盖项

## 最近完成：复审修复 A：extended gate 覆盖语义（2026-04-28）

- 状态：已完成
- 目标：修复 `tests/run_extended_gate.sh` 单跑时漏掉 quick 主路径的问题
- 范围：
  1. `tests/run_extended_gate.sh` 改为先跑 quick 总入口，再跑 extended 余量
  2. 同步 README、tests README 与当前工作流/回归基线文档中的 gate 口径
- 验收标准：
  - `bash tests/run_extended_gate.sh` 不再等价于单独 `TEST_PROFILE=extended`
  - quick 与 extended 的互补关系在文档中清楚可见

## 最近完成：复审修复 B：玩家界面小窗口可操作性（2026-04-28）

- 状态：已完成
- 目标：修复 Player MVP BattleScreen 根节点固定 1280x720 导致小窗口溢出的问题
- 范围：
  1. 移除 `BattleScreen` 根节点固定最小尺寸
  2. 为主界面增加外层 `MainScroll`，小窗口下保留核心操作区可达
  3. 同步 PlayerBattleScreen 节点路径与 UI 合同测试
- 验收标准：
  - 960x540 视口下 PlayerBattleScreen 通过 scroll shell 暴露核心操作区
  - 玩家界面主按钮合同测试仍可推进一回合并渲染日志

## 最近完成：复审修复 C：错误可见化与行动文档同步（2026-04-28）

- 状态：已完成
- 目标：修复玩家侧错误被静默改写/忽略，以及 action execution 文档引用旧服务的问题
- 范围：
  1. `PlayerBattleSession.run_turn` 在 forced command 查询失败时透传 manager 原始 envelope
  2. `PlayerBattleScreen` 刷新事件日志失败时走统一 toast 错误展示
  3. `docs/design/action_execution.md` 更新为当前 action cast owner 服务名
- 验收标准：
  - forced command legal query 失败时保留原始错误码和错误信息
  - 日志 streamer 失败不会静默返回
  - 设计文档不再引用已删除的 action cast 旧服务

## 最近完成：玩家侧深化：多对局选择（2026-04-27）

- 状态：已完成
- 目标：让玩家 BattleScreen 不再只能进入固定 `gojo_vs_sample`，可以从当前可见正式 setup 对局中选择并重新开局
- 范围：
  1. `PlayerBattleSession` 新增 `available_matchups_result()`，复用现有 `SessionFactory + SampleBattleFactory` 读取可见对局，不绕开 formal catalog fail-fast
  2. `BattleScreen.tscn` 顶部增加 `MatchupSelect` 与 `StartMatchupButton`
  3. 新增 `BattleScreenMatchupSelector.gd`，负责可见 matchup 装载、推荐排序标签与 OptionButton metadata
  4. `BattleScreen.gd` 支持选择后关闭旧 session、清理日志 / 弹层 / 缓存、用同一 seed 开新局
  5. `player_battle_screen_contract_suite.gd` 新增对局列表与真实切换到 `kashimo_vs_sample` 的 UI contract
- 验收标准：
  - 默认仍进入 `gojo_vs_sample`
  - 下拉至少包含 `gojo_vs_sample / sukuna_setup / kashimo_vs_sample / obito_vs_sample`
  - 选择 `kashimo_vs_sample` 后点击开始，P1 active unit 变为 `kashimo_hajime`，无错误 toast
- 验证结果：
  - `TEST_PATH=res://test/suites/player_battle_screen_contract_suite.gd bash tests/run_gdunit.sh`（7 cases / 0 failures）
  - `TEST_PATH=res://test/suites/player_battle_session_contract_suite.gd bash tests/run_gdunit.sh`（12 cases / 0 failures）
  - `bash tests/check_architecture_constraints.sh`
  - `bash tests/check_repo_consistency.sh`

## 最近完成：项目复审 C 阶段 #4 Formal capability suite 矩阵（2026-04-27）

- 状态：已完成
- 目标：把 formal capability catalog 到角色交付 suite 的映射放进日常 quick gate，避免新增角色或新增 capability 时漏挂抽样 suite
- 范围：
  1. `capability_catalog_suite.gd` 新增 `test_formal_character_capability_matrix_suite_profile_contract`，从 capability catalog、delivery registry 与 `tests/suite_profiles.json` 反推角色 capability matrix
  2. 对每个 `character_id + shared_capability_id` 检查 capability 存在、至少声明一个 required suite，且所有 capability required suite 都在 suite profiles 中登记
  3. `tests/suite_profiles.json` 将 `content_validation_core/formal_registry/capability_catalog_suite.gd` 从 extended 提到 quick
- 验收标准：
  - capability catalog suite 通过
  - suite reachability 与 repo consistency 通过
  - 不删除现有 per-character bad_cases / runtime suite，只先把矩阵约束前移到 quick
- 验证结果：
  - `TEST_PATH=res://test/suites/content_validation_core/formal_registry/capability_catalog_suite.gd bash tests/run_gdunit.sh`（4 cases / 0 failures）
  - `bash tests/check_suite_reachability.sh`（quick=34 / extended=99）
  - `bash tests/check_repo_consistency.sh`

## 最近完成：项目复审 C 阶段 #2 Sandbox UI 响应式（2026-04-27）

- 状态：已完成
- 目标：让 Sandbox 选择页与战斗页在窄桌面/竖屏宽度下保持可操作，避免依赖 1280 宽布局假设
- 范围：
  1. `SandboxPlayerUIBuilder._add_battle_body` 把战斗三栏从固定 `HBoxContainer` 改为 `ScrollContainer + HFlowContainer`，窄屏可竖向换行并保留滚动兜底
  2. `SandboxViewRefs` 更新 body scroll / body content 引用路径，P1 / Event / P2 summary 继续通过稳定 refs 访问
  3. `SandboxViewPresenter._update_responsive_layout` 保留选择页 `GridContainer` 自适应列数，并在 `<900px` 时把 P1 / Event / P2 三块面板设为统一窄屏宽度
  4. `manual_flow_suite` 增加 620px 选择页单列断言与战斗页 scroll/wrap 断言；同步 demo replay 的事件 header 路径
- 验收标准：
  - 选择页 620px 下角色卡为单列，1000px / 1280px 下仍保持多列
  - 战斗页 620px 下 BodyRow 是可见 ScrollContainer，内部三块内容同宽并可换行
  - manual flow 与 demo replay UI suite 通过
- 验证结果：
  - `TEST_PATH=res://test/suites/manual_battle_scene/manual_flow_suite.gd bash tests/run_gdunit.sh`（11 cases / 0 failures）
  - `TEST_PATH=res://test/suites/manual_battle_scene/demo_replay_suite.gd bash tests/run_gdunit.sh`（3 cases / 0 failures）

## 最近完成：项目复审 C 阶段 #3 README 行数 gate 收口（2026-04-27）

- 状态：已完成
- 目标：确认 README 不再镜像 GDScript 精确行数，并清理残留的旧行数强校验 helper
- 范围：
  1. 确认 `README.md` 当前只说明由 `tests/check_repo_consistency.sh` 运行时输出 `GDSCRIPT_LINE_STATS`
  2. 确认 `repo_consistency_surface_gate.py` 不再调用 README 精确行数比对，只打印当前统计
  3. 删除 `repo_consistency_common.py` 中已无调用点的 `require_readme_count`
- 验收标准：
  - README 不再需要随 src/test/tests 行数变化而更新
  - repo consistency 与 Python lint 通过
- 验证结果：
  - `bash tests/check_repo_consistency.sh`
  - `bash tests/check_python_lint.sh`

## 最近完成：项目复审 C 阶段 #1 validator helper 二期（2026-04-27）

- 状态：已完成
- 目标：继续压缩 formal character validator 的重复 payload 验证样板，把高频 `require_effect -> extract_payload -> expect_shape` 与 apply_effect target 检查收口到 base helper
- 范围：
  1. `content_snapshot_formal_character_validator_base.gd` 扩展 `_validate_single_payload_effect`，支持 `contract_label_suffix`
  2. 同 base 新增 `_expect_payload_target` 与 `_expect_apply_effect_target`，覆盖不带 effect_contract 的 payload target 验证与 apply_effect target 验证
  3. Gojo / Sukuna / Kashimo / Obito validator 改用新 helper，保留多 payload、动态 trigger、独立 contract 的显式验证路径
  4. 修复 GDScript 父子类 const 同名解析错误：base 内部 apply_effect payload 脚本改名为 `_BaseApplyEffectPayloadScript`
  5. 清理 Gojo / Sukuna validator 中已不再使用的 `ApplyEffectPayloadScript` preload
- 验收标准：
  - 4 个 formal bad_cases suite 全过，错误信息保持可读且关键 needle 对齐
  - scoped validator suite 全过
  - quick gate 全过
  - 不放宽 fail-fast，不删除既有角色 contract 校验
- 验证结果：
  - `TEST_PATH=res://test/suites/extension_validation_contract/gojo_bad_cases_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/extension_validation_contract/sukuna_bad_cases_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/extension_validation_contract/kashimo_bad_cases_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/extension_validation_contract/obito_bad_cases_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/content_validation_core/formal_registry/scoped_validator_suite.gd bash tests/run_gdunit.sh`
  - `bash tests/run_with_gate.sh`
- 结果：6 个文件改动，formal validator 区域从 1297 行降到 1243 行；代码 diff 为 110 insertions / 160 deletions

## 最近完成：玩家 BattleScreen UI 交互回归补强（2026-04-27）

- 状态：已完成
- 目标：在进入下一阶段开发前，把 player BattleScreen 真实 UI 点击覆盖从 1 条扩到 3 条，挡住按钮信号、popup 弹出、强制换人弹窗的 contract 漂移
- 范围：
  1. `player_battle_screen_contract_suite.gd` 新增 `test_player_battle_screen_wait_button_signal_advances_turn`：`WaitButton` 真实 `pressed.emit()` 推进回合，先断言 `disabled == false` 锁住默认 `gojo_vs_sample` 首回合 wait 合法性前提
  2. 同 suite 新增 `test_player_battle_screen_switch_menu_button_pops_menu_with_options`：`SwitchMenuButton` 点击后弹 `SwitchMenuPopup`，等一帧再读 `get_item_count` 与 `_switch_menu_options.size()`，验证与 `legal_switch_target_public_ids` 数量与顺序一致
  3. 同 suite 新增 `test_player_forced_replace_dialog_invokes_callback_with_selected_id`：直接 instantiate `ForcedReplaceDialog`，open(2 个 public_id, callback) → 用 `find_children("*", "Button", true, false)` 递归找列表内 Button（避免硬编码节点路径）→ 点第二个验证 callback 收到正确 public_id 且 dialog 自动 close
- 验收标准：
  - 新增 3 个 `func test_*` 全过
  - `bash tests/run_with_gate.sh` quick gate 通过
  - 不动 BattleScreen.gd / .tscn / 任何业务逻辑
- 验证结果：
  - `TEST_PATH=res://test/suites/player_battle_screen_contract_suite.gd bash tests/run_gdunit.sh`（5 cases / 0 failures）
  - `bash tests/run_with_gate.sh`（quick gdUnit + boot smoke + suite reachability + architecture + repo consistency + Python lint + sandbox smoke matrix 全绿）
- 不做：未构造完整 KO 局来真实触发 ForcedReplaceDialog（改用单元 contract）；未补 WinPanel 真实点击；未补 ErrorToast 全部 trigger path；未补 UltimateButton disabled 态（在已有 skill case 间接走过）

## 最近完成：玩家审查问题收口（2026-04-27）

- 状态：已完成
- 目标：修复玩家战斗入口审查提出的 session 生命周期、默认策略、sandbox 日志门禁、BattleScreen 职责膨胀与玩家手册索引问题
- 范围：
  1. `PlayerBattleSession.start()` 拒绝重复启动，避免覆盖 `session_id` 后泄露旧 manager session
  2. `PlayerBattleSession.close()` 返回 close envelope，manager close 失败时保留当前 session 状态；`BattleScreen` 调用点检查 close 结果
  3. `PlayerDefaultPolicy` 支持 switch-only legal action，玩家 MVP 的 P2 policy 不再忽略合法换人
  4. `tests/check_sandbox_smoke_matrix.sh` 对 sandbox catalog 导出日志执行 engine error / warning 扫描
  5. `BattleScreen.gd` 抽出 `BattleScreenViewRenderer.gd` 负责卡片、替补、颜色与文本解析渲染，主控制器降到 600 行以内
  6. `docs/rules/README.md` 接入 `player_quick_start_v2.md` 文档入口
- 验收标准：
  - 玩家 session 契约覆盖重复 start、close 失败透传与 switch-only policy
  - 玩家 BattleScreen 契约仍可推进按钮指令并渲染日志
  - quick gate 与 sandbox smoke matrix 通过
- 验证结果：
  - `TEST_PATH=res://test/suites/player_battle_session_contract_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/player_battle_screen_contract_suite.gd bash tests/run_gdunit.sh`
  - `bash tests/check_sandbox_smoke_matrix.sh`
  - `bash tests/run_with_gate.sh`
- 提交：`fix: close player review findings`

## 最近完成：模块复审 round 1 收口四阶段（2026-04-26）

- 状态：已完成
- 目标：按 `docs/records/project_review_2026-04-26_module_round_1.md` 的四阶段计划，先 fail-fast 与 sandbox 边界，再测试基建与 helper 模块化，避免遗留无声跳过与跨层耦合
- 范围：
  1. 阶段 1：`payload_damage_runtime_service` 公式分支 owner 丢失改为 `INVALID_STATE_CORRUPTION` fail-fast；`payload_rule_mod_handler._resolve_rule_mod_owner` 区分"target invalid 合理跳过"与"unit/chain_context 缺失 corruption"两种路径，后者 fail-fast；补 `payload_execution_contract_suite` 三条负路径回归
  2. 阶段 2：`BattleSandboxController.get_state_snapshot` 移除 live `BattleSetup` 引用泄露；`SandboxSessionCoordinator.bootstrap_scene` 在 close 失败时显式 fail-fast；`_exit_tree` 在 close_runtime 失败时 printerr；`SandboxViewCharacterCardsRenderer.render` / `_character_options` 改为 pure 渲染，错误以 render result 形式上抛，由 controller 写 state
  3. 阶段 3：`tests/check_suite_reachability.sh` 增 `func test_*` 正则检查，禁止哑 suite 默默通过；评估 `manual_flow_suite` 与 `sandbox_smoke_matrix`，结论是 GUI 真点击与 headless full run 双轨覆盖不同维度，保留现状
  4. 阶段 4：`manual_battle_scene_support` 收回 context / drive 转发壳到单文件；删除 `manual_battle_submit_full_run.gd`，`manual_battle_full_run.gd` 成为唯一 headless 整局入口；`SampleBattleFactoryFormalAccess._normalize_path` 与 `SampleBattleFactoryBaseSnapshotPathsService.normalize_res_path` 统一调用 `ResourcePathHelper.normalize`
- 验收标准：
  - quick / extended sandbox smoke 与 gate 均通过
  - `payload_execution_contract_suite` 新增 fail-fast 用例 PASSED
  - `manual_flow_suite` / `demo_replay_suite` PASSED，验证 helper 合并未破坏 GUI 路径
- 验证结果：
  - `TEST_PATH=res://test/suites/payload_execution_contract_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/manual_battle_scene/manual_flow_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/manual_battle_scene/demo_replay_suite.gd bash tests/run_gdunit.sh`
  - `bash tests/check_boot_smoke.sh`
  - `bash tests/check_suite_reachability.sh`
  - `bash tests/check_sandbox_smoke_matrix.sh`
  - `bash tests/run_with_gate.sh`
  - `bash tests/run_extended_gate.sh`
- 提交：`0b80aa7 fix: fail-fast on missing owner in damage formula and rule_mod payloads`、`0103362 refactor: tighten sandbox boundary on snapshot, close, and view rendering`、`a30caec test: forbid empty gdunit suites with no func test_*`、`853adcb refactor: collapse helper layers and unify resource path normalization`

## 最近完成：codex follow-up refactor v5 收口（2026-04-26）

- 状态：已完成
- 目标：落实 `/Users/xuyicheng/.windsurf/plans/codex-followup-refactor-v5-19c179.md` 剩余优化，按批次提交推送，并保持 quick / extended / full 验收入口可用。
- 范围：
  1. B/C/D 收口：精简 docs gate wording 镜像、拆 formal baseline catalog 污染面、把 `SampleBattleFactory` 主入口拆到 runtime graph 与 facade，保留外部 API 签名。
  2. E 收口：formal source 由单文件拆为 runtime / delivery descriptor，`00_shared_registry.json` 拆为 shared matchups / capabilities；移除 per-character `required_test_names / design_needles / adjustment_needles` 治理字段，改用设计稿结构章节、调整记录日期章节、suite 可达性和 surface smoke 技能引用校验。
  3. 同步脚手架、draft readiness、registry export、delivery registry fixture、schema/checklist/decision 文档。
- 验收标准：
  - `SampleBattleFactory` 主文件保持 ≤ 100 行，公开 API 不变。
  - 单条 formal runtime/delivery descriptor 保持小文件，manifest / capability catalog 只由 source 导出。
  - quick / extended / full sandbox smoke 与默认/extended gate 均通过。
- 验证结果：
  - `bash tests/sync_formal_registry.sh`
  - `bash scripts/check_formal_character_draft_ready.sh <temp-draft-dir>`（临时草稿模拟通过）
  - `bash tests/check_repo_consistency.sh`
  - `bash tests/check_suite_reachability.sh`
  - `bash tests/check_python_lint.sh`
  - `git diff --check`
  - `bash tests/run_with_gate.sh`
  - `SANDBOX_SMOKE_SCOPE=extended bash tests/check_sandbox_smoke_matrix.sh`
  - `SANDBOX_SMOKE_SCOPE=full bash tests/check_sandbox_smoke_matrix.sh`
  - `bash tests/run_extended_gate.sh`
- 提交：`37e40cc refactor: slim factory facades and docs gates`、`06a1ed2 refactor: split formal source into runtime and delivery descriptors`、`0e7a300 test: align formal delivery fixtures with split descriptors`

## 最近完成：项目复审三阶段（2026-04-26）

- 状态：已完成
- 目标：基于全项目复审，按"快赢 → 中等重构 → 长期方向"三阶段收口
- 范围：
  1. 阶段 A：`SandboxViewPresenter._character_options` manifest 错误透传到 `state.error_message`；`SandboxSessionBootstrapService.dispose` 与 `BattleSandboxController.player_ui_mode` 三处 `has_method` 冗余收窄；`decisions.md` 补 baseline-only API 容忍 formal failure 的边界条款
  2. 阶段 B1：拆 `sandbox_view_presenter.gd`，提取 `sandbox_view_palette.gd` / `sandbox_view_character_cards_renderer.gd` / `sandbox_view_action_buttons_renderer.gd` 三个适配器，主 presenter 只剩调度、布局、replay 控件、结果格式化
  3. 阶段 B2：在 `content_snapshot_formal_character_validator_base.gd` 加 `_validate_single_payload_effect` 共享 helper，gojo / sukuna / kashimo / obito 共 9 处「require_effect → effect_contract → extract_single_payload → expect_payload_shape」重复 pattern 收口；validator 文件净减 102 行
- 验收标准：
  - quick gate（gdunit + 架构 + repo + boot smoke + sandbox smoke matrix）全通过
  - bad_cases 测试不破坏（4 个角色 19 cases）
  - `has_method` 出现次数（架构闸门口径）按预期下降
- 验证结果：`bash tests/check_gdunit_gate.sh`（73 cases / 0 failures）、`bash tests/check_architecture_constraints.sh`、`bash tests/check_repo_consistency.sh`、`bash tests/check_boot_smoke.sh`、`bash tests/check_sandbox_smoke_matrix.sh`、4 个 bad_cases suite 全过
- 提交：`93ed78d fix: surface manifest errors on character select page`、`333b43d refactor: split sandbox view presenter into renderers`、`f82fb0c refactor: extract single payload effect helper for formal validators`

## 后续方向：项目复审 C 阶段（2026-04-26）

- 状态：进行中
- 目标：在主线稳定基础上，把本次复审里"长期"维度的事项按节奏推进，不做一次性大改
- 候选项（按优先级，影响越大越靠前）：
  1. 已完成：validator 共享 helper 二期，把 payload target 与 apply_effect target 高频 pattern 抽到 base；多 payload 与动态 contract 路径保留显式验证
  2. 已完成：sandbox UI 响应式，选择页窄屏单列，战斗页用 `ScrollContainer + HFlowContainer` 兜底三栏换行
  3. 已完成：README 行数强校验放宽，README 只保留运行时 `GDSCRIPT_LINE_STATS` 入口，旧 helper 已删除
  4. 已完成：Formal 角色 suite 进一步往 capability 驱动矩阵收口，以 `formal_character_capability_catalog` 输出的 capability 列表反推抽样 suite，并把矩阵 contract 提到 quick
  5. macOS 26.4.1 + Godot 4.6.1 兼容性观察：当前依赖 godot 默认 server (-s) 模式不卡 NSApplication 事件循环；如出现回退迹象，再评估给 `tests/run_gdunit.sh` 加 macOS-only `--ignoreHeadlessMode` 分支（注意 UI 测试必须保留输入事件）
- 节奏：每个候选项独立小阶段（目标 / 范围 / 验收 / 验证一组），中间接入新角色或新功能不阻断
- 暂不做：删除现有 fail-fast 路径、删除现有测试 suite、更换 godot 版本

## 最近完成：项目问题收口三阶段（2026-04-25）

- 状态：已完成
- 目标：先让 Sandbox 可见 matchup 汇总对 formal catalog 错误 fail-fast，再重做 Sandbox UI，最后用 manifest 驱动 matrix suite 删除重复角色测试壳
- 范围：
  1. `SampleBattleFactory.available_matchups_result()` 遇到 formal catalog 加载失败直接返回错误，baseline setup、legacy demo 与 baseline-only setup snapshot 继续独立
  2. Sandbox 选择页改成角色卡网格，战斗页改成双方角色卡、中央战况、底部行动区的稳定布局
  3. formal 角色 snapshot / manager public / manager blackbox 合并为 manifest 驱动 matrix suite，并清理重复 per-character 壳
- 验收标准：
  - formal catalog 失败会阻断 Sandbox 可选列表加载并暴露错误
  - 窄桌面窗口下选择页和战斗页不空白、不挤压核心操作
  - 删除重复壳后 suite reachability、架构约束、repo consistency、quick gate 和 extended gate 通过
- 验证结果：阶段 1 已通过 `TEST_PATH=res://test/suites/sample_battle_factory_contract_suite.gd bash tests/run_gdunit.sh`、`bash tests/check_sandbox_smoke_matrix.sh`、`bash tests/check_repo_consistency.sh`；阶段 2 已通过 `TEST_PATH=res://test/suites/manual_battle_scene/manual_flow_suite.gd bash tests/run_gdunit.sh`、`TEST_PATH=res://test/suites/battle_sandbox_launch_config_contract_suite.gd bash tests/run_gdunit.sh`、`bash tests/check_boot_smoke.sh`、`bash tests/check_sandbox_smoke_matrix.sh`；阶段 3 已通过 `bash tests/sync_formal_registry.sh`、`bash tests/check_suite_reachability.sh`、`bash tests/check_architecture_constraints.sh`、`bash tests/check_repo_consistency.sh`、`bash tests/run_with_gate.sh`（73 test cases / 0 failures）和 `bash tests/run_extended_gate.sh`（381 test cases / 0 failures）

## 最近完成：项目问题修复与测试分层（2026-04-25）

- 状态：已完成
- 目标：修复 strict seed、玩家选角硬编码、脚手架 wrapper、draft readiness 空目录与 CI 文档漂移，并把测试入口分成 quick / extended / full
- 范围：
  1. CLI `seed` / `battle_seed` 保留原始字符串进入 strict normalize，非法值触发 `BATTLE_SANDBOX_FAILED`
  2. 玩家选角页从 formal manifest 与可见 matchup 交集派生角色卡，新增角色不再改硬编码卡片列表
  3. 新角色脚手架不再生成 `{pair_token}_suite.gd` wrapper，draft readiness 只接受有 `func test_*` 的真实 suite
  4. draft readiness 要求非 `fields` 的 content root 至少含 `.tres`
  5. `tests/run_with_gate.sh` 默认 quick gate，新增 `tests/run_extended_gate.sh`，`TEST_PROFILE=quick|extended|full` 统一控制分层
- 验收标准：
  - 非法 CLI seed 在 strict 启动路径失败，UI 控件的非 strict 归一化不变
  - 选角卡数量等于当前可见 formal setup matchup 数
  - 脚手架和 readiness 不再复活 wrapper suite
  - quick gate 与 extended gate 都可本地验证
- 验证结果：`seed=bad / seed=-99 / seed=0` strict CLI 均输出 `BATTLE_SANDBOX_FAILED`；`battle_sandbox_launch_config_contract_suite.gd`、`manual_battle_scene/manual_flow_suite.gd`、`bash scripts/check_formal_character_draft_ready.sh`、`bash tests/run_with_gate.sh` 与 `bash tests/run_extended_gate.sh` 均通过；临时脚手架验证确认不生成 `{pair_token}_suite.gd`，空的非 `fields` content root 会失败

## 最近完成：测试面压缩与空 suite 防护（2026-04-25）

- 状态：已完成
- 目标：收口测试代码比例偏高的问题，删除没有真实断言价值的聚合 wrapper，并避免 gdUnit 空跑被误判为通过
- 范围：
  1. 删除 39 个仅转发 `register_tests` 的 wrapper suite 及对应 `.gd.uid`
  2. formal source descriptor、生成 manifest / capability catalog、repo gate 和设计文档全部改为引用真实 suite 路径
  3. 四名正式角色的 snapshot suite 合并为每个角色 1 个公开测试入口
  4. 四名正式角色的 manager smoke / blackbox suite 合并为每个文件 1 个公开测试入口，保留原场景断言
  5. `tests/run_gdunit.sh` 对不存在路径、空 suite、缺失 XML、0 testcase XML 直接失败
- 验收标准：
  - 删除 wrapper 后 manifest suite 路径仍可达
  - 旧 wrapper 路径不能被误判为通过
  - 全量 gate 通过，且测试数量下降但关键覆盖保留
- 验证结果：`bash tests/run_with_gate.sh` 通过，`388 test cases / 0 failures`；当时定向验证角色 smoke / blackbox / snapshot suite 通过；`does_not_exist_suite.gd` 与已删除的 `gojo_suite.gd` 均按预期失败

## 最近完成：玩家战斗 UI 首版（2026-04-25）

- 状态：已完成
- 目标：提供简单、统一、简洁典雅的玩家 UI，覆盖选人、进入战斗和战斗结算流程
- 范围：
  1. `BattleSandbox` 从调试界面改为玩家界面，启动先进入四角色预设对局选择页
  2. 战斗页完整展示双方 active/team、HP/MP/UP、类型、效果、待选边、合法动作、指令和事件记录
  3. 结算页展示胜负摘要、最终双方状态，并提供再来一局与返回选择
  4. 四个角色新增原创 SVG 头像资产，以不同色彩、轮廓和符号区分角色形象
  5. 手动战斗 UI 回归测试补充选人页启动检查，并保留原有真实点击战斗流程覆盖
- 验收标准：
  - 启动后能看到角色选择页，并可选择预设角色进入战斗
  - P1 手动、P2 policy 的默认对局可提交行动并推进到结算
  - 结算页能返回选择或按当前配置重开
  - 本地门禁通过
- 验证结果：`bash tests/run_with_gate.sh` 通过，`406 test cases / 0 failures`，boot smoke、architecture、repo consistency、Python lint 与 sandbox smoke matrix 均 clean

## 最近完成：项目审查问题收口（2026-04-25）

- 状态：已完成
- 目标：修复项目全量审查中确认的门禁、文档和仓库卫生问题
- 范围：
  1. engine log gate 纳入普通 `ERROR:` 扫描，并只对白名单内的 Godot shader cache 启动噪声做精确放行
  2. 本地总闸门纳入 Python lint，与 CI 的 `ruff` 检查对齐
  3. `.gitignore` 补 `.DS_Store`，并清理当前工作区系统文件噪声
  4. 统一测试 support helper 行数阈值文档到实际 gate 口径：`220..250` 预警，`>250` 失败
  5. 清理 Python lint 暴露的未使用 import
- 验收标准：
  - 本地 `tests/run_with_gate.sh` 覆盖 gdUnit、boot smoke、suite reachability、architecture、repo consistency、Python lint 和 sandbox smoke matrix
  - `.DS_Store` 不再污染工作区
  - 文档阈值与实际 gate 保持一致
- 验证结果：`bash tests/run_with_gate.sh` 通过，`405 test cases / 0 failures`，Python lint、repo consistency、architecture constraints 与 sandbox smoke matrix 均 clean

## 最近完成：扩角前基础架构稳固审阅修复（2026-04-25）

- 状态：已完成
- 目标：在接入新正式角色前，修复本轮审阅发现的基础架构、自动化和 fail-fast 风险
- 范围：
  1. 修复 repo gate 运行阻断：补 `repo_consistency_formal_character_gate_pairs.py` 缺失 `re` import，放宽 architecture helper needle 以兼容返回类型标注，并同步 README 行数与缺失 `.gd.uid`
  2. formal pair smoke suite 从逐角色硬编码函数改为派生 case 循环，新增角色后不再为每个 directed pair 手写测试函数
  3. sandbox launch config contract 从 manifest/runtime entries 派生推荐 matchup 顺序，移除当前四个正式角色名单硬编码
  4. `export_formal_registry_views.gd` 对 source descriptor 的 `test_only` 执行严格 bool 校验，避免字符串被布尔转换吞掉
  5. pair interaction case 派生器校验 battle seed 为正整数且全局唯一；formal gate 同步检查重复 seed，并补 seed 负向用例
- 验收标准：
  - 新增角色主要改 source descriptor 与对应内容，不需要同步扩写 pair smoke / sandbox 推荐测试名单
  - source descriptor 类型错误和 pair interaction seed 冲突会在本地 gate 或运行态 catalog 构建时直接失败
  - repo consistency、architecture constraints、定向 GdUnit 与最终总 gate 通过
- 验证结果：定向 GdUnit、formal gate、repo consistency、architecture constraints 已通过；`bash tests/run_with_gate.sh` 通过，`405 test cases / 0 failures`，boot smoke、suite reachability、architecture、repo consistency 与 sandbox smoke matrix 均 clean

## 最近完成：架构审阅第四轮修复（2026-04-25）

- 状态：已完成
- 目标：修复第四轮架构审阅报告中的全部优先级问题
- 范围：
  1. A1+B1: `PairInteractionBuilder` 中 ~125 行 pair interaction case 派生逻辑委托给 `CaseBuilder`，消除与 `FormalCharacterPairInteractionCaseBuilder` 的代码重复；清理 `ManifestViews` 中未使用的 `PairInteractionCaseBuilderScript` import 和 `_pair_interaction_case_builder` 实例
  2. A2+B3: `FormalCharacterCapabilityCatalog` 加实例级缓存（`_cached_entries_result`），与 `FormalRegistryContracts` 模式一致；`find_entry_result` / `capability_ids_result` 不再每次重新读取 JSON
  3. A3: `_build_pair_maps_result` 中 `pair_token_by_character.values().has()` O(n) 查重改为 `seen_pair_tokens` Dictionary O(1) 查重
  4. B2: scaffold `_build_interaction_spec_placeholders` 的 `base_seed` 从硬编码 3001 改为扫描已有 source descriptor 最大 seed + 2，避免连续 scaffold 时 seed 碰撞
- 验收标准：行为不变，结构更清晰，性能和安全性改善

## 最近完成：架构审阅第三轮清理（2026-04-24）

- 状态：已完成
- 目标：清理残留分支，修复架构审阅报告中所有优先级项目
- 范围：
  1. 合并 `codex/formal-automation-polish` 分支到 main，解决全部冲突，删除远端分支
  2. A2: `BattleState` unit 查找加 Dictionary 索引（O(1) 代替 O(n*m)）
  3. A3: `BaselineLoader` static cache 在 `SampleBattleFactory._init()` 时 invalidate
  4. B6: `ContentSchema` 的 `MANAGED_ACTION_TYPES` / `ALWAYS_ALLOWED_ACTION_TYPES` 从 mutable `static var` 改为 `static func`
  5. B8: Kashimo validator 拆分 ultimate domain 到子 validator（418→319+114 行）
  6. B1: 为 22 个缺返回类型标注的函数补 `-> Variant`
  7. B7: sandbox envelope 非标准 `summary` 字段收进 `data`
  8. B5: SampleBattleFactory helper 评估，调整软上限为 10 个
  9. B3/B2/B4: has_method / Variant 收窄 / ok_result codestyle 方向记录到 decisions.md
  10. C1: `BattleState.to_stable_dict` 缺字段注释
  11. C3: dedupe key 管道符约束注释
  12. C6: CI 加 Python lint（ruff）
- 验收标准：全部修复项落地、提交、推送

## 最近完成：架构审阅第二轮优化（2026-04-24）

- 状态：已完成
- 目标：修复架构审阅中发现的结构性和防御性问题
- 范围：
  1. `manifest_views.gd` 拆分 pair interaction 派生逻辑到 `formal_character_manifest_pair_interaction_builder.gd`（views 471→178 行，builder 309 行）
  2. `pair_token` 不含下划线约束：脚手架 + manifest loader 双重校验
  3. `BaselineLoader` 加 static cache 避免重复 manifest JSON 解析
  4. Gate stale needle 检查从硬编码列表改为正则模式，新角色自动覆盖
  5. decisions.md 补充三条规范：validator 拆分阈值（400 行）、factory helper 上限（5 个）、test/ vs tests/ 约定
  6. ResultEnvelope wrapper 模式确认为可接受约定并记录
- 验收标准：行为不变，结构更清晰，防御性校验更完整

## 最近完成：项目架构审阅问题清理（2026-04-24）

- 状态：已完成
- 目标：修复架构审阅中发现的 7 项代码质量问题
- 范围：
  1. 澄清 `PayloadExecutor._leave_effect_guard` dedupe key 生命周期意图（注释）
  2. 澄清 `ContentSnapshotCache` signature 路径列表的维护约定（注释）
  3. 提取 `ResourcePathHelper`，消除 6 处 `normalize_resource_path` 重复实现
  4. `FormalRegistryContracts.load_contracts_result()` 加实例级缓存，避免重复读文件
  5. `ContentSnapshotFormalCharacterRegistry` 返回格式统一为 `ResultEnvelopeHelper` 标准 envelope
  6. Gojo/Sukuna/Kashimo validator 中可替代的内联 effect contract dict 改为 baseline 引用
  7. `SampleBattleFactory.dispose()` 提取 `_nullify_links` 简化循环引用清理
- 验收标准：行为不变，代码重复减少，格式统一
- 验证：待闸门验证

## 最近完成：Formal 草稿晋升前检查入口（2026-04-24）

- 状态：已完成
- 目标：给新角色脚手架草稿增加晋升前的独立检查，避免手工搬文件时把占位符或缺文件带入正式目录
- 范围：
  1. 新增 `scripts/check_formal_character_draft_ready.py/.sh`
  2. 检查 source draft、baseline、validator、suite、设计文档和 pair runner 草稿是否齐全
  3. 检查 `FILL_IN / FORMAL_DRAFT_ / draft_marker / TODO: implement / interaction placeholder` 等占位符，以及 live 目标路径冲突
  4. 在脚手架输出、正式角色接入清单和当前工作流里记录入口
- 验收标准：
  - 无草稿时脚本可安全跳过
  - 有草稿但未填完占位符时脚本失败
  - repo consistency gate 继续锁住文档入口

## 最近完成：Pair interaction 顺序归属合同显式化（2026-04-24）

- 状态：已完成
- 目标：把 manifest 顺序承担 pair interaction ownership 的隐含规则写入正式文档，并用 gate 防止实现/文档漂移
- 范围：
  1. `formal_character_delivery_checklist.md` 明确新角色默认追加到 manifest 末尾，不能为排序美观重排既有正式角色
  2. `battle_content_schema.md` 与 `decisions.md` 同步记录 manifest 角色顺序是 pair interaction ownership 的稳定输入
  3. repo consistency gate 同时锁文档措辞与 `formal_character_pair_interaction_case_builder.gd` 的 earlier-character 约束
- 验收标准：
  - 后续扩角时不会误把 manifest 顺序当纯展示排序
  - gate 能发现 pair ownership 实现或规范文字被移除

## 最近完成：Sandbox 推荐入口去角色硬编码（2026-04-24）

- 状态：已完成
- 目标：把扩角前审阅发现的 sandbox 推荐列表和 quick smoke 手写角色名移到 manifest 派生
- 范围：
  1. `BattleSandboxLaunchConfig.recommended_matchup_ids()` 从 formal runtime entries 的 `formal_setup_matchup_id` 派生推荐 matchup，并追加 `sample_default`
  2. 命令行启动配置默认带 `strict_config=true`，拼错 matchup / mode / seed / control mode 直接暴露错误
  3. `tests/check_sandbox_smoke_matrix.sh` 的 quick 集合读取 sandbox smoke catalog 导出的推荐 matchup，不再硬编码当前四个正式角色
- 验收标准：
  - 新角色使用自定义 `formal_setup_matchup_id` 时，sandbox 推荐排序和 quick smoke 自动跟随 manifest
  - 默认 CLI/debug 启动不再静默吞掉非法配置
  - launch-config suite 与 sandbox smoke matrix 通过

## 最近完成：扩角前审阅问题修复（2026-04-24）

- 状态：已完成
- 目标：修复扩角前架构审阅确认的问题，降低新增角色后的自动化误判和验证成本
- 范围：
  1. `manual_battle_full_run.gd` / `manual_battle_submit_full_run.gd` 不再预先吞掉非法 `BATTLE_SEED`，strict config 统一负责失败判定
  2. `tests/check_sandbox_smoke_matrix.sh` 增加 `SANDBOX_SMOKE_SCOPE=quick|full`，日常 gate 默认 quick，按需 full 覆盖全部可见 matchup
  3. `demo_profile_ids_result` contract 不再写死当前 profile 全集，只锁默认优先与剩余稳定排序
  4. 文档同步 submit 入口真实覆盖口径，避免把重复脚本误读成额外行为面
- 验收标准：
  - 非法 sandbox seed 在 strict helper 路径失败
  - 日常 sandbox smoke 不随 formal directed matchup 二次方增长
  - 新增 demo profile 不会被旧单测硬编码阻断
  - `bash tests/run_with_gate.sh` 通过
- 验证结果：`git diff --check`、非法 `BATTLE_SEED=-99` strict 反向检查、`bash tests/check_repo_consistency.sh`、`bash tests/check_sandbox_smoke_matrix.sh` 与 `bash tests/run_with_gate.sh` 均通过；总 gate 为 `425 test cases / 0 failures`

## 最近完成：formal 接线自动化与 Sandbox smoke 动态化（2026-04-22）

- 状态：已完成
- 目标：继续扩角前，把 formal 角色接入末端的手工步骤和 sandbox smoke 的硬编码名单进一步收口
- 范围：
  1. `FormalCharacterManifestViews` 默认自动派生 `<pair_token>_vs_sample` matchup，formal setup 不再强依赖手工改 `00_shared_registry.json`
  2. `tests/support/formal_pair_interaction/scenario_registry.gd` 改为自动发现 `tests/support/formal_pair_interaction/*_cases.gd`，新增角色不再手工注册 scenario runner
  3. `scripts/new_formal_character.py` 同步改为生成 `build_runners()` 壳子，并把 shared matchup / pair interaction 说明改成新的自动化流程
  4. `tests/check_sandbox_smoke_matrix.sh` 改为动态覆盖全部可见 matchup、默认模式变体、真实 submit 路径和全部 demo profile
  5. 补 `demo_profile_ids_result()`、sandbox smoke catalog helper、pair runner key export helper 与对应 contract/gate 对齐
- 验收标准：新增角色默认接线步骤更少，sandbox 主 smoke 自动跟随当前 manifest/demo 真相，现有 gate 与主回归继续通过
- 验证结果：`bash tests/run_with_gate.sh` 通过，`421 test cases / 0 failures`；动态 sandbox smoke 已覆盖全部可见 matchup、默认模式变体、真实 submit 路径和全部 demo replay

## 最近完成：扩角前架构审阅问题收口（2026-04-24）

- 状态：已完成
- 目标：接入新角色前，把审阅发现的脚手架、运行时配置、缓存签名和 manifest 体量风险收口
- 范围：
  1. `scripts/new_formal_character.py` 遇到坏 descriptor 直接失败；未完成 baseline / validator / suite / design doc 统一进入 `scripts/drafts/` 镜像路径
  2. formal live gate 扫描 `FORMAL_DRAFT_` / `draft_marker`，并阻断 live validator 中残留的 `pass`
  3. `BattleSandboxLaunchConfig` 新增 strict normalize 入口；测试与脚本 smoke 入口启用 strict config，非法 matchup / mode / seed / control mode 不再静默改成默认值
  4. `ContentSnapshotCache` 签名依赖缺失时直接失败，并暴露具体缺失路径；缓存签名继续覆盖 formal source / baseline / capability / validator 输入
  5. `formal_character_manifest_views.gd` 抽出 pair interaction case builder，主文件从 502 行降到 369 行
  6. `tests/godot_headless_env.sh` cleanup 后清理 Godot headless 环境变量，避免同 shell 重复 setup 指向已删除目录
- 验收标准：
  - 新角色草稿不会污染正式目录
  - 测试入口不会把拼错的 sandbox 配置当默认局跑成功
  - 内容快照签名依赖缺失不再被弱签名掩盖
  - manifest views 不再触发架构体量预警
- 验证结果：分批定向 gdUnit、`check_repo_consistency`、`check_architecture_constraints`、`check_sandbox_smoke_matrix` 已通过；最终总 gate 见本轮提交记录

## 最近完成：扩角前文档口径修正与脚手架增强（2026-04-22）

- 状态：已完成
- 目标：统一文档口径冲突，增强脚手架覆盖 pair interaction 层，降低下一个正式角色接入的手工成本
- 范围：
  1. 修正 `decisions.md` pair 覆盖模型描述：从"允许同 pair 多 case"改为"每个无序 pair 恰好 1 条 spec"，与 gate 和 checklist 保持一致
  2. 修正 `formal_character_delivery_checklist.md` SampleBattleFactory 条目：明确已有动态入口 `build_formal_character_setup_result(character_id)`，不需要手动加构局方法
  3. 修正 `project_folder_structure.md`：删掉不存在的 `assets/` 目录及相关约束
  4. 增强 `scripts/new_formal_character.py`：
     - 新增 `collect_existing_characters()` 自动发现已有正式角色
     - `generate_source_descriptor()` 自动生成 `owned_pair_interaction_specs` 占位（含所有已有角色）
     - 新增 `generate_interaction_cases()` 生成 pair interaction runner 壳子
     - main 流程扩充到 8 步，第 7 步生成 interaction cases 文件，第 8 步打印 scenario_registry.gd 注册提示
     - checklist 输出补充 pair interaction 层的完整操作说明
- 验收标准：文档口径统一，脚手架幂等无破坏，现有闸门不受影响
- 验证结果：`bash tests/run_with_gate.sh` 通过，`421 test cases / 0 failures`；repo consistency / formal pair coverage / 文档入口对齐 gate 全部通过

## 最近完成：提取 TurnExpiryDecrementHelper 消除 turn 阶段重复代码（2026-04-22）

- 状态：已完成
- 目标：消除 TurnStartExpiryService 与 TurnEndPhaseService 之间的 4 个重复方法，补齐 `_unit_has_persistent_effect` 缺失的 UnitState 类型标注
- 范围：
  - 新增 `src/battle_core/turn/turn_expiry_decrement_helper.gd`，承载 `collect_effect_decrement_owner_ids`、`decrement_effect_instances_and_log`、`decrement_rule_mods_and_log`、`_unit_has_persistent_effect` 共 4 个方法
  - 重构 `turn_start_expiry_service.gd` 和 `turn_end_phase_service.gd`，改为委托 helper
  - 更新 README 代码行数统计
- 验收标准：闸门全通过，行为不变
- 验证结果：419 test cases / 0 failures，所有架构约束和 sandbox smoke matrix 通过

## 最近完成：Sandbox 正式角色覆盖补齐（2026-04-21）

- 状态：已完成
- 目标：在继续下一个正式角色开发前，补齐 BattleSandbox 推荐对局和 smoke matrix 对已交付角色的可见覆盖
- 范围：
  1. `BattleSandboxLaunchConfig` 推荐 matchup 顺序加入 `obito_vs_sample`
  2. `tests/check_sandbox_smoke_matrix.sh` 固定补跑 `obito_vs_sample + manual/policy` 与 `sukuna_setup + manual/policy`
  3. README 与 launch config contract suite 同步到新的推荐顺序和 smoke 覆盖面
- 验证：
  - `TEST_PATH=res://test/suites/battle_sandbox_launch_config_contract_suite.gd bash tests/run_gdunit.sh`
  - `bash tests/check_sandbox_smoke_matrix.sh`
  - `bash tests/run_with_gate.sh`

## 最近完成：深度审查 9 项问题修复（2026-04-21）

- 状态：已完成
- 目标：修复仓库深度审查确认的 3 个阻断级 + 6 个重要级问题
- 范围：
  1. （阻断）`turn_start_phase_service` 在 expiry phase 后补 `faint_resolver.resolve_faint_window` + victory check
  2. （阻断）`sample_battle_factory_baseline_matchup_catalog.available_matchups_result()` formal catalog 失败时 graceful 降级，不再拖死 baseline/demo
  3. （阻断）`check_sandbox_smoke_matrix.sh` 标注"manual 路径实际由 auto-policy 驱动"已知限制
  4. （重要）`replay_runner_output_helper` + `replay_output` 的 `event_log` / `battle_result` 改为 deep copy，断开 live 引用
  5. （重要）`field_apply_service` 在取 `challenger_field_definition` 后立刻判空，fail-fast
  6. （重要）`effect_queue_service` tie group 分配 random roll 前按 `event_id` 排序，消除收集顺序对 RNG 的影响
  7. （重要）`sample_battle_factory_baseline_matchup_catalog` 三个 override 函数各归各位，不再互相污染
  8. （重要）`effect_instance_dispatcher` dangling owner 从 `continue` 改为 fail-fast 返回 `INVALID_STATE_CORRUPTION`
  9. （重要）`content_snapshot_effect_validator._uses_effect_scope_unit_target` 添加 `ForcedReplacePayload`
- 验证：`bash tests/run_with_gate.sh`

## 最近完成：审阅问题修复收口（2026-04-20）

- 状态：已完成
- 目标：把本轮详细审查确认的工程问题直接修回脚本、gate 与记录
- 范围：
  1. 修复 `tests/run_gdunit.sh` 的 `GODOT_BIN` 闭合问题
  2. 修复 formal scaffold 的 source index 与 drafts 脱节问题
  3. 把 tests support helper 体量 gate 调回当前决策记录约定
- 修复内容：
  1. `tests/run_gdunit.sh` 改为统一校验并复用 `GODOT_BIN_PATH`，不再在收尾日志复制步骤偷偷回退到裸 `godot`
  2. `scripts/new_formal_character.py` 的 `next_source_index()` 现在同时扫描 `config/formal_character_sources/` 与 `scripts/drafts/`，避免连续 scaffold 时重复占号
  3. `tests/check_architecture_constraints.sh` 把 tests support helper 阈值恢复到 `220..250` 预警、`>250` 失败，重新和 `docs/records/decisions.md` 对齐
- 验证：
  - `GODOT_BIN="$(command -v godot)" TEST_PATH=res://test/suites/composition_container_contract_suite.gd bash tests/run_gdunit.sh`
  - `python3 scripts/new_formal_character.py review_probe_alpha "审查探针A"`
  - `python3 scripts/new_formal_character.py review_probe_beta "审查探针B"`
  - `bash tests/check_architecture_constraints.sh`
  - `bash tests/run_with_gate.sh`

## 最近完成：长期工程化重构波次（2026-04-19）

- 状态：已完成
- 总体目标：项目定位从"原型期"升级为长期工程，清理过度工程化的形式噪声，保留工程严谨性
- 分阶段结果：

| Stage | 内容 | 状态 |
|---|---|---|
| 0 | 统一定位与活跃规则基线 | 已完成 |
| 1 | composition 盘点 + 目标图冻结 + 错误体系设计 + payload dispatch 决策 | 已完成 |
| 2 | composition 主链路收缩（81→65 slot, 16 helper 下沉） | 已完成 |
| 3 | 错误体系统一（B/C 类内联/重命名） | 已完成 |
| 4 | 测试修复 + 死代码清理 | 已完成 |
| 5 | 测试结构评估（降级保留） | 已完成 |
| 6 | 文档 + gate 合并（降级保留） | 已完成 |
| 7 | 核心类型标注 | 已完成 |

- 验证：`bash tests/run_with_gate.sh` 全通过
- 详细子阶段记录见 `docs/records/archive/tasks_2026-04-19_engineering_overhaul.md`

## 最近完成：代码审阅修复（2026-04-19）

- 状态：已完成
- 目标：审阅当前实现并修复发现的问题
- 修复内容：
  1. `battle_core → composition` 逆向依赖：文档标注为受控例外 + architecture gate 增加白名单校验
  2. 核心函数参数类型标注：`battle_core` 119 个文件补齐 `BattleState / BattleContentIndex / ChainContext / QueuedAction / EffectEvent / Command` 的显式类型
  3. 冗余 `.gitkeep` 清理：移除 `content/` 下 7 个已有实际内容的目录中的 `.gitkeep`
- 验证：全部 gate 通过

## 最近完成：gate 修复收口（2026-04-19）

- 状态：已完成
- 目标：修复本轮类型标注后遗留的 gate 失败，恢复主线验证基线
- 修复内容：
  1. 强类型测试替身补齐：`sukuna_setup_skill_runtime_suite`、`field_lifecycle_contract_suite`、`manager_log_and_runtime_contract/replay_guard_failure_suite` 改为继承真实 service / resolver / dispatcher 类型，不再向强类型字段写入裸 `RefCounted`
  2. 期望伤害辅助同步 fake resolver：`tests/support/sukuna_setup_regen_test_support.gd` 新增可注入 `PowerBonusResolver`，保证 delegation contract 测试和运行时走同一套口径
  3. gdUnit warning 清零：`effect_precondition_service`、`payload_executor`、`action_chain_context_builder` 的 ternary 类型不兼容改成显式分支
  4. README 代码规模统计回写到当前真值，修复 repo consistency surface gate
- 验证：
  - `TEST_PATH=res://test/suites/sukuna_setup_skill_runtime_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/field_lifecycle_contract_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/manager_log_and_runtime_contract/replay_guard_failure_suite.gd bash tests/run_gdunit.sh`
  - `bash tests/check_gdunit_gate.sh`
  - `bash tests/run_with_gate.sh`

## 最近完成：formal 自动化审阅问题修复（2026-04-24）

- 状态：已完成
- 目标：修复 formal 自动化接入审阅中确认的问题，暂不拆分 `FormalCharacterManifestViews`
- 范围：
  1. 修复内容快照缓存签名遗漏 formal baseline/source/capability 输入的问题
  2. 收紧新角色 scaffold 的命名校验与 pair interaction 草稿流转
  3. 增加 live scaffold 占位符 gate，避免占位 runner 或 `FILL_IN` 进入正式目录
  4. 清理本地 `.DS_Store` 噪声
- 验收标准：
  - cache signature 会随 formal baseline/source/capability 相关输入变化而变化
  - draft pair interaction runner 不会被 live registry 自动发现
  - live formal 目录中出现 scaffold 占位符时 repo consistency gate 会失败
  - `bash tests/run_with_gate.sh` 通过

## 最近完成：审阅问题补齐（2026-04-20）

- 状态：已完成
- 目标：把 2026-04-19 全部提交复查后确认的问题补齐到代码、gate 和文档
- 修复内容：
  1. manager replay 容器依赖补校验：`BattleCoreManagerContainerService.run_replay_result()` 现在显式校验 `replay_runner`，缺失时返回 `invalid_composition` 并释放临时容器；补了对应 contract suite
  2. sandbox smoke 合同对齐真实 battle contract：`winner_side_id` 只在 `result_type=win` 时要求非空，`draw / no_winner` 必须保持为空
  3. `manual/manual` 主路径补成真实整局回归：`tests/check_sandbox_smoke_matrix.sh` 新增 `gojo_vs_sample + manual/manual` 覆盖，README 与当前阶段基线同步回写
- 验证：
  - `TEST_PATH=res://test/suites/manager_log_and_runtime_contract/replay_guard_summary_suite.gd bash tests/run_gdunit.sh`
  - `bash tests/check_sandbox_smoke_matrix.sh`
  - `bash tests/run_with_gate.sh`

## 最近完成：审阅问题收口（2026-04-20）

- 状态：已完成
- 目标：把复查后确认需要落地的两项工程问题直接收口到代码与记录
- 范围：
  1. 收紧 `container_factory_owner` 的类型边界，去掉 facade 层对裸 `RefCounted` + `has_method("error_state")` 的依赖
  2. 提升 formal validator 共享 helper，收口 Kashimo / Obito 中重复的 payload 断言样板
  3. 不改双轨错误模型，不引入 `BattleState` 索引缓存
- 修复内容：
  1. 新增 `ContainerFactoryOwnerPort`，`BattleCoreComposer.ContainerFactoryPort` 显式继承该 port；manager/container service 不再把 factory owner 写成裸 `RefCounted`
  2. `BattleCoreManagerContainerService` 去掉对 `container_factory_owner.has_method("error_state")` 的鸭子类型分支，统一走显式 port 合同
  3. formal validator 共享 helper 新增按脚本提取 payload、按类型校验 payload、按字段匹配 payload 三个通用方法
  4. Kashimo `amber_contract` 与 Obito `yinyang_dun` 的重复 payload 断言改走共享 helper，保持原合同语义不变
- 验证：
  - `TEST_PATH=res://test/suites/composition_container_contract_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/manager_log_and_runtime_contract/replay_guard_summary_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/content_validation_core/formal_registry/runtime_registry_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/extension_validation_contract/kashimo_bad_cases_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/extension_validation_contract/obito_bad_cases_suite.gd bash tests/run_gdunit.sh`
  - `bash tests/check_architecture_constraints.sh`
  - `bash tests/check_repo_consistency.sh`

## 最近完成：formal 新角色接入脚手架（2026-04-20）

- 状态：已完成
- 目标：降低新正式角色接入的手工成本，为 source descriptor、baseline、validator、test suite 提供模板生成
- 范围：
  1. 新增脚手架脚本 `scripts/new_formal_character.sh`（bash wrapper）+ `scripts/new_formal_character.py`（Python 生成逻辑）
  2. 自动生成：source descriptor、baseline 脚本、validator 脚本、snapshot/runtime/manager smoke 三个 suite 壳子、content 目录占位、设计稿占位
  3. 不改现有 formal 模型、gate、`COMPOSE_DEPS` 边界、battle_core 架构
  4. 生成物为"半成品但合法"：GDScript 可加载、JSON 可解析、不会让 gate 因脚手架自身报结构错误
- 验收标准：
  - 脚手架生成的 `.gd` / `.json` 文件语法合法
  - 脚手架幂等：重复运行不会覆盖已有文件或重复创建 source descriptor
  - 不改任何现有角色时，现有 gate 不受影响
- 用法：`bash scripts/new_formal_character.sh <character_id> <display_name> [--pair-token TOKEN]`

## 最近完成：全面修复与瘦身重构阶段 4 - 测试门禁瘦身（2026-04-26）

- 状态：已完成
- 目标：把 quick/extended 门禁入口改成可声明、可校验的 profile 清单，并清理本地测试产物策略。
- 范围：
  1. 新增 `tests/suite_profiles.json`，显式记录每个 `gdUnit` suite 属于 `quick` 或 `extended`；`manual` 保留给人工复查脚本
  2. `tests/run_gdunit.sh` 改为读取 suite profile 清单，不再内嵌 quick suite 列表
  3. `tests/check_suite_reachability.sh` 增加 suite profile 完整性校验，阻止未分配 profile 的新 suite 混入
  4. formal registry 中偏数据一致性的 `catalog_factory_surface_suite`、`catalog_factory_delivery_alignment_suite` 从 quick 移出，保留在 extended/full
  5. `tests/cleanup_local_artifacts.sh` 覆盖 `reports/gdunit/report_1`、`tmp/`、`__pycache__`、`.ruff_cache`
- 验收标准：
  - quick 仍覆盖 BattleSandbox 主路径、formal runtime、pair smoke、sample factory、replay header 与 domain guard
  - extended/full 仍能跑完整 `res://test` 与 full sandbox smoke
  - suite profile 漂移会被静态 gate 直接拦下
- 验证：
  - `bash tests/check_suite_reachability.sh`
  - `bash tests/check_gdunit_gate.sh`
  - `bash tests/cleanup_local_artifacts.sh`
  - `bash tests/run_extended_gate.sh`

## 最近完成：全面修复与瘦身重构阶段 5 - 文档与最终收口（2026-04-26）

- 状态：已完成
- 目标：完成这轮全面修复与瘦身重构的最终验收，确认 quick、extended、full 三档入口与 sandbox smoke 都保持稳定。
- 范围：
  1. 保持前四阶段改动不再扩散，只做最终验收与记录补充
  2. 复核 `run_with_gate`、`run_extended_gate`、`TEST_PROFILE=full run_with_gate` 三条总入口
  3. 把最终验收结果写回任务记录，方便后续阶段直接沿用当前基线
- 验收标准：
  - `quick`、`extended`、`full` 门禁全部通过
  - full profile 下 `gdUnit` 129 个 suite、390 个用例通过
  - full sandbox smoke matrix 通过，manual/policy、submit_action、demo replay 主路径稳定
- 验证：
  - `bash tests/run_with_gate.sh`
  - `bash tests/run_extended_gate.sh`
  - `TEST_PROFILE=full bash tests/run_with_gate.sh`

## 最近完成：全面修复与瘦身重构阶段 3 - composition 与 Sandbox 低风险瘦身（2026-04-26）

- 状态：已完成
- 目标：收敛 `SampleBattleFactory` override 配置归属，并降低 Sandbox 角色选择页重复构建开销。
- 范围：
  1. `SampleBattleFactory` 持有共享 override 配置，baseline/formal/demo/snapshot helper 改为读取同一个配置对象
  2. 保留现有 facade 方法，不改变外部调用形状
  3. `SandboxViewPresenter` 单次渲染只派生一次 visible matchup 列表
  4. 角色卡只在选择页渲染，并按 visible matchup 与错误信息签名缓存，避免战斗页/结算页重复清空重建
  5. `SandboxViewRefs` 集中声明节点路径常量，减少路径字符串散落
- 验收标准：
  - baseline setup/demo/baseline-only snapshot 仍不依赖 formal manifest
  - formal matchup/角色选择仍能 fail-fast 暴露 manifest/catalog 错误
  - manual scene 与 demo replay smoke 保持可启动、可操作
- 验证：
  - `TEST_PATH=res://test/suites/sample_battle_factory_contract_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/manual_battle_scene/manual_flow_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/manual_battle_scene/demo_replay_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/content_validation_core/formal_registry/catalog_factory_error_suite.gd bash tests/run_gdunit.sh`
  - `bash tests/check_architecture_constraints.sh`
  - `bash tests/check_repo_consistency.sh`

## 最近完成：全面修复与瘦身重构阶段 2 - schema 与 formal 唯一性（2026-04-26）

- 状态：已完成
- 目标：把内容 schema 中会导致运行时漂移的隐式约束前移到快照校验，并补 formal setup matchup id 的唯一性与撞名保护。
- 范围：
  1. `apply_field` payload 强制承载 effect 使用 `duration_mode="turns"` 且 `duration > 0`
  2. `rule_mod.priority` 增加 `-10..10` 范围校验，覆盖当前内容中合法的高优先级需求
  3. `remove_mode="single"` 禁止直接指向 `stacking="stack"` 的 effect
  4. `stat_mod.stage_delta` 增加 `-2..2` 范围校验，与运行时 clamp 保持一致
  5. formal manifest runtime entry 禁止重复 `formal_setup_matchup_id`
  6. formal 角色 setup id 禁止与 baseline matchup id 撞名，避免 baseline 路由静默抢先
- 新增回归：
  - extension validation 覆盖 apply_field duration、rule_mod priority、stat_delta、stack single remove
  - formal runtime registry 覆盖重复 `formal_setup_matchup_id`
  - sample factory 覆盖 formal setup id 与 baseline matchup id 撞名 fail-fast
- 验证：
  - `TEST_PATH=res://test/suites/extension_validation_contract/extension_validation_contract_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/content_validation_core/formal_registry/runtime_registry_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/content_validation_core/formal_registry/catalog_factory_error_suite.gd bash tests/run_gdunit.sh`
  - `bash tests/check_architecture_constraints.sh`
  - `bash tests/check_repo_consistency.sh`
  - `bash tests/check_gdunit_gate.sh`

## 最近完成：全面修复与瘦身重构阶段 1 - 核心稳定（2026-04-26）

- 状态：已完成
- 目标：修复执行期 fail-fast 与核心状态一致性问题，先补稳定行为和替代覆盖，再进入 schema/formal/门禁瘦身。
- 范围：
  1. rule_mod 数值读取统一传播 `error_state()`，命中、伤害倍率、回蓝、治疗倍率与入站伤害倍率读错时直接终止对局
  2. `ActionDomainGuard` 从 bool 结果升级为结构化结果，执行期领域/规则查询错误向 `ActionResult.invalid_battle_code` 传播
  3. field apply 在生命周期与 success effects 成功后才写成功日志；失败恢复 active field 与 field rule_mod 状态
  4. 手动换人与 forced replace 的 `STATE_SWITCH` 改为生命周期成功后记录；失败路径不写成功换人日志
  5. invalid runtime 后允许 `get_event_log_snapshot()` 只读诊断；已结束对局再次 `run_turn` 返回明确 manager error
- 新增回归：
  - rule_mod 数值读取错误终止对局
  - field apply 生命周期失败不提交 field、不写 apply 成功日志
  - manual switch 生命周期失败不写 `STATE_SWITCH`
  - invalid battle 后仍可读取 event log snapshot
  - finished battle 再次 `run_turn` 返回 `invalid_manager_request`
- 验证：
  - `TEST_PATH=res://test/suites/action_guard_invalid_runtime_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/lifecycle_replacement_flow/manual_switch_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/forced_replace_lifecycle_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/field_lifecycle_contract_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/manager_log_and_runtime_contract/event_log_suite.gd bash tests/run_gdunit.sh`
  - `bash tests/check_architecture_constraints.sh`
  - `bash tests/check_repo_consistency.sh`

## 最近完成：全项目体量与风险审查（2026-04-25）

- 状态：已完成
- 目标：审查当前工程实现阶段、测试体量、引擎/技能实现、Sandbox 前端和可精简点。
- 范围：
  1. 扫描 `src/`、`content/`、`scenes/`、`test/`、`tests/`、`config/`、`docs/`
  2. 识别可保留、可删减、可优化与潜在问题
  3. 不修改业务逻辑，不删除文件
- 结论记录：`docs/records/project_review_2026-04-25.md`
- 关键发现：
  1. Formal catalog 错误在 `available_matchups_result()` 可见 matchup 汇总路径里仍可能被静默吃掉，需要改成显式 fail-fast 或拆出 baseline-only API
  2. Sandbox 角色选择页对 manifest 读取失败缺少明确错误展示
  3. Sandbox UI 当前是桌面固定布局，后续需要响应式列数与滚动容器
  4. 测试/gate 维护面偏重，README 精确行数强校验和多处测试入口列表可继续收窄
  5. Formal per-character validator 与角色 suite 有重复样板，后续可向 manifest/capability 驱动矩阵收口
- 验证：
  - `bash tests/run_with_gate.sh`
  - `bash tests/run_extended_gate.sh`

## 最近完成：模块化复审第一轮（2026-04-26）

- 状态：已完成
- 目标：在上一轮稳定性修复与瘦身收口之后，按模块重新审查 `composition / adapters / shared / test / tests / docs`，继续收集下一轮修复与瘦身入口。
- 范围：
  1. 重点检查 `SampleBattleFactory`、Sandbox、formal suite / gate、docs gate、BattleSandbox headless helper
  2. 只做审查与记录，不改业务逻辑
  3. 输出明确的下一轮修复顺序，避免再次做散点清理
- 结论记录：`docs/records/project_review_2026-04-26_module_round_1.md`
- 关键发现：
  1. `effect_queue_service.gd` 的跨来源同速 trigger tie-break 没有真正走随机决胜，会稳定按实例 ID 顺序执行
  2. field break / expire 在事件收集阶段失败时，没有把 invalid 往上传，仍可能继续清掉 field
  3. `replacement_service.gd` 在后半段失败时可能留下半提交 roster 状态
  4. `SampleBattleFactorySetupAccess.build_setup_by_matchup_id_result()` 仍可能通过 `has_matchup()` 把 catalog 加载错误吞成 unknown matchup，需要改成结构化 owner 查询
  5. demo replay 启动链仍会先吃 `available_matchups` 与 strict `matchup_id` 校验，导致 formal catalog 坏掉时回放入口一起被堵
  6. `FormalCharacterCapabilityCatalog` 的实例缓存没有按 `catalog_path` 分桶，存在多目录读取串数据风险
  7. `tests/check_suite_reachability.sh` 与 formal suite gate 组合后，仍允许 manifest 指向空壳 suite 入口，和现行决策冲突
  8. `repo_consistency_docs_gate.py` / `repo_consistency_surface_gate.py` 对同一套测试入口事实做了过多硬编码，维护噪声偏高
  9. BattleSandbox quick 主路径与 headless helper 仍有可合并的重复覆盖
- 验证：
  - `git push origin main`
  - `bash tests/check_repo_consistency.sh`

## 最近完成：review round 1 实修（2026-04-26）

- 状态：已完成
- 目标：核查并修复 2026-04-26 模块复审里记录的高影响真实问题，补齐最小回归。
- 范围：
  1. battle 核心：同速 trigger tie-break、field 生命周期 fail-fast、replacement 失败回滚
  2. composition / adapters / shared：matchup owner 查询、demo replay bootstrap、capability catalog 缓存分桶
  3. 补对应 gdUnit 回归，不改无关规范
- 修复内容：
  1. `effect_queue_service.gd` 把随机 tie-break 提升到跨来源完全同层事件，避免同速 trigger 被 `source_instance_id` 固定排序
  2. `field_service.gd` / `turn_field_lifecycle_service.gd` / `field_apply_effect_runner.gd` 把 field lifecycle 收口成结构化结果，`on_break / on_expire / field_apply` 收集失败立即 fail-fast
  3. `replacement_service.gd` 为换人链补最小回滚，覆盖 `leave_unit / field_break / on_enter` 失败后的 roster、field 与日志半提交
  4. `sample_battle_factory_setup_access.gd` 改成结构化 matchup owner 查询，formal catalog 加载错误不再被吞成 unknown matchup
  5. `battle_sandbox_launch_config.gd` / `sandbox_session_bootstrap_service.gd` 提前 demo 分流，strict demo 不再校验无关 `matchup_id`，demo bootstrap 不再先吃 `available_matchups`
  6. `formal_character_capability_catalog.gd` 改为按 resolved path 分桶缓存，避免多目录能力定义串读
- 验证：
  - `TEST_PATH=res://test/suites/effect_queue_service_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/field_lifecycle_contract_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/forced_replace_lifecycle_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/content_validation_core/formal_registry/catalog_factory_error_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/content_validation_core/formal_registry/capability_catalog_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/battle_sandbox_launch_config_contract_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/sample_battle_factory_contract_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/manual_battle_scene/demo_replay_suite.gd bash tests/run_gdunit.sh`

## 最近完成：核心函数参数类型标注补齐（2026-04-20）

- 状态：已完成
- 目标：补齐上一轮类型标注遗漏的核心函数参数
- 修复内容：
  1. `hit_service.gd` — `roll_hit` 的 `rng_service` 参数补 `RngService` 类型
  2. `effect_queue_service.gd` — `sort_events` 的 `rng_service` 参数补 `RngService` 类型
  3. `replay_runner_execution_context_builder.gd` — `build_context` 的 5 个参数全部补显式类型（`ReplayInput / ContentSnapshotCache / IdFactory / RngService / BattleInitializer`）
- 验证：`bash tests/run_with_gate.sh` 全通过

- Batch A2: hit RNG 一致性 + 入境约束 + 加载期校验

## 当前验证基线

- 最小可玩性检查：
  - 可启动：能进入 `BattleSandbox` 主流程
  - 可操作：`manual/policy` 至少能完整跑完一局
  - 无阻断错误：没有崩溃、卡死或 invalid runtime 漂移
- 当前总验收入口：
  - `bash tests/check_repo_consistency.sh`
  - `bash tests/run_with_gate.sh`

## 最近完成：信息可见性边界修复（2026-04-26）

- 状态：已完成
- 目标：修复公开事件日志、manager replay 输出、投降命令校验、回放多余命令静默忽略与 replay 文档口径漂移。
- 范围：
  1. `get_event_log_snapshot()` 公开投影移除私有 RNG 字段：`battle_seed / battle_rng_profile / speed_tie_roll / hit_roll / effect_roll / rng_stream_index`
  2. `BattleCoreManager.run_replay()` 返回的 `replay_output.event_log` 改为公开安全投影，内部 `ReplayRunner` 完整日志保留给核心校验
  3. `surrender` 指令在即时结束前仍走 `CommandValidator` 校验当前 side、turn_index 与 active actor
  4. `ReplayRunner` 对未消费的未来 turn command fail-fast，返回 `invalid_replay_input`
  5. `run_replay().data.public_snapshot` 文档改为与 `turn_timeline` 最后一帧对齐
- 验证：
  - `TEST_PATH=res://test/suites/manager_log_and_runtime_contract/event_log_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/manager_replay_header_contract_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/content_snapshot_cache_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/action_guard_command_payload_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/manager_log_and_runtime_contract/replay_guard_input_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/replay_determinism_suite.gd bash tests/run_gdunit.sh`

## 最近完成：formal pair interaction 接入面收窄（2026-04-24）

- 状态：已完成
- 目标：在接入新正式角色前，减少 pair interaction 中央注册改动，并阻止占位交互用例进入主线
- 范围：
  1. `scenario_registry.gd` 从 manifest 派生 scenario_key，并从 `tests/support/formal_pair_interaction/*_cases.gd` 自动发现 runner
  2. `repo_consistency_formal_character_gate_pairs.py` 禁止回退到手写中央 registry，并禁止 pair interaction case 保留 `TODO` / placeholder runner
  3. `scripts/new_formal_character.py` 的后续步骤改为提示自动发现 runner，不再要求手改 `scenario_registry.gd`
  4. 补交 `src/shared/resource_path_helper.gd.uid`，修复当前 repo consistency 阻断项
- 验证：
  - `python3 -m py_compile tests/gates/repo_consistency_formal_character_gate_pairs.py scripts/new_formal_character.py`
  - `bash tests/check_suite_reachability.sh && bash tests/check_architecture_constraints.sh`
  - `bash tests/check_repo_consistency.sh` 当前受本机 Godot 日志轮转崩溃影响未完成；前置 uid / surface gate 已通过
  - `git push origin main` 当前受网络 DNS/SSH 解析失败阻断：`Could not resolve hostname github.com`


Batch A1: effect/log 契约 + apply_field 时序

## Batch K: adapter 装配收回 + envelope helper 清理（2026-04-27）

- 状态：已完成
- 目标：把 `BattleCoreComposer + SampleBattleFactory` 实例化收到统一 SessionFactory，让 adapter 只持 manager + sample_factory 不再 own composer；删 sandbox_session_coordinator_envelope_helper（5 个透明转发 + 1 个非平凡 helper）。
- 范围：
  1. 新增 `src/adapters/session_factory.gd`（67 行）`compose_battle_runtime() / dispose_battle_runtime()` 两个 static 方法，返回/接受 manager + sample_factory + composer
  2. `player_battle_session.gd` + `sandbox_session_bootstrap_service.gd` 删 `BattleCoreComposerScript / SampleBattleFactoryScript` preload，统一走 SessionFactory
  3. layering gate 加规则 13：`adapter 不再直接 preload BattleCoreComposer / SampleBattleFactory`，仅豁免 `session_factory.gd` 自己
  4. 删 `sandbox_session_coordinator_envelope_helper.gd` + `.uid`（35 行）；4 个透明转发方法切到 `ResultEnvelopeHelperScript / PropertyAccessHelperScript` 直调；`unwrap_sample_factory_result` inline 到 demo_service；`build_summary_context` 下沉到 `BattleSandboxLaunchConfig.build_summary_context`（参数 `side_control_modes` → `control_modes` 避同 class shadow）
  5. 改 `sandbox_session_command_service.gd / sandbox_session_demo_service.gd / sandbox_session_coordinator.gd` 删 envelope 字段 + EnvelopeHelperScript const，调用方全部切到 ResultEnvelopeHelperScript / PropertyAccessHelperScript
- 验证：
  - `bash tests/run_with_gate.sh` 全绿（120 quick + sandbox/player_mvp/replay_cases）
  - `TEST_PROFILE=extended bash tests/run_with_gate.sh` 全绿
  - `grep -r "BattleCoreComposerScript" src/adapters/` 仅命中 session_factory.gd 1 处
  - `grep -r "EnvelopeHelperScript" src/` 0 命中
- 不做：不删 `payload_effect_event_helper.gd`（DI 1:N 共享端口，被 6 个 handler 共用，删除 ROI 严重不平衡 — 改 19+ 处换 5 行删除，不值得）；不删 `battle_sandbox_policy_port.gd`（7 行 polymorphism contract，留作 actor 抽象基类）；不动 actions/ 颗粒度。

## Batch J: 闸门升级 + replay cases 进 gate + 测试覆盖补齐 + docs gate 减负（2026-04-27）

- 状态：已完成
- 目标：闸门链补 5 项遗留短板：动态 path 白名单、replay cases 进 quick gate、Obito 独立 replay case、Sukuna bad_cases 5 case 齐平、docs gate 减负。
- 范围：
  1. `tests/gates/architecture_layering_gate.py` 新增规则 12："动态 load(path_var) 必须在白名单内"，覆盖 `\b(?:ResourceLoader\.)?load\(\s*[a-z_]\w*\s*[,)]`，11 个合理调用点登记到 drop_if_file_path
  2. `tests/check_sandbox_smoke_matrix.sh` 新增 `run_replay_case_runner` helper 跑 domain (5) + kashimo (3) + obito (1) = 9 case，所有 scope 都跑（quick / extended / full 不分级）
  3. 新增 `tests/replay_cases/obito_cases.md` + `tests/helpers/obito_case_runner.gd`：阴阳遁防反逐段 baseline vs guarded 对照断言（hp_loss / yinyang_count / defense_stage / sp_defense_stage）
  4. `test/suites/extension_validation_contract/sukuna_bad_cases_suite.gd` 补到 5 case：domain field_definition_id + kamado shared damage amount，与 gojo/kashimo/obito 5 case 齐平
  5. `tests/gates/repo_consistency_docs_gate.py` 96→62 行，27 处中文 heading 字面量镜像砍到 `DOCS_ANCHOR_WORDS` 10 项真锚（4 链接 + 3 entrypoint + 3 config 路径）+ 13 项 `require_exists`
- 验证：
  - `bash tests/run_with_gate.sh` 全绿（120 quick + 3 段 replay_cases）
  - `TEST_PROFILE=extended bash tests/run_with_gate.sh` 全绿
  - Sukuna 5 case 全 PASSED；Obito case 实测 hp_loss baseline=20 / guarded=6 / yinyang=3
  - 单独 `python3 tests/gates/repo_consistency_docs_gate.py` `REPO_CONSISTENCY_GATE_PASSED`；`architecture_layering_gate.py` `ARCH_GATE_PASSED`
- 不做：不实现 layering gate 的 token graph（preload 依赖图，留给后续）；不改 domain/kashimo case_runner 风格（保留 print + JSON dump 形态，只 obito_case_runner 演示带内置断言的案例）；不动其它 repo_consistency_*_gate（surface / formal_character 等独立 gate 保留）。

## Batch J3: sandbox smoke 引擎日志 fail-fast（2026-04-27）

- 状态：已完成
- 目标：修复 replay case runner 输出 ObjectDB / resource leak 仍被 sandbox smoke 判定通过的问题。
- 范围：
  1. `domain_case_runner.gd / kashimo_case_runner.gd / obito_case_runner.gd` 退出前补 `dispose_sample_factories()`。
  2. `tests/check_sandbox_smoke_matrix.sh` 复用 boot smoke 的 engine error / warning 扫描语义，允许 headless shader cache 已知噪音，其余 `ERROR:` / `WARNING:` fail-fast。
- 验收标准：
  - `SANDBOX_SMOKE_SCOPE=quick bash tests/check_sandbox_smoke_matrix.sh` 通过。
  - `SANDBOX_SMOKE_SCOPE=extended bash tests/check_sandbox_smoke_matrix.sh` 通过。
  - `bash tests/run_with_gate.sh` 通过（123 quick gdUnit cases + boot/suite/arch/repo/python/sandbox smoke）。

## Batch J2: 玩家日志 public snapshot 对齐（2026-04-27）

- 状态：已完成
- 目标：修复玩家日志读取旧 payload / 旧事件名导致的显示失真，并补真实 BattleScreen 点击路径回归。
- 范围：
  1. `scenes/player/LogText.gd` 改读 public event snapshot 扁平字段：`actor_public_id / target_public_id / value_changes / payload_summary`。
  2. 事件名对齐当前 `EventTypes`：`action:cast / action:hit / action:miss / effect:* / state:* / system:*`。
  3. 新增 `player_battle_screen_contract_suite.gd`：直接覆盖 LogText public snapshot 格式化与 BattleScreen 真实技能点击推进。
- 验收标准：
  - `TEST_PATH=res://test/suites/player_battle_screen_contract_suite.gd bash tests/run_gdunit.sh` 通过（2 cases）。
  - `TEST_PATH=res://test/suites/player_battle_session_contract_suite.gd bash tests/run_gdunit.sh` 通过（9 cases）。
  - `TEST_PATH=res://test/suites/player_content_lexicon_contract_suite.gd bash tests/run_gdunit.sh` 通过（5 cases）。

## Batch I: legacy assert migration 收尾 + README facade 口径同步（2026-04-27）

- 状态：已完成
- 目标：消灭 `_assert_legacy_result` 全部 8 处残留 + 删 helper + 同步 README §4 / §7 BattleCoreSession 措辞与 design docs 对齐。
- 范围：
  1. 3 个 suite 共 8 处 `_assert_legacy_result(_test_X(...))` 双层桩迁到 `var result: Dictionary = _test_X(_harness); if not bool(result.get("ok", false)): fail(str(result.get("error", "unknown error")))` 形态：forced_replace_lifecycle (5)、sukuna_setup_ultimate_window (2)、effect_instance_order (1)
  2. 删 `tests/support/gdunit_suite_bridge.gd:21-26` 的 `_assert_legacy_result(result)` helper（5 行）
  3. README §4 第 90 行改为 "含两层稳定 facade"；README §7 第 205 行替换"内部会话壳"旧口径为 7 个 production API + 2 条边界
- 验证：
  - `bash tests/run_with_gate.sh` 全绿（120 quick）
  - 3 个迁移 suite 用例数等价（5+2+1=8 case 全 PASSED）
  - `grep -r "_assert_legacy_result" --include="*.gd" .` 0 命中
  - README 与 design docs / decisions.md Batch E1 段交叉读不矛盾
- 不做：不改测试断言逻辑（仅形态迁移）；不重命名公开 API；不动 archive 历史记录。

## Batch H: phase / battle_result 写入收口（2026-04-27）

- 状态：已完成
- 目标：把 `src/` 下 16 处 `battle_state.phase = ...` 与 4 组 battle_result 字段直接赋值收敛到 `BattleState` 的三个公共 setter，加 layering gate 守住单一 writer。
- 范围：
  1. BattleState 加 `transition_phase / finalize_invalid_termination / finalize_normal_termination` 三个 setter
  2. 16 处 phase 写入改 `transition_phase`；4 组 battle_result 终止副作用改 `finalize_*_termination`
  3. 删 BattleResultService.record_runtime_fault wrapper（外部无 caller）；4 个文件清理 BattlePhasesScript 死 import
  4. architecture_layering_gate.py 加 2 条 grep 规则（phase / battle_result 直写）+ scan_rule 加 `drop_if_file_path` 字段
- 验证：
  - `bash tests/run_with_gate.sh` 全绿（120 quick）
  - `TEST_PROFILE=extended bash tests/run_with_gate.sh` 全绿
  - 负向：在 adapter 故意写 `battle_state.phase = "BAD"` → layering gate 红
  - `grep "battle_state\.phase\s*=" src/` 在 src/ 命中 0（除 battle_state.gd 自身）
- 不做：不重命名 phase / battle_result 字段为下划线前缀（保持外部读 API）；不内置 chain_context 清理进 finalize_*_termination（caller 各自语义不同）。

## Batch G: 玩家 MVP 进 gate（2026-04-27）

- 状态：已完成
- 目标：把 Batch F 修过的 ~1910 行 player MVP 代码进入 quick / extended / boot_smoke 三层闸门，挡住下一次 API drift。
- 范围：
  1. `tests/check_boot_smoke.sh` 拆两轮：sandbox 默认入口 + `-- --player_mvp` 切到 BattleScreen，共用 ENGINE_ERROR / WARNING / `BATTLE_(SANDBOX|PLAYER)_FAILED:` 检查
  2. `tests/check_sandbox_smoke_matrix.sh` 加 player_mvp 段：quick scope 跑默认 matchup 一次；extended/full scope 跑 4 个 quick anchor matchup 各一次（policy/policy）；复用 `validate-summary`
  3. 新增 `test/suites/player_battle_session_contract_suite.gd`（8 case，quick profile）守 PlayerBattleSession 公开 API 契约
  4. 新增 `test/suites/player_content_lexicon_contract_suite.gd`（5 case，quick profile）守 6 张索引 dict + 18 调色板 + 中文 fallback + `*_display_name` 命名稳定
  5. `tests/suite_profiles.json` quick 30 → 32
  6. `README.md` §5.4 同步 boot smoke 双轮、smoke matrix 加 player_mvp 段
  7. 顺手清理 `seed` 参数 shadow 内置函数（→ `battle_seed`）、`var name` shadow Node.name（→ `skill_name` / `effect_name`）两个 main 上的预存 warning
- 验证：
  - `bash tests/run_with_gate.sh` 全绿（120 quick）
  - `TEST_PROFILE=extended bash tests/run_with_gate.sh` 全绿（含 4 个 player_mvp_anchor）
  - 负向：把 `PlayerBattleSession.start` 改名 `start_battle` 后 quick gate 红（contract suite + smoke + boot_smoke 三层都报）
- 不做：不动 sandbox 端任何文件；不引入 GUI 自动化；不改 repo_consistency gate。

## Batch F: 玩家 MVP 接线断裂修复（2026-04-27）

- 状态：已完成
- 目标：让 `Boot.launch_config = "player_mvp"` 能从启动跑到一局结束，玩家可以选技能、看日志、被强制换人、看胜负、回主菜单。
- 范围：
  1. 对齐 `scenes/player/BattleScreen.gd`（813 行）的所有调用方：方法名、参数签名、`side_id` 协议（`"0"` → `"P1"`）、`public_snapshot` 字段形状（删除 `events / current_side_to_select / legal_actions_by_side` 误读、改读 `team_units` + `bench_public_ids`、`unit.effects` → `effect_instances`）、lexicon API 命名（`translate_*` → `*_display_name`）。
  2. `PlayerBattleSession` 加两个薄助手：`current_side_to_select()` 与 `legal_action_summary(side_id)`，把 `LegalActionSet` RefCounted 转成 Dict envelope 给 UI 消费。
  3. `LogText.gd` 的 `_translate_unit / _translate_skill / _translate_effect` 改用 lexicon 的 `units / skills / effects` 真实 dict 与 `*_display_name` 函数；unit 翻译按 `definition_id`（去 `#N` 后缀）查表。
  4. `BattleScreen.tscn` 新增 `DialogContainer` CanvasLayer；`ForcedReplaceDialog` 通过 `preload + instantiate` 在"无 skill/ultimate/wait/仅 switch" 状态下弹出；玩家选完直接 `submit_player_command(SWITCH)`。
  5. `WinPanel.menu_requested` 连到 `_on_win_panel_menu_requested`，回主入口调 `_session.close()` + `reload_current_scene()`。
  6. `Boot._open()` 加 `OS.get_cmdline_user_args()` 解析，`--player_mvp` / `--sandbox` 覆盖 export 默认值。
  7. 新增 `tests/helpers/player_mvp_full_run.gd`：双侧 policy headless runner，最多 64 回合跑到 `battle_result.finished`，失败 `push_error("BATTLE_PLAYER_FAILED:")` + `quit(1)`，成功打印 `player_summary` JSON + `quit(0)`。Batch F 用它验收，Batch G 接入 gate。
  8. 删 `test/suites/formal_character_pair_smoke/interaction_suite.gd:17/21` 同函数内 `__legacy_result` 重复声明（Godot 4.6.1 在 `^WARNING:` 严格扫描下报错；属 main 预存量）。
- 验证：
  - 4 个推荐 matchup 通过 `player_mvp_full_run.gd` 跑完：gojo_vs_sample 15 回合 / kashimo_vs_sample 13 回合 / obito_vs_sample 15 回合 / sukuna_setup 15 回合，全部 `result_type=win / reason=elimination`
  - `bash tests/run_with_gate.sh` 全绿（107 quick）
  - `TEST_PROFILE=extended bash tests/run_with_gate.sh` 全绿
- 不做：不动 sandbox 端任何文件；不重写 BattleScreen view 渲染分层；不改造 `PlayerContentLexicon` 内容索引；不补 `_assert_legacy_result` 残余迁移（留给 Batch I）。

## Batch E2: payload_service_specs 静态 preload 绑定（2026-04-27）

- 状态：已完成
- 目标：把 `BattleCorePayloadServiceSpecs` 的 payload handler script 绑定从「文件名约定 + `ResourceLoader.load(path_string)`」改为静态 `preload` 常量，让重命名 handler 文件触发编译期硬错。
- 范围：
  - `src/composition/battle_core_payload_service_specs.gd`：新增 9 个 handler script `const ... := preload(...)`，新增 `HANDLER_SERVICE_DESCRIPTORS` 静态映射；`service_descriptors()` 改为按 `PayloadContractRegistry` 的 `handler_slot` 在静态 dict 中查表，未命中触发 `assert` fail-fast；删除 `PAYLOAD_HANDLER_SCRIPT_ROOT`、`handler_script_path_for_slot`、`_handler_service_descriptor`、`_load_handler_script` 这条「字符串拼接 + 运行期 load」链路。
  - `HANDLER_SERVICE_DESCRIPTORS` 放在 `SHARED_SERVICE_DESCRIPTORS` 之前，以保 architecture composition consistency gate 的 `r"const SHARED_SERVICE_DESCRIPTORS := \[(.*?)\]\n\nstatic func service_descriptors"` 正则匹配不变。
- 验收：`bash tests/check_architecture_constraints.sh` 全 PASS（composition consistency / wiring DAG / layering / 缩进）。
- 不做：未触动 `effects/payload_handlers/` 下任何 handler 实现文件，未触动 adapters/scenes/tests/test 任何测试。
