# Pokemon Battle Core

Godot 回合制战斗引擎项目（类宝可梦）。

当前目标是先稳定 1v1 战斗核心闭环（可回放、可测试、可扩展），再进入角色与内容扩展阶段。

## 1. 项目定位

- 阶段：长期工程（非发布版）
- 核心能力：
  - 1v1、每队 3 单位、固定 Lv50
  - 指令选择、`wait / resource_forced_default` 分流、行动排序、命中/伤害、换人、击倒补位
  - `combat_type` 战斗属性系统（单位 `0..2`、技能 `0..1`、显式克制表）
  - `ultimate_points` 奥义点资源、公开快照与合法性校验
  - `on_matchup_changed`、field 生命周期（自然到期 / 提前打断 / 领域对拼 / 普通 field 阻断 / 成功后附带效果）、被动技能、被动持有物、受限 rule_mod
  - 默认装配可直接加载的 Gojo / Sukuna / Kashimo / Obito 正式角色原型内容包
  - deterministic 回放（同输入同结果）
  - 完整日志契约（`log_schema_version = 3`）
- 明确不做：通用状态包、暴击、STAB、属性免疫、主动道具、多目标/双打

## 2. 权威文档入口

规则与实现以这些文档为准：

- 规则权威：`docs/rules/README.md`
- 全局基线：`docs/rules/00_rule_baseline.md`
- 模块规则：`docs/rules/01~06_*.md`
- 工程设计：`docs/design/*.md`
- 当前研发工作流：`docs/design/current_development_workflow.md`

过程记录 `docs/records/tasks.md`、`docs/records/decisions.md` 只记录任务与决策背景，不作为现行规则权威入口。

## 3. 目录结构

```text
content/                # 战斗定义资源（.tres）
  battle_formats/
  samples/              # 最小可运行样例与样例对局资源
  shared/               # 供内容资源复用的非顶层辅助 Resource，不直接参与 snapshot 注册
  combat_types/
  units/
  skills/
  passive_skills/
  passive_items/
  effects/
  fields/
docs/
  rules/                # 规则权威
  design/               # 工程实现说明
  records/              # 任务与决策记录
scenes/
  boot/                 # 主入口
  sandbox/              # 原型试跑场景
src/
  battle_core/          # 核心引擎
    content/formal_validators/  # 正式角色 formal validator（shared + per-character）
    effects/payload_handlers/   # payload handler 与 payload 子 runtime service
  composition/          # 依赖装配与 compose metadata helper
  adapters/             # UI/输入适配
  shared/               # 通用常量与工具
test/
  suites/               # gdUnit4 业务回归 suite（唯一 Godot 业务测试目录）
  support/              # gdUnit4 suite 公共基类与少量桥接资源
tests/
  support/              # 共享 harness、构局 helper 与固定案例 support
  fixtures/             # 预留样例输入与内容快照
  helpers/              # 测试辅助与批量探针脚本
  gates/                # README/文档/注册表一致性细分 gate
  replay_cases/         # 固定 deterministic 回放 / 复查案例
  run_gdunit.sh         # gdUnit4 CLI 入口（支持单 suite/单目录过滤与报告输出）
  run_with_gate.sh      # quick 测试闸门（断言 + 引擎错误 + 架构 + 仓库一致性）
  run_extended_gate.sh  # extended 测试闸门（长尾 gdUnit + full sandbox smoke）
  check_repo_consistency.sh # README/文档/关键回归一致性闸门聚合入口
  cleanup_local_artifacts.sh # 清理废弃本地报告目录与 scratch 目录
```

## 4. 架构分层（核心）

- `runtime`：唯一运行态真相（`BattleState` 等）
- `content`：内容 `Resource` 类型与快照加载校验
- `contracts`：跨模块强类型契约（`Command`、`LogEvent`、`ReplayInput`...）
- `commands`：合法性计算、指令构建与校验
- `turn`：回合编排与子域协调（初始化、选指解析、field/对位生命周期、`turn_start -> selection -> queue_lock -> execution -> turn_end`）
- `actions`：单行动执行与目标解析
- `math`：纯计算服务（命中、伤害、能力阶段、属性克制）
- `effects`：触发收集、排序、payload 协调执行、effect 实例管理、`rule_mod` 读写拆分
- `lifecycle`：离场/倒下/补位链
- `passives`：被动技能、被动持有物、field 落地/对拼/生命周期
- `logging`：日志构造、回放、确定性校验
- `facades`：对外稳定接口（唯一稳定 facade 是 `BattleCoreManager`；`BattleCoreSession` 只是内部会话壳）
- `BattleCoreManager`、`LegalActionService`、`BattleResultService` 等大型 owner 均已按职责拆分为 owner + helper 结构

架构约束与拆分细节见：`docs/design/battle_core_architecture_constraints.md`。

## 5. 运行与测试

### 5.1 运行 Sandbox

```bash
godot --path .
```

日常研发的推荐顺序、允许改动边界和文档更新顺序，统一看 `docs/design/current_development_workflow.md`。
当前推荐复查命令和最小可玩性检查，统一看 `docs/design/current_stage_regression_baseline.md`。

默认会进入 `BattleSandbox` 的单人研发试玩 sandbox，固定 launch config 为 `mode=manual_matchup`、`matchup_id=gojo_vs_sample`、`battle_seed=9101`、`p1_control_mode=manual`、`p2_control_mode=policy`，启动后停在 `P1` 选指界面。
HUD 当前支持按当前配置重开：`matchup` 下拉、`battle_seed` 输入、`P1 control mode`、`P2 control mode` 和重启按钮。控制模式只支持 `manual | policy`；预设对局列表来自 `SampleBattleFactory.available_matchups_result()`，UI 默认只显示非 `test_only` matchup，并按 `gojo_vs_sample -> kashimo_vs_sample -> obito_vs_sample -> sukuna_setup -> sample_default -> 其余可见 matchup` 的推荐顺序展示。状态区固定补出当前配置摘要、当前轮到谁操作与 policy 状态、已提交指令摘要、稳定 `battle_summary` 和按回合分隔的最近日志；`manual/manual` 与 `policy/policy` 继续保留为显式模式。
如需复查旧自动回放，可追加命令行参数 `-- demo=<profile>`，例如 `godot --path . -- demo=legacy`。demo profile 的单一真相仍在 `config/demo_replay_catalog.json`；`BattleSandboxController` 在检测到 `demo=<profile>` 时会进入只读回放浏览态，固定消费 `ReplayOutput.turn_timeline`，并通过“上一回合 / 下一回合”浏览 frame，不再允许提交 action。当前 smoke matrix 会动态覆盖 catalog 中全部 demo profile。

### 5.2 Sandbox 主验证入口

```bash
godot --headless --path . --script tests/helpers/manual_battle_full_run.gd
godot --headless --path . --script tests/helpers/manual_battle_submit_full_run.gd
P1_MODE=manual P2_MODE=manual godot --headless --path . --script tests/helpers/manual_battle_full_run.gd
MATCHUP_ID=kashimo_vs_sample P1_MODE=manual P2_MODE=policy godot --headless --path . --script tests/helpers/manual_battle_full_run.gd
P1_MODE=policy P2_MODE=policy godot --headless --path . --script tests/helpers/manual_battle_full_run.gd
```

`tests/helpers/manual_battle_full_run.gd` 是当前 `BattleSandbox` 的主 smoke 入口；省略环境变量时，默认沿用 sandbox 基线 `gojo_vs_sample + 9101 + manual/policy`。`tests/helpers/manual_battle_submit_full_run.gd` 保留为 submit 链路的显式入口，当前与主 smoke 一样通过 `BattleSandboxController.submit_action()` 推进。两个脚本当前都支持：

- `MATCHUP_ID`
- `BATTLE_SEED`
- `P1_MODE`
- `P2_MODE`

输出固定为统一的 `battle_summary` JSON，至少包含：

- `matchup_id`
- `battle_seed`
- `p1_control_mode`
- `p2_control_mode`
- `winner_side_id`
- `reason`
- `result_type`
- `turn_index`
- `event_log_cursor`
- `command_steps`

这样可以直接对比 `manual/manual`、`manual/policy`、`policy/policy` 三条主路径，并保留稳定的 submit 命令入口。

### 5.3 formal 产物同步

formal 角色的唯一人工维护入口是 `config/formal_character_sources/`。
source descriptor 变更后，统一通过下面这条命令同步生成产物：

```bash
bash tests/sync_formal_registry.sh
```

它会回写：

- `config/formal_character_manifest.json`
- `config/formal_character_capability_catalog.json`

这两份文件继续提交到仓库，但不再手工维护。

### 5.4 运行闸门（推荐）

```bash
tests/run_with_gate.sh
```

默认 `tests/run_with_gate.sh` 是 quick gate；长尾回归用 `tests/run_extended_gate.sh`，完整收口用 `TEST_PROFILE=full bash tests/run_with_gate.sh`。

闸门通过条件：

- `tests/run_with_gate.sh` 内部顺序固定为：`gdUnit4 quick -> boot smoke -> suite reachability -> architecture constraints -> repo consistency -> Python lint -> sandbox smoke matrix quick`
- 本地与 CI 共用子入口：
  - `bash tests/check_gdunit_gate.sh`
  - `bash tests/check_boot_smoke.sh`
- 业务断言通过（`tests/run_gdunit.sh` -> `gdUnit4`；默认 `TEST_PROFILE=quick`，显式 `extended|full` 扫描 `res://test`）
- 产出可消费测试报告（`JUnit XML + HTML`，默认落在 `reports/gdunit`）
- 废弃本地产物可通过 `bash tests/cleanup_local_artifacts.sh` 清理；当前只认 `reports/gdunit` 为有效报告目录
- headless 主流程启动 smoke 通过（`bash tests/check_boot_smoke.sh`），且不得出现 `BATTLE_SANDBOX_FAILED:` 应用层失败标记
- 无引擎级 warning（`WARNING:`）
- suite 可达性检查通过（`tests/check_suite_reachability.sh`）
- 无引擎级错误（`SCRIPT ERROR / Compile Error / Parse Error / Failed to load script`）
- 架构约束检查通过（`tests/check_architecture_constraints.sh`）
  - 当前额外包含 composition `SERVICE_DESCRIPTORS / container API / wiring_specs` 一致性检查，以及 runtime wiring DAG 检查
- 仓库一致性检查通过（`tests/check_repo_consistency.sh`）
  - 当前会聚合 `tests/gates/repo_consistency_surface_gate.py`、`tests/gates/repo_consistency_formal_character_gate.py`、`tests/gates/repo_consistency_docs_gate.py`
- sandbox smoke matrix 通过（`tests/check_sandbox_smoke_matrix.sh`，默认 `SANDBOX_SMOKE_SCOPE=quick`，覆盖推荐 matchup、所有 `<pair>_vs_sample` 主路径、默认 matchup 的 `policy/policy` 与 `manual/manual`、默认 matchup 的 submit 入口，以及全部 demo profile；设 `SANDBOX_SMOKE_SCOPE=full` 可覆盖全部可见 matchup）

## 6. 对外核心接口（Manager）

`BattleCoreManager` 当前稳定入口：

- `create_session(init_payload)`（返回“已预回首回合 MP 后”的初始公开快照；这次预回蓝不补写进初始 `event_log`）
- `get_legal_actions(session_id, side_id)`
- `build_command(input_payload)`
- `run_turn(session_id, commands)`
- `get_public_snapshot(session_id)`（返回与运行态断引用的公开快照）
- `get_event_log_snapshot(session_id, from_index = 0)`（返回 `{ events, total_size }`；供调试与固定案例复查读取只读日志增量快照，且只暴露公开安全字段，并与内部日志断引用）
- `close_session(session_id)`
- `run_replay(replay_input)`
- `active_session_count()`（返回当前活跃会话数量）
- `dispose()`（释放全部会话与管理器依赖）
- `resolve_missing_dependency()`（返回缺失依赖名；为空表示依赖完整）

其中 `run_replay` 使用临时容器隔离执行，不污染活跃会话池。
对外返回结构固定为 manager envelope：`{ ok, data, error_code, error_message }`。
成功时 `data = { replay_output, public_snapshot }`，其中 `replay_output.final_battle_state` 必须为 `null`，运行态对象不得越过 manager 边界。
失败时 `data = null`，并返回明确的 `error_code / error_message`。
内部 `ReplayRunner` 仍保留 `final_battle_state`，用于计算 `final_state_hash` 与回放诊断，不对外透传。
`BattleCoreSession` 只作为 manager 内部持有的会话对象，不属于外围稳定入口。
`BattleCoreManager` 现在也不再直接持有完整 composition root；若需要装配容器，只允许依赖一个 build-container callable / factory port。

`get_event_log_snapshot()` 对外固定补公开归因字段：

- `actor_public_id / actor_definition_id`
- `target_public_id / target_definition_id`
- `killer_public_id / killer_definition_id`
- `value_changes[].entity_public_id / entity_definition_id`

同时明确不再暴露 `actor_id / source_instance_id / target_instance_id / killer_id / value_changes[].entity_id`。

## 7. 外层 ID 契约

- `unit_id`：只用于内容定义、队伍构筑与资源引用。
- `public_id`：当前唯一外层输入/输出 ID。玩家输入、合法性列表、公开快照、换人目标、回放输入都只使用它。
- `unit_instance_id`：只允许留在核心内部运行态、内部日志归因、内部排序和系统自动动作里，不对外暴露。

当前对外稳定 contract 已收口为：

- `LegalActionSet.actor_public_id`
- `LegalActionSet.legal_switch_target_public_ids`
- 外层 `Command` 默认提交 `actor_public_id / target_public_id`

`actor_id / target_unit_id` 仍保留，但只用于核心内部与系统自动注入路径。
`forced_command_type` 只作为合法性结果的引擎侧信号，自动注入统一由 `TurnSelectionResolver` 执行。

## 8. 内容资源最小 Schema

主要资源类型：

- `BattleFormatConfig`
- `CombatTypeDefinition`
- `UnitDefinition`
- `SkillDefinition`
- `PassiveSkillDefinition`
- `PassiveItemDefinition`
- `EffectDefinition`
- `FieldDefinition`

加载入口：`src/battle_core/content/battle_content_index.gd`

特点：

- 加载期强校验（非法内容直接 fail-fast）
- `combat_type_chart` 使用强类型 `CombatTypeChartEntry`，`combat_type` 与 `damage_kind` 完全独立
- field 持续时间由施加它的 `EffectDefinition.duration / decrement_on` 决定，不写在 `FieldDefinition`
- `SkillDefinition` 支持 `damage_segments`（多段伤害）、`execute_*` 条件执行
- `RuleModPayload` 支持 `dynamic_value_formula` 运行时求值
- `UnitDefinition` 包含 MP、奥义点、候选技能池完整字段
- `SampleBattleFactory` 拆为 owner + setup/override/snapshot helper，统一走结果式接口
- `SampleBattleFactory.content_snapshot_paths_result()` 固定覆盖 `content/battle_formats / combat_types / units / skills / passive_items / effects / fields / passive_skills / samples`
- 共享 payload 放 `content/shared/`，不参与顶层 snapshot 注册

完整 Schema 细节见：`docs/design/battle_content_schema.md`。

### 8.1 正式角色资源

- `Gojo`：默认技能组 `苍 / 赫 / 茈`（`gojo_ao / gojo_aka / gojo_murasaki`），候选技能池 `candidate_skill_ids = 苍 / 赫 / 茈 / 反转术式`，奥义 `无量空处`，被动 `无下限`，奥义点 `required=3 / cap=3 / regular skill cast +1`
- `宿傩`：默认技能组 `解 / 捌 / 开`（`sukuna_kai / sukuna_hatsu / sukuna_hiraku`），奥义 `伏魔御厨子`，被动 `教会你爱的是...`，候选技能池 `candidate_skill_ids = 解 / 捌 / 开 / 反转术式`，奥义点 `required=3 / cap=3 / regular skill cast +1`；MP 回复按“基础 `12` + 对位追加值”结算
- `Kashimo`：默认技能组 `雷拳 / 蓄电 / 回授电击`（`kashimo_raiken / kashimo_charge / kashimo_feedback_strike`），候选技能池 `candidate_skill_ids = 雷拳 / 蓄电 / 回授电击 / 弥虚葛笼`，奥义 `幻兽琥珀`，被动 `电荷分离`，奥义点 `required=3 / cap=3 / regular skill cast +1`
- `Obito`：默认技能组 `求道焦土 / 阴阳遁 / 求道玉`（`obito_qiudao_jiaotu / obito_yinyang_dun / obito_qiudao_yu`），候选技能池 `candidate_skill_ids = 求道焦土 / 阴阳遁 / 求道玉 / 六道十字奉火`，奥义 `十尾尾兽玉`，被动 `仙人之力`，奥义点 `required=3 / cap=3 / regular skill cast +1`
- `poison` 已作为正式 `combat_type` 接入主线；仓库内同时保留独立样例技能 `sample_poison_sting` 与对应 runtime suite，用来验证它不是鹿紫云专属的临时标签
- prototype 额外内置一个最小正式 passive item 样例：`sample_attack_charm` 绑定到 `sample_pyron_charm`，用于锁被动持有物的内容加载、公开快照、manager 黑盒与 replay 主路径
- 赛前覆盖：`SideSetup.regular_skill_loadout_overrides` 可把候选常规技能换入本场装配；未提供覆盖时，行为等价于使用默认 `skill_ids`
- 公开快照：`prebattle_public_teams[*].units[*].skill_ids` 只公开本场实际已装备的常规技能，不公开候选池全集

### 8.2 角色接入工作流

正式角色接入继续只认一条主线：

- 唯一人工真相：`config/formal_character_sources/`
- 唯一人工同步入口：`bash tests/sync_formal_registry.sh`
- committed 生成产物：`config/formal_character_manifest.json`、`config/formal_character_capability_catalog.json`
- runtime / tests / gate 都只消费生成后的 manifest / capability catalog

角色 source descriptor 继续固定承载正式交付合同，包括：

- `content_validator_script_path`
- `pair_token`
- `baseline_script_path`
- `owned_pair_interaction_specs`
- `shared_capability_ids`

详细接入动作不再在 README 展开，统一看：

- 接入清单：`docs/design/formal_character_delivery_checklist.md`
- 设计模板：`docs/design/formal_character_design_template.md`
- 共享能力说明：`docs/design/formal_character_capability_catalog.md`

当前 Gojo、Sukuna、Kashimo 与 Obito 都继续沿用这套单源交付面。

## 9. 日志与回放契约

- `log_schema_version` 固定为 `3`
- 存在且仅存在 1 条 `system:battle_header`
- effect 事件必须具备 `trigger_name / cause_event_id`
- `cause_event_id` 固定指向真实上游触发事件：直接伤害/反伤指向 `action:hit`，effect payload 指向内部 `effect_event_*`，系统结算到期链指向对应系统锚点
- 相同 `seed + content snapshot + command stream` 输出稳定哈希

参考：`docs/design/log_and_replay_contract.md`

## 10. 当前代码规模（2026-04-25）

- `src/**/*.gd`：`22864` 行
- `test/**/*.gd`：`21953` 行
- `tests/**/*.gd`：`5223` 行
- GDScript 合计：`50040` 行

> 统计口径：与 repo consistency gate 一致，按 `.gd` 文件中的换行数累计统计。

## 11. 后续扩展建议（进入角色设计前）

建议按以下顺序推进，避免基础层返工：

1. 继续保持“规则先行”：新增机制先改 `docs/rules`，再改实现。
2. 角色设计优先复用现有 payload 与触发点，不先扩流程控制口。
3. 正式角色接入必须同时落 `设计稿 + 调整记录 + 内容资源 + SampleFactory 接线 + 角色 suite`，必要时再补固定案例与复查入口。
4. 新角色/技能回归至少覆盖命中、伤害、生命周期、日志字段与公开快照。
5. 每个小任务都走 `tests/run_with_gate.sh`，再进入下一步扩展。
