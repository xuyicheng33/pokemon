# 决策记录（精简版）

本文件只保留当前阶段仍会直接约束实现、测试或扩角流程的关键决策。

历史完整记录已归档到：

- `docs/records/archive/decisions_pre_v0.6.3.md`
- `docs/records/archive/decisions_pre_v0.6.4.md`

当前生效规则以 `docs/rules/` 为准；本文件只记录“为什么这样定”。

## 当前有效决策

### 1. 规则、设计、记录的职责分层固定

- `docs/rules/` 是当前生效规则权威。
- `docs/design/` 负责实现落点、架构与角色/机制设计。
- `docs/records/` 只保留决策背景、任务摘要与追溯入口，不再承载会被误当成“当前真相”的大正文。

### 2. 扩角前先做规范整合，不先做新角色与平衡修正

- 当前主线先解决工程/文档/门禁/诊断漂移。
- 宿傩对 Gojo 的领域兑现率问题保留到下一轮平衡任务。
- 本轮默认不动 Gojo / Sukuna 数值，不把 `domain_successes = 0` 当成规范整合阶段的实现目标。

### 3. 预期 invalid termination 不再伪装成引擎级错误

- `invalid_battle / hard_terminate_invalid_state` 仍要保留可检索诊断输出。
- 但这类预期负路径不再走引擎级 `push_error()`，避免闸门全绿时控制台仍充满误导性 `ERROR:`
- `tests/run_with_gate.sh` 继续只拦截真正的脚本/编译/解析/加载错误。

### 4. `BattleFormatConfig` 的正式目录固定为 `content/battle_formats/`

- `content/samples/` 只承载样例资源与样例对局资源，不再承载正式 battle format。
- 默认快照扫描目录必须与目录规范一致；新增 battle format 时不允许靠样例目录兜底。

### 5. 默认快照扫描目录固定显式列出

- `SampleBattleFactory.content_snapshot_paths()` 默认收集：
  - `battle_formats`
  - `combat_types`
  - `units`
  - `skills`
  - `passive_skills`
  - `passive_items`
  - `effects`
  - `fields`
  - `samples`
- 继续保持稳定排序，避免内容接线漏资源与 replay 漂移。

### 6. 领域公共规则必须有单独模板入口

- Gojo / Sukuna 共享的领域规则，不再只分散写在角色设计稿里。
- 当前正式要求：领域角色扩展前，先阅读并对齐领域模板文档，再写角色差异项。
- 角色设计稿只保留自身差异，不再重复定义整套公共领域冲突矩阵。

### 7. 领域公共规则继续沿用当前主线 contract

- `domain vs domain` 比较双方扣费后的当前 MP。
- 成功后附带链统一走 `field_apply_success`。
- 领域增幅必须是 field 绑定收益，跟随 `field_apply / field_break / field_expire` 生命周期。
- 同回合双方已入队的领域动作不得被 action lock 回溯取消。
- 己方领域在场时，己方不得重开己方领域；该限制不影响对手领域，也不影响普通 field。

### 8. 固定案例诊断口径（已被第 15 条进一步收口）

- 当前主线只保留 `tests/replay_cases/` 固定可复查案例作为角色与规则复查入口。
- 历史上的 batch probe 拆分方案已随第 15 条一起退出主线，不再作为现行要求。
- 固定案例至少覆盖领域成功、领域失败、平 MP tie-break、普通 field 阻断、同回合双开域。

### 9. 正式角色资产交付面继续保持不变

- 每个正式角色都必须同时具备：
  - 设计稿
  - 调整记录
  - 内容资源
  - `SampleBattleFactory` 接线
  - 独立角色 suite
- 后续新角色默认沿用这套交付面，不再接受“只有 `.tres` + 测试”的半成品接入。

### 10. 对外 contract 继续收口到公开层接口

- 外层输入与公开快照继续只使用 `public_id`。
- `BattleCoreManager` 仍是外围稳定入口。
- 调试读取若需要更多信息，只允许走显式的只读快照/日志接口，不再直穿内部 session/runtime。

### 11. 复杂度预拆阶段的大文件过渡上限（2026-03-30）

- `src/battle_core/lifecycle/faint_resolver.gd`
  - 本轮已把击倒窗口主流程拆成 `collect/resolve/replacement` 子函数，先降职责密度，再做下一步子服务外提。
  - 过渡期允许行数上限 `290`，后续继续拆出独立 faint pipeline 服务。
- `src/battle_core/actions/action_cast_service.gd`
  - 本轮已把直接伤害上下文计算拆到独立 helper，先降低单段结算复杂度。
  - 过渡期允许行数上限 `280`，后续继续拆分 cast/hit/effect pipeline。

### 12. 领域合法性统一（原 AI 口径已被第 15 条废止，2026-03-30）

- 新增 `domain_legality_service` 作为领域重开判定的单一真相：
  - 选指阶段（`LegalActionService`）与执行阶段（`ActionDomainGuard`）统一复用同一判定。
- `public_snapshot.field` 扩展 `field_kind / creator_side_id`：
  - 供外层输入、公开快照与规则复查统一读取当前 field 类型与归属侧。
- 当时引入的 AI 领域优先与策略表驱动实现，已随第 15 条退出主线：
  - 后续若恢复自动选指，必须重新补齐规则、设计文档与接线任务，不得直接回填历史实现。

### 13. Active Field 的 creator 视为运行态硬约束（2026-03-30）

- 只要 `battle_state.field_state != null`，就必须满足：
  - `field_state.creator` 非空
  - `field_state.creator` 能解析到当前运行态中的单位
- 原因：
  - 领域对拼与 field 生命周期日志都依赖 creator 归因；继续用缺失 creator 的脏状态往下跑，只会把坏状态伪装成正常对拼结果。
- 当前处理：
  - `RuntimeGuardService` 在每回合入口统一拦截这类坏状态，直接返回 `invalid_state_corruption`
  - `FieldApplyConflictService` 额外保留本地防御，不再把缺失 creator 降级成 `-1 MP` 继续参与领域对拼

### 14. 扩角前规范整合口径正式收紧（2026-03-30）

- manager 对外事件日志改为白名单公开快照：
  - 保留公开归因字段 `actor_public_id / actor_definition_id / target_public_id / target_definition_id / killer_public_id / killer_definition_id`
  - 移除 `actor_id / source_instance_id / target_instance_id / killer_id / value_changes[].entity_id`
- `create_session()` 的对外 contract 正式定义为“已预回首回合 MP 后的初始公开快照”，且初始 `event_log` 不补这条预回蓝。
- 初始化阶段的 `invalid_battle` 与 startup victory 统一归 `BattleResultService` 落盘，`BattleInitializer` 只保留编排 owner。
- `ActionCastService` 与 `FaintResolver` 已完成一轮职责预拆；后续扩角优先继续沿子域 helper 扩展，不再把复杂度继续堆回主类。

### 15. 主线移除 AI 选指与批量模拟层（2026-03-30）

- 当前主线不再保留 `BattleAIAdapter`、heuristic policy、角色 mode handler、batch probe 与对应回归。
- 原因：
  - 现阶段优先收口核心战斗 contract、角色资源与扩角前治理，不再维护实验性自动选指层。
  - 继续保留 AI 模拟层会把角色行为问题与核心规则问题混在一起，增加扩角前整合成本。
- 当前处理：
  - 正式角色交付面回退为 `设计稿 / 调整记录 / 内容资源 / SampleBattleFactory 接线 / 角色 suite / 必要固定案例`。
  - 若未来恢复自动选指，必须先补规则与设计文档，再单开接线任务，不得直接回填历史实现。
