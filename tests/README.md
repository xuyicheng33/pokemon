# Tests Skeleton

本目录承载当前业务回归闸门与测试支撑脚手架。

- `suites/`: 业务回归测试套件
- `suites/*_suite.gd`: 优先作为顶层 wrapper 或按单一 contract 聚合的 suite；若文件足够小且不值得再拆，也允许直接在本文件注册具体 `_test_*`
- `suites/*_contract_suite.gd` / `suites/*_runtime_suite.gd` / 角色子套件：按单一子域拆分的真实断言文件
- `suites/adapter_contract_suite.gd`: manager 输出边界契约回归
- `suites/content_snapshot_cache_suite.gd`: manager 黑盒视角下的 content snapshot cache 语义等价回归
- `suites/content_snapshot_cache_composer_suite.gd`: composer 级共享 cache 的 hits/misses/size 统计与签名失效回归
- `suites/passive_item_contract_suite.gd`: 最小正式 passive item 内容、runtime、manager 与 replay 黑盒回归
- `suites/trigger_validation_suite.gd`: 触发器声明一致性校验回归
- `suites/heal_extension_suite.gd`: `missing_hp` 百分比治疗与 `incoming_heal_final_mod` 共享回归
- `suites/skill_execute_contract_suite.gd`: 技能级 `execute_*` 共享契约回归
- `suites/multihit_skill_runtime_suite.gd`: `damage_segments` 与 `on_receive_action_damage_segment` 共享回归
- `support/`: 测试 harness、公共构造器与 suite 级共享 helper
- `run_all.gd`: Godot 原生测试入口（业务断言）
- `run_with_gate.sh`: 闸门脚本（业务断言 + 引擎级错误检查 + 架构约束 + 仓库一致性）
- `check_suite_reachability.sh`: suite 可达性闸门；确保 `tests/suites/*.gd` 都能从 `run_all.gd` 或正式角色 wrapper 子树走到
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
- 正式角色 wrapper 统一登记在 `config/formal_character_registry.json`，由 `tests/run_all.gd` 自动加载。
- 正式角色注册表除 `suite_path` 外，还要显式登记 `sample_setup_method / required_suite_paths / required_test_names`，把样例构局入口、角色 suite 子树与关键回归锚点一并固定下来。
- runtime formal validator 当前统一由 `src/battle_core/content/content_snapshot_formal_character_registry.gd` 读取 `config/formal_character_registry.json` 并动态装配；这份 registry 同时承载测试/文档/交付面元数据与可选 `content_validator_script_path`。
- `ContentSnapshotFormalCharacterValidator` 只校验当前快照里实际出现的正式角色，不会因为缺席角色而误炸。
- 正式角色 entry validator 当前固定按 `unit_passive_contracts / skill_effect_contracts / ultimate_domain_contracts` 三桶模板组织；tests 侧只验证这三个入口仍可实例化并回挂到 wrapper 子树。
- 正式角色的 `required_suite_paths` 可以同时挂角色专属子套件与共享 suite；例如 `gojo_snapshot_suite.gd` / `sukuna_snapshot_suite.gd` 用来锁资源快照，`ultimate_field_suite.gd` 用来把共享领域回归正式挂回角色交付面。
- 只要角色登记了 `content_validator_script_path`，`required_suite_paths` 里就必须显式挂 `tests/suites/extension_validation_contract_suite.gd`，`required_test_names` 里也必须挂至少一个对应角色的 validator 坏例锚点。
- 带土当前也按同一机制挂接：`obito_suite.gd` 负责 wrapper，`obito_*` 子 suite 负责角色专项回归，`heal_extension_suite.gd / skill_execute_contract_suite.gd / multihit_skill_runtime_suite.gd` 作为带土依赖面的共享锚点继续挂在 formal registry 里。
- `tests/suites/formal_character_pair_smoke_suite.gd` 当前固定承担正式角色跨配对黑盒 smoke，避免配对覆盖长期偏在 Gojo 对局。
- `check_suite_reachability.sh` 只把 `run_all.gd` 和注册表里的 wrapper 当作入口；`required_suite_paths` 必须真的能从这些入口沿 `preload(...)` 子树走到，不能靠注册表直接兜底。
- manager smoke 与 manager public contract 现在不允许再通过 `_debug_session` 之类私有钩子钻进内部 session。
- 当单测试文件接近 `500` 行时，先做预拆分评估；超过 `600` 行前必须完成按子域拆分。
- 若 wrapper 内部的执行顺序带语义依赖，必须在 wrapper 文件头注明“顺序不可调换”的原因。
