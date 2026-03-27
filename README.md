# Pokemon Battle Core Prototype

概念期 Godot 回合制战斗原型项目（类宝可梦）。

当前目标是先稳定 1v1 战斗核心闭环（可回放、可测试、可扩展），再进入角色与内容扩展阶段。

## 1. 项目定位

- 阶段：概念/原型期（非发布版）
- 核心能力：
  - 1v1、每队 3 单位、固定 Lv50
  - 指令选择、行动排序、命中/伤害、换人、击倒补位
  - `combat_type` 战斗属性系统（单位 `0..2`、技能 `0..1`、显式克制表）
  - field、被动技能、被动持有物、受限 rule_mod
  - deterministic 回放（同输入同结果）
  - 完整日志契约（`log_schema_version = 3`）
- 明确不做：通用状态包、暴击、STAB、属性免疫、主动道具、多目标/双打

## 2. 权威文档入口

规则与实现以这些文档为准：

- 规则权威：`docs/rules/README.md`
- 全局基线：`docs/rules/00_rule_baseline.md`
- 模块规则：`docs/rules/01~06_*.md`
- 工程设计：`docs/design/*.md`
- 过程记录：`docs/records/tasks.md`、`docs/records/decisions.md`

说明：`docs/records/archive/` 与 `docs/records/battle_system_rules.md` 仅用于历史追溯，不作为现行实现依据。

## 3. 目录结构

```text
content/                # 战斗定义资源（.tres）
  samples/              # 最小可运行样例
  combat_types/
  units/
  skills/
  passive_skills/
  passive_items/
  effects/
  fields/
  battle_formats/
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
  adapters/             # UI/AI 适配
  shared/               # 通用常量与工具
tests/
  suites/               # 回归测试套件
    lifecycle_core_suite.gd
    forced_replace_suite.gd
  support/              # 测试 harness 与公共构造器
  fixtures/             # 预留样例输入与内容快照
  helpers/              # 预留测试辅助脚本
  replay_cases/         # 预留 deterministic 回放案例
  run_all.gd            # 测试入口
  run_with_gate.sh      # 测试闸门（断言 + 引擎错误）
```

## 4. 架构分层（核心）

- `runtime`：唯一运行态真相（`BattleState` 等）
- `content`：内容 `Resource` 类型与快照加载校验
- `contracts`：跨模块强类型契约（`Command`、`LogEvent`、`ReplayInput`...）
- `commands`：合法性计算、指令构建与校验
- `turn`：回合编排（`turn_start -> selection -> queue_lock -> execution -> turn_end`）
- `actions`：单行动执行与目标解析
- `math`：纯计算服务（命中、伤害、能力阶段、属性克制）
- `effects`：触发收集、排序、payload 协调执行、rule_mod
- `lifecycle`：离场/倒下/补位链
- `passives`：被动技能、被动持有物、field 接入
- `logging`：日志构造、回放、确定性校验
- `facades`：对外稳定接口（Manager + Session）

架构约束见：`docs/design/battle_core_architecture_constraints.md`。

## 5. 运行与测试

### 5.1 运行 Sandbox

```bash
godot --path .
```

### 5.2 运行完整闸门（推荐）

```bash
tests/run_with_gate.sh
```

闸门通过条件：

- 业务断言全部通过（`tests/run_all.gd`）
- 无引擎级错误日志（`SCRIPT ERROR / Compile Error / Parse Error / Failed to load script`）
- 架构约束检查通过（`tests/check_architecture_constraints.sh`）

## 6. 对外核心接口（Manager）

`BattleCoreManager` 当前稳定入口：

- `create_session(init_payload)`
- `get_legal_actions(session_id, side_id)`
- `build_command(input_payload)`
- `run_turn(session_id, commands)`
- `get_public_snapshot(session_id)`
- `close_session(session_id)`
- `run_replay(replay_input)`
- `active_session_count()`（返回当前活跃会话数量）
- `dispose()`（释放全部会话与管理器依赖）
- `resolve_missing_dependency()`（返回缺失依赖名；为空表示依赖完整）

其中 `run_replay` 使用临时容器隔离执行，不污染活跃会话池。

## 7. 内容资源最小 Schema

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
- `on_receive_effect_ids` 为禁用迁移字段，非空即失败
- 普通技能与奥义优先级约束分离校验

## 8. 日志与回放契约

- `log_schema_version` 固定为 `3`
- 存在且仅存在 1 条 `system:battle_header`
- effect 事件必须具备 `trigger_name / cause_event_id`
- 相同 `seed + content snapshot + command stream` 输出稳定哈希

参考：`docs/design/log_and_replay_contract.md`

## 9. 当前代码规模（2026-03-27）

- `src/**/*.gd`：`6036` 行
- `tests/**/*.gd`：`3575` 行
- GDScript 合计：`9611` 行

> 统计口径：`find src tests -name '*.gd' | xargs wc -l`

## 10. 后续扩展建议（进入角色设计前）

建议按以下顺序推进，避免基础层返工：

1. 继续保持“规则先行”：新增机制先改 `docs/rules`，再改实现。
2. 角色设计优先复用现有 payload 与触发点，不先扩流程控制口。
3. 新角色/技能接入必须附带回归用例（至少覆盖命中、伤害、生命周期、日志字段）。
4. 每个小任务都走 `tests/run_with_gate.sh`，再进入下一步扩展。
