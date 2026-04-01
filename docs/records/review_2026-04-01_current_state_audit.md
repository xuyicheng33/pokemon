# 2026-04-01 当前项目完整审查记录

## 结论

- 当前主线没有发现会阻断继续开发的红灯问题。
- `bash tests/run_with_gate.sh` 于 2026-04-01 本地通过，最近几次提交没有引入可复现的新回归。
- 但如果下一步要继续大规模扩角色，建议先做一轮“规范整合”而不是直接扩角；当前主要风险不在功能能不能跑，而在角色约束、回归模板和文档形态会不会失控。
- 本轮已顺手补齐 4 个低风险缺口：
  - `stacking=none` 的重复施加不再额外写 `EFFECT_APPLY_EFFECT` 日志，并已补回归
  - `SukunaKamadoSuite` 新增 `sukuna_kamado_natural_expire_path`
  - 宿傩正式角色注册表补挂 `kamado stack cap / forced replace / natural expire / domain break on faint`
  - `BattleCoreTestHarness.build_loaded_content_index()` 改成内容快照加载失败即断言终止

## 本轮审查范围

- 架构与文档：
  - `README.md`
  - `docs/design/*.md`
  - `docs/rules/*.md`
  - `docs/records/formal_character_registry.json`
- 角色内容与实现：
  - `content/units/gojo/*`
  - `content/skills/gojo/*`
  - `content/effects/gojo/*`
  - `content/passive_skills/gojo/*`
  - `content/fields/gojo/*`
  - `content/units/sukuna/*`
  - `content/skills/sukuna/*`
  - `content/effects/sukuna/*`
  - `content/passive_skills/sukuna/*`
  - `content/fields/sukuna/*`
  - 相关 `src/battle_core/**/*`
  - 相关 `tests/suites/**/*`
- 最近提交：
  - `df059e1 refine: bind marker ownership and split hot suites`
  - `45f9159 fix: guard disposed manager reuse`
  - `bd898d6 fix: guard initializer helper dependencies`
  - `6dec8c5 refine: unify action legality and repo gates`

## 阻断级问题

- 本轮未发现阻断级问题。

## 发现的问题与风险

### 1. `stacking=none` 的重复施加日志语义问题已在本轮修复

- 证据：
  - `docs/rules/06_effect_schema_and_extension.md:197-204`
  - `src/battle_core/effects/effect_instance_service.gd:20-23`
  - `src/battle_core/effects/payload_handlers/payload_state_handler.gd:85-113`
- 原问题：
  - `EffectInstanceService.create_instance()` 在 `stacking=none` 且已有实例时直接返回旧实例。
  - `PayloadStateHandler._apply_effect_payload()` 会把“未新建实例”的返回值继续当成一次成功施加，写出 `EFFECT_APPLY_EFFECT` 日志。
- 本轮处理：
  - 现在 `stacking=none` 的重复施加会统一标记为 skipped，不再额外写 apply log。
  - 已新增 `apply_effect_none_repeat_skips_log` 回归，锁死“实例未变化时不追加 apply log”的语义。
- 结论：
  - 这个点已不再属于后续扩角前必须先修的遗留项。

### 2. `persists_on_switch` 目前只保住了 effect instance，本轮扩角若引入“跨离场持续 rule_mod”会直接踩语义坑

- 证据：
  - `docs/rules/04_status_switch_and_lifecycle.md:44-49`
  - `src/battle_core/lifecycle/leave_service.gd:21-33`
- 当前状态：
  - 离场时会按 `persists_on_switch` 保留部分 effect instance。
  - 但同一个离场流程会无条件 `unit_state.rule_mod_instances.clear()`。
- 风险：
  - 这意味着将来一旦出现“效果实例声明跨换人保留，但它落地时还伴随单位级 `rule_mod`”的角色或机制，离场后会留下半残状态：effect 还在，rule mod 没了。
  - 当前 Gojo / 宿傩没有踩到这条线，所以现有测试不会报红；但它是继续扩角前必须先定口径的基础设施坑。
- 建议：
  - 二选一尽快收口：
    - 要么正式禁止“`persists_on_switch=true` 的效果在运行时生成跨离场依赖的 rule_mod”
    - 要么把 leave 流程改成只清非持久 rule_mod，并补回归锁死

### 3. Gojo 的跨资源不变量还没进入“加载期硬校验”，目前主要靠文档 + snapshot/runtime suite 守住

- 证据：
  - `docs/records/formal_character_registry.json:2-74`
  - `src/battle_core/content/content_snapshot_formal_character_registry.gd:4-37`
  - `docs/design/gojo_satoru_design.md:403-410`
  - `docs/design/gojo_satoru_design.md:566-579`
- 当前状态：
  - 宿傩已经挂了 `content_validator_script_path`，用加载期 validator 锁三处固定火伤一致性。
  - Gojo 没有对应 formal validator。
  - Gojo 的关键语义，例如“双标记 + same-owner 前置守卫”“领域成功才锁人”“标记 refresh / switch 生命周期”，现在主要由测试和文档保证。
- 风险：
  - 如果有人只改了某个 `.tres`，又没有完整跑 suite，内容仍可能加载成功，但正式角色语义已经漂了。
  - 这会直接提高后续扩角时的维护成本，因为同类“角色私有不变量”没有统一的落点。
- 建议：
  - 给 Gojo 补一个 formal validator，至少把 `gojo_murasaki_conditional_burst` 与双标记资源之间的关键关联收成加载期 fail-fast。

### 4. 角色回归目前偏“内部 harness 驱动”，公开 manager 流程上的角色级端到端覆盖还不够厚

- 证据：
  - `tests/suites/gojo_murasaki_suite.gd:17-91`
  - `tests/support/gojo_test_support.gd:17-40`
  - `tests/support/gojo_test_support.gd:71-77`
  - `tests/suites/sukuna_setup_skill_runtime_suite.gd:15-113`
  - `tests/support/sukuna_setup_regen_test_support.gd:27-83`
- 当前状态：
  - Gojo / 宿傩的大多数专项 suite 都是直接拿 `core / content_index / battle_state`，然后调用 `turn_loop_controller`、`legal_action_service` 或直接往运行态塞前置状态。
  - 这种测试很适合锁引擎 contract，但不是完整的公开 API 路径。
- 风险：
  - 如果未来 `BattleCoreManager` 的 envelope、`public_id` 映射、session 级隔离或 `build_command()` 约束对角色动作产生了角色特有回归，现有角色 suite 不一定第一时间抓到。
  - 当前 generic manager suite 能兜一部分，但还不够角色化。
- 建议：
  - 给正式角色各补 1 组 manager 级 smoke：`create_session -> get_legal_actions -> build_command -> run_turn -> get_public_snapshot / get_event_log_snapshot`。

### 5. `mp_regen / incoming_accuracy` 当前的 stacking key 会把“同 owner、同 mod_op”的多来源修正器静默折叠成一个

- 证据：
  - `src/battle_core/content/rule_mod_schema.gd:10-15`
  - `src/battle_core/effects/rule_mod_write_service.gd:27-41`
- 当前行为：
  - `mp_regen` 与 `incoming_accuracy` 的 stacking key 都只看 `mod_kind / scope / owner_scope / owner_id / mod_op`。
  - 这意味着同一单位身上，两个不同来源的 `mp_regen add` 或 `incoming_accuracy add`，第二个实例会直接命中旧 key，运行态不会并存。
- 风险：
  - 宿傩当前单一被动回蓝路径还能工作，所以现状不炸。
  - 但如果你后面再加“回蓝被动 + 回蓝持有物”“命中干扰被动 + 命中干扰 field”这类组合，玩法会出现“资源写出来了、加载也通过了、结果运行时不叠”的暗坑。
- 建议：
  - 在扩新角色前，先明确这是“刻意只允许一个来源”还是“暂时的实现简化”。
  - 如果希望未来可组合，就要先重审 stacking key schema，再补回归。

### 6. 角色设计文档已经开始同时承载“角色设计 + 引擎扩展方案 + 验收矩阵 + 平衡备注”，继续扩角会显著放大文档维护成本

- 证据：
  - `docs/design/gojo_satoru_design.md:385-455`
  - `docs/design/gojo_satoru_design.md:540-609`
  - `docs/design/sukuna_design.md:245-320`
- 当前状态：
  - Gojo 文档不仅写角色设计，还写了 `required_target_same_owner`、`incoming_accuracy` 这类已经进入共享主线的引擎扩展规范。
  - Gojo / 宿傩文档里都带了较长的专项验收矩阵与平衡说明。
- 风险：
  - 现在靠 repo consistency gate 还能勉强压住漂移，但新增第 3、第 4 个正式角色后，角色稿会越来越像“半个系统规范副本”。
  - 这不是今天会炸的 bug，但会明显拖慢扩角速度，并增加误同步成本。
- 建议：
  - 在扩新角色前，先抽一份“正式角色模板”：
    - 角色稿只保留角色特有玩法与数值。
    - 引擎扩展约束全部回收到共享设计文档。
    - 验收矩阵抽成统一模板，只在角色稿里列差异项。

### 7. 本轮已顺手补齐的低风险缺口

- `stacking=none` 的重复施加现在会标记为 skipped，不再额外写 `EFFECT_APPLY_EFFECT` 日志，并已补 `apply_effect_none_repeat_skips_log` 回归。
- `BattleCoreTestHarness.build_loaded_content_index()` 现在会在内容快照加载失败时立刻断言终止，不再把资源加载问题拖到后续测试里才间接暴露。
- `SukunaKamadoSuite` 已新增 `sukuna_kamado_natural_expire_path`，宿傩“灶自然到期终爆”已进入专项 runtime 回归。
- 宿傩正式角色注册表已补挂 `natural expire / stack cap / forced replace / domain break on faint` 等关键测试锚点。
- 宿傩设计稿已明确区分“6 维面板 BST”与“7 维被动公式口径”，当前文档与 `UnitBstHelper` 一致。

## Gojo / 宿傩实现对齐结论

### Gojo

- 设计稿、资源和运行时实现总体对齐。
- `苍 / 赫 / 茈 / 无下限 / 无量空处` 的关键 contract 当前都有对应 snapshot 或 runtime suite 锁住。
- 最近 `same-owner` 收口已经接线到资源、执行器和测试面，当前没有发现新回归。

### 宿傩

- 设计稿、资源和运行时实现总体对齐。
- `解 / 捌 / 开 / 反转术式 / 伏魔御厨子 / 教会你爱的是...` 当前都已经落进正式回归面。
- 本轮已把“灶自然到期终爆”和若干已存在但未挂 formal anchor 的关键测试补回正式交付面。
- 宿傩的已知问题仍然是平衡层而不是实现层：`docs/design/sukuna_design.md:7-13` 已明确写了“Gojo 对位里领域对拼仍长期立不住”。

## 单文件体量风险结论

- 当前没有运行时代码文件超过架构硬门禁 `250` 行。
- 本轮扫描到的最大运行时代码文件：
  - `src/battle_core/turn/battle_result_service.gd`：217 行
  - `src/battle_core/actions/action_executor.gd`：206 行
  - `src/battle_core/turn/turn_loop_controller.gd`：202 行
  - `src/battle_core/facades/battle_core_manager.gd`：202 行
  - `src/battle_core/effects/rule_mod_write_service.gd`：201 行
- 结论：
  - 现在还不能叫“单个运行时文件已经长成屎山”。
  - 但上述 5 个文件都属于高编排密度 owner，继续扩机制时最容易再次膨胀。
  - 反而更大的文件主要集中在测试套件，当前最大约 300 行，仍低于测试门禁 `600` 行。

## 最近提交回看结论

### `df059e1 refine: bind marker ownership and split hot suites`

- 结论：方向正确，没有发现新的破坏性回归。
- 正向变化：
  - `same-owner` 语义已真正落到资源、执行器和 suite。
  - 原本过热的大 suite 已开始拆分，测试组织比之前更清楚。
- 残余风险：
  - 上面第 2、3 条风险依旧存在，说明这次提交主要解决了“功能正确性”，还没把“扩角模板化”做完。

### `45f9159 fix: guard disposed manager reuse`

- 结论：修复有效，manager 生命周期更清楚。
- 本轮闸门中对应 contract suite 已通过，未见新问题。

### `bd898d6 fix: guard initializer helper dependencies`

- 结论：修复有效，初始化路径的 fail-fast 更完整。
- `BattleInitializer` 的 helper 依赖检查现在更稳，但 owner 文件仍属于后续需要继续观察的高编排点。

### `6dec8c5 refine: unify action legality and repo gates`

- 结论：这次提交没有引入当前可见新回归，反而把 gate 和 helper 切得更清楚。
- 同时也说明项目已经进入“规则很多、闸门也很多”的阶段，扩角前做一次模板整合是值得的。

## 审查建议

- 如果你现在的目标是“尽快再接新角色”，项目能撑，但会把上面 2-5 这几类维护风险继续放大。
- 如果你想控制后续接角色的成本，我建议先做一轮整合规范，再扩角色。优先顺序：
  1. 收口 `persists_on_switch` 与 `rule_mod` 的跨离场语义。
  2. 给 Gojo 补 formal content validator，并抽角色 validator 模板。
  3. 给正式角色补 manager 级端到端 smoke 模板。
  4. 抽离“正式角色设计模板”，把共享引擎扩展说明从角色稿挪回共享文档。

## 本轮验证

- `bash tests/run_with_gate.sh`：通过
