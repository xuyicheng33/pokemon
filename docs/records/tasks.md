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
  - `docs/design/sukuna_design.md` / `docs/design/sukuna_adjustments.md` 已冻结默认装配第 6 回合、反转装配第 7 回合的首次奥义窗口

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

### 1. 宿傩对 Gojo 的领域兑现率仍为 0（已知，不在本轮修）

- 当前结论：宿傩已经能稳定进入奥义窗口，也会按领域，但在 Gojo 对位里仍长期立不住领域。
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
  - 宿傩在 Gojo 对位中的 `domain_successes` 仍为 `0`，属于后续平衡与角色资源轴问题，不影响本轮规范收口目标。
