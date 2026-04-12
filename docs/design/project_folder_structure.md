# 项目目录与命名规范（骨架阶段）

本文件定义当前工程的正式目录方案。若目录职责变化，必须先更新本文件，再改仓库结构。

## 1. 目录结构

```text
/
  config/
  content/
    battle_formats/
    samples/
    shared/
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
        formal_validators/
      contracts/
      commands/
      turn/
      actions/
      math/
      lifecycle/
      effects/
        payload_handlers/
      passives/
      logging/
      facades/
    adapters/
    composition/
      battle_core_wiring_specs/
    shared/
  tests/
    gates/
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
|`content/`|战斗规则资源定义、正式角色资源与共享 payload 资源|
|`config/`|工程级静态配置；当前包含 `formal_character_manifest.json / formal_character_capability_catalog.json / formal_registry_contracts.json / sample_matchup_catalog.json / demo_replay_catalog.json`|
|`content/battle_formats`|战斗格式定义资源|
|`content/samples`|最小样例资源与样例对局资源|
|`content/shared`|供正式角色跨资源复用的共享 payload / helper Resource，不直接作为顶层 snapshot 注册项|
|`content/combat_types`|战斗属性定义资源|
|`docs/design/`|工程实现方案文档|
|`docs/rules/`|规则权威文档|
|`docs/records/`|任务与决策记录|
|`src/battle_core/runtime`|运行态对象|
|`src/battle_core/content`|内容 `Resource` 类型|
|`src/battle_core/content/formal_validators`|formal validator 目录；`shared/` 放共享模板与 registry loader，角色子目录放正式角色 validator|
|`src/battle_core/contracts`|跨模块强类型契约|
|`src/battle_core/*`|领域服务|
|`src/battle_core/effects/payload_handlers`|payload handler 与其子 runtime service；Effects 的正式子域|
|`src/battle_core/facades`|对外围公开的稳定 facade 与公开快照构建辅助|
|`src/adapters`|UI/输入/测试适配层|
|`src/composition`|服务装配入口；`battle_core_wiring_specs/` 收口分域 wiring spec，`battle_core_wiring_specs.gd` 只负责聚合|
|`src/shared`|不依赖 `battle_core` 的共享工具、常量，以及 formal manifest / capability catalog / registry contracts 这类跨子域治理入口|
|`scenes/boot`|应用启动入口|
|`scenes/sandbox`|战斗骨架调试场景|
|`tests/suites`|业务回归测试套件；超阈值时保留稳定 wrapper，并把真实断言下沉到同名子目录|
|`tests/gates`|仓库一致性与架构闸门；当前至少包含 `surface / formal_character / docs` 三类治理入口|
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
4. `shared` 只放不依赖 `battle_core` 的共享代码；允许承载 formal registry / contract 这类跨子域治理入口，但不能反向依赖核心实现。
5. `tests/` 可以依赖全部公开接口，但不能成为正式运行时依赖。
