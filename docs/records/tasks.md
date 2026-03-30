# 任务清单（精简版）

本文件只保留当前仍需直接指导开发的任务摘要、验证结果与未解决问题。

历史完整记录已归档到：

- `docs/records/archive/tasks_pre_v0.6.3.md`
- `docs/records/archive/tasks_pre_v0.6.4.md`

当前生效规则以 `docs/rules/` 为准；工程落点以 `docs/design/` 为准。

## 当前阶段

- 阶段目标：先修 effect 链递归防抖与扩角前治理闸门，再进入新角色接入。
- 当前不做：新角色扩充、Gojo / Sukuna 数值平衡调整、宿傩对 Gojo 的领域兑现率修正。
- 当前优先级：
  - 修补 effect 链递归重新派发时的去重失效
  - 泛化角色接入与内容快照门禁，避免继续绑死 Gojo / Sukuna
  - 保持无 AI 前提下的主线文档、测试与接入模板一致

## 2026-03-30

### 去 AI 化整合（已完成）

- 目标：
  - 从主线移除 AI 选指、heuristic policy、角色 mode handler 与 batch probe
  - 保持核心战斗、手动输入、回放与固定案例复查链路可用
  - 同步收口 README / rules / design / records / tests 口径
- 范围：
  - `src/adapters/**/*`
  - `tests/suites/*`
  - `tests/helpers/*`
  - `docs/**/*`
  - `README.md`
- 验收标准：
  - 仓库不再保留 AI adapter、AI policy、AI decision suite、batch probe
  - `tests/run_with_gate.sh` 通过
  - 活跃文档不再把 AI policy / regression / probe 作为当前主线交付面

#### 当前执行结果

- 已完成：
  - `src/adapters/` 下 AI adapter、policy service、角色 mode handler 已从主线移除
  - `tests/run_all.gd`、adapter / manager contract suites 与 consistency gate 已同步删除 AI / probe 交付面
  - README、rules、design、records、tests 文档口径已统一为“玩家输入 + 系统自动注入 + 回放 + 固定案例”

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

1. 先修掉 effect 链递归重新派发时的 dedupe 漏洞，并补真正覆盖“新事件对象”场景的回归。
2. 再泛化内容快照收集与角色接入门禁，避免后续扩角继续手工追 Gojo / Sukuna 特例。

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
