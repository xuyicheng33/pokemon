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

### 扩角前规范整合（进行中）

- 目标：
  - 统一错误日志、门禁和 README 口径
  - 统一 `content/` 目录规范与默认快照加载入口
  - 把 `docs/records/` 收回为索引与追溯层
  - 抽出独立的领域模板文档，减少角色稿重复公共规则
  - 给 batch probe 配套固定 replay case，避免只剩聚合统计
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
  - `BattleFormatConfig` 正式目录、默认快照扫描目录与文档描述一致
  - `docs/records/tasks.md` / `decisions.md` 回落到高频可读规模
  - 领域公共规则存在单独权威模板入口
  - `tests/replay_cases/` 有可直接复查的固定案例

#### 当前执行结果

- 已完成：
  - 预期 invalid termination 诊断从 `push_error()` 改为普通文本告警
  - `SampleBattleFactory.content_snapshot_paths()` 已纳入 `battle_formats / passive_items`
  - `sample_battle_format.tres` 已迁到 `content/battle_formats/`
  - `README` / `content/README.md` / `docs/design/*` / `tests/README.md` 已开始同步新目录与门禁口径
  - 本文件与 `docs/records/decisions.md` 已从大正文模式切回精简索引模式

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

1. 先完成领域模板文档与 replay case 收口。
2. 再复跑统一闸门与对称 probe。
3. 确认规范层稳定后，再开启“新角色接入”或“宿傩领域兑现率修正”。
