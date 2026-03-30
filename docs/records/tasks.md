# 任务清单（精简版）

本文件只保留当前仍需直接指导开发的任务摘要、验证结果与未解决问题。

历史完整记录已归档到：

- `docs/records/archive/tasks_pre_v0.6.3.md`
- `docs/records/archive/tasks_pre_v0.6.4.md`

当前生效规则以 `docs/rules/` 为准；工程落点以 `docs/design/` 为准。

## 当前阶段

- 阶段目标：先泛化角色接入与内容快照门禁，再进入新角色接入。
- 当前不做：新角色扩充、Gojo / Sukuna 数值平衡调整、宿傩对 Gojo 的领域兑现率修正。
- 当前优先级：
  - 泛化角色接入与内容快照门禁，避免继续绑死 Gojo / Sukuna
  - 让正式角色接入门禁从“点名角色”收口为“统一交付面”
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

## 当前未解决问题

### 1. 宿傩对 Gojo 的领域兑现率仍为 0（已知，不在本轮修）

- 当前结论：宿傩已经能稳定进入奥义窗口，也会按领域，但在 Gojo 对位里仍长期立不住领域。
- 当前处理：只记录为下一轮平衡问题，不在本轮规范整合里动数值。
- 后续入口：完成本轮整合后，再单开“领域资源轴/平衡修正”任务。

## 下一步建议

1. 先把 `SampleBattleFactory.content_snapshot_paths()` 改成递归收集内容资源，堵住子目录漏扫。
2. 再把角色接入门禁从手写 Gojo / Sukuna 特例抽成统一注册表或统一交付面校验。

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
