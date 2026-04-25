# 宇智波带土（十尾人柱力）调整记录
<!-- anchor:obito.adjust.formal-first-delivery -->
<!-- anchor:obito.adjust.yinyang-dun-skill-ultimate-filter -->
<!-- anchor:obito.adjust.heal-block-sync-expire -->
<!-- anchor:obito.adjust.no-balance-retune -->
<!-- anchor:obito.adjust.tests-impacted -->

## 2026-04-06

### 调整：阴阳遁逐段过滤与禁疗生命周期同步收口到共享 contract

- 改了什么：
  - `阴阳遁` 的逐段减伤与叠层监听统一复用现有 `required_incoming_command_types / required_incoming_combat_type_ids` 过滤，不新增角色私有字段
  - 当前明确只响应敌方 `skill / ultimate` 的逐段直接伤害；非主动技段伤害不会再给带土白送叠层
  <!-- anchor:obito.adjust.yinyang-dun-skill-ultimate-filter -->
  - `求道焦土` 的公开禁疗标记与 `incoming_heal_final_mod` 固定要求在同一 `turn_end` 节点同步过期
  <!-- anchor:obito.adjust.heal-block-sync-expire -->
- 为什么改：
  - 旧口径虽然已经接入 `on_receive_action_damage_segment`，但没有把“哪些段伤害能触发”彻底收回共享过滤 contract，后续扩角会继续留下语义歧义
  - 禁疗标记和 heal block rule mod 若不锁成同窗失效，公开快照与真实治疗行为会发生肉眼可见的漂移
- 影响测试：
  - `test/suites/obito_runtime_yinyang_suite.gd`
  - `test/suites/obito_runtime_passive_and_seal_suite.gd`
  - `test/suites/multihit_skill_runtime/damage_segments_suite.gd`

## 2026-04-05

### 首版正式接入冻结

<!-- anchor:obito.adjust.formal-first-delivery -->

- 首版正式接入，当前先冻结语义、formal 交付面与测试矩阵。
- 不做平衡回调；先保证资源、validator、suite、registry 与文档口径一致。
<!-- anchor:obito.adjust.no-balance-retune -->
- 这轮接入依赖并正式消费以下共享能力：
  - `incoming_heal_final_mod`
  - `execute_target_hp_ratio_lte`
  - `damage_segments`
  - `on_receive_action_damage_segment`
- 影响测试：
  <!-- anchor:obito.adjust.tests-impacted -->
  - 新增带土 snapshot / runtime / ultimate / manager smoke suites
  - formal registry 需要新增带土条目与锚点
  - 共享 heal / execute / multihit suites 继续作为带土依赖面的正式回归
