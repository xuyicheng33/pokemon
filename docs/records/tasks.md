# 任务清单（活跃）

本文件只保留仍会直接影响扩角决策、交付验收或回归节奏的现行任务信息。

更早且已关闭的完整记录见：

- `docs/records/archive/tasks_pre_2026-04-05_repair_wave.md`
- `docs/records/archive/tasks_pre_v0.6.4.md`
- `docs/records/archive/tasks_pre_v0.6.3.md`

当前生效规则以 `docs/rules/` 为准；工程落点与交付模板以 `docs/design/` 为准。

## 当前波次：正式角色整合修复波次（2026-04-07）

- 状态：已完成
- 目标：
  - 在不扩第 5 个正式角色、不改四角色数值平衡的前提下，把 formal 合同源、sample/demo 基线、pair interaction 覆盖、manager 黑盒与测试 support/gate 重新收成一套稳定底座。
- 范围：
  - formal 角色元数据收口到 manifest 单真源与共享合同源
  - `SampleBattleFactory` baseline / formal flow 解耦
  - `docs/records` 从机器约束里降级为记录与归档索引
  - pair interaction 改为“每对可多 case + 当前 6 组关键 pair 双向覆盖”
  - Kashimo / Sukuna manager 黑盒补洞
  - support / gate 热点拆分并补结构性回归
- 非范围：
  - 不新增正式角色
  - 不改四角色技能数值与平衡
  - 不扩更多 demo 命令类型

## 当前波次：扩角前整合规范（2026-04-07）

- 状态：进行中
- 目标：
  - 在不新增第 5 个正式角色、不改四角色数值与平衡的前提下，把扩角前最容易持续返工的四个热点先收口：
    - manifest runtime / delivery 视图解耦
    - 角色事实重复维护面收缩
    - `SampleBattleFactory` 家族继续按职责拆分
    - `LegalActionService` 提前拆成稳定子职责
- 范围：
  - 第 1 批：runtime loader 不再依赖 delivery/test 字段；manifest/runtime/delivery 合同、gate 与文档同步
  - 第 2 批：收缩 validator / snapshot 等角色事实重复维护面
  - 第 3 批：拆分 `SampleBattleFactory` 热点职责
  - 第 4 批：拆分 `LegalActionService` 热点职责
- 当前进度：
  - 第 1 批已完成：manifest runtime / delivery 视图解耦已落地并通过 gate
  - 第 2 批已完成：formal 角色 baseline 已收口到共享描述层，snapshot suite 与 formal validator 的基础事实开始共用同一份 descriptor
  - 第 3 批已完成：`SampleBattleFactory` owner 已拆出 `override router + setup access`，path override 广播与 baseline/formal setup 组装不再继续堆在主入口
  - 第 4 批待继续推进
- 非范围：
  - 不改四角色玩法语义
  - 不新增正式角色
  - 不改 battle core 主循环规则

## 本轮交付结果

### Formal / Sample 收口

- formal registry 字段真相已统一到共享合同文件：
  - `config/formal_registry_contracts.json`
  - `src/shared/formal_registry_contracts.gd`
- `SampleBattleFactory` 当前固定采用：
  - baseline catalog：`config/sample_matchup_catalog.json`
  - baseline loader：`src/composition/sample_battle_factory_baseline_matchup_catalog.gd`
  - manifest runtime-view loader：`src/composition/sample_battle_factory_runtime_registry_loader.gd`
  - manifest delivery-view loader：`src/composition/sample_battle_factory_delivery_registry_loader.gd`
- `build_setup_by_matchup_id_result()` 现行为 baseline 优先、formal fallback。
- `build_sample_setup_result()`、legacy demo、passive item demo 已不再依赖 formal manifest 健康度。
- demo 默认 profile 已固定收口为 `kashimo`，并由 `config/demo_replay_catalog.json` 提供单一真相。

### Pair / Gate 重做

- `config/formal_character_manifest.json` 当前允许同一无序正式角色对登记多条 interaction case。
- 当前四正式角色已显式补齐 6 组关键 pair 的双向 interaction case，共 12 条 directional case。
- repo consistency gate 当前固定检查：
  - `scenario_id` 唯一
  - case 字段完整
  - 每个无序正式角色对至少 1 条 case
  - 当前约定的 12 条关键 directional case 都存在
- `docs/records/tasks.md` / `docs/records/decisions.md` 的措辞漂移不再触发机器 gate 失败。

### 黑盒 / Support 拆分

- Kashimo manager 黑盒已补：
  - `feedback_strike`
  - `kyokyo`
- Sukuna manager 黑盒已补：
  - `hatsu`
  - `teach_love`
- support 热点已拆分：
  - `battle_core_test_harness` -> facade + pool/sample helper
  - `combat_type_test_helper` -> facade + cases
  - `damage_payload_contract_test_helper` -> facade + cases
  - `obito_runtime_contract_support` -> facade + heal_block / yinyang helper

## 当前波次：正式角色稳定化三波整合（2026-04-07）

- 状态：已完成
- 目标：
  - 在不新增第 5 个正式角色、不改四角色数值平衡的前提下，把 formal manifest 单真源、pair 回归矩阵、sandbox/demo 真相、content snapshot cache freshness，以及活跃记录可信度一次收口。
- 范围：
  - Wave 1：manifest 单真源、sandbox demo catalog 化、cache freshness 扩大到 manifest 与 content/formal validator 脚本
  - Wave 2：删除手写 `pair_surface_cases`，改为 `matchups + surface_smoke_skill_id` 自动生成 directed surface smoke；interaction 保持显式场景制
  - Wave 3：补齐 Gojo / Sukuna / Kashimo / Obito 的 manager/runtime 黑盒缺口，并同步 README、tests README、design docs 与 records
- 非范围：
  - 不新增正式角色
  - 不改既有技能数值
  - 不新增 battle 规则接口或玩法机制

## 本轮交付结果

### Wave 1：硬问题收口与开发边界清理

- `config/formal_character_manifest.json` 已成为 formal 角色元数据的唯一人工维护真源；`characters / matchups / pair_interaction_cases` 三桶全部走统一 loader/domain model。
- interaction catalog 当前对 `scenario_id / matchup_id / character_ids[2] / battle_seed` 走硬校验；缺字段、空值、类型错误或 `battle_seed <= 0` 直接 fail-fast。
- `BattleSandboxRunner` 不再写死角色专属 demo 命令流；demo profile 的单一真相固定为 `config/demo_replay_catalog.json`。
- `SampleBattleFactory` 负责根据 demo profile 构建 replay input；demo profile 缺失、非法或 builder 失败时直接失败。
- `ContentSnapshotCache` 的签名输入已扩大到：
  - snapshot 路径列表
  - 顶层资源递归外部 `.tres/.res` 依赖
  - `config/formal_character_manifest.json`
  - `src/battle_core/content/**/*.gd`
  - `src/battle_core/content/formal_validators/**/*.gd`

### Wave 2：pair surface 自动生成与回归矩阵重构

- `config/formal_character_manifest.json` 已补 `surface_smoke_skill_id` 必填字段。
- `config/formal_character_manifest.json` 已移除手写 `pair_surface_cases`，当前只保留：
  - `matchups`
  - `pair_interaction_cases`
- `SampleBattleFactory.formal_pair_surface_cases_result()` 当前只返回运行时生成结果，不再读取手写 surface case。
- surface gate 当前固定验证：
  - formal roster 的 directed pair surface coverage 完整
  - 缺 `surface_smoke_skill_id` 或缺合法 directed matchup 时直接 fail-fast
- interaction gate 当前固定验证：
  - 6 组 unordered pair 覆盖完整
  - `scenario_registry` 与 catalog `scenario_id` 一一对应

### Wave 3：四角色黑盒补洞与记录可信度修复

- Gojo：已补 `苍 / 赫 / 茈` 双标记爆发链的 manager 黑盒路径。
- Sukuna：已补 `灶` 的离场结算 manager 黑盒路径。
- Kashimo：已补 `水中外泄` 的 manager 黑盒路径。
- Obito：已补 `六道十字奉火` 的真实 runtime/manager 回归，以及 `阴阳遁` 的 manager 黑盒路径。
- Kashimo / Obito 当前已把 `弥虚葛笼` 领域命中还原、`阴阳遁` 起手生效这类主玩法锚点收回 manager/pair 黑盒主链；runtime suite 只继续保留 probe 型边界断言。
- README / tests README / design docs 已同步：
  - `surface_smoke_skill_id`
  - pair surface 自动生成
  - interaction `battle_seed` 必填
  - demo replay catalog 化
  - cache freshness 语义扩展
- 旧审查记录中仍引用单表 formal registry 的文件已显式标记为历史审查，不再作为现行依据。

## 当前验证基线

- 已通过：
  - `godot --headless --path . --script tests/run_all.gd`
- 本轮完成标准：
  - `tests/run_with_gate.sh`
  - `godot --headless --path . --quit-after 20`
  - formal 四角色 manager smoke、pair smoke、pair interaction 全绿
  - repo consistency gate 与文档口径一致

## 下一步是否扩第 5 个角色的判断线

只有在以下条件继续保持成立时，才建议进入新角色扩充：

- formal manifest 的 `characters / matchups / pair_interaction_cases` 与 gate 保持一致，不再回退成多真源手抄或兼容口径
- pair surface 继续由 `matchups + surface_smoke_skill_id` 自动生成，不再恢复手写 surface matrix
- interaction 继续保持显式场景制，且每个 case 都显式带 `battle_seed`
- sandbox/demo 继续只改 `config/demo_replay_catalog.json`，不再把角色专属脚本塞回 runner
- content schema、formal validator、manifest 任一变化后，cache freshness 仍会触发 miss
- 新角色接入继续按 `设计稿 + 调整记录 + 内容资源 + SampleFactory 接线 + 角色 suite` 的完整交付面推进

## 最小可玩性检查

- 可启动：`godot --headless --path . --quit-after 20`
- 可操作：sandbox 默认 demo 能启动并完整跑完
- 无致命错误：不得出现 `BATTLE_SANDBOX_FAILED:`、`SCRIPT ERROR:`、`Compile Error:`、`Parse Error:`
