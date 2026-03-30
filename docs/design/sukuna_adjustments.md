# 两面宿傩（Sukuna）调整记录

本文件只记录增量调整，不重复抄写当前冻结设计稿。当前生效方案以 `docs/design/sukuna_design.md` 为准。

领域公共规则另见 `docs/design/domain_field_template.md`。

## 2026-03-29

### 调整：宿傩动态回蓝表上调，先补默认装配的奥义窗口

- 改了什么：
  - 宿傩维持 `required=3 / cap=3 / gain=1`
  - 被动“教会你爱的是...”继续走 `mp_regen set`，但动态回蓝表从 `5 / 4 / 3 / 2 / 1 / 0` 上调到 `9 / 8 / 7 / 6 / 5 / 0`
- 为什么改：
  - 首轮对局复查已证明宿傩默认装配在真实对局里长期拿不到奥义合法窗口，主堵点在回蓝曲线过低
  - 这条调整只处理资源窗口，不直接改领域冲突与伤害模型
  - 直接把奥义点改成 2 会过冲成反向碾压，不适合作为主线平衡修法
- 影响测试：
  - `tests/suites/sukuna_setup_regen_suite.gd`
- 是否改变玩家口径：
  - 是
  - 宿傩现在仍是 3 点开大，但对位接近时能更稳定攒出第一次领域窗口
- 是否改变数值平衡结论：
  - 是
  - 这是第一步温和补强；默认装配不再长期卡在零窗口，但最终强度还要结合后续策略修正一起看
  - 当前固定回归基线下，默认装配的第一次奥义合法窗口落在第 6 回合；反转术式装配落在第 7 回合

## 2026-03-30

### 调整：奥义点、领域对拼与领域绑定增幅收口

- 改了什么：
  - 宿傩加入 `ultimate_points_required = 3`、`ultimate_points_cap = 3`、`ultimate_point_gain_on_regular_skill_cast = 1`
  - `sukuna_domain_cast_buff` 改成 `sukuna_malevolent_shrine_field.effect_ids` 的 `field_apply` 增幅
  - 新增 `sukuna_domain_buff_remove`，在领域自然结束或提前打断时回收 `attack +1 / sp_attack +1`
  - 场上已有领域且本次也是领域时改成进入领域对拼；普通 field 仍按 `field_kind` 冲突矩阵处理
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
  - 当前保留 3 点体系；是否进一步补数值，要看后续固定案例与手动复查结果

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
