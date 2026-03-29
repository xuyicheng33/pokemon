# 两面宿傩（Sukuna）调整记录

本文件只记录增量调整，不重复抄写当前冻结设计稿。当前生效方案以 `docs/design/sukuna_design.md` 为准。

## 2026-03-29

### 调整：奥义点、领域对拼与领域绑定增幅收口

- 改了什么：
  - 宿傩加入 `ultimate_points_required = 3`、`ultimate_points_cap = 3`、`ultimate_point_gain_on_regular_skill_cast = 1`
  - `sukuna_domain_cast_buff` 改成 `sukuna_malevolent_shrine.effect_ids` 的 `field_apply` 增幅
  - 新增 `sukuna_domain_buff_remove`，在领域自然结束或提前打断时回收 `attack +1 / sp_attack +1`
  - 场上已有 field 时改成进入领域对拼，不再直接覆盖
- 为什么改：
  - 宿傩需要与全局奥义点/领域对拼规则一致
  - 旧设计存在“领域没了，双攻增幅还留着”的状态风险
- 影响测试：
  - `tests/suites/sukuna_suite.gd`
  - `tests/suites/ultimate_field_suite.gd`
  - `tests/suites/replay_turn_suite.gd`
- 是否改变玩家口径：
  - 是
  - 领域增幅改成“只有领域成功立住才会获得，领域消失就一起消失”
- 是否改变数值平衡结论：
  - 是
  - 3 点奥义点体系下，宿傩开大更慢；本轮接受这一结果，不额外补偿数值

## 2026-03-28

### 调整：删除领域后摇，只保留自然到期终爆

- 改了什么：
  - 删除领域结束后的封印与 rollback 设计
  - 保留 `sukuna_domain_expire_burst`
  - 打断路径不再触发任何终爆或后摇
- 为什么改：
  - 旧后摇让宿傩领域语义过重，而且与当前简化原型目标不匹配
- 影响测试：
  - `tests/suites/sukuna_suite.gd`
- 是否改变玩家口径：
  - 是
  - 当前口径固定为“领域自然到期终爆保留，被打断则没有终爆”
- 是否改变数值平衡结论：
  - 是
  - 宿傩的领域收益重新聚焦在展开期和自然结束节点，不再靠额外后摇压制对手
