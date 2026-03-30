# 领域角色模板（Domain Field Template）

本文件定义领域型角色的公共接入模板。规则权威仍以 `docs/rules/05_items_field_ai_and_logging.md` 与 `docs/rules/06_effect_schema_and_extension.md` 为准；本文件只收口“新角色做领域时，工程和内容应如何落地”。

当前 Gojo / Sukuna 都必须遵守这套模板；后续新领域角色默认沿用，不再从角色稿里重复发明一套冲突矩阵。

## 1. 公共规则

- 领域技能必须显式声明 `is_domain_skill = true`。
- 领域技能施加的 field 必须是 `field_kind = domain`。
- `domain vs domain` 才进入领域对拼；比较值固定为双方在各自动作扣费后的当前 MP。
- `domain vs normal`：新领域直接替换旧普通 field。
- `normal vs domain`：新普通 field 被阻断，并写 `effect:field_blocked`。
- 同回合双方都已排队施放领域时，后手领域动作不得被 action lock 或合法性回溯取消，必须进入对拼。
- 己方领域在场时，己方不得再次施放己方领域技能；该限制不影响对手领域，也不影响普通 field。

## 2. 成功与失败语义

- field 真正成功落地后，才继续执行 `field_apply`。
- “只有领域成功立住后才成立”的附带效果，统一放在 `ApplyFieldPayload.on_success_effect_ids`，并通过 `field_apply_success` 触发。
- 领域对拼失败方：
  - field 不落地
  - 领域成功后附带链不执行
  - field 绑定增幅不成立
  - 只允许保留奥义本体伤害或本体动作已产生的结算结果

## 3. 领域增幅模板

- 领域增幅必须写在 `FieldDefinition.effect_ids` 里，通过 `field_apply` 生效。
- 领域结束清理必须写在：
  - `on_break_effect_ids`
  - `on_expire_effect_ids`
- 不允许把领域增幅做成脱离 field 生命周期的独立常驻 buff。
- 若领域有自然到期专属收益，必须只放在 `on_expire_effect_ids`；被打断时不得误触发。

## 4. 生命周期要求

- 领域创建者离场、被强制换下或被击倒时，旧领域必须在补位与新单位 `on_enter` 之前打断。
- `field_break` 只执行 `on_break_effect_ids`，不执行自然到期链。
- `field_expire` 只在自然到期路径触发，并写 `effect:field_expire`。
- `field_break / field_expire` 链上，`scope=self` 的清理 effect 允许命中“已离场但仍存活”的领域创建者运行态。

## 5. 日志与回放要求

- `domain vs domain` 必须写 `effect:field_clash`。
- 平 MP tie-break 时必须写出 `effect_roll`，保证 replay 可复现。
- 普通 field 被领域阻断时必须写 `effect:field_blocked`。
- 领域成功后附带链的日志归因，继续沿用真实上游 `cause_event_id` 语义，不单独发明领域专用旁路。

## 6. 角色稿只保留差异项

角色设计稿在领域章节里只需要写：

- 领域技能本体数值与类型
- 本角色领域成功后附带的差异化收益
- 本角色领域自然到期/被打断时的差异化收益或损失
- 与公共模板相比的少数特化边界

角色稿不再重复定义以下公共规则：

- 对拼比较轴
- `field_apply_success` 用法
- `normal vs domain` / `domain vs normal` 冲突矩阵
- 己方领域重开禁用
- 同回合双开域不被回溯取消

## 7. 最小验收

新领域角色接入时，至少补齐以下回归：

- 领域成功落地
- 领域对拼失败
- 平 MP tie-break 可复现
- 己方领域在场时不可重开
- 对手领域在场时仍可提交己方领域
- 普通 field 被领域阻断
- 领域绑定增幅在自然到期与提前打断后都能正确回收
