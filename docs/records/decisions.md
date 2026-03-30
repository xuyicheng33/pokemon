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

### 8. replay / probe 诊断拆成“聚合统计 + 固定案例”

- batch probe 继续用于观察趋势，不再承担唯一诊断入口。
- `tests/replay_cases/` 必须保留固定可复查案例，至少覆盖领域成功、领域失败、平 MP tie-break、普通 field 阻断、同回合双开域。

### 9. 正式角色资产交付面继续保持不变

- 每个正式角色都必须同时具备：
  - 设计稿
  - 调整记录
  - 内容资源
  - `SampleBattleFactory` 接线
  - 独立角色 suite
- 后续新角色默认沿用这套交付面，不再接受“只有 `.tres` + 测试”的半成品接入。

### 10. 对外 contract 继续收口到公开层接口

- 外围输入/公开快照/AI 输入继续只使用 `public_id`。
- `BattleCoreManager` 仍是外围稳定入口。
- probe 与调试读取若需要更多信息，只允许走显式的只读快照/日志接口，不再直穿内部 session/runtime。

### 11. 复杂度预拆阶段的大文件过渡上限（2026-03-30）

- `src/battle_core/lifecycle/faint_resolver.gd`
  - 本轮已把击倒窗口主流程拆成 `collect/resolve/replacement` 子函数，先降职责密度，再做下一步子服务外提。
  - 过渡期允许行数上限 `290`，后续继续拆出独立 faint pipeline 服务。
- `src/battle_core/actions/action_cast_service.gd`
  - 本轮已把直接伤害上下文计算拆到独立 helper，先降低单段结算复杂度。
  - 过渡期允许行数上限 `280`，后续继续拆分 cast/hit/effect pipeline。

### 12. 领域合法性与 AI 领域优先口径统一（2026-03-30）

- 新增 `domain_legality_service` 作为领域重开判定的单一真相：
  - 选指阶段（`LegalActionService`）与执行阶段（`ActionDomainGuard`）统一复用同一判定。
- `public_snapshot.field` 扩展 `field_kind / creator_side_id`：
  - AI 在“领域优先”判定时只把“己方 active domain”视作重开阻断，不再把己方普通 field 误判为己方领域。
- AI 策略从角色硬编码分支改为代码内策略表驱动：
  - 后续新增角色默认走“加策略配置 + 测试”的接入路径，不再继续堆叠 `if actor_def_id == ...` 分支。
