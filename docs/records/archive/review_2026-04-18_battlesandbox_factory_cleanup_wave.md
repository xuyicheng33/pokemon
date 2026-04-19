# 2026-04-18 BattleSandbox / SampleBattleFactory 收口波次审查处置

本记录用于正式收口本轮对 BattleSandbox 边界、共享 helper、`BattleInitializer` child ports 和 `SampleBattleFactory` 减负的处置，后续复查统一引用本文件。

状态说明：

- 本轮已改完：本轮代码与记录已经落地，并纳入验证
- 本轮明确不改：确认收益不足或会误伤既有契约，本轮只记录原因并保持现状

## 1. BattleSandbox 可变状态外泄

- 状态：本轮已改完
- 处置：
  - `BattleSandboxController` 不再直接暴露运行态字段和 UI 裸引用
  - 新增 session state / view refs 承接运行态与节点引用
  - 测试 support 改走 controller 明确入口

## 2. 共享属性读取重复实现

- 状态：本轮已改完
- 处置：
  - 新增 `src/shared/property_access_helper.gd`
  - adapter / composition / contracts 里的重复 `read_property` 统一复用该 helper

## 3. 外层结果式仍有 `{ok,error}` 变体

- 状态：本轮已改完
- 处置：
  - `src/shared/result_envelope_helper.gd` 继续作为唯一正式结果式入口
  - adapter / composition / shared 触达边界统一收口到 `ok/data/error_code/error_message`

## 4. `BattleInitializer` 子 helper wiring 过于松散

- 状态：本轮已改完
- 处置：
  - 保留 owner 私有 helper 结构
  - 改成显式 ports 配置并补回归，不把 helper 升级成 composer service

## 5. `SampleBattleFactory` 文件碎片过多

- 状态：本轮已改完
- 处置：
  - 保留现有 facade 公开方法与 override 入口
  - 按职责域强力合并内部 helper，明显减少文件数和跳转深度
  - 同步迁移 tests / gates / docs 对旧 helper 路径的引用

## 6. `BattleState` cache-first + fallback rebuild 逻辑

- 状态：本轮明确不改
- 原因：
  - 当前测试明确依赖“外部直接替换 `sides / team_units` 后，查询路径能自动重建索引”的恢复语义
  - 本轮不把这条保护逻辑误改成纯缓存命中即返回

## 7. `BattleState.seed` 命名

- 状态：本轮明确不改
- 原因：
  - 该字段已经深入 replay/hash/测试契约
  - 单纯命名清理会扩成跨层契约改动，收益不够高

## 8. `to_stable_dict()` 通用化

- 状态：本轮明确不改
- 原因：
  - 当前显式序列化仍然是更稳的契约表达
  - 本轮聚焦边界收口，不额外引入声明式序列化抽象
