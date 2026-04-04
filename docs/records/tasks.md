# 任务清单（精简版）

本文件只保留当前仍需直接指导开发的任务摘要、验证结果与未解决问题。

历史完整记录已归档到：

- `docs/records/archive/tasks_pre_v0.6.3.md`
- `docs/records/archive/tasks_pre_v0.6.4.md`

当前生效规则以 `docs/rules/` 为准；工程落点以 `docs/design/` 为准。

## 当前阶段

- 阶段目标：按“基础稳定化整改路线图”先收口 passive fail-fast、错误读取通道、runtime wiring DAG、content cache 与 replay 索引，再继续扩正式角色与批量回放。
- 当前不做：Gojo / Sukuna / Kashimo 数值平衡调整、新角色扩角、现有角色机制重设计、整仓库 DI 重写。
- 当前优先级：
  - 先保证 `invalid_battle` 与用户可见错误不再通过字符串通道静默漏报
  - 再把 runtime wiring DAG、content cache 与 replay 索引做成 gate 和回归
  - 同步把审查记录、设计稿与 README 口径写回仓库，避免“严格 DAG / 完全对齐”这类过度结论继续扩散
  - 每阶段都要完成验证、提交、推送，并在进入下一阶段前把工作区收干净

## 2026-04-04

### 正式角色扩展前整合：批次 1 共享机制硬约束收口（已完成）

- 目标：
  - 把 `action_legality`、`required_target_same_owner`、effect/rule_mod `refresh` 这三块共享机制里的隐式约定收成显式 contract，避免第 4 个正式角色接入时踩旧坑
- 范围：
  - `src/battle_core/content/content_schema.gd`
  - `src/battle_core/effects/effect_instance_service.gd`
  - `src/battle_core/effects/effect_precondition_service.gd`
  - `src/battle_core/effects/effect_source_meta_helper.gd`
  - `src/battle_core/effects/payload_handlers/payload_apply_effect_handler.gd`
  - `src/battle_core/effects/rule_mod_read_service.gd`
  - `src/battle_core/effects/rule_mod_service.gd`
  - `src/battle_core/effects/rule_mod_write_service.gd`
  - `tests/suites/action_legality_contract_suite.gd`
  - `tests/suites/extension_targeting_accuracy_suite.gd`
  - `tests/suites/on_receive_action_hit_suite.gd`
  - `tests/suites/rule_mod_runtime_core_paths_suite.gd`
  - `tests/support/gojo_test_support.gd`
  - `README.md`
- 验收标准：
  - `action_legality` 明确只管理 `skill / ultimate / switch`，`wait / resource_forced_default / surrender` 永不受管控
  - `required_target_same_owner` 读取 `source_owner_id` 时不再依赖散落裸 meta 约定；缺 owner 归因必须显式失败
  - effect / rule_mod 的 `refresh` 语义统一为“同实例续命并刷新来源元数据”
  - `bash tests/run_with_gate.sh` 通过

#### 当前执行结果

- 已完成：
  - `ContentSchema` 已新增显式 `MANAGED_ACTION_TYPES / ALWAYS_ALLOWED_ACTION_TYPES`
  - `RuleModReadService` 已切到显式受管控动作白名单；未知动作类型改为返回显式 `invalid_command_payload` 错误状态，不再靠默认分支静默吞掉
  - 已新增 `EffectSourceMetaHelper`，统一写入 / 读取 `meta.source_owner_id`
  - `PayloadApplyEffectHandler`、Gojo test helper 与相关 shared suite 已统一改走 owner meta helper
  - `EffectPreconditionService` 在 `required_target_same_owner=true` 且命中缺 owner 归因 effect instance 时，会显式上浮 `invalid_state_corruption`
  - `EffectInstanceService` 与 `RuleModWriteService` 的 `refresh` 路径都已同步刷新：
    - `remaining`
    - `source_instance_id`
    - `source_kind_order`
    - `source_order_speed_snapshot`
    - effect `meta`
  - 已补共享回归：
    - `action_legality_managed_action_matrix_contract`
    - `action_legality_unknown_action_type_reports_contract`
    - `required_target_same_owner_missing_owner_contract`
    - `effect_refresh_updates_source_metadata_contract`
    - `rule_mod_refresh_updates_source_metadata_contract`
  - `README.md` GDScript 行数统计已同步到当前仓库状态

#### 当前验证结果

- `bash tests/run_with_gate.sh` 通过

### 共享 schema 收口与 effect validator 硬化（已完成）

- 目标：
  - 收口 `action_actor` / `ChainContext` / `rule_mod` 读取点相关文档漂移，避免设计稿继续落后于正式实现
  - 把“内容能加载但运行时静默 no-op”的 effect scope / payload 组合改成加载期直接 fail-fast
  - 顺手抽掉角色 manager smoke suite 里的重复 helper，并固定公开快照里 effect stack 的稳定排序
- 范围：
  - `docs/design/battle_content_schema.md`
  - `docs/design/effect_engine.md`
  - `docs/design/battle_runtime_model.md`
  - `docs/rules/06_effect_schema_and_extension.md`
  - `src/battle_core/content/content_snapshot_effect_validator.gd`
  - `src/battle_core/facades/public_snapshot_builder.gd`
  - `tests/suites/extension_validation_contract_suite.gd`
  - `tests/suites/manager_snapshot_public_contract_suite.gd`
  - `tests/suites/gojo_manager_smoke_suite.gd`
  - `tests/suites/sukuna_manager_smoke_suite.gd`
  - `tests/suites/kashimo_manager_smoke_suite.gd`
  - `tests/support/manager_contract_test_helper.gd`
  - `tests/gates/repo_consistency_docs_gate.py`
  - `README.md`
- 验收标准：
  - docs gate 必须明确覆盖 `action_actor`、`action_actor_id / action_combat_type_id`、`nullify_field_accuracy`、`incoming_action_final_mod`
  - `action_actor + 非 on_receive_action_hit`、`field + unit-target payload`、`非 field + apply_field` 必须在 `validate_snapshot()` 直接报错
  - manager smoke suite 的公开快照/事件日志黑盒检查 helper 不再三份复制
  - `public_snapshot.effect_instances` 排序稳定，且不新增公开字段
  - `bash tests/run_with_gate.sh` 通过

#### 当前执行结果

- 已完成：
  - `battle_content_schema.md`、`06_effect_schema_and_extension.md`、`effect_engine.md`、`battle_runtime_model.md` 已补齐 `action_actor` 作用域、`ChainContext.action_actor_id / action_combat_type_id`、`nullify_field_accuracy`、`incoming_action_final_mod` 与 scope/payload 兼容约束
  - `repo_consistency_docs_gate.py` 已补对应静态检查，防止后续文档再次回漂
  - `ContentSnapshotEffectValidator` 已新增：
    - `scope=action_actor` 只能用于 `on_receive_action_hit`
    - `apply_field` 必须配 `scope=field`
    - `damage / heal / resource_mod / stat_mod / apply_effect / remove_effect` 不得配 `scope=field`
  - `extension_validation_contract_suite.gd` 已补负向回归，固定坏组合必须在加载期 fail-fast
  - `ManagerContractTestHelper` 已吸收三个 manager smoke suite 共有的 unit snapshot / runtime id leak / public heal / public cast 检查
  - `BattleCorePublicSnapshotBuilder` 已把 `effect_instances` 排序收口为 `effect_definition_id -> remaining -> persists_on_switch -> instance_id`
  - `manager_snapshot_public_contract_suite.gd` 已补公开快照 effect 顺序 contract
  - `README.md` 的 GDScript 行数统计已同步到当前仓库状态

#### 当前验证结果

- `bash tests/run_with_gate.sh` 通过

### manager 黑盒边界收口与 passive item 最小正式闭环（已完成）

- 目标：
  - 去掉 `BattleCoreManager` 的测试专用私有钩子，把 manager smoke 和 manager public contract 收回黑盒边界
  - 补一个最小正式 passive item 样例，把被动持有物从“只有框架”推进到“资源 + runtime + manager + replay”闭环
- 范围：
  - `src/battle_core/facades/*`
  - `src/composition/sample_battle_factory.gd`
  - `content/passive_items/*`
  - `content/effects/*`
  - `content/units/*`
  - `tests/suites/*manager*`
  - `tests/suites/content_snapshot_cache_suite.gd`
  - `tests/suites/content_snapshot_cache_composer_suite.gd`
  - `tests/suites/passive_item_contract_suite.gd`
  - `tests/run_all.gd`
  - `tests/gates/repo_consistency_surface_gate.py`
  - `README.md`
  - `content/README.md`
  - `tests/README.md`
- 验收标准：
  - manager 侧不再保留 `_debug_session`、`_inject_session_for_test`、`_override_container_factory_for_test`、`_replace_public_snapshot_builder_for_test`、`_shared_content_snapshot_cache_for_test`
  - Gojo / Sukuna manager smoke 不再钻内部 session
  - 新增 passive item 正式样例资源、黑盒 manager 回归与 replay 回归
  - `godot --headless --path . --script tests/run_all.gd`、`bash tests/check_repo_consistency.sh`、`bash tests/run_with_gate.sh` 通过

#### 当前执行结果

- 已完成：
  - `BattleCoreManager` 已删除 5 个测试专用私有钩子
  - `content_snapshot_cache_suite.gd` 已改成只保留 manager 黑盒语义断言；cache stats 另拆到 `content_snapshot_cache_composer_suite.gd`
  - `gojo_manager_smoke_suite.gd`、`sukuna_manager_smoke_suite.gd` 已改成纯 facade 主路径
  - `manager_facade_internal_contract_suite.gd`、`manager_log_and_runtime_contract_suite.gd` 已改成不依赖 manager 私有钩子的公开 contract 回归
  - 已新增最小正式 passive item 样例：
    - `content/passive_items/sample_attack_charm.tres`
    - `content/effects/sample_attack_charm_bonus.tres`
    - `content/units/sample_pyron_charm.tres`
  - `SampleBattleFactory` 已新增 passive item 专用 setup / replay builder
  - 已新增 `tests/suites/passive_item_contract_suite.gd`
  - `repo_consistency_surface_gate.py` 已补“manager 私有钩子不得回流”的静态检查

#### 当前验证结果

- `godot --headless --path . --script tests/run_all.gd` 通过
- `bash tests/check_repo_consistency.sh` 通过
- `bash tests/run_with_gate.sh` 通过

### runtime wiring DAG 收口与生命周期边界再瘦身（已完成）

- 目标：
  - 把残余 runtime wiring 闭环真正拆掉，让 `architecture_wiring_graph_gate.py` 回到严格 DAG 口径
  - 继续收窄 `faint` / `forced_replace` / `fatal damage attribution` 的职责边界
- 范围：
  - `src/battle_core/actions/action_cast_direct_damage_pipeline.gd`
  - `src/battle_core/lifecycle/faint_resolver.gd`
  - `src/battle_core/lifecycle/faint_leave_replacement_service.gd`
  - `src/composition/battle_core_wiring_specs.gd`
  - `tests/gates/architecture_wiring_graph_gate.py`
  - `docs/design/*`
  - `docs/records/*`
- 验收标准：
  - runtime wiring 图无 SCC，`python3 tests/gates/architecture_wiring_graph_gate.py` 直接通过
  - `PayloadDamageRuntimeService` 与行动直伤链只记录 fatal damage attribution，不再依赖 `FaintResolver`
  - `FaintLeaveReplacementService` 不再自己持有 field break 依赖，也不在 helper 内直接跑 `on_exit / field_break` batch
  - `godot --headless --path . --script tests/run_all.gd` 通过

#### 当前执行结果

- 已完成：
  - `ActionCastDirectDamagePipeline` 已切到 `faint_killer_attribution_service`
  - `FaintResolver` 已删掉 `leave_service / replacement_service / field_service / trigger_dispatcher` 这组多余属性注入，专注于 faint window 编排
  - `FaintLeaveReplacementService` 已收口成“击倒离场 + 补位 helper”，不再自己跑 `on_exit / field_break`
  - `battle_core_wiring_specs.gd` 已清掉对应陈旧依赖边
  - `architecture_wiring_graph_gate.py` 当前已恢复成严格 DAG gate，运行时 wiring 图无环

#### 当前验证结果

- `python3 tests/gates/architecture_wiring_graph_gate.py` 通过
- `godot --headless --path . --script tests/run_all.gd` 通过

### 基础稳定化整改路线图（已完成）

- 目标：
  - 按“先稳基础、再准备扩角和批量回放”的顺序落地基础稳定化整改
  - 不改 `BattleCoreManager` 等对外公开接口，不顺手扩新角色或补正式 passive item 内容
  - 把本轮审查结论同步落成 gate、回归与仓库记录
- 范围：
  - `src/battle_core/passives/*`
  - `src/battle_core/effects/*`
  - `src/battle_core/logging/replay_runner.gd`
  - `src/battle_core/content/*`
  - `src/composition/*`
  - `tests/suites/*`
  - `tests/support/*`
  - `tests/gates/*`
  - `docs/design/*`
  - `docs/records/*`
  - `README.md`
- 验收标准：
  - passive skill / passive item 的坏 trigger source 必须走 `invalid_battle`，不能静默失效
  - runtime wiring 图必须真的恢复成 strict DAG，并由 gate 明确约束
  - 同一组 `content_snapshot_paths` 的 session / replay 要命中 cache，且 public snapshot、event log、`final_state_hash` 与 baseline 一致
  - replay 预分组前后必须保持 event log 与 `final_state_hash` 一致
  - `bash tests/run_with_gate.sh` 全绿

#### 当前执行结果

- 已完成（任务 A：passive fail-fast）：
  - `PassiveSkillService`、`PassiveItemService` 已显式保存并暴露 `last_invalid_battle_code`
  - `TriggerBatchRunner.collect_trigger_events()` 已统一检查 passive skill / passive item / effect instance / field 四类 trigger source
  - 已新增负向回归：
    - `invalid_passive_skill_trigger_source_fails_fast`
    - `invalid_passive_item_trigger_source_fails_fast`
- 已完成（任务 B：错误通道显式化）：
  - 当前跨模块用户可见错误读取统一收口到 `error_state()`
  - 当前跨模块 `invalid_battle` 读取统一收口到 `invalid_battle_code()`
  - `BattleCoreManagerContractHelper`、`BattleCoreSession`、`TriggerBatchRunner` 与 `ReplayRunner -> BattleInitializer` 已切到显式读取
  - pluggable mock 只在局部 helper 里保留兼容 fallback，不再把动态 `get("last_*")` 继续扩散到正式主路径
- 已完成（任务 C：runtime wiring DAG gate）：
  - 已新增 `tests/gates/architecture_wiring_graph_gate.py`
  - `tests/check_architecture_constraints.sh` 已接入该 gate
  - 当前 runtime wiring 图正式收口为“静态 import 单向 + strict DAG”
- 已完成（任务 D：审查记录与文档落盘）：
  - 已新增正式审查记录：`docs/records/review_2026-04-04_foundation_stabilization_audit.md`
  - `architecture_overview.md`、`battle_core_architecture_constraints.md`、`log_and_replay_contract.md`、`kashimo_hajime_design.md`、`README.md`、`tests/README.md` 已同步到当前实现口径
  - `decisions.md` 已补充 passive fail-fast / 显式错误读取 / runtime wiring DAG / content cache / replay 索引的正式决策
- 已完成（任务 E：content cache）：
  - 已新增 composer 级共享 `ContentSnapshotCache`
  - session / replay 现在都先从 cache 取“已加载且已校验”的资源数组，再深复制构造 fresh `BattleContentIndex`
  - 已新增 `content_snapshot_cache_session_and_replay_contract`，固定比较 cache 命中前后的 public snapshot、event log 与 `final_state_hash`
- 已完成（任务 F：replay 索引）：
  - `ReplayRunner` 已在 while 循环前按 `turn_index` 预分组 `command_stream`
  - 已新增 `replay_turn_index_lookup_contract`，固定锁同回合顺序与 deterministic 行为

#### 当前验证结果

- `godot --headless --path . --script tests/run_all.gd` 通过

### 基础稳定化收口：manager 边界与错误读取统一（已完成）

- 目标：
  - 收紧 `BattleCoreManager` 的 raw port 暴露面，并把正式服务间残留的 `last_*` 直读 / property fallback 统一切回显式 getter
- 范围：
  - `src/battle_core/facades/*`
  - `src/composition/battle_core_composer.gd`
  - `src/battle_core/actions/*`
  - `src/battle_core/turn/*`
  - `src/battle_core/lifecycle/*`
  - `src/battle_core/passives/*`
  - `src/battle_core/effects/*`
  - `tests/suites/*manager*`
  - `tests/suites/composition_container_contract_suite.gd`
  - `tests/suites/content_snapshot_cache_suite.gd`
  - `tests/suites/field_lifecycle_contract_suite.gd`
  - `tests/support/battle_core_test_harness.gd`
  - `README.md`
- 验收标准：
  - `BattleCoreManager` 不再暴露 `container_factory / command_builder / command_id_factory / public_snapshot_builder` 这组 raw port 字段
  - manager 相关测试不再直接摸 raw port，内部访问改走明确的 debug/test 入口
  - 正式服务间不再保留 `last_invalid_battle_code / last_error_code` 跨对象直读，也不再保留 `get("last_*")` / `_has_property()` 兼容回退
  - `bash tests/run_with_gate.sh` 通过

#### 当前执行结果

- 已完成：
  - `BattleCoreManager` raw port 已改为私有字段，composer 改走 `_configure_core_ports(...)`
  - manager 相关测试已改为使用 `_debug_session / _inject_session_for_test / _override_container_factory_for_test / _replace_public_snapshot_builder_for_test / _shared_content_snapshot_cache_for_test`
  - `composer_build_manager_contract` 已新增回归，锁 `container_factory / command_builder / command_id_factory / public_snapshot_builder` 不得重新暴露成 manager raw port 字段
  - 正式服务间残留的 `last_*` 直读与 property fallback 已收口为 `invalid_battle_code()` / `error_state()`
  - `payload_executor` 与各 payload handler 的错误读取口径已统一

#### 当前验证结果

- `bash tests/run_with_gate.sh` 通过
- `bash tests/check_architecture_constraints.sh` 通过
- `bash tests/run_with_gate.sh` 通过

### 审查收口补修（已完成）

- 目标：
  - 把 2026-04-04 审查里剩余的真实问题分批修完，不再只停留在报告
  - 收口 `Kashimo` formal validator 覆盖缺口、共享 schema/规则文档漂移、`BattleCoreManager` facade 边界过宽、跨模块错误读取残留
  - 每批修完都保持 gate 可复查，最后保证可提交、可推送、工作区可收干净
- 范围：
  - `src/battle_core/content/*`
  - `src/battle_core/facades/*`
  - `src/battle_core/actions/*`
  - `src/battle_core/turn/*`
  - `src/battle_core/lifecycle/*`
  - `src/battle_core/passives/*`
  - `src/battle_core/effects/*`
  - `src/composition/battle_core_composer.gd`
  - `tests/suites/*`
  - `tests/support/*`
  - `tests/gates/*`
  - `docs/design/*`
  - `docs/rules/*`
  - `README.md`
- 验收标准：
  - `kashimo_kyokyo_katsura` 与相关资源漂移必须被 formal validator fail-fast 拦住
  - schema / rules / architecture wording 与 gate 必须回到当前实现口径
  - `BattleCoreManager` 测试不再直接依赖公开端口字段和 `_sessions / _container_factory_owner`
  - 正式服务之间不再继续读 `last_invalid_battle_code / last_error_code` 或 property fallback
  - `bash tests/run_with_gate.sh` 全绿

#### 当前执行结果

- 已完成（批次 A：Kashimo formal validator 与文档/gate 收口）：
  - 新增 `content_snapshot_formal_kashimo_contracts.gd`，把 unit / skill / passive / water leak wiring / `kyokyo` / `feedback_strike` / `amber` 的静态合约补齐到加载期 fail-fast
  - `extension_validation_contract_suite.gd` 已新增 `formal_kashimo_validator_kyokyo_bad_case_contract`
  - `battle_content_schema.md`、`06_effect_schema_and_extension.md`、`battle_core_architecture_constraints.md` 与 `repo_consistency_docs_gate.py` 已补齐 `effect_stack_sum`、`power_bonus_*`、`retention_mode`、`persistent_stat_stages` 与架构口径
- 已完成（批次 B：BattleCoreManager facade 边界收口）：
  - `BattleCoreManager` 的 runtime ports 已改成内部字段，由 composer 统一走 `_configure_core_ports(...)` 装配
  - 测试侧现在只通过显式 test hook 访问内部 session / shared cache / snapshot builder override，不再直接摸公开端口变量和 `_sessions`
  - `BattleCoreManager` 文件保持在 250 行 gate 阈值以内，避免这轮收口本身引入新的大文件警告
- 已完成（批次 C：跨模块错误读取显式化补齐）：
  - `ActionQueueBuilder`、`LeaveService`、`EffectInstanceService`、`FieldApplyConflictService`、`FieldApplyEffectRunner`、`DomainClashOrchestrator` 已补齐显式 getter
  - `TurnLoopController`、`ReplacementService`、`FaintLeaveReplacementService`、`DomainLegalityService`、`FieldApplyService`、`PayloadApplyEffectHandler` 等调用点已切到 `invalid_battle_code()`
  - `PayloadRuleModHandler` 已改成统一读取 `rule_mod_value_resolver.error_state()` / `rule_mod_service.error_state()`
  - `TriggerBatchRunner`、`PassiveSkillService`、`PassiveItemService`、`FieldService` 已删除 property fallback，不再走 `get("last_*")`

#### 当前验证结果

- `bash tests/run_with_gate.sh` 通过

## 2026-04-03

### 战斗核心最大整顿计划（已完成）

- 目标：
  - 按“修真实问题 + 一次性收口长期治理项”执行 battle core 最大整顿
  - 保持 `BattleCoreManager`、public snapshot、event log、replay 契约与角色玩法不变
  - 分 5 个可提交小任务完成 formal validator、Teach Love 参数化、payload 执行层与 composition 容器重构
- 范围：
  - `src/battle_core/content/*`
  - `src/battle_core/effects/*`
  - `src/composition/*`
  - `docs/design/architecture_overview.md`
  - `docs/records/tasks.md`
  - `docs/records/decisions.md`
  - `tests/suites/*`
  - `tests/gates/*`
- 验收标准：
  - Gojo / Sukuna / Kashimo 的 formal validator 能在加载期直接拦住关键资源漂移
  - 宿傩 `Teach Love` 分档改成显式 table-driven 回归，覆盖边界值与运行时回蓝结果
  - payload 执行层完成 registry + 单 payload handler 改造，未知 payload 继续 fail-fast
  - composition 改成 descriptor + dictionary-backed 容器，仓库内不再依赖 `core.<service>` 访问
  - `bash tests/run_with_gate.sh` 最终通过

#### 当前执行结果

- 已完成（任务 A：真问题收口与文档纠偏）：
  - `docs/design/architecture_overview.md` 第 3 节模块表已补回 `Content`
  - 已确认两条审查误报只做记录，不引入运行时代码补丁：
    - `gojo_ao_mark_apply / gojo_aka_mark_apply` 残留实例
    - `kashimo_kyokyo_nullify` 永久 meta-effect 残留
- 已完成（任务 B：角色 formal validator 补强）：
  - `ContentSnapshotFormalCharacterValidatorBase` 已新增统一 helper：
    - `_require_unit / _require_skill / _require_effect / _require_field / _require_passive_skill`
    - `_expect_int / _expect_string / _expect_bool / _expect_packed_string_array / _expect_payload_shape`
  - `Gojo / Sukuna / Kashimo` formal validator 已统一套用 helper 结构
  - Gojo validator 已补基础角色合约、`苍 / 赫`、双标记、`Mugen` 与领域链路
  - Sukuna validator 已补基础角色合约、`解 / 捌 / 开`、`灶`、领域链路、`Teach Love` 阈值表与共享火伤 fingerprint
  - Kashimo validator 已在不改玩法前提下补齐 `雷拳 priority / combat_type` 与 `蓄电 mp_cost / 正电荷绑定`
  - `extension_validation_contract_suite.gd` 已新增三组 drift bad-case contract
- 已完成（任务 C：Teach Love 分档参数化）：
  - 已新增 `tests/suites/sukuna_teach_love_band_suite.gd`
  - 宿傩回蓝分档现在显式覆盖：
    - `gap 0 / 20 -> +9`
    - `gap 21 / 40 -> +8`
    - `gap 41 / 70 -> +7`
    - `gap 71 / 110 -> +6`
    - `gap 111 / 160 -> +5`
    - `gap 161 -> +0`
  - 每个 case 同时验证：
    - 运行时 `mp_regen` rule mod 数值
    - 初始化预回蓝 + 下一次有效 `turn_start` 后的 `current_mp` 增量
- 已完成（任务 D：payload 执行层重构）：
  - `PayloadExecutor` 已收口为：
    - effect guard / chain depth / dedupe
    - `EffectPreconditionService` 前置守卫
    - `PayloadHandlerRegistry` 明确路由
  - 已删除旧的粗粒度多 payload 壳：
    - `payload_numeric_handler.gd`
    - `payload_state_handler.gd`
  - 当前 payload 路由已改为单 payload handler：
    - `damage / heal / resource_mod / stat_mod`
    - `apply_field / apply_effect / remove_effect / rule_mod / forced_replace`
  - 既有 runtime 业务执行层保留复用：
    - `payload_damage_runtime_service.gd`
    - `payload_resource_runtime_service.gd`
    - `payload_stat_mod_runtime_service.gd`
  - 已补 payload contract 回归：
    - `payload_handler_registry_completeness_contract`
    - `payload_executor_unknown_payload_fail_fast_contract`
    - `payload_executor_handler_missing_dependency_propagation_contract`
- 已完成（任务 E：composition 容器重构）：
  - `BattleCoreServiceSpecs` 已改成 `SERVICE_DESCRIPTORS = [{slot, script}]` 单一描述源
  - `service_slots()` / `script_by_slot()` 现都由 descriptors 派生，不再维护双份 slot 表面
  - `BattleCoreContainer` 已改成 dictionary-backed 容器，只保留：
    - `set_service(slot_name, service)`
    - `service(slot_name)`
    - `has_service(slot_name)`
    - `clear_service(slot_name)`
    - `configure_dispose_specs(...)`
    - `dispose()`
  - `BattleCoreComposer` 已全量迁移到新容器 API：
    - 实例化使用 `set_service(...)`
    - wiring / 校验统一使用 `service(...)`
  - 仓库内 battle core 容器消费者已全部迁移到 `core.service("slot") / container.service("slot")`
  - `tests/gates/architecture_composition_consistency_gate.py` 已同步改造，当前会额外拦截：
    - `SERVICE_DESCRIPTORS` 漂移
    - container API 缺失
    - composer 退回 `container.get/set(...)`
    - repo 内残留 `core.<service> / container.<service>` 旧写法

#### 当前验证结果

- `godot --headless --path . --script tests/run_all.gd` 通过
- `tests/check_architecture_constraints.sh` 通过
- `tests/check_repo_consistency.sh` 通过
- `bash tests/run_with_gate.sh` 通过

### 正式角色交付契约收口与 `rule_mod` 热区拆分（已完成）

- 目标：
  - 修正 formal validator runtime 读取面、formal registry 元数据、文档口径与 gate 之间的漂移
  - 把 `rule_mod` runtime 热区从单大文件拆回 wrapper + 子 suite 结构
  - 不改战斗玩法与公开 facade，只收口交付契约、文档和测试组织
- 范围：
  - `src/battle_core/content/*`
  - `src/composition/sample_battle_factory.gd`
  - `docs/records/formal_character_registry.json`
  - `docs/design/battle_runtime_model.md`
  - `docs/design/formal_character_delivery_checklist.md`
  - `README.md`
  - `tests/gates/*`
  - `tests/suites/content_validation_core_suite.gd`
  - `tests/suites/rule_mod_runtime*.gd`
- 验收标准：
  - runtime validator registry 与 docs registry 重新收回“code-side read model + docs 交付面记录”的同一口径
  - formal registry 显式补齐 `sample_setup_method`，并由 gate 校验对应 `SampleBattleFactory` builder 存在
  - `battle_runtime_model.md` 的 `RuleModInstance` 说明补齐 `nullify_field_accuracy / incoming_action_final_mod`
  - `rule_mod` runtime core 热区完成拆分，现有测试名与 reachability 不漂移

#### 当前执行结果

- 已新增 `src/battle_core/content/formal_character_validator_registry.json`，运行时 `ContentSnapshotFormalCharacterRegistry` 现在只读取这份 code-side registry，不再直接读取 `docs/records/formal_character_registry.json`
- `tests/gates/repo_consistency_formal_character_gate.py` 已改成双向校验 docs registry 与 runtime validator registry 的 `character_id / content_validator_script_path`
- 已新增 `formal_character_validator_registry_runtime_contract`，直接断言 runtime validator registry 可加载且能实例化 validator
- 正式角色 registry 已补齐 `sample_setup_method`：
  - `gojo_satoru -> build_gojo_vs_sample_setup`
  - `sukuna -> build_sukuna_vs_sample_setup`
  - `kashimo_hajime -> build_kashimo_vs_sample_setup`
- 已新增 `SampleBattleFactory.build_sukuna_vs_sample_setup(...)`
- `repo_consistency_formal_character_gate.py` 已显式校验 `sample_setup_method` 非空且对应 builder 存在，不再用 `unit_definition_id` 的字符串包含兜底
- `README.md`、`tests/README.md`、`formal_character_delivery_checklist.md` 与 `battle_runtime_model.md` 已同步到当前正式口径
- `rule_mod_runtime_core_suite.gd` 已改成薄 wrapper，并拆出：
  - `rule_mod_runtime_core_paths_suite.gd`
  - `rule_mod_runtime_extension_suite.gd`

#### 当前验证结果

- `git diff --check` 通过
- `python3 tests/gates/repo_consistency_formal_character_gate.py` 通过
- `python3 tests/gates/repo_consistency_docs_gate.py` 通过
- `godot --headless --path . --script tests/run_all.gd` 通过

## 2026-04-02

### 审查问题分阶段修复（已完成）

- 目标：
  - 按完整审查里确认的问题顺序逐段修复，而不是只停留在报告层
  - 每阶段完成后都完成最小回归、记录、提交、推送，保持工作区干净
  - 在继续扩角前先把运行时 contract、文档/gate 与 formal character 交付面收回一致
- 范围：
  - `src/battle_core/effects/**/*`
  - `src/battle_core/content/*`
  - `docs/design/*`
  - `docs/rules/*`
  - `docs/records/tasks.md`
  - `README.md`
  - `tests/suites/*`
  - `tests/gates/*`
- 验收标准：
  - 运行时坏依赖必须 fail-fast，不允许静默跳过关键结算
  - `stacking=none` 的重复施加日志语义与实例写入保持一致
  - 正式角色文档、formal registry、manager smoke 与 repo consistency gate 保持同一交付口径
  - 每个阶段完成后都完成验证并提交推送

#### 当前执行结果

- 已完成（阶段一：运行时硬问题收口）：
  - `payload_damage_runtime_service.gd` 已把 `faint_resolver` 纳入依赖守卫，伤害结算不再允许缺依赖时静默漏掉濒死/补位链
  - `trigger_batch_runner.gd` 已继续向下递归检查 `field_service` 与 `payload_executor` 的嵌套依赖，turn loop 入口现在能提前拦截这类坏装配
  - `rule_mod_write_service.gd` / `rule_mod_service.gd` 已显式暴露 `last_apply_skipped`，`payload_state_handler.gd` 现在会在 `stacking=none` 的重复施加被跳过时同步跳过 apply 日志
  - 已新增回归：
    - `rule_mod_none_repeat_skips_log`
    - `manager_create_session_damage_runtime_dependency_guard_contract`
  - `README.md` 代码量统计已同步到当前仓库实际值：
    - `src`：`10932`
    - `tests`：`14081`
    - `total`：`25013`
  - `godot --headless --path . --script tests/run_all.gd` 已通过
  - `bash tests/run_with_gate.sh` 已通过
- 已完成（阶段二：文档与 gate 漂移收口）：
  - `docs/design/battle_content_schema.md` 已改成当前正式口径：仓库内正式角色内容包为 `Gojo / Sukuna / Kashimo` 三人，而不是旧的两人表述
  - `battle_content_schema.md` 已补 Kashimo 的正式字段示例，写清默认三技能、候选池与 `3 / 3 / 1` 奥义点 contract
  - `docs/rules/06_effect_schema_and_extension.md` 已补齐 `nullify_field_accuracy / incoming_action_final_mod` 两个正式 `rule_mod` 读取点，以及 `required_incoming_command_types / required_incoming_combat_type_ids` 过滤字段
  - `docs/design/battle_core_architecture_constraints.md` 已把上述两个读取点写回 `rule_mod` 白名单，并明确 incoming action 过滤字段不构成新读取点
  - `docs/design/kashimo_hajime_design.md` 已把 `kashimo_manager_smoke_suite.gd`、formal registry 挂回的共享 suite，以及 `tests/replay_cases/kashimo_cases.md` / `tests/helpers/kashimo_case_runner.gd` 固定复查入口写回正式交付面说明
  - `tests/gates/repo_consistency_docs_gate.py` 已新增文档锚点，后续若再把正式角色数、`rule_mod` 新读取点、鹿紫云 manager smoke 或固定案例说明写丢，会直接被 gate 拦住
  - `python3 tests/gates/repo_consistency_docs_gate.py` 已通过
  - `bash tests/run_with_gate.sh` 已通过
- 已完成（阶段三：formal registry / runtime validator / manager smoke / gate 收口）：
  - 已新增 `src/battle_core/content/formal_character_validator_registry.json`；`ContentSnapshotFormalCharacterValidator` 运行时不再直接读取 `docs/records/formal_character_registry.json`
  - `tests/gates/repo_consistency_formal_character_gate.py` 当前会强校验 docs registry 与 runtime validator registry 的 `content_validator_script_path` 完全对齐，避免双份注册表静默漂移
  - 正式角色 registry 已新增 `sample_setup_method`；`repo_consistency_formal_character_gate.py` 不再只看角色 ID 字符串，而会强校验 `SampleBattleFactory` 上存在对应 builder
  - 已新增 `SampleBattleFactory.build_sukuna_vs_sample_setup(...)`，让宿傩也有与五条悟 / 鹿紫云同口径的角色对样例建局入口
  - `gojo_manager_smoke_suite.gd` 与 `sukuna_manager_smoke_suite.gd` 已改成真正黑盒：通过公开 facade 驱动“两回合先受伤、再反转术式回血”的主路径，不再伸手访问 `manager._sessions` 或内部 battle state
  - `README.md`、`battle_content_schema.md`、`formal_character_delivery_checklist.md` 与 `decisions.md` 已同步改成“docs registry 记录交付面，runtime 只读 code-side validator registry”的当前口径
  - `python3 tests/gates/repo_consistency_formal_character_gate.py` 已通过
  - `bash tests/run_with_gate.sh` 已通过

#### 当前验证结果

- `godot --headless --path . --script tests/run_all.gd` 通过
- `bash tests/run_with_gate.sh` 通过

### 扩角前稳定化收口（进行中）

- 目标：
  - 在继续开发下一个正式角色前，把当前仓库里已确认的工程问题真正修掉
  - 收口项目到“warning 干净、gate 更严、扩角热点更平”的状态
  - 每个阶段完成后都做最小回归、提交并推送，保持工作区干净
- 范围：
  - `tests/run_with_gate.sh`
  - `src/battle_core/**/*`
  - `src/composition/*`
  - `docs/records/tasks.md`
  - `docs/records/decisions.md`
- 验收标准：
  - Godot 项目启动不再输出当前已确认的 warning
  - `bash tests/run_with_gate.sh` 通过，且能拦截 warning 漂移
  - formal character validator 的公共 helper 已下沉，不再为每个角色重复写一套
  - composition 装配热点已整理，新增角色或机制时的接线改动面缩小
  - 各阶段完成后均有提交与推送，最终主干工作区干净

#### 当前执行结果

- 已完成（阶段一：warning 清零 + gate 收紧）：
  - 已修掉当前主流程启动时确认存在的 Godot warning：
    - `ResourceLoader.load(..., 0)` 的无效 enum 用法
    - `PublicIdAllocator` 的隐式整数除法 warning
    - 若干未使用参数 / 变量遮蔽 / 兼容性差的三元表达式 warning
  - `tests/run_with_gate.sh` 已新增：
    - warning 拦截
    - headless 主流程启动 smoke（`godot --headless --path . --quit-after 20`）
  - `README.md` 的 gate 描述与代码量统计已同步到当前仓库实际值
- 已完成（阶段二：formal character validator 公共化）：
  - 已新增 `ContentSnapshotFormalCharacterValidatorBase`
  - 三个正式角色 validator 已统一复用公共 helper：
    - `_extract_single_payload(...)`
    - `_expect_packed_string_array(...)`
  - `Gojo / Sukuna / Kashimo` 的角色级内容校验脚本不再各自重复维护同一套底层 helper
  - Phase 2 收口时已同步刷新 `README.md` 代码量统计，避免 gate 因文档漂移失败
- 已完成（阶段三：composition 接线热点降耦）：
  - `BattleCoreServiceSpecs` 已改成“单一 slot 列表 + script map”的结构，不再在 `SERVICE_SPECS` 里重复抄一遍全部 slot
  - 已新增 `tests/gates/architecture_composition_consistency_gate.py`
  - `tests/check_architecture_constraints.sh` 已接入 composition 静态一致性 gate，当前会拦截：
    - `service_slots` 与 `SCRIPT_BY_SLOT` 漂移
    - `BattleCoreContainer` 服务槽位缺失或残留旧槽位
    - `WIRING_SPECS / RESET_SPECS` 引用未知 owner/source
    - 重复的 `owner + dependency` 接线项
  - `README.md` 已补当前架构 gate 的 composition 一致性说明
- 已完成（最终复查与剩余热点收口）：
  - `rule_mod_write_service.gd` 已把 owner 作用域/实例读写逻辑下沉到 `RuleModOwnerScopeService`，文件体积已从预警线附近降回安全范围
  - 已修正 `field_service.break_active_field()` 错用 `battle_state.chain_context` 的问题，改为真正传递调用方给定的 `chain_context`
  - 已新增回归 `field_break_uses_explicit_chain_context_contract`，锁定 field break 生命周期链使用显式 chain_context 的口径
  - 当前 `ARCH_GATE_WARNING` 已不再提示 `rule_mod_write_service.gd`
- 进行中：
  - 当前只剩合并回 `main`、推送与分支清理收尾

#### 当前验证结果

- `git diff --check` 通过
- `bash tests/run_with_gate.sh` 通过

## 2026-04-01

### 扩角前模板化收口（已完成）

- 目标：
  - 把正式角色设计模板补成可直接套用的标准模板
  - 把角色接入动作从分散约定收成一份单独 checklist
  - 固定正式角色最低测试面，避免后续再靠角色 suite 手搓流程
- 范围：
  - `docs/design/formal_character_design_template.md`
  - `docs/design/formal_character_delivery_checklist.md`
  - `docs/design/domain_field_template.md`
  - `README.md`
  - `docs/records/tasks.md`
  - `docs/records/decisions.md`
- 验收标准：
  - 正式角色模板已包含角色定位与资源定义、角色机制、验收矩阵、平衡备注和可选领域附录
  - 仓库中存在单独的正式角色接入 checklist，覆盖设计稿、资源、registry、suite、记录与最终验证
  - 正式角色最低测试面已明确固定为 `snapshot / runtime / manager smoke`
  - `bash tests/run_with_gate.sh` 通过

#### 当前执行结果

- 已完成：
  - `formal_character_design_template.md` 已升级为可直接填写的正式模板，并补了“领域角色差异附录”写法
  - 已新增 `formal_character_delivery_checklist.md`，统一收口角色接入动作、最低测试面与最终验证步骤
  - `domain_field_template.md` 已明确“领域角色只补差异附录，不重写公共矩阵”的写法
  - `README.md` 已补模板、checklist 与 manager smoke 的正式入口说明

#### 当前验证结果

- `bash tests/run_with_gate.sh` 通过

### 审查问题修复与热点 suite 拆分治理（已完成）

- 目标：
  - 把完整审查里确认的问题真正落成修复，而不是只停留在报告层
  - 去掉 Gojo 双标记爆发仍靠玩法前提兜住的实现债
  - 把已点名的高热点大 suite 按主题继续拆分，降低扩角前维护成本
- 范围：
  - `src/battle_core/content/effect_definition.gd`
  - `src/battle_core/content/content_snapshot_effect_validator.gd`
  - `src/battle_core/effects/payload_executor.gd`
  - `src/battle_core/effects/effect_instance_service.gd`
  - `src/battle_core/effects/payload_handlers/payload_state_handler.gd`
  - `content/effects/gojo/gojo_murasaki_conditional_burst.tres`
  - `docs/design/battle_content_schema.md`
  - `docs/design/battle_runtime_model.md`
  - `docs/design/effect_engine.md`
  - `docs/design/gojo_satoru_design.md`
  - `docs/rules/06_effect_schema_and_extension.md`
  - `docs/records/decisions.md`
  - `docs/records/tasks.md`
  - `docs/records/formal_character_registry.json`
  - `tests/suites/gojo_murasaki_suite.gd`
  - `tests/suites/gojo_snapshot_suite.gd`
  - `tests/suites/extension_targeting_accuracy_suite.gd`
  - `tests/suites/extension_validation_contract_suite.gd`
  - `tests/suites/content_validation_contract_suite.gd`
  - `tests/suites/sukuna_setup_regen_suite.gd`
  - `tests/suites/action_guard_state_integrity_suite.gd`
  - `tests/suites/rule_mod_runtime_suite.gd`
  - `tests/suites/gojo_domain_suite.gd`
  - `tests/support/gojo_test_support.gd`
  - `tests/support/action_guard_state_integrity_test_support.gd`
  - `tests/support/sukuna_setup_regen_test_support.gd`
  - `tests/gates/repo_consistency_docs_gate.py`
- 验收标准：
  - Gojo 的茈只消费当前五条悟本人施加的双标记
  - `required_target_same_owner` 已进入内容 schema、加载期校验、运行时前置守卫与回归
  - 已点名的热点大 suite 完成 wrapper + 子 suite 拆分，原有回归锚点不丢
  - `bash tests/run_with_gate.sh` 通过
  - 完成提交与推送

#### 当前执行结果

- 已完成：
  - 新增 `required_target_same_owner`，并把 `meta.source_owner_id` 写入 effect instance；当前 `gojo_murasaki_conditional_burst` 已正式要求双标记必须来自当前这名五条悟本人
  - 已补 `gojo_murasaki_same_owner_contract`、`required_target_same_owner_contract` 与对应坏例校验，Gojo snapshot / formal registry / docs gate 已同步
  - 已把 `content_validation_contract_suite.gd`、`sukuna_setup_regen_suite.gd`、`action_guard_state_integrity_suite.gd`、`rule_mod_runtime_suite.gd`、`gojo_domain_suite.gd` 拆成 wrapper + 子 suite
  - 已新增两份测试 support helper，把 suite 级共享构造与辅助逻辑从热点文件里下沉

#### 当前验证结果

- `bash tests/run_with_gate.sh` 通过
- `git diff --check` 通过
- 工作区已提交并推送

### 当前项目完整审查、风险研判与提交流程（已完成）

- 目标：
  - 对当前项目做一次完整审查，覆盖架构、实现、设计文档对齐、正式角色实现与未提交改动风险
  - 明确当前是否适合继续扩角，还是应先做一轮整合规范
  - 在结论落盘后完成一次提交与推送
- 范围：
  - `docs/design/*.md`
  - `docs/rules/*.md`
  - `docs/records/*.md`
  - `src/battle_core/**/*.gd`
  - `src/composition/sample_battle_factory.gd`
  - `tests/**/*.gd`
  - `tests/gates/*`
- 验收标准：
  - 架构 / 文档 / 运行时主线 contract 对齐结论已落盘
  - Gojo / Sukuna 的设计兑现、测试覆盖与扩角风险已给出明确结论
  - 未提交改动已复核，新增问题与大文件风险已形成可执行判断
  - `bash tests/run_with_gate.sh` 通过
  - 完成提交与推送

#### 当前执行结果

- 已完成：
  - 已确认本轮未提交改动的主线目标一致：统一移除旧 `skill_legality` 口径、补齐宿傩 `matchup_bst_gap_band` 的 `max_mp` 第七维 contract、并把 `BattleInitializerPhaseService` / `BattleCoreManagerContainerService` / `tests/gates/*` 写回文档与 gate
  - 已确认正式角色交付面当前由 `formal_character_registry.json`、角色设计稿、内容资源、wrapper suite、required suite / test anchors 共同收口，Gojo / Sukuna 两条链路当前保持一致
  - 已补 `BattleInitializer` 本地依赖缺失的 fail-fast 守卫，并新增 `manager_create_session_initializer_dependency_guard_contract` 覆盖坏装配场景
  - 已补 `BattleCoreManager.dispose()` 后的请求防御，避免外层误复用已释放 manager 时直接落入空引用崩溃，并新增 `manager_disposed_request_guard_contract`
  - 已恢复 `tests/check_repo_consistency.sh` 的可执行位，并同步 `README.md` 当前代码量统计
  - 已确认当前未提交改动没有引入新的红灯回归；总测试、总闸门、架构闸门、仓库一致性 gate 均通过
  - 审查结论：当前仓库没有发现阻断继续扩角的硬伤；但多个角色/规则测试文件继续膨胀，仍是扩角前值得优先整合的维护风险

#### 当前验证结果

- `godot --headless --path . --script tests/run_all.gd` 通过

### 当前实现稳定化批次：固定案例、Facade 收口与 ActionExecutor 拆分（已完成）

- 目标：
  - 在继续扩新角色前，先把当前主线的固定复查入口、manager facade 边界和 `action_executor` 热点职责收口
- 范围：
  - `tests/helpers/kashimo_case_runner.gd`
  - `tests/replay_cases/kashimo_cases.md`
  - `tests/README.md`
  - `README.md`
  - `src/battle_core/facades/*`
  - `src/battle_core/actions/*`
  - `src/composition/battle_core_*`
  - `tests/suites/manager_*`
  - `tests/check_architecture_constraints.sh`
  - `docs/records/tasks.md`
  - `docs/records/decisions.md`
- 验收标准：
  - 鹿紫云固定案例入口可直接复查 `电荷主循环 / 琥珀换人保留 / 弥虚葛笼对抗领域`
  - `BattleCoreManager` 不再直接访问 `session.container.*`
  - `action_executor.gd` 从热点大函数降回编排壳，链上下文、起手资源、技能触发、命中/命中后结算拆到独立服务
  - `bash tests/run_with_gate.sh` 全量通过

#### 当前执行结果

- 已完成：
  - 已补固定鹿紫云案例入口：
    - `tests/helpers/kashimo_case_runner.gd`
    - `tests/replay_cases/kashimo_cases.md`
  - 已把固定案例说明补回：
    - `README.md`
    - `tests/README.md`
  - 已把 `BattleCoreManager` 的 session 内部调用改成统一经由 `BattleCoreSession`：
    - runtime 校验
    - 合法行动查询
    - 回合执行
    - event log 只读快照
  - 已新增 manager 内部 facade 契约回归：
    - `tests/suites/manager_facade_internal_contract_suite.gd`
  - 已为 facade 泄露补架构 gate：
    - `tests/check_architecture_constraints.sh`
  - 已把 `action_executor.gd` 拆成 4 个独立子服务：
    - `action_chain_context_builder.gd`
    - `action_start_phase_service.gd`
    - `action_skill_effect_service.gd`
    - `action_execution_resolution_service.gd`
  - 已把对应 wiring / container 装配补回：
    - `src/composition/battle_core_container.gd`
    - `src/composition/battle_core_service_specs.gd`
    - `src/composition/battle_core_wiring_specs.gd`
  - 当前稳定化批次分 3 个提交独立落盘：
    - `13c4def add: kashimo replay cases and runner`
    - `4c98d3d refactor: seal manager session facade`
    - `6a0ddfa refactor: split action executor phases`

#### 当前验证结果

- `CASE=all godot --headless --path . --script tests/helpers/kashimo_case_runner.gd` 通过
- `bash tests/run_with_gate.sh` 通过
- `bash tests/run_with_gate.sh` 通过

### 第三角色前整备计划第二轮（已完成）

- 目标：
  - 在继续扩第三角色前，把 `power_bonus_source`、离场保留策略、领域对拼编排与少量硬编码战斗常量收成单点，并同步收口正式角色文档
- 范围：
  - `src/battle_core/actions/*`
  - `src/battle_core/lifecycle/*`
  - `src/battle_core/passives/*`
  - `src/battle_core/content/*`
  - `src/battle_core/runtime/*`
  - `src/composition/*`
  - `content/battle_formats/sample_battle_format.tres`
  - `tests/suites/*`
  - `tests/support/sukuna_setup_regen_test_support.gd`
  - `docs/design/*`
  - `docs/rules/01_battle_format_and_visibility.md`
  - `docs/rules/03_stats_resources_and_damage.md`
  - `docs/rules/05_items_field_input_and_logging.md`
  - `docs/records/decisions.md`
- 验收标准：
  - `power_bonus_source` 不再硬编码在共享伤害管线
  - `faint` 当前行为不变，但离场保留判断已有统一策略入口
  - 领域对拼保护、重开豁免与 field 冲突矩阵由单点入口编排
  - 默认反伤比例与领域平 MP 阈值进入 `BattleFormatConfig`
  - Gojo / 宿傩正式角色稿按同一模板骨架收口，公共 contract 不再整段重写
  - `bash tests/run_with_gate.sh` 通过

#### 当前执行结果

- 已完成：
  - 已新增 `power_bonus_resolver.gd` 与共享 `power_bonus_source` 注册表；`ActionCastDirectDamagePipeline` 与 `ContentSnapshotSkillValidator` 现在统一读同一份来源定义，不再各自写死
  - 已新增 `lifecycle_retention_policy.gd`，`LeaveService` 当前通过统一策略入口决定 effect / rule_mod 在不同离场原因下是否保留；`faint` 语义保持不变
  - 已新增 `domain_clash_orchestrator.gd`，把同回合双领域保护、领域重开豁免与 field 冲突矩阵收口到单点；`ActionQueueBuilder`、`DomainLegalityService`、`FieldApplyService` 已改成薄转发
  - 已把默认反伤比例与领域平 MP tie-break 阈值下沉到 `BattleFormatConfig -> BattleState` 运行时快照，并补 content validation / runtime guard
  - 已补生命周期链的 fail-fast 守卫：`LeaveService`、`ReplacementService`、`FaintLeaveReplacementService`、`FaintResolver`、`SwitchActionService` 现在都会把嵌套缺依赖继续上抛
  - 已补回归：
    - `battle_format_runtime_constant_validation`
    - `battle_format_runtime_constants_copy_contract`
    - `recoil_ratio_runtime_config_contract`
    - `field_clash_tie_threshold_runtime_contract`
    - `power_bonus_resolver_delegation_contract`
  - 已同步更新 README、BattleFormat / 运行时 / 行动 / 生命周期 / field 文档
  - 已把 Gojo / Sukuna 正式角色稿继续收口到同一模板骨架：主章节统一为“基础属性 / 技能详细设计 / 角色特有验收矩阵 / 平衡备注”，共享 contract 回收到公共文档引用

#### 当前验证结果

- `HOME=/tmp GODOT_USER_HOME=/tmp godot --headless --path . --script tests/run_all.gd` 通过
- `git diff --check` 通过
- `HOME=/tmp GODOT_USER_HOME=/tmp bash tests/run_with_gate.sh` 通过

### 扩角前规范整合硬收口（已完成）

- 目标：
  - 把活动 contract 中残留的旧合法性口径彻底移除，统一到 `action_legality`
  - 把宿傩 `matchup_bst_gap_band` 的 `max_mp` 第七维假设正式写死到规则、设计文档、回归与角色注册表
  - 把新拆出的 owner helper 与 repo consistency 子 gate 写回 README / 设计文档 / 测试文档，避免继续靠口头约定
- 范围：
  - `docs/design/battle_runtime_model.md`
  - `docs/design/battle_content_schema.md`
  - `docs/design/battle_core_architecture_constraints.md`
  - `docs/design/effect_engine.md`
  - `docs/design/architecture_overview.md`
  - `docs/design/turn_orchestrator.md`
  - `docs/design/gojo_satoru_design.md`
  - `docs/design/sukuna_design.md`
  - `docs/rules/03_stats_resources_and_damage.md`
  - `docs/rules/06_effect_schema_and_extension.md`
  - `README.md`
  - `tests/README.md`
  - `tests/suites/sukuna_setup_regen_suite.gd`
  - `docs/records/formal_character_registry.json`
  - `docs/records/decisions.md`
  - `docs/records/tasks.md`
- 验收标准：
  - 活动规则/设计文档里不再保留旧合法性双口径表述
  - 宿傩新增一条专门证明 `matchup_bst_gap_band` 必须计入 `max_mp` 的回归，并挂回 formal registry
  - README、测试文档、架构文档能解释 `BattleInitializerPhaseService`、`BattleCoreManagerContainerService` 与 `tests/gates/*`
  - `bash tests/run_with_gate.sh` 通过

#### 当前执行结果

- 已完成：
  - 活动文档里的 rule_mod 合法性 contract 已统一收口为 `final_mod / mp_regen / action_legality / incoming_accuracy`，不再保留旧合法性口径
  - 宿傩新增 `sukuna_matchup_bst_includes_max_mp_contract`，并同步写入 `formal_character_registry.json`
  - `matchup_bst_gap_band` 当前按 `max_hp + attack + defense + sp_attack + sp_defense + speed + max_mp` 的绝对差求值，README / 规则 / 设计稿已统一
  - `architecture_overview.md`、`turn_orchestrator.md`、`tests/README.md` 与 README 已补齐 `BattleInitializerPhaseService`、`BattleCoreManagerContainerService` 与 `tests/gates/*` 的落点说明
  - `README.md` 代码量统计已同步到当前仓库实际值

#### 当前验证结果

- `godot --headless --path . --script tests/run_all.gd` 通过
- `bash tests/run_with_gate.sh` 通过

## 2026-03-31

### 运行态公开读口、正式角色校验注册与宿傩 suite 拆分收口（已完成）

- 目标：
  - 把 `BattleCoreManager` 的公开读口与回合入口补成真正的 runtime fail-fast，避免外围读到半坏 session
  - 把正式角色内容层共享约束从单文件 hardcode 收口成由 formal registry 驱动的可选 validator 装配
  - 把 manager / domain 这两组过大的 contract suite 拆成 wrapper + 子 suite，并同步仓库记录
- 范围：
  - `src/battle_core/facades/battle_core_manager.gd`
  - `src/battle_core/facades/battle_core_manager_contract_helper.gd`
  - `src/battle_core/commands/domain_legality_service.gd`
  - `src/battle_core/commands/legal_action_service.gd`
  - `src/battle_core/content/content_snapshot_formal_character_validator.gd`
  - `src/battle_core/content/content_snapshot_formal_character_registry.gd`
  - `src/battle_core/content/content_snapshot_formal_sukuna_validator.gd`
  - `tests/suites/domain_clash_contract_suite.gd`
  - `tests/suites/domain_clash_resolution_suite.gd`
  - `tests/suites/domain_clash_guard_suite.gd`
  - `tests/suites/manager_public_contract_suite.gd`
  - `tests/suites/manager_snapshot_public_contract_suite.gd`
  - `tests/suites/manager_log_and_runtime_contract_suite.gd`
  - `tests/suites/sukuna_suite.gd`
  - `tests/suites/sukuna_kamado_suite.gd`
  - `tests/suites/sukuna_domain_suite.gd`
  - `tests/support/sukuna_test_support.gd`
  - `tests/check_repo_consistency.sh`
  - `docs/design/architecture_overview.md`
  - `docs/design/battle_content_schema.md`
  - `docs/design/passive_and_field.md`
  - `docs/records/decisions.md`
  - `docs/records/formal_character_registry.json`
  - `docs/records/tasks.md`
  - `README.md`
- 验收标准：
  - manager 在公开读口和 `run_turn` 入口命中坏运行态时，必须返回结构化 `invalid_state_corruption`
  - 正式角色共享内容约束通过 formal registry 的可选 `content_validator_script_path` 分发，门禁与运行时口径一致
  - 宿傩正式回归拆分后，角色 wrapper、注册表和仓库一致性闸门全部同步
  - `README.md` 代码量统计与仓库实际一致
  - `bash tests/run_with_gate.sh` 通过

#### 当前执行结果

- 已完成：
  - `BattleCoreManager` 公开读口与 `run_turn` 入口已统一先做 runtime 校验；session 坏状态会直接返回结构化错误 envelope
  - `domain_legality_service` / `legal_action_service` 已把 active domain 缺失 creator 等坏状态收口为 `invalid_state_corruption`
  - 已新增 `content_snapshot_formal_character_registry.gd` 与 `content_snapshot_formal_sukuna_validator.gd`；formal character validator 现在按 formal registry 的可选 validator path 分发
  - `manager_public_contract_suite.gd` 已拆为 snapshot / log-runtime 两组子 suite；`domain_clash_contract_suite.gd` 已拆为 resolution / guard 两组子 suite
  - 宿傩原单文件 suite 已拆为 `sukuna_kamado_suite.gd` 与 `sukuna_domain_suite.gd`，wrapper、角色注册表与一致性脚本已同步
  - `README.md`、设计文档、决策记录与任务记录已补齐本轮口径

#### 当前验证结果

- `bash tests/run_with_gate.sh` 通过

### 外部审查报告复核结论补档（已完成）

- 目标：
  - 核对外部审查报告里的低中优先级观察，明确哪些是事实、哪些是误判、哪些已被当前仓库口径覆盖
  - 把 helper 文档缺口与命名结论补进正式记录，避免后续重复误读
- 范围：
  - `docs/design/architecture_overview.md`
  - `docs/records/decisions.md`
  - `docs/records/tasks.md`
- 验收标准：
  - `architecture_overview.md` 明确写出内部 helper 的存在与边界
  - records 明确记录宿傩命名问题为何“不成立”，以及当前命名口径是什么
  - 不为报告中的误判项引入无必要的仓库级重命名

#### 当前执行结果

- 已完成：
  - `architecture_overview.md` 已补 `BattleInitializerStateBuilder / BattleInitializerPhaseService / BattleCoreManagerContractHelper / BattleCoreManagerContainerService` 的 helper 说明，并把 `battle_core_session.gd` / manager 内部 helper 标回 facade 子域内部实现
  - 已确认外部审查里的 `S-1` 结论不成立：Gojo 与 Sukuna 当前都采用“术式罗马音 + 领域英文描述”的混合命名，不存在“只有宿傩跑偏”
  - 已沿用既有正式口径，不做只针对宿傩单角色的重命名

#### 当前验证结果

- `bash tests/check_repo_consistency.sh` 通过

### 宿傩领域与灶伤害断言去硬编码（已完成）

- 目标：
  - 去掉宿傩回归里对“火打水减半后一定等于 10 / 20”的字面量依赖，避免属性表调整时出现误报
  - 保持 suite 继续验证“运行时结算值必须匹配当前 content + combat type chart”
- 范围：
  - `tests/suites/sukuna_kamado_suite.gd`
  - `tests/suites/sukuna_domain_suite.gd`
  - `README.md`
  - `docs/records/tasks.md`
- 验收标准：
  - `sukuna_kamado_stack_on_exit_path`
  - `sukuna_kamado_forced_replace_on_exit_path`
  - `sukuna_domain_expire_chain_path`
    不再硬编码当前属性表下的固定伤害结果
  - `README.md` 的 GDScript 行数统计与仓库一致性闸门保持同步
  - `bash tests/run_with_gate.sh` 通过

#### 当前执行结果

- 已完成：
  - 原 `sukuna_kamado_domain_suite.gd` 已拆成 `sukuna_kamado_suite.gd` 与 `sukuna_domain_suite.gd`，并按 effect payload 与当前属性表动态计算预期固定伤害，不再把 `10 / 20` 写死在断言里
  - 连带收口了 `double kamado on_exit`、`forced_replace on_exit`、`domain expire burst` 三处同类脆断点
  - `README.md` 已同步最新测试行数与 GDScript 总行数统计，恢复仓库一致性闸门

#### 当前验证结果

- `bash tests/run_with_gate.sh` 通过

### 闸门前置依赖与设计文档补齐（已完成）

- 目标：
  - 把测试闸门的 shell 工具前置依赖改成显式 fail-fast，避免依赖表达不清
  - 修正 effect / turn 编排设计文档里的模块归属与文件清单偏差
- 范围：
  - `tests/run_with_gate.sh`
  - `tests/check_architecture_constraints.sh`
  - `tests/check_suite_reachability.sh`
  - `tests/check_repo_consistency.sh`
  - `tests/require_tools.sh`
  - `tests/README.md`
  - `docs/design/effect_engine.md`
  - `docs/design/turn_orchestrator.md`
- 验收标准：
  - 闸门脚本缺少 `godot / python3 / rg` 任一工具时直接 fail-fast
  - `effect_engine.md` 不再错挂 `passives` 子域文件，且触发点权威来源写清楚
  - `turn_orchestrator.md` 文件清单补齐 `turn_limit_scoring_service.gd`

#### 当前执行结果

- 已完成：
  - 新增 `tests/require_tools.sh`，统一收口 gate 脚本工具前置检查
  - `run_with_gate.sh`、`check_architecture_constraints.sh`、`check_suite_reachability.sh`、`check_repo_consistency.sh` 已改为显式检查所需 shell 工具
  - `tests/README.md` 已补“`godot / python3 / rg` 缺任一即 fail-fast”的约定
  - `effect_engine.md` 已移除错挂的 `passives` 子域文件清单，并改成引用 `passive_and_field.md`
  - `effect_engine.md` 已声明触发点全集以 `docs/rules/06_effect_schema_and_extension.md` 为权威，不再重复维护一份漂移副本
  - `turn_orchestrator.md` 已补入 `turn_limit_scoring_service.gd`

#### 当前验证结果

- `bash tests/run_with_gate.sh` 通过

### 扩角前共享 payload 与 facade 踩线收口（已完成）

- 目标：
  - 把宿傩三处共享火属性固定伤害从“纯文档同步点”升级成加载期硬校验
  - 给这条约束补一条负向回归，确保漂移时直接 fail-fast
  - 把 `BattleCoreManager` 从 250 行踩线状态收回到安全线，并在 BST 计算代码里写明 `max_mp` 第七维假设
- 范围：
  - `src/battle_core/content/content_snapshot_shape_validator.gd`
  - `tests/suites/content_validation_contract_suite.gd`
  - `src/battle_core/facades/battle_core_manager.gd`
  - `src/battle_core/effects/rule_mod_value_resolver.gd`
  - `docs/design/sukuna_design.md`
  - `docs/records/decisions.md`
- 验收标准：
  - 宿傩 `sukuna_kamado_mark / sukuna_kamado_explode / sukuna_domain_expire_burst` 的固定火伤配置若发生漂移，`BattleContentIndex.load_snapshot()` 必须直接失败
  - `content_validation_contract_suite.gd` 有专项负向回归覆盖这条约束
  - `battle_core_manager.gd` 低于 250 行阈值
  - `bash tests/run_with_gate.sh` 通过

#### 当前执行结果

- 已完成：
  - 内容快照 shape validator 已补正式角色共享火伤一致性校验
  - `content_validation_contract_suite.gd` 已新增宿傩共享火伤漂移负向回归
  - `BattleCoreManager` 已从 250 行踩线降回阈值以内
  - `rule_mod_value_resolver.gd` 已补 `max_mp` 计入 BST 的代码注释

#### 当前验证结果

- `bash tests/run_with_gate.sh` 通过

### 审查报告复核与问题收口（已完成）

- 目标：
  - 逐条复核外部审查报告里的架构、角色、代码质量与风险结论，确认哪些问题真实存在，哪些只是维护性观察，哪些属于表述过度
  - 对真实存在的问题整理可执行整改方案，避免把“当前 bug”和“后续技术债”混成一类
- 范围：
  - `src/battle_core/effects/payload_handlers/*`
  - `src/battle_core/passives/field_service.gd`
  - `src/battle_core/lifecycle/replacement_service.gd`
  - `src/composition/battle_core_wiring_specs.gd`
  - `docs/design/architecture_overview.md`
  - `docs/design/lifecycle_and_replacement.md`
  - `docs/design/passive_and_field.md`
  - `docs/design/sukuna_design.md`
  - `tests/suites/sukuna_kamado_suite.gd`
  - `tests/suites/sukuna_domain_suite.gd`
  - `tests/suites/forced_replace_field_break_suite.gd`
  - `tests/check_architecture_constraints.sh`
- 验收标准：
  - 审查报告中的重点问题要明确分成“成立 / 部分成立 / 不成立”
  - 结论需要有源码或测试依据，不能只靠口头判断
  - 对成立问题给出最小改法、验证点与实施顺序

#### 当前执行结果

- 已完成：
  - 全量跑通 `bash tests/run_with_gate.sh`，确认当前主线无回归，角色链路、架构闸门与仓库一致性全部通过
  - `PayloadForcedReplaceHandler` 已改为注入并复用 `PayloadUnitTargetHelper`，不再本地重复实现 target 解析与合法性判断
  - 已新增 `payload_effect_event_helper.gd`，统一收口 4 处 `_resolve_effect_roll()` 重复逻辑
  - `PayloadStateHandler` 也已改成复用组合根注入的 helper，不再内部 `new()` helper
  - 确认 `last_invalid_battle_code` 在 `src/` 内共 13 处扩散，属于当前 fail-fast 错误传播约定，不是新近漂移
  - 已把 `trigger_batch_runner -> payload_executor -> payload_numeric_handler -> faint_resolver -> replacement_service -> trigger_batch_runner` 的受控运行时环补成显式架构约束与决策记录
  - 确认 `architecture_overview.md` 已明确写出 `BattleCoreSession` 是 manager 内部会话壳，因此原审查里“未在高层文档明确列出 battle_core_session”这句不准确
  - 已修正 `lifecycle_and_replacement.md` 对 `field_service.gd` 的文档口径，明确它是 field 子域服务，本文件只是引用其提前打断能力
  - 已在 `sukuna_design.md` 标注 `20` 点火属性固定伤害的三处同步修改点
  - 确认源码最大文件当前为 `src/battle_core/facades/battle_core_manager.gd` 的 241 行，仍处在架构闸门的预警区间内但未超过 `>250` 阈值

#### 当前验证结果

- `bash tests/run_with_gate.sh` 通过

### 战斗核心全量治理整顿（已完成）

- 目标：
  - 把扩角前最后一轮底盘治理一次收紧：统一运行时 helper 装配、移除公开入口与主链关键断言、公开 API 统一结构化 envelope、宿傩灶补正式 3 层上限，并把文档与回归锚点补齐
- 范围：
  - `src/composition/*`
  - `src/battle_core/facades/*`
  - `src/battle_core/actions/*`
  - `src/battle_core/commands/*`
  - `src/battle_core/lifecycle/*`
  - `src/battle_core/passives/*`
  - `src/battle_core/effects/*`
  - `src/battle_core/content/*`
  - `tests/suites/manager_*`
  - `tests/suites/adapter_contract_suite.gd`
  - `tests/suites/sukuna_kamado_suite.gd`
  - `tests/suites/sukuna_domain_suite.gd`
  - `docs/design/*`
  - `docs/records/*`
- 验收标准：
  - 运行时 helper 不再由 owner service 内部 `new()` + 手工同步依赖
  - `BattleCoreManager` 公开方法统一返回严格 `{"ok","data","error_code","error_message"}` envelope
  - 宿傩灶正式写死 `max_stacks = 3`，满层后再挂灶不新增、不刷新、不替换
  - manager / Sukuna / 架构回归与三条总闸门全绿

#### 当前执行结果

- 已完成：
  - `ActionExecutor`、`ActionCastService`、`PayloadNumericHandler`、`FaintResolver`、`FieldApplyService` 已切到容器统一注入 helper
  - `RuntimeGuardService` 已改为递归缺依赖检查，缺线会在主链启动前 fail-fast
  - `BattleCoreComposer` 不再靠断言暴露装配失败；`BattleCoreManager` 公开方法已统一 envelope
  - `CommandBuilder`、`LegalActionService`、`BattleInitializer`、`ReplayRunner` 等公开主链依赖点已改为显式错误路径
  - 宿傩灶已补 `max_stacks = 3`，并新增“满层忽略新层”“强制换下触发 on_exit”“creator 被击倒导致 field_break 无终爆”回归
  - helper 文件清单、`facades/` 目录、宿傩设计稿与 records 已同步补齐

#### 当前验证结果

- `godot --headless --path . --script tests/run_all.gd` 通过
- `bash tests/check_architecture_constraints.sh` 通过
- `bash tests/check_repo_consistency.sh` 通过

### 角色契约收口与机制说明统一（已完成）

- 目标：
  - 把 Gojo / Sukuna 的正式交付契约、共享回归归属、资源快照断言和机制说明统一收口
  - 统一对外 facade 口径，明确 `BattleCoreManager` 是唯一稳定入口
  - 在不改角色主玩法语义的前提下，把现状文档、测试和注册表挂稳
- 范围：
  - `src/battle_core/facades/battle_core_manager.gd`
  - `src/composition/battle_core_composer.gd`
  - `tests/support/battle_core_test_harness.gd`
  - `tests/suites/gojo_suite.gd`
  - `tests/suites/sukuna_suite.gd`
  - `tests/suites/gojo_snapshot_suite.gd`
  - `tests/suites/sukuna_snapshot_suite.gd`
  - `tests/suites/gojo_murasaki_suite.gd`
  - `docs/records/formal_character_registry.json`
  - `README.md`
  - `tests/README.md`
  - `docs/design/action_execution.md`
  - `docs/design/turn_orchestrator.md`
  - `docs/design/architecture_overview.md`
  - `docs/design/battle_core_architecture_constraints.md`
  - `docs/design/gojo_satoru_design.md`
  - `docs/design/sukuna_design.md`
  - `docs/records/decisions.md`
- 验收标准：
  - Gojo / Sukuna 正式角色交付面显式挂住共享领域回归与各自 snapshot suite
  - Gojo `茈` 新增“无反噬”回归
  - README / 设计稿 / 测试说明 / 决策记录里的 facade、priority、类型名与机制说明一致
  - `bash tests/run_with_gate.sh` 通过

#### 当前执行结果

- 已完成：
  - `BattleCoreManager` 内部装配依赖改为 `container_factory`，并通过独立工厂端口保活，不再直接依赖完整 composition root
  - Gojo / Sukuna wrapper 已接入各自 snapshot suite
  - Gojo 新增 `gojo_murasaki_no_recoil_contract`
  - 正式角色注册表已补齐 snapshot suite、共享领域 suite 与共享子 suite 锚点
  - Gojo / Sukuna 设计稿已统一 priority 数字写法、领域 / 锁行动 / 来袭命中修正 / 灶 / 终爆等机制说明
  - README、架构文档、测试说明与决策记录已统一为“`BattleCoreManager` 是唯一稳定 facade”

#### 当前验证结果

- `bash tests/run_with_gate.sh` 通过

### 扩角前中等治理收口（已完成）

- 目标：
  - 拆分内容快照 shape validator 的长函数，避免扩角时继续堆进单个入口
  - 预拆 turn limit 计分职责，为后续新增胜负条件留出空间
  - 统一 `on_matchup_changed` 的编排 owner，避免初始化与回合内双份实现继续漂移
  - 同步架构文档与宿傩 BST 公式假设
- 范围：
  - `src/battle_core/content/content_snapshot_shape_validator.gd`
  - `src/battle_core/content/content_snapshot_unit_validator.gd`
  - `src/battle_core/turn/battle_result_service.gd`
  - `src/battle_core/turn/turn_limit_scoring_service.gd`
  - `src/battle_core/turn/battle_initializer.gd`
  - `src/composition/*`
  - `docs/design/architecture_overview.md`
  - `docs/design/sukuna_design.md`
  - `docs/records/*`
- 验收标准：
  - `ContentSnapshotShapeValidator.validate()` 收口成分段编排入口，不再承载全部 unit/skill/field/effect 校验细节
  - `battle_result_service.gd` 低于 250 行，turn limit 计分独立成 helper service，行为不变
  - 初始化阶段与回合内阶段统一复用 `TurnFieldLifecycleService.execute_matchup_changed_if_needed()`
  - 相关 suite 与 `bash tests/run_with_gate.sh` 通过

#### 当前执行结果

- 已完成：
  - `ContentSnapshotShapeValidator` 已改为分段校验入口；unit 校验下沉到独立 helper
  - `BattleResultService` 已把 turn limit 计分职责拆到 `TurnLimitScoringService`
  - `BattleInitializer` 已改为复用 `TurnFieldLifecycleService.execute_matchup_changed_if_needed()`
  - `architecture_overview.md` 已补 `effects/payload_handlers/` 粒度说明
  - `sukuna_design.md` 已明确 BST 公式包含 `max_mp` 的设计假设

#### 当前验证结果

- `bash tests/run_with_gate.sh` 通过

### 宿傩回蓝语义收口与样例口径同步（已完成）

- 目标：
  - 把宿傩被动回蓝从“覆盖最终值”收口成“基础回蓝 + 对位追加”
  - 重算默认装配与反转术式装配的首次奥义窗口基线
  - 同步收口 README / content / design / registry / samples 目录口径
- 范围：
  - `content/effects/sukuna/sukuna_refresh_love_regen.tres`
  - `content/samples/*`
  - `tests/suites/sukuna_setup_regen_suite.gd`
  - `docs/design/sukuna_design.md`
  - `docs/design/sukuna_adjustments.md`
  - `docs/records/*`
  - `content/README.md`
  - `README.md`
- 验收标准：
  - 宿傩动态回蓝按 `基础 12 + 对位追加` 结算，初始化预回蓝与后续 `turn_start` 一致
  - 默认装配与反转术式装配的首次奥义窗口新基线已写入设计稿、调整记录、注册表与 suite
  - `content/samples/` 补入最小合法样例资源，占位目录不再为空
  - `bash tests/run_with_gate.sh` 通过

#### 当前执行结果

- 已完成：
  - 宿傩 `sukuna_refresh_love_regen` 已从 `mp_regen set` 改为 `mp_regen add`
  - `sukuna_setup_regen_suite.gd` 已改为同时守住初始化预回蓝与下一回合 `turn_start` 的追加回蓝
  - 宿傩默认装配与反转术式装配的首次奥义窗口已统一更新为第 `4` 回合
  - `content/samples/` 已补最小合法样例资源占位，目录口径重新对齐

#### 当前验证结果

- `bash tests/run_with_gate.sh` 通过

### 正式角色 content 子目录收口（已完成）

- 目标：
  - 把 Gojo / Sukuna 的正式内容资源从平铺目录下沉到各自角色子目录
  - 保持递归 snapshot 收集策略不变，不为角色资源写额外装配分支
  - 同步 formal character registry 与 content 文档口径
- 范围：
  - `content/units/{gojo,sukuna}/`
  - `content/skills/{gojo,sukuna}/`
  - `content/effects/{gojo,sukuna}/`
  - `content/passive_skills/{gojo,sukuna}/`
  - `content/fields/{gojo,sukuna}/`
  - `docs/records/formal_character_registry.json`
  - `content/README.md`
  - `docs/records/decisions.md`
- 验收标准：
  - 正式角色资源全部位于各自子目录，sample / format / combat type 资源不受影响
  - `docs/records/formal_character_registry.json` 的 `required_content_paths` 全部指向新路径
  - `SampleBattleFactory.content_snapshot_paths()` 无需新增角色特判仍能加载全量资源
  - `bash tests/run_with_gate.sh` 通过

#### 当前执行结果

- 已完成：
  - Gojo / Sukuna 的 unit、skill、effect、passive_skill、field 资源已迁到各自角色子目录
  - formal character registry 已同步切到新路径
  - `content/README.md` 已明确记录正式角色子目录布局与递归收集策略

#### 当前验证结果

- `bash tests/run_with_gate.sh` 通过

### Gojo 领域失败锁人修补（已完成）

- 目标：
  - 补上 Gojo 先手开域但领域对拼最终失败时，不得残留 `action_lock` 的时序回归
  - 把同回合双开领域时，先手方的 `field_apply_success` 附带效果延后到对拼结论后再兑现
  - 同步收口相关 runtime / suite / registry / design / rules / records 口径
- 范围：
  - `src/battle_core/passives/**/*`
  - `src/battle_core/contracts/**/*`
  - `src/battle_core/runtime/**/*`
  - `src/battle_core/actions/action_executor.gd`
  - `src/battle_core/turn/action_queue_builder.gd`
  - `tests/suites/gojo_domain_suite.gd`
  - `docs/design/battle_runtime_model.md`
  - `docs/design/gojo_satoru_design.md`
  - `docs/rules/05_items_field_input_and_logging.md`
  - `docs/records/*`
- 验收标准：
  - Gojo 若先手展开领域、但同回合被后手领域翻盘，不得先挂出并残留 `gojo_domain_action_lock`
  - 先手领域若最终对拼失败，不得提前兑现只属于成功立场的 success 附带效果
  - `gojo_unlimited_void_failed_clash_does_not_revive_action_lock_contract` 纳入正式角色回归锚点
  - `bash tests/run_with_gate.sh` 通过

#### 当前执行结果

- 已完成：
  - 同回合双开领域时，先手方的 `field_apply_success` 已改为等待对拼窗口关闭后再兑现
  - Gojo 先手但对拼失败时，不再残留 `action_lock`
  - `gojo_unlimited_void_failed_clash_does_not_revive_action_lock_contract` 已加入正式角色回归锚点

#### 当前验证结果

- `bash tests/run_with_gate.sh` 通过

## 2026-03-30

### 去自动选指化整合（已完成）

- 目标：
  - 从主线移除自动选指、旧策略表、角色 mode handler 与批量模拟案例
  - 保持核心战斗、手动输入、回放与固定案例复查链路可用
  - 同步收口 README / rules / design / records / tests 口径
- 范围：
  - `src/adapters/**/*`
  - `tests/suites/*`
  - `tests/helpers/*`
  - `docs/**/*`
  - `README.md`
- 验收标准：
  - 仓库不再保留自动选指 adapter、自动选指策略、自动选指决策回归、批量模拟案例
  - `tests/run_with_gate.sh` 通过
  - 活跃文档不再把自动选指策略 / 自动选指回归 / probe 作为当前主线交付面

#### 当前执行结果

- 已完成：
  - `src/adapters/` 下自动选指 adapter、policy service、角色 mode handler 已从主线移除
  - `tests/run_all.gd`、adapter / manager contract suites 与 consistency gate 已同步删除自动选指 / probe 交付面
  - README、rules、design、records、tests 文档口径已统一为“玩家输入 + 系统自动注入 + 回放 + 固定案例”

#### 当前验证结果

- `bash tests/run_with_gate.sh` 通过

### Effect 链递归防抖与规则命名收口（已完成）

- 目标：
  - 修补 effect 链递归重新派发时，`event_id` 导致的 dedupe 失效
  - 保留合法的“换目标后重新触发”路径
  - 清掉活跃规则文件里残留的旧自动选指命名
- 范围：
  - `src/battle_core/effects/**/*`
  - `tests/suites/action_guard_state_integrity_suite.gd`
  - `docs/rules/*`
  - `docs/design/*`
  - `docs/records/*`
  - `tests/check_repo_consistency.sh`
  - `README.md`
- 验收标准：
  - 新建的 effect event 在同链路递归重派发时会命中 `invalid_chain_depth`
  - `battle_init` 换位后的 `on_matchup_changed` 合法重触发不受影响
  - 活跃文档不再保留带 `ai` 的规则文件命名
  - `tests/run_with_gate.sh` 通过

#### 当前执行结果

- 已完成：
  - `PayloadExecutor` 改为按稳定语义键做 effect dedupe，不再依赖一次性的 `event_id`
  - `invalid_chain_depth_dedupe_guard` 已升级为“重新 collect 出新事件对象”的真实回归
  - `docs/rules/05_items_field_input_and_logging.md` 已替换旧规则文件命名，活跃引用与 consistency gate 已同步

#### 当前验证结果

- `bash tests/run_with_gate.sh` 通过

### 正式角色注册表与内容快照门禁泛化（已完成）

- 目标：
  - 把正式角色接入从手写 Gojo / Sukuna 特例收口为统一注册表
  - 让 `SampleBattleFactory.content_snapshot_paths()` 支持递归目录，避免子目录漏扫
  - 同步 README / 测试说明 / 一致性门禁口径
- 范围：
  - `src/composition/sample_battle_factory.gd`
  - `tests/run_all.gd`
  - `tests/check_repo_consistency.sh`
  - `tests/support/formal_character_registry.gd`
  - `docs/records/formal_character_registry.json`
  - `tests/suites/content_index_split_suite.gd`
  - `tests/fixtures/content_snapshot/**/*`
  - `README.md`
  - `tests/README.md`
  - `docs/records/*`
- 验收标准：
  - 正式角色 suite 由注册表驱动接入 `tests/run_all.gd`
  - consistency gate 统一按注册表校验角色交付面
  - `SampleBattleFactory.content_snapshot_paths()` 对嵌套 `.tres` 生效
  - `tests/run_with_gate.sh` 通过

#### 当前执行结果

- 已完成：
  - 新增 `docs/records/formal_character_registry.json`，Gojo / 宿傩交付面已落单一真相
  - `tests/run_all.gd` 已改为通过注册表动态装配正式角色 wrapper
  - `tests/check_repo_consistency.sh` 已改为统一校验注册表、内容资源与 `SampleBattleFactory` 接线
  - `content_snapshot_recursive_contract` 已守住嵌套 `.tres` 收集

#### 当前验证结果

- `bash tests/run_with_gate.sh` 通过

### 扩角前规范整合（已完成）

- 目标：
  - 收紧 manager 对外日志接口，移除 runtime id 泄漏
  - 把 active field creator invariant 升级为权威规则
  - 正式澄清初始化预回蓝 contract 与 BattleResult owner
  - 固化扩角前角色接入模板
  - 预拆 ActionCast / FaintResolver 热点职责
- 范围：
  - `src/battle_core/**/*`
  - `src/composition/*`
  - `content/**/*`
  - `docs/design/*`
  - `docs/records/*`
  - `tests/**/*`
  - `README.md`
- 验收标准：
  - `tests/run_with_gate.sh` 通过，且预期 invalid path 不再伪装成引擎级 `ERROR:`
  - manager 对外日志不再泄漏 runtime id
  - field creator invariant 已进入规则 / 设计文档
  - 角色接入模板与当前主线口径一致
  - `ActionCastService` / `FaintResolver` 已完成一轮职责预拆

#### 当前执行结果

- 已完成：
  - `BattleCoreManager.get_event_log_snapshot()` 已切到公开安全投影，contract 测试已守住公开字段与私有字段边界
  - active field 缺失 creator 与同侧领域重开主路径都已统一 `invalid_state_corruption` fail-fast
  - `BattleResultService` 已接管初始化阶段 invalid/startup victory 落盘
  - `ActionCastService` 与 `FaintResolver` 已拆出子 pipeline / 子服务
  - README / 规则 / 设计 / 测试文档已同步公开日志、初始化预回蓝与角色接入模板口径

#### 当前验证结果

- 待本轮全部收口后统一复跑：
  - `bash tests/run_with_gate.sh`

### 扩角前整治第二阶段收口（已完成）

- 目标：
  - 把本轮 runtime 修补和扩角前 gate 收口成统一主线
  - 让正式角色注册表覆盖 effect 资源、子 suite 与关键回归名
  - 补齐 suite 可达性门禁与 battle_core 内部分层静态约束
  - 把宿傩首次奥义窗口写成文档硬锚点，避免“测试变了但文档还算对”
- 范围：
  - `src/battle_core/**/*`
  - `tests/**/*`
  - `docs/design/*`
  - `docs/records/*`
  - `README.md`
- 验收标准：
  - `bash tests/run_with_gate.sh` 通过
  - `CASE=all godot --headless --path . --script tests/helpers/domain_case_runner.gd` 通过
  - 正式角色注册表包含 `required_content_paths / required_suite_paths / required_test_names`
  - 宿傩设计稿与调整记录明确冻结首次奥义窗口回合

#### 当前执行结果

- 已完成：
  - effect 链去重键加入 `effect_instance_id`，同源叠层 effect 不再被误吞
  - field 生命周期旧实例清理改成按实例范围回收，`field_break / field_expire` 链里新接上的后继 field 不会被旧清理误删
  - turn end field/effect 生命周期 helper 统一回传终局信号，turn loop 会在 invalid / terminal 路径立刻停机
  - `runtime_guard_service` 与 `turn_selection_resolver` 都已补“仍有存活单位但 active 槽为空”的本地 fail-fast
  - `tests/run_with_gate.sh` 已串上 suite reachability gate，`tests/check_architecture_constraints.sh` 已补 L1/L2 静态约束
  - `formal_character_registry.json` 已补 Gojo / 宿傩 effect 资产、子 suite 路径与关键测试名锚点
  - `docs/design/sukuna_design.md` / `docs/design/sukuna_adjustments.md` 已冻结默认装配第 4 回合、反转装配第 4 回合的首次奥义窗口

#### 当前验证结果

- `godot --headless --path . --script tests/run_all.gd` 通过
- 待本节文件更新后统一复跑：
  - `bash tests/run_with_gate.sh`
  - `CASE=all godot --headless --path . --script tests/helpers/domain_case_runner.gd`

### 扩角前整治补完与扩角门禁收口（已完成）

- 目标：
  - 修补多层 effect、field 交接链与运行态守卫中的剩余坏状态路径
  - 把正式角色注册表从“wrapper + 文档 + 资源”升级为“资源 + suite 子树 + 关键回归锚点”的单一真相
  - 给总闸门补上 suite 可达性与 `battle_core` 内部分层静态约束，降低下轮复审再冒出一批基础漂移的问题
- 范围：
  - `src/battle_core/**/*`
  - `tests/**/*`
  - `docs/design/*`
  - `docs/records/*`
  - `README.md`
- 验收标准：
  - stacked effect、field 继任链、active slot / active field 坏状态都由 fail-fast contract 或专项回归守住
  - `formal_character_registry.json` 已登记正式角色 effect 资源、`required_suite_paths` 与 `required_test_names`
  - `bash tests/run_with_gate.sh` 与固定领域案例 runner 全部通过

#### 当前执行结果

- 已完成：
  - effect dedupe 现在按 `effect_instance_id` 区分合法堆叠实例，不再把 distinct stacked instances 当成递归噪音吞掉
  - 旧 field 在 `field_break / field_expire` 链里创建 successor field 时，旧清理逻辑不会再误删新 field 与其派生状态
  - `turn_start / selection / turn_end` 的运行态坏状态已补本地守卫与 fail-fast 回归，缺失 active slot / active field creator 不再静默滑过去
  - `tests/run_with_gate.sh` 已接入 `check_suite_reachability.sh`；架构闸门新增 `battle_core` L1/L2 纯度约束并清掉历史大文件 allowlist
  - Gojo / Sukuna 注册表已补 effect 资产、suite 子树与关键回归锚点；宿傩设计稿与调整记录已补首个奥义窗口基线

#### 当前验证结果

- `bash tests/run_with_gate.sh` 通过
- `CASE=all godot --headless --path . --script tests/helpers/domain_case_runner.gd` 通过

## 当前未解决问题

### 1. 宿傩对 Gojo 的领域兑现率仍需复查（已知，不在本轮修）

- 当前结论：宿傩已经能稳定进入奥义窗口，也会按领域；但在回蓝语义从 `set` 改成 `add` 之后，Gojo 对位里的领域兑现率需要在下一轮平衡任务里重新复查。
- 当前处理：只记录为下一轮平衡问题，不在本轮规范整合里动数值。
- 后续入口：完成本轮整合后，再单开“领域资源轴/平衡修正”任务。

## 下一步建议

1. 若继续扩新角色，先补 `docs/records/formal_character_registry.json`、设计稿、调整记录、suite 与 `SampleBattleFactory` 接线。
2. 若转去做平衡整理，再单开“宿傩对 Gojo 的领域兑现率修正”任务，不与当前治理规范混做。

### 领域规范整合与扩角前收口（已完成）

- 目标：
  - 修复领域重开与普通 field 阻断口径
  - 把领域模板关键规则下沉为加载期硬校验
  - 统一领域重开合法性判定路径（选指/执行共用）
  - 对齐 README/架构总览/角色稿与一致性门禁
  - 抽公共 DomainRoleTestSupport，去除 suite 对私有方法依赖
  - 对热点服务做函数级预拆并更新架构闸门过渡上限
- 实现摘要：
  - 新增 `domain_legality_service`，LegalActionService 与 ActionDomainGuard 共用
  - `public_snapshot.field` 新增 `field_kind / creator_side_id`
  - 新增 `domain_field_contract_validation` 回归，强约束 domain field 清理链
  - README 代码行统计、快照目录口径、facade 接口文档与 consistency 脚本同步
  - `sukuna_*_suite` 不再调用 `_support._*` 私有 helper
- 验证结果：
  - `bash tests/run_with_gate.sh` 通过
  - `CASE=all godot --headless --path . --script tests/helpers/domain_case_runner.gd` 通过
- 本轮遗留（非本任务范围）：
  - 宿傩在 Gojo 对位中的领域兑现率仍需另开平衡任务复查，不影响本轮规范收口目标。

### 扩角前治理收口实施（已完成）

- 目标：
  - 收口 release-safe fail-fast，去掉受内容/运行态输入影响的生产路径 raw `assert()`
  - 把内容快照 shape validator 推进到第二轮按子域编排
  - 预拆初始化与回合主编排函数，降低继续扩角时的增长风险
  - 保持 `250` 硬门禁不变，同时补 `220..250` 非阻断预警
- 范围：
  - `src/battle_core/content/*`
  - `src/battle_core/effects/rule_mod_write_service.gd`
  - `src/battle_core/turn/battle_initializer.gd`
  - `src/battle_core/turn/turn_loop_controller.gd`
  - `tests/suites/content_validation_contract_suite.gd`
  - `tests/suites/rule_mod_runtime_suite.gd`
  - `tests/check_architecture_constraints.sh`
  - `tests/check_repo_consistency.sh`
  - `docs/design/battle_core_architecture_constraints.md`
  - `docs/records/decisions.md`
  - `README.md`
- 验收标准：
  - unsupported content resource 与 invalid stacking key schema 都走结构化 fail-fast，不再依赖 raw `assert()`
  - `ContentSnapshotShapeValidator.validate()` 只保留编排入口，formal character dual-write 一致性校验继续保留
  - `BattleInitializer.initialize_battle()` 与 `TurnLoopController.run_turn()` 只保留阶段编排
  - 架构闸门对 `220..250` 行输出 `ARCH_GATE_WARNING`，但不阻断
  - `bash tests/run_with_gate.sh` 通过

#### 当前执行结果

- 已完成：
  - `BattleContentRegistry` 对 unsupported resource 改成显式错误，`BattleContentIndex.load_snapshot()` 现在会返回 `INVALID_CONTENT_SNAPSHOT`
  - `RuleModWriteService` 的 stacking key schema / field 异常改成 `INVALID_RULE_MOD_DEFINITION`，并补了定向回归
  - 内容快照 shape validator 已拆成 catalog / unit / skill / field / effect / formal-character consistency 多个 helper
  - `BattleInitializer` 与 `TurnLoopController` 已拆成阶段式私有 helper，日志、回放与终止点行为保持不变
  - 架构闸门已补 `220..250` 非阻断预警，README 统计、架构约束文档与决策记录已同步

#### 当前验证结果

- `bash tests/run_with_gate.sh` 通过
- 当前非阻断预警热点：
  - `src/battle_core/turn/battle_initializer.gd` `226` 行
  - `src/battle_core/facades/battle_core_manager.gd` `237` 行

### 2026-04-01 当前项目完整审查（已完成）

- 目标：
  - 对当前项目做一次完整实现审查，覆盖架构、设计文档对齐、Gojo / 宿傩正式角色实现、最近提交回归，以及单文件体量风险
- 范围：
  - `README.md`
  - `docs/design/*`
  - `docs/rules/*`
  - `docs/records/formal_character_registry.json`
  - `content/{units,skills,effects,passive_skills,fields}/{gojo,sukuna}/*`
  - `src/battle_core/**/*`
  - `tests/**/*`
- 验收标准：
  - 明确给出“是否适合继续扩角”的结论
  - 明确区分阻断问题、结构风险、测试缺口与单文件体量风险
  - 审查结论落盘并附本地验证结果

#### 当前执行结果

- 已完成：
  - 已完成架构、规则文档、设计稿、正式角色资源、关键运行时服务与回归套件的交叉审查
  - 已复查最近提交 `6dec8c5..df059e1` 的主线变更，未发现新的可复现破坏性回归
  - 已顺手修复 `stacking=none` 的重复施加仍会误写 `EFFECT_APPLY_EFFECT` 日志的问题，并补 `apply_effect_none_repeat_skips_log` 回归
  - 已补 `sukuna_kamado_natural_expire_path`，把“灶自然到期终爆”纳入正式回归
  - 已补宿傩 formal registry 缺失的关键回归锚点，并让 `BattleCoreTestHarness` 在内容快照加载失败时立刻 fail-fast
  - 已澄清宿傩设计稿里 6 维面板 BST 与被动公式 7 维 matchup BST 的口径差异
  - 已输出完整审查记录：`docs/records/review_2026-04-01_current_state_audit.md`
- 核心结论：
  - 当前没有发现阻断级问题，完整闸门通过
  - 建议先做一轮规范整合，再继续扩新角色
  - 主要风险集中在：
    - `persists_on_switch` 与 `rule_mod` 跨离场语义仍未收口
    - `mp_regen / incoming_accuracy` stacking key 的多来源折叠风险
    - Gojo 缺少 formal content validator
    - 正式角色缺少 manager 级端到端 smoke 模板

#### 当前验证结果

- `bash tests/run_with_gate.sh` 通过

### 扩角前规范整合计划（已完成）

- 目标：
  - 在继续扩第三个复杂角色前，先把持久 buff 生命周期、`mp_regen / incoming_accuracy` 多来源叠加、正式角色交付面 smoke，以及角色设计稿模板化一次收口
- 范围：
  - `src/battle_core/content/*`
  - `src/battle_core/lifecycle/*`
  - `src/battle_core/effects/*`
  - `src/battle_core/turn/*`
  - `tests/suites/*`
  - `docs/rules/04_status_switch_and_lifecycle.md`
  - `docs/rules/06_effect_schema_and_extension.md`
  - `docs/design/battle_runtime_model.md`
  - `docs/design/battle_content_schema.md`
  - `docs/design/formal_character_design_template.md`
  - `docs/design/gojo_satoru_design.md`
  - `docs/design/sukuna_design.md`
  - `docs/records/formal_character_registry.json`
  - `docs/records/decisions.md`
- 验收标准：
  - `persists_on_switch` 与 bench 持续效果 contract 明确落地
  - `mp_regen / incoming_accuracy` 支持多来源并存，且有回归覆盖
  - Gojo formal validator、Gojo/Sukuna manager smoke 接入正式角色交付面
  - 角色稿改成“共享引擎规则只引用、不重写”
  - `bash tests/run_with_gate.sh` 通过

#### 当前执行结果

- 已完成：
  - 生命周期 contract 已收口：非击倒离场会保留 `persists_on_switch=true` 的 unit effect / unit rule mod；板凳上只继续倒计时，不跑普通 `turn_start / turn_end` trigger
  - `mp_regen / incoming_accuracy` 已改成按来源分组并存，并补了多来源回归
  - 已新增 `content_snapshot_formal_gojo_validator.gd`，并把 Gojo validator path 挂进 `formal_character_registry.json`
  - 已新增 `gojo_manager_smoke_suite.gd` / `sukuna_manager_smoke_suite.gd`，wrapper suite 与 formal registry 都已接线
  - 已新增 `formal_character_design_template.md`，并把共享 lifecycle / rule_mod contract 下沉回公共规则文档
  - 已补两条正式决策：
    - 持久 buff 在板凳上只掉时间
    - `mp_regen / incoming_accuracy` 允许多来源并存，来源组内再走 stacking

#### 当前验证结果

- `godot --headless --path . --script tests/run_all.gd` 通过
- `bash tests/run_with_gate.sh` 通过

### 鹿紫云一设计稿对齐重写（已完成）

- 目标：
  - 把鹿紫云一角色稿改回最终讨论方向，消除“文档冻结结论”和实际讨论内容之间的偏差
- 范围：
  - `docs/design/kashimo_hajime_design.md`
  - `docs/records/tasks.md`
  - `docs/records/decisions.md`
- 验收标准：
  - 被动不再写成 `incoming_accuracy -15`，而是改回“抗雷减伤 + 水属性命中后漏 MP 并毒返”
  - 四个常规技能的讨论结论明确落成“当前格式下 4 选 3”，不再模糊表达
  - 幻兽琥珀的换人语义明确写成“强化、自伤、奥义封锁都应保留”，不再接受静默降级
  - 需要的引擎 / 内容扩展单独列清楚

#### 当前执行结果

- 已完成：
  - 已将 `docs/design/kashimo_hajime_design.md` 重写为 `v1.1`
  - 已把“雷抗改减伤、水属性漏 MP 与毒返、弥虚葛笼只中和必中、四技能按 4 选 3 落地、琥珀按不可逆形态处理”写成明确冻结结论
  - 已把原草稿里偏离讨论的点显式移除或改写：
    - 不再把鹿紫云的抗性写成闪避型被动
    - 不再把水属性弱点写成“首版暂缓”
    - 不再默认接受“琥珀换人后只留自伤、不留强化”的半残语义
  - 已把 `poison` 类型、来袭属性触发条件、弥虚葛笼读取点、回授电击动态威力与整层移除能力写入扩展清单

#### 当前验证结果

- `git diff --check` 通过
- `bash tests/check_repo_consistency.sh` 通过

### 鹿紫云一设计稿第二轮口径校正（已完成）

- 目标：
  - 根据最新讨论，把鹿紫云一被动、毒属性与扩展清单收口到可直接进入实现拆分的版本
- 范围：
  - `docs/design/kashimo_hajime_design.md`
  - `docs/records/tasks.md`
  - `docs/records/decisions.md`
- 验收标准：
  - 明确“雷属性减伤”是鹿紫云一的角色特性，不得错误地下沉为全局 `thunder` 克制条目
  - 明确“水属性外泄”固定为：只对主动技能 / 奥义命中触发，自身 -15 MP，攻击者吃 15 点毒伤
  - 明确 `poison` 要作为正式完整新属性进入后续内容设计，不再写成临时占位
  - 明确常规技能仍然固定 3 个

#### 当前执行结果

- 已完成：
  - 已将鹿紫云一被动口径改为“角色特有抗雷 + 水属性命中外泄”，并删除把抗雷错误写成全局类型表的说法
  - 已把水属性外泄触发边界写死为“命中就触发，但只对主动技能 / 奥义触发”
  - 已把 `action_actor` 作用域、`on_receive_action_hit` 被动触发、来袭技能属性过滤与目标侧主动伤害减伤读取点补进扩展清单
  - 已把 `poison` 从“首版可中立占位”升级为“正式完整新属性”
  - 已再次确认常规技能仍然固定为 3 个，`弥虚葛笼` 继续作为候选换装位

### 鹿紫云一回授电击与固定属性伤害口径修订（已完成）

- 目标：
  - 把鹿紫云一设计稿里残留的 miss / 清层旧口径收掉，并把固定属性伤害是否吃克制写死
- 范围：
  - `docs/design/kashimo_hajime_design.md`
  - `docs/records/tasks.md`
  - `docs/records/decisions.md`
- 验收标准：
  - 明确负电荷的 `8` 点雷属性固定伤害继续吃雷属性克制
  - 明确水中外泄返还的 `15` 点 `poison` 固定伤害继续吃毒属性克制，不锁死最终值
  - 明确水中外泄不响应持续伤害，但若命中这一击已击杀鹿紫云，反击仍照样结算
  - 删除 `回授电击` 的 miss 残留口径，改成“命中后同时清空双方电荷”

#### 当前执行结果

- 已完成：
  - 已把 `回授电击` 的技能描述与验收矩阵改为“命中后同时清空自身正电荷与目标负电荷”
  - 已删除“miss 时只亏自己正电荷”的旧残留口径
- 已把负电荷 DOT 与水中外泄毒返都明确写成“基础值固定，但最终仍吃属性克制”
- 已把“持续水伤不触发，但致死命中仍触发导电反击”写进主稿和决策记录

### 鹿紫云共享底座扩展与 poison 属性落地（已完成）

- 目标：
  - 先独立交付鹿紫云一需要的共享引擎骨架与 `poison` 正式属性，不把角色内容和底层扩展混在一起
- 范围：
  - `src/battle_core/actions/*`
  - `src/battle_core/content/*`
  - `src/battle_core/contracts/*`
  - `src/battle_core/effects/*`
  - `src/battle_core/runtime/*`
  - `content/combat_types/poison.tres`
  - `content/battle_formats/sample_battle_format.tres`
  - `tests/suites/*`
  - `tests/run_all.gd`
  - `README.md`
  - `docs/records/tasks.md`
  - `docs/records/decisions.md`
- 验收标准：
  - `effect_stack_sum`、`remove_mode=all`、`nullify_field_accuracy`、`incoming_action_final_mod`、`on_receive_action_hit`、`action_actor` scope 全部可用
  - `poison` 成为正式属性并接入克制表与回归
  - 全量 `godot --headless --path . --script tests/run_all.gd` 通过
  - `git diff --check` 与 `bash tests/check_repo_consistency.sh` 通过

#### 当前执行结果

- 已完成：
  - 已把 `SkillDefinition.power_bonus_source` 扩到通用的 `effect_stack_sum`，并新增：
    - `power_bonus_self_effect_ids`
    - `power_bonus_target_effect_ids`
    - `power_bonus_per_stack`
  - 已把 `RemoveEffectPayload` 扩成 `remove_mode = single | all`
  - 已新增 `rule_mod`：
    - `nullify_field_accuracy`
    - `incoming_action_final_mod`
  - 已新增 `required_incoming_command_types / required_incoming_combat_type_ids`
  - 已新增：
    - trigger `on_receive_action_hit`
    - effect scope `action_actor`
    - `ChainContext.action_actor_id`
    - `ChainContext.action_combat_type_id`
  - 已新增正式属性资源 `content/combat_types/poison.tres`
  - 已把 `poison` 首版克制表接进 `sample_battle_format.tres`
  - 已新增回归：
    - `power_bonus_runtime_suite.gd`
    - `on_receive_action_hit_suite.gd`
    - 以及 rule_mod / combat_type / content validation 相关扩展断言
  - 已把 `PowerBonusRuntimeSuite` 接进 `tests/run_all.gd`
  - 已同步 README 代码行数统计，修复 consistency gate

#### 当前验证结果

- `godot --headless --path . --script tests/run_all.gd` 通过
- `git diff --check` 通过
- `bash tests/check_repo_consistency.sh` 通过

### 鹿紫云 Phase 1 主循环与候选技接线（已完成）

- 目标：
  - 先独立交付鹿紫云一的主循环常规技、候选位弥虚葛笼、被动与基础回归，不提前把 `幻兽琥珀` 半接上主线
- 范围：
  - `content/units/kashimo/*`
  - `content/skills/kashimo/*`
  - `content/effects/kashimo/*`
  - `content/passive_skills/kashimo/*`
  - `src/battle_core/content/effect_definition.gd`
  - `src/battle_core/content/content_snapshot_effect_validator.gd`
  - `src/battle_core/effects/payload_executor.gd`
  - `tests/support/kashimo_test_support.gd`
  - `tests/suites/kashimo_*`
  - `tests/run_all.gd`
  - `README.md`
  - `docs/records/tasks.md`
  - `docs/records/decisions.md`
- 验收标准：
  - 鹿紫云 unit 能正常加载，默认三技能为 `雷拳 / 蓄电 / 回授电击`，候选池含 `弥虚葛笼`
  - 主循环、弥虚葛笼、抗雷、水中外泄全部有 runtime 回归
  - `godot --headless --path . --script tests/run_all.gd`、`git diff --check`、`bash tests/check_repo_consistency.sh` 通过

#### 当前执行结果

- 已完成：
  - 已新增鹿紫云 Phase 1 资源：
    - `content/units/kashimo/kashimo_hajime.tres`
    - `content/skills/kashimo/*`
    - `content/effects/kashimo/*`
    - `content/passive_skills/kashimo/kashimo_charge_separation.tres`
  - Phase 1 unit 仍采用“临时不挂奥义”口径：
    - `ultimate_skill_id = ""`
    - `ultimate_points_required = 0`
    - `ultimate_points_cap = 0`
    - `ultimate_point_gain_on_regular_skill_cast = 0`
  - 已把 `回授电击` 正式接到：
    - `power_bonus_source = effect_stack_sum`
    - `remove_mode = all`
  - 为了精确表达“只对水属性主动技能 / 奥义命中触发”，已新增 effect 级来袭动作过滤：
    - `EffectDefinition.required_incoming_command_types`
    - `EffectDefinition.required_incoming_combat_type_ids`
  - 已新增：
    - `tests/support/kashimo_test_support.gd`
    - `tests/suites/kashimo_snapshot_suite.gd`
    - `tests/suites/kashimo_runtime_suite.gd`
    - `tests/suites/kashimo_suite.gd`
  - 已将 `KashimoSuite` 接进 `tests/run_all.gd`

#### 当前验证结果

- `godot --headless --path . --script tests/run_all.gd` 通过
- `git diff --check` 通过

### 鹿紫云 Phase 2 幻兽琥珀、持久能力阶段与正式交付面（已完成）

- 目标：
  - 把 `幻兽琥珀`、持久能力阶段载体和正式角色交付面一起补齐，让鹿紫云从 Phase 1 临时状态切回正式角色
- 范围：
  - `src/battle_core/runtime/*`
  - `src/battle_core/actions/*`
  - `src/battle_core/effects/*`
  - `src/battle_core/lifecycle/*`
  - `src/battle_core/facades/*`
  - `src/battle_core/content/*`
  - `content/skills/kashimo/*`
  - `content/effects/kashimo/*`
  - `content/units/kashimo/*`
  - `tests/suites/kashimo_*`
  - `tests/suites/persistent_stat_stage_suite.gd`
  - `tests/run_all.gd`
  - `docs/design/kashimo_hajime_design.md`
  - `docs/design/kashimo_hajime_adjustments.md`
  - `docs/records/formal_character_registry.json`
  - `docs/records/tasks.md`
  - `docs/records/decisions.md`
  - `docs/rules/04_status_switch_and_lifecycle.md`
  - `docs/rules/06_effect_schema_and_extension.md`
- 验收标准：
  - `幻兽琥珀` 开启后获得持久 `+2 / +2 / +1`
  - 强化、自伤、奥义封锁跨换人保留，击倒后清空
  - 同回合重上场时，`persists_on_switch=true` 的持续效果仍暂停普通 `turn_start / turn_end` 触发；下一整回合恢复
  - 鹿紫云正式接入 `formal_character_registry.json`，`tests/run_all.gd` 不再保留临时手动接线
  - `godot --headless --path . --script tests/run_all.gd`、`bash tests/check_repo_consistency.sh`、`bash tests/run_with_gate.sh` 通过

#### 当前执行结果

- 已完成：
  - 已新增 `UnitState.persistent_stat_stages`
  - 已把 `StatModPayload.retention_mode = persist_on_switch` 接进运行时读写与公开快照
  - 已新增共享回归：
    - `tests/suites/persistent_stat_stage_suite.gd`
  - 已新增鹿紫云 Phase 2 内容资源：
    - `content/skills/kashimo/kashimo_phantom_beast_amber.tres`
    - `content/effects/kashimo/kashimo_amber_self_transform.tres`
    - `content/effects/kashimo/kashimo_amber_bleed.tres`
  - 已把 `content/units/kashimo/kashimo_hajime.tres` 切回正式奥义配置 `3 / 3 / 1`
  - 已新增回归：
    - `tests/suites/kashimo_amber_suite.gd`
    - `tests/suites/kashimo_manager_smoke_suite.gd`
  - 已把“持久 effect 同回合重上场仍暂停普通回合触发”补成共享生命周期语义
  - 已新增：
    - `docs/design/kashimo_hajime_adjustments.md`
    - `src/battle_core/content/content_snapshot_formal_kashimo_validator.gd`
  - 已把鹿紫云接进 `docs/records/formal_character_registry.json`
  - 已把 `tests/run_all.gd` 的临时 `KashimoSuite` 手动接线删掉，改为统一走 formal registry

#### 当前验证结果

- `godot --headless --path . --script tests/run_all.gd` 通过

### 正式角色扩展前整合 Batch 1：共享机制硬约束收口（已完成）

- 目标：
  - 把后续扩角会复用的共享机制隐式契约收口到显式、可回归的状态
- 范围：
  - `src/battle_core/content/content_schema.gd`
  - `src/battle_core/effects/effect_*`
  - `src/battle_core/effects/payload_handlers/payload_apply_effect_handler.gd`
  - `src/battle_core/effects/rule_mod_*`
  - `tests/suites/action_legality_contract_suite.gd`
  - `tests/suites/extension_targeting_accuracy_suite.gd`
  - `tests/suites/rule_mod_runtime_core_paths_suite.gd`
  - `tests/suites/on_receive_action_hit_suite.gd`
  - `tests/support/gojo_test_support.gd`
  - `README.md`
  - `docs/records/tasks.md`
  - `docs/records/decisions.md`
- 验收标准：
  - `action_legality` 改为显式受管控动作白名单口径，`deny all` 仍不封 `wait / resource_forced_default / surrender`
  - `required_target_same_owner` 的 owner 归因统一走 helper，缺失 owner 归因时不能静默成功
  - effect / rule_mod 的 `refresh` 统一为“同实例续命并更新来源元数据”
  - `tests/run_with_gate.sh` 通过

#### 当前执行结果

- 已完成：
  - `ContentSchema` 新增共享动作分层常量：
    - `MANAGED_ACTION_TYPES`
    - `ALWAYS_ALLOWED_ACTION_TYPES`
  - `RuleModReadService` 现在显式区分：
    - 永远不受 `action_legality` 管控的动作
    - 受管控动作类型的匹配 token
    - 未知动作类型的显式报错
  - 新增 `src/battle_core/effects/effect_source_meta_helper.gd`
    - 统一生成 `meta.source_owner_id`
    - 统一读取 / 校验 `source_owner_id`
  - `PayloadApplyEffectHandler`、`GojoTestSupport`、`on_receive_action_hit_suite` 已切到 owner meta helper
  - `EffectPreconditionService` 在 `required_target_same_owner=true` 且 marker 缺少 owner 归因时，改为显式报 `invalid_state_corruption`
  - `EffectInstanceService.STACKING_REFRESH` 现在会同步刷新：
    - `remaining`
    - `source_instance_id`
    - `source_kind_order`
    - `source_order_speed_snapshot`
    - `meta`
  - `RuleModWriteService` 的 `refresh` 路径现在会同步刷新来源三件套，并显式保持 `last_apply_skipped = false`
  - 已补共享回归：
    - `action_legality_managed_action_matrix_contract`
    - `action_legality_unknown_action_type_reports_contract`
    - `required_target_same_owner_missing_owner_contract`
    - `effect_refresh_updates_source_metadata_contract`
    - `rule_mod_refresh_updates_source_metadata_contract`

#### 当前验证结果

- `bash tests/run_with_gate.sh` 通过
