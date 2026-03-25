# Passive & Field（被动与场地）

本文件定义被动技能、被动持有物与 field 的接入方式。

## 1. 文件清单

|文件|职责|
|---|---|
|`passive_skill_service.gd`|接入被动技能|
|`passive_item_service.gd`|接入被动持有物|
|`field_service.gd`|管理全场 field|

## 2. 接入原则

- 三者都作为 trigger source 接入效果系统。
- 三者都不自己决定效果排序，排序统一交给 `EffectQueueService`。
- 回合节点触发范围固定为：仅当前在场单位 + 全场 field。

## 3. PassiveSkillService / PassiveItemService

职责：

- 根据定义资源注册触发点
- 在触发点到达时产出 `EffectEvent`

被动持有物的回合节点效果必须受“仅 active 触发”约束，不得让 bench 参与。

## 4. FieldService

职责：

- 创建 field 实例
- 替换旧 field
- 在 `turn_end` 扣减剩余回合
- 到期时产生日志事件

约束：

- 当前同一时刻全场只允许 1 个 field。
- 新 field 成功生效后直接替换旧 field。
