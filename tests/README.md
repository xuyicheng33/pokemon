# Tests Skeleton

本目录承载当前静态门禁、诊断脚本、共享辅助资源，以及 `gdUnit4` 的命令行入口。

当前日常研发顺序、Sandbox 试玩路径和文档更新要求，统一见 `docs/design/current_development_workflow.md`。

- `test/suites/`: Godot 业务回归 suite 唯一目录；`gdUnit4` 会直接发现 `test/` 下的业务 suite
- `test/support/`: `gdUnit4` suite 公共基类与少量桥接资源
- `tests/support/`: 共享 harness、构局 helper、固定案例 support；供 `gdUnit4` suite、导出脚本与诊断 runner 复用
- `tests/run_gdunit.sh`: `gdUnit4` CLI 入口；默认跑 `res://test`，并输出 `JUnit XML` 与 `HTML` 报告
- `tests/run_with_gate.sh`: 唯一总入口；串起 `gdUnit4`、boot smoke、架构 gate、repo consistency gate
- `tests/check_suite_reachability.sh`: suite 可达性闸门；确保 manifest 里的 `required_suite_paths` 都落在 `test/` 下，且 gdUnit 树里不再出现 `register_tests()`
- `tests/check_architecture_constraints.sh`: 分层与大文件架构闸门
- `tests/gates/architecture_wiring_graph_gate.py`: runtime wiring 图 DAG 闸门；要求当前属性注入图无闭环
- `tests/check_repo_consistency.sh`: README / 文档 / 关键回归一致性闸门总入口
- `tests/gates/`: 仓库一致性细分 gate；当前按 `surface / formal_character / docs` 三类拆开维护
- `tests/fixtures/`: 预留样例输入与内容快照目录
- `tests/helpers/`: 测试辅助脚本目录
- `tests/replay_cases/`: 固定 replay 案例与说明目录（当前包含领域案例与鹿紫云案例）
- `tests/helpers/domain_case_runner.gd`: 固定领域案例 runner；用于在门禁异常或契约漂移时快速复查具体局面
- `tests/helpers/kashimo_case_runner.gd`: 固定鹿紫云案例 runner；用于快速复查电荷主循环、琥珀换人与弥虚葛笼对 Gojo 真领域

当前约定：

- `tests/run_with_gate.sh` 是唯一总入口；本地快跑 `gdUnit4` 时直接使用 `tests/run_gdunit.sh`
- `tests/run_gdunit.sh` 默认以 `res://test` 为入口，支持 `TEST_PATH` 过滤单 suite / 单目录，报告落在 `REPORT_DIR`；CI 与本地都统一消费 `JUnit XML` 与 `HTML`
- `BattleSandbox` 的场景回归当前固定看 `TEST_PATH=res://test/suites/manual_battle_scene_suite.gd bash tests/run_gdunit.sh`
- `BattleSandbox` 的整局 headless 复查看 `godot --headless --path . --script tests/helpers/manual_battle_full_run.gd`
- `manual_battle_full_run.gd` 当前支持 `MATCHUP_ID / BATTLE_SEED / P1_MODE / P2_MODE`；主用途是快速复查 `manual/manual`、`manual/policy` 与 `policy/policy`
- 闸门脚本当前显式依赖 `godot`、`python3` 与 `rg`；缺少任一工具时必须直接 fail-fast，不做隐式 fallback
- `config/formal_character_manifest.json` 是 formal 角色元数据的唯一人工真源；顶层固定两桶：`characters / matchups`，pair interaction 的唯一手写输入固定挂在 `characters[*].owned_pair_interaction_specs`
- `config/formal_character_capability_catalog.json` 是共享能力目录的唯一人工真源；这里只维护共享入口定义、规则归属、必挂 suite 和“该停下来改专用机制”的边界。实际消费者统一从 manifest 的 `shared_capability_ids` 派生
- `characters[*]` 当前固定拆成 runtime 视图与 delivery/test 视图：
  - runtime：`character_id / unit_definition_id / formal_setup_matchup_id / pair_token / baseline_script_path / pair_initiator_bench_unit_ids / pair_responder_bench_unit_ids / owned_pair_interaction_specs / required_content_paths`，以及按需补的 `content_validator_script_path`
  - delivery/test：`character_id / display_name / design_doc / adjustment_doc / surface_smoke_skill_id / suite_path / required_suite_paths / required_test_names / shared_capability_ids / design_needles / adjustment_needles`
- runtime formal validator 当前统一由 `src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_registry.gd` 读取 `config/formal_character_manifest.json`；loader 只校验 runtime 视图与 validator 路径存在性，真正的 validator 实例化延迟到 `ContentSnapshotFormalCharacterValidator.validate()` 按 present-only 角色执行
- `ContentSnapshotFormalCharacterValidator` 只校验当前快照里实际出现的正式角色，不会因为缺席角色而误炸
- 正式角色 entry validator 当前固定按 `unit_passive_contracts / skill_effect_contracts / ultimate_domain_contracts` 三桶模板组织；tests 侧只验证这三个入口仍可实例化并回挂到 gdUnit suite 锚点
- `required_suite_paths` 现在只要求显式落在 `test/` 下；gdUnit 直接发现 suite，不再依赖手工聚合入口或 wrapper preload reachability
- `required_test_names` 继续作为 repo consistency gate 的回归锚点；每个名字都必须在 `suite_path + required_suite_paths` 对应的 gdUnit suite 树里找到 `func test_<name>()`
- 只要角色在 `shared_capability_ids` 里声明了共享入口，repo consistency gate 就会同时检查 capability catalog 是否存在该入口、catalog 要求的 `required_suite_paths` 是否已被自动派生、以及角色 `required_content_paths` 导出的语义事实是否真的对上对应的 `required_fact_ids`
- 只要角色登记了 `content_validator_script_path`，delivery/test 视图就会自动并入 `test/suites/extension_validation_contract_suite.gd`；`required_test_names` 里仍必须挂至少一个对应角色的 validator 坏例锚点
- `SampleBattleFactory.content_snapshot_paths_for_setup_result(battle_setup)` 是 formal manager smoke、pair smoke 与 formal demo replay 的默认快照入口；`content_snapshot_paths_result()` 只保留给全量正式快照与 baseline demo 这类不做 setup 裁剪的路径
- `config/formal_character_manifest.json.matchups` 只显式维护样例/单角色 setup/`test_only` 特例 matchup；非 `test_only` 的 formal-vs-formal directed matchup 由 loader 按 `pair_token + pair_initiator_bench_unit_ids + pair_responder_bench_unit_ids` 自动派生，`formal_setup_matchup_id` 只服务默认 formal setup 入口，directed pair surface smoke 仍由 `matchups + characters[*].surface_smoke_skill_id` 运行时生成
- `tests/support/formal_pair_interaction/scenario_registry.gd` 当前是 pair interaction scenario runner 的单一真相；catalog 校验和运行分发都只能读这张映射，不再允许双维护场景列表
- `owned_pair_interaction_specs[*]` 固定挂在角色条目上，字段为 `other_character_id / scenario_key / owner_as_initiator_battle_seed / owner_as_responder_battle_seed`；manifest 第 `i` 个角色只能声明与更早角色的 pair，catalog loader 会从它派生两条 directed `pair_interaction_case`
- shared gate 现在直接按 manifest 派生出的非 `test_only` directed matchup 推导必备 interaction 覆盖；每个正式方向至少要有一条 `pair_interaction_case`，而且必须锁到正确的 `scenario_key`
- manager smoke 与 manager public contract 现在不允许再通过 `_debug_session` 之类私有钩子钻进内部 session
- 当单测试文件接近 `500` 行时，先做预拆分评估；超过 `600` 行前必须完成按子域拆分
- `tests/support/**/*.gd` 当前进入 `220..250` 行预警带就要预拆分，超过 `250` 行必须拆；`tests/gates/*.py` 当前进入 `350..400` 行预警带就要预拆分，超过 `400` 行必须拆
