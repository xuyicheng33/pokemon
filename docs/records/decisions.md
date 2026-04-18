# 决策记录（活跃）

本文件只保留当前仍直接约束实现、门禁和扩角节奏的活规则；更早的完整背景与执行流水统一看 archive。

历史归档：

- `docs/records/archive/decisions_pre_2026-04-05_repair_wave.md`
- `docs/records/archive/decisions_pre_v0.6.4.md`
- `docs/records/archive/decisions_pre_v0.6.3.md`
- `docs/records/archive/decisions_2026-04-10_to_2026-04-18_refactor_wave.md`

当前生效规则以 `docs/rules/` 为准；`docs/design/` 负责结构与交付面；本文件只解释“为什么现在这样定”。

## 0. 正式角色整合修复波次的新固定决定

- `docs/records/` 以后只承担活跃记录、决策入口与 archive 索引，不再继续充当现行规则的机器约束层。
- formal 共享字段定义只保留一份真相：
  - `config/formal_registry_contracts.json`
  - `src/shared/formal_registry_contracts.gd`
- formal pair 覆盖模型继续固定为：
  - 每个无序正式角色对至少 1 条 interaction case
  - 允许同 pair 多 case
- Kashimo / Sukuna 的 manager 黑盒继续视为正式交付面的一部分；后续扩角不得跳过 manager 级黑盒。

## 0R. README surface 合同与 demo replay smoke 固定补回主线（2026-04-18）

- README 当前继续承担 surface gate 的一部分合同，尤其是代码规模统计与 `content_snapshot_paths_result()` 的基础覆盖面说明。
- `demo=<profile>` 继续是 CLI/debug 入口，但必须固定自动回归：
  - `tests/check_sandbox_smoke_matrix.sh` 补跑 `legacy` 与 `kashimo` 两个 demo profile
  - demo replay 摘要上下文固定取 profile 真值，不再回退到 launch config 默认的 `matchup_id / battle_seed`

## 0S. formal character registry 改为 source descriptor 单源，validator 升级为硬约束（2026-04-18）

- `config/formal_character_sources/` 现在是 formal 角色 registry 的唯一人工维护入口：
  - `00_shared_registry.json` 负责共享 `matchups/capabilities`
  - 每个角色一份 `0N_<character>.json` 负责 runtime + delivery + `content_roots`
- `config/formal_character_manifest.json` 与 `config/formal_character_capability_catalog.json` 继续提交到仓库，但已经退成生成产物，不再手工维护。
- `content_roots` 允许目录与单文件资源混用，导出时统一递归展开成稳定排序的 `required_content_paths`。
- `content_validator_script_path` 现在是 formal 角色 runtime 合同的必填字段，不再写成“按需”。
- formal gate 当前固定校验：
  - source descriptors 可导出
  - 导出结果与 committed manifest/catalog 完全一致
  - 同一轮里不允许 source 与产物漂移

## 0Q. 正式角色 manager smoke/blackbox 与 formal registry 厚 suite 固定模板化（2026-04-18）

- `tests/support/formal_character_manager_smoke_helper.gd` 当前固定承担 shared runner：
  - `run_named_case / run_case`
  - `build_case_state`
  - `get_legal_actions_result / get_public_snapshot_result / get_event_log_result`
  - `build_command_result / run_turn_result / run_turn_sequence_result`
- 四个正式角色的 `manager smoke/blackbox` suite 当前固定写成“case spec + 少量角色断言”，不再各自复制 session / command / close 样板。
- `catalog_factory_suite.gd` 与 `replay_guard_suite.gd` 当前固定不再回到单大文件：
  - `catalog_factory` 拆成 `setup / delivery_alignment / surface`
  - `replay_guard` 拆成 `input / summary / failure`
  - 跨域断言只允许留在 shared support
- formal registry 的 fixture helper 当前默认会补合法 validator 路径；如果坏例不是在测 validator，就不应该先被 validator 缺失抢走失败原因。

## 0O. 组合依赖、turn/init 编排与 sandbox 外围热点继续冻结为新结构（2026-04-18）

- compose 依赖与 reset 元数据继续只认 script 自声明：
  - `COMPOSE_DEPS`
  - `COMPOSE_RESET_FIELDS`
- `BattleCoreComposer`、runtime 缺依赖检查与两条 architecture gate 统一通过 `service_dependency_contract_helper.gd` 读取这份声明，不再恢复 split wiring specs。
- 回合编排继续固定为：
  - `turn_selection_resolver.gd`
  - `turn_start_phase_service.gd`
  - `turn_end_phase_service.gd`
  - `turn_field_lifecycle_service.gd`
- `BattleInitializer` 继续只保留顺序调度；setup 校验、side/unit 构造与初始化阶段子流程分别下沉到独立 owner。
- `SandboxSessionCoordinator` 继续只保留 facade；sandbox 会话热点固定拆成 `bootstrap / demo / command` 三个 owner。

## 0U. BattleSandbox 当前主线入口与验证矩阵固定保留（2026-04-13）

- `BattleSandboxController` 继续是当前研发试玩入口；默认路径继续固定为 `gojo_vs_sample + 9101 + manual/policy`。
- `tests/run_with_gate.sh` 继续是唯一总入口，顺序保持：
  - `gdUnit4`
  - `boot smoke`
  - `suite reachability`
  - `architecture constraints`
  - `repo consistency`
  - `sandbox smoke matrix`
- `BattleSandbox`、`run_with_gate` 与 `gdUnit4 + test/` 继续构成当前仓库的主研发主线。

## 0Y. formal pair 输入与派生 contract 继续冻结（2026-04-12）

- `2026-04-12` 起，formal pair 输入继续固定挂在 `characters[*]` 的 runtime 条目：
  - `pair_token`
  - `baseline_script_path`
  - `owned_pair_interaction_specs`
- `pair_token` 继续作为 formal pair 身份字段；`baseline_script_path` 继续作为 formal baseline 注册字段；`owned_pair_interaction_specs` 继续是唯一手写 pair interaction 输入。
- manifest 不再恢复顶层 pair bucket；pair 覆盖与 directed case 继续从 manifest 角色条目派生。

## 1. Archive 读取顺序

- 查当前仍生效的结构与交付规则：先看本文件，再看 `docs/design/`
- 查 2026-04-10 到 2026-04-18 这轮完整背景：看 `docs/records/archive/decisions_2026-04-10_to_2026-04-18_refactor_wave.md`
- 查更早 repair wave 或 v0.6.3/v0.6.4 背景：看对应历史 archive
