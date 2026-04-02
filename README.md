# Pokemon Battle Core Prototype

概念期 Godot 回合制战斗原型项目（类宝可梦）。

当前目标是先稳定 1v1 战斗核心闭环（可回放、可测试、可扩展），再进入角色与内容扩展阶段。

## 1. 项目定位

- 阶段：概念/原型期（非发布版）
- 核心能力：
  - 1v1、每队 3 单位、固定 Lv50
  - 指令选择、`wait / resource_forced_default` 分流、行动排序、命中/伤害、换人、击倒补位
  - `combat_type` 战斗属性系统（单位 `0..2`、技能 `0..1`、显式克制表）
  - `ultimate_points` 奥义点资源、公开快照与合法性校验
  - `on_matchup_changed`、field 生命周期（自然到期 / 提前打断 / 领域对拼 / 普通 field 阻断 / 成功后附带效果）、被动技能、被动持有物、受限 rule_mod
  - 默认装配可直接加载的 Gojo / Sukuna / Kashimo 正式角色原型内容包
  - deterministic 回放（同输入同结果）
  - 完整日志契约（`log_schema_version = 3`）
- 明确不做：通用状态包、暴击、STAB、属性免疫、主动道具、多目标/双打

## 2. 权威文档入口

规则与实现以这些文档为准：

- 规则权威：`docs/rules/README.md`
- 全局基线：`docs/rules/00_rule_baseline.md`
- 模块规则：`docs/rules/01~06_*.md`
- 工程设计：`docs/design/*.md`

过程记录 `docs/records/tasks.md`、`docs/records/decisions.md` 只记录任务与决策背景，不作为现行规则权威入口。

## 3. 目录结构

```text
content/                # 战斗定义资源（.tres）
  battle_formats/
  samples/              # 最小可运行样例与样例对局资源
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
  composition/          # 依赖装配
  adapters/             # UI/输入适配
  shared/               # 通用常量与工具
tests/
  suites/               # 回归测试套件
    lifecycle_core_suite.gd
    forced_replace_suite.gd
    gojo_suite.gd
    sukuna_suite.gd
    ultimate_field_suite.gd
    adapter_contract_suite.gd
    trigger_validation_suite.gd
  support/              # 测试 harness 与公共构造器
  fixtures/             # 预留样例输入与内容快照
  helpers/              # 测试辅助与批量探针脚本
  gates/                # README/文档/注册表一致性细分 gate
  replay_cases/         # 固定 deterministic 回放 / 复查案例
  run_all.gd            # 测试入口
  run_with_gate.sh      # 测试闸门（断言 + 引擎错误 + 架构 + 仓库一致性）
  check_repo_consistency.sh # README/文档/关键回归一致性闸门聚合入口
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

架构约束见：`docs/design/battle_core_architecture_constraints.md`。

## 5. 运行与测试

### 5.1 运行 Sandbox

```bash
godot --path .
```

默认会进入 `BattleSandbox` 并运行 Kashimo 演示回放；如需保留旧样例演示，可追加命令行参数 `demo=legacy`。

### 5.2 运行完整闸门（推荐）

```bash
tests/run_with_gate.sh
```

闸门通过条件：

- 业务断言全部通过（`tests/run_all.gd`）
- headless 主流程启动 smoke 通过（`godot --headless --path . --quit-after 20`）
- 无引擎级 warning（`WARNING:`）
- suite 可达性检查通过（`tests/check_suite_reachability.sh`）
- 无引擎级错误（`SCRIPT ERROR / Compile Error / Parse Error / Failed to load script`）
- 架构约束检查通过（`tests/check_architecture_constraints.sh`）
- 仓库一致性检查通过（`tests/check_repo_consistency.sh`）
  - 当前会聚合 `tests/gates/repo_consistency_surface_gate.py`、`tests/gates/repo_consistency_formal_character_gate.py`、`tests/gates/repo_consistency_docs_gate.py`

## 6. 对外核心接口（Manager）

`BattleCoreManager` 当前稳定入口：

- `create_session(init_payload)`（返回“已预回首回合 MP 后”的初始公开快照；这次预回蓝不补写进初始 `event_log`）
- `get_legal_actions(session_id, side_id)`
- `build_command(input_payload)`
- `run_turn(session_id, commands)`
- `get_public_snapshot(session_id)`
- `get_event_log_snapshot(session_id, from_index = 0)`（返回 `{ events, total_size }`；供调试与固定案例复查读取只读日志增量快照，且只暴露公开安全字段）
- `close_session(session_id)`
- `run_replay(replay_input)`
- `active_session_count()`（返回当前活跃会话数量）
- `dispose()`（释放全部会话与管理器依赖）
- `resolve_missing_dependency()`（返回缺失依赖名；为空表示依赖完整）

其中 `run_replay` 使用临时容器隔离执行，不污染活跃会话池。
对外返回结构固定为 `{ replay_output, public_snapshot }`，其中 `replay_output.final_battle_state` 必须为 `null`，运行态对象不得越过 manager 边界。
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
- `combat_type_chart` 使用强类型 `CombatTypeChartEntry` 资源条目，不做代码侧反向推导
- `combat_type` 与 `damage_kind` 完全独立；缺失 pair 默认 `1.0`
- `on_receive_effect_ids` 为禁用迁移字段（历史保留字段），非空即失败
- `EffectDefinition.stacking` 已开放 `stack`
- `FieldDefinition` 已包含 `on_expire_effect_ids / on_break_effect_ids / creator_accuracy_override`
- 触发点当前包含 `field_apply / field_break / field_expire / on_expire`，并要求引用关系与触发器声明一致
- field 持续时间不写在 `FieldDefinition`；由施加它的 `EffectDefinition.duration / decrement_on` 决定
- `RuleModPayload` 已支持 `dynamic_value_formula` 运行时求值（当前仅开放 `matchup_bst_gap_band`，且只允许单位 owner 的数值 rule_mod 使用；该公式按 `max_hp + attack + defense + sp_attack + sp_defense + speed + max_mp` 的绝对差求值）
- `BattleFormatConfig` 已包含 `visibility_mode / selection_deadline_ms / max_chain_depth / default_recoil_ratio / domain_clash_tie_threshold`
- `UnitDefinition` 已包含 `max_mp / init_mp / regen_per_turn / ultimate_points_required / ultimate_points_cap / ultimate_point_gain_on_regular_skill_cast`
- `UnitDefinition.skill_ids` 表示默认装配的 3 个常规技能；`candidate_skill_ids` 表示可供赛前替换的常规技能候选池（为空表示没有额外候选池）
- 普通技能与奥义优先级约束分离校验
- `BattleSetup.sides[*].regular_skill_loadout_overrides` 已开放赛前常规三技能覆盖，键固定为队伍槽位下标，值固定为本场实际装配的 3 个常规技能
- `SampleBattleFactory.content_snapshot_paths()` 统一从 `content/battle_formats / combat_types / units / skills / passive_items / effects / fields / passive_skills / samples` 递归自动收集 `.tres`，并做稳定排序，避免角色接线漏资源与回放漂移

### 8.1 正式角色资源

- `Gojo`：默认技能组 `苍 / 赫 / 茈`（`gojo_ao / gojo_aka / gojo_murasaki`），候选技能池 `candidate_skill_ids = 苍 / 赫 / 茈 / 反转术式`，奥义 `无量空处`，被动 `无下限`，奥义点 `required=3 / cap=3 / regular skill cast +1`
- `宿傩`：默认技能组 `解 / 捌 / 开`（`sukuna_kai / sukuna_hatsu / sukuna_hiraku`），奥义 `伏魔御厨子`，被动 `教会你爱的是...`，候选技能池 `candidate_skill_ids = 解 / 捌 / 开 / 反转术式`，奥义点 `required=3 / cap=3 / regular skill cast +1`；MP 回复按“基础 `12` + 对位追加值”结算
- `Kashimo`：默认技能组 `雷拳 / 蓄电 / 回授电击`（`kashimo_raiken / kashimo_charge / kashimo_feedback_strike`），候选技能池 `candidate_skill_ids = 雷拳 / 蓄电 / 回授电击 / 弥虚葛笼`，奥义 `幻兽琥珀`，被动 `电荷分离`，奥义点 `required=3 / cap=3 / regular skill cast +1`
- `poison` 已作为正式 `combat_type` 接入主线；仓库内同时保留独立样例技能 `sample_poison_sting` 与对应 runtime suite，用来验证它不是鹿紫云专属的临时标签
- 赛前覆盖：`SideSetup.regular_skill_loadout_overrides` 可把候选常规技能换入本场装配；未提供覆盖时，行为等价于使用默认 `skill_ids`
- 公开快照：`prebattle_public_teams[*].units[*].skill_ids` 只公开本场实际已装备的常规技能，不公开候选池全集

### 8.2 角色接入工作流

正式角色接入当前固定走同一套资产流程：

- 设计稿：`docs/design/<character>_design.md`
- 调整记录：`docs/design/<character>_adjustments.md`
- 设计模板：`docs/design/formal_character_design_template.md`
- 接入清单：`docs/design/formal_character_delivery_checklist.md`
- 内容资源：`content/units|skills|effects|fields|passive_skills`
- 样例接线：`SampleBattleFactory`
- 角色注册：`docs/records/formal_character_registry.json`
- 共享内容校验：若角色有跨资源共享不变量，可在 formal registry 里登记可选 `content_validator_script_path`，内容快照校验会自动装配并 fail-fast
- 注册表锚点：除 wrapper `suite_path` 外，还固定登记 `required_suite_paths / required_test_names`；共享 suite（如 `ultimate_field_suite.gd`）也必须显式挂回角色正式交付面
- 专项回归：`tests/suites/<character>_suite.gd`，并通过注册表接入 `tests/run_all.gd` 与一致性门禁
- 资源快照：`tests/suites/<character>_snapshot_suite.gd` 用显式字面量断言锁死正式角色面板、技能、关键 effect / field / passive 资源
- manager smoke：`tests/suites/<character>_manager_smoke_suite.gd`，固定覆盖公开 facade 主路径
- 固定案例：必要时补 `tests/replay_cases/*` 与对应 runner / 说明
- 当前仓库已内置两组固定诊断入口：`tests/helpers/domain_case_runner.gd`（领域）与 `tests/helpers/kashimo_case_runner.gd`（鹿紫云）

当前已落地的固定案例入口：

- `tests/replay_cases/domain_cases.md`：领域与对拼复查
- `tests/replay_cases/kashimo_cases.md`：鹿紫云电荷主循环 / 琥珀换人 / 弥虚葛笼复查

当前 Gojo、Sukuna 与 Kashimo 都必须满足这套交付面，后续新角色默认沿用。

## 9. 日志与回放契约

- `log_schema_version` 固定为 `3`
- 存在且仅存在 1 条 `system:battle_header`
- effect 事件必须具备 `trigger_name / cause_event_id`
- `cause_event_id` 固定指向真实上游触发事件：直接伤害/反伤指向 `action:hit`，effect payload 指向内部 `effect_event_*`，系统结算到期链指向对应系统锚点
- 相同 `seed + content snapshot + command stream` 输出稳定哈希

参考：`docs/design/log_and_replay_contract.md`

## 10. 当前代码规模（2026-04-02）

- `src/**/*.gd`：`10898` 行
- `tests/**/*.gd`：`13871` 行
- GDScript 合计：`24769` 行

> 统计口径：`find src tests -name '*.gd' | xargs wc -l`

## 11. 后续扩展建议（进入角色设计前）

建议按以下顺序推进，避免基础层返工：

1. 继续保持“规则先行”：新增机制先改 `docs/rules`，再改实现。
2. 角色设计优先复用现有 payload 与触发点，不先扩流程控制口。
3. 正式角色接入必须同时落 `设计稿 + 调整记录 + 内容资源 + SampleFactory 接线 + 角色 suite`，必要时再补固定案例与复查入口。
4. 新角色/技能回归至少覆盖命中、伤害、生命周期、日志字段与公开快照。
5. 每个小任务都走 `tests/run_with_gate.sh`，再进入下一步扩展。
