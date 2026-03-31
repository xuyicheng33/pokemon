# 战斗系统架构总览（骨架阶段）

本文件描述当前原型期战斗核心的工程总览。规则权威仍以 `docs/rules/` 为准；本文件只回答“按什么结构实现，才能不分叉”。

> 详细红线见：`docs/design/battle_core_architecture_constraints.md`。

## 1. 架构目标

|目标|说明|
|---|---|
|deterministic|同一 `seed + content snapshot + command stream` 必须得到同一结果|
|强类型|跨模块正式接口不使用裸 `Dictionary` 作为长期契约|
|单一真相|`BattleState` 是运行态唯一真相，其他模块不得各自缓存状态副本|
|显式装配|核心依赖由 composition root 显式组装，不靠全局单例偷偷注入|
|可回放|日志、随机消费与状态哈希有固定落点|

## 2. 总体分层

|层级|目录|职责|禁止事项|
|---|---|---|---|
|内容资源层|`content/`|放 `.tres` 战斗定义资源|不放美术资源|
|内容类型层|`src/battle_core/content`|定义 `Resource` 类|不写运行态逻辑|
|运行时层|`src/battle_core/runtime`|保存唯一运行态真相|不直接读场景树|
|契约层|`src/battle_core/contracts`|定义跨模块 I/O 契约|不持有全局状态|
|领域服务层|`src/battle_core/*`|实现各模块职责边界|不直接依赖 UI/外层输入|
|组合装配层|`src/composition`|组装核心服务依赖图|不承载业务规则|
|适配层|`src/adapters`|向 UI/输入/测试暴露接口|不直接改内部状态|
|场景入口层|`scenes/`|Godot 入口与 sandbox 组装|不承载核心战斗规则|

补充约束：

- `BattleFormatConfig` 的正式目录是 `content/battle_formats/`；`content/samples/` 只承载样例资源与样例对局资源。
- 外围层（`composition/adapters/scenes`）不得直接依赖 `battle_core/runtime/*`。
- `adapters/scenes` 只能依赖 facade、公开 contract，或输入枚举常量 `commands/command_types.gd`；不得直接连 `actions/effects/lifecycle/logging/math/passives/turn/content` 等内部服务实现。
- 外围只能通过 facade 与公开 contract 调核心。

## 3. 模块拆分

|模块|目录|职责|
|---|---|---|
|Runtime|`battle_core/runtime`|`BattleState`、`SideState`、`UnitState` 等运行态对象|
|Contracts|`battle_core/contracts`|`QueuedAction`、`ActionResult`、`LogEvent` 等跨模块契约|
|Commands|`battle_core/commands`|选择、构建、验证指令|
|Turn|`battle_core/turn`|初始化、回合推进、行动排序|
|Actions|`battle_core/actions`|执行单次行动与目标锁定|
|Math|`battle_core/math`|纯计算服务|
|Lifecycle|`battle_core/lifecycle`|倒下、离场、补位|
|Effects|`battle_core/effects`|触发、排序、payload 执行、rule mod 接入；`payload_handlers/` 负责按 payload 家族拆分运行时处理|
|Passives|`battle_core/passives`|被动技能、被动持有物、field 作为 trigger source 接入|
|Logging|`battle_core/logging`|日志构造、写入、回放|
|Facades|`battle_core/facades`|外围稳定入口、公开快照与事件日志公开快照构建|

补充说明：

- 为了把 owner 文件维持在可控体量内，同子域允许拆出只服务于该 owner 的内部 helper；当前已存在 `BattleInitializerStateBuilder` 与 `BattleCoreManagerContractHelper` 两个例子。
- 这类 helper 只负责分担编排或 contract 拼装，不改变模块边界，也不自动升级成新的稳定入口。

## 4. 数据流

1. `BattleSandboxRunner` 或测试入口请求 `BattleCoreComposer` 创建核心依赖图。
2. `BattleInitializer` 读取内容资源与队伍快照，构造 `BattleState`。
3. `TurnLoopController` 驱动 `turn_start -> selection -> queue_lock -> execution -> turn_end -> victory_check`。
4. `LegalActionService` 产出 `LegalActionSet`；`CommandBuilder` 组装 `Command`；`CommandValidator` 做硬校验。
5. `ActionQueueBuilder` 生成 `QueuedAction` 列表。
6. `ActionExecutor` 执行行动，调用 `TargetResolver`、`math`、`effects` 与 `lifecycle`。
7. `BattleLogger` 与 `LogEventBuilder` 为每个步骤写 `LogEvent`。
8. `ReplayRunner` 使用 `ReplayInput` 重建流程，产出 `ReplayOutput`。

## 5. 依赖纪律

- `battle_core` 不依赖 `adapters`、`composition`、`scenes`。
- `shared` 不依赖 `battle_core`。
- `math` 不写 `BattleState`。
- `logging` 不改写运行态，只观察并记录。
- `effects` 只能通过 `PayloadExecutor`、`payload_handlers/*` 与实例服务改写持续效果/field/rule mod。
- `PayloadExecutor` 只负责 effect 级前置守卫、payload 分派与 handler 编排；具体 payload 语义下沉到 `payload_handlers/` 与其子 runtime service。
- `adapters` 只通过公开 contract 访问核心，不直接拼内部细节。
- `composition` 负责 new 依赖，但不做业务判断。

## 6. Composition Root

当前采用 `Scene + Composition Root`：

- `scenes/boot/Boot.tscn`
  - 作为 Godot 主场景。
  - 只负责进入 `BattleSandbox.tscn`。
- `scenes/sandbox/BattleSandbox.tscn`
  - 作为战斗骨架试跑入口。
  - 挂载 `BattleSandboxRunner`。
- `src/composition/battle_core_composer.gd`
  - 负责创建 RNG、ID、commands、turn、effects、logging 等服务对象。
  - 返回一个明确的依赖容器。

当前不采用 autoload 主导架构，避免原型期过早引入全局状态污染。

## 7. 扩展纪律

- 新机制先改 `docs/rules/`，再改 `docs/design/`，最后改骨架代码。
- 多目标、`scope = side`、双打、状态包都不属于当前骨架范围。
- `rule_mod` 只能修改已明文开放的读取节点，不得改写核心流程。
- 对外接口新增字段时，必须同步更新 contract 类和设计文档，不能只改聊天口径。

## 8. Facade 稳定入口

`battle_core` 对外围公开稳定 facade 的当前实现是 `BattleCoreManager`。
`BattleCoreSession` 只是 manager 内部会话壳，不属于外围稳定入口。

`battle_core/facades/` 当前包含：

- `battle_core_manager.gd`
- `public_snapshot_builder.gd`
- `event_log_public_snapshot_builder.gd`
- `battle_core_manager_contract_helper.gd`（manager 内部 helper）
- `battle_core_session.gd`（manager 内部会话壳）

对外围稳定开放的最小接口为：

- `create_session`
- `get_legal_actions`
- `build_command`
- `run_turn`
- `get_public_snapshot`
- `get_event_log_snapshot`
- `close_session`
- `run_replay`

管理器级辅助接口：

- `active_session_count`
- `dispose`
- `resolve_missing_dependency`

补充说明：

- `initialize_battle` 与 `build_public_snapshot` 仍然存在于核心内部服务图中，但属于 `composition + facades` 内部装配细节，不作为外围稳定入口。
- facade 若需要装配核心容器，只能依赖 build-container callable / factory port，不应直接持有完整 composition root。
- `BattleCoreManager` 的公开返回当前统一使用严格 envelope：
  - 成功：`{"ok": true, "data": ... , "error_code": null, "error_message": null}`
  - 失败：`{"ok": false, "data": null, "error_code": String, "error_message": String}`
