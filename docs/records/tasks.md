# 任务清单（精简版）

本文件只保留最近任务与当前回归要点，避免历史条目干扰实现。

历史完整记录已归档到：

- `docs/records/archive/tasks_pre_v0.6.3.md`

当前生效规则以 `docs/rules/` 为准。

## 2026-03-29

### 战斗规则重构 + 角色规范化工作流（已完成）
- 目标：按阶段 A-E 一次性收口奥义点、领域对拼、领域 buff 跟 field 生命周期走、热点文件最小拆分、角色设计稿/调整记录规范与统一闸门。
- 范围：`src/battle_core/**/*`、`src/composition/*`、`content/**/*`、`docs/design/*`、`docs/rules/*`、`docs/records/*`、`README.md`、`content/README.md`、`tests/**/*`；按“规则/实现/文档/闸门”四层同步，不留单边漂移。
- 验收标准：
  - 奥义点、领域对拼、Gojo 锁人成功条件、field 绑定增幅都已落代码并有专项回归
  - `BattleCoreComposer / BattleCoreContainer`、`RuleModService`、field apply 主路径、`SampleBattleFactory.content_snapshot_paths()` 完成最小收口
  - Gojo / Sukuna 都具备设计稿与调整记录
  - `README / rules / design / tests` 不互相打架
  - `tests/run_with_gate.sh` 通过

#### 当前执行结果（2026-03-29）
- 机制接线已完成：
  - `ultimate_points` 已接入运行态、合法性、公开快照与日志
  - 领域对拼已接入 `field_apply` 主路径，平 MP 随机结果写入日志并可回放复现
  - Gojo 锁人改为只有无量空处成功立住才成立
  - Gojo / Sukuna 领域增幅都改成 field 生命周期绑定
- 热点收口已完成：
  - `BattleCoreComposer` / `BattleCoreContainer` 改为声明式注册表驱动装配
  - `RuleModService` 拆成 facade + `rule_mod_read_service.gd` + `rule_mod_write_service.gd`
  - `field_apply_service.gd` 承接领域落地/对拼/成功后附带效果
  - `SampleBattleFactory.content_snapshot_paths()` 改成目录自动收集 + 稳定排序
- 角色资产已补齐：
  - 校正 `docs/design/gojo_satoru_design.md`
  - 新增 `docs/design/sukuna_design.md`
  - 新增 `docs/design/gojo_satoru_adjustments.md`
  - 新增 `docs/design/sukuna_adjustments.md`
- 统一闸门已完成，结果见下。

#### 当前验证结果（2026-03-29）
- `HOME=/tmp/godot-home godot --headless --path . --script tests/run_all.gd`：通过（`ALL TESTS PASSED`）。
- `bash tests/check_architecture_constraints.sh`：通过（`ARCH_GATE_PASSED`）。
- `bash tests/check_repo_consistency.sh`：通过（`REPO_CONSISTENCY_PASSED`）。
- `bash tests/run_with_gate.sh`：通过（`ALL TESTS PASSED` + `ARCH_GATE_PASSED` + `REPO_CONSISTENCY_PASSED` + `GATE PASSED`）。

### Gojo 一期阶段3：命中链 helper 拆分与测试样板抽取（已完成）
- 目标：把 `action_cast_service` 里与命中解析直接相关的职责拆到独立 helper，并把 Gojo suite 里重复的构局/命令辅助收进专用 support，给后续新角色接入留出更稳的模板。
- 范围：`src/battle_core/actions/action_cast_service.gd`、`src/battle_core/actions/action_hit_resolution_service.gd`、`src/composition/battle_core_composer.gd`、`src/composition/battle_core_container.gd`、`tests/support/gojo_test_support.gd`、`README.md`、`tests/check_architecture_constraints.sh`、`docs/records/tasks.md`、`docs/records/decisions.md`；不改对外 manager API。
- 验收标准：命中链至少拆开“基础命中值 / field 覆盖 / incoming_accuracy / roll”四段职责，`action_cast_service` 回到阈值内；`gojo_suite` 的共用构局与命令辅助不再内嵌成大段重复代码；完整闸门全绿。

#### 当前验证结果（2026-03-29）
- `godot --headless --path . --script tests/run_all.gd`：通过。
- `tests/run_with_gate.sh`：通过（`ALL TESTS PASSED` + `ARCH_GATE_PASSED` + `REPO_CONSISTENCY_PASSED` + `GATE PASSED`）。

### Gojo 一期阶段2：专项回归与统一闸门接线（已完成）
- 目标：把 `docs/design/gojo_satoru_design.md` 第 6 节里与 Gojo 正式玩法直接相关的关键行为落成 `gojo_suite`，并接入 `tests/run_all.gd` 与统一仓库闸门。
- 范围：`tests/suites/gojo_suite.gd`、`tests/run_all.gd`、`tests/check_repo_consistency.sh`、`docs/design/gojo_satoru_design.md`、`docs/records/tasks.md`、`docs/records/decisions.md`；不改对外 manager API 与内容 schema。
- 验收标准：Gojo 的默认配招/换装、苍/赫/茈、无下限、无量空处、反转术式、标记换人与 refresh、`+5` 竞争等关键行为均有自动化回归；统一测试入口真实执行 `gojo_suite`。

#### 当前验证结果（2026-03-29）
- `godot --headless --path . --script tests/run_all.gd`：通过，`gojo_suite` 已接入并覆盖 Gojo 核心玩法回归。

### Gojo 一期阶段1：资源落地与样例接线（已完成）
- 目标：按 `docs/design/gojo_satoru_design.md` 冻结口径落地 Gojo 全套内容资源，并接入统一内容快照与样例对局构造入口。
- 范围：`content/units/gojo_satoru.tres`、`content/skills/gojo_*.tres`、`content/effects/gojo_*.tres`、`content/fields/gojo_unlimited_void_field.tres`、`content/passive_skills/gojo_mugen.tres`、`src/composition/sample_battle_factory.gd`。
- 验收标准：Gojo 资源可加载；`SampleBattleFactory` 可直接构造 `Gojo vs Sukuna` 与 `Gojo vs 样例单位`；不新增对外 manager API。

#### 当前验证结果（2026-03-29）
- `godot --headless --path . --script tests/run_all.gd`：通过（`ALL TESTS PASSED`）。

### Gojo 审查发现的运行时缺口补齐（已完成）
- 目标：把上一轮 Gojo 审查里确认属实、且已经会直接影响后续角色内容实现的两处运行时缺口补齐：同队重复角色禁用真正落到建局校验；`remove_effect` 的歧义处理真正落到运行时。
- 范围：`src/battle_core/content/battle_setup_validator.gd`、`src/battle_core/effects/effect_instance_service.gd`、`tests/suites/setup_loadout_suite.gd`、`tests/suites/extension_contract_suite.gd`、`tests/check_repo_consistency.sh`、`docs/records/tasks.md`、`docs/records/decisions.md`；不创建 Gojo 资源。
- 验收标准：同一 side 若重复提交 `unit_definition_id`，建局前必须 fail-fast；`remove_effect` 若命中 0 个或多个同名实例，必须走 `invalid_effect_remove_ambiguous`；统一闸门全绿。

#### 当前验证结果（2026-03-29）
- `godot --headless --path . --script tests/run_all.gd`：通过，新增 `same_side_duplicate_unit_forbidden` 与 `remove_effect_ambiguity_contract` 均已通过。
- `tests/run_with_gate.sh`：通过（`ALL TESTS PASSED` + `ARCH_GATE_PASSED` + `REPO_CONSISTENCY_PASSED` + `GATE PASSED`）。

### 五条悟设计文档与当前实现对照审查（已完成）
- 目标：逐条审查 `docs/design/gojo_satoru_design.md` 与当前主线实现、架构文档、扩展 contract 是否一致，找出会误导后续 Gojo 落资源与测试的风险点，并判断是否已经可以进入角色内容实现阶段。
- 范围：`docs/design/gojo_satoru_design.md`、`docs/design/battle_content_schema.md`、`docs/design/effect_engine.md`、`docs/rules/*`、`src/battle_core/**/*`、`src/composition/sample_battle_factory.gd`、`tests/**/*`、`docs/records/tasks.md`；不改运行时代码与 Gojo 资源。
- 验收标准：必须明确区分“文档已冻结”与“代码已硬约束”的边界；指出所有会直接影响 Gojo 技能落地的实现风险；给出是否可进入内容实现的结论与前置条件。

#### 当前审查结论（2026-03-29）
- 可以进入 **Gojo 资源与 gojo_suite 编写阶段**，因为 `action_legality / required_target_effects / incoming_accuracy` 三块扩展已真实接线，相关 contract 测试已覆盖。
- 审查发现的两处硬缺口已经补齐：同队重复角色现在会在 `BattleSetup` 校验阶段直接 fail-fast；`remove_effect` 现在只允许精确命中单个同名实例，歧义会按 `invalid_effect_remove_ambiguous` 终止。
- 因此 Gojo 文档在“重复角色前提”和“标记清除安全前提”这两处，已经重新与当前主线实现对齐。
- 当前剩余的非阻断项只在内容接线层：Gojo 资源还未创建、未接入 `SampleBattleFactory.content_snapshot_paths()`，`gojo_suite` 也还未注册到统一闸门。

#### 当前验证结果（2026-03-29）
- `tests/run_with_gate.sh`：通过（`ALL TESTS PASSED` + `ARCH_GATE_PASSED` + `REPO_CONSISTENCY_PASSED` + `GATE PASSED`）。
- 审查后续补齐阶段已确认：`same_side_duplicate_unit_forbidden` 与 `remove_effect_ambiguity_contract` 已接入并通过，说明上述两处 contract 已进入当前运行时。

### 同队重复角色口径收紧为禁止（已完成）
- 目标：把仓库中的正式文档口径统一改成“同一 side 禁止重复 `unit_definition_id`”，同时修正 Gojo 文档里依赖“双五条悟”假设的内容；本轮不改运行时代码。
- 范围：`docs/rules/01_battle_format_and_visibility.md`、`docs/design/battle_content_schema.md`、`docs/design/gojo_satoru_design.md`、`docs/records/decisions.md`、`docs/records/tasks.md`。
- 验收标准：正式规则层与设计层不再出现“同队允许重复角色”的当前口径；Gojo 文档不再把“双五条悟共享标记”列为正式玩法验收项；记录文件明确说明“本轮先改文档，代码校验后补”。

#### 当前验证结果（2026-03-29）
- 文档检索已确认活跃规则/设计/记录层不再把“同队允许重复角色”写成当前生效口径。

### Gojo 扩展接线与仓库级 contract 同步（已完成）
- 目标：把当前工作区里已经落地的 `action_legality / required_target_effects / incoming_accuracy` 收口为正式主线能力，同时修掉会误导后续 Gojo 实现的测试、记录与规则漂移。
- 范围：`src/battle_core/**/*`、`src/composition/*`、`tests/**/*`、`docs/design/*`、`docs/rules/*`、`docs/records/*`；不创建 Gojo 内容资源。
- 验收标准：扩展契约测试全绿；manager 首回合预回蓝合同成立；仓库级文档不再把三块扩展写成“待实现”；`tests/run_with_gate.sh` 全绿。

#### 当前验证结果（2026-03-29）
- `tests/run_with_gate.sh`：通过（`ALL TESTS PASSED` + `ARCH_GATE_PASSED` + `REPO_CONSISTENCY_PASSED` + `GATE PASSED`）。

### 五条悟设计文档实施边界与扩展 contract 修订（已完成）
- 目标：把 Gojo 设计文档里仍会误导后续实现的点彻底写死，特别是“先扩引擎还是先建资源”“`required_target_effects` / `incoming_accuracy` / `action_legality` 的细部 contract”“无量空处 `on_cast` 自 buff 语义”等边界。
- 范围：`docs/design/gojo_satoru_design.md`、`docs/records/decisions.md`、`docs/records/tasks.md`；不改运行时代码。
- 验收标准：Gojo 文档必须明确两阶段施工顺序、`required_target_effects` 的合法作用域与跳过日志口径、`incoming_accuracy` 的多实例求值顺序、`action_legality` 同 key 覆盖不复活语义，以及无量空处 miss 仍拿 `sp_attack +1` 的固定时序；相关决策已落盘；`tests/run_with_gate.sh` 全绿。

#### 当前验证结果（2026-03-29）
- `tests/run_with_gate.sh`：通过（`ALL TESTS PASSED` + `ARCH_GATE_PASSED` + `REPO_CONSISTENCY_PASSED` + `GATE PASSED`）。

## 2026-03-28

### 五条悟设计审计收口到当前主线语义（已完成）
- 目标：把五条悟设计文档和记录里的剩余歧义一次收口，确保后续实现时不会再被“标记归属”“领域首回合锁行动”“扩展数量”这些口径误导。
- 范围：`docs/design/gojo_satoru_design.md`、`docs/records/decisions.md`、`docs/records/tasks.md`；不改运行时代码。
- 验收标准：五条悟文档必须明确双标记 owner 与换人清理语义、当前方案的团队共享取舍、领域锁行动的时序前提，以及“若要限制为同一施法者消耗标记需新增第 4 个扩展”；相关记录不得再保留 `gojo_domain_expire_seal / gojo_domain_rollback` 等过时冻结口径；`tests/run_with_gate.sh` 全绿。
- 说明：下方较早的 Gojo 任务条目仅保留历史过程；凡与本条、`docs/records/decisions.md` 第 223 条或当前 `gojo_satoru_design.md` 冲突，以本轮收口后的口径为准。

#### 当前验证结果（2026-03-28）
- `bash tests/check_repo_consistency.sh`：通过（`REPO_CONSISTENCY_PASSED`）。
- `tests/run_with_gate.sh`：通过（`ALL TESTS PASSED` + `ARCH_GATE_PASSED` + `REPO_CONSISTENCY_PASSED` + `GATE PASSED`）。

### Gojo 扩展口径回滚到当前代码事实（已完成）
- 目标：把仓库级规则文档里提前写成“已实现”的 Gojo 扩展能力回滚掉，恢复为当前 main 真实支持范围，同时保留 Gojo 角色文档里的待实现设计。
- 范围：`docs/design/battle_content_schema.md`、`docs/rules/06_effect_schema_and_extension.md`、`docs/design/effect_engine.md`、`docs/design/battle_runtime_model.md`、`docs/design/gojo_satoru_design.md`、`docs/records/*`；不改运行时代码。
- 验收标准：仓库级正式文档不再把 `required_target_effects / action_legality / incoming_accuracy` 写成当前已接线能力；Gojo 文档明确这些是待实现扩展；`tests/run_with_gate.sh` 全绿。

#### 当前验证结果（2026-03-28）
- `bash tests/check_repo_consistency.sh`：通过（`REPO_CONSISTENCY_PASSED`）。
- `tests/run_with_gate.sh`：通过（`ALL TESTS PASSED` + `ARCH_GATE_PASSED` + `REPO_CONSISTENCY_PASSED` + `GATE PASSED`）。

### 启动对位补触发与动态公式边界收口（已完成）
- 目标：修掉 `battle_init` 后补位漏跑 `on_matchup_changed` 的初始化时序缺口，并把 `dynamic_value_formula` 的可用边界从运行时假设改为内容校验期硬约束。
- 范围：`src/battle_core/content/battle_content_index.gd`、`src/battle_core/turn/battle_initializer.gd`、`tests/suites/content_logging_suite.gd`、`tests/suites/replay_turn_suite.gd`、`README.md`、`docs/rules/*`、`docs/design/*`、`docs/records/*`。
- 验收标准：`scope = field` 的动态公式数值 rule_mod 必须在内容校验期 fail-fast；`battle_init` 若导致补位，稳定对位会在进入 `selection` 前补跑一次 `on_matchup_changed`；`tests/run_with_gate.sh` 全绿。

#### 当前验证结果（2026-03-28）
- `tests/run_with_gate.sh`：通过（`ALL TESTS PASSED` + `ARCH_GATE_PASSED` + `REPO_CONSISTENCY_PASSED` + `GATE PASSED`）。

### 战斗核心强治理收口计划
- 目标：分 3 个可独立验收的小阶段，一次性收口日志契约漂移、文档事实漂移、候选技能池/赛前配招 contract 缺口，以及仓库一致性闸门缺失问题。
- 范围：`src/battle_core/**/*`、`src/composition/sample_battle_factory.gd`、`content/units/sukuna.tres`、`README.md`、`content/README.md`、`docs/design/*`、`docs/rules/*`、`docs/records/*`、`tests/**/*`、`tests/*.sh`；按阶段拆分提交并保持工作区干净。
- 验收标准：阶段一修回 `cause_event_id` 真实因果语义并完成文档收口；阶段二落地候选技能池与赛前常规三技能覆盖 contract；阶段三补齐仓库一致性闸门、记录新基线，并保证每阶段完成后都能提交推送。

#### 执行与提交

|任务|结果|提交|
|---|---|---|
|阶段一：日志契约与文档事实收口|已完成|独立提交完成（`fix: realign log cause contracts`）|
|阶段二：候选技能池与赛前配招 contract 落地|已完成|独立提交完成（`add: prebattle regular skill loadouts`）|
|阶段三：一致性闸门与总收口|已完成|阶段三独立提交（本次提交）|

#### 阶段一最小可玩性检查清单
- 可启动：`godot --headless --path . --script tests/run_all.gd` 通过。
- 可操作：直接伤害、effect payload、turn_start/turn_end 到期链、离场清理都能产出真实上游 `cause_event_id`。
- 无致命错误：日志 V3 校验已拒绝 “`cause_event_id` 指向自己” 的伪因果链。

#### 阶段一回归检查要点
- `effect:*` 日志必须带 `trigger_name / cause_event_id`，且 `cause_event_id != 当前事件 ID`。
- 行动直接伤害/反伤指向 `action:hit`；turn_start 回复、effect/rule_mod 到期、field 自然到期分别指向对应系统锚点；离场清理指向 `state:exit`。
- `README.md`、`docs/design/log_and_replay_contract.md`、`docs/design/battle_content_schema.md`、`docs/rules/01_battle_format_and_visibility.md`、`docs/rules/05_items_field_ai_and_logging.md` 与当前实现一致。
- README 代码规模与命令 `find src tests -name '*.gd' | xargs wc -l` 当前输出一致。

#### 阶段一当前验证结果（2026-03-28）
- `godot --headless --path . --script tests/run_all.gd`：通过（`ALL TESTS PASSED`）。
- `tests/run_with_gate.sh`：通过（`ALL TESTS PASSED` + `ARCH_GATE_PASSED` + `GATE PASSED`）。

#### 阶段二最小可玩性检查清单
- 可启动：`tests/run_with_gate.sh` 通过。
- 可操作：赛前可按 `SideSetup.regular_skill_loadout_overrides` 覆盖本场常规三技能；合法动作、公开快照与运行时都只读取本场已装备技能。
- 无致命错误：候选技能池与赛前覆盖 contract 非法输入会在加载期/建局期 fail-fast；宿傩默认装配与换入 `反转术式` 两条路径都可回归。

#### 阶段二回归检查要点
- `UnitDefinition.candidate_skill_ids` 非空时必须至少 3 个、不能重复、必须包含默认 `skill_ids`、不能混入 `ultimate_skill_id`。
- `SideSetup.regular_skill_loadout_overrides` 必须按槽位下标建模，覆盖列表必须正好 3 个且不重复；无候选池时只能等于默认装配，有候选池时必须是候选池子集。
- `BattleInitializer` 必须把默认装配或 override 写入 `UnitState.regular_skill_ids`；`LegalActionService`、`CommandValidator`、public snapshot 都只读取这份运行时镜像。
- 宿傩默认装配保持 `解 / 捌 / 开`；通过 setup override 换入 `反转术式` 后，治疗链可正常执行；未换入时默认装配不变。
- `README.md`、`content/README.md`、`docs/design/battle_content_schema.md`、`docs/design/battle_runtime_model.md`、`docs/design/command_and_legality.md`、`docs/rules/01_battle_format_and_visibility.md`、`docs/rules/05_items_field_ai_and_logging.md` 与实现一致。

#### 阶段二当前验证结果（2026-03-28）
- `godot --headless --path . --script tests/run_all.gd`：通过（内含 `setup_loadout_suite` 与宿傩专项回归）。
- `tests/run_with_gate.sh`：通过（`ALL TESTS PASSED` + `ARCH_GATE_PASSED` + `GATE PASSED`）。

#### 阶段三最小可玩性检查清单
- 可启动：`tests/run_with_gate.sh` 通过，且新增 `tests/check_repo_consistency.sh` 已挂入统一闸门。
- 可操作：README 代码规模、关键日志契约回归、候选技能池/赛前配招专门回归、文档 contract 名称都能自动校验。
- 无致命错误：仓库一致性检查和架构约束检查职责分离，任何一层失败都会阻断提交。

#### 阶段三回归检查要点
- `tests/check_repo_consistency.sh` 必须校验 README 代码规模与实测一致。
- `tests/check_repo_consistency.sh` 必须校验关键 `cause_event_id` 回归锚点仍在 `content_logging_suite.gd` 中。
- `tests/check_repo_consistency.sh` 必须校验 `setup_loadout_suite.gd` 已注册并覆盖候选技能池、setup override、运行时装配 contract。
- `tests/check_repo_consistency.sh` 必须校验 `candidate_skill_ids / regular_skill_loadout_overrides / regular_skill_ids` 已按正式名称落盘到 README / docs / rules，不再容忍旧漂移口径。
- `tests/check_architecture_constraints.sh` 继续只负责分层和文件体量，不混入文档一致性职责。

#### 阶段三当前验证结果（2026-03-28）
- `bash tests/check_repo_consistency.sh`：通过（`REPO_CONSISTENCY_PASSED`）。
- `tests/run_with_gate.sh`：通过（`ALL TESTS PASSED` + `ARCH_GATE_PASSED` + `REPO_CONSISTENCY_PASSED` + `GATE PASSED`）。

## 2026-03-27

### 复查问题收口（二次文档同步 + 闸门补强）
- 目标：把复查中确认属实的剩余漂移一次性收口，重点修正 `03/06` 规则字段口径、README 实况、action 设计细节与架构闸门覆盖面。
- 范围：`README.md`、`docs/rules/03_stats_resources_and_damage.md`、`docs/rules/06_effect_schema_and_extension.md`、`docs/design/action_execution.md`、`docs/design/architecture_overview.md`、`docs/design/battle_core_architecture_constraints.md`、`docs/records/tasks.md`、`docs/records/decisions.md`、`tests/check_architecture_constraints.sh`；不改运行时代码。
- 验收标准：规则文档不再混用旧 schema 字段名；README 目录/分层/代码规模与仓库事实一致；`TargetSnapshot` 文档含 `bench_unit`；架构闸门新增对 `adapters/scenes` 直连内部服务的阻断；`tests/run_with_gate.sh` 全绿。

#### 执行与提交

|任务|结果|提交|
|---|---|---|
|收口 `03/06` 规则中的旧 schema 术语与 `final_mod` 公式漂移|已完成|待提交|
|修正 README 目录、分层与代码规模统计|已完成|待提交|
|补齐 action 设计文档中的 `bench_unit` 目标快照口径|已完成|待提交|
|补强架构闸门并同步约束文档|已完成|待提交|
|任务/决策记录同步|已完成|待提交|
|闸门回归（`tests/run_with_gate.sh`）|已完成|待提交|

#### 最小可玩性检查清单（本轮）
- 可启动：`tests/run_with_gate.sh` 可执行完成。
- 可操作：规则阅读、适配层接入与后续扩展都能直接映射到当前代码。
- 无致命错误：本轮只改文档、记录与闸门，不引入运行时代码回归。

#### 回归检查要点（本轮）
- `EffectDefinition / SkillDefinition / PassiveItemDefinition` 字段名必须与当前 `Resource` 类一致。
- `final_mod` 汇总公式必须体现 `rule_mod` 白名单读取点。
- README 代码规模与命令 `find src tests -name '*.gd' | xargs wc -l` 当前输出一致。
- `tests/check_architecture_constraints.sh` 必须能拦住 `adapters/scenes` 直连 `battle_core` 内部服务实现。

#### 当前验证结果（2026-03-27）
- `tests/run_with_gate.sh`：通过（`ALL TESTS PASSED` + `ARCH_GATE_PASSED` + `GATE PASSED`）。

### 审查问题分批收口（设计文档同步 + 术语统一 + 公式伤害契约）
- 目标：按复核后的真实问题分三批收口设计文档、规则术语与 `DamagePayload` 公式伤害契约，保证 README / rules / design / code / tests 五层口径一致。
- 范围：`README.md`、`docs/design/*`、`docs/rules/*`、`docs/records/*`、`src/battle_core/**/*`、`tests/suites/*`；按批次逐步提交。
- 验收标准：design 文档对齐当前 manager facade 与 `combat_type` 运行态；换人/补位目标 ID 术语无歧义；`DamagePayload` 公式伤害具备明确 `damage_kind` 契约与回归覆盖；`tests/run_with_gate.sh` 全绿。

#### 执行与提交

|任务|结果|提交|
|---|---|---|
|第一批：同步 facade、目录与 runtime 文档事实|已完成|待提交|
|第二批：统一换人/补位目标 ID 术语|已完成|待提交|
|第三批：补 `DamagePayload` 公式伤害契约、实现与测试|已完成|待提交|

#### 最小可玩性检查清单（本计划）
- 可启动：每批提交前都能独立完成本批相关验证。
- 可操作：外围接入、规则阅读与属性系统扩展都能直接映射到当前代码。
- 无致命错误：最终以 `tests/run_with_gate.sh` 全绿为准。

#### 回归检查要点（本计划）
- design 文档的 facade 入口必须与 `BattleCoreManager` 当前公开 API 一致。
- `combat_type` 必须同时出现在内容目录说明与运行态模型说明中。
- 外部输入、手动换人和系统补位的目标 ID 术语不能混用模板 ID 与实例 ID。
- `DamagePayload.use_formula` 的 `damage_kind`、阶段修正与属性继承规则必须有文档和测试双重约束。

#### 当前验证结果（2026-03-27）
- `tests/run_with_gate.sh`：通过（`ALL TESTS PASSED` + `ARCH_GATE_PASSED` + `GATE PASSED`）。

### 审查报告复核与文档收口（`combat_type` + 代码规模）
- 目标：复核本轮外部审查报告，只修复仓库中已确认属实的文档偏差，并把复核结果写入记录。
- 范围：`README.md`、`docs/rules/00_rule_baseline.md`、`docs/rules/player_quick_start.md`、`docs/design/combat_math.md`、`docs/records/tasks.md`、`docs/records/decisions.md`；不改运行时代码。
- 验收标准：总则/玩家速览不再误报“属性系统未接入”；`combat_math.md` 补齐 `CombatTypeService`；README 代码规模改为当前实测值；`tests/run_with_gate.sh` 通过。

#### 执行与提交

|任务|结果|提交|
|---|---|---|
|复核审查报告中的实现、测试与文档结论|已完成|待提交|
|修正 `combat_type` 已接入后的总则与玩家速览口径|已完成|待提交|
|补齐 `combat_math.md` 服务清单并更新 README 代码规模|已完成|待提交|
|任务/决策记录同步|已完成|待提交|
|闸门回归（`tests/run_with_gate.sh`）|已完成|待提交|

#### 最小可玩性检查清单（本轮）
- 可启动：`tests/run_with_gate.sh` 可执行完成。
- 可操作：文档对外口径能直接映射到当前 `combat_type` 实现与测试。
- 无致命错误：本轮只改文档与记录，不引入运行时代码回归。

#### 回归检查要点（本轮）
- `00_rule_baseline` 与 `player_quick_start` 明确“有属性克制、无 STAB / 免疫”。
- `combat_math.md` 文件清单与 math 层实际服务一致。
- README 代码规模与命令 `find src tests -name '*.gd' | xargs wc -l` 当前输出一致。

#### 当前验证结果（2026-03-27）
- `tests/run_with_gate.sh`：通过（`ALL TESTS PASSED` + `ARCH_GATE_PASSED` + `GATE PASSED`）。

### 17 属性系统 v1（`combat_type`）落地
- 目标：一次性落地 `combat_type` 战斗属性系统，包括 schema、内容校验、伤害接入、sample content、日志字段、文档与回归测试。
- 范围：`content/combat_types/*`、`content/samples/sample_battle_format.tres`、`content/skills/*`、`content/units/*`、`src/battle_core/**/*`、`src/composition/*`、`tests/suites/*`、`tests/run_all.gd`、`README.md`、`docs/rules/*`、`docs/design/battle_content_schema.md`、`docs/records/*`。
- 验收标准：`combat_type` 资源与显式克制表可加载；直接伤害和公式伤害接入 `type_effectiveness`；公共快照与日志契约补齐；`tests/run_with_gate.sh` 全绿。

#### 执行与提交

|任务|结果|提交|
|---|---|---|
|新增 `CombatTypeDefinition / CombatTypeChartEntry / CombatTypeService`|已完成|待提交|
|BattleFormat / Unit / Skill / UnitState / LogEvent / public snapshot 扩展|已完成|待提交|
|内容校验追加 `combat_type` 约束|已完成|待提交|
|直接伤害、公式伤害、默认动作/反伤日志接入 `type_effectiveness`|已完成|待提交|
|新增 17 个 `combat_type` 资源、3 个 typed sample skill、sample unit 属性与显式 chart|已完成|待提交|
|新增 `combat_type_suite` 并修正受 sample 槽位调整影响的旧测试|已完成|待提交|
|README / rules / schema / records 同步|已完成|待提交|
|闸门回归（`tests/run_with_gate.sh`）|已完成|待提交|

#### 最小可玩性检查清单（本轮）
- 可启动：`tests/run_with_gate.sh` 可执行完成。
- 可操作：typed 技能、公式伤害继承属性、默认动作与反伤中立路径都可通过自动化用例验证。
- 无致命错误：闸门输出无引擎级错误，架构约束检查通过。

#### 回归检查要点（本轮）
- `combat_type` 与 `damage_kind` 语义独立，`UnitState.combat_type_ids` 仅为运行态镜像。
- `combat_type_chart` 采用强类型资源条目，缺失 pair 默认 `1.0`，不做反向推导。
- 伤害日志 `type_effectiveness` 在直接伤害、effect damage、默认动作、反伤路径上都符合口径。
- 公共快照与 `prebattle_public_teams` 已公开 `combat_type_ids`，且不泄露私有实例 ID。

#### 当前验证结果（2026-03-27）
- `tests/run_with_gate.sh`：通过（`ALL TESTS PASSED` + `ARCH_GATE_PASSED` + `GATE PASSED`）。

### 问题全量修复（规则收口 + payload 拆分 + 测试治理）
- 目标：一次性修复术语缺口、`on_cast` 自伤语义边界、`PayloadExecutor` 超阈值和生命周期测试膨胀问题，并清理过期审查产物。
- 范围：`docs/rules/*`、`docs/design/action_execution.md`、`docs/records/tasks.md`、`docs/records/decisions.md`、`src/battle_core/effects/*`、`src/composition/*`、`tests/suites/*`、`tests/run_all.gd`、`tests/check_architecture_constraints.sh`、`_review/full_review_report.md`。
- 验收标准：文档语义无空白；`payload_executor.gd` 降到阈值内并移除对应 allowlist；生命周期 suite 拆分完成且新增 `on_cast` 自伤回归；`tests/run_with_gate.sh` 全绿。

#### 执行与提交

|任务|结果|提交|
|---|---|---|
|术语与 `on_cast` 自伤语义文档收口|已完成|待提交|
|`PayloadExecutor` 子处理器拆分 + 组合根接线|已完成|待提交|
|生命周期测试拆分 + 新增回归用例|已完成|待提交|
|删除 `_review/full_review_report.md`|已完成|待提交|
|闸门回归（`tests/run_with_gate.sh`）|已完成|待提交|

#### 最小可玩性检查清单（本轮）
- 可启动：`tests/run_with_gate.sh` 可执行完成。
- 可操作：默认动作反伤、`on_cast` 链与击倒窗口语义可通过自动化用例验证。
- 无致命错误：闸门输出无引擎级错误，架构约束检查通过。

#### 回归检查要点（本轮）
- `unit_id` 与 `unit_instance_id` 术语边界在规则总则中明确。
- `on_cast` 自伤致死后，行动链继续到本次行动结束，再进入击倒窗口。
- payload 各类型日志字段语义保持（`trigger_name / cause_event_id / payload_summary`）。
- `forced_replace` 成功/非法路径与既有行为一致。

#### 当前验证结果（2026-03-27）
- `tests/run_with_gate.sh`：通过（`ALL TESTS PASSED` + `ARCH_GATE_PASSED` + `GATE PASSED`）。

## 2026-03-26

### 审查报告复核与文档纠偏（action 字段 + README 目录示例）
- 目标：核对外部审查报告真实性，只修复当前仓库中属实偏差并保持工作区可提交。
- 范围：`docs/design/action_execution.md`、`README.md`、`docs/records/tasks.md`；不改运行时代码与规则语义。
- 验收标准：`QueuedAction` 与 `ActionResult` 字段说明和代码一致；README 目录示例不再省略 `content/` 关键子目录；本轮提交后工作区恢复干净。

#### 执行与提交

|任务|结果|提交|
|---|---|---|
|复核报告中的代码规模、目录与字段差异|已完成|待提交|
|修正文档滞后（`speed_tie_roll`、`invalid_battle_code`）|已完成|待提交|
|补全 README `content/` 子目录示例|已完成|待提交|
|闸门回归（`tests/run_with_gate.sh`）|已完成|待提交|

### 文档二次对齐优化（runtime/effect/模块清单/阈值说明）
- 目标：按最新复查结论补齐剩余文档偏差，确保进入角色设计前“规则-设计-实现-记录”四层口径一致。
- 范围：`docs/design/battle_runtime_model.md`、`docs/design/effect_engine.md`、`docs/design/lifecycle_and_replacement.md`、`docs/design/turn_orchestrator.md`、`docs/design/action_execution.md`、`docs/records/decisions.md`；不改运行时代码。
- 验收标准：EffectInstance/RuleModInstance/EffectEvent 字段对齐代码；lifecycle/turn/actions 文件清单对齐实际目录；超阈值暂不拆分理由在 decisions 里补充到可复核粒度。

#### 执行与提交

|任务|结果|提交|
|---|---|---|
|核实字段偏差与目录清单差异|已完成|待提交|
|更新 5 份设计文档（runtime/effect/lifecycle/turn/actions）|已完成|待提交|
|补充超阈值文件复核说明（decisions）|已完成|待提交|
|闸门回归（`tests/run_with_gate.sh`）|已完成|待提交|

#### 最小可玩性检查清单（本轮）
- 可启动：`tests/run_with_gate.sh` 可执行完成。
- 可操作：设计文档字段与模块文件清单可直接映射到当前代码。
- 无致命错误：闸门输出无引擎级错误。

#### 回归检查要点（本轮）
- `EffectInstance` 含 `persists_on_switch`，`RuleModInstance` 含 `scope/duration_mode/owner_scope/owner_id/stacking_key`。
- `EffectEvent` 文档含 `priority/sort_random_roll`。
- `lifecycle/turn/actions` 文件清单与 `src/battle_core/*` 实际文件一一对应。

### Battle Core 文档偏差同步（runtime/command/manager API）
- 目标：核实“全面复查报告”中的文档偏差并完成一次性同步，避免角色设计阶段误读。
- 范围：`docs/design/battle_runtime_model.md`、`docs/design/command_and_legality.md`、`README.md`；不改运行时代码与测试逻辑。
- 验收标准：BattleState/UnitState/Command/BattlePhases 与代码字段一致；README §6 补齐 3 个 manager 辅助方法说明；工作区提交后恢复干净。

#### 执行与提交

|任务|结果|提交|
|---|---|---|
|核对代码与文档差异（runtime/command/phases/manager API）|已完成|待提交|
|同步更新 3 份文档|已完成|待提交|
|闸门回归（`tests/run_with_gate.sh`）|已完成|待提交|

#### 最小可玩性检查清单（本轮）
- 可启动：`tests/run_with_gate.sh` 可执行完成。
- 可操作：核心战斗流程相关文档可直接映射到现有代码字段。
- 无致命错误：闸门输出无引擎级错误。

#### 回归检查要点（本轮）
- `BattlePhases` 文档值与 `src/shared/battle_phases.gd` 完全一致。
- `BattleState` 缺失字段（8 项）与 `UnitState` 缺失字段（11 项）已补齐。
- `Command` 缺失字段（4 项）已补齐；README §6 补齐 `active_session_count / dispose / resolve_missing_dependency`。

### Battle Core 会话隔离 + 日志 V3 收口（manager/session）
- 目标：完成会话级隔离重构，修复回放快照上下文一致性，升级日志到 V3 并补齐初始化结构化日志头。
- 范围：`battle_core/facades`、`composition`、`turn/logging/contracts`、sandbox 与测试套件、规则/设计/记录文档；不扩展 UI 与角色内容。
- 验收标准：manager API 全量可用；`run_replay` 隔离执行且快照完整；`system:battle_header` 契约与私有 ID 约束生效；`tests/run_with_gate.sh` 全绿。

#### 执行与提交

|任务|结果|提交|
|---|---|---|
|新增 `BattleCoreManager + BattleCoreSession`，每局独立 compose 容器|已完成|待提交|
|删除旧 facade 调用链（sandbox/tests 全迁移）|已完成|待提交|
|`run_replay` 临时容器隔离 + 快照上下文修复|已完成|待提交|
|日志升级 V3，新增 `system:battle_header` 与 `header_snapshot`|已完成|待提交|
|新增回归测试（会话隔离/回放隔离/日志头与 V3）|已完成|待提交|
|规则、设计、记录文档同步|已完成|待提交|

#### 最小可玩性检查清单（本轮）
- 可启动：headless 全量测试可完整执行。
- 可操作：manager 可完成建局、查合法动作、构建指令、推进回合、查快照、关局、隔离回放。
- 无致命错误：并行会话互不串扰，回放不污染活跃会话池，日志头不泄露私有实例 ID。

#### 回归检查要点（本轮）
- `create_session/get_public_snapshot/run_replay` 均返回完整 `prebattle_public_teams`。
- `run_replay` 执行前后不会改变活跃 session 数量与既有会话快照。
- 日志全量 `log_schema_version = 3`，且存在且仅存在一条 `system:battle_header`。
- `system:battle_header` 在首条 `state:enter` 之前，`header_snapshot` 字段齐全且递归不含 `unit_instance_id`。

#### 当前验证结果（2026-03-26）
- `godot --headless --path . --script tests/run_all.gd`：通过（41 个断言全绿）。
- `tests/run_with_gate.sh`：通过（`ALL TESTS PASSED` + `ARCH_GATE_PASSED` + `GATE PASSED`）。

### 复查问题修复落地（full-open 快照 + effect_roll + 架构瘦身）
- 目标：修复复查阶段发现的“规则/文档/实现偏差”，把核心契约收敛到可扩展且可回归验证的单一口径。
- 范围：`battle_core facade/effects/lifecycle/composition`、测试套件、规则/设计/记录文档；不扩到 UI 展示层与正式角色内容设计。
- 验收标准：full-open 快照契约补齐且不泄露私有实例 ID；effect 日志补齐 `effect_roll`；ReplacementService 依赖瘦身；文档口径一致；`tests/run_with_gate.sh` 全绿。

#### 执行与提交

|任务|结果|提交|
|---|---|---|
|full-open 快照契约补齐（含 `prebattle_public_teams`）|已完成|待提交|
|effect 日志补齐 `effect_roll`|已完成|待提交|
|ReplacementService 依赖注入瘦身|已完成|待提交|
|新增回归测试（快照契约 + effect_roll 语义）|已完成|待提交|
|规则/设计文档与记录收口|已完成|待提交|

#### 最小可玩性检查清单（本轮）
- 可启动：headless 测试可完整执行。
- 可操作：facade 可返回 full-open 公共快照；effect 队列排序随机语义可被日志验证。
- 无致命错误：架构闸门通过，无分层越界与超阈值文件违规。

#### 回归检查要点（本轮）
- 快照包含 `visibility_mode / field / sides.team_units / prebattle_public_teams`，并保留旧字段兼容。
- 公共快照不出现 `unit_instance_id`。
- tie-group effect 事件日志 `effect_roll != null`，单事件 `effect_roll == null`。
- `tests/run_with_gate.sh` 输出 `GATE PASSED`。

#### 当前验证结果（2026-03-26）
- `HOME=/tmp XDG_DATA_HOME=/tmp tests/run_with_gate.sh`：通过（`ALL TESTS PASSED` + `ARCH_GATE_PASSED` + `GATE PASSED`）。

## 2026-03-25

### Battle Core 完美架构约束方案 v1（分层/门面/拆分）
- 目标：把 battle core 收敛为“高内聚、低耦合、强边界、早拆分”的长期骨架，外围不再直连 runtime。
- 范围：仅 `battle_core`、`adapters`、`composition`、测试与规则/设计/记录文档；不扩到正式 UI、scene 交互与复杂 AI。
- 验收标准：三阶段改造全部落地，`tests/run_with_gate.sh` 全绿，且新增架构闸门能拦截外围直连 runtime。

#### 阶段执行与提交

|阶段|结果|提交|
|---|---|---|
|阶段 1：硬约束文档与规则落盘（6 层依赖、rule_mod 白名单、阈值治理）|已完成|待提交|
|阶段 2：新增 facade 并切断外围直连 runtime|已完成|待提交|
|阶段 3：拆 `TurnLoopController`、`ActionExecutor` 与测试总入口|已完成|待提交|

#### 最小可玩性检查清单（本计划）
- 可启动：sandbox 与回放可正常执行。
- 可操作：facade 可完成初始化、合法性查询、构建指令、回合推进与回放。
- 无致命错误：外围不再直接依赖 runtime，非法依赖可被闸门拦截。

#### 回归检查要点（本计划）
- `battle_end / turn_limit / invalid_battle` 语义不回归。
- `on_cast / on_hit / on_miss / switch / default action` 日志语义不回归。
- `rule_mod` 仍只影响白名单读取点，不能改流程。
- 测试入口拆分后总闸门仍支持一键执行全部断言。

#### 当前验证结果（2026-03-25）
- `tests/run_with_gate.sh`：通过（含 `tests/check_architecture_constraints.sh`）。
- `tests/run_all.gd`：通过，34 个核心断言全部 PASS。

### Battle Core 收口与反兜底改造计划（文档先行，4 批次）
- 目标：按“先文档后代码”收口 Battle Core 契约，消除文档-实现漂移，补齐 `forced_replace`，移除关键兜底并强化依赖 fail-fast。
- 范围：仅战斗核心（content/lifecycle/effects/logging/composition）与测试闸门；不扩到多槽/多目标，不引入兼容旧行为的运行时回退。
- 验收标准：4 批次分别可验收并独立提交；`tests/run_with_gate.sh` 全绿且引擎错误日志为 0。

#### 批次执行与提交

|批次|结果|提交|
|---|---|---|
|批次 1：文档与契约收口（`on_receive` 禁用、`forced_replace` 落地计划、runtime 字段纠偏）|已完成|`1d31974`|
|批次 2：内容层 fail-fast 收紧（`on_receive_effect_ids` 非空即加载失败）|已完成|`4a7b49d`|
|批次 3：`forced_replace` 最小闭环（payload + 生命周期顺序 + 失败语义）|已完成|`59c1c8c`|
|批次 4：去兜底与依赖强约束（去 `system:orphan`、关键依赖缺失硬失败）|已完成|`d6dbe09`|

#### 最小可玩性检查清单（本计划）
- 可启动：核心回放与回合流程可完整执行。
- 可操作：手动换人、击倒补位、`forced_replace`（落地后）均可闭环。
- 无致命错误：非法内容、非法替补、缺失依赖、缺失链上下文都能立即暴露。

#### 回归检查要点（本计划）
- `manual_switch` 与 `faint replace` 既有语义保持不回归。
- 日志 V2 字段语义保持不变（仅移除 `system:orphan` 兜底）。
- deterministic 契约保持：同输入同输出哈希一致。

### 收口后续问题修复（终止链健壮性 + 触发批次去重复）
- 目标：修复“依赖缺失时终止链可能二次崩”风险，并消除生命周期触发批次在多模块重复实现导致的后续扩展隐患。
- 范围：`turn_loop_controller` 依赖失败处理、统一触发批次执行器抽象、composition 接线与依赖断言、回归测试。
- 验收标准：`tests/run_with_gate.sh` 全绿；依赖缺失仍可稳定 fail-fast；触发批次收集/排序/执行逻辑收口到单点实现。

#### 执行与提交

|任务|结果|提交|
|---|---|---|
|终止链健壮性修复 + 触发批次收口|已完成|待提交|

### 复查问题全量修复计划（核心契约优先，4 批次）
- 目标：统一规则文档、设计文档、核心实现与测试闸门，优先消除会导致分叉的核心契约冲突。
- 范围：仅核心契约与测试；不接 UI/AI 真实交互；不做双轨兼容，直接迁移新契约。
- 验收标准：非法提交/替补选择/field 归属/内容校验均按新口径 fail-fast；`tests/run_with_gate.sh` 全绿且引擎错误日志为 0。

#### 批次执行与提交

|批次|结果|提交|
|---|---|---|
|批次 1：文档口径收口（非法提交 fail-fast + 替补选择契约）|已完成|`135b962`|
|批次 2：核心契约改造（ReplacementSelector + 关键逻辑修正）|已完成|`858780f`|
|批次 3：内容校验强约束前置|已完成|`7850505`|
|批次 4：测试与闸门升级|已完成|本批次提交|

#### 最小可玩性检查清单（本计划）
- 可启动：headless 测试可完整运行到结束。
- 可操作：强制补位链在显式选择契约下可闭环。
- 无致命错误：非法输入立即终止并给出明确错误码，无静默回退。

#### 回归检查要点（本计划）
- 规则/设计/记录三层文档对非法提交与替补选择语义完全一致。
- `double_faint` 平局原因、`apply_field` 来源归属、内容校验新增约束都有回归覆盖。
- `tests/run_with_gate.sh` 是唯一闸门，必须断言全绿且引擎错误日志为 0。

### 战斗核心修复总方案（V2 契约保持，四批次落地）
- 目标：修复回放与日志契约、持续效果主链、内容校验、测试与 CI 闸门，并收口文档与记录。
- 范围：批次 1（回放与日志契约对齐）+ 批次 2（持续效果实例主链）+ 批次 3（内容校验 fail-fast）+ 批次 4（测试/CI/文档/记录）。
- 验收标准：回放完整终局；日志 V2 字段合规；持续效果生命周期完整；非法内容加载期失败；CI 闸门拦截回归。

#### 批次执行与提交

|批次|结果|提交|
|---|---|---|
|批次 1：回放与日志契约硬对齐|已完成|`2199835`（合并提交）|
|批次 2：持续效果实例接入主链|已完成|`2199835`（合并提交）|
|批次 3：内容层校验与失败前置|已完成|`2199835`（合并提交）|
|批次 4：测试、CI、文档与记录收口|已完成|`2199835`（合并提交）|

#### 最小可玩性检查清单（本轮）
- 可启动：`tests/run_with_gate.sh` 可完整运行并通过。
- 可操作：回放在无后续输入时仍能自动打到终局。
- 无致命错误：引擎日志无 `SCRIPT ERROR / Compile Error / Parse Error / Failed to load script`。

#### 回归检查要点（本轮）
- `result:battle_end` 事件 `command_type` 必须为 `system:*`，且 `ReplayOutput.succeeded` 判定收紧。
- `apply_effect` 产生的持续效果在 `turn_start / turn_end / on_enter / on_exit / on_faint / on_kill` 触发并可扣减移除。
- 内容加载期非法配置直接 fail-fast（优先级、`rule_mod` 组合、断引用）。
- CI 默认执行 `tests/run_with_gate.sh` 并阻断失败。

### Battle Core 全量修复计划（严格验收版，4 批次）
- 目标：一次性修复“编译断裂、测试假绿灯、规则链未落地、文档口径漂移”，并把代码、规则文档、记录文档收敛到同一口径。
- 范围：批次 1（编译与类型稳定）+ 批次 2（测试闸门与 deterministic）+ 批次 3（规则链与生命周期）+ 批次 4（文档收口与回归封板）。
- 验收标准：`godot --headless` 无脚本错误；测试通过同时满足“断言全绿 + 引擎错误日志为 0”；规则关键路径与 `docs/rules/00~06` 最小全集一致；记录落盘可追溯。

#### 批次执行与提交

|批次|结果|提交|
|---|---|---|
|批次 1：编译与类型系统修复|已完成|`8989750` (`fix: batch1 compile-type stabilization`)|
|批次 2：测试可信化与 deterministic 基线|已完成|`924a542` (`fix: batch2 deterministic test gate`)|
|批次 3：规则最小全集补齐|已完成|`845e7d1` (`fix: batch3 rule chain and lifecycle parity`)|
|批次 4：文档收口 + 回归矩阵 + 封板|已完成|`0df94fb` + `f9abe49` + `c3174fd`|

#### 本轮已落地内容（批次 1~3）
- 批次 1：修复 headless 脚本加载断裂、类型推断不稳定、跨脚本类型依赖问题，恢复可执行骨架。
- 批次 2：重构 `tests/run_all.gd` 失败语义，新增 `tests/run_with_gate.sh` 引擎错误闸门，固化 `ReplayRunner` 与 `IdFactory` 的 deterministic 重置。
- 批次 3：补齐 `battle_init/on_enter` 批次边界、`turn_start/turn_end` active+field 触发链、`on_faint/on_kill/on_exit/on_enter` 生命周期调度、`rule_mod` 三读取点与扣减移除日志、invalid code fail-fast 终止链路。

#### 严格验收回归矩阵（2026-03-25）

|项|结果|
|---|---|
|编译健康（headless 脚本加载）|通过：`godot --headless --path . --script tests/run_all.gd`，0 个 `SCRIPT ERROR`|
|回放确定性（同输入哈希一致）|通过：`PASS deterministic_replay`|
|默认动作链（历史回归名：`timeout_default` / `resource_forced_default`，现已被 `wait / resource_forced_default` 覆盖）|通过：`PASS timeout_default_path` + `PASS resource_forced_default_path`|
|初始化时序（`on_enter` -> 击倒窗口 -> `battle_init`）|通过：`PASS init_chain_order`|
|回合节点范围（仅 active + field）|通过：`PASS turn_scope_active_and_field`|
|生命周期（倒下窗口、补位、`on_faint/on_kill/on_exit/on_enter`）|通过：`PASS lifecycle_faint_replace_chain`|
|field（替换、扣减、到期移除）|通过：`PASS field_expire_path`|
|rule_mod（三读取点、扣减、过期移除）|通过：`PASS rule_mod_paths` + `PASS rule_mod_skill_legality_enforced`|
|非法终止（`invalid_battle_code` 即停）|通过：`PASS invalid_battle_rule_mod_definition`|
|日志契约（`null` 语义、`event_type`、`command_type/source`）|通过：`PASS log_contract_semantics`|

#### 本轮最终命令结果
- `tests/run_with_gate.sh`：通过，输出 `GATE PASSED: assertions and engine logs are clean`。
- `godot --headless --path . --script tests/run_all.gd`：通过，输出 `ALL TESTS PASSED`。

### Battle Core 深度修复计划（后续收口：日志链路与资源释放）
- 目标：补齐 V2 日志链路的去重与归因口径，修复测试残留导致的资源泄露告警。
- 范围：effect 去重键改为 `source_instance_id + trigger + event_id`；所有 effect/system 事件写入 `cause_event_id = event_chain_id:event_step_id`；测试流程在结束后统一 dispose battle core；内容快照加载改为显式 `ResourceLoader`。
- 验收标准：`tests/run_with_gate.sh` 通过且引擎日志干净；`invalid_chain_depth_dedupe_guard` 保持稳定；日志 V2 字段不再出现链路归因缺口。

#### 批次执行与提交

|批次|结果|提交|
|---|---|---|
|后续收口：日志链路与资源释放|已完成|`a84bca4` (`fix: log v2 follow-up and cleanup`)|

#### 最小可玩性检查清单（后续收口）
- 可启动：测试脚本无解析错误，可完整跑完并退出。
- 可操作：触发链去重不再依赖 `step_counter`，同事件重复触发仍可稳定 fail-fast。
- 无致命错误：引擎不再报告 `ObjectDB` 泄露告警。

#### 回归检查要点
- `effect` 去重键是否为 `source_instance_id + trigger + event_id`。
- `cause_event_id` 是否统一为 `event_chain_id:event_step_id`。
- 测试结束是否显式释放 core，且引擎日志为 0 错误。

### 工程骨架补全 + 强类型契约落盘（已完成：v0.8.0 骨架补丁）
- 目标：把战斗核心从“提纲式文档 + 半截目录”升级为“决策完整骨架”，让后续实现者不再需要自行决定目录、contract、场景入口和内容资源格式。
- 范围：`content/` 根目录、`docs/design/` 修订、`src/battle_core/contracts/`、runtime 强类型化、各模块 service skeleton、`src/composition/`、`Boot/BattleSandbox` 场景、测试脚手架占位。
- 验收标准：目录结构、设计文档、强类型 contract、模块入口类、主场景接线与记录文档全部一致；仓库中不再存在“文档提到但没有对应类/目录”的骨架缺口。

#### 已完成内容
- 新增独立 `content/` 根目录，明确战斗定义资源与 `assets/` 分离。
- 把 `docs/design/` 从提纲式文档修订为实现级骨架方案，写死 `contracts/`、`composition/`、Scene Composition Root 与 Resource 方向。
- 新增强类型 contract：`Command / LegalActionSet / SelectionState / ChainContext / EffectEvent / QueuedAction / ActionResult / LogEvent / ReplayInput / ReplayOutput / BattleResult`。
- 把 runtime 层升级为强类型对象，`BattleState / SideState / UnitState` 不再继续使用长期裸 `Dictionary` 口径。
- 新增内容 `Resource` 类与 payload 基类，确立 `.tres` 为正式内容格式。
- 补齐 `commands / turn / actions / math / lifecycle / effects / passives / logging / adapters` 的模块入口类。
- 新增 `BattleCoreComposer` 与 `BattleCoreContainer`，确立显式装配方式。
- 新增 `Boot.tscn`、`BattleSandbox.tscn` 并将 `project.godot` 主场景指向 boot。
- 新增 `content/README.md`、样例 `sample_battle_format.tres`、`tests/README.md` 与空目录占位文件。
- 通过 Godot 4.6.1 本地运行自检：项目能正常进入 `BattleSandbox`，输出 `Battle sandbox ready: battle_1`，无解析错误。

#### 最小可玩性检查清单（骨架基线）
- 可启动：Godot 工程有明确主场景，启动后可进入 `BattleSandbox`。
- 可操作：核心服务可被 `BattleCoreComposer` 一次性装配，sandbox 可创建空 `BattleState`。
- 无致命错误：不会再出现“文档提到 contract 但仓库里没有类”“内容资源和美术资源混放”“只有目录没有入口类”的结构分叉。

#### 回归检查要点
- `project.godot` 是否已指向 `scenes/boot/Boot.tscn`。
- `docs/design/` 是否与当前目录、contract、composition root 口径一致。
- `src/battle_core/contracts/` 是否覆盖文档中提到的核心 contract。
- `content/` 是否已经独立于 `assets/`。
- 各模块空目录是否都已变成“至少有一个明确入口类”。

### 规则歧义补齐 + 日志事件枚举收口（已完成：v0.7.2 文档补丁）
- 目标：补齐剩余歧义点，避免实现分叉，并把日志事件类型与非法终止错误码写死。
- 范围：回合节点触发范围、`action_failed_post_start` 触发点、持续时间扣减起算、`rule_mod` 运行时模型、日志 `event_type` 与 `invalid_battle_code`、`invalid_battle` 错误码表。
- 验收标准：实现者只读现行文档，就能唯一确定回合节点触发范围、行动失败语义、持续时间扣减起算、`rule_mod` 应用顺序与日志事件类型。

#### 已完成内容
- 写死回合节点触发范围：仅在场单位与 field 生效，bench 不参与。
- 收口 `action_failed_post_start`：仅在执行起点判定，后续 payload 目标无效只跳过该 payload。
- 明确 `turns` 持续时间扣减起算点：创建后遇到的第一个对应节点即为首次扣减。
- 补齐 `rule_mod` payload 最小字段与 `RuleModInstance` 运行时模型与应用顺序。
- 日志新增 `event_type` 最小枚举与 `invalid_battle_code` 字段，补齐错误码表。

#### 最小可玩性检查清单（文档基线）
- 可启动：实现者能唯一实现回合节点触发范围、持续时间扣减与 `rule_mod` 应用顺序。
- 可操作：行动失败语义与日志事件类型只有一套口径，不会分叉。
- 无致命错误：不会出现 bench 触发回合节点、`action_failed_post_start` 乱用、field 回合数起算不一致等实现歧义。

#### 回归检查要点
- 模块 04/06 是否一致声明回合节点只对在场单位与 field 生效。
- 模块 02 是否将 `action_failed_post_start` 限定为执行起点判定，并补齐 payload 跳过口径。
- 模块 05/06 是否写死持续时间扣减起算点。
- 模块 06 是否补齐 `rule_mod` payload 字段与运行时应用顺序。
- 模块 05 是否新增 `event_type` 枚举与 `invalid_battle_code` 字段。

### 规则执行契约补齐 + 运行时日志收口（已完成：v0.7.2 文档补丁）
- 目标：把现行文档里还会逼实现者临场拍板的执行契约补齐，并修掉剩余术语漂移。
- 范围：首发 `on_enter / battle_init` 时序、`fainted_pending_leave` 统一命名、持续效果排序继承、行动链日志字段继承、AI 合法列表边界、`on_cast` / payload 顺序、field 扣减节点、技能对接字段收口。
- 验收标准：实现者只读现行文档，就能唯一写出初始化、行动链日志、持续效果排序和 AI 选指令接口，不需要再靠聊天补口径。

#### 已完成内容
- 把战斗开始初始化顺序拆成 `on_enter` 阶段和 `battle_init` 阶段，写死它们之间先后与击倒窗口位置，不再允许跨触发点混排。
- 统一双倒下流程里的状态名，明确当前运行态只使用 `fainted_pending_leave`。
- 为持续效果实例补上 `source_kind_order` 继承规则，避免 `apply_effect` 落地后出现“到底归哪个排序桶”的实现分叉。
- 把行动链日志字段继承规则写清：同一行动链里的衍生效果事件继续沿用根行动的 `action_id / command_type / command_source`。
- 收紧 AI 合法性契约，不再把“空合法列表”丢给 AI；无合法主动方案时由引擎直接生成 `resource_forced_default`。
- 写死技能、奥义、默认动作的执行起点顺序，并补齐 `payloads` 声明顺序、`effects_on_cast_ids / effects_on_hit_ids / effects_on_miss_ids / effects_on_kill_ids` 的精确落点。
- 写明 field 剩余回合固定在 `turn_end` 扣减，并删除主动技能对接字段里多余的 `effects_on_enter` 口子。
- 同步更新 `docs/records/decisions.md`，把本轮新增契约和裁剪原则落盘。

#### 最小可玩性检查清单（文档基线）
- 可启动：实现者能唯一实现战斗初始化、行动链日志、默认动作和持续效果排序。
- 可操作：AI 和玩家端都能围绕同一套合法指令契约工作，不会在“空列表”或自动动作上各做一套逻辑。
- 无致命错误：不会再出现 `on_enter` 和 `battle_init` 混排、双倒状态名不一致、持续效果排序无来源桶、日志字段继承靠猜的分叉。

#### 回归检查要点
- 模块 01 是否已把初始化拆成 `on_enter` 阶段和 `battle_init` 阶段，并写明两者不跨触发点混排。
- 模块 04 是否已只使用 `fainted_pending_leave` 作为运行态名。
- 模块 05 是否已写明持续效果继承根来源类型、AI 不接收空合法列表、行动链日志字段继承规则、field 在 `turn_end` 扣减。
- 模块 06 是否已补齐 `source_kind_order`、`chain_origin`、payload 顺序与技能触发字段时序。
- 模块 03 是否已写明 `on_cast` 在扣 MP 之后、命中之前，以及命中侧 payload 与 `effects_on_hit_ids` 的先后。

### 执行契约收口 + 效果模型再瘦身（已完成：v0.7.1 文档补丁）
- 目标：把上一轮审查里真正会阻断实现的规则口补齐，同时把还能再瘦的保留口继续收紧。
- 范围：行动失败分类、换人/补位选择契约、`HP = 0` 中间态、日志空值与自动来源、首发 `on_enter` / `battle_init` 分工、模块 06 的作用域与 `rule_mod` 约束。
- 验收标准：实现者只看现行文档，就能唯一确定这些关键边界；不会再因为“文档里留太宽”而临场拍板。

#### 已完成内容
- 删除当前基线里没有触发接口支撑的 `action_failed_pre_start`，避免失败分类先于触发模型落地。
- 补齐手动换人、强制换下、强制补位的替补选择规则，写死锁定时机、自动锁定条件与非法运行态处理。
- 为 `HP = 0` 增加 `fainted_pending_leave` 中间态，明确它在击倒窗口前就已失去在场资格，不再接受普通 payload。
- 把超时比较的 HP 占比公式补成唯一口径：倒下单位按 `current_hp = 0` 计入，全队 `max_hp` 总和固定作分母。
- 历史口径：当时补齐的自动来源命名包含 `timeout_default / timeout_auto`；该口径已在后续被 `wait / timeout_auto` 覆盖。
- 拆清首发 `on_enter` 与 `battle_init` 的先后与职责，避免同一份效果双触发。
- 继续收紧模块 06：移除 `scope = side` 的现行保留位，删除 `custom targeting` 的现行保留位，并限制 `rule_mod` 不能改写核心流程。
- 同步更新 `docs/records/decisions.md`，把本轮收口原则落盘。

#### 最小可玩性检查清单（文档基线）
- 可启动：实现者能唯一写出换人、补位、击倒窗口、首发初始化和默认动作日志。
- 可操作：玩家和 AI 都有明确的替补选择入口，不会在补位或强制换下时卡在“到底谁来选”。
- 无致命错误：不会再出现“动作前拦下没有触发点”“倒下单位还能不能吃后续效果”“日志里 null 到底怎么写”这类实现分叉。

#### 回归检查要点
- 模块 02 是否已不存在 `action_failed_pre_start`，且手动换人目标锁定规则已写明。
- 模块 04 是否已写明 `fainted_pending_leave`、强制换下失败口径、强制补位选择权。
- 模块 05 是否已写明 `resource_auto` 与非适用字段统一写 `null`。
- 模块 06 是否已不再保留 `scope = side` 与 `custom targeting` 这类现行宽口。
- 模块 01 的首发初始化与超时比较是否都已有唯一时序和数学口径。

## 2026-03-24

### 极简基线终检 + 玩家一页说明（已完成：v0.7.0 审查补丁）
- 目标：确认“极简基线”在现行文档中已经完整落地，并给玩家提供一眼可懂的玩法说明。
- 范围：全量审查 `docs/rules/` 与 `docs/records/`（排除历史归档），补充玩家速览文档，标注仍保留旧口径的文件边界。
- 验收标准：开发者不会把旧口径误当现行规则；玩家不读实现细节也能看懂怎么打。

#### 已完成内容
- 逐份复查现行规则文档，确认 `priority`、命中、物理/特殊伤害、被动持有物、单全局 field 的口径一致。
- 复查记录文档，确认旧机制口径仅存在于 `docs/records/archive/*` 与退役总表，且都已显式标注“不可直接实现”。
- 在规则目录新增 `docs/rules/player_quick_start.md`，整理玩家一页速览：回合流程、行动先后、命中与伤害、field 与持有物、当前未启用机制。
- 在 `docs/rules/README.md` 补充审查提醒，明确哪些文档是历史追溯用途。

#### 最小可玩性检查清单（文档基线）
- 可启动：实现者只看 `docs/rules/` 就能开始写代码，不需要回头翻历史条目。
- 可操作：玩家只看一页速览就知道每回合要做什么、为什么先后手会这样排。
- 无致命错误：不会再把 archive 或退役总表里的旧口径当成当前实现依据。

#### 回归检查要点
- `docs/rules/player_quick_start.md` 是否与 `00~06` 当前规则一致。
- `docs/rules/README.md` 是否明确标注历史文档边界。
- 现行文档里是否仍不存在旧的多层 priority 命名和已移除机制的“现行条款”。

### 极简战斗基线收口（已完成：v0.7.0 文档冻结）
- 目标：把战斗规则收成最小可玩闭环，为后续属性系统接入打稳定底板。
- 范围：统一 `priority`、保留被动持有物与单全局 field、保留命中与物理/特殊伤害、移除通用状态包、移除暴击/真伤/护盾/闪避、多档可见性、主动道具。
- 验收标准：开发者只读 `docs/rules/` 即可开始实现，不需要再靠聊天补规则。

#### 已完成内容
- 把总则改为“极简闭环优先”，并清掉旧的复杂机制定位。
- 只保留 `prototype_full_open` 一个可见性模式。
- `priority` 收敛成唯一数轴：`-5 ~ +5`，数值越大越先。
- 写死行动侧取值：绝对先手奥义 `+5`，换人 `+4`，普通技能 `-2 ~ +2`，绝对后手奥义 `-5`。
- 标准模式只保留被动持有物，不再存在主动使用持有物指令。
- field 改为“全场唯一实例”，由技能描述决定具体效果。
- 命中率只看技能自身 `accuracy`，移除闪避相关全部口径。
- 伤害改为官方骨架简化版，并保留物理 / 特殊双轨。
- 当前基线移除通用状态包、暴击、真伤、护盾、属性克制、同属性加成。
- AI 改为从引擎提供的合法指令列表中选指令。
- 日志字段同步删去 `crit_roll`、`damage_roll` 等已移除机制。

#### 最小可玩性检查清单（文档基线）
- 可启动：按文档可以从开战一路走到胜负结算。
- 可操作：玩家能完成选技能、换人、奥义、击倒补位这一整轮循环。
- 无致命错误：不会再出现“到底该看哪套 priority”“有没有闪避”“护盾先不先扣”这种口径分叉。

#### 回归检查要点
- 文档里是否已经不存在 `absolute_order / action_priority / skill_priority` 这类旧排序口径。
- 文档里是否已经不存在暴击、真伤、护盾、闪避率、通用状态包的现行条款。
- 标准模式下是否只保留 `prototype_full_open`。
- field 是否被统一写成“全场最多 1 个”。
- 被动持有物是否始终被描述成装备，不是行动指令。
- AI 是否明确是“合法列表内选择”，不是反复试错。

### 文档口径冲突收口（已完成：v0.7.0 一致性补丁）
- 目标：在不增加机制的前提下，把现行文档里的冲突项和松口项全部收紧到极简基线。
- 范围：持续效果持续模型、`turn_start` MP 回复与 field/rule_mod 时序、超时默认动作命名、`source_instance_id` 的排序与日志口径。
- 验收标准：开发者不会再因为这些条目写出两套实现；现行文档里只保留一套最小规则。

#### 已完成内容
- 把持续效果持续模型统一收紧为“按回合 / 永久”两种，移除“按触发次数”这类未落地模型口子。
- 写死 `turn_start` MP 回复读取“本回合开始前已生效状态”，同节点新触发的 field / effect / rule_mod 不回头改写本次回复。
- 历史口径：当时把超时默认动作命名统一为 `command_type = timeout_default`、`command_source = timeout_auto`；现行规则已改为 `wait / timeout_auto`。
- 补齐 `source_instance_id` 的最小生成口径，并要求进入完整日志。
- 明确模块 06 是“当前最小效果框架 + 扩展纪律”，不是首版一次性全做完的清单。

#### 最小可玩性检查清单（文档基线）
- 可启动：实现者只看现行规则，就能唯一确定持续效果和 MP 回复时序。
- 可操作：超时默认动作、field 替换、效果排序都只有一套日志命名和触发源口径。
- 无致命错误：不会再出现“这个 field 到底算不算本回合回复”“timeout 到底写哪种名字”“持续效果能不能按次数扣”这类文档分叉。

#### 回归检查要点
- `duration_mode` 是否仍只允许 `turns / permanent`。
- 模块 04 与模块 06 对持续时间描述是否一致。
- `turn_start` MP 回复是否只读取本回合开始前已经生效的状态。
- 历史检查点：当时确认 `timeout_default / timeout_auto` 已替代 `timeout_auto_action`；现行规则继续以 `wait / timeout_auto` 为准。
- `source_instance_id` 是否同时出现在排序口径与完整日志口径里。

### 未用触发点清理（已完成：v0.7.0 极简触发点补丁）
- 目标：删掉当前基线没落地需求的触发点，避免效果系统文档看起来比真实目标更重。
- 范围：模块 06 的当前基线触发点表、技能对接字段说明、对应决策记录。
- 验收标准：现行文档里，技能字段和触发点表一一对应；不再保留当前没使用的触发点名字。

#### 已完成内容
- 从当前基线触发点中移除 `on_action_attempt / before_action / after_action / on_resource_change`。
- 新增并明确使用 `on_cast`，与 `effects_on_cast_ids` 直接对应。
- 把“只保留当前最小触发点集合”同步写入决策记录。

#### 最小可玩性检查清单（文档基线）
- 可启动：实现者只需支持当前最小触发点集合，就能覆盖现行技能、换人、倒下和回合节点。
- 可操作：技能侧 `effects_on_cast_ids / effects_on_hit_ids / effects_on_miss_ids` 都能找到唯一对应触发点。
- 无致命错误：不会再出现“字段叫 cast、触发点却没有 cast”这种文档自相矛盾。

#### 回归检查要点
- 模块 06 的触发点表里是否已不存在 `on_action_attempt / before_action / after_action / on_resource_change`。
- `effects_on_cast_ids` 是否已明确对应 `on_cast`。

### 极简基线审查与历史文档防误读（已完成：v0.7.0 审查补丁）
- 目标：确认当前极简基线已经自洽，同时把仍然保留旧口径的历史文档明确标成“只能追溯，不能实现”。
- 范围：`docs/rules/README.md`、退役总表、`docs/records/archive/` 抬头警告、决策记录补充。
- 验收标准：开发者全局搜规则时，不会把 archive 里的旧机制误当成当前生效规则。

#### 已完成内容
- 复查现行 `docs/rules/`，确认极简基线仍以 `prototype_full_open + 被动持有物 + 单全局 field + 统一 priority + 简化命中与伤害` 为唯一口径。
- 为 `docs/records/archive/` 两个历史文件补上“含已废弃口径，不得直接实现”的显式提醒。
- 为退役总表补上“命中这里不能直接实现”的警告。
- 在规则导航中新增“全局搜索默认排除 archive”的使用约束。
- 在决策记录中补充“历史文档保留但必须显式防误读”的约束。

#### 最小可玩性检查清单（文档基线）
- 可启动：新开发者只看 `docs/rules/` 就能开始实现，不会被 archive 带偏。
- 可操作：全局搜索 `priority / field / 状态 / 暴击` 这类词时，能一眼分清现行规则和历史归档。
- 无致命错误：不会再出现“旧文档里写过，所以现在也算数”的误读。

#### 回归检查要点
- `docs/rules/README.md` 是否明确要求全局搜索时排除 `docs/records/archive/`。
- `docs/records/archive/` 的文件头是否明确标注“历史归档，不能直接实现”。
- 退役总表是否已明确声明“只读 `docs/rules/`，不要据此实现”。

## 2026-03-25

### 战斗骨架审查问题修复（已完成：三批提交收口）
- 目标：把本轮架构审查中确认的真实问题修平，避免“日志语义漂移”和“脏内容静默进入运行态”继续积累。
- 范围：`battle_end` 系统链归因、`turn_limit` 链来源、内容快照加载期校验补强、日志/内容 schema 文档收口、记录更新。
- 验收标准：终局日志继承真实系统来源；重复 ID 与非法内容字段在加载期直接失败；文档口径与现行实现一致。

#### 已完成内容
- 第一批：修复 `battle_end` 在 `turn_start / surrender / turn_limit` 路径上可能丢失真实系统来源的问题，并补充针对 `turn_start` 与 `turn_limit` 的专门回归测试。
- 第二批：补齐内容快照校验，新增重复 ID、技能 `accuracy / mp_cost / damage_kind / power`、效果优先级、`resource_mod.resource_key`、`stat_mod.stat_name` 等硬校验。
- 第二批同时补充测试，覆盖新的加载期失败类别，防止后续回归。
- 第三批：同步更新日志契约和内容 schema 文档，并把本轮修复决策写入 `docs/records/decisions.md`。
- 分批提交完成：`fix: preserve battle end system origins`、`fix: harden content snapshot validation`。

#### 最小可玩性检查清单
- 可启动：样例战斗仍可正常初始化、回放并打到终局。
- 可操作：现有技能、换人、补位、field、默认动作路径没有因新校验或链路收口而失效。
- 无致命错误：`battle_end` 与 `system:turn_limit` 不再挂错系统来源；非法内容不会再静默覆盖或带病运行。

#### 回归检查要点
- `tests/run_with_gate.sh` 必须全绿。
- `result:battle_end` 在 `turn_start` 终局路径上必须继承 `system:turn_start / turn_start`。
- `system:turn_limit` 与它收尾的 `result:battle_end` 必须归入 `turn_end`。
- 内容快照若出现重复 ID、非法 `accuracy/mp_cost`、非法 `resource_key/stat_name`，必须在加载期直接失败。

## 2026-03-27

### 宿傩准入与核心机制扩展（已完成）
- 目标：落地 `wait + Struggle` 分流、领域生命周期拆分、effect 到期后效、内容 schema 扩展，并接入默认装配版宿傩内容包。
- 范围：`battle_core` 指令/合法性/执行/生命周期链路、内容定义与校验、宿傩资源、测试迁移、规则与设计文档同步。
- 验收标准：`tests/run_with_gate.sh` 全绿；规则文档口径不再出现 `timeout_default`；宿傩回归用例可通过。

#### 已完成内容
- 指令层：新增 `wait`，移除 `timeout_default`；`wait_allowed` 接入 legal set；超时自动行为切到 `wait(timeout_auto)` 或 `resource_forced_default`。
- 执行层：`wait` 仅产生日志 cast，不走命中/伤害/recoil/effect；默认动作专属 recoil 仅保留给 `resource_forced_default`。
- 生命周期：effect 到期后效先执行后移除；field 自然到期与提前打断分别走 `on_expire_effect_ids` / `on_break_effect_ids`。
- 命中与数值：领域 creator 命中覆盖、`power_bonus_source = mp_diff_clamped`、固定属性伤害克制、百分比治疗。
- 触发扩展：新增 `on_matchup_changed` 与对位签名去重触发。
- 内容接入：新增 `sukuna` 单位、`解/捌/开/反转术式/伏魔御厨子`、灶/领域/被动相关资源。
- 测试迁移：新增 `timeout_wait_path / wait_allowed_non_mp_blocked_path / manual_wait_no_damage_path / sukuna_content_pack_smoke / on_matchup_changed_dedup_path` 等回归。

#### 最小可玩性检查清单
- 可启动：宿傩资源可加载，回放与会话模式可正常创建战斗。
- 可操作：`wait` 可手动与超时自动触发；领域与灶可按生命周期结算。
- 无致命错误：规则闸门与架构闸门均通过。

#### 回归检查要点
- `tests/run_with_gate.sh` 必须全绿。
- 无合法动作且全 MP 不足时必须强制 `resource_forced_default`；非 MP 阻断场景超时必须自动 `wait`。
- `select_timeout` 必须由 `command_source = timeout_auto` 驱动。
- `damage_payload_fixed_type_resolution` 与 `heal_payload_percent_resolution` 必须通过。

## 2026-03-28

### 规则收口与架构对齐（已完成）
- 目标：把外层 ID contract、field 生命周期时序、宿傩内容口径与 README / rules / design / records / tests 一次性收口。
- 范围：`LegalActionSet` 与选择适配层改用 `public_id`、field 提前打断下沉到共享服务并接入手动换人/强制换下/击倒补位、宿傩默认装配与候选技能池文档化、records 历史口径覆盖标注。
- 验收标准：完整闸门全绿；合法性接口与适配层不再暴露 bench `unit_instance_id`；creator 离场时 field 必须先打断再补位/入场；README 与规则文档只保留一套现行口径。

#### 已完成内容
- contract：`LegalActionSet` 已切换为 `actor_public_id / legal_switch_target_public_ids`，`BattleAIAdapter / PlayerSelectionAdapter` 已切到 `target_public_id`。
- validator：外层默认输入继续走 `actor_public_id / target_public_id`，内部 `actor_id / target_unit_id` 仍保留给系统自动动作，并在校验时回填对应 `public_id`。
- lifecycle：field 提前打断逻辑下沉到 `FieldService`，并接入手动换人、强制换下、击倒窗口与 field 覆盖链，保证 `field_break` 发生在 `replace / on_enter` 之前。
- tests：新增手动换人 / 强制换下 / 击倒补位 field 提前打断回归、`public_id` facade 契约回归、适配层 `public_id` 回归、宿傩默认装配回归。
- docs：README、`docs/rules`、`docs/design`、`content/README.md` 与 records 已同步到最终口径。

#### 回归检查要点
- `tests/run_with_gate.sh` 必须全绿。
- creator 离场后，旧 field 不得再影响替补入场链与 `on_enter`。
- manager/adapter 层不得再把 bench `unit_instance_id` 暴露给外层。
- 宿傩默认装配快照必须保持 `解 / 捌 / 开`，`反转术式` 只作为候选技能保留。

### 宿傩收口与回合协调器瘦身（已完成）
- 目标：把宿傩内容包、README/规则/设计文档与当前实现重新对齐，并消掉 `turn_resolution_service / battle_initializer` 的临时超阈值豁免。
- 范围：宿傩 `灶` 持续配置、宿傩回归、turn 子域拆分、首页与 schema 文档同步、架构闸门更新。
- 验收标准：`tests/run_all.gd` 与 `tests/check_architecture_constraints.sh` 全绿；README 和 `docs/rules / docs/design` 不再保留旧口径。

#### 已完成内容
- 宿傩：`灶` 调整为可支撑“双层挂灶后下一回合离场同时触发”的持续时长，并补了“两层都在场”的回归断言。
- 回合层：新增 `turn_selection_resolver.gd` 与 `turn_field_lifecycle_service.gd`，把选指分流、field 生命周期和 `on_matchup_changed` 从 `turn_resolution_service.gd` 中拆出。
- 初始化层：`battle_initializer.gd` 清掉未使用依赖，保留清晰的启动链。
- 文档层：更新 README、内容说明、effect/schema/turn 文档，补齐 `stack / on_matchup_changed / creator_accuracy_override / dynamic rule_mod value` 口径。

#### 回归检查要点
- `sukuna_kamado_stack_on_exit_path` 必须稳定通过，且中途断言为“场上有两层灶”。
- `tests/check_architecture_constraints.sh` 不再允许 `turn_resolution_service.gd` 与 `battle_initializer.gd` 走超阈值豁免。

### 五条悟设计文档实现对照审计（已完成）
- 目标：把 `docs/design/gojo_satoru_design.md` 与当前引擎、宿傩内容资源、合法性/执行时序的真实实现重新对齐，修正所有已确认的事实性偏差。
- 范围：`docs/design/gojo_satoru_design.md`、`docs/records/decisions.md`、`docs/records/tasks.md`。
- 验收标准：五条悟文档中与宿傩迁移、领域回滚、`action_legality` / `wait` 时序、资源清单、命名一致性相关的错误全部修正；关键决策落盘。

#### 已完成内容
- 修正宿傩迁移口径：`sukuna_domain_rollback.tres` 从迁移表移除，明确只有 `sukuna_domain_expire_seal.tres` 需要从 `skill_legality` 迁到 `action_legality`。
- 修正五条悟领域回滚口径：冻结为“与 `gojo_domain_expire_seal` 相同的 3 条封印链”，不再错误引用宿傩 `domain_rollback` 的 `stat_mod` 设计。
- 修正文档里把 `action_lock` / `action_legality deny all` 说成“forced WAIT”的问题，改为与当前执行链一致的“两种口径”：队列中途失效按 `cancelled_pre_start` 跳过；选择阶段则保留 `wait` 为唯一合法动作。
- 修正文档示例代码：去掉不符合当前 `Command` 对象类型的 `command.has("skill_id")` 写法，并补齐 `_command_to_action_type()` 示例。
- 修正资源清单与命名：补充复合 effect 描述，确认 `space / psychic` 已存在且 `sample_battle_format.tres` 无需补改，并把领域文件名统一为 `gojo_unlimited_void_field.tres` 以匹配现有资源命名习惯。
- 统一“无量空处”写法，消除 `无量空処 / 無量空処 / 无量空处` 混用。

#### 最小可玩性检查清单
- 可启动：本轮仅改文档与记录，不影响游戏启动链。
- 可操作：本轮不改运行时代码，现有样例战斗与宿傩玩法不应受影响。
- 无致命错误：文档口径已与当前实现对齐，后续按文档施工时不会再误迁移宿傩 rollback 或误判 `wait` / `cancelled_pre_start` 时序。

#### 回归检查要点
- 文档中的宿傩迁移表不得再把 `sukuna_domain_rollback.tres` 记成 `skill_legality -> action_legality`。
- Gojo 文档必须明确：`action_legality deny all` 不阻断 `wait`，中途挂锁的已选指令按 `cancelled_pre_start` 跳过。
- `space / psychic` 已存在的事实与 `sample_battle_format.tres` 已配置的事实必须在文档中写明。

### 五条悟设计文档二次收敛（已完成）
- 目标：按最终讨论结论收敛 Gojo 方案，去掉当前阶段不必要的高成本引擎改动，确保文档直接可施工。
- 范围：`docs/design/gojo_satoru_design.md`、`docs/records/decisions.md`、`docs/records/tasks.md`。
- 验收标准：文档中不再包含“茈自伤链”和“无下限改伤害链”，并明确新的最小引擎改动范围与测试口径。

#### 已完成内容
- 重写 `gojo_satoru_design.md` 为收敛版 v2：茈改为“命中后条件追加爆发 + 清双标记”，明确不做自伤。
- 无下限改为“敌方攻击五条悟时（除必中外）命中率 -10”，并收口为 `incoming_accuracy` 规则读取点，不再使用 `on_before_damage + damage_override`。
- 数值同步收敛：`init_mp` 下调到 50、`regen_per_turn` 下调到 14，奥义改为 `power=48 / mp_cost=50`，茈改为 `power=64 / accuracy=90 / mp_cost=24`。
- 引擎范围收敛为 `action_legality + required_target_effects + incoming_accuracy`，并在文档中明确列出延期项（`effects_pre_damage_ids`、`action_tags`、`last_dealt_damage` 等）。
- 在 `decisions.md` 追加冻结决策，防止后续实现回滚到旧方案。

#### 最小可玩性检查清单
- 可启动：本轮仅改文档与记录，不影响现有运行时代码。
- 可操作：后续实现可直接按三块引擎改动拆任务，不再被旧版大改方案阻塞。
- 无致命错误：文档中已移除与当前目标冲突的机制路径（茈反噬、自伤、无下限改伤害）。

#### 回归检查要点
- Gojo 文档不得再出现 `on_before_damage`、`damage_override`、`last_dealt_damage` 作为首版必做项。
- 无下限描述必须固定为“非必中来袭命中 -10”，而不是概率改伤害。
- 茈描述必须固定为“条件追加爆发 + 清双标记 + 不自伤”。

### 五条悟设计文档严谨性补充（已完成）
- 目标：吸收 v2 审查反馈中有效项，补齐文档语义边界，避免后续实现阶段出现字段归属与 payload 语义误解。
- 范围：`docs/design/gojo_satoru_design.md`、`docs/records/decisions.md`。
- 验收标准：赛前字段归属、领域封印结构、`action_legality` 语义、`incoming_accuracy` 约束、茈追加伤害语义都在文档里写成可执行口径。

#### 已完成内容
- 在 Gojo 文档中明确 `SideSetup.regular_skill_loadout_overrides` 字段归属，并同步修正测试计划用语。
- 把 `gojo_domain_expire_seal / gojo_domain_rollback` 明确写成“单 effect + 3 rule_mod payload”结构。
- 补充 `action_legality` 的 `mod_op=allow/deny` 共同 value 范围，明确 `all` 不影响 `wait`。
- 补充 `resolve_hit` 目标侧读取 `incoming_accuracy` 的签名改造要求（调用侧需补传 target）。
- 补充茈条件追加伤害里 `use_formula=true` 时 `amount` 语义与 `combat_type` 继承规则说明。
- 冻结 `incoming_accuracy` 文档示例参数为 `stacking=none`，并注明 permanent 场景仍显式声明 `decrement_on` 是为匹配当前 validator 约束。

#### 回归检查要点
- Gojo 文档中涉及赛前换装的描述必须使用 `SideSetup.regular_skill_loadout_overrides`。
- `gojo_domain_expire_seal / rollback` 的结构描述必须是“1 个 effect 内 3 个 payload”。
- 文档必须明确 `resolve_hit` 读取 `incoming_accuracy` 是目标侧语义且需要目标参数。

### 五条悟文档全链路彻查收口（已完成）
- 目标：按“实现层约束 -> 设计文档 -> 测试计划”三层做彻查，消除剩余歧义点，形成可直接施工的 Gojo 文档。
- 范围：`docs/design/gojo_satoru_design.md`、`docs/records/decisions.md`、`docs/records/tasks.md`。
- 验收标准：文档中所有关键资源定义都能映射到当前 schema/validator/服务行为，不再依赖口头补充。

#### 已完成内容
- 补齐茈条件爆发 effect 的完整字段定义（含 `scope=target`），并明确 `required_target_effects` 的目标解析来源为 `chain_context.target_unit_id`。
- 补齐苍/赫标记（`gojo_ao_mark` / `gojo_aka_mark`）的完整 EffectDefinition 字段，消除“纯标记 effect”落地歧义。
- 补齐领域三类关键 effect（action_lock / expire_seal / rollback）的“EffectDefinition 层 + RuleModPayload 层”双层配置口径。
- 修正文档里无下限触发点：由 `battle_init` 改为 `on_enter`，并写明原因是离场会清空 `rule_mod_instances`。
- 明确 `action_legality` 与 `incoming_accuracy` 的完整接入清单（含 validator 白名单、stacking key schema、服务函数签名与调用点变更）。
- 明确 `incoming_accuracy` 的 `0~99` 上界是设计选择（不允许通过该规则把命中改成硬必中）。

#### 回归检查要点
- 无下限章节必须显式区分 EffectDefinition 层与 RuleModPayload 层的 `decrement_on` 约束。
- 文档中无下限触发点必须是 `on_enter`，不能回退为 `battle_init`。
- `action_legality / incoming_accuracy` 的改动清单必须覆盖 `content_schema + content_payload_validator + rule_mod_service + action_cast_service + action_executor + legal_action_service`。

### 五条悟文档二审细节补丁（已完成）
- 目标：吸收第二轮审查的中风险建议，补齐“实现者最容易误读”的语义边角，降低后续再审漏项概率。
- 范围：`docs/design/gojo_satoru_design.md`、`docs/records/decisions.md`。
- 验收标准：文档内对 stacking key、兼容期混合读取、permanent 空转字段、领域互斥触发与茈清标记边界都有显式说明。

#### 已完成内容
- 补充 `action_legality` 与 `incoming_accuracy` 的 stacking key schema 明确数组定义。
- 补充兼容期 `is_action_allowed` 混合读取策略：`action_legality + skill_legality` 同排序链处理。
- 补充 `permanent` RuleModPayload 的 `decrement_on` 运行时空转语义（仅为校验约束字段）。
- 补充领域 `expire` 与 `break` 互斥触发说明，避免误判为可叠加双封印。
- 补充苍/赫标记 `persists_on_switch=false` 的玩法含义（换人清标记）。
- 补充茈命中后“击杀导致 remove_effect 静默跳过”的边界说明，并明确 `required_target_effects` 前置检查是 remove_effect 安全前提。

#### 回归检查要点
- Gojo 文档必须包含 `action_legality` 与 `incoming_accuracy` 的 stacking key schema 字段列表。
- Gojo 文档必须明确兼容期 `is_action_allowed` 同时读取新旧 mod_kind 并走统一排序。
- Gojo 文档必须写明 `permanent` RuleModPayload 的 `decrement_on` 不参与实际扣减。

### 五条悟文档三审明显错误修复（已完成）
- 目标：只处理“无需拍板即可直接修”的硬缺口，消除实施歧义并同步仓库级规范文档。
- 范围：`docs/design/gojo_satoru_design.md`、`docs/rules/06_effect_schema_and_extension.md`、`docs/design/effect_engine.md`、`docs/design/battle_runtime_model.md`、`docs/design/battle_content_schema.md`、`docs/records/decisions.md`、`docs/records/tasks.md`。
- 验收标准：匹配矩阵、读取约束、fail-fast 校验、领域后摇时间线、测试边界与规则文档同步都落盘；待拍板项显式隔离。

#### 已完成内容
- Gojo 文档补齐 `action_legality` 匹配矩阵与统一判定顺序（含兼容期 `skill_legality + action_legality` 同排序链）。
- Gojo 文档补齐 `required_target_effects` 的加载期 fail-fast 要求（非空/去重/存在性校验）与坏引用测试项。
- Gojo 文档补齐 `incoming_accuracy` 的硬约束：仅敌方来袭技能/奥义读取；`self/field/none` 与 `switch/wait/resource_forced_default` 一律跳过。
- Gojo 文档补齐领域后摇显式时间线，明确 `duration=2 + turn_end` 如何落到“体感封印 1 回合”。
- Gojo 测试计划新增边界：标记换人清除、茈追加击杀后 remove skip、坏引用 fail-fast、兼容期双口径共读、矩阵组合用例。
- 仓库级规则文档同步补齐 `action_legality / incoming_accuracy / required_target_effects` 的扩展规范，避免 Gojo 文档与 `docs/rules` 分叉。
- 三个需要你拍板的议题已显式标记为“本轮不改语义”。

#### 回归检查要点
- `docs/rules/06`、`docs/design/effect_engine.md`、`docs/design/battle_runtime_model.md`、`docs/design/battle_content_schema.md` 必须与 Gojo 文档使用同一术语集合（`action_legality / incoming_accuracy / required_target_effects`）。
- Gojo 文档必须明确 `wait` 不受 `action_legality` 影响，且 `switch` 必须命中 `value=switch/all` 才受管控。
- Gojo 文档必须保留“待拍板项”隔离区，不允许把未定语义伪装成已冻结实现口径。

### 领域后摇删除（Gojo + Sukuna）（已完成）
- 目标：按你拍板直接删除“领域放完后的后摇”，并让宿傩现有实现与 Gojo 新文档保持同口径。
- 范围：`content/fields/sukuna_malevolent_shrine.tres`、`tests/suites/sukuna_suite.gd`、`src/composition/sample_battle_factory.gd`、`docs/design/gojo_satoru_design.md`、`docs/records/decisions.md`、`docs/records/tasks.md`。
- 验收标准：领域到期/打破后不再追加封印或回滚；领域强度本轮不下调；回归全绿。

#### 已完成内容
- Sukuna 领域资源改为“到期仅终爆、打破无后效”：移除 `sukuna_domain_expire_seal` 与 `sukuna_domain_rollback` 触发。
- 删除未再使用的资源文件：`content/effects/sukuna_domain_expire_seal.tres`、`content/effects/sukuna_domain_rollback.tres`。
- `sample_battle_factory` 移除两份已删除资源路径，防止快照加载死链。
- Sukuna 回归用例改为新语义：验证“领域结束后不封技能、不回退攻阶”。
- Gojo 设计文档删除后摇设计（field 的 `on_expire_effect_ids/on_break_effect_ids` 置空、资源清单和测试计划同步）。

#### 回归检查要点
- `sukuna_domain_expire_chain_path` 必须验证“终爆仍生效，但无封印、无 rollback”。
- `sukuna_domain_break_chain_path` 必须验证“打破无终爆、无封印、无 rollback”。
- Gojo 文档不得再出现 `gojo_domain_expire_seal / gojo_domain_rollback` 的可施工定义。

### 五条悟文档四审职责与边界修复（已完成）
- 目标：把上一轮口头审查里会直接误导后续实现的硬问题全部修掉，确保 Gojo 文档可作为后续施工蓝图使用。
- 范围：`docs/design/gojo_satoru_design.md`、`docs/records/decisions.md`、`docs/records/tasks.md`。
- 验收标准：文档不再误指 `CommandValidator` 承担 legal set 语义；`switch` 被封禁时的 `wait/forced default` 分支写清；同批次 effect 顺序、首回合 MP 时点、换人打断茈连段与宿傩非中性参照都显式落盘。

#### 已完成内容
- 修正 `action_legality` 实现清单，明确选择阶段职责仍在 `LegalActionService + TurnSelectionResolver`，`CommandValidator` 只保留硬非法校验。
- 补充 `action_legality` 对换人的影响：当换人被封禁时，也要计入非 MP 阻断，保证 `wait` 仍是唯一合法动作，而不是错误转成 `resource_forced_default`。
- 补充 `action_legality.value` 与 `incoming_accuracy.value` 的加载期 fail-fast 约束，并明确两者都禁止 `dynamic_value_formula`。
- 补充苍/赫与领域 `effects_on_hit_ids` 的顺序约束：当前设计不得依赖同批次 effect 的默认声明顺序；若未来需要先后依赖，必须显式拉开 `priority`。
- 补充茈的槽位重定向边界：目标先换下时，茈命中新 active，且因旧目标离场清标记而默认不会触发追加段。
- 修正平衡口径：写明 Gojo 首个可操作回合实战可用 MP 为 `64`，并注明宿傩不是严格中性参照。
- Gojo 测试计划新增首回合 MP、换人被封禁后的 `wait`、茈槽位重定向等边界用例。

#### 回归检查要点
- Gojo 文档中的 `action_legality` 实现清单不能再把“legal set 提交通道”错误挂到 `command_validator.gd`。
- Gojo 文档必须明确“换人被 `action_legality` 封禁”会影响 `wait_allowed / forced_command_type` 的分支。
- Gojo 文档必须明确：同批次 `effects_on_hit_ids` 默认不保证声明顺序。
- Gojo 文档必须明确：首回合选指前先回 MP，Gojo 的首个可操作回合实战可用 MP 是 `64`。
