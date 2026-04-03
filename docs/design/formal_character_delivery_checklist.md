# 正式角色接入清单

本清单用于把“新角色设计稿”真正落成“正式角色交付面”。

默认规则：

- 若只是新角色复用现有机制，不新增 `decisions.md`
- 只有引入新 trigger / payload / schema / 生命周期口径时，才补 `docs/records/decisions.md`
- 不允许只交 `.tres` + 零散测试；必须走完整正式角色交付面

## 1. 文档与记录

### 必做

- [ ] 设计稿：`docs/design/<character>_design.md`
- [ ] 调整记录：`docs/design/<character>_adjustments.md`
- [ ] 若是领域角色：设计稿末尾追加“领域角色差异附录”，公共规则继续引用 `docs/design/domain_field_template.md`
- [ ] `docs/records/tasks.md` 新增本轮任务记录，写清目标、范围、验收标准与验证结果

### 条件触发

- [ ] 只有当角色接入引入了新 trigger / payload / schema / 生命周期规则时，才更新 `docs/records/decisions.md`

## 2. 内容资源

至少补齐以下资源目录：

- [ ] `content/units/<character>/`
- [ ] `content/skills/<character>/`
- [ ] `content/effects/<character>/`
- [ ] `content/passive_skills/<character>/`
- [ ] `content/fields/<character>/`（如果没有 field，可不建）

资源要求：

- [ ] `UnitDefinition` 写清 `skill_ids / candidate_skill_ids / ultimate_skill_id / passive_skill_id`
- [ ] 关键 effect / field / passive 资源与设计稿名称一致
- [ ] 若角色存在跨资源共享不变量，评估是否需要 `content_validator_script_path`

## 3. 接线与正式交付面

- [ ] `SampleBattleFactory` 增加该角色相关构局入口，避免 suite 内手写拼装
- [ ] `docs/records/formal_character_registry.json` 新增角色条目
- [ ] registry 至少补齐：
  - [ ] `character_id / display_name / unit_definition_id`
  - [ ] `design_doc / adjustment_doc`
  - [ ] `suite_path`
  - [ ] `sample_setup_method`（必须与 `SampleBattleFactory` 里的 builder 方法名完全一致）
  - [ ] `required_content_paths`
  - [ ] `required_suite_paths`
  - [ ] `required_test_names`
- [ ] 若角色存在加载期必须锁死的跨资源不变量，再补 `content_validator_script_path`
- [ ] 若补了 `content_validator_script_path`，同步刷新 `src/battle_core/content/formal_character_validator_registry.json`，并确保 `character_id / content_validator_script_path` 与 docs registry 完全一致

## 4. 测试最低面

每个新角色至少固定 3 类测试：

### A. Snapshot suite

- [ ] `tests/suites/<character>_snapshot_suite.gd`
- [ ] 锁 `UnitDefinition` 字面量
- [ ] 锁技能资源字面量
- [ ] 锁关键 effect / field / passive 资源字面量

### B. Runtime suite

- [ ] `tests/suites/<character>_suite.gd` 作为 wrapper
- [ ] 至少 1 个角色独有 runtime 子 suite
- [ ] 锁角色主玩法路径，而不是只测通用 contract

### C. Manager smoke suite

- [ ] `tests/suites/<character>_manager_smoke_suite.gd`
- [ ] 覆盖 `create_session -> get_legal_actions -> build_command -> run_turn -> get_public_snapshot / get_event_log_snapshot`
- [ ] 断言公开快照与事件日志不泄漏 runtime private id

### D. 共享 suite 回挂

- [ ] 若共享领域 / 奥义点 / 合法性 suite 属于正式交付面，必须显式挂到 `required_suite_paths`
- [ ] 不允许只靠通用 contract suite 兜角色回归

### E. Replay case（按需）

- [ ] 若角色存在特别容易漂移的固定案例，再补 `tests/replay_cases/*`

## 5. 最终验证

- [ ] `git diff --check`
- [ ] `bash tests/run_with_gate.sh`
- [ ] 复核设计稿、registry、resource id、suite 名称一致

## 6. 干跑顺序

建议按这个顺序施工：

1. 先写设计稿和调整记录
2. 再落 `.tres` 资源
3. 再补 `SampleBattleFactory` 与 formal registry
4. 再补 `snapshot / runtime / manager smoke`
5. 最后更新 `tasks.md`，必要时补 `decisions.md`

这样可以避免“测试名、resource id、registry 锚点”来回改喵。
