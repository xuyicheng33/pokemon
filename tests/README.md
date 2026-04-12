# Tests Skeleton

本目录承载当前业务回归闸门与测试支撑脚手架。

- `suites/`: 业务回归测试套件
- `suites/*_suite.gd`: 优先作为顶层 wrapper 或按单一 contract 聚合的 suite；若文件足够小且不值得再拆，也允许直接在本文件注册具体 `_test_*`
- 当顶层 suite 超过维护阈值时，保持原 wrapper 文件名与测试名不变，并把断言本体下沉到同名子目录，例如 `suites/multihit_skill_runtime_suite.gd` + `suites/multihit_skill_runtime/*.gd`
- `suites/*_contract_suite.gd` / `suites/*_runtime_suite.gd` / 角色子套件：按单一子域拆分的真实断言文件
- `suites/adapter_contract_suite.gd`: manager 输出边界契约回归
- `suites/content_snapshot_cache_suite.gd`: manager 黑盒视角下的 content snapshot cache 语义等价回归
- `suites/content_snapshot_cache_composer_suite.gd`: composer 级共享 cache 的 hits/misses/size 统计与签名失效回归；当前同时锁顶层文件改动、外部资源依赖改动、`content/shared/` 共享 payload 改动、formal manifest 角色元数据改动，以及 `src/battle_core/content/**/*.gd` / `src/battle_core/content/formal_validators/**/*.gd` 改动都会触发签名变化
- `suites/passive_item_contract_suite.gd`: 最小正式 passive item 内容、runtime、manager 与 replay 黑盒回归
- `suites/trigger_validation_suite.gd`: 触发器声明一致性校验回归
- `suites/heal_extension_suite.gd`: `missing_hp` 百分比治疗与 `incoming_heal_final_mod` 共享回归
- `suites/skill_execute_contract_suite.gd`: 技能级 `execute_*` 共享契约回归
- `suites/multihit_skill_runtime_suite.gd`: `damage_segments` 与 `on_receive_action_damage_segment` 共享回归
- `support/`: 测试 harness、公共构造器与 suite 级共享 helper
- `run_all.gd`: Godot 原生测试入口（业务断言）
- `run_with_gate.sh`: 闸门脚本（业务断言 + 引擎级错误检查 + 架构约束 + 仓库一致性）
- `check_suite_reachability.sh`: suite 可达性闸门；确保 `tests/suites/**/*.gd` 都能从 `run_all.gd` 或正式角色 wrapper 子树走到
- `check_architecture_constraints.sh`: 分层与大文件架构闸门
- `gates/architecture_wiring_graph_gate.py`: runtime wiring 图 DAG 闸门；要求当前属性注入图无闭环
- `check_repo_consistency.sh`: README/文档/关键回归一致性闸门总入口
- `gates/`: 仓库一致性细分 gate；当前按 `surface / formal_character / docs` 三类拆开维护，由 `check_repo_consistency.sh` 聚合执行
- `fixtures/`: 预留的样例输入与内容快照目录
- `helpers/`: 测试辅助脚本目录
- `replay_cases/`: 固定 replay 案例与说明目录（当前包含领域案例与鹿紫云案例）
- `helpers/domain_case_runner.gd`: 固定领域案例 runner；用于在门禁异常或契约漂移时快速复查具体局面
- `helpers/kashimo_case_runner.gd`: 固定鹿紫云案例 runner；用于快速复查电荷主循环、琥珀换人与弥虚葛笼对 Gojo 真领域

当前约定：

- `run_all.gd` 会直接注册核心公共 suite，并按正式角色注册表动态追加角色 wrapper；共享子套件仍必须沿 `preload(...)` 子树真实可达。
- 闸门脚本当前显式依赖 `godot`、`python3` 与 `rg`；缺少任一工具时必须直接 fail-fast，不做隐式 fallback。
- 正式角色 wrapper 统一登记在 `config/formal_character_manifest.json.characters[*]`，由 `tests/run_all.gd` 自动加载。
- `config/formal_character_manifest.json` 是 formal 角色元数据的唯一人工真源；顶层固定三桶：`characters / matchups / pair_interaction_specs`。
- `config/formal_character_capability_catalog.json` 是共享能力目录的唯一人工真源；这里只维护共享入口定义、规则归属、必挂 suite 和“该停下来改专用机制”的边界。实际消费者统一从 manifest 的 `shared_capability_ids` 派生。
- `characters[*]` 当前固定拆成 runtime 视图与 delivery/test 视图：
  - runtime：`character_id / unit_definition_id / formal_setup_matchup_id / pair_initiator_bench_unit_ids / pair_responder_bench_unit_ids / required_content_paths`，以及按需补的 `content_validator_script_path`
  - delivery/test：`character_id / display_name / design_doc / adjustment_doc / surface_smoke_skill_id / suite_path / required_suite_paths / required_test_names / shared_capability_ids / design_needles / adjustment_needles`
- runtime formal validator 当前统一由 `src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_registry.gd` 读取 `config/formal_character_manifest.json`；loader 只校验 runtime 视图与 validator 路径存在性，真正的 validator 实例化延迟到 `ContentSnapshotFormalCharacterValidator.validate()` 按 present-only 角色执行。测试、文档、suite reachability 与回归锚点也统一读取 manifest 派生视图；delivery/test 字段漂移不得拖死 runtime loader。
- `ContentSnapshotFormalCharacterValidator` 只校验当前快照里实际出现的正式角色，不会因为缺席角色而误炸。
- 正式角色 entry validator 当前固定按 `unit_passive_contracts / skill_effect_contracts / ultimate_domain_contracts` 三桶模板组织；tests 侧只验证这三个入口仍可实例化并回挂到 wrapper 子树。
- 正式角色的 `required_suite_paths` 不再手抄共享 capability suite 与 validator suite；这两类会自动并入 delivery/test 视图。角色专属子套件仍由 manifest 显式维护，部分共享但不属于 capability 派生的正式交付 suite 也可以继续显式挂在这里。
- 只要角色在 `shared_capability_ids` 里声明了共享入口，repo consistency gate 就会同时检查 capability catalog 是否存在该入口、catalog 要求的 `required_suite_paths` 是否已被自动派生、以及角色 `required_content_paths` 导出的语义事实是否真的对上对应的 `required_fact_ids`。
- 只要角色登记了 `content_validator_script_path`，delivery/test 视图就会自动并入 `tests/suites/extension_validation_contract_suite.gd`；`required_test_names` 里仍必须挂至少一个对应角色的 validator 坏例锚点。
- 共享能力未先登记进 capability catalog、或登记后没把对应 suite / manifest 消费声明 / 使用证据补齐时，`check_repo_consistency.sh` 会直接失败。
- `SampleBattleFactory.content_snapshot_paths_for_setup_result(battle_setup)` 是 formal manager smoke、pair smoke 与 formal demo replay 的默认快照入口；`content_snapshot_paths_result()` 只保留给全量正式快照与 baseline demo 这类不做 setup 裁剪的路径。
- `config/formal_character_manifest.json.matchups` 只显式维护样例/单角色 setup/`test_only` 特例 matchup；非 `test_only` 的 formal-vs-formal directed matchup 由 loader 按角色级 pair bench 输入自动派生，directed pair surface smoke 仍由 `matchups + characters[*].surface_smoke_skill_id` 运行时生成。
- `matchups[*].test_only` 可选；用于 `obito_mirror` 这类只服务测试/手动 setup 的 matchup。被标成 `test_only` 的 matchup 不会进入 directed surface smoke 矩阵，同角色 mirror matchup 也必须显式打这个标记。
- `tests/support/formal_pair_interaction/scenario_registry.gd` 当前是 pair interaction scenario runner 的单一真相；catalog 校验和运行分发都只能读这张映射，不再允许双维护场景列表。
- `pair_interaction_specs[*]` 每个无向正式 pair 只写一条规格，固定携带 `character_ids[2] / scenario_key / forward_battle_seed / reverse_battle_seed`；catalog loader 会从它派生两条 directed `pair_interaction_case`，并补齐 `test_name / matchup_id / scenario_key / character_ids[2] / battle_seed`。
- `tests/support/formal_pair_interaction/scenario_registry.gd` 只注册无向 `scenario_key`；runner 执行时读取的是已派生好的 directed case context，同一个 `scenario_key` 必须稳定生成正反两个方向。
- shared gate 现在直接按 manifest 派生出的非 `test_only` directed matchup 推导必备 interaction 覆盖；每个正式方向至少要有一条 `pair_interaction_case`，而且必须锁到正确的 `scenario_key`，不再额外维护 Python 里的手写场景常量表。
- 共享 pair surface / interaction 已不再逐角色手抄进 `required_test_names`；覆盖完整性统一由 shared gate 和 suite matrix contract 校验。
- `check_suite_reachability.sh` 只把 `run_all.gd` 和注册表里的 wrapper 当作入口；`required_suite_paths` 必须真的能从这些入口沿 `preload(...)` 子树走到，不能靠注册表直接兜底；当 wrapper 超过维护阈值时，真实断言统一下沉到同名子目录，例如 `tests/suites/manager_snapshot_public_contract_suite.gd` + `tests/suites/manager_snapshot_public_contract/*.gd`
- manager smoke 与 manager public contract 现在不允许再通过 `_debug_session` 之类私有钩子钻进内部 session。
- 当单测试文件接近 `500` 行时，先做预拆分评估；超过 `600` 行前必须完成按子域拆分。
- `tests/support/**/*.gd` 当前进入 `220..250` 行预警带就要预拆分，超过 `250` 行必须拆；`tests/gates/*.py` 当前进入 `350..400` 行预警带就要预拆分，超过 `400` 行必须拆。
- 若 wrapper 内部的执行顺序带语义依赖，必须在 wrapper 文件头注明“顺序不可调换”的原因。
