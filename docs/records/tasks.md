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
  - `config/formal_character_delivery_registry.json` 挂齐本轮新增关键回归锚点
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
    - formal registry 已迁到 `config/formal_character_runtime_registry.json + config/formal_character_delivery_registry.json`
    - runtime / delivery registry 已补回本轮新增测试锚点、跨角色 smoke 锚点与设计/调整文档锚点
    - `SampleBattleFactory.content_snapshot_paths_result()` 已改成“顶层样例资源 + runtime registry.required_content_paths”显式收口，不再递归扫完整内容树
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

## Formal 交付层整合收口计划（2026-04-06）

- 状态：已完成
- 目标：
  - 按“两阶段收口”把正式角色接入链压回单一失败语义、单一场景来源，以及清晰的 runtime / delivery 元数据边界。
- 范围：
  - `SampleBattleFactory` 结果式接口与调用面
  - formal runtime / delivery registry loader、gate 与 fixture
  - pair interaction wrapper / support / catalog 分发链
  - replay 公开契约文档
  - `damage_segments` 共享 schema / validator / Obito 设计稿口径
  - 活跃 README / tests README / delivery checklist / design template / folder structure 等交付文档
- 验收标准：
  - 活跃代码不再回读旧单表 legacy formal registry。
  - pair interaction wrapper 不再维护本地 scenario 清单，也不再直连别的 suite 私有 `_test_*`。
  - formal runtime 只读 runtime registry，delivery / suite / 文档 gate 只读 delivery registry。
  - `run_replay` 文档与 manager envelope 实现一致。
  - `damage_segments` 非空时顶层 `power` 固定为 `0`，共享文档与 validator 口径一致。
  - `bash tests/run_with_gate.sh` 全绿。

### 执行结果

- `tests/suites/content_validation_core/formal_registry_suite.gd` 已补齐 split 后的 fixture 与坏例：
  - alias / mismatch 用例分别构造 runtime + delivery fixture
  - runtime duplicate `unit_definition_id`、runtime 缺字段、runtime 缺 validator path、delivery 缺字段全部有独立坏例
  - `character_id != unit_definition_id` 继续保留并验证可用
- `tests/suites/formal_character_pair_smoke/interaction_suite.gd` 已收成纯 wrapper：
  - 只按 catalog 注册 case 并分发到 suite-local `interaction_support.gd`
  - 本地 scenario 清单与跨 suite 私有 `_test_*` 直连已移除
- pair interaction 断言已下沉到 `tests/support/formal_pair_interaction_test_support.gd`，suite-local `interaction_support.gd` 只做单一转发；旧的重复 support 脚本已移除，避免再长出第二套真相
- `tests/gates/repo_consistency_formal_character_gate.py` 已同步到新的 pair interaction support 路径，并新增静态防回退检查：
  - wrapper 必须 preload suite-local helper
  - suite-local helper 必须继续路由到 `tests/support/formal_pair_interaction_test_support.gd`
- 活跃文档已统一到当前口径：
  - `BattleCoreManager.run_replay()` 对外是 manager envelope
  - formal registry 为 runtime / delivery 双表
  - `required_test_names` 只保留角色私有 runtime / validator 坏例锚点
  - `sample_setup_method` 已从活跃文档清理
  - `damage_segments` 非空时顶层 `power = 0`
- `README.md` 的 GDScript 统计已同步到当前仓库实数。

### 当前验证结果

- 已通过：
  - `godot --headless --path . --script tests/run_all.gd`
  - `bash tests/run_with_gate.sh`

## 扩角前整合修复计划（第二阶段收口，2026-04-06）

- 状态：已完成
- 目标：
  - 把继续扩第 5 个正式角色前最容易复制扩散的 formal contract、pair coverage、segmented skill 语义与文档 gate 收口到单一真相。
- 范围：
  - `character_id / unit_definition_id` 分工与 mismatch 回归
  - `config/formal_matchup_catalog.json` 的 formal matchup / pair surface / pair interaction 单一真相
  - 四正式角色 pair surface 全方向矩阵与 6 组 deep interaction 回归
  - `damage_segments` 为真相时顶层 `power = 0` 的内容 / runtime / validator / 文档一致性
  - formal registry 文档锚点化、shared pair 锚点减重、README/tests README 对齐
  - `SampleBattleFactory` / `BattleCoreManager` / `BattleResultService` 热点压线
- 验收标准：
  - `character_id != unit_definition_id` 时，formal setup、pair matrix 与公开快照仍然正确。
  - pair surface 覆盖完整有向矩阵，pair interaction 覆盖 6 个无向正式角色对。
  - segmented skill 不再消费顶层 `power` 作为伤害真相。
  - `tests/run_with_gate.sh` 全绿，且三个热点文件全部退出 `220+` 预警带。

### 执行结果

- `formal_registry_suite.gd` 已新增 mismatch fixture 回归，锁住 `character_id / unit_definition_id` 分离后 formal setup、公开快照和 pair matrix 仍读对口径。
- `config/formal_matchup_catalog.json` 继续作为 formal matchup、pair surface case 与 pair interaction case 的单一真相；`SampleBattleFactoryMatchupCatalog` 当前也会在 runtime fail-fast 校验 catalog 形状。
- `tests/suites/formal_character_pair_smoke/interaction_suite.gd` 已实际注册并通过：
  - 6 个无向正式角色 pair 的 deep interaction case
  - shared matrix / catalog completeness contract
- `config/formal_character_delivery_registry.json` 已去掉逐角色手抄的 shared pair smoke 测试名；`required_test_names` 现在只保留角色私有 runtime / validator 锚点。
- design / adjustment 文档已补显式 anchor id；formal gate 现改为校验 anchor，不再依赖自然语言句子。
- segmented skill 语义已继续锁死：
  - `content/skills/obito/obito_shiwei_weishouyu.tres` 顶层 `power = 0`
  - runtime 仍按 `damage_segments` 结算真实伤害
  - formal validator / snapshot / runtime 回归同步收口
- 热点文件当前行数：
  - `src/composition/sample_battle_factory.gd`：`205`
  - `src/battle_core/facades/battle_core_manager.gd`：`219`
  - `src/battle_core/turn/battle_result_service.gd`：`219`

### 当前验证结果

- 已通过：
  - `python3 tests/gates/repo_consistency_surface_gate.py`
  - `python3 tests/gates/repo_consistency_formal_character_gate.py`
  - `python3 tests/gates/repo_consistency_docs_gate.py`
  - `bash tests/check_repo_consistency.sh`
  - `godot --headless --path . --script tests/run_all.gd`
  - `bash tests/run_with_gate.sh`

## 整合规范波落地：Wave 1 + Wave 2 收口（2026-04-06）

- 状态：已完成
- 目标：
  - 按“先收口边界与共享语义，再恢复扩角”的方案，把 manager 初始化边界、公开快照 contract、effect dedupe 扩展位、共享测试支撑和 lifecycle 热点一起压回可继续扩复杂角色的状态。
- 范围：
  - `BattleCoreManager.create_session()` 初始化后 runtime guard
  - `public_snapshot / header_snapshot` 的 field creator 公开 contract
  - `EffectEvent.dedupe_discriminator` 与 `PayloadExecutor` dedupe key
  - `SampleBattleFactory` 结果式 setup surface、FormalCharacter shared support、四角色 snapshot suite
  - `tests/suites/lifecycle_replacement_flow_suite.gd` wrapper + 子 suite 拆分
  - 对应 design / rules / gate / records
- 验收标准：
  - 初始化完成但 runtime 非法时，manager 失败且不返回首帧公开快照。
  - field creator 解析失败时，公开快照与 header snapshot 只返回 `public_id | null`。
  - dedupe 默认行为不变；显式设置 `dedupe_discriminator` 才允许同链合法重复。
  - 四角色 snapshot / manager / runtime 结果不变，lifecycle wrapper 与 suite reachability 继续全绿。
  - `bash tests/run_with_gate.sh` 全绿。

### 执行结果

- `BattleCoreManager.create_session()` 已在收下 session 前补 runtime guard；非法运行态会先 `dispose()` session，再返回失败 envelope。
- `BattleHeaderSnapshotBuilder` 已删掉 field creator 的原始 id 回退；`creator_public_id` 现在只会是公开 `public_id` 或 `null`。
- `EffectEvent` 已新增 `dedupe_discriminator`，`PayloadExecutor` dedupe key 已把它纳入稳定语义键；默认空串不改变现有四角色行为。
- 已补新增回归：
  - `manager_create_session_runtime_guard_contract`
  - `field_creator_public_id_contract`
  - `dedupe_discriminator_explicit_repeat_contract`
- `FormalCharacterTestSupport` 已补结果式 setup helper，并作为通用 setup / command builder 基类；Sukuna / Kashimo / Obito / Gojo support 只保留角色专属 helper。
- 四个 snapshot suite 已去掉本地 `_build_content_index()` / `_run_checks()` 壳层，统一直接走 `FormalCharacterSnapshotTestHelper`。
- `tests/suites/lifecycle_replacement_flow_suite.gd` 已改成稳定 wrapper，具体断言拆到 `tests/suites/lifecycle_replacement_flow/` 子 suite，并保留原测试名。
- `docs/design/battle_runtime_model.md`、`docs/design/log_and_replay_contract.md`、`docs/rules/05_items_field_input_and_logging.md` 与 `tests/gates/repo_consistency_docs_gate.py` 已对齐新增 contract wording。

### 当前验证结果

- 已通过：
  - `bash tests/run_with_gate.sh`

## 整合规范波补完（2026-04-06）

- 状态：已完成
- 目标：
  - 按“平衡收口”补完 Wave 1 / Wave 2，把继续扩复杂角色前最容易放大的 runtime / public contract / shared support 风险先压住。
- 范围：
  - `BattleCoreManager.create_session()` 首帧公开快照前的 runtime guard
  - field creator 公开字段与 header snapshot 收口
  - effect dedupe 扩展位 `dedupe_discriminator`
  - `SampleBattleFactory` 结果式 setup surface、formal shared support、四角色 snapshot suite、lifecycle replacement flow suite
- 验收标准：
  - 初始化后 runtime 非法时，`create_session()` 失败且不返回公开快照。
  - `creator_public_id` 只允许 `public_id | null`。
  - `dedupe_discriminator` 默认不改现有行为，显式设置后可区分合法重复。
  - lifecycle wrapper 保留原测试名，suite reachability 不断链。
  - 现有四角色正式回归面继续通过。

### 执行结果

- `BattleCoreManager.create_session()` 已改成：
  - 初始化后再次做 runtime guard
  - 非法 session 直接返回失败 envelope，并在返回前 dispose
  - manager 不再先拿 container service 预构好的首帧公开快照直接外发
- `BattleCoreManagerContainerService.create_session_result()` 已改成：
  - 在内部也先做一次 runtime guard
  - 成功路径只返回 session 与最小成功 envelope，把首帧公开快照的正式投影收回 manager
- `public_snapshot.field.creator_public_id` / `header_snapshot.initial_field.creator_public_id` 的防御性路径已统一写 `null`，不再回退 runtime/source id。
- `EffectEvent` / `PayloadExecutor` 已补 `dedupe_discriminator` 扩展位，并新增显式 repeat 回归。
- `SampleBattleFactory` 已补：
  - `build_setup_from_side_specs_result()`
  - `build_matchup_setup_result()`
- Formal shared support 已继续收口：
  - `FormalCharacterTestSupport` 现在统一提供结果式 setup helper
  - Gojo / Sukuna / Kashimo / Obito support 已改成继承共享 support，只保留角色专属 helper
- 四个 snapshot suite 已去掉本地 `_build_content_index()` / `_run_checks()` 模板壳，统一直接复用共享 snapshot helper。
- `tests/suites/lifecycle_replacement_flow_suite.gd` 已拆成 wrapper + `tests/suites/lifecycle_replacement_flow/` 子 suite，原四个测试名保持不变。
- `sample_battle_factory.gd` 当前为 `243` 行：
  - 仍低于 `>250` 的硬门禁
  - 但已经进入 `220+` 的架构预警带，下一波若再扩增长度必须继续拆 helper，不能再让它回到热点大文件

### 当前验证结果

- 已通过：
  - `godot --headless --path . --script tests/run_all.gd`
  - `bash tests/check_suite_reachability.sh`
  - `bash tests/check_architecture_constraints.sh`
  - `bash tests/check_repo_consistency.sh`
  - `bash tests/run_with_gate.sh`
  - `python3 tests/gates/repo_consistency_docs_gate.py`
  - `python3 tests/gates/repo_consistency_formal_character_gate.py`
  - `git diff --check`
  - `bash tests/check_repo_consistency.sh`
  - `bash tests/check_architecture_constraints.sh`
  - `bash tests/run_with_gate.sh`

## 当前补充修复：扩角前收尾批次（2026-04-06）

- 状态：进行中
- 目标：
  - 把扩角前审查里剩余的共享契约、formal 交付面与 docs 口径问题分批收口；每批都独立回归、提交、推送，最后恢复干净工作区。
- 范围：
  - 第一批：`on_receive_action_hit / on_receive_action_damage_segment` 的同侧误触发防线，以及 `battle_end` 执行链继承回归。
  - 第二批：默认 demo / setup 敏感测试统一接 setup-scoped snapshot 入口。
  - 第三批：formal registry 单一真相收口，补强 Obito formal bad cases。
  - 第四批：大文件约束文档与 gate 当前零 allowlist 策略对齐。
- 验收标准：
  - 每批完成后至少通过该批相关回归。
  - 最终通过 `bash tests/run_with_gate.sh`。
  - 完成后工作区恢复干净。

### 当前执行结果

- 第一批已完成：
  - 共享 precondition 已统一拦截 `on_receive_action_hit / on_receive_action_damage_segment` 的同侧 action 误触发。
  - damage segment 派发入口已补“仅敌方 `skill / ultimate` 且目标是敌方 active”保护，避免 runtime 派发链自己放水。
  - `battle_end` 在执行阶段结束时，若根链仍是 action chain，则继承该 action chain，不再错误退回 system chain。
  - 已补回归：
    - `on_receive_action_hit_same_side_skill_ignored_contract`
    - `obito_yinyang_dun_same_side_segment_ignored_contract`
    - `battle_end_system_chain` 中 execution battle_end 继承 action chain 的断言
- 第二批已完成：
  - `BattleSandboxRunner` 默认 Kashimo demo 已改成先构建 `battle_setup`，再走 `content_snapshot_paths_for_setup_result(battle_setup)`，不再回退到全量 snapshot。
  - `BattleCoreTestHarness` 已新增 setup-scoped snapshot / content index helper，后续 formal 与 setup-sensitive 用例可以统一接入，不必各自重复造轮子。
  - `content_snapshot_cache_composer_stats_contract` 已切到 harness 的 setup-scoped helper，保证这条测试入口不是死代码。
  - formal/setup 敏感 support 已开始接入新 helper，当前已覆盖 `formal_character_snapshot_test_helper`、Gojo、Kashimo、Sukuna 的相关测试支撑。
- 第三批已完成：
  - `SampleBattleFactory.formal_character_ids_result()` 与 `build_formal_character_setup_result()` 已改成直接读取 `config/formal_character_runtime_registry.json`，不再保留第二份正式角色 ID / setup 映射常量。
  - registry 已新增 `formal_setup_matchup_id`，把“样例 builder 名称”和“默认 formal setup 实际走哪一组 matchup”拆成两个显式字段；Sukuna 因此不再需要额外特判，也能继续保持 `sukuna_setup` 的正式构局语义。
  - Obito formal bad cases 已补强 effect surface：
    - `formal_obito_validator_heal_block_surface_bad_case_contract`
    - `formal_obito_validator_yinyang_guard_surface_bad_case_contract`
    - `formal_obito_validator_yinyang_listener_surface_bad_case_contract`
  - Obito registry 测试锚点已补齐新增 validator bad cases，以及 runtime 的 `obito_yinyang_dun_same_side_segment_ignored_contract`。
  - formal docs / gate / runtime suite 也已补齐 `formal_setup_matchup_id` 的一致性约束，避免 registry 口径只写不验。
- 第四批已完成：
  - `docs/design/battle_core_architecture_constraints.md` 已改成和当前 gate 一致的“零 allowlist”口径：核心文件 > `250` 行直接拆分，不再文档上保留临时白名单承诺。
  - `README.md` 的 `src/**/*.gd`、`tests/**/*.gd` 与总 GDScript 行数统计已同步到最新，`check_repo_consistency.sh` 不再被陈旧计数拦住。

### 当前验证结果

- 第一批已通过：
  - `git diff --check`
  - `godot --headless --path . --script tests/run_all.gd`
- 第二批已通过：
  - `git diff --check`
  - `godot --headless --path . --script tests/run_all.gd`
  - `godot --headless --path . --quit-after 20`
  - formal/setup 敏感 support 接入后再次通过 `godot --headless --path . --script tests/run_all.gd`
- 第三批已通过：
  - `git diff --check`
  - `godot --headless --path . --script tests/run_all.gd`
  - `bash tests/check_suite_reachability.sh`
- 第四批已通过：
  - `git diff --check`
  - `bash tests/check_architecture_constraints.sh`
  - `bash tests/check_repo_consistency.sh`
  - `bash tests/run_with_gate.sh`

## 下一角色扩充准备

- 新角色进入正式交付链前，必须先完成：
  - 设计稿与调整记录
  - `formal_character_runtime_registry.json / formal_character_delivery_registry.json` 条目
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

## 当前补充修复：共享失败语义与 SampleBattleFactory 收口（2026-04-06）

- 状态：已完成
- 目标：
  - 把扩角前审查里已经确认的问题真正落地修掉：回放稳定哈希漏项、`on_receive_*` 共享契约的 fail-fast 边界、`SampleBattleFactory` 的结果式失败语义，以及大文件 gate / README 统计漂移。
- 范围：
  - `src/battle_core/runtime/unit_state.gd`
  - `src/battle_core/effects/effect_precondition_service.gd`
  - `src/battle_core/passives/passive_skill_service.gd`
  - `src/battle_core/passives/passive_item_service.gd`
  - `src/composition/sample_battle_factory*.gd`
  - 对应回归 suite、`README.md`、`docs/records/tasks.md`、`docs/records/decisions.md`
- 验收标准：
  - 新增契约回归通过。
  - `SampleBattleFactory` 的正式失败路径返回 `{ ok, data, error_code, error_message }`，旧薄封装继续按 `null / [] / PackedStringArray()` 退化。
  - `sample_battle_factory.gd` 继续保持在架构 gate 的 250 行硬阈值内。
  - `bash tests/run_with_gate.sh` 全绿。

### 执行结果

- `UnitState.to_stable_dict()` 已把 `used_once_per_battle_skill_ids` 纳入稳定序列化，并在写入前排序；`final_state_hash` 不再漏掉 battle-scoped 一次性技能使用记录。
- `EffectPreconditionService` 已收紧 `on_receive_action_hit / on_receive_action_damage_segment`：
  - 缺 `battle_state / chain_context / owner_id / action_actor_id / side` 时直接报 `invalid_state_corruption`
  - `required_incoming_command_types` 缺 command 上下文时 fail-fast
  - `required_incoming_combat_type_ids` 只在 `action_combat_type_id == null` 时 fail-fast；空字符串继续按“合法但不匹配”处理，避免把无属性技能误判成状态损坏
- `PassiveSkillService / PassiveItemService` 已改成 fail-fast：
  - owner unit 缺失 => `invalid_state_corruption`
  - unit/passive 定义缺失 => `invalid_content_snapshot`
- `SampleBattleFactoryContentPathsHelper` 已把递归扫目录的裸 `assert()` 改成结果式错误；缺目录时 `collect_tres_paths_recursive_result()` 返回结构化失败，旧 wrapper 继续降级成空数组。
- `SampleBattleFactoryMatchupCatalog` 与 `SampleBattleFactory` 已补结果式 API：
  - `build_setup_by_matchup_id_result()`
  - `formal_character_ids_result()`
  - `build_formal_character_setup_result()`
  - `collect_tres_paths_recursive_result()`
- `SampleBattleFactory` 已继续拆分：
  - 新增 `sample_battle_factory_registry_helper.gd`
  - `sample_battle_factory.gd` 当前为 243 行，继续保持零 allowlist 口径，但已重新进入 220 行预警带
- `README.md` 的源码 / 测试 GDScript 行数统计已同步到当前仓库实数。

### 当前验证结果

- 已通过：
  - `godot --headless --path . --script tests/run_all.gd`
  - `bash tests/check_architecture_constraints.sh`
  - `bash tests/check_repo_consistency.sh`
  - `bash tests/run_with_gate.sh`

## 扩角前整合规范波（2026-04-06）

- 状态：已完成
- 目标：
  - 在继续扩第 5 个角色前，把最容易放大的 runtime / formal contract / 文档对齐问题先一次性收口。
- 范围：
  - 生命周期主链：`manual_switch / forced_replace / faint replace`
  - formal registry 与 `SampleBattleFactory` runtime contract
  - Gojo / Sukuna / Kashimo / Obito 四角色专项回归与 validator 锁点
  - `SampleBattleFactory`、`manager_log_and_runtime_contract_suite.gd`、`rule_mod_runtime_core_paths_suite.gd` 热点降温
  - `README.md`、`tests/README.md`、design docs、`decisions.md`
- 验收标准：
  - `manual_switch / forced_replace / faint replace` 顺序与入场状态一致。
  - formal setup 只认 `character_id + formal_setup_matchup_id`，活跃 runtime / delivery registry 不再保留 `sample_setup_method`。
  - 四角色新补的专项锚点全部进入 delivery registry。
  - `sample_battle_factory.gd` 继续保持在架构硬门禁以下，wrapper suite 继续保持原文件名与测试名。
  - `bash tests/run_with_gate.sh` 全绿。

### 执行结果

- `SwitchActionService` 已只保留换人指令校验与换人日志入口，真正生命周期统一委托给 `ReplacementService.execute_replacement_lifecycle()`。
- `manual_switch / forced_replace / faint replace` 当前统一口径为：
  - `on_switch -> on_exit -> leave -> field_break(若 creator 离场) -> replace -> on_enter`
  - replacement 入场后统一写 `reentered_turn_index = battle_state.turn_index`
  - replacement 入场后统一重置 `has_acted=false / action_window_passed=false`
- `FaintResolver` 已显式注入 `field_service`，不再通过 `trigger_batch_runner.field_service` 读取隐藏依赖。
- `BattleCoreSession` 已改成 manager 内部实现细节：
  - 去掉全局 `class_name`
  - runtime 通过 `configure_runtime()` 注入
  - manager/helper 不再直接读公开字段 `container / battle_state / content_index`
- `SampleBattleFactory.build_formal_character_setup_result()` 已统一按 `character_id` 查 runtime registry；formal runtime 只认 `formal_setup_matchup_id`。
- 活跃 runtime / delivery registry 已删除 `sample_setup_method`。
- 四角色新增并挂回 registry 的专项锚点：
  - Gojo：`formal_gojo_validator_action_lock_stacking_bad_case_contract`
  - Sukuna：`sukuna_teach_love_replace_on_matchup_change_contract`
  - Kashimo：`formal_kashimo_validator_water_leak_counter_fixed_damage_bad_case_contract`
  - Obito：`obito_qiudaoyu_execute_short_circuit_contract`、`obito_shiwei_weishouyu_mid_kill_stop_contract`
- 热点文件已降温：
  - `manager_log_and_runtime_contract_suite.gd` 拆成 wrapper + `manager_log_and_runtime_contract/`
  - `rule_mod_runtime_core_paths_suite.gd` 拆成 wrapper + `rule_mod_runtime_core_paths/`
  - `sample_battle_factory.gd` 曾压到 `207` 行；本轮补结果式 setup surface 后回到 `243` 行，仍低于 250 行硬门禁

### 当前验证结果

- 已通过：
  - `godot --headless --path . --script tests/run_all.gd`
