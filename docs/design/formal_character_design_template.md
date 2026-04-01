# 正式角色设计模板

本模板用于正式角色设计稿收口。角色稿只保留角色特有信息；共享引擎规则统一引用公共文档，不在角色稿重复定义。

## 固定范围

正式角色稿固定只保留 4 类内容：

1. 角色定位与资源定义
2. 角色特有机制
3. 角色特有验收矩阵
4. 平衡备注

## 共享规则引用

下列内容一律引用公共文档，不在角色稿重复展开：

|共享主题|权威入口|
|---|---|
|换人、离场、bench 持续效果与补位|`docs/rules/04_status_switch_and_lifecycle.md`|
|effect / rule_mod schema、持久 rule_mod、来源分组叠加|`docs/rules/06_effect_schema_and_extension.md`|
|运行时模型与 `EffectInstance / RuleModInstance` 字段|`docs/design/battle_runtime_model.md`|
|内容资源字段与加载期校验|`docs/design/battle_content_schema.md`|
|领域公共流程、对拼与 field_apply_success|`docs/design/domain_field_template.md`|

## 建议结构

### 1. 角色定位与资源定义

- UnitDefinition 面板
- MP / 奥义点
- 默认配招与候选池
- 被动、奥义、关键 effect / field 资源

### 2. 角色特有机制

- 只写该角色独有的玩法差异、资源绑定和共享能力的角色化用法
- 若某能力是共享引擎能力，只写“本角色怎么用”，不重复写完整 schema / 读写路径 / 全局排序链

### 3. 角色特有验收矩阵

- 固定写角色专属断言
- 共享 suite 可作为交付面的一部分被引用，但不在角色稿里重写公共机制全表

### 4. 平衡备注

- 当前冻结值
- 已知平衡风险
- 后续调优入口

## 禁止事项

- 不把共享 effect / rule_mod schema 再抄一遍
- 不在角色稿里重新定义公共领域对拼矩阵
- 不把 manager envelope、public_id 契约、bench 生命周期等全局规则复制到每个角色稿
