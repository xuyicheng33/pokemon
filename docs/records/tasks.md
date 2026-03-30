# 任务清单（精简版）

本文件只保留当前仍需直接指导开发的任务摘要、验证结果与未解决问题。

历史完整记录已归档到：

- `docs/records/archive/tasks_pre_v0.6.3.md`
- `docs/records/archive/tasks_pre_v0.6.4.md`

当前生效规则以 `docs/rules/` 为准；工程落点以 `docs/design/` 为准。

## 当前阶段

- 阶段目标：先完成扩角前规范整合，再进入新角色接入。
- 当前不做：Gojo / Sukuna 数值平衡调整、宿傩对 Gojo 的领域兑现率修正。
- 当前优先级：
  - 收口工程/文档/门禁漂移
  - 固化领域角色接入模板
  - 补强 replay / probe 诊断链路

## 2026-03-30

### 扩角前规范整合（已完成）

- 目标：
  - 收紧 manager 对外日志接口，移除 runtime id 泄漏
  - 把 active field creator invariant 升级为权威规则
  - 正式澄清初始化预回蓝 contract 与 BattleResult owner
  - 补齐角色接入模板的 AI / probe 交付面
  - 预拆 AI / ActionCast / FaintResolver 热点职责
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
  - 角色接入模板已补 AI policy / regression / probe 交付面
  - `ActionCastService` / `FaintResolver` 已完成一轮职责预拆

#### 当前执行结果

- 已完成：
  - `BattleCoreManager.get_event_log_snapshot()` 已切到公开安全投影，contract 测试已守住公开字段与私有字段边界
  - active field 缺失 creator 与同侧领域重开主路径都已统一 `invalid_state_corruption` fail-fast
  - `BattleResultService` 已接管初始化阶段 invalid/startup victory 落盘
  - `BattleAIPolicyService` 已收口为通用调度，Gojo / Sukuna 角色分支已下沉到 catalog + mode handler
  - `ActionCastService` 与 `FaintResolver` 已拆出子 pipeline / 子服务
  - README / 规则 / 设计 / 测试文档已同步公开日志、初始化预回蓝与角色接入模板口径

#### 当前验证结果

- 待本轮全部收口后统一复跑：
  - `bash tests/run_with_gate.sh`
  - `HOME=/tmp GODOT_USER_HOME=/tmp RUN_NAIVE=0 RUN_HEURISTIC=1 BATTLES=200 SYMMETRIC_ONLY=1 godot --headless --path . --script tests/helpers/gojo_sukuna_batch_probe.gd`

## 当前未解决问题

### 1. 宿傩对 Gojo 的领域兑现率仍为 0（已知，不在本轮修）

- 当前结论：宿傩已经能稳定进入奥义窗口，也会按领域，但在 Gojo 对位里仍长期立不住领域。
- 当前处理：只记录为下一轮平衡问题，不在本轮规范整合里动数值或 AI。
- 后续入口：完成本轮整合后，再单开“领域资源轴/平衡修正”任务。

### 2. batch probe 需要固定 replay case 配套

- 当前 probe 能稳定复现聚合统计，但排查异常仍要靠临时读日志。
- 本轮目标是补足固定案例与复查入口，不再把 probe 当唯一诊断工具。

## 下一步建议

1. 先复跑统一闸门与对称 probe，确认本轮收口没有回归。
2. 规范层稳定后，再二选一开启“新角色接入”或“宿傩领域兑现率修正”。

### 领域规范整合与扩角前收口（已完成）

- 目标：
  - 修复 AI 领域优先误判（普通 field 不再误判为己方领域）
  - 把领域模板关键规则下沉为加载期硬校验
  - 统一领域重开合法性判定路径（选指/执行共用）
  - 把 Gojo/Sukuna AI 从硬编码分支改为策略表驱动
  - 对齐 README/架构总览/角色稿与一致性门禁
  - 抽公共 DomainRoleTestSupport，去除 suite 对私有方法依赖
  - 对热点服务做函数级预拆并更新架构闸门过渡上限
- 实现摘要：
  - 新增 `domain_legality_service`，LegalActionService 与 ActionDomainGuard 共用
  - `public_snapshot.field` 新增 `field_kind / creator_side_id`
  - 新增 `domain_field_contract_validation` 回归，强约束 domain field 清理链
  - 新增 AI 回归：`ai_policy_domain_not_blocked_by_owned_normal_field` 与 `ai_policy_domain_blocked_by_owned_domain_field`
  - README 代码行统计、快照目录口径、facade 接口文档与 consistency 脚本同步
  - `sukuna_*_suite` 不再调用 `_support._*` 私有 helper
- 验证结果：
  - `bash tests/run_with_gate.sh` 通过
  - `CASE=all godot --headless --path . --script tests/helpers/domain_case_runner.gd` 通过
  - `HOME=/tmp GODOT_USER_HOME=/tmp RUN_NAIVE=0 RUN_HEURISTIC=1 BATTLES=200 SYMMETRIC_ONLY=1 godot --headless --path . --script tests/helpers/gojo_sukuna_batch_probe.gd` 完成
- 本轮遗留（非本任务范围）：
  - 宿傩在 Gojo 对位中的 `domain_successes` 仍为 `0`，属于后续平衡与角色资源轴问题，不影响本轮规范收口目标。
