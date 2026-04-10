# 2026-04-10 当前项目实现全景复查

## 结论

- 当前主线没有发现阻断或重要实现问题。
- `docs/design/`、核心实现、四个正式角色交付链和 gate 状态当前是对齐的。
- 最近这一轮管理修复方向是对的，已经真实降低了共享机制和 formal 角色交付链的漂移风险。
- 外部 Claude 审查里有几条高风险表述不适合继续当现行依据，尤其是 `assert()` 违规、architecture gate 未执行、manifest 合同口径这三块。

## 本轮确认

### 1. 当前仓库状态

- `bash tests/run_with_gate.sh` 通过。
- `bash tests/check_architecture_constraints.sh` 通过。
- `bash tests/check_repo_consistency.sh` 通过。
- `bash tests/check_suite_reachability.sh` 通过。
- 当前工作区干净，审查开始时 `git status --short` 为空。

### 2. 架构、代码与设计文档

- `BattleCoreManager` 仍是唯一稳定 facade；外围入口仍走 composer -> manager 路径，没有重新泄漏 session/container 到 `adapters/scenes`。
- `BattleState` 仍是运行态唯一真相，composition root 继续显式装配，不依赖 autoload。
- effect 主链仍是 `trigger_dispatcher -> effect_queue_service -> payload_executor -> payload_handler_registry -> single handler`。
- `PayloadContractRegistry` 已成为 payload script -> handler slot -> validator key 的单点事实源；`ContentPayloadValidator`、`PayloadHandlerRegistry` 和 effects-core wiring 都从它派生。
- `PowerBonusSourceRegistry` 已收口 source 列表、合同校验和运行时解析；`PowerBonusResolver` 当前只保留稳定委托入口。

### 3. 最近提交方向

- `14580aa / 445bdb5 / 9d1bd03 / ac3383e` 主要是热点 owner 拆 helper，公共 API 保持不变，属于正确的体量治理。
- `d9cc721` 是这轮最有价值的 formal 交付治理改动之一：把 shared capability catalog 变成正式合同和 gate 的一部分。
- `0e7c60e` 把 wiring specs 拆回子域聚合，同时把 composition consistency gate 和 wiring DAG gate 一起改到新结构，方向正确。
- `7f501bd` 把 manifest 拆成 facade + loader/views，并把 payload / power bonus 共享注册事实收回单点注册表，实质降低了多点维护风险。
- `fff2e62` 补上 `battle_setup.sides[*].side_id` 的公开入口、setup validator 和 replay 输入校验，是一条真实 bug fix，不是单纯整理记录。

## 对外部 Claude 审查的修正

### 1. `assert()` 违规判断不成立

- 架构约束当前明确允许 raw `assert()` 留在三类位置：
  - 抽象基类 / 必须 override 的占位实现
  - 纯程序员不变量检查
  - 测试辅助与测试装配
- 因此下列断言并不构成当前约束下的违规：
  - `src/battle_core/lifecycle/replacement_selector.gd`
  - `src/battle_core/effects/effect_queue_service.gd`
  - `src/battle_core/turn/public_id_allocator.gd`
- 同时，若只做“全 `src/` 搜索”，实际还会扫到 `src/shared/formal_character_baselines.gd` 里的 3 处 `assert()`；所以“唯一 4 处硬问题”这个结论本身也不准确。

### 2. architecture gate 未执行这条已过时

- 当前环境里 `rg` 与 `godot` 都可用。
- 本轮已实际执行：
  - `bash tests/check_architecture_constraints.sh`
  - `bash tests/run_with_gate.sh`
- 两者都通过，所以“因为缺少 ripgrep 未执行 architecture gate”不再是当前仓库状态。

### 3. formal manifest / 交付清单口径需要回到现行合同

- 当前 manifest runtime 合同的核心字段是：
  - `character_id`
  - `unit_definition_id`
  - `formal_setup_matchup_id`
  - `required_content_paths`
  - `content_validator_script_path`（可选）
- 当前 delivery 合同的核心字段是：
  - `display_name`
  - `design_doc`
  - `adjustment_doc`
  - `surface_smoke_skill_id`
  - `suite_path`
  - `required_suite_paths`
  - `required_test_names`
  - `shared_capability_ids`
  - `design_needles`
  - `adjustment_needles`
- 因此外部报告里把 manifest 说成“13 个必填字段”或按 `unit_path / passive_skill_path` 去列，不是当前代码正在消费的正式合同。
- 当前 formal 角色内容资产的正式真相是各角色 `required_content_paths`，其中：
  - Gojo `21`
  - Sukuna `17`
  - Kashimo `21`
  - Obito `17`

### 4. 旧四角色审查记录只能当历史背景

- 仓库内的 `review_2026-04-10_four_character_architecture_audit.md` 已明确标成“历史审查，不再作为现行依据”。
- 它对 baseline 热点、旧路径和旧体量的描述已经被后续修补覆盖，不适合再直接拿来驱动当前改动。

## 仍需保留的现实判断

- 新增 payload 或 power bonus source 还没有做到近似零中心改动；当前只是从“多处重复手抄”收口成“有明确 seam 的集中维护”。
- capability catalog gate 现在依赖 `coverage_needles` 做文本证据扫描，这能拦声明漂移，但不是语义级依赖图。
- 这两点都属于中长期治理观察，不是当前阻断。

## 验证

- `git status --short`
- `git log --oneline --decorate -20`
- `bash tests/check_suite_reachability.sh`
- `bash tests/check_architecture_constraints.sh`
- `bash tests/check_repo_consistency.sh`
- `bash tests/run_with_gate.sh`
