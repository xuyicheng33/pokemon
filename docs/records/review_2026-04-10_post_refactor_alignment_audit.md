# 2026-04-10 重构后实现对齐审查记录

## 结论

- 当前主线没有发现阻断继续开发的实现问题。
- `f077b8b / d9cc721 / 0e7c60e / 49109b1` 这四次提交，已经把 formal baseline、shared capability catalog、battle core wiring specs 与设计文档的大部分热点实打实收住。
- 四个正式角色当前的设计稿、资源、formal validator、runtime suite、manager smoke、pair smoke 与 pair interaction 没查到新的玩法语义漂移。
- 这轮遗留问题主要集中在“记录口径还有少量漂移”和“机制扩展层的中心改动点仍然偏多”，不是 battle core 主循环失控。

## 本轮发现

### 1. 记录口径仍有两处漂移

- `docs/records/review_2026-04-10_four_character_architecture_audit.md` 还放在活跃记录目录里，但没有像更早的审查记录那样显式说明“历史审查，不再作为现行依据”。
- 同一文件正文仍引用已经在当天后续重构里删掉的 baseline 路径与旧体量判断：
  - `src/shared/formal_character_baselines/obito_formal_character_baseline.gd`
  - `src/shared/formal_character_baselines/kashimo_formal_character_baseline.gd`
  - `src/shared/formal_character_baselines/gojo_formal_character_baseline.gd`
- `docs/records/tasks.md` 的“formal contract 扩角前硬收口”条目仍写成“进行中”，但正文已经写明四个阶段全部完成并做了最终验收。
- 这些问题不影响运行时，但会误导后续人工复查。

### 2. `pair_interaction_case` 的共享合同源还差半步

- `docs/records/decisions.md` 已经把 `pair_interaction_cases[*].battle_seed` 定成正式必填项。
- 但 `config/formal_registry_contracts.json` 的 `pair_interaction_case` 合同里，当前只登记了：
  - `test_name`
  - `scenario_id`
  - `matchup_id`
  - `character_ids`
- `battle_seed` 现在主要靠：
  - `src/composition/sample_battle_factory_matchup_catalog_loader.gd`
  - `tests/gates/repo_consistency_formal_character_gate_pairs.py`
 这两处额外校验来保证，而不是回到共享合同单真相。
- 当前 runtime 入口仍然安全，因为 `SampleBattleFactoryFormalMatchupCatalog` 会走 loader；但“formal 共享字段定义只保留一份真相”的目标在这里还没有完全落齐。

### 3. 角色接入治理已收口，但机制扩展实现仍然偏中心化

- `d9cc721` 解决的是 formal 角色交付面的治理问题，不是 engine 级机制扩展的中心修改面。
- 当前新增共享机制时，仍然需要同时改多个中心入口。例如：
  - 新增 `power_bonus_source` 仍要同步改 `power_bonus_source_registry.gd`、`power_bonus_resolver.gd`、`content_snapshot_skill_validator.gd`
  - 新增 payload / `rule_mod` 仍要同步改 `rule_mod_schema.gd`、`content_payload_validator.gd`、`payload_handler_registry.gd`、`battle_core_wiring_specs_payload_handlers.gd`
- 这说明项目已经从“无序返工”收到了“有明确 seam 的返工”，但还没有到“新增机制几乎只改一处声明”的程度。

## 本轮确认已收口的问题

### Formal baseline official ids

- `FormalCharacterBaselines` 当前只认 manifest 正式 ID：
  - `gojo_satoru`
  - `sukuna`
  - `kashimo_hajime`
  - `obito_juubi_jinchuriki`
- baseline 目录已经进入 architecture size gate，旧短别名残留也有 repo consistency gate 锁住。

### Shared capability catalog gate

- `config/formal_character_manifest.json.characters[*].shared_capability_ids`、`config/formal_character_capability_catalog.json`、`src/shared/formal_character_capability_catalog.gd` 与 repo consistency gate 已经形成完整校验链。
- 新共享入口如果没有登记、消费者没对齐、required suite 没回挂、或缺少实际使用证据，现在都会被 gate 直接拦下。

### Wiring specs split + docs align

- `src/composition/battle_core_wiring_specs.gd` 当前只保留聚合职责。
- 真实 wiring spec 已按 `commands / turn / lifecycle / passives / effects_core / payload_handlers / actions` 拆到子目录。
- `BattleCoreComposer`、架构 gate、`docs/design/architecture_overview.md` 与 `docs/design/battle_core_architecture_constraints.md` 的口径当前一致。

## 验证

- `bash tests/check_architecture_constraints.sh`
- `bash tests/check_repo_consistency.sh`
- `bash tests/check_suite_reachability.sh`
- `bash tests/run_with_gate.sh`

以上命令本地通过。
