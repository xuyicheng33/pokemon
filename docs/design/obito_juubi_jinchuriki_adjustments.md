# 宇智波带土（十尾人柱力）调整记录

## 2026-04-05

### 首版正式接入冻结

- 首版正式接入，当前先冻结语义、formal 交付面与测试矩阵。
- 不做平衡回调；先保证资源、validator、suite、registry 与文档口径一致。
- 这轮接入依赖并正式消费以下共享能力：
  - `incoming_heal_final_mod`
  - `execute_target_hp_ratio_lte`
  - `damage_segments`
  - `on_receive_action_damage_segment`
- 影响测试：
  - 新增带土 snapshot / runtime / ultimate / manager smoke suites
  - formal registry 需要新增带土条目与锚点
  - 共享 heal / execute / multihit suites 继续作为带土依赖面的正式回归
