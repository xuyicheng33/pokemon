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
- [ ] `SampleBattleFactory` 公开 builder 名称保持稳定，内部只允许走统一 helper，不再为单角色保留私有手写构局
- [ ] `SampleBattleFactory` 正式快照路径读取统一走 `content_snapshot_paths_result()`；正式失败语义不再允许降级成 `null / [] / PackedStringArray()`
- [ ] `config/formal_character_manifest.json` 新增或更新该角色的 `characters[*]` 条目
- [ ] `characters[*]` 至少补齐：
  - [ ] `character_id / display_name / unit_definition_id`
  - [ ] `formal_setup_matchup_id`（默认 formal setup 实际要走的 matchup_id；formal runtime 只认 `character_id + formal_setup_matchup_id`）
  - [ ] `required_content_paths`
  - [ ] `content_validator_script_path`（按需）
  - [ ] `design_doc / adjustment_doc`
  - [ ] `surface_smoke_skill_id`（该正式角色用于自动生成 directed pair surface smoke 的默认黑盒技能）
  - [ ] `suite_path`
  - [ ] `required_suite_paths / required_test_names`
  - [ ] `design_needles / adjustment_needles`（显式 anchor id，不再写自然语言句子）
- [ ] `required_content_paths`
- [ ] `required_suite_paths`
- [ ] `required_test_names`（只保留角色私有 runtime / validator 坏例锚点；共享 pair surface / interaction 由 catalog + shared gate 统一兜）
- [ ] `design_needles / adjustment_needles`（显式 anchor id；要指向“该角色如何消费共享机制”的私有语义锚点，不能直接把共享机制名本身当交付锚点）
- [ ] 若角色存在加载期必须锁死的跨资源不变量，再补 `content_validator_script_path`
- [ ] 若补了 `content_validator_script_path`，只登记在 `config/formal_character_manifest.json.characters[*]` 对应角色条目里；runtime loader 会直接读取 manifest 角色条目并动态装配 validator
- [ ] formal validator 统一放在 `src/battle_core/content/formal_validators/`：`shared/` 放模板与 loader，角色子目录放对应 validator
- [ ] formal validator 优先复用共享模板 helper；角色 validator 只保留角色差异校验，不再复制 unit / skill / effect / field 的通用断言文案
- [ ] formal validator 入口固定收口为三桶：`unit_passive_contracts / skill_effect_contracts / ultimate_domain_contracts`
- [ ] entry validator 只负责 preload 这三桶并串联 `validate()`，不再在入口文件内自由追加角色私有校验
- [ ] 若登记了 `content_validator_script_path`，同时把 `tests/suites/extension_validation_contract_suite.gd` 挂进 `required_suite_paths`
- [ ] 若登记了 `content_validator_script_path`，同时把至少一个 `formal_<character>_validator_*bad_case_contract` 挂进 `required_test_names`
- [ ] `config/formal_character_manifest.json` 新增或更新该角色相关 `matchups / pair_interaction_cases`
- [ ] 确认该角色的 `surface_smoke_skill_id` 能在所有 formal directed matchup 的首发黑盒 smoke 中稳定施放；pair surface 不再手写登记到 catalog
- [ ] 若补 interaction case，`pair_interaction_cases[*]` 必须显式补齐 `scenario_id / matchup_id / character_ids[2] / battle_seed`
- [ ] 若要给该角色补 sandbox/demo 演示，统一改 `config/demo_replay_catalog.json`；`BattleSandboxRunner` 不再写死角色专属命令流

## 4. 测试最低面

每个新角色至少固定 3 类测试：

### A. Snapshot suite

- [ ] `tests/suites/<character>_snapshot_suite.gd`
- [ ] 优先复用共享 snapshot helper / formal character test support，不再为单角色复制 `_build_content_index()` 与 `_run_checks()` 模板
- [ ] 锁 `UnitDefinition` 字面量
- [ ] 锁技能资源字面量
- [ ] 锁关键 effect / field / passive 资源字面量

### B. Runtime suite

- [ ] `tests/suites/<character>_suite.gd` 作为 wrapper
- [ ] 至少 1 个角色独有 runtime 子 suite
- [ ] 若共享或角色 wrapper 超过维护阈值，保持原 wrapper 文件名与测试名不变，并把断言本体下沉到 `tests/suites/<wrapper_name_without_.gd>/`
- [ ] 锁角色主玩法路径，而不是只测通用 contract

### C. Manager smoke suite

- [ ] `tests/suites/<character>_manager_smoke_suite.gd`
- [ ] 优先复用共享 manager smoke helper，统一 `build_manager -> create_session -> close_session` 黑盒样板
- [ ] 覆盖 `create_session -> get_legal_actions -> build_command -> run_turn -> get_public_snapshot / get_event_log_snapshot`
- [ ] 断言公开快照与事件日志不泄漏 runtime private id

### D. 共享 suite 回挂

- [ ] 若共享领域 / 奥义点 / 合法性 suite 属于正式交付面，必须显式挂到 `required_suite_paths`
- [ ] 若角色依赖共享 `missing_hp heal / incoming_heal_final_mod / execute_* / damage_segments / on_receive_action_damage_segment` 等扩展能力，对应共享 suite 也必须显式挂到 `required_suite_paths`
- [ ] 若角色依赖共享 `required_target_effects / incoming_accuracy / power_bonus_source=effect_stack_sum` 等扩展能力，对应共享 suite 也必须显式挂到 `required_suite_paths`
- [ ] 共享 pair surface / interaction 不再逐角色手抄进 `required_test_names`；统一改在 `config/formal_character_manifest.json.matchups / pair_interaction_cases` 收口并由 shared gate 校验覆盖完整性
- [ ] 不允许只靠通用 contract suite 兜角色回归
- [ ] 至少补一组“该角色 + 另一名正式角色”的黑盒 smoke，避免正式角色配对覆盖只堆在单一对局上

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

## 7. 共享语义归属

角色稿默认只保留：

- 角色独有玩法
- 数值口径
- 验收矩阵
- 与共享机制的差异说明

以下语义已属于共享主线，必须回收进公共设计文档，不再在角色稿里重复承载引擎规范：

- `damage_segments`
- `on_receive_action_damage_segment`
- `incoming_heal_final_mod`
- `execute_*`
- `effect_stack_sum`
- `persistent_stat_stages`
- `incoming_action_final_mod`
