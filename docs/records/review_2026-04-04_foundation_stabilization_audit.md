# 2026-04-04 基础稳定化审查记录

> 本记录用于替代“项目整体完全健康 / 严格 DAG / 完全对齐 / 覆盖充分”这类过度结论。  
> 当前仓库可以继续开发，但在继续扩正式角色与批量回放前，必须先把基础设施里的真实风险收口。
>
> 同日后续更新：
> runtime wiring 图已在后续整改里真正收口回 strict DAG；本记录保留的是当时审查发现的问题与收口起点，不再代表当前仓库现状。

## 结论

- 当前项目不是“无问题可直接无限扩角”的状态，而是“核心主路径可跑，但有几条基础设施红线必须先稳住”的状态。
- 本轮确认并收口的真实问题有 6 类：
  1. passive trigger source 在 `collect_events()` 阶段抛出的 `invalid_battle` 之前会被静默吞掉。
  2. facade / orchestrator 侧仍有一批跨模块错误读取依赖 `get("last_*")` 这类脆弱字符串通道。
  3. runtime wiring 图并不是严格 DAG；它一直存在一个受控 SCC，只是之前缺少机器门禁和正式文档口径。
  4. session / replay 会重复整量重载相同 `content_snapshot_paths`，对后续扩角和批量回放都不友好。
  5. replay 每回合都线性扫描整条 `command_stream`，会把批量回放成本无谓放大。
  6. Kashimo 设计稿里的部分资源粒度描述已经与现状实现漂移。
- 这几项里，前 3 项属于继续扩正式角色前就应该收口的基础线；后 3 项属于为多角色和批量回放提前铺路。

## 本轮审查范围

- 运行时主链：
  - `src/battle_core/passives/*`
  - `src/battle_core/effects/*`
  - `src/battle_core/facades/*`
  - `src/battle_core/logging/replay_runner.gd`
  - `src/battle_core/content/*`
  - `src/composition/*`
- 回归与门禁：
  - `tests/suites/*`
  - `tests/support/*`
  - `tests/gates/*`
  - `tests/check_architecture_constraints.sh`
- 文档与记录：
  - `docs/design/architecture_overview.md`
  - `docs/design/battle_core_architecture_constraints.md`
  - `docs/design/log_and_replay_contract.md`
  - `docs/design/kashimo_hajime_design.md`
  - `docs/records/tasks.md`
  - `docs/records/decisions.md`

## 本轮落地结果

### 1. passive fail-fast 漏洞已收口

- `PassiveSkillService` 与 `PassiveItemService` 现在会在内部 `TriggerDispatcher.collect_events()` 后立刻保存 `last_invalid_battle_code`。
- `TriggerBatchRunner.collect_trigger_events()` 现在统一检查四类 trigger source：
  - 被动技能
  - 被动持有物
  - effect instance
  - field
- 任一支路返回 `invalid_battle_code`，本批次会立刻停止并向上终止，不再静默表现成“这次没触发”。

### 2. 错误读取通道已改成显式约定

- 跨模块读取用户可见错误的服务，现在统一提供 `error_state() -> { code, message }`。
- 跨模块读取 `invalid_battle` 的服务，现在统一提供 `invalid_battle_code() -> Variant`。
- 本轮已先迁移最危险的动态读取点：
  - `BattleCoreManagerContractHelper`
  - `BattleCoreSession`
  - `TriggerBatchRunner`
- 为了兼容测试替身，pluggable dependency 边界保留了“优先显式 getter，旧 mock 只在局部 helper 里兼容 `last_invalid_battle_code`”的过渡策略；正式服务之间不再继续新增裸 `get("last_*")` 读取。

### 3. runtime wiring 图正式改成“受控 SCC + gate”口径

- 当前 runtime wiring 图存在且只允许存在 1 个登记过的 SCC，不再把它误写成“严格 DAG”。
- 新增 `tests/gates/architecture_wiring_graph_gate.py`：
  - 直接解析 `WIRING_SPECS`
  - 用 strongly connected component 校验 runtime wiring 图
  - 只允许当前登记的 13 节点 SCC
  - 自带 synthetic SCC 自检，防止 gate 自己失效
- 这意味着以后只要：
  - 新增一个 runtime SCC
  - 扩大现有 SCC 成员
  - 把现有 SCC 拆成新的未登记闭环
  - 架构 gate 都会直接失败

### 4. 内容加载路径已为扩角 / 批量回放做缓存准备

- 新增 composer 级共享 `ContentSnapshotCache`。
- cache 键为稳定排序后的 `content_snapshot_paths` 签名。
- cache 中共享的是“已加载且已校验”的资源数组；命中后：
  - 不再重复走磁盘 load
  - 不再重复跑整套快照校验
  - 但仍会深复制资源并构造 fresh `BattleContentIndex`
- 这样既能复用内容加载成本，又不会跨 session / replay 共享可变运行态索引。

### 5. replay 现在按回合索引命令

- `ReplayRunner` 已在 while 循环前把 `command_stream` 预分组到 `Dictionary<int, Array>`。
- 每回合直接读取当前 `turn_index` 的命令数组，不再反复全表扫描。
- 同回合命令的相对顺序保持不变，deterministic 行为不变。

### 6. 文档漂移已同步纠偏

- `architecture_overview.md` / `battle_core_architecture_constraints.md` 现在明确区分：
  - 静态 import 面保持单向
  - runtime wiring 允许受控 SCC
- `log_and_replay_contract.md` 已补齐：
  - `ContentSnapshotCache`
  - replay 按 `turn_index` 预分组
  - cache 命中后 public snapshot / event log / `final_state_hash` 必须不变
- `kashimo_hajime_design.md` 已把资源粒度改回当前真实实现：
  - `kashimo_amber_self_transform` 是单一入口 effect，不再误写成多个独立 `amber_*_up` 资源
  - `water leak` 当前口径是 `kashimo_apply_water_leak_listeners` + 两个 listener，而不是旧的 `kashimo_water_leak_self / counter`

## 新增回归与门禁

- 负向回归：
  - `invalid_passive_skill_trigger_source_fails_fast`
  - `invalid_passive_item_trigger_source_fails_fast`
- cache / replay 回归：
  - `content_snapshot_cache_session_and_replay_contract`
  - `replay_turn_index_lookup_contract`
- 静态门禁：
  - `architecture_wiring_graph_gate.py`

## 仍然不在本轮范围内

- 不改 `BattleCoreManager` 等对外公开接口字段。
- 不补正式 passive item 内容。
- 不做整仓库 DI 重写。
- 不顺手扩第 4 个正式角色。
- 不改角色玩法数值和平衡。

## 验证

- `godot --headless --path . --script tests/run_all.gd`
- `bash tests/check_architecture_constraints.sh`
- `bash tests/run_with_gate.sh`
