# 任务清单（活跃）

本文件只保留当前仍直接影响交付、门禁或下一步开发节奏的任务入口。

更早且已关闭的完整记录见：

- `docs/records/archive/tasks_2026-04-19_engineering_overhaul.md`
- `docs/records/archive/tasks_2026-04-10_to_2026-04-18_refactor_wave.md`
- `docs/records/archive/tasks_pre_2026-04-05_repair_wave.md`
- `docs/records/archive/tasks_pre_v0.6.4.md`
- `docs/records/archive/tasks_pre_v0.6.3.md`

当前生效规则以 `docs/rules/` 为准；工程结构与交付模板以 `docs/design/` 为准。
带日期的已完成阶段只保留当前仍有引用价值的摘要；完整流水统一看 archive。

## 最近完成：架构审阅第三轮清理（2026-04-24）

- 状态：已完成
- 目标：清理残留分支，修复架构审阅报告中所有优先级项目
- 范围：
  1. 合并 `codex/formal-automation-polish` 分支到 main，解决全部冲突，删除远端分支
  2. A2: `BattleState` unit 查找加 Dictionary 索引（O(1) 代替 O(n*m)）
  3. A3: `BaselineLoader` static cache 在 `SampleBattleFactory._init()` 时 invalidate
  4. B6: `ContentSchema` 的 `MANAGED_ACTION_TYPES` / `ALWAYS_ALLOWED_ACTION_TYPES` 从 mutable `static var` 改为 `static func`
  5. B8: Kashimo validator 拆分 ultimate domain 到子 validator（418→319+114 行）
  6. B1: 为 22 个缺返回类型标注的函数补 `-> Variant`
  7. B7: sandbox envelope 非标准 `summary` 字段收进 `data`
  8. B5: SampleBattleFactory helper 评估，调整软上限为 10 个
  9. B3/B2/B4: has_method / Variant 收窄 / ok_result codestyle 方向记录到 decisions.md
  10. C1: `BattleState.to_stable_dict` 缺字段注释
  11. C3: dedupe key 管道符约束注释
  12. C6: CI 加 Python lint（ruff）
- 验收标准：全部修复项落地、提交、推送

## 最近完成：架构审阅第二轮优化（2026-04-24）

- 状态：已完成
- 目标：修复架构审阅中发现的结构性和防御性问题
- 范围：
  1. `manifest_views.gd` 拆分 pair interaction 派生逻辑到 `formal_character_manifest_pair_interaction_builder.gd`（views 471→178 行，builder 309 行）
  2. `pair_token` 不含下划线约束：脚手架 + manifest loader 双重校验
  3. `BaselineLoader` 加 static cache 避免重复 manifest JSON 解析
  4. Gate stale needle 检查从硬编码列表改为正则模式，新角色自动覆盖
  5. decisions.md 补充三条规范：validator 拆分阈值（400 行）、factory helper 上限（5 个）、test/ vs tests/ 约定
  6. ResultEnvelope wrapper 模式确认为可接受约定并记录
- 验收标准：行为不变，结构更清晰，防御性校验更完整

## 最近完成：项目架构审阅问题清理（2026-04-24）

- 状态：已完成
- 目标：修复架构审阅中发现的 7 项代码质量问题
- 范围：
  1. 澄清 `PayloadExecutor._leave_effect_guard` dedupe key 生命周期意图（注释）
  2. 澄清 `ContentSnapshotCache` signature 路径列表的维护约定（注释）
  3. 提取 `ResourcePathHelper`，消除 6 处 `normalize_resource_path` 重复实现
  4. `FormalRegistryContracts.load_contracts_result()` 加实例级缓存，避免重复读文件
  5. `ContentSnapshotFormalCharacterRegistry` 返回格式统一为 `ResultEnvelopeHelper` 标准 envelope
  6. Gojo/Sukuna/Kashimo validator 中可替代的内联 effect contract dict 改为 baseline 引用
  7. `SampleBattleFactory.dispose()` 提取 `_nullify_links` 简化循环引用清理
- 验收标准：行为不变，代码重复减少，格式统一
- 验证：待闸门验证

## 最近完成：Formal 草稿晋升前检查入口（2026-04-24）

- 状态：已完成
- 目标：给新角色脚手架草稿增加晋升前的独立检查，避免手工搬文件时把占位符或缺文件带入正式目录
- 范围：
  1. 新增 `scripts/check_formal_character_draft_ready.py/.sh`
  2. 检查 source draft、baseline、validator、suite、设计文档和 pair runner 草稿是否齐全
  3. 检查 `FILL_IN / FORMAL_DRAFT_ / draft_marker / TODO: implement / interaction placeholder` 等占位符，以及 live 目标路径冲突
  4. 在脚手架输出、正式角色接入清单和当前工作流里记录入口
- 验收标准：
  - 无草稿时脚本可安全跳过
  - 有草稿但未填完占位符时脚本失败
  - repo consistency gate 继续锁住文档入口

## 最近完成：Pair interaction 顺序归属合同显式化（2026-04-24）

- 状态：已完成
- 目标：把 manifest 顺序承担 pair interaction ownership 的隐含规则写入正式文档，并用 gate 防止实现/文档漂移
- 范围：
  1. `formal_character_delivery_checklist.md` 明确新角色默认追加到 manifest 末尾，不能为排序美观重排既有正式角色
  2. `battle_content_schema.md` 与 `decisions.md` 同步记录 manifest 角色顺序是 pair interaction ownership 的稳定输入
  3. repo consistency gate 同时锁文档措辞与 `formal_character_pair_interaction_case_builder.gd` 的 earlier-character 约束
- 验收标准：
  - 后续扩角时不会误把 manifest 顺序当纯展示排序
  - gate 能发现 pair ownership 实现或规范文字被移除

## 最近完成：Sandbox 推荐入口去角色硬编码（2026-04-24）

- 状态：已完成
- 目标：把扩角前审阅发现的 sandbox 推荐列表和 quick smoke 手写角色名移到 manifest 派生
- 范围：
  1. `BattleSandboxLaunchConfig.recommended_matchup_ids()` 从 formal runtime entries 的 `formal_setup_matchup_id` 派生推荐 matchup，并追加 `sample_default`
  2. 命令行启动配置默认带 `strict_config=true`，拼错 matchup / mode / seed / control mode 直接暴露错误
  3. `tests/check_sandbox_smoke_matrix.sh` 的 quick 集合读取 sandbox smoke catalog 导出的推荐 matchup，不再硬编码当前四个正式角色
- 验收标准：
  - 新角色使用自定义 `formal_setup_matchup_id` 时，sandbox 推荐排序和 quick smoke 自动跟随 manifest
  - 默认 CLI/debug 启动不再静默吞掉非法配置
  - launch-config suite 与 sandbox smoke matrix 通过

## 最近完成：扩角前审阅问题修复（2026-04-24）

- 状态：已完成
- 目标：修复扩角前架构审阅确认的问题，降低新增角色后的自动化误判和验证成本
- 范围：
  1. `manual_battle_full_run.gd` / `manual_battle_submit_full_run.gd` 不再预先吞掉非法 `BATTLE_SEED`，strict config 统一负责失败判定
  2. `tests/check_sandbox_smoke_matrix.sh` 增加 `SANDBOX_SMOKE_SCOPE=quick|full`，日常 gate 默认 quick，按需 full 覆盖全部可见 matchup
  3. `demo_profile_ids_result` contract 不再写死当前 profile 全集，只锁默认优先与剩余稳定排序
  4. 文档同步 submit 入口真实覆盖口径，避免把重复脚本误读成额外行为面
- 验收标准：
  - 非法 sandbox seed 在 strict helper 路径失败
  - 日常 sandbox smoke 不随 formal directed matchup 二次方增长
  - 新增 demo profile 不会被旧单测硬编码阻断
  - `bash tests/run_with_gate.sh` 通过
- 验证结果：`git diff --check`、非法 `BATTLE_SEED=-99` strict 反向检查、`bash tests/check_repo_consistency.sh`、`bash tests/check_sandbox_smoke_matrix.sh` 与 `bash tests/run_with_gate.sh` 均通过；总 gate 为 `425 test cases / 0 failures`

## 最近完成：formal 接线自动化与 Sandbox smoke 动态化（2026-04-22）

- 状态：已完成
- 目标：继续扩角前，把 formal 角色接入末端的手工步骤和 sandbox smoke 的硬编码名单进一步收口
- 范围：
  1. `FormalCharacterManifestViews` 默认自动派生 `<pair_token>_vs_sample` matchup，formal setup 不再强依赖手工改 `00_shared_registry.json`
  2. `tests/support/formal_pair_interaction/scenario_registry.gd` 改为自动发现 `tests/support/formal_pair_interaction/*_cases.gd`，新增角色不再手工注册 scenario runner
  3. `scripts/new_formal_character.py` 同步改为生成 `build_runners()` 壳子，并把 shared matchup / pair interaction 说明改成新的自动化流程
  4. `tests/check_sandbox_smoke_matrix.sh` 改为动态覆盖全部可见 matchup、默认模式变体、真实 submit 路径和全部 demo profile
  5. 补 `demo_profile_ids_result()`、sandbox smoke catalog helper、pair runner key export helper 与对应 contract/gate 对齐
- 验收标准：新增角色默认接线步骤更少，sandbox 主 smoke 自动跟随当前 manifest/demo 真相，现有 gate 与主回归继续通过
- 验证结果：`bash tests/run_with_gate.sh` 通过，`421 test cases / 0 failures`；动态 sandbox smoke 已覆盖全部可见 matchup、默认模式变体、真实 submit 路径和全部 demo replay

## 最近完成：扩角前架构审阅问题收口（2026-04-24）

- 状态：已完成
- 目标：接入新角色前，把审阅发现的脚手架、运行时配置、缓存签名和 manifest 体量风险收口
- 范围：
  1. `scripts/new_formal_character.py` 遇到坏 descriptor 直接失败；未完成 baseline / validator / suite / design doc 统一进入 `scripts/drafts/` 镜像路径
  2. formal live gate 扫描 `FORMAL_DRAFT_` / `draft_marker`，并阻断 live validator 中残留的 `pass`
  3. `BattleSandboxLaunchConfig` 新增 strict normalize 入口；测试与脚本 smoke 入口启用 strict config，非法 matchup / mode / seed / control mode 不再静默改成默认值
  4. `ContentSnapshotCache` 签名依赖缺失时直接失败，并暴露具体缺失路径；缓存签名继续覆盖 formal source / baseline / capability / validator 输入
  5. `formal_character_manifest_views.gd` 抽出 pair interaction case builder，主文件从 502 行降到 369 行
  6. `tests/godot_headless_env.sh` cleanup 后清理 Godot headless 环境变量，避免同 shell 重复 setup 指向已删除目录
- 验收标准：
  - 新角色草稿不会污染正式目录
  - 测试入口不会把拼错的 sandbox 配置当默认局跑成功
  - 内容快照签名依赖缺失不再被弱签名掩盖
  - manifest views 不再触发架构体量预警
- 验证结果：分批定向 gdUnit、`check_repo_consistency`、`check_architecture_constraints`、`check_sandbox_smoke_matrix` 已通过；最终总 gate 见本轮提交记录

## 最近完成：扩角前文档口径修正与脚手架增强（2026-04-22）

- 状态：已完成
- 目标：统一文档口径冲突，增强脚手架覆盖 pair interaction 层，降低下一个正式角色接入的手工成本
- 范围：
  1. 修正 `decisions.md` pair 覆盖模型描述：从"允许同 pair 多 case"改为"每个无序 pair 恰好 1 条 spec"，与 gate 和 checklist 保持一致
  2. 修正 `formal_character_delivery_checklist.md` SampleBattleFactory 条目：明确已有动态入口 `build_formal_character_setup_result(character_id)`，不需要手动加构局方法
  3. 修正 `project_folder_structure.md`：删掉不存在的 `assets/` 目录及相关约束
  4. 增强 `scripts/new_formal_character.py`：
     - 新增 `collect_existing_characters()` 自动发现已有正式角色
     - `generate_source_descriptor()` 自动生成 `owned_pair_interaction_specs` 占位（含所有已有角色）
     - 新增 `generate_interaction_cases()` 生成 pair interaction runner 壳子
     - main 流程扩充到 8 步，第 7 步生成 interaction cases 文件，第 8 步打印 scenario_registry.gd 注册提示
     - checklist 输出补充 pair interaction 层的完整操作说明
- 验收标准：文档口径统一，脚手架幂等无破坏，现有闸门不受影响
- 验证结果：`bash tests/run_with_gate.sh` 通过，`421 test cases / 0 failures`；repo consistency / formal pair coverage / 文档入口对齐 gate 全部通过

## 最近完成：提取 TurnExpiryDecrementHelper 消除 turn 阶段重复代码（2026-04-22）

- 状态：已完成
- 目标：消除 TurnStartExpiryService 与 TurnEndPhaseService 之间的 4 个重复方法，补齐 `_unit_has_persistent_effect` 缺失的 UnitState 类型标注
- 范围：
  - 新增 `src/battle_core/turn/turn_expiry_decrement_helper.gd`，承载 `collect_effect_decrement_owner_ids`、`decrement_effect_instances_and_log`、`decrement_rule_mods_and_log`、`_unit_has_persistent_effect` 共 4 个方法
  - 重构 `turn_start_expiry_service.gd` 和 `turn_end_phase_service.gd`，改为委托 helper
  - 更新 README 代码行数统计
- 验收标准：闸门全通过，行为不变
- 验证结果：419 test cases / 0 failures，所有架构约束和 sandbox smoke matrix 通过

## 最近完成：Sandbox 正式角色覆盖补齐（2026-04-21）

- 状态：已完成
- 目标：在继续下一个正式角色开发前，补齐 BattleSandbox 推荐对局和 smoke matrix 对已交付角色的可见覆盖
- 范围：
  1. `BattleSandboxLaunchConfig` 推荐 matchup 顺序加入 `obito_vs_sample`
  2. `tests/check_sandbox_smoke_matrix.sh` 固定补跑 `obito_vs_sample + manual/policy` 与 `sukuna_setup + manual/policy`
  3. README 与 launch config contract suite 同步到新的推荐顺序和 smoke 覆盖面
- 验证：
  - `TEST_PATH=res://test/suites/battle_sandbox_launch_config_contract_suite.gd bash tests/run_gdunit.sh`
  - `bash tests/check_sandbox_smoke_matrix.sh`
  - `bash tests/run_with_gate.sh`

## 最近完成：深度审查 9 项问题修复（2026-04-21）

- 状态：已完成
- 目标：修复仓库深度审查确认的 3 个阻断级 + 6 个重要级问题
- 范围：
  1. （阻断）`turn_start_phase_service` 在 expiry phase 后补 `faint_resolver.resolve_faint_window` + victory check
  2. （阻断）`sample_battle_factory_baseline_matchup_catalog.available_matchups_result()` formal catalog 失败时 graceful 降级，不再拖死 baseline/demo
  3. （阻断）`check_sandbox_smoke_matrix.sh` 标注"manual 路径实际由 auto-policy 驱动"已知限制
  4. （重要）`replay_runner_output_helper` + `replay_output` 的 `event_log` / `battle_result` 改为 deep copy，断开 live 引用
  5. （重要）`field_apply_service` 在取 `challenger_field_definition` 后立刻判空，fail-fast
  6. （重要）`effect_queue_service` tie group 分配 random roll 前按 `event_id` 排序，消除收集顺序对 RNG 的影响
  7. （重要）`sample_battle_factory_baseline_matchup_catalog` 三个 override 函数各归各位，不再互相污染
  8. （重要）`effect_instance_dispatcher` dangling owner 从 `continue` 改为 fail-fast 返回 `INVALID_STATE_CORRUPTION`
  9. （重要）`content_snapshot_effect_validator._uses_effect_scope_unit_target` 添加 `ForcedReplacePayload`
- 验证：`bash tests/run_with_gate.sh`

## 最近完成：审阅问题修复收口（2026-04-20）

- 状态：已完成
- 目标：把本轮详细审查确认的工程问题直接修回脚本、gate 与记录
- 范围：
  1. 修复 `tests/run_gdunit.sh` 的 `GODOT_BIN` 闭合问题
  2. 修复 formal scaffold 的 source index 与 drafts 脱节问题
  3. 把 tests support helper 体量 gate 调回当前决策记录约定
- 修复内容：
  1. `tests/run_gdunit.sh` 改为统一校验并复用 `GODOT_BIN_PATH`，不再在收尾日志复制步骤偷偷回退到裸 `godot`
  2. `scripts/new_formal_character.py` 的 `next_source_index()` 现在同时扫描 `config/formal_character_sources/` 与 `scripts/drafts/`，避免连续 scaffold 时重复占号
  3. `tests/check_architecture_constraints.sh` 把 tests support helper 阈值恢复到 `220..250` 预警、`>250` 失败，重新和 `docs/records/decisions.md` 对齐
- 验证：
  - `GODOT_BIN="$(command -v godot)" TEST_PATH=res://test/suites/composition_container_contract_suite.gd bash tests/run_gdunit.sh`
  - `python3 scripts/new_formal_character.py review_probe_alpha "审查探针A"`
  - `python3 scripts/new_formal_character.py review_probe_beta "审查探针B"`
  - `bash tests/check_architecture_constraints.sh`
  - `bash tests/run_with_gate.sh`

## 最近完成：长期工程化重构波次（2026-04-19）

- 状态：已完成
- 总体目标：项目定位从"原型期"升级为长期工程，清理过度工程化的形式噪声，保留工程严谨性
- 分阶段结果：

| Stage | 内容 | 状态 |
|---|---|---|
| 0 | 统一定位与活跃规则基线 | 已完成 |
| 1 | composition 盘点 + 目标图冻结 + 错误体系设计 + payload dispatch 决策 | 已完成 |
| 2 | composition 主链路收缩（81→65 slot, 16 helper 下沉） | 已完成 |
| 3 | 错误体系统一（B/C 类内联/重命名） | 已完成 |
| 4 | 测试修复 + 死代码清理 | 已完成 |
| 5 | 测试结构评估（降级保留） | 已完成 |
| 6 | 文档 + gate 合并（降级保留） | 已完成 |
| 7 | 核心类型标注 | 已完成 |

- 验证：`bash tests/run_with_gate.sh` 全通过
- 详细子阶段记录见 `docs/records/archive/tasks_2026-04-19_engineering_overhaul.md`

## 最近完成：代码审阅修复（2026-04-19）

- 状态：已完成
- 目标：审阅当前实现并修复发现的问题
- 修复内容：
  1. `battle_core → composition` 逆向依赖：文档标注为受控例外 + architecture gate 增加白名单校验
  2. 核心函数参数类型标注：`battle_core` 119 个文件补齐 `BattleState / BattleContentIndex / ChainContext / QueuedAction / EffectEvent / Command` 的显式类型
  3. 冗余 `.gitkeep` 清理：移除 `content/` 下 7 个已有实际内容的目录中的 `.gitkeep`
- 验证：全部 gate 通过

## 最近完成：gate 修复收口（2026-04-19）

- 状态：已完成
- 目标：修复本轮类型标注后遗留的 gate 失败，恢复主线验证基线
- 修复内容：
  1. 强类型测试替身补齐：`sukuna_setup_skill_runtime_suite`、`field_lifecycle_contract_suite`、`manager_log_and_runtime_contract/replay_guard_failure_suite` 改为继承真实 service / resolver / dispatcher 类型，不再向强类型字段写入裸 `RefCounted`
  2. 期望伤害辅助同步 fake resolver：`tests/support/sukuna_setup_regen_test_support.gd` 新增可注入 `PowerBonusResolver`，保证 delegation contract 测试和运行时走同一套口径
  3. gdUnit warning 清零：`effect_precondition_service`、`payload_executor`、`action_chain_context_builder` 的 ternary 类型不兼容改成显式分支
  4. README 代码规模统计回写到当前真值，修复 repo consistency surface gate
- 验证：
  - `TEST_PATH=res://test/suites/sukuna_setup_skill_runtime_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/field_lifecycle_contract_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/manager_log_and_runtime_contract/replay_guard_failure_suite.gd bash tests/run_gdunit.sh`
  - `bash tests/check_gdunit_gate.sh`
  - `bash tests/run_with_gate.sh`

## 最近完成：formal 自动化审阅问题修复（2026-04-24）

- 状态：已完成
- 目标：修复 formal 自动化接入审阅中确认的问题，暂不拆分 `FormalCharacterManifestViews`
- 范围：
  1. 修复内容快照缓存签名遗漏 formal baseline/source/capability 输入的问题
  2. 收紧新角色 scaffold 的命名校验与 pair interaction 草稿流转
  3. 增加 live scaffold 占位符 gate，避免占位 runner 或 `FILL_IN` 进入正式目录
  4. 清理本地 `.DS_Store` 噪声
- 验收标准：
  - cache signature 会随 formal baseline/source/capability 相关输入变化而变化
  - draft pair interaction runner 不会被 live registry 自动发现
  - live formal 目录中出现 scaffold 占位符时 repo consistency gate 会失败
  - `bash tests/run_with_gate.sh` 通过

## 最近完成：审阅问题补齐（2026-04-20）

- 状态：已完成
- 目标：把 2026-04-19 全部提交复查后确认的问题补齐到代码、gate 和文档
- 修复内容：
  1. manager replay 容器依赖补校验：`BattleCoreManagerContainerService.run_replay_result()` 现在显式校验 `replay_runner`，缺失时返回 `invalid_composition` 并释放临时容器；补了对应 contract suite
  2. sandbox smoke 合同对齐真实 battle contract：`winner_side_id` 只在 `result_type=win` 时要求非空，`draw / no_winner` 必须保持为空
  3. `manual/manual` 主路径补成真实整局回归：`tests/check_sandbox_smoke_matrix.sh` 新增 `gojo_vs_sample + manual/manual` 覆盖，README 与当前阶段基线同步回写
- 验证：
  - `TEST_PATH=res://test/suites/manager_log_and_runtime_contract/replay_guard_summary_suite.gd bash tests/run_gdunit.sh`
  - `bash tests/check_sandbox_smoke_matrix.sh`
  - `bash tests/run_with_gate.sh`

## 最近完成：审阅问题收口（2026-04-20）

- 状态：已完成
- 目标：把复查后确认需要落地的两项工程问题直接收口到代码与记录
- 范围：
  1. 收紧 `container_factory_owner` 的类型边界，去掉 facade 层对裸 `RefCounted` + `has_method("error_state")` 的依赖
  2. 提升 formal validator 共享 helper，收口 Kashimo / Obito 中重复的 payload 断言样板
  3. 不改双轨错误模型，不引入 `BattleState` 索引缓存
- 修复内容：
  1. 新增 `ContainerFactoryOwnerPort`，`BattleCoreComposer.ContainerFactoryPort` 显式继承该 port；manager/container service 不再把 factory owner 写成裸 `RefCounted`
  2. `BattleCoreManagerContainerService` 去掉对 `container_factory_owner.has_method("error_state")` 的鸭子类型分支，统一走显式 port 合同
  3. formal validator 共享 helper 新增按脚本提取 payload、按类型校验 payload、按字段匹配 payload 三个通用方法
  4. Kashimo `amber_contract` 与 Obito `yinyang_dun` 的重复 payload 断言改走共享 helper，保持原合同语义不变
- 验证：
  - `TEST_PATH=res://test/suites/composition_container_contract_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/manager_log_and_runtime_contract/replay_guard_summary_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/content_validation_core/formal_registry/runtime_registry_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/extension_validation_contract/kashimo_bad_cases_suite.gd bash tests/run_gdunit.sh`
  - `TEST_PATH=res://test/suites/extension_validation_contract/obito_bad_cases_suite.gd bash tests/run_gdunit.sh`
  - `bash tests/check_architecture_constraints.sh`
  - `bash tests/check_repo_consistency.sh`

## 最近完成：formal 新角色接入脚手架（2026-04-20）

- 状态：已完成
- 目标：降低新正式角色接入的手工成本，为 source descriptor、baseline、validator、test suite 提供模板生成
- 范围：
  1. 新增脚手架脚本 `scripts/new_formal_character.sh`（bash wrapper）+ `scripts/new_formal_character.py`（Python 生成逻辑）
  2. 自动生成：source descriptor、baseline 脚本、validator 脚本、snapshot/runtime/manager smoke 三个 suite 壳子、content 目录占位、设计稿占位
  3. 不改现有 formal 模型、gate、`COMPOSE_DEPS` 边界、battle_core 架构
  4. 生成物为"半成品但合法"：GDScript 可加载、JSON 可解析、不会让 gate 因脚手架自身报结构错误
- 验收标准：
  - 脚手架生成的 `.gd` / `.json` 文件语法合法
  - 脚手架幂等：重复运行不会覆盖已有文件或重复创建 source descriptor
  - 不改任何现有角色时，现有 gate 不受影响
- 用法：`bash scripts/new_formal_character.sh <character_id> <display_name> [--pair-token TOKEN]`

## 最近完成：核心函数参数类型标注补齐（2026-04-20）

- 状态：已完成
- 目标：补齐上一轮类型标注遗漏的核心函数参数
- 修复内容：
  1. `hit_service.gd` — `roll_hit` 的 `rng_service` 参数补 `RngService` 类型
  2. `effect_queue_service.gd` — `sort_events` 的 `rng_service` 参数补 `RngService` 类型
  3. `replay_runner_execution_context_builder.gd` — `build_context` 的 5 个参数全部补显式类型（`ReplayInput / ContentSnapshotCache / IdFactory / RngService / BattleInitializer`）
- 验证：`bash tests/run_with_gate.sh` 全通过

## 当前验证基线

- 最小可玩性检查：
  - 可启动：能进入 `BattleSandbox` 主流程
  - 可操作：`manual/policy` 至少能完整跑完一局
  - 无阻断错误：没有崩溃、卡死或 invalid runtime 漂移
- 当前总验收入口：
  - `bash tests/check_repo_consistency.sh`
  - `bash tests/run_with_gate.sh`

## 最近完成：formal pair interaction 接入面收窄（2026-04-24）

- 状态：已完成
- 目标：在接入新正式角色前，减少 pair interaction 中央注册改动，并阻止占位交互用例进入主线
- 范围：
  1. `scenario_registry.gd` 从 manifest 派生 scenario_key，并从 `tests/support/formal_pair_interaction/*_cases.gd` 自动发现 runner
  2. `repo_consistency_formal_character_gate_pairs.py` 禁止回退到手写中央 registry，并禁止 pair interaction case 保留 `TODO` / placeholder runner
  3. `scripts/new_formal_character.py` 的后续步骤改为提示自动发现 runner，不再要求手改 `scenario_registry.gd`
  4. 补交 `src/shared/resource_path_helper.gd.uid`，修复当前 repo consistency 阻断项
- 验证：
  - `python3 -m py_compile tests/gates/repo_consistency_formal_character_gate_pairs.py scripts/new_formal_character.py`
  - `bash tests/check_suite_reachability.sh && bash tests/check_architecture_constraints.sh`
  - `bash tests/check_repo_consistency.sh` 当前受本机 Godot 日志轮转崩溃影响未完成；前置 uid / surface gate 已通过
  - `git push origin main` 当前受网络 DNS/SSH 解析失败阻断：`Could not resolve hostname github.com`
