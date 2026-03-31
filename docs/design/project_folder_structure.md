# 项目目录与命名规范（骨架阶段）

本文件定义当前工程的正式目录方案。若目录职责变化，必须先更新本文件，再改仓库结构。

## 1. 目录结构

```text
/
  content/
    battle_formats/
    samples/
    combat_types/
    units/
    skills/
    passive_skills/
    passive_items/
    effects/
    fields/
  docs/
    design/
    rules/
    records/
  scenes/
    boot/
    sandbox/
  src/
    battle_core/
      runtime/
      content/
      contracts/
      commands/
      turn/
      actions/
      math/
      lifecycle/
      effects/
      passives/
      logging/
      facades/
    adapters/
    composition/
    shared/
  tests/
    suites/
    support/
    fixtures/
    helpers/
    replay_cases/
  assets/
```

## 2. 目录职责

|目录|职责|
|---|---|
|`content/`|战斗规则资源定义与最小样例|
|`content/battle_formats`|战斗格式定义资源|
|`content/samples`|最小样例资源与样例对局资源|
|`content/combat_types`|战斗属性定义资源|
|`docs/design/`|工程实现方案文档|
|`docs/rules/`|规则权威文档|
|`docs/records/`|任务与决策记录|
|`src/battle_core/runtime`|运行态对象|
|`src/battle_core/content`|内容 `Resource` 类型|
|`src/battle_core/contracts`|跨模块强类型契约|
|`src/battle_core/*`|领域服务|
|`src/battle_core/facades`|对外围公开的稳定 facade 与公开快照构建辅助|
|`src/adapters`|UI/输入/测试适配层|
|`src/composition`|服务装配入口|
|`src/shared`|无业务依赖的通用工具和常量|
|`scenes/boot`|应用启动入口|
|`scenes/sandbox`|战斗骨架调试场景|
|`tests/suites`|业务回归测试套件|
|`tests/support`|测试 harness 与公共构造器|
|`tests/fixtures`|回放/样例输入|
|`tests/helpers`|预留的测试辅助脚本目录|
|`tests/replay_cases`|预留的 deterministic 回放用例说明目录|
|`assets/`|美术、音频、UI 静态资源|

## 3. 命名规范

|对象|规则|
|---|---|
|脚本文件|`snake_case.gd`|
|类名|`PascalCase`|
|文件夹|`snake_case`|
|场景|`PascalCase.tscn`|
|节点名|`PascalCase`|
|内容资源|`snake_case.tres`|
|样例资源|`sample_*.tres`|

## 4. 约束

1. `content/` 与 `assets/` 语义必须分离，战斗定义资源不允许继续堆到 `assets/`。
2. `battle_core` 不依赖 `adapters`、`composition`、`scenes`。
3. `composition` 可以依赖 `battle_core` 与 `shared`，但不能反向被它们依赖。
4. `shared` 只放通用工具、常量和无领域依赖代码。
5. `tests/` 可以依赖全部公开接口，但不能成为正式运行时依赖。
