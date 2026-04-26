# 决策记录（活跃）

本文件只保留当前仍直接约束实现、门禁和扩角节奏的活规则；更早的完整背景与执行流水统一看 archive。

历史归档：

- `docs/records/archive/decisions_pre_2026-04-05_repair_wave.md`
- `docs/records/archive/decisions_pre_v0.6.4.md`
- `docs/records/archive/decisions_pre_v0.6.3.md`
- `docs/records/archive/decisions_2026-04-10_to_2026-04-18_refactor_wave.md`

当前生效规则以 `docs/rules/` 为准；`docs/design/` 负责结构与交付面；本文件只解释“为什么现在这样定”。

## 2026-04-27 Batch D-Layout：BattleScreen tscn + controller（重启）

- **背景**：上一次 D-Layout 因 Cloudflare 521 中断未产出文件；本批次从零重做。D-UIBoot（ErrorToast / WinPanel / ForcedReplaceDialog / LogText + boot.gd 分支）已落地；D-Lex（PlayerContentLexicon）与 D-Session（PlayerBattleSession / PlayerEventLogStreamer / PlayerDefaultPolicy）并行写入，class_name 预留可引用。本批次只动 `scenes/player/BattleScreen.{tscn,gd}` 两个文件 + 各自 .uid，不动 `src/` / `tests/` / `test/` / `content/` / 其它 `scenes/player/*` / `scenes/sandbox/`。
- **节点结构**：`BattleScreen (Control, anchors_preset=15, custom_minimum_size 1280×720)` 全屏占位，`MarginContainer (12px)` 包 `VBoxContainer (separation=6)`，依次：TopBar（TurnLabel + FieldBadge + HSpacer + CurrentSideLabel）/ OpponentZone（OpponentCard + OpponentSprite ColorRect 200×200）/ OpponentBenchRow / MiddleLog（PanelContainer min_h=180 内含 ScrollContainer + LogText RichTextLabel，script=LogText.gd）/ PlayerZone（镜像）/ PlayerBenchRow / ActionBar（GridContainer columns=4，4 个 SkillButton + UltimateButton + SwitchMenuButton + WaitButton + ForcedHintLabel hidden）/ SideDetailPanel hidden。两个 CanvasLayer：ErrorToastContainer (layer=10) 与 WinPanelContainer (layer=11) 接 toast / 终局面板的临时实例。OpponentCard / PlayerCard 内部统一 HeaderRow（NameLabel + CombatTypeBadgeRow）+ HPRow（HPBar + HPLabel）+ MPRow（MPBar + MPLabel）+ UltimateDots（运行时塞 ColorRect 圆点 + VSeparator）+ StatStagesRow（运行时按非 0 stage 塞 Label）+ EffectsBox（运行时按 active_effects 塞 Label）。
- **Controller**：`class_name PlayerBattleScreen extends Control`。`_ready` 走 `_bootstrap_session() → _refresh_ui_from_session()`：先尝试通过 `ProjectSettings._global_script_classes` 反射 `PlayerContentLexicon` / `PlayerBattleSession` / `PlayerEventLogStreamer` 的脚本路径并 `new()`，未注册时回 null 不报错（D-Lex / D-Session 还没落地时 .gd 仍能解析），仅在最终启动 session 缺失时弹 `invalid_composition` toast。session 启动用 `start_session({matchup_id="gojo_vs_sample", seed=9101, local_player_side_id="0"})`；按钮回调走 `submit_player_command(payload)` + `run_turn()` 双步推进，因为 P2 默认走 PlayerDefaultPolicy。
- **中文文案**：按钮 `换人 ▼` / `等待` / `奥义 {名}` / `奥义 {名} 满`；状态阶段 `攻 +1 / 防 -1 / 速 +2`；effects `{中文 effect_display_name}（剩 N 回合）`；场地 `场地: 无` / `场地: {名}（剩 N 回合）`；TopBar `回合 N` / `等待 P{side_id} 选择` / `请选择你的指令`；强制反伤提示 `无可用主动技能，将自动反伤`；倒下后备 `X 倒下`；终局走 `PlayerWinPanel.show_outcome(winner_side_id, result_type, reason)`。命中 / 伤害 / miss 文案完全交给 `PlayerLogText.append_event` 处理，避免重复字面量两份。
- **跨子代理接口约定**：
  - **PlayerContentLexicon（D-Lex）**：`load_all() / translate_unit_public_id(public_id) / translate_skill_id(skill_id) / translate_effect_definition_id(def_id) / translate_field_id(field_id) / translate_combat_type_id(combat_type_id) / combat_type_color(combat_type_id) -> Color / skill_mp_cost(skill_id) -> int`。任何方法返回空字符串 / null 时 BattleScreen 回到原 id 兜底，不 fail-fast，给 D-Lex 留扩展余地。
  - **PlayerBattleSession（D-Session）**：`set_lexicon(lex) / set_local_player_side_id(side_id) / start_session(opts: Dictionary) -> envelope / submit_player_command(payload: Dictionary) -> envelope / run_turn() -> envelope / get_public_snapshot() -> Dictionary / get_legal_action_set(side_id: String) -> Dictionary`。envelope 失败用 `{ok=false, error_code, error_message}`，BattleScreen 直接转给 PlayerErrorToast；`get_public_snapshot()` 形态对齐 `BattleUIViewModelBuilder` 的 sides[].active / .bench / .team_units + `legal_actions_by_side` + `field` + `events` + `battle_result`，BattleScreen 不再做二次 view-model 转换。
  - **PlayerEventLogStreamer（D-Session）**：`set_log_text(log) / set_lexicon(lex) / consume_into_log_text(snapshot, log_text)` 或备选 `consume(snapshot)`；都缺时 BattleScreen 直接走 `_log_text.append_event` 兜底，避免和 D-Session 进度强耦合。
- **未引入的工程**：BattleScreen 不复用 sandbox 那一套 `BattleUIViewModelBuilder / SandboxViewPresenter / palette` 链路，因为玩家流不走 sandbox 的多重 control mode、replay、launch_config 切换。后续如果需要复用底层 view model，可以新增 `PlayerSnapshotPresenter`，但本批次保留就地渲染避免提前抽象。`SwitchMenuButton` 用 PopupMenu 即时弹出而不是 ForcedReplaceDialog，因为后者只接强制换下；主动换人继续在 ActionBar 流。
- **暴露给主代理 review 的风险点**：(1) `_try_new_global_class` 通过 `ProjectSettings._global_script_classes` 反射 + `load(script_path).new()`，如果将来 D-Session 把类名换成别的（例如 `PlayerBattleSessionFacade`），需要同步改这里的字面量；(2) 强制 `forced_command_type == resource_forced_default` 自动 `submit + run_turn` 走 `call_deferred`，避免 `_ready` / 按钮回调链里递归，但若 session 端在该路径上抛错，会连续两次 `_show_toast` —— 视觉无大问题，但日志会重复一行。

## 2026-04-27 Batch D-Session：player session adapter（重启）

- **背景**：上一次 D-Session 因 Cloudflare 521 中断未产出文件；本批次从零重做。仅新增 `src/adapters/player/player_battle_session.gd` / `player_event_log_streamer.gd` / `player_default_policy.gd`，不动 `src/composition/`、`src/battle_core/`、`scenes/`、`tests/`、`test/`，也不动并行 D-Lex 域内的 `src/adapters/player/player_content_lexicon.gd`。
- **PlayerBattleSession**（240 行，class_name `PlayerBattleSession extends RefCounted`）：玩家会话门面，封装 `BattleCoreManager`（`res://src/battle_core/facades/battle_core_manager.gd`）。`_init(manager_ref: Variant = null)` 允许注入外部 manager；为空时延迟到 `start()` 时通过 `BattleCoreComposer.compose_manager()` 自建并由本对象持有 dispose 责任（`_owns_manager`）。`start(matchup_id, seed)` 借 `SampleBattleFactory.build_setup_by_matchup_id_result` + `content_snapshot_paths_for_setup_result` 把字符串 matchup_id 翻译成 `battle_setup` + `content_snapshot_paths` 给 manager.create_session；`seed == 0` 时回落到 `DEFAULT_BATTLE_SEED = 9101`。`legal_actions(side_id)` 直接转 `manager.get_legal_actions`（缓存到 `_legal_actions_by_side`，但本批次未对外暴露缓存读 API，避免和 manager 出口形成第二真源）。`submit_player_command(side_id, payload)` 仅接受 `P1`，调 `manager.build_command(payload)` 后把 `{side_id, command}` 存入 `pending_p1_command`。`run_turn()` 内部为 `P2` 拉 `legal_actions` + 跑 `default_policy.decide` + 复用 `PlayerSelectionAdapter.build_player_payload` 补 `actor_public_id / turn_index / command_source`，再 `manager.build_command` 拿到 P2 command，最终 `manager.run_turn(session_id, [p1_command, p2_command])`，刷新 `current_snapshot_data` / `battle_finished`。`close()` 幂等：先 `close_session`，自建 manager 时再 `dispose`，`SampleBattleFactory.dispose()` 一并释放。所有失败路径直接外抛 manager envelope，不做 retry / 兜底。
- **PlayerEventLogStreamer**（50 行，class_name `PlayerEventLogStreamer extends RefCounted`）：内部 `_last_cursor: int = 0`，`reset()` 复位，`pull_increment(manager, session_id)` 调 `manager.get_event_log_snapshot(session_id, _last_cursor)` 拉增量后把 `_last_cursor` 推到 `total_size`。返回扁平 envelope `{ok, events, total_size, error_code, error_message}`（与任务规格的字段顺序对齐，区别于 manager 通用 `{ok, data, error_code, error_message}` 的嵌套形态——任务要求 UI 直接读 `events / total_size`，这里把 unwrap 一次性做掉）。manager envelope 失败时按其 `error_code/error_message` 透传，不补救。事件 dict 直接来自 `BattleCorePublicSnapshotBuilder.build_event_public_snapshot`，已剥离敏感字段（unit_instance_id 等）；本类不再读这些字段也不二次过滤，避免出现"两个出口语义不同"。
- **PlayerDefaultPolicy**（122 行，class_name `PlayerDefaultPolicy extends RefCounted`）：自包含，**不依赖 `src/dev_kit/sample_battle/`**，避免 D-Session 反向引用 dev_kit 资源做策略决策。`decide(side_id, public_snapshot, legal_actions)` 优先级实现：(1) `forced_command_type` 非空 → 按 forced 走（`resource_forced_default`，`command_type` 字段直接透传 `legal_actions.forced_command_type`）；(2) `legal_ultimate_ids` 非空 → 取首项发奥义（`command_type=ultimate`）；(3) **反伤可用**（`legal_skill_ids` 非空且首选含 `counter` / `reflect` 的 skill_id 或 active unit `effect_instances` 含 `counter`/`reflect` 字样的 effect_definition_id）→ 取该 skill_id；(4) `legal_skill_ids` 非空首选 → 第一个合法主动技能；(5) `wait_allowed=true` → wait。所有失败路径走 `INVALID_COMMAND_PAYLOAD` envelope。返回 dict 仅含 `command_type / skill_id / command_source="policy"`，由 PlayerBattleSession 后续用 PlayerSelectionAdapter 补 `side_id / actor_public_id / turn_index`。
- **manager facade 入口**：本批次精确选定 `res://src/battle_core/facades/battle_core_manager.gd`（class `BattleCoreManager extends RefCounted`），通过 `create_session / get_legal_actions / build_command / run_turn / get_public_snapshot / get_event_log_snapshot / close_session / dispose` envelope API 单向调用，不绕过 `BattleCoreManagerSessionService`，不直接读 `_sessions` 内部 dict。
- **未做的事**：(1) PlayerBattleSession 不缓存 `legal_actions_by_side` 对外暴露——避免和 manager envelope 真源形成两份；UI 想读时直接调 `legal_actions(side_id)` 拉新（manager 内部已是纯查询无副作用）。(2) 不引入 `PlayerSnapshotPresenter` 之类视图模型——D-Layout 直接读 `current_snapshot()` 的原始 public_snapshot，不在本批次额外抽象。(3) 不写 `tests/`：本批次只交付 adapter 文件 + 文档，回归走 D-Layout 的 BattleScreen smoke 与下一轮专项 suite。

## 2026-04-27 Batch C-A：test/suites 精简

- **双层桩去除**：`tests/support/gdunit_suite_bridge.gd` 删掉 `_assert_legacy_result(result: Dictionary)` helper（5 行）。119 个 `*_suite.gd` 走自动转换：`func test_X() -> void: _assert_legacy_result(_test_X(_harness))` + `func _test_X(harness) -> Dictionary: ... return harness.fail_result(msg) ... return harness.pass_result()` 这套"双层桩"被改写成单层 `func test_X() -> void: ...` 直接 `fail(msg); return`，私有 `_test_X` 整段 git rm。两个例外形态保留为内嵌 `__legacy_result` unwrap：(a) 旧 `_test_X` 末尾返回的不是 `pass_result/fail_result` 而是另一个 helper 的 Dict 结果（`return _shared.run_case(...)`）；(b) 同文件内仍有非 `_test_*` helper 函数返回 Dict 协议（`_run_yinyang_guard_case(harness, ...)`），那些 helper 的内部 `harness.fail_result/pass_result` 调用保持不动，避免连锁修改 `tests/support/*.gd` 共享 helper。
- **`tests/support/battle_core_test_harness.gd` 中 `pass_result()` / `fail_result(message)` 暂保留**：仍被 90+ 个分散在 suite 内、签名为 `(harness, ...) -> Dictionary` 的局部 helper 使用。Batch C-A 不删它们的原因是 helper 信号链路没有"_test_X"那种 1:1 双层关系；改造它们等于再做一轮 130+ 文件级 churn，下一轮（C-D 或 round 2）专项处理。
- **`_setup_default_battle(seed=1)`** 引入到 `gdunit_suite_bridge.gd`：返回 `{ok, core, sample_factory, content_index, battle_state}`，把"build_core/build_sample_factory/build_loaded_content_index/build_initialized_battle"这套 8-10 行起手式压成一行。每次调用仍构造全新对象（保持 fixture 隔离，不跨 test/不跨 suite 缓存可变状态），仅作为可选语法糖；既有 166 / 188 / 258 处显式 build_* 调用按"动量保留"原则不主动改写，避免和 C-B/C-C 的并行批次撞车。
- **角色 bad_cases 参数化**：`test/suites/extension_validation_contract/{gojo,sukuna,kashimo,obito}_bad_cases_suite.gd` 共 19 条 test 由 `_run_validator_bad_case(needle, label, mutator: Callable)` 收口（helper 落在 `extension_validation_contract/base.gd` 上）。每条 test 现在只声明三件事：期望 needle、失败 label、mutator lambda（在 content_index 上做单点篡改，返回空字符串或失败原因）。原先每条 80+ 行的 `build_factory + build_index + lookup + mutate + validate + assert` 全展开形态消失。4 个文件保留独立性（`suite_profiles.json` 引用未动），但每个文件从平均 75 行压到 ~50 行；`base.gd` 净增 ~25 行 helper 行。`extension_validation_contract_suite.gd` 的死代码 `const BaseSuiteScript := preload(...)` 也一并删除（自动转换没去掉的尾巴）。
- **replay_guard 7→4 文件**：`test/suites/manager_log_and_runtime_contract/` 下 `replay_guard_shared.gd`（反射桥 `_call_helper` 入口）+ `replay_guard_failure_shared.gd` + `replay_guard_input_shared.gd` + `replay_guard_summary_shared.gd` 共 4 个 `*_shared.gd` 整段 `git rm`（连同 `.uid`）。3 个 `replay_guard_*_suite.gd` 直接 `extends "res://test/suites/manager_log_and_runtime_contract/replay_guard_shared_base.gd"`，把原本散在 *_shared.gd 里的 `_test_X(harness) -> Dictionary` 实现按 native gdunit 形态搬进 suite，反射 `callv()` 桥彻底消失；`replay_guard_shared_base.gd` 保留作为 stub class（`ReplayRunnerStub / ContainerStub / NullLegalActionService / OneSideLegalActionFailureStub / NullCommandBuilder / RuleModServiceFailureStub / DomainLegalityServiceClearStub / PublicSnapshotBuilderStub`）和共享 helper（`_build_failed_replay_output / _build_finished_battle_state / _helper`）的唯一持有者。
- **catalog_factory 反射桥同理收口**：`catalog_factory_shared.gd` 原本承担 `_call_helper` 反射桥 + 9 条 `_test_X(harness)` thunk，被改写为 5 行的 `_run_legacy_helper(script_ref, method_name, args)` 单 helper（直接 `script_ref.new().callv(method_name, args)` 然后内嵌 `fail(error)` unwrap）；3 个 `catalog_factory_*_suite.gd`（setup / delivery_alignment / surface）改为直接调用 `_run_legacy_helper(SetupSharedScript / SetupMismatchSharedScript / SurfaceSharedScript / PairSeedCasesScript / PairMatrixCasesScript, "_test_X", [_harness])`。`catalog_factory_pair_shared.gd` 因为是另一层"shared 调 shared"的反射桥（_call_helper 转发到 PairSeedCasesScript / PairMatrixCasesScript），整段 `git rm`，suite 直接 preload `pair_seed_cases.gd` / `pair_matrix_cases.gd`。`*_shared.gd`（setup / setup_mismatch / surface / pair_seed_cases / pair_matrix_cases）保留为旧 Dict 协议 helper，因为它们的 fixture 长度（150-300 行）、JSON manifest 模板字面量、`_build_manifest_character_entry` 等 base helper 链路一旦下到 suite 文件就会爆 600 行硬警；这一层延后到 C-D 处理。
- **命名收敛跳过**：`test/suites/formal_character_pair_smoke/interaction_support.gd` 改名 `interaction_shared.gd` 被 `tests/gates/repo_consistency_formal_character_*.py` 的硬编码字符串 `interaction_support.gd` 阻挡（gate 文件不在 C-A 范围）；rename 已 revert，留作下一批与 gate 一起处理。
- **后果**：从 158 → 152 个 `test/suites/**.gd` 文件（净减 6：4 个 replay_guard *_shared + 1 个 catalog_factory_pair_shared + 0 命名变化），1 个反射桥 helper（`_call_helper`）在仓库内绝迹；私有 `_test_X` 在 suite 文件中绝迹（仅保留在 5 个 `*_shared.gd` 共享 fixture 文件，那是有意为之）。`fail()` 调用从 0 处涨到约 600 处，全部走 native gdunit 协议。

## 2026-04-27 Batch C-C：profile 重划分 + double support 合一 + 行数硬警

- `tests/suite_profiles.json` 按"每模块至少一条 quick"原则重划分：quick 从 15 条扩到 30 条（净增 15），extended 从 115 条收缩到 100 条；新加的 quick 覆盖此前完全缺席的 actions / commands / turn / effects / math / lifecycle / passives / logging / contracts / content / extensions / trigger 等模块代表，以及 sukuna / kashimo / obito / gojo 四个角色各 1 条轻量入口（行数 60-200，避免把 290+ 行的长尾塞进 quick）。新 quick 列表：`action_guard_command_payload / composition_container_contract / lifecycle_turn_scope / effect_queue_service / combat_type_definition / passive_fail_fast / log_cause_anchor / shared_contract / content_index_split / rule_mod_guard / trigger_validation / sukuna_setup_loadout_regen / kashimo_amber / obito_runtime_passive_and_seal / gojo_misc_runtime`。
- `manual` 档全面删除：`tests/suite_profiles.json` 顶层 `manual_checks` 数组（4 条人工脚本镜像）整段 `git rm`；`tests/check_suite_reachability.sh` 的 `allowed_profiles` 从 `{"quick","extended","manual"}` 收为 `{"quick","extended"}`；`tests/run_gdunit.sh` 删除 `manual)` 分支共 22 行 dispatch 代码（含独立 heredoc Python 脚本），`TEST_PROFILE` 错误信息更新为 `must be quick, extended, or full`。理由：原 manual 档解析路径在仓库里仍跑得通但归属为 0 条 suite，是死配置；显式人工复查脚本（`tests/helpers/manual_battle_full_run.gd` / `tests/helpers/demo_replay_full_run.gd`）已通过 `godot --headless --script` 直接执行，不需要再走 profile dispatch。
- `test/support/` 与 `tests/support/` 合一到 `tests/support/`：`test/support/gdunit_suite_bridge.gd` + `.gd.uid` 用 `git mv` 迁到 `tests/support/`，老目录 `rmdir`；`res://test/support/` import 字符串在 94 个 `test/suites/**.gd` 中全部改写为 `res://tests/support/`（仅触动 import 行，不动 suite 内容），`grep` 结果在 `src/` `tests/` `test/` `docs/` `scenes/` 全仓 0 命中。文档侧 `docs/design/project_folder_structure.md` 的 `test/support` 行删除并合并描述到 `tests/support`，`docs/design/battle_core_architecture_constraints.md` 的测试 support glob 集合删 `test/support/**.gd`，`tests/README.md` 第 25-26 行合并描述。理由：原双目录命名混乱（`test/` vs `tests/`）且 `test/support/` 只剩 1 个 bridge 文件；保留 `tests/support/` 因为它跟 `tests/check_*.sh` 同根，治理边界更稳定。**留下的检测真空**：未来如果 gdUnit4 需要 `test/support/` 路径下的隐式发现机制（目前仅 `extends "res://..."` 显式 preload），需要重新引入；当前所有 suite 都是显式 extends，没有这个隐式依赖。
- `tests/gates/architecture_layering_gate.py` 收紧硬警：`TEST_FILE_HARD_MAX` 从 1200 调到 600（任何 `test/**` 或 `tests/**` 单测试文件超 600 行直接 fail），`shared_support_patterns` 删除 `test/support/`（目录已合一），新增"壳子 suite"硬警——任何 `*suite.gd` 行数 < 13 且无 `^func\s+test_\w+\s*\(` 入口的文件直接 `ARCH_GATE_FAILED`，与 `tests/check_suite_reachability.sh` 现有的"必须有至少 1 条 func test_*"形成双层拦截（reachability 看 0 条，layering 看壳子最小行数）。理由：1200 行单文件没有任何业务回归是合理大小；600 行已经覆盖最长的合规 suite（当前最大 524 行）并预留 ~70 行冗余，超出意味着 suite 内必须按子域拆分。
- 验证：`bash tests/check_suite_reachability.sh` PASS（`extended=100, quick=30`），`bash tests/check_architecture_constraints.sh` PASS，`bash tests/check_repo_consistency.sh` PASS。

## 2026-04-27 Batch C-B：tests/ 脚本和 gate 实现减负

- `tests/gates/repo_consistency_surface_gate.py` 删掉 `tests/run_gdunit.sh` / `tests/run_with_gate.sh` / `tests/check_architecture_constraints.sh` 三组共 13 条 shell 字面量镜像（原行 32-44 + 159 那条 `architecture_wiring_graph_gate.py` 拼写检查）。理由：这些 `require_contains` 把 shell 脚本里的字符串拷贝到 Python gate 做反向核对，每次重命名/编辑 shell 变量都连锁改 gate；它们既不是结构化路径常量，也不能在 shell 改路径前先 fail（因为本来就是镜像），等于纯维护税。**留下的检测真空**：未来如果有人把 `check_*.sh` 中 gate 装配顺序删掉一条（例如不再调 `architecture_layering_gate.py`），surface gate 不再直接拦下。结论：可接受——`run_with_gate.sh` 自己 `set -euo pipefail`，缺哪条 gate 直接体现为 CI 缺失通过日志，不会变成静默漏检；同时新加的 layering gate 自身在 `set -e` 链路中 fail-fast，wrapper 不能吞错。
- `tests/check_architecture_constraints.sh` 由 9 段 `rg + tmp file + cat + exit` 重写为薄壳：仅保留 `require_command python3` + 顺序调 4 个 `python3 tests/gates/architecture_*_gate.py`，依赖 `set -euo pipefail` 转发非零退出码。所有 layering 规则统一搬到新建的 `tests/gates/architecture_layering_gate.py`：单遍 `rglob` 扫描 `*.gd / *.tscn / *.tres`、按 `(label, pattern, search_roots, drop_if_contains)` 元组驱动，输出仍以 `ARCH_GATE_FAILED:` / `ARCH_GATE_PASSED:` 起手以保 CI grep 兼容。
- 旧 heredoc 内联 Python 里的 `size_review_rules = {}` + `missing_review_allowlist` + `stale_allowlist` + `allowlist_overflow` 三段 allowlist 死代码全部删除——`size_review_rules` 是空 dict、所有相关分支不可达。core file 体量超限路径直接报 `ARCH_GATE_FAILED: core files >800 lines require fresh split:` 列表，不再走 allowlist。
- `tests/check_sandbox_smoke_matrix.sh` 5 段独立 Python heredoc（解析 catalog × 3 + summary 校验 × 2）合并为 `tests/helpers/sandbox_smoke_catalog.py`：`dump` 子命令一次读完 catalog 后输出 `KEY <name>\n<value>...\n` 形式的扁平块，shell 用单次 `while read` 灌进 5 个数组；`validate-summary` / `validate-demo-summary` 两个子命令承担原本两套 heredoc 的字段断言。catalog JSON 解析、必填字段、winner_side_id 与 result_type 的耦合校验、turn_index/event_log_cursor/command_steps 正数检查全部走单一文件，shell 不再持有任何 Python 字面量；`tests/check_python_lint.sh` 同步把 `tests/helpers/sandbox_smoke_catalog.py` 纳入 ruff 范围。
- `tests/cleanup_local_artifacts.sh` 由"白名单删"反转为"白名单留"：保留 `reports/gdunit/`、`reports/manual_log/`、`tmp/preserved/`，对 `reports/` 与 `tmp/` 一级子项做 `find -mindepth 1 -maxdepth 1` 枚举后非白名单全删；`__pycache__` / `.ruff_cache` / `.tmp` / `assets`（仅当为空目录）继续清理。**风险点（需主代理 review）**：原脚本只删 `reports/gdunit/report_1` 等具名目录，其它 `reports/*` 一律保留；新策略会清掉历史上手工放进 `reports/` 的任何非白名单目录（例如本机现存的顶层 `reports/report_1/`）。如果有别处脚本把生成物默认写到非白名单路径，第一次本地清理可能误删；上游 CI 因为是干净 checkout 不受影响。
- 新增文件：`tests/gates/architecture_layering_gate.py`、`tests/helpers/sandbox_smoke_catalog.py`。删除的隐式语义：`require_command rg` 不再出现在 `check_architecture_constraints.sh`（架构约束已不依赖 rg）。

## 2026-04-27 Batch B3a：action_cast_service 拆分为 4 个 owner

- `action_cast_service.gd` 从 14 deps / 170 行（"上帝服务"）退化为 6 deps / 93 行 thin orchestrator：仅按 phase 路由到 4 个新建 owner + `action_cast_effect_dispatch_service` + `trigger_batch_runner.execute_trigger_batch` Callable。对外 `execute_lifecycle_trigger_batch` 入口删除，唯一的内部使用点（`_dispatch_on_receive_action_hit_if_needed`）改走新 `dispatch_receive_action_hit_trigger(target, battle_state, content_index)`，把 trigger 名 / chain_context 收口在 segment service 内。
- 4 个新 owner（均带 `COMPOSE_DEPS` + `resolve_missing_dependency()`，均为顶层 service slot）：
  - `ActionCastMpService`（2 deps：mp_service / action_log_service）：`resolve_mp_cost / consume_mp / apply_action_start_resource_changes / mark_once_per_battle_usage`。把原本散在 `action_start_phase_service.gd` 内联实现的奥义点累加 / 清空与 `_mark_once_per_battle_usage` 一并归一到 MP service，开始阶段对外只暴露这 4 个语义动作。
  - `ActionCastTargetService`（1 dep：target_resolver）：`resolve_target / is_action_target_valid / resolve_target_instance_id`。
  - `ActionCastHitService`（3 deps：hit_service / rule_mod_service / rng_service）：从原 `action_hit_resolution_service.gd` rename 而来；`RESOURCE_FORCED_DEFAULT` 必中分支与领域必中 / 来袭命中修正全部留在该 owner 内部。
  - `ActionCastSegmentService`（7 deps：damage_service / combat_type_service / stat_calculator / rule_mod_service / faint_killer_attribution_service / action_log_service / trigger_batch_runner）：从原 `action_cast_direct_damage_pipeline.gd` rename 而来；`is_damage_action / apply_direct_damage / apply_default_recoil` 之外新增 `dispatch_receive_action_hit_trigger`，把段级 `on_receive_action_damage_segment` 与 action 级 `on_receive_action_hit` 归到同一 segment owner。
- 第 5 个 owner：`ActionCastEffectDispatchService`（5 deps：trigger_dispatcher / effect_queue_service / payload_executor / rng_service / trigger_batch_runner）从原 `action_cast_skill_effect_dispatch_pipeline.gd` rename 而来；`on_cast / on_hit / on_miss` 三个 trigger 的 effect 收集 + 排序 + 执行均落在它身上。orchestrator 不再持有 `_compose_post_wire` 私有 helper，全部 owner 走标准 composer 装配路径。
- 旧文件 `action_cast_direct_damage_pipeline.gd / action_cast_skill_effect_dispatch_pipeline.gd / action_hit_resolution_service.gd` 连同对应 `.gd.uid` 一并 `git rm`，不留 fallback / shim。`docs/records/decisions.md` 老的"slot 下沉"清单（编号 135 / 136 / 137）即时生效——`action_cast_direct_damage_pipeline / action_cast_skill_effect_dispatch_pipeline / action_hit_resolution_service` 不再下沉到 owner 私有，而是各自被 1:1 替换成顶层 service slot；`power_bonus_resolver` 仍是 `action_cast_segment_service` 私有（在 `_compose_post_wire` 中实例化）。
- 装配端：`battle_core_service_specs.gd` 新增 5 个 slot（`action_cast_mp_service / action_cast_target_service / action_cast_hit_service / action_cast_segment_service / action_cast_effect_dispatch_service`）。`action_cast_service` 的 COMPOSE_DEPS 收缩为 6 条（5 个 cast owner + trigger_batch_runner，全部 `nested: true`）；`architecture_wiring_graph_gate` 验证装配图仍无环。
- 调用端联动：`action_executor / action_start_phase_service / action_execution_resolution_service / switch_action_service` 仍只通过 `action_cast_service` 入口调用；测试侧仅 `test/suites/sukuna_setup_skill_runtime_suite.gd` 的 `power_bonus_resolver` 替换路径从 `core.service("action_cast_service").action_cast_direct_damage_pipeline.power_bonus_resolver` 改为 `core.service("action_cast_segment_service").power_bonus_resolver`。

## 2026-04-27 Batch B3b：EffectInstanceService 查询 API 收口

- `EffectInstanceService` 新增 4 个查询 API（其中 2 个走 instance、2 个走 static），把原本散在 6 个域的 effect_instance 字段穿透读统一收口：
  - `unit_has_persistent_effect(unit_state) -> bool`（instance）：覆盖 `turn_expiry_decrement_helper._unit_has_persistent_effect`。
  - `target_satisfies_required_effect(target_unit, def_id, require_same_owner, required_owner_id) -> {has_match, invalid_battle_code}`（instance）：覆盖 `effect_precondition_service._target_has_required_effect`，meta 缺 `source_owner_id` 时直接返回 `INVALID_STATE_CORRUPTION`，调用方按 fail-fast 处理。
  - `partition_effects_on_leave(unit_state, leave_reason) -> {kept_effects, removed_effects}` + `removed_effect_log_descriptors(removed, content_index) -> {descriptors, invalid_battle_code}`（instance）：覆盖 `leave_service.leave_unit` 内的离场过滤 + log descriptor 构造（descriptor 按 `{source_instance_id, def_id, priority}` 三元组返回，`def_id → effect_definition` 解析失败直接 `INVALID_EFFECT_DEFINITION` fail-fast）；`lifecycle_retention_policy.should_keep_effect_instance` 整段删除（rule_mod 那一份保留，因为 leave_service 还在用）。
  - `count_matching_effect_instances(unit_state, allowed_def_ids: PackedStringArray) -> int`（static）：覆盖 `action_cast_execute_contract_helper.count_matching_effect_instances` 与原 `power_bonus_resolver_strategy_effect_stack_sum._count_matching_effect_instances` 这两条几乎重复实现；其中 `power_bonus_resolver_strategy_effect_stack_sum.gd` 因仍在 `src/battle_core/content/`（受 L1 purity gate 约束，不允许 import effects/）保留私有 `_count_matching_effect_instances` 内联实现，未走 static helper。这是本批次唯一未收口的穿透读，理由是收口需要把 strategy 文件搬出 content/，与 B3b 范围分离；audit 单独留作"content 层运行态读取"未决项。
  - `build_active_effect_public_summaries(unit_state) -> Array`（static）：覆盖 `public_snapshot_builder._build_public_unit_snapshot` 内的 effect_instances 直读循环；schema_version 不动，输出字段集合与原循环一致（`effect_definition_id / remaining / persists_on_switch / __sort_instance_id`），public_snapshot_builder 排序逻辑保持原有路径。public_snapshot_builder 不在 container 内（compose_manager 路径单独实例化），所以走 static helper 而非 COMPOSE_DEPS 注入。
- 收口的穿透读点：原 6 域共 7 个站点，B3b 收口 6 个（剩 `content/power_bonus_resolver_strategy_effect_stack_sum.gd` 1 个保留私有副本，理由如上）：actions=1（execute_contract_helper）、turn=1（expiry_decrement_helper）、effects=1（precondition_service）、lifecycle=2（leave_service partition + log）、facades=1（public_snapshot_builder）、content=0（保留）。`unit_state.effect_instances` 写入仅在合法 owner 中：`effect_instance_service` / `effect_instance_dispatcher` / `leave_service` 写 `unit_state.effect_instances = kept` / `replacement_change_set.duplicate()`（rollback 语义）。
- 装配联动：
  - `effect_precondition_service` 新增 `effect_instance_service` 依赖（COMPOSE_DEPS 1 条，原本声明为空）。
  - `leave_service` 新增 `effect_instance_service` 依赖（COMPOSE_DEPS 从 2 条扩到 3 条）。
  - `turn_expiry_decrement_helper` 不是顶层 service slot，新增字段 `effect_instance_service`，由两个真实 owner（`turn_end_phase_service / turn_start_expiry_service`）在 `_sync_decrement_helper` 中同步注入；两个 owner 的 COMPOSE_DEPS 同时增加 `effect_instance_service` slot，`turn_start_expiry_service` 的字段拼接通过 `turn_start_phase_service` 转传。

## 2026-04-27 Batch B2c：payload_handlers 三对折叠

- 调查 `damage / resource_mod / stat_mod` 三对 handler+runtime_service 二级拆分后，确认实际 owner-helper 1:1 关系仅成立于 `damage` 与 `stat_mod`：
  - `payload_damage_runtime_service` 仅由 `payload_damage_handler` 一处 `apply_damage_payload` 调用（外加 contract_suite 一条单元测试）。
  - `payload_stat_mod_runtime_service` 仅由 `payload_stat_mod_handler` 一处 `apply_stat_mod_payload` 调用。
  - `payload_resource_runtime_service` 同时承载 `apply_heal_payload`（heal_handler 用）与 `apply_resource_mod_payload`（resource_mod_handler 用），两个 handler 共享私有 `_apply_resource_like_change`，1:1 owner 关系不成立 → 跳过这对，保持原状。
- 折叠后两个 handler 自包含逻辑：
  - `payload_damage_handler.gd` 从 33 行扩为 211 行（吸收原 runtime_service 209 行），COMPOSE_DEPS 由 1 条间接依赖（`payload_damage_runtime_service`）展开为 9 条直接依赖（battle_logger / log_event_builder / damage_service / combat_type_service / stat_calculator / rule_mod_service / faint_killer_attribution_service / target_helper / effect_event_helper）。
  - `payload_stat_mod_handler.gd` 从 31 行扩为 117 行（吸收原 runtime_service 110 行），COMPOSE_DEPS 由 1 条展开为 4 条直接依赖（battle_logger / log_event_builder / target_helper / effect_event_helper）。
  - 两个 runtime_service 文件总计删除 209 + 110 = 319 行 GDScript（外加 4 个 .gd / .gd.uid 文件 git rm）。`battle_core_payload_runtime_service_registry.gd` 从 78 行收缩到 50 行。
- 装配端联动：
  - `BattleCorePayloadRuntimeServiceRegistry.RUNTIME_SERVICE_DESCRIPTORS` 仅保留 `payload_resource_runtime_service` 一条；damage/stat_mod 的 descriptor 与 preload 引用一并删除。
  - `PayloadContractRegistry.PAYLOAD_DESCRIPTORS` 中 damage/stat_mod 的 `runtime_service_slots` 改为 `[]`，并把对应依赖清单平移到 `handler_dependencies`，与 apply_effect / rule_mod 等已自包含的 handler 形态对齐。
  - `payload_execution_contract_suite` 两个用例改用 `payload_handler_registry.handler_by_slot("payload_damage_handler")` 而非 `core.service("payload_damage_runtime_service")`：包括 missing dependency propagation 测试期望路径从 `payload_handler_registry.payload_damage_handler.payload_damage_runtime_service.faint_killer_attribution_service` 收紧为 `payload_handler_registry.payload_damage_handler.faint_killer_attribution_service`，以及 formula owner missing 用例直接调用 handler.execute。
  - 设计文档 `docs/design/effect_engine.md` 中"三件 runtime_service 保留"那段改写为"resource_runtime_service 是 heal/resource_mod 共享层；damage/stat_mod 已折叠回 handler"。
- 跨闸结果：`architecture_composition_consistency_gate / architecture_wiring_graph_gate / architecture_gdscript_style_gate / repo_consistency_uid_gate / repo_consistency_docs_gate` 均通过（runtime_service_registry 文件保留，gate 仍要求其存在；只是描述符表收缩到 1 条）。

## 2026-04-27 Batch B1：chain_context phase-scope + runtime_fault 单写者

- `BattleState.chain_context` 字段下沉为内部 `_chain_context_stack: Array`，外部一律通过 `current_chain_context()` / `set_phase_chain_context(ctx)` / `push_chain_context(ctx)` / `pop_chain_context()` / `clear_chain_context_stack()` 访问；旧的 `battle_state.chain_context = X` / `battle_state.chain_context = null` 直接改名为新 API，不留兼容 shim。
- 栈深守卫：`set_phase_chain_context` 仅容忍 depth ∈ {0, 1}，否则 `push_error + assert(false)` 并清栈，意味着上一阶段遗留了未配对的 `push_chain_context`；`pop_chain_context` 在空栈上同样 fail-fast。这把"阶段链直接覆盖"和"嵌套链入栈"两种语义在 API 上分离，既保留当前 codebase 的覆盖语义，又为将来真正的嵌套 effect 链留出栈底座。
- 现有所有阶段切换点（`turn_loop_controller`、`turn_start/end_phase_service`、`battle_initializer_phase_service`、`action_executor`、`battle_result_service*`、`turn_loop_validation_helper`、`log_event_builder._fail`、新加的 `set_phase_chain_context`/`clear_chain_context_stack` 调用）都属于 phase-scope replacement，不再产生嵌套；嵌套场景由 `ActionDamageSegmentTriggerContextService` 通过 `current_chain_context()` 拿到当前 ChainContext 后局部 mutate + `_capture/_restore`，不上栈。
- `BattleState.runtime_fault_code` / `runtime_fault_message` 字段重命名为 `_runtime_fault_code` / `_runtime_fault_message`（grep gate 标记"私有"），公开 API 仅有 `record_runtime_fault(code, message)` 写入与 `runtime_fault_code()` / `runtime_fault_message()` 读取。
- 单写者入口 `BattleResultService.record_runtime_fault(battle_state, code, message)` 是 service 层唯一允许写入的方法；原本直接写字段的 `LogEventBuilder._fail` 与 `TurnSelectionResolver._fail_invalid_result` 都注入 `battle_result_service` 依赖（`nested: false` 防 compose 循环递归）后改走该入口；composer 已自动按 `COMPOSE_DEPS` 拓扑装配，循环引用通过 `nested: false` + `visited` 双保险避免。
- 若 LogEventBuilder / TurnSelectionResolver 在没有 battle_result_service 的情况下落进 `_fail` 路径，立即 `push_error + assert(false)` fail-fast，强制单写者契约不允许"静默漏写"。
- 测试侧的 `LogEventBuilderScript.new()` 隔离测试（`replay_guard_summary_shared._test_log_event_builder_missing_*_contract`）改用 `BattleResultServiceFaultStub`（继承自 `BattleResultService`）注入桩 service，从而保持单写者契约可运行；测试桩仅转发到 `battle_state.record_runtime_fault`。
- `to_stable_dict()` 的 `runtime_fault_code` / `runtime_fault_message` 输出 key 不变；`_chain_context_stack` 与原 `chain_context` 字段一致仍排除在 stable_dict 外（transient per-turn state）。

## 2026-04-27 模块复审 round 1 文档对齐（Batch A3）

- `forced_command_type = resource_forced_default` 触发条件以 `LegalActionService._finalize_wait_and_forced_default` 为单一真相：
  - 当 `legal_skill_ids / legal_ultimate_ids / legal_switch_target_public_ids` 全空且 `wait_allowed = false` 时一律注入。
  - 既覆盖“全部仅因 MP 不足”，也覆盖“被 rule_mod / domain / once_per_battle 完全锁死且无可换人”等所有“无任何主动出口”的情形，不再单独区分阻断原因。
  - 旧版“仅在‘全部仅因 MP 不足’时给出 forced_command_type”的措辞与代码不一致，按代码（更宽松、更稳健）为准统一改写 `docs/design/command_and_legality.md` 与 `docs/rules/05_items_field_input_and_logging.md`。
- `effect_dedupe_keys` 在 `PayloadExecutor` 是“单链单实例”去重，不等于链深限制：
  - dedupe key 由 `_build_dedupe_key` 拼出 `source_instance_id / effect_instance_id / trigger_name / effect_definition_id / owner_id / dedupe_discriminator / target_unit_id / action_segment_index` 八元组，命中后整条 effect 二次入栈直接 `INVALID_CHAIN_DEPTH` fail-fast。
  - 去重表的生命周期跟随 `chain_context` 自身：主链结束时 `chain_context` 被重置或置 null，dedupe 表随之出栈，`_leave_effect_guard` 不再 erase 任何 key。
  - 链深守卫由独立的 `chain_depth ≤ max_chain_depth` 负责；两条守卫职责独立，不再在文档里混为一谈。
  - `docs/design/effect_engine.md` 与 `docs/rules/06_effect_schema_and_extension.md` 同步改写。
- `FaintResolver` `on_kill` 派发归因到当前主链 `actor_id` 是显式语义：
  - 只读取 `chain_context.actor_id`，effect 链（中毒、反伤、领域 tick）触发的致命伤害不会回到 effect 源头计 kill。
  - 这条由 `faint_resolver.gd` 的 docstring 锁住，避免后续被解读成“漏归因”。

## 2026-04-19 长期工程化定位升级

- 项目定位从"概念/原型期"升级为**长期工程**：底层架构稳定规范是第一优先级，后续会长期加入新机制，基础不稳会直接传导到未来扩展。
- 整体策略为"**保留严谨性、精简形式噪声**"：
  - 保留项：6 层架构与依赖方向、单一运行态真相、确定性回放、核心 facade 合同、内容资源加载期 fail-fast、Composition Root 显式装配、对外公开 ID 边界、主测试闸门
  - 精简项：文件过度碎片化、双错误体系、formal character 治理层多余分层、测试重复覆盖、文档冗余、gate 数量
- 架构文件行数阈值放宽：
  - 核心源文件：`500..800` 行预警、`> 800` 行必须拆分
  - 测试 support：`220..250` 预警、`> 250` 必须拆分
  - 测试文件：`> 1200` 必须拆分
  - Gate py：`800..1200` 预警、`> 1200` 必须拆分
  - 理由：原 `250` 行硬线适合原型期速写，长期工程需要主 owner 与 facade 容纳稳定合同与装配编排。
- 分阶段推进：详见 `docs/records/tasks.md` 当前阶段。

### 本轮长期不动边界（2026-04-19 冻结）

以下 5 项在本轮工程化重构全程不动，任何阶段如需触碰必须先暂停说明：

1. **`BattleCoreManager` 外部 envelope 合同**：`create_session / get_legal_actions / build_command / run_turn / get_public_snapshot / get_event_log_snapshot / close_session / run_replay` 的签名与返回 envelope `{ok, data, error_code, error_message}` 不变。
2. **Deterministic replay**：同 `seed + content snapshot + command stream` 必须产出同一 `final_state_hash`。
3. **Fail-fast**：非法输入直接报错，不做静默降级。
4. **单一运行态真相**：`BattleState` 是唯一运行态对象，其他模块不得各自缓存状态副本。
5. **`tests/run_with_gate.sh` 作为默认 quick gate 总入口**：内部顺序 `gdUnit4 quick → boot smoke → suite reachability → architecture constraints → repo consistency → Python lint → sandbox smoke matrix quick` 不变；长尾回归进入显式 `tests/run_extended_gate.sh`，完整收口使用 `TEST_PROFILE=full bash tests/run_with_gate.sh`。

### 扩角前接入安全线（2026-04-24）

- 新正式角色脚手架产物在完成前只能进入 `scripts/drafts/` 镜像路径；正式目录不接收 `FORMAL_DRAFT_`、`draft_marker`、`FILL_IN`、占位 runner 或 live validator `pass`。
- `config/formal_character_sources/` 与 `scripts/drafts/` 中的 source descriptor 读取失败必须直接中止脚手架，不允许跳过坏 JSON 后继续做 collision 检查。
- Sandbox UI 可以继续把用户控件输入规范化；测试、CLI smoke 和自动化入口必须使用 strict config，非法 matchup / mode / seed / control mode 直接失败。
- Sandbox smoke matrix 默认使用 `SANDBOX_SMOKE_SCOPE=quick` 覆盖推荐与 `<pair>_vs_sample` 主路径；全量可见 matchup 只通过 `SANDBOX_SMOKE_SCOPE=full` 显式触发，避免 formal directed matchup 随角色数二次方拖慢日常 gate。
- 内容快照缓存签名的显式依赖缺失属于内容快照错误，必须失败并暴露缺失路径，不允许退到 mtime 或空依赖签名。
- `FormalCharacterManifestViews` 只保留 runtime / delivery / catalog 入口协调；pair interaction case 派生逻辑由 `FormalCharacterPairInteractionCaseBuilder` 承担，后续 manifest 派生继续按职责拆分。

### 测试入口收口（2026-04-25）

- gdUnit suite 入口以真实可发现的 `test/suites/**/*.gd` 文件为准；不再新增只负责 `register_tests` 聚合的 wrapper suite。
- manifest、文档和 gate 必须引用真实 suite 路径；大型主题直接拆成子目录下的具体 suite。
- 对同一文件内同类黑盒场景，优先保留一个公开 `test_*` 聚合入口，内部按 case 列表顺序执行原断言，减少测试面噪声。
- `tests/run_gdunit.sh` 必须把不存在路径、空 suite、缺失报告 XML 和 0 testcase XML 当失败处理，避免删除或重命名 suite 后出现假绿。
- 测试分层固定为 `quick / extended / full`：quick 是默认开发门禁；extended 保留长尾边界、角色细节组合与历史回归；full 在 extended 基础上固定启用 full sandbox smoke。
- 新正式角色脚手架不得生成 `{pair_token}_suite.gd` 空 wrapper；`suite_path` 和 `required_suite_paths` 必须指向包含 `func test_*` 的真实 suite。
- draft readiness 对列入 `content_roots` 的 `units / skills / effects / passive_skills` 要求至少存在一个 `.tres`；只有 `fields` 可为空。
- `tests/check_suite_reachability.sh` 必须扫描所有 `*suite.gd` 文件，要求至少存在一个 `^func\s+test_\w+\s*\(` 入口，禁止哑 suite 通过 manifest / profile 校验后混过 gate（2026-04-26 起）。

### Sandbox 边界与 fail-fast（2026-04-26）

- `BattleSandboxController.get_state_snapshot()` 不再暴露 live `BattleSetup` 引用：sandbox 对外快照只承载 dict / 标量字段，外部调用方不得绕过它直接读取运行态对象。
- `SandboxSessionCoordinator.bootstrap_scene` 在 `close_runtime` 失败时直接 fail-fast，并把上一次会话的关闭错误显式抛出来；`BattleSandboxController._exit_tree` 同样会把 close 失败用 `printerr` 暴露，避免生命周期吞错。
- `SandboxViewCharacterCardsRenderer` 与 `SandboxViewPresenter` 不再写 `state.error_message`：渲染层只返回 `{"manifest_error_message": ...}` 形式的 render result，由 `BattleSandboxController._render_ui` 决定是否写入 session 状态。后续视图层组件保持同样的"返回 render result"边界。
- `payload_damage_runtime_service` 在公式分支 owner 丢失时报 `INVALID_STATE_CORRUPTION`，不再静默跳过；`payload_rule_mod_handler._resolve_rule_mod_owner` 区分两种语义：`is_effect_target_valid` 失败属于"target 已离场"的合理跳过；`battle_state.get_unit(owner_id)` 找不到 / "target" scope 缺 `chain_context` 属于内部 corruption，必须 fail-fast。
- `tests/helpers/manual_battle_full_run.gd` 是 BattleSandbox 唯一 headless 整局入口，所有 smoke / 文档 / suite_profiles 不再引用 `manual_battle_submit_full_run.gd`；`ManualBattleSceneSupport` 收回 context / drive helper 到单文件，外部仍以 `ManualBattleSceneSupport` 作为正式入口。`SampleBattleFactoryFormalAccess._normalize_path` 与 `SampleBattleFactoryBaseSnapshotPathsService.normalize_res_path` 统一调用 `ResourcePathHelper.normalize`，避免重复实现。

### 战斗引擎 actions/math 契约一致性（2026-04-27）

- `HitService.roll_hit` 必中分支也消费一次 `rng_service.next_float()`（结果丢弃），确保 `rng_stream_index` 单调；未来若 `rule_mod` 把命中从 100 改到 95，不再因为多消费一个 `next_float` 引入相同 seed 不同 hash 的回放漂移。`accuracy = 100` 仍视为必中、`hit_roll` 字段在日志中保持 `null`。
- `HitService.roll_hit` / `ActionHitResolutionService.resolve_hit` 入境处对 `accuracy < 0` 直接 `push_error` + `assert(false)`，附 actor / skill / accuracy 上下文，不做静默 clamp。
- `CombatTypeService.calc_effectiveness` 的空 `defender_type_ids` 校验前移到内容加载期：`ContentSnapshotUnitValidator._validate_unit_combat_types` 强制每个 unit 至少声明 1 个 `combat_type_id`；运行期一旦 defender_type_ids 为空，service 直接 `push_error` + `assert(false)`，不再静默返回 `1.0`。
- `DamageService.apply_final_mod` 的 `max(1, ...)` 是显式设计选择（"无属性免疫" + "0 伤地板=1"），未来若想用 `final_mod=0` 模拟 0 伤需明确改这一处；docstring 已锁定该 WHY。

### Stage 1 composition slot 收缩目标图（2026-04-19 冻结）

当前 81 slot = base 66 + payload shared 3 + payload runtime 3 + payload handler 9。

**Payload dispatch 模式决策：保留。**  
`PayloadContractRegistry → PayloadHandlerRegistry → handler slot` 动态分派模式清晰可扩展，15 个 payload 相关 slot 本轮不动。

**Base 66 → 50：下沉 16 个 slot 为 owner 私有 helper。**  
目标总 slot 数：**65**（50 base + 15 payload）。

下沉清单：

| 原 slot | 下沉到 owner |
|---|---|
| action_chain_context_builder | action_executor |
| action_start_phase_service | action_executor |
| action_skill_effect_service | action_executor |
| action_execution_resolution_service | action_executor |
| action_domain_guard | action_executor |
| action_cast_direct_damage_pipeline | action_cast_service |
| action_cast_skill_effect_dispatch_pipeline | action_cast_service |
| action_hit_resolution_service | action_cast_service |
| power_bonus_resolver | action_cast_service |
| switch_action_service | action_executor |
| battle_initializer_setup_validator | battle_initializer |
| field_apply_log_service | field_apply_service |
| field_apply_effect_runner | field_apply_service |
| lifecycle_retention_policy | leave_service |
| faint_leave_replacement_service | faint_resolver |
| replacement_selector | replacement_service |

保留 50 slot 理由：均为跨模块依赖（被 2+ 其他 service 引用）或模块入口。

### Stage 1 错误体系目标设计（2026-04-19 冻结）

**结论：维持双轨模型，不强制合并。**

- **Track A — `ErrorStateHelper`（`last_error_code` + `error_state()`）**：用于 composition / builder / content loader 的组装期错误。这类错误发生在战斗开始前。
- **Track B — `last_invalid_battle_code` + `invalid_battle_code()`**：用于运行时战斗规则违反。这类错误发生在战斗执行中。
- **对外 — `ResultEnvelopeHelper`**：manager envelope 统一 `{ok, data, error_code, error_message}`。

两者各司其职（2026-04-18 审计结论确认），不合并。

**`_ok_result`/`_error_result` 本地包装处理方案：**

| 类别 | 文件数 | 处理 |
|---|---|---|
| A：已 delegate 到 `ResultEnvelopeHelper` 的纯别名 | 18 | 保留。部分 wrapper 注入固定 error code 或 strip_edges()，内联后调用点更冗长，可读性下降 |
| B：标准 envelope 结构但未 import helper | 6 | ✅ Stage 3 已加 import 并内联 |
| C：有副作用或自定义返回结构 | 1 (replay_runner_output_helper) | ✅ Stage 3 已重命名为 `_build_error_envelope` |

详细文件清单：
- A 类（18）：sandbox_policy_driver / sample_battle_factory_* 全部 10 个 / formal_character_baselines + loader / formal_character_capability_catalog / formal_character_manifest + loader + views / formal_registry_contracts
- B 类（6）：legal_action_service_rule_gate / cast_option_collector / switch_option_collector / sandbox_session_command_service / sandbox_session_coordinator
- C 类（1）：replay_runner_output_helper

### 代码质量与样式（2026-04-19）

1. `.gd.uid` 当前固定纳入版本管理：
   - `.gitignore` 不再允许忽略 `*.uid`
   - 有效 `.gd.uid` 必须随同对应 `.gd` 一起提交
   - 孤儿 `.gd.uid` 必须删除，并由 repo consistency gate 直接失败
2. GDScript 前导缩进当前固定只允许 tab（`src/`、`test/`、`tests/`、`scenes/`），space-only 与 tab/space 混用都直接视为失败。
3. 测试 support helper 体量 gate 当前固定扩到 `test/**/shared*.gd`、`test/**/*_shared.gd`、`tests/support/**/*.gd`，落在 `220..250` 行输出预警，> `250` 直接失败。
4. `BattleState` 查询路径不保留缓存语义；`get_side / get_unit / get_unit_by_public_id` 始终返回当前 `sides / team_units` 真值；`rebuild_indexes()` 已移除。
5. `COMPOSE_DEPS` 当前固定只描述 composer 注入的外部依赖；owner 私有 helper 不再混入这份声明。
6. 共享结果式 helper 的适用边界当前扩大到 policy / adapters / facade helper；外层成功/失败结果统一只认 `ok / data / error_code / error_message`。各文件允许定义 `_ok_result` / `_error_result` 等私有包装器委托到 `ResultEnvelopeHelperScript`，这属于可接受的约定性模式，不视为冗余。
7. 本地报告目录当前固定只认 `reports/gdunit`；其余历史 `reports/gdunit_*` 目录与 `tmp / .tmp` 都视为可清理噪声。

### 核心类型标注边界（2026-04-19，更新）

- `BattleCoreManager` / `BattleCoreManagerContainerService` 这类 facade 公开入口，继续允许非法输入走运行时 envelope 校验并返回正式错误，不把 contract 失败提前变成 GDScript 解析错误。
- `session state / facade service / initializer ports` 这类核心运行态依赖字段，继续优先补成显式具体类型，不回退成大面积 `RefCounted`。
- 测试替身如果要写进这些强类型字段，固定通过继承真实类或 typed stub 适配；`shared_contract_suite` 这类 wiring 契约测试不再用裸 `RefCounted` 穿过类型边界。
- `battle_core` 核心函数参数中的高频运行态类型（`BattleState`、`BattleContentIndex`、`ChainContext`、`QueuedAction`、`EffectEvent`、`Command`）已补齐显式类型标注。GDScript 4 class-type 参数允许 null，不影响现有防御性 null 检查。

### SampleBattleFactory 迁出 composition 到 dev_kit（2026-04-27 Batch B2b）

- `src/composition/sample_battle_factory*.gd`（17 个文件）整套迁到 `src/dev_kit/sample_battle/`，对应 `.gd.uid` 一并 `git mv` 保留。`composition/` 目录现在只承载 production 装配链（`battle_core_composer / battle_core_container / battle_core_*service_specs / battle_core_payload_*`），不再混入开发与测试用的 sample 装配。
- 4 个 facade（`sample_battle_factory_setup_facade / snapshot_facade / demo_facade / catalog_facade`）属于 runtime graph 的内部装配组件，仅由 `sample_battle_factory_runtime_graph.gd` 引用（无外部 caller），随主套迁到 `src/dev_kit/sample_battle/`，不删、不下沉到 `tests/support/`。结论：它们不是“delegating shim”，而是 owner 拆分出的固定职责面，归属同一 dev_kit 模块。
- 唯一的 production caller `src/adapters/sandbox_session_bootstrap_service.gd` 改 preload 到 `res://src/dev_kit/sample_battle/sample_battle_factory.gd`；测试与 helper caller（`tests/support/battle_core_test_harness_sample_helper.gd / formal_character_registry.gd`、`tests/helpers/export_sandbox_smoke_catalog.gd / export_formal_delivery_registry.gd`、`test/suites/battle_sandbox_launch_config_contract_suite.gd`）同步切到新路径，不留旧路径 shim。
- `tests/check_architecture_constraints.sh` 新增反向白名单：`src/battle_core / src/composition / src/shared / scenes` 一律禁止 import `res://src/dev_kit/`。这把“dev_kit 是开发与测试用模块、不参与 production 装配链”这条边界编码进 gate；SandboxSessionBootstrapService 在 `src/adapters/` 是受控例外（适配层允许装配 dev sample factory）。
- `tests/gates/repo_consistency_formal_character_gate*.py` 中所有 pin 到 `src/composition/sample_battle_factory*` 的常量（`FORMAL_ACCESS_SCRIPT_PATH / RUNTIME_REGISTRY_LOADER_PATH / DELIVERY_REGISTRY_LOADER_PATH` 与 cutover gate 的 `sample_factory_text` 读取）一并切到 `src/dev_kit/sample_battle/`，class_name（`SampleBattleFactory*` 全集）保持不变以避免破坏 manifest / suite 引用。

### `battle_core → composition` 反向依赖清零（2026-04-27 Batch B2a）

- `service_dependency_contract_helper.gd` 已下沉为 `src/shared/dependency_contract_helper.gd`（`class_name DependencyContractHelper`），并移除原本依赖的 `BattleCoreServiceSpecs` 句柄；`battle_core` 各 service 改 preload 这份 shared helper 完成 `resolve_missing_dependency` 自检。
- 仅供 composer 使用的 `dependency_edges()` / `compose_reset_specs()` 派生逻辑直接内聚回 `BattleCoreComposer`；shared helper 只暴露 `resolve_missing_dependency` / `compose_deps` / `compose_reset_fields` 三个静态入口。
- `tests/check_architecture_constraints.sh` 的 `battle_core → composition` 白名单已删除：现在 `battle_core` 一律禁止 import `composition`，原 2026-04-19 的受控例外作废。
- composition consistency gate 同步把 helper 入口期望刷成 shared 三函数版，并把 composer 必备 snippet 改为 `DependencyContractHelperScript.compose_deps(` / `.compose_reset_fields(` / `.resolve_missing_dependency(`。

## 2. 组合依赖与编排冻结（2026-04-18）

- compose 依赖与 reset 元数据继续只认 script 自声明：`COMPOSE_DEPS`、`COMPOSE_RESET_FIELDS`。
- `BattleCoreComposer`、runtime 缺依赖检查与两条 architecture gate 统一通过 `src/shared/dependency_contract_helper.gd` 读取这份声明，不再恢复 split wiring specs。
- composition 当前固定只分三层：核心稳定 service slot、payload/runtime slot、owner 私有 helper 实例。
- 单 owner、无独立生命周期、无跨模块复用的 helper，默认只留在 owner 内部，不再继续晋升为 composer service slot。
- 回合编排继续固定为：`turn_selection_resolver.gd`、`turn_start_phase_service.gd`、`turn_end_phase_service.gd`、`turn_field_lifecycle_service.gd`。
- `BattleInitializer` 继续只保留顺序调度；setup 校验、side/unit 构造与初始化阶段子流程分别下沉到独立 owner。
- `SandboxSessionCoordinator` 继续只保留 facade；sandbox 会话热点固定拆成 `bootstrap / demo / command` 三个 owner。

## 3. 正式角色体系（2026-04-12 起，2026-04-18 更新）

### 基础规则

- `docs/records/` 以后只承担活跃记录、决策入口与 archive 索引，不再继续充当现行规则的机器约束层。
- formal 共享字段定义只保留一份真相：`config/formal_registry_contracts.json`、`src/shared/formal_registry_contracts.gd`。
- formal pair 覆盖模型继续固定为：每个无序正式角色对恰好 1 条 interaction spec（1 个 `scenario_key`），派生出 2 条 directed case。gate 与 checklist 不再允许同 pair 多 case。
- Kashimo / Sukuna 的 manager 黑盒继续视为正式交付面的一部分；后续扩角不得跳过 manager 级黑盒。

### Registry 单源与 validator 硬约束

- `config/formal_character_sources/` 现在是 formal 角色 registry 的唯一人工维护入口：
  - `00_shared_matchups.json` 负责共享 `matchups`（含显式 setup / `test_only` 对局）
  - `00_shared_capabilities.json` 负责共享 `capabilities`
  - 每个角色拆成 `0N_<character>.runtime.json` 与 `0N_<character>.delivery.json`；runtime 负责运行时字段、`content_roots`、pair interaction 与共享能力声明，delivery 负责文档和私有 suite 路径
- `config/formal_character_manifest.json` 与 `config/formal_character_capability_catalog.json` 继续提交到仓库，但已经退成生成产物，不再手工维护。
- `content_roots` 允许目录与单文件资源混用，导出时统一递归展开成稳定排序的 `required_content_paths`。
- `content_validator_script_path` 现在是 formal 角色 runtime 合同的必填字段，不再写成"按需"。
- formal gate 当前固定校验：source descriptors 可导出、导出结果与 committed manifest/catalog 完全一致、同一轮里不允许 source 与产物漂移。
- formal delivery 治理不再要求逐角色维护测试名和文档 anchor 清单，改为校验设计稿统一章节结构、调整记录日期章节、suite 可达性和 surface smoke 技能引用。
- 人工同步 committed artifacts 的唯一入口固定为：`bash tests/sync_formal_registry.sh`。

### Manager smoke/blackbox 与 suite 模板化

- `tests/support/formal_character_manager_smoke_helper.gd` 当前固定承担 shared runner：`run_named_case / run_case`、`build_case_state`、`get_legal_actions_result / get_public_snapshot_result / get_event_log_result`、`build_command_result / run_turn_result / run_turn_sequence_result`。
- 四个正式角色的 `manager smoke/blackbox` suite 当前固定写成"case spec + 少量角色断言"，不再各自复制 session / command / close 样板。
- `catalog_factory_suite.gd` 拆成 `setup / delivery_alignment / surface`；`replay_guard_suite.gd` 拆成 `input / summary / failure`；跨域断言只允许留在 shared support。
- formal registry 的 fixture helper 当前默认会补合法 validator 路径；如果坏例不是在测 validator，就不应该先被 validator 缺失抢走失败原因。

### Pair 输入与派生 contract

- formal pair 输入继续固定挂在 `characters[*]` 的 runtime 条目：`pair_token`、`baseline_script_path`、`owned_pair_interaction_specs`。
- `pair_token` 继续作为 formal pair 身份字段；`baseline_script_path` 继续作为 formal baseline 注册字段；`owned_pair_interaction_specs` 继续是唯一手写 pair interaction 输入。
- manifest 角色顺序继续作为 pair interaction ownership 的稳定输入：新正式角色默认追加到末尾，只能声明与更早角色的 `owned_pair_interaction_specs`；重排既有正式角色属于规范变更，必须同步迁移 specs 并记录决策。
- manifest 不再恢复顶层 pair bucket；pair 覆盖与 directed case 继续从 manifest 角色条目派生。

## 4. 外层结果式与回放（2026-04-18）

- `BattleCoreManager` 的外部 envelope 继续固定为：`ok`、`data`、`error_code`、`error_message`。
- 共享结果式构造与 unwrap 当前统一只认：`src/shared/result_envelope_helper.gd`。
- 这轮触及的 adapter / composition / shared formal 访问代码，不再直接散写 `ok/data/error_*` 字典。
- `battle_core/contracts/*` 与 runtime 类契约继续保留；只有序列化边界、gate/export 边界和 manager facade 外层结果式继续使用 `Dictionary`。
- `ReplayOutput` 当前正式新增 `turn_timeline`：初始化完成后固定记录 `turn_index = 0` 的初始 frame，每个完整 turn 结束后固定追加一个 frame，final `public_snapshot` 继续与 timeline 最终 frame 对齐。
- `BattleSandbox` 的 `MODE_DEMO_REPLAY` 当前固定进入只读回放浏览态：允许浏览上一回合 / 下一回合，固定显示当前 frame 的公开快照与事件片段，replay 模式下禁止手动 action 和 policy 推进。
- 2026-04-26 起，manager 边界外的 `run_replay().data.replay_output.event_log` 固定改为公开安全投影，和 `get_event_log_snapshot()` 同口径；完整内部 `LogEvent` 只保留在核心 `ReplayRunner` 内部。
- `run_replay().data.public_snapshot` 固定与 `replay_output.turn_timeline` 最后一帧对齐，不再表述为单独从最终运行态即时重建。
- 回放命令流必须 fail-fast：战斗结束或回合上限后仍有未消费的 `command_stream` turn_index 时，按 `invalid_replay_input` 失败。
- 投降保持“即时结束、不进入行动队列”，但必须先通过 `CommandValidator` 的 side、turn_index 与当前 active actor 校验。

## 5. Sandbox 与研发入口（2026-04-13 起，2026-04-18 更新）

### 主线入口与验证矩阵

- `BattleSandboxController` 继续是当前研发试玩入口；默认路径继续固定为 `gojo_vs_sample + 9101 + manual/policy`。
- BattleSandbox 可见推荐 matchup 的正式角色段从 `config/formal_character_manifest.json` 的 `characters[*].formal_setup_matchup_id` 派生；新增角色不再手工维护 sandbox 推荐名单或 quick smoke 角色名单。
- CLI/debug 启动路径默认启用 strict launch config；非法 matchup / mode / seed / control mode 必须暴露为启动错误，只有 UI 控件内的选择归一化可以保留非 strict 行为。
- `tests/run_with_gate.sh` 继续是默认 quick 总入口，顺序保持：`gdUnit4 quick → boot smoke → suite reachability → architecture constraints → repo consistency → Python lint → sandbox smoke matrix quick`。
- `BattleSandbox`、`run_with_gate`、`run_extended_gate` 与 `gdUnit4 + test/` 继续构成当前仓库的主研发主线。
- CI 当前固定拆成 4 个并行 job（`gdunit`、`repo_and_arch_gates`、`python_lint`、`boot_and_sandbox_smoke`），并与本地总入口共用同一批子脚本。
- `tests/check_gdunit_gate.sh` 与 `tests/check_boot_smoke.sh` 当前固定作为本地与 CI 共用的子入口，不允许出现 CI / 本地分叉脚本。

### README surface 合同与 demo replay smoke

- README / `tests/README.md` 当前只继续承担入口与操作说明，不再镜像 formal 字段清单或长段 contract 正文。
- README 当前继续承担 surface gate 的一部分合同，尤其是代码规模统计与研发入口说明。
- `demo=<profile>` 继续是 CLI/debug 入口，但必须固定自动回归：`tests/check_sandbox_smoke_matrix.sh` 补跑 `legacy` 与 `kashimo` 两个 demo profile，demo replay 摘要上下文固定取 profile 真值。

### BattleSandbox 边界与 SampleBattleFactory 收口

- `BattleSandboxController` 继续保留主入口方法与场景生命周期职责，但不再作为外部可写状态袋：运行态必须下沉到显式 session state，UI 节点引用必须下沉到独立 view refs，测试与 support 层不得再直接读写 `manager / session_id / sample_factory / error_message`。
- `BattleInitializer` 的 `_setup_validator / _phase_service / _state_builder` 继续只做 owner 私有 helper，不升级成 composer service slot；但共享依赖必须通过显式 ports 配置，不再散写 `_sync_*` 赋值。
- `SampleBattleFactory` 允许合并内部 helper 以减少文件数和跳转成本；前提是：公开 facade 方法与 override 入口保持稳定，任何 owner 文件都不能突破 architecture gate 行数限制，引用到的 helper 路径必须同轮完成迁移。

### Formal Character Validator 拆分阈值

- 单个 formal character validator 文件超过 400 行时，应按验证维度（unit / skill / effect / passive / field）拆分为子 validator。
- 拆分后各子 validator 由主 validator 组合调用，保持对外接口不变。

### SampleBattleFactory formal failure 容忍边界（2026-04-26）

- `SampleBattleFactory.available_matchups_result()` 必须在 formal matchup catalog 加载失败时直接 fail-fast；这是 sandbox bootstrap 的角色选择入口，不允许静默吞错。`build_formal_character_setup_result()` / `formal_character_ids_result()` / `formal_unit_definition_ids_result()` / `content_snapshot_paths_result()` 同样 fail-fast。
- 反过来，`build_sample_setup_result()`、`build_demo_replay_input_for_profile_result("legacy")`、以及 `content_snapshot_paths_for_setup_result(baseline_setup)` 三条 baseline-only 入口固定容忍 formal runtime registry / formal matchup catalog 的加载失败。该容忍由 `test/suites/sample_battle_factory_contract_suite.gd` 的 `_test_baseline_setup_ignores_formal_runtime_registry_failure / _test_legacy_demo_ignores_formal_runtime_registry_failure / _test_baseline_flow_ignores_formal_matchup_catalog_failure / _test_baseline_setup_snapshot_ignores_formal_runtime_registry_failure` 锁定。
- 容忍边界的目的：baseline-only 自动化测试不被 formal manifest 状态拖累；formal API 的 fail-fast 仍由专门的 expectation 锁定。新增 SampleBattleFactory 公开方法时必须显式落入"baseline-only 容忍"或"覆盖 formal 必须 fail-fast"两类之一，不允许出现第三种"formal 失败时静默退化"的行为。
- Sandbox `_character_options` 在 view 层加载 `FormalCharacterManifest.build_character_entries_result()` 时也必须 fail-fast：失败时把 manifest 错误透传到 `state.error_message`，让选择页直接展示具体错误而非"当前没有可选角色"。

### SampleBattleFactory 复杂度边界

- `SampleBattleFactory` 内部 helper 文件当前为 10 个（matchup_contracts 61 行、base_snapshot_paths_service 78 行等），各自职责明确，暂不强制合并。后续如新增 matchup 类型导致 helper 继续膨胀，应引入 factory strategy 模式按 matchup 类型分发，而非继续堆叠 helper。软上限调整为 10 个。

### test/ 与 tests/ 目录约定

- `test/` 存放运行时测试套件（gdUnit suite 文件、support bridge 等，由 Godot 直接加载）。
- `tests/` 存放外部验证脚本（gate 脚本、shell runner、Python 检查器等，不由 Godot 加载）。
- 文档中引用时必须准确使用对应目录名，不得混用。

### has_method 鸭子类型使用约定

- `src/` 当前有 20+ 处 `has_method` 调用，多数为防御性 null + capability check（`dispose`、`error_state`、`validate`、`resolve_power_bonus`、`resolve_missing_dependency`、`_compose_post_wire` 等）。
- 短期保留：这些 duck type 检查是合理的防御性模式，强制替换为接口/基类约束改动面大且无直接收益。
- 长期方向：新增核心 service 间交互优先使用显式 port 声明（`COMPOSE_DEPS`），避免新增 `has_method` 调用。现有调用在涉及文件重构时顺带收窄。
- 已确认可直接收窄的低垂果实（对端是定式强类型、方法是契约成员）应一次去掉鸭子检查。2026-04-26 已收窄 `sandbox_session_bootstrap_service.dispose_manager` 中的 `state.manager.has_method("dispose")` / `state.sample_factory.has_method("dispose")` 与 `sandbox_view_presenter._current_player_ui_mode` 中的 `controller.has_method("player_ui_mode")` 三处。

### -> Variant 收窄方向

- 本轮已为 22 个无返回类型标注的函数补充 `-> Variant`。
- 热路径（`BattleState.get_unit` / `get_side`、`SideState.find_unit` 等）因 null 返回仍需保持 `-> Variant`。
- 后续新增函数优先使用具体返回类型；返回 null 场景用 `-> Variant` 并在文档注释中说明。

## 6. Archive 读取顺序

- 查当前仍生效的结构与交付规则：先看本文件，再看 `docs/design/`
- 查 2026-04-10 到 2026-04-18 这轮完整背景：看 `docs/records/archive/decisions_2026-04-10_to_2026-04-18_refactor_wave.md`
- 查更早 repair wave 或 v0.6.3/v0.6.4 背景：看对应历史 archive

## 2026-04-27 Batch A1：effect/log 契约 + apply_field 时序

- `LogEventBuilder.build_event` 对 `event_type` 以 `effect:` 开头时强校验 `payload.cause_event_id` 必须存在且非空：
  - 缺失即 `push_error` + `assert(false)` + 走 `_fail` 回到 INVALID_STATE_CORRUPTION，battle 立即收尾。
  - 决策原因：所有 `effect:*` 写入必须经 `build_effect_event(event_type, battle_state, cause_event_id, payload)` 路径；旧的“在 payload 里塞 cause_event_id 直接调 build_event”绕过点全部收紧，不留 shim。
- `apply_field` 时序：先 `build_effect_event(EFFECT_APPLY_FIELD)` 落地日志，再用其 `event_id`（chain:step 形式）作为 `field_apply` 子 batch 的 cause anchor：
  - 实现方式：`field_apply_effect_runner.execute_field_effects` 增加 `cause_event_id_override` 参数；命中时直接覆写子 batch `effect_event.event_id`，让既有 payload handler 自然把 cause 指向 apply_field 日志。
  - 副作用：失败回滚不再撤掉 apply_field 日志（fail-fast 直接终结战斗，留下日志反而便于排查）；`field_lifecycle_contract_suite._test_field_apply_failure_does_not_commit_field` 删掉“失败时禁止出现 EFFECT_APPLY_FIELD”这条断言，保留 invalid_code + field_state 不落地两条更本质的断言。
- `EffectQueueService.sort_events` 排序键改为 `priority desc → source_order_speed_snapshot desc → source_kind_order asc → source_instance_id asc → sort_random_roll asc → event_id asc`，与 `docs/design/effect_engine.md` 第 51 行对齐：
  - 分组键同步加入 `source_instance_id`，只有同一 source 内才滚 `sort_random_roll`，跨 source 直接走 id 决胜。
  - `effect_queue_service_suite` 拆成两条：cross-source 走 source_instance_id 决胜（不滚 random），same-source 走 random 决胜。
- `FieldState.to_stable_dict` 追加 `pending_success_*` 全部字段（含 `pending_success_chain_context` 序列化为稳定 dict），保证 replay 哈希在 `defer_field_apply_success` 路径下仍可复现。
- `replacement_service` 抽出 `ReplacementChangeSet`（`collect_changes` 收集回滚态、`apply_change_set` 原子还原），把 `event_log.resize` 直接截断封装进 helper；`_snapshot_replacement_runtime` / `_restore_replacement_runtime` 整段删除，无兼容 shim。
