# 任务清单（活跃）

本文件只保留仍会直接影响扩角决策、交付验收或回归节奏的现行任务信息。

更早且已关闭的完整记录见：

- `docs/records/archive/tasks_pre_2026-04-05_repair_wave.md`
- `docs/records/archive/tasks_pre_v0.6.4.md`
- `docs/records/archive/tasks_pre_v0.6.3.md`

当前生效规则以 `docs/rules/` 为准；工程落点与交付模板以 `docs/design/` 为准。

## 当前波次：正式角色稳定化三波整合（2026-04-07）

- 状态：已完成
- 目标：
  - 在不新增第 5 个正式角色、不改四角色数值平衡的前提下，把 formal 交付链、pair 回归矩阵、sandbox/demo 真相、content snapshot cache freshness，以及活跃记录可信度一次收口。
- 范围：
  - Wave 1：严格校验 interaction catalog、sandbox demo catalog 化、cache freshness 扩大到 runtime registry 与 content/formal validator 脚本
  - Wave 2：删除手写 `pair_surface_cases`，改为 `matchups + surface_smoke_skill_id` 自动生成 directed surface smoke；interaction 保持显式场景制
  - Wave 3：补齐 Gojo / Sukuna / Kashimo / Obito 的 manager/runtime 黑盒缺口，并同步 README、tests README、design docs 与 records
- 非范围：
  - 不新增正式角色
  - 不改既有技能数值
  - 不把 runtime / delivery registry 合并成单表

## 本轮交付结果

### Wave 1：硬问题收口与开发边界清理

- interaction catalog 当前对 `scenario_id / matchup_id / character_ids[2] / battle_seed` 走硬校验；缺字段、空值、类型错误或 `battle_seed <= 0` 直接 fail-fast。
- `BattleSandboxRunner` 不再写死角色专属 demo 命令流；demo profile 的单一真相固定为 `config/demo_replay_catalog.json`。
- `SampleBattleFactory` 负责根据 demo profile 构建 replay input；demo profile 缺失、非法或 builder 失败时直接失败。
- `ContentSnapshotCache` 的签名输入已扩大到：
  - snapshot 路径列表
  - 顶层资源递归外部 `.tres/.res` 依赖
  - `config/formal_character_runtime_registry.json`
  - `src/battle_core/content/**/*.gd`
  - `src/battle_core/content/formal_validators/**/*.gd`

### Wave 2：pair surface 自动生成与回归矩阵重构

- `config/formal_character_delivery_registry.json` 已补 `surface_smoke_skill_id` 必填字段。
- `config/formal_matchup_catalog.json` 已移除手写 `pair_surface_cases`，当前只保留：
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

- formal runtime / delivery 双表字段与 gate 保持一致，不再回退成手抄或兼容口径
- pair surface 继续由 `matchups + surface_smoke_skill_id` 自动生成，不再恢复手写 surface matrix
- interaction 继续保持显式场景制，且每个 case 都显式带 `battle_seed`
- sandbox/demo 继续只改 `config/demo_replay_catalog.json`，不再把角色专属脚本塞回 runner
- content schema、formal validator、runtime registry 任一变化后，cache freshness 仍会触发 miss
- 新角色接入继续按 `设计稿 + 调整记录 + 内容资源 + SampleFactory 接线 + 角色 suite` 的完整交付面推进

## 最小可玩性检查

- 可启动：`godot --headless --path . --quit-after 20`
- 可操作：sandbox 默认 demo 能启动并完整跑完
- 无致命错误：不得出现 `BATTLE_SANDBOX_FAILED:`、`SCRIPT ERROR:`、`Compile Error:`、`Parse Error:`
