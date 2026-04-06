# 任务清单（活跃）

本文件只保留 2026-04-06 repair wave 之后仍会直接指导开发、验收或扩角节奏的活跃任务。

更早且已关闭的完整记录见：

- `docs/records/archive/tasks_pre_2026-04-05_repair_wave.md`
- `docs/records/archive/tasks_pre_v0.6.4.md`
- `docs/records/archive/tasks_pre_v0.6.3.md`

当前生效规则以 `docs/rules/` 为准；工程落点以 `docs/design/` 为准。

## 目录锚点

- 当前波次：扩角前整合修复
- 下一角色扩充准备
- 最小可玩性检查
- 关键回归基线

## 当前波次：扩角前整合修复（2026-04-06）

- 状态：已完成（2026-04-06 扩角前整改整合）
- 目标：
  - 在不新增第 5 名正式角色、不调整四名现有角色数值平衡的前提下，把共享规则、角色高风险边界、formal validator 模板、docs gate 与记录治理统一收口。
- 范围：
  - 共享合法性 / effect 过滤：
    - `on_receive_action_damage_segment` 复用现有 `required_incoming_command_types / required_incoming_combat_type_ids`
    - `SkillDefinition.once_per_battle`
    - `UnitState` battle-scoped 一次性使用记录
  - 角色修复：
    - Obito `阴阳遁` 逐段过滤与 `求道焦土` 禁疗生命周期同步
    - Kashimo `幻兽琥珀` battle-scoped 一次性锁
    - Sukuna `sukuna_refresh_love_regen` 的 `permanent` 语义
  - formal 交付面：
    - entry validator 固定三桶模板
    - 共享 contract helper 复用
    - registry 锚点补全
    - validator 坏例与跨角色 smoke 回挂
  - 文档 / gate：
    - 四角色口径
    - `incoming_heal_final_mod` 白名单与 `stacking_source_key` 枚举
    - `once_per_battle` 与 damage-segment 过滤文档
    - formal registry 路径迁移到 `config/`
    - `SampleBattleFactory.content_snapshot_paths_result()`、formal validator 子目录与大 suite wrapper/sub-suite 口径重新对齐
  - 可扩展性整改：
    - `ReplayRunner` 拆成输入校验/预分组、执行上下文建立、输出组装三段职责
    - `SampleBattleFactory` 保留具名 builder 薄壳，但底层改成统一 side spec/helper 装配
    - formal validator 迁到 `src/battle_core/content/formal_validators/`
    - `400+` 行 suite 按子域拆到 `tests/suites/<wrapper_name_without_.gd>/`
  - 记录治理：
    - `tasks.md / decisions.md` 活跃文件瘦身
    - 2026-04-05 之前历史闭环条目归档
- 验收标准：
  - `config/formal_character_registry.json` 挂齐本轮新增关键回归锚点
  - `repo_consistency_docs_gate.py / repo_consistency_formal_character_gate.py` 能直接校验本轮新规则与三桶模板
  - validator-backed 角色都挂上坏例 suite 与坏例锚点
  - 四名正式角色当前两两组合都至少有一组 manager 级黑盒 smoke 覆盖
  - `tasks.md / decisions.md` 只保留当前波次、下一角色准备项与仍生效活规则
  - `bash tests/check_repo_consistency.sh`
  - `bash tests/run_with_gate.sh`

### 当前执行结果

- 已完成：
  - 架构整合：
    - `SampleBattleFactory` 已改成“正式结果式快照路径 API + 具名 builder 薄壳 + 统一 side spec/helper 装配”
    - `content_snapshot_paths_result()` 现在统一返回 `{ ok, data, error_code, error_message }`
    - `ReplayRunner` 已拆成 input helper / execution context builder / output helper，`ReplayRunner` 自身只保留编排
  - Obito：
    - `阴阳遁` 的逐段叠层与逐段减伤统一只响应敌方 `skill / ultimate`
    - `求道焦土` 的公开禁疗标记与 `incoming_heal_final_mod` 已补同步过期回归
  - Kashimo：
    - `幻兽琥珀` 已开启 `once_per_battle`
    - battle-scoped 使用记录已经进入合法性与执行链
    - 已补 `弥虚葛笼` 二次施放刷新持续时间回归
  - Sukuna：
    - `sukuna_refresh_love_regen` 已从 `duration=999` 收口为 `duration_mode=permanent`
    - snapshot / formal contract /设计文档已改成长期存在、对位变化 replace 的统一口径
  - formal validator：
    - 全部脚本已迁到 `src/battle_core/content/formal_validators/`
    - `shared/` 负责 base / registry loader / 共享 helper
    - `gojo/ sukuna/ kashimo/ obito/` 各自承载角色 validator
    - 四名正式角色 entry validator 已统一成 `unit_passive_contracts / skill_effect_contracts / ultimate_domain_contracts` 三桶模板
    - formal gate 已新增“三桶 wrapper 存在 + entry validator preload/dispatch”结构 smoke
    - Gojo / Sukuna / Kashimo / Obito 现在都补上了 validator 坏例锚点，并统一挂进 `extension_validation_contract_suite.gd`
  - docs / registry：
    - docs gate 已补 `once_per_battle`、四角色口径、`incoming_heal_final_mod`、完整 `stacking_source_key` 枚举与三桶模板文案检查
    - formal registry 已迁到 `config/formal_character_registry.json`
    - formal registry 已补回本轮新增测试锚点、跨角色 smoke 锚点与设计/调整文档锚点
    - `SampleBattleFactory.content_snapshot_paths_result()` 已改成“顶层样例资源 + registry.required_content_paths”显式收口，不再递归扫完整内容树
    - `SampleBattleFactory.content_snapshot_paths_for_setup_result()` 已补 setup-scoped 快照入口；manager smoke / pair smoke / demo replay 不再默认携带全部正式角色内容
    - `ContentSnapshotCache` 已补“外部 `.tres/.res` 依赖改动也会失效”的回归锁，覆盖 `content/shared/` 共享 payload
    - `SampleBattleFactory` 当前已拆成 matchup catalog + replay helper；正式角色 support 不再继续手写阵容数组
    - 四名正式角色当前 manager 级 pair smoke 已补到完整两两组合
    - 大型共享 suite 已统一改成“稳定 wrapper + 子 suite”组织，原测试名保持不变
    - Gojo / Sukuna / Kashimo 的 formal validator 已补关键 effect 顶层字段坏例，避免只锁 payload 不锁 effect surface
  - records：
    - 已新建 repair-wave archive：
      - `docs/records/archive/tasks_pre_2026-04-05_repair_wave.md`
      - `docs/records/archive/decisions_pre_2026-04-05_repair_wave.md`
    - 当前活跃记录已改成短版入口

### 当前验证结果

- 已通过：
  - `godot --headless --path . --script tests/run_all.gd`
  - `python3 tests/gates/repo_consistency_docs_gate.py`
  - `python3 tests/gates/repo_consistency_formal_character_gate.py`
  - `git diff --check`
  - `bash tests/check_repo_consistency.sh`
  - `bash tests/check_architecture_constraints.sh`
  - `bash tests/run_with_gate.sh`

## 下一角色扩充准备

- 新角色进入正式交付链前，必须先完成：
  - 设计稿与调整记录
  - `formal_character_registry.json` 条目
  - `SampleBattleFactory` builder
  - entry validator 三桶模板
  - snapshot / runtime / manager smoke / 必要共享 suite 锚点
  - validator 坏例锚点（若登记了 `content_validator_script_path`）
  - 至少一组和现有正式角色的跨配对 smoke
- 若新角色要消费共享扩展，必须先确认以下文档与 gate 已有明确口径：
  - `once_per_battle`
  - `incoming_heal_final_mod`
  - `damage_segments`
  - `on_receive_action_damage_segment`
  - `required_incoming_command_types / required_incoming_combat_type_ids`
- 下一角色扩充前的预检查：
  - 工作区干净
  - 总闸门全绿
  - 活跃记录已更新

## 最小可玩性检查

- 可启动：`BattleCoreManager.create_session()` 与 sample setup 主链可正常创建对局
- 可操作：双方能完成至少一整回合合法选指与回合推进
- 无致命错误：无 `invalid_battle` 之外的脚本/编译/加载错误

## 关键回归基线

- `godot --headless --path . --script tests/run_all.gd`
- `bash tests/check_repo_consistency.sh`
- `bash tests/check_architecture_constraints.sh`
- `bash tests/run_with_gate.sh`
