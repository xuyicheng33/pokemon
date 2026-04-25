# 鹿紫云一（Kashimo Hajime）调整记录
<!-- anchor:kashimo.adjust.battle-scoped-usage-record -->
<!-- anchor:kashimo.adjust.once-per-battle -->
<!-- anchor:kashimo.adjust.kyokyo-window-refresh -->
<!-- anchor:kashimo.adjust.feedback-strike-dual-charge-burst -->
<!-- anchor:kashimo.adjust.amber-switch-persist -->
<!-- anchor:kashimo.adjust.amber-same-turn-reentry -->

本文件只记录增量调整，不重复抄写当前冻结设计稿。当前生效方案以 `docs/design/kashimo_hajime_design.md` 为准。

## 2026-04-06

### 调整：幻兽琥珀的“一整场一次”改由 battle-scoped 使用记录承接

- 改了什么：
  - `kashimo_phantom_beast_amber` 当前正式开启共享字段 `once_per_battle = true`
  <!-- anchor:kashimo.adjust.once-per-battle -->
  - 合法性与执行链不再只依赖琥珀自带的 `action_legality deny ultimate` 常驻 rule mod，而是额外写入并读取 battle-scoped 使用记录
  <!-- anchor:kashimo.adjust.battle-scoped-usage-record -->
  - `弥虚葛笼` 的 `kashimo_kyokyo_nullify` 在持续中再次施放时，继续按 `stacking=refresh` 把剩余窗口刷新回完整 3 回合
  <!-- anchor:kashimo.adjust.kyokyo-window-refresh -->
- 为什么改：
  - 旧做法只能保证“当前活着这条 runtime state 里别再开第二次”，但挡不住未来出现复活、重建状态或特殊回放装配时把它误放宽成“活着时一次”
  - 琥珀的强化、自伤、奥义封锁仍然保留在角色资源里；“整场一次”则收回共享合法性 contract，更适合作为后续扩角复用模板
- 影响测试：
  - `test/suites/kashimo_amber_suite.gd`
  - `test/suites/kashimo_runtime/charge_loop_suite.gd`
- 是否改变玩家口径：
  - 否
  - 玩家感知仍然是“整场只能开一次”
- 是否改变数值平衡结论：
  - 否
  - 这轮不改鹿紫云强度，只补 battle-scoped 使用记录这层真正的语义兜底

## 2026-04-02

### 调整：鹿紫云正式交付接回奥义，并把共享机制名与生命周期语义收口

- 改了什么：
  - 鹿紫云 unit 从 Phase 1 的“临时禁奥义”切回正式配置：
    - `ultimate_skill_id = kashimo_phantom_beast_amber`
    - `ultimate_points_required = 3`
    - `ultimate_points_cap = 3`
    - `ultimate_point_gain_on_regular_skill_cast = 1`
  - `回授电击` 的额外威力来源正式固定为共享字段 `effect_stack_sum`，不再沿用设计讨论期的临时名
  <!-- anchor:kashimo.adjust.feedback-strike-dual-charge-burst -->
  - `幻兽琥珀` 的强化改为走 `persistent_stat_stages`，并通过 `retention_mode = persist_on_switch` 保证跨换人保留
  <!-- anchor:kashimo.adjust.amber-switch-persist -->
  - `persists_on_switch=true` 的持续效果在“同回合重上场”时，继续暂停普通 `turn_start / turn_end` 触发；下一整回合再恢复
  <!-- anchor:kashimo.adjust.amber-same-turn-reentry -->
  - 鹿紫云正式接入 `formal_character_manifest.json`，旧的手工聚合入口已下线，正式改为 `gdUnit4 + manifest` 统一发现与 formal registry 派生
- 为什么改：
  - Phase 1 的临时禁奥义只适合做主循环隔离交付，不能作为正式角色交付形态留在主线里
  - `effect_stack_sum`、`persistent_stat_stages` 和同回合重上场暂停语义已经变成共享能力，必须落到正式文档与正式回归面，而不是继续留在临时测试口径里
  - formal 角色元数据现在统一收口到 `formal_character_manifest.json` 单真源，鹿紫云不能再靠 `run_all` 的临时直连维持
- 影响测试：
  - `test/suites/formal_character_snapshot_matrix_suite.gd`
  - `test/suites/kashimo_amber_suite.gd`
  - `test/suites/persistent_stat_stage_suite.gd`
  - `test/suites/combat_type_runtime_suite.gd`
  - `tests/run_gdunit.sh`
- 是否改变玩家口径：
  - 否
  - 这轮主要是把已经冻结的角色语义正式接回实现，并把“同回合重上场时琥珀自伤继续暂停”写成共享生命周期规则
- 是否改变数值平衡结论：
  - 否
  - 本轮不改鹿紫云的数值，只补齐正式奥义交付、持久能力阶段载体与交付面登记
