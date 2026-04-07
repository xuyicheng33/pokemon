# Tests Skeleton

本目录承载当前业务回归闸门与测试支撑脚手架。

- `suites/`: 业务回归测试套件
- `suites/*_suite.gd`: 优先作为顶层 wrapper 或按单一 contract 聚合的 suite；若文件足够小且不值得再拆，也允许直接在本文件注册具体 `_test_*`
- 当顶层 suite 超过维护阈值时，保持原 wrapper 文件名与测试名不变，并把断言本体下沉到同名子目录，例如 `suites/multihit_skill_runtime_suite.gd` + `suites/multihit_skill_runtime/*.gd`
- `suites/*_contract_suite.gd` / `suites/*_runtime_suite.gd` / 角色子套件：按单一子域拆分的真实断言文件
- `suites/adapter_contract_suite.gd`: manager 输出边界契约回归
- `suites/content_snapshot_cache_suite.gd`: manager 黑盒视角下的 content snapshot cache 语义等价回归
- `suites/content_snapshot_cache_composer_suite.gd`: composer 级共享 cache 的 hits/misses/size 统计与签名失效回归；当前同时锁顶层文件改动、外部资源依赖改动、`content/shared/` 共享 payload 改动、formal runtime registry 改动，以及 `src/battle_core/content/**/*.gd` / `src/battle_core/content/formal_validators/**/*.gd` 改动都会触发签名变化
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
- 正式角色 wrapper 统一登记在 `config/formal_character_delivery_registry.json`，由 `tests/run_all.gd` 自动加载。
- runtime registry 固定为 `config/formal_character_runtime_registry.json`：字段只保留 `character_id / unit_definition_id / formal_setup_matchup_id / required_content_paths`，以及按需补的 `content_validator_script_path`。
- delivery registry 固定为 `config/formal_character_delivery_registry.json`：字段固定为 `character_id / display_name / design_doc / adjustment_doc / surface_smoke_skill_id / suite_path / required_suite_paths / required_test_names / design_needles / adjustment_needles`。
- runtime formal validator 当前统一由 `src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_registry.gd` 读取 `config/formal_character_runtime_registry.json`；registry loader 只校验 runtime entry 形状与 validator 路径存在性，真正的 validator 实例化延迟到 `ContentSnapshotFormalCharacterValidator.validate()` 按 present-only 角色执行。测试、文档、suite reachability 与回归锚点统一读取 delivery registry。
- `ContentSnapshotFormalCharacterValidator` 只校验当前快照里实际出现的正式角色，不会因为缺席角色而误炸。
- 正式角色 entry validator 当前固定按 `unit_passive_contracts / skill_effect_contracts / ultimate_domain_contracts` 三桶模板组织；tests 侧只验证这三个入口仍可实例化并回挂到 wrapper 子树。
- 正式角色的 `required_suite_paths` 可以同时挂角色专属子套件与共享 suite；例如 `gojo_snapshot_suite.gd` / `sukuna_snapshot_suite.gd` 用来锁资源快照，`ultimate_field_suite.gd` 用来把共享领域回归正式挂回角色交付面。
- 只要角色登记了 `content_validator_script_path`，`required_suite_paths` 里就必须显式挂 `tests/suites/extension_validation_contract_suite.gd`，`required_test_names` 里也必须挂至少一个对应角色的 validator 坏例锚点。
- 带土当前也按同一机制挂接：`obito_suite.gd` 负责 wrapper，`obito_*` 子 suite 负责角色专项回归，`heal_extension_suite.gd / skill_execute_contract_suite.gd / multihit_skill_runtime_suite.gd` 作为带土依赖面的共享锚点继续挂在 delivery registry 里。
- `config/formal_matchup_catalog.json` 现在只保留 formal matchup 与 `pair_interaction_cases`；directed pair surface smoke 统一由 `matchups + delivery_registry.surface_smoke_skill_id` 运行时生成，`tests/suites/formal_character_pair_smoke_suite.gd` 只负责按生成结果动态注册和执行。
- `tests/support/formal_pair_interaction/scenario_registry.gd` 当前是 pair interaction scenario runner 的单一真相；catalog 校验和运行分发都只能读这张映射，不再允许双维护场景列表。
- `pair_interaction_cases[*]` 必须显式填写 `scenario_id / matchup_id / character_ids[2] / battle_seed`；catalog loader 与 shared gate 都会对空值、类型错误和不一致开局直接 fail-fast。
- 共享 pair surface / interaction 已不再逐角色手抄进 `required_test_names`；覆盖完整性统一由 shared gate 和 suite matrix contract 校验。
- `check_suite_reachability.sh` 只把 `run_all.gd` 和注册表里的 wrapper 当作入口；`required_suite_paths` 必须真的能从这些入口沿 `preload(...)` 子树走到，不能靠注册表直接兜底；当 wrapper 超过维护阈值时，真实断言统一下沉到同名子目录，例如 `tests/suites/manager_snapshot_public_contract_suite.gd` + `tests/suites/manager_snapshot_public_contract/*.gd`
- manager smoke 与 manager public contract 现在不允许再通过 `_debug_session` 之类私有钩子钻进内部 session。
- 当单测试文件接近 `500` 行时，先做预拆分评估；超过 `600` 行前必须完成按子域拆分。
- `tests/support/**/*.gd` 当前进入 `220..250` 行预警带就要预拆分，超过 `250` 行必须拆；`tests/gates/*.py` 当前进入 `350..400` 行预警带就要预拆分，超过 `400` 行必须拆。
- 若 wrapper 内部的执行顺序带语义依赖，必须在 wrapper 文件头注明“顺序不可调换”的原因。
