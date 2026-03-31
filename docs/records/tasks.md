# 任务清单（精简版）

本文件只保留当前仍需直接指导开发的任务摘要、验证结果与未解决问题。

历史完整记录已归档到：

- `docs/records/archive/tasks_pre_v0.6.3.md`
- `docs/records/archive/tasks_pre_v0.6.4.md`

当前生效规则以 `docs/rules/` 为准；工程落点以 `docs/design/` 为准。

## 当前阶段

- 阶段目标：扩角前治理闸门、角色回归锚点与运行态 fail-fast 已收口；下一步可按统一注册表进入新角色接入。
- 当前不做：新角色扩充、Gojo / Sukuna 数值平衡调整、宿傩对 Gojo 的领域兑现率修正。
- 当前优先级：
  - 若继续扩角，先补 `formal_character_registry.json` 资产登记，再补内容与 suite
  - 保持正式角色接入门禁走统一交付面，不再回到手写角色特例
  - 保持无自动选指前提下的主线文档、测试与接入模板一致

## 2026-03-31

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
  - `tests/suites/sukuna_kamado_domain_suite.gd`
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
  - 确认源码最大文件当前为 `src/battle_core/facades/battle_core_manager.gd` 的 250 行，未超过架构闸门的 `>250` 阈值

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
  - `tests/suites/sukuna_kamado_domain_suite.gd`
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
  - `content/effects/sukuna_refresh_love_regen.tres`
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
