# 五条悟（Gojo Satoru）调整记录

本文件只记录增量调整，不重复抄写当前冻结设计稿。当前生效方案以 `docs/design/gojo_satoru_design.md` 为准。

## 2026-03-29

### 调整：奥义点、领域对拼与领域绑定增幅收口

- 改了什么：
  - 五条悟加入 `ultimate_points_required = 3`、`ultimate_points_cap = 3`、`ultimate_point_gain_on_regular_skill_cast = 1`
  - `gojo_domain_action_lock` 从技能平级 `effects_on_hit_ids` 挪到 `gojo_apply_domain_field.payload.on_success_effect_ids`
  - `gojo_domain_cast_buff` 改成 `gojo_unlimited_void_field.effect_ids` 的 `field_apply` 增幅
  - 新增 `gojo_domain_buff_remove`，在领域自然结束或提前打断时回收 `sp_attack +1`
  - 场上已有 field 时改成进入领域对拼，不再直接覆盖
- 为什么改：
  - 旧实现无法表达“领域对拼失败时不锁人”
  - 旧设计会留下“领域消失但 buff 还残留”的脏状态
  - 需要把 Gojo 与全局新规则统一到同一套奥义点/field contract
- 影响测试：
  - `tests/suites/gojo_suite.gd`
  - `tests/suites/ultimate_field_suite.gd`
  - `tests/suites/replay_turn_suite.gd`
- 是否改变玩家口径：
  - 是
  - 当前玩家口径从“无量空处命中后锁人、并自带增幅”改为“无量空处领域成功立住后才锁人，增幅也只跟着领域存在”
- 是否改变数值平衡结论：
  - 是
  - 五条悟奥义从纯 MP 门槛改成 `3` 点奥义点后才可开启，但仍保留苍 / 赫 / 茈与无下限的原有玩法闭环

## 2026-03-28

### 调整：删除领域后摇

- 改了什么：
  - 删除无量空处结束后的额外封印/回滚后摇口径
- 为什么改：
  - 旧后摇同时增加实现复杂度和解释成本，而且和宿傩已经收口后的领域语义不一致
- 影响测试：
  - `tests/suites/gojo_suite.gd`
- 是否改变玩家口径：
  - 是
  - 无量空处结束后不再额外给五条悟自己加负面状态
- 是否改变数值平衡结论：
  - 是
  - 五条悟领域收益更集中在“成功立场后的 3 回合窗口”，不再靠领域结束后的自损来做二次平衡
