# 2026-04-10 最近提交与扩展治理复查记录

## 结论

- 当前主线没有发现阻断或重要实现问题。
- 最近这轮提交的修复方向是对的，而且已经真正落到代码、门禁和文档，不是只做了记录整理。
- 对“新增复杂角色时要同时改很多地方”这个问题，这轮修复已经明显降低了治理层重复录入和接线层热点，但还没有把机制扩展成本降到“几乎只改一处声明”。

## 本轮重点确认

### 1. 架构与设计文档当前是对齐的

- `docs/design/architecture_overview.md`、`docs/design/battle_core_architecture_constraints.md`、`src/composition/battle_core_service_specs.gd`、`src/composition/battle_core_wiring_specs.gd` 与 split wiring 子文件当前口径一致。
- `BattleCoreComposer` 继续只认聚合入口，container API、service descriptor 单一真相、strict DAG gate 也都仍然成立。
- `BattleCoreManager` 仍是唯一稳定 facade，session/container 调度没有重新泄漏到外围层。

### 2. formal 角色交付链的治理修复已经形成稳定主轴

- manifest 运行时视图、交付视图和 pair interaction catalog 已从单文件热点拆成 facade + helper；共享字段合同继续由 `config/formal_registry_contracts.json` 与 `src/shared/formal_registry_contracts.gd` 维护。
- `battle_seed` 已回收到共享合同，不再只靠 loader/gate 私下补约束。
- `shared_capability_ids + capability catalog + repo consistency gate` 已形成完整闭环，四个正式角色的共享机制声明、required suite 回挂和证据扫描当前一致。

### 3. 最近几次提交确实命中了前一轮真实痛点

- `f077b8b` 把正式角色 baseline 收回 manifest 正式 ID，并把 baseline 热点纳入 architecture size gate。
- `d9cc721` 把共享能力目录变成正式交付模板的一部分，解决了“共享机制到底算不算正式入口”长期靠零散补丁维持的问题。
- `0e7c60e` / `49109b1` 把 wiring specs 从单热点拆回子域聚合，并把 gate 与设计文档同步到新结构。
- `e7a336b` / `7f501bd` 把 pair contract、manifest helper、payload registry 收回单点事实源，并把 power bonus 的共享声明面收回单点注册。

## 遗留观察

### 1. 机制扩展入口仍然没有做到接近零中心改动

- payload 已经不再多处手抄名单，但新增 payload 仍然至少会碰：
  - `src/battle_core/content/payload_contract_registry.gd`
  - `src/battle_core/content/content_payload_validator.gd`
  - handler/runtime service 实现
  - `src/composition/battle_core_service_specs.gd`
  - 对应 wiring spec
- power bonus 当前已经从“名单 + 校验 + 运行时分支”三处分裂收成“注册表 + resolver”两处明确接缝，但新增 source 仍要同时补合同校验和运行时解析。
- 这说明当前状态已经从“分散重复维护”修到了“有清晰 seam 的集中维护”，方向正确，但还不是最终形态。

### 2. capability 证据门禁目前偏文本匹配

- `repo_consistency_formal_character_gate_capabilities.py` 现在会扫描角色内容、validator、设计稿、调整稿和 suite 中的 `coverage_needles`。
- 这能有效拦“在用却没声明”的问题，但它本质上仍是文本证据，不是语义级依赖图。
- 后面如果继续重构设计稿措辞或 validator 命名，需要注意不要把这层文本 gate 当成玩法语义正确性的替代品。

## 验证

- `bash tests/check_architecture_constraints.sh`
- `bash tests/check_repo_consistency.sh`
- `bash tests/check_suite_reachability.sh`
- `bash tests/run_with_gate.sh`
