# Battle Core 架构约束（v1）

本文件是 `battle_core` 的硬约束文档，只覆盖核心引擎。  
目标是长期保持“高内聚、低耦合、强边界、早拆分”，避免核心继续长成隐性耦合与超大文件。

## 1. 分层与依赖方向（6 层）

|层级|内容|允许依赖|禁止依赖|
|---|---|---|---|
|L1|`content / contracts / runtime / shared constants`|仅本层|上层服务与外围层|
|L2|纯领域服务（`commands / math`、排序、合法性判定、实例管理）|L1|L3-L6|
|L3|子系统协调器（effects、lifecycle）|L1-L2|L4-L6|
|L4|orchestrators（回合阶段编排）|L1-L3|L5-L6 的实现细节|
|L5|facades（核心稳定入口）|L1-L4|外围对象图细节|
|L6|外围层（adapters / scenes / sandbox / boot）|L5 或显式 contract|直接进核心内部服务图与 runtime 细节|

## 2. 角色硬约束

|模块|必须遵守|
|---|---|
|runtime|只保存状态，不写业务判断|
|math|只算数，不改运行态|
|logging|只观察和构造日志，不改状态|
|orchestrator|只编排阶段，不直接做公式、payload 结算、实例增删|
|adapters|禁止直接依赖 `runtime` 内部结构|
|外围层|只能通过 facade 或明确 contract 进入核心|

补充说明：

- 静态 import 面必须继续维持分层单向；runtime wiring 图当前也必须保持 strict DAG。
- 当前禁止在 composition root 的属性注入图里保留任何 SCC；若新增闭环，`architecture_wiring_graph_gate.py` 必须直接失败。
- 若后续机制扩展又逼出新的 runtime 环，必须先补设计文档、决策记录与回归，再做新的装配方案评审；不能把闭环偷偷塞回 wiring。

Composition 补充约束：

- `BattleCoreServiceSpecs` 只允许维护一份 `SERVICE_DESCRIPTORS` 单一描述源，不再分裂维护 `SERVICE_SLOTS / SCRIPT_BY_SLOT` 双清单。
- `BattleCoreContainer` 只允许暴露：
  - `set_service`
  - `service`
  - `has_service`
  - `clear_service`
  - `configure_dispose_specs`
  - `dispose`
- 仓库内对 battle core 容器的服务读取统一使用 `core.service("slot")`；不再依赖 `core.<service>` 显式 slot 属性面。

## 3. Rule Mod 约束

`rule_mod` 定义为“受限读取修正器”，只能作用于白名单读取点，不能改流程。

### 3.1 固定白名单（当前）

- `final_mod`
- `mp_regen`
- `action_legality`
- `incoming_accuracy`
- `nullify_field_accuracy`
- `incoming_action_final_mod`

补充说明：

- `required_target_effects` 属于 effect 级前置守卫，不属于 `rule_mod` 读取点。
- `required_incoming_command_types / required_incoming_combat_type_ids` 只属于 `incoming_action_final_mod` 的过滤条件，不单独形成新的读取点。

### 3.2 明确禁止

- 行动排序
- 回合阶段顺序
- 击倒窗口
- 补位时机
- 胜负判定
- 目标锁定模型
- 生命周期顺序
- 日志链路语义

### 3.3 新增读取点流程

1. 先更新 `docs/rules/06_effect_schema_and_extension.md`。
2. 再更新本文件与 `docs/records/decisions.md`。
3. 最后才允许实现代码。

若玩法持续要求扩大 `rule_mod` 权限，优先新建专用机制，不继续放权给 `rule_mod`。

## 4. 大文件治理规则

采用“职责优先拆分 + 行数强预警”。

### 4.1 职责规则

- 一个类只能有一个主职责。
- 一个 orchestrator 只能编排，不承担 3 类以上领域职责。
- 一个执行器不能同时长期承载：行动主流程、生命周期、效果调度、日志拼装、直接数值计算中的 3 类以上。
- 一个测试入口文件不能长期承载整个核心的全部断言。

### 4.2 强预警阈值

- 核心服务文件、`src/composition/*.gd` 落在 `220..250` 行：输出非阻断预警，并纳入下一轮职责复核观察名单。
- 核心服务文件 > `250` 行：必须触发职责复核。
- `src/composition/*.gd` 同样纳入 > `250` 行复核范围（组合根虽然不在 `battle_core` 子目录，但属于核心装配边界）。
- orchestrator / coordinator > `350` 行：默认拆分。
- 单测试文件 > `600` 行：默认按子域拆分。

若超阈值仍不拆，必须同时满足：

- 在 `docs/records/decisions.md` 写明“为何仍合理 + 预计何时拆分”。
- 在架构闸门的 `size_review_rules` allowlist 里写明该文件的临时 `max_lines` 上限，超限直接 gate fail。

### 4.3 `assert()` 与 fail-fast 边界

- 会直接受内容快照、战斗输入、运行态污染影响的生产路径，不允许把 `assert()` 当成正式失败路径。
- 这类路径必须返回结构化错误或显式 `invalid_*` 终止，确保 debug / release 构建口径一致。
- 当前允许保留 raw `assert()` 的范围：
  - 测试辅助与测试装配
  - 抽象基类 / 必须 override 的占位实现
  - 纯程序员不变量检查（例如内部日志链前置条件、排序服务缺线、公共 ID 生成参数约束）

## 5. Facade 与对外契约

外围层只允许调用 facade，不允许直连内部容器和 runtime。

当前核心稳定 facade 只有 `BattleCoreManager`；`BattleCoreSession` 只是内部会话壳。

当前核心 facade 最小职责：

- `create_session`
- `get_legal_actions`
- `build_command`
- `run_turn`
- `get_public_snapshot`
- `get_event_log_snapshot`
- `close_session`
- `run_replay`
- `active_session_count`
- `dispose`
- `resolve_missing_dependency`

补充约束：

- facade 若需要装配容器，只能依赖 build-container callable / factory port，不得直接持有完整 composition root。
- 外围不得绕过 facade 直接操作 `BattleCoreSession`、内部容器或 runtime。

输出契约分离：

- 内部状态：`runtime`，只在核心内部流动。
- 对外快照：`public snapshot / view model contract`，不得暴露内部 `unit_instance_id`。

## 6. 静态约束检查

工程闸门必须包含：

- 外围层（`src/adapters`、`src/composition`、`scenes`）不得 import `src/battle_core/runtime/*`。
- `src/adapters` 与 `scenes` 不得 import `battle_core` 内部服务实现；允许范围固定为 `facades/*`、`contracts/*` 与 `commands/command_types.gd`。
- `src/adapters` 与 `scenes` 若 import `battle_core/commands/*`，只允许 `commands/command_types.gd`，其他命令实现一律禁止。
- 大文件闸门必须覆盖 `src/battle_core` 与 `src/composition`；若出现超阈值文件，必须同时有 allowlist 临时上限与决策记录。
- runtime wiring 图必须额外经过 `tests/gates/architecture_wiring_graph_gate.py` 校验，并保持严格无环。
