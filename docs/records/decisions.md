# 决策记录（精简版）

本文件只保留当前阶段仍会直接约束实现、测试或扩角流程的关键决策。

历史完整记录已归档到：

- `docs/records/archive/decisions_pre_v0.6.3.md`
- `docs/records/archive/decisions_pre_v0.6.4.md`

当前生效规则以 `docs/rules/` 为准；本文件只记录“为什么这样定”。

## 当前有效决策

### 1. 规则、设计、记录的职责分层固定

- `docs/rules/` 是当前生效规则权威。
- `docs/design/` 负责实现落点、架构与角色/机制设计。
- `docs/records/` 只保留决策背景、任务摘要与追溯入口，不再承载会被误当成“当前真相”的大正文。

### 2. 扩角前先做规范整合，不先做新角色与平衡修正

- 当前主线先解决工程/文档/门禁/诊断漂移。
- 宿傩对 Gojo 的领域兑现率问题保留到下一轮平衡任务。
- 本轮默认不动 Gojo / Sukuna 数值，不把 `domain_successes = 0` 当成规范整合阶段的实现目标。

### 3. 预期 invalid termination 不再伪装成引擎级错误

- `invalid_battle / hard_terminate_invalid_state` 仍要保留可检索诊断输出。
- 但这类预期负路径不再走引擎级 `push_error()`，避免闸门全绿时控制台仍充满误导性 `ERROR:`
- `tests/run_with_gate.sh` 继续只拦截真正的脚本/编译/解析/加载错误。

### 4. `BattleFormatConfig` 的正式目录固定为 `content/battle_formats/`

- `content/samples/` 只承载样例资源与样例对局资源，不再承载正式 battle format。
- 默认快照扫描目录必须与目录规范一致；新增 battle format 时不允许靠样例目录兜底。

### 5. 默认快照扫描目录固定显式列出

- `SampleBattleFactory.content_snapshot_paths()` 默认收集：
  - `battle_formats`
  - `combat_types`
  - `units`
  - `skills`
  - `passive_skills`
  - `passive_items`
  - `effects`
  - `fields`
  - `samples`
- 继续保持稳定排序，避免内容接线漏资源与 replay 漂移。

### 6. 领域公共规则必须有单独模板入口

- Gojo / Sukuna 共享的领域规则，不再只分散写在角色设计稿里。
- 当前正式要求：领域角色扩展前，先阅读并对齐领域模板文档，再写角色差异项。
- 角色设计稿只保留自身差异，不再重复定义整套公共领域冲突矩阵。

### 7. 领域公共规则继续沿用当前主线 contract

- `domain vs domain` 比较双方扣费后的当前 MP。
- 成功后附带链统一走 `field_apply_success`。
- 领域增幅必须是 field 绑定收益，跟随 `field_apply / field_break / field_expire` 生命周期。
- 同回合双方已入队的领域动作不得被 action lock 回溯取消。
- 己方领域在场时，己方不得重开己方领域；该限制不影响对手领域，也不影响普通 field。

### 8. 固定案例诊断口径（已被第 15 条进一步收口）

- 当前主线只保留 `tests/replay_cases/` 固定可复查案例作为角色与规则复查入口。
- 历史上的批量模拟拆分方案已随第 15 条一起退出主线，不再作为现行要求。
- 固定案例至少覆盖领域成功、领域失败、平 MP tie-break、普通 field 阻断、同回合双开域。

### 9. 正式角色资产交付面继续保持不变

- 每个正式角色都必须同时具备：
  - 设计稿
  - 调整记录
  - 内容资源
  - `SampleBattleFactory` 接线
  - 独立角色 suite
- 后续新角色默认沿用这套交付面，不再接受“只有 `.tres` + 测试”的半成品接入。

### 9.1 正式角色模板、checklist 与最低测试面固定（2026-04-01）

- 正式角色设计稿统一使用 `docs/design/formal_character_design_template.md`。
- 正式角色接入动作统一使用 `docs/design/formal_character_delivery_checklist.md`。
- 默认施工顺序固定为：
  - 先写设计稿 / 调整记录
  - 再落内容资源
  - 再补 `SampleBattleFactory`、formal registry 与 suite
- 正式角色最低测试面固定包含：
  - `snapshot suite`
  - 角色独有 `runtime suite`
  - `manager smoke suite`
- 若角色是领域角色，只在角色稿末尾追加“领域角色差异附录”；公共领域规则继续引用 `docs/design/domain_field_template.md`，不再在角色稿内重复展开。
- 若只是复用现有机制接入新角色，不新增 `decisions.md`；只有引入新 trigger / payload / schema / 生命周期口径时，才补新决策记录。

### 10. 对外 contract 继续收口到公开层接口

- 外层输入与公开快照继续只使用 `public_id`。
- `BattleCoreManager` 仍是外围稳定入口。
- 调试读取若需要更多信息，只允许走显式的只读快照/日志接口，不再直穿内部 session/runtime。

### 11. `battle_core / composition` 的源码大文件 allowlist 已清空（2026-03-30）

- 当前 `src/battle_core` 与 `src/composition` 已无 `>250` 行源码文件。
- 架构闸门不再保留历史临时 `max_lines` allowlist；若旧 allowlist 条目继续留在门禁脚本里，也视为漂移。
- 后续若再次出现 `>250` 行源码文件，必须重新做职责复核、补决策记录，再显式登记新的临时上限。

### 12. 领域合法性与公开快照口径统一（2026-03-30）

- 新增 `domain_legality_service` 作为领域重开判定的单一真相：
  - 选指阶段（`LegalActionService`）与执行阶段（`ActionDomainGuard`）统一复用同一判定。
- `public_snapshot.field` 扩展 `field_kind / creator_side_id`：
  - 供外层输入、公开快照与规则复查统一读取当前 field 类型与归属侧。
- 领域重开、field 归属与公开快照的读取口径，当前统一依赖上述公共 contract。
- 若未来恢复自动选指，必须重新补齐规则、设计文档与接线任务，不得直接回填历史实现。

### 13. Active Field 的 creator 视为运行态硬约束（2026-03-30）

- 只要 `battle_state.field_state != null`，就必须满足：
  - `field_state.creator` 非空
  - `field_state.creator` 能解析到当前运行态中的单位
- 原因：
  - 领域对拼与 field 生命周期日志都依赖 creator 归因；继续用缺失 creator 的脏状态往下跑，只会把坏状态伪装成正常对拼结果。
- 当前处理：
  - `RuntimeGuardService` 在每回合入口统一拦截这类坏状态，直接返回 `invalid_state_corruption`
  - `FieldApplyConflictService` 额外保留本地防御，不再把缺失 creator 降级成 `-1 MP` 继续参与领域对拼

### 14. 扩角前规范整合口径正式收紧（2026-03-30）

- manager 对外事件日志改为白名单公开快照：
  - 保留公开归因字段 `actor_public_id / actor_definition_id / target_public_id / target_definition_id / killer_public_id / killer_definition_id`
  - 移除 `actor_id / source_instance_id / target_instance_id / killer_id / value_changes[].entity_id`
- `create_session()` 的对外 contract 正式定义为“已预回首回合 MP 后的初始公开快照”，且初始 `event_log` 不补这条预回蓝。
- 初始化阶段的 `invalid_battle` 与 startup victory 统一归 `BattleResultService` 落盘，`BattleInitializer` 只保留编排 owner。
- `ActionCastService` 与 `FaintResolver` 已完成一轮职责预拆；后续扩角优先继续沿子域 helper 扩展，不再把复杂度继续堆回主类。

### 15. 主线移除自动选指与批量模拟层（2026-03-30）

- 当前主线不再保留自动选指适配器、旧策略表、角色 mode handler、批量模拟案例与对应回归。
- 原因：
  - 现阶段优先收口核心战斗 contract、角色资源与扩角前治理，不再维护实验性自动选指层。
  - 继续保留自动选指模拟层会把角色行为问题与核心规则问题混在一起，增加扩角前整合成本。
- 当前处理：
  - 正式角色交付面回退为 `设计稿 / 调整记录 / 内容资源 / SampleBattleFactory 接线 / 角色 suite / 必要固定案例`。
  - 若未来恢复自动选指，必须先补规则与设计文档，再单开接线任务，不得直接回填历史实现。

### 16. Effect 链递归防抖改用稳定语义键（2026-03-30）

- 同一条 `event_chain` 内，effect dedupe key 统一使用：
  - `source_instance_id / effect_instance_id / trigger_name / effect_definition_id / owner_id / target_unit_id`
- 不再把 `event_id` 作为去重键的一部分。
- 原因：
  - `TriggerDispatcher` / `EffectInstanceDispatcher` 每次重新收集 effect event 都会生成新的 `event_id`，继续依赖它只能拦住“同一个事件对象重复执行”，挡不住递归重新派发出来的新事件。
  - 同时补入 `effect_instance_id`，避免“同源、同触发、同目标、但属于不同叠层实例”的 effect 在合法路径里被误判成重复。
  - 保留 `target_unit_id` 维度，避免把 battle_init 换位后重新形成的新稳定对位错误拦成递归。

### 17. 正式角色接入与内容快照门禁改用统一注册表（2026-03-30）

- 新增 `docs/records/formal_character_registry.json` 作为正式角色交付面的单一真相：
  - 至少登记 `unit_definition_id / design_doc / adjustment_doc / suite_path / required_content_paths`
- `tests/run_all.gd` 不再手写正式角色 wrapper 列表，统一按注册表动态装配。
- `tests/check_repo_consistency.sh` 不再点名 Gojo / 宿傩的交付面路径，统一按注册表校验正式角色文档、suite、内容资源与 `SampleBattleFactory` 接线。
- `SampleBattleFactory.content_snapshot_paths()` 改为递归收集 `.tres`：
  - 避免后续把角色资源拆进子目录后，内容快照与回放输入静默漏资源。

### 18. Effect 去重必须区分具体 effect instance（2026-03-30）

- effect dedupe key 必须包含 effect_instance_id。
- `PayloadExecutor` 的 effect dedupe key 不能只靠来源与目标语义。
- 同来源、同目标、同触发名下，来自不同 `effect_instance_id` 的合法堆叠实例必须分别结算；否则会把“同链递归防抖”和“多层独立实例”错误混成一件事。
- 当前 contract 固定为：继续拦递归重派发，但 distinct stacked instances 不能互相吞掉。

### 19. `field_break / field_expire` 链上创建的 successor field 必须保留（2026-03-30）

- field_break / field_expire 链上创建的 successor field 必须保留。
- 若旧 field 的 `on_break_effect_ids` 或 `on_expire_effect_ids` 在自身生命周期链里成功创建了 successor field，旧 field 清理阶段不得把 successor 一并删掉。
- 原因：
  - 这类链路本质上是“旧 field 结束时交接到新 field”，不是“旧 field 清理自己时把场地彻底清空”。
  - 若继续复用旧清理逻辑，会把新 field、其 rule_mod 与公开快照一起误判成旧状态垃圾。

### 20. 正式角色注册表升级为“资产 + suite 子树 + 回归锚点”单一真相（2026-03-30）

- 正式角色注册表当前必须登记角色 effect 资源、wrapper 下属 suite 与关键回归测试名。
- `docs/records/formal_character_registry.json` 当前除了角色文档、wrapper suite 与内容资源外，还必须登记：
  - `required_suite_paths`
  - `required_test_names`
- 原因：
  - 正式角色的真实交付面不只是“有个 wrapper”；还包括 wrapper 下的 suite 子树和必须长期保留的关键回归断言。
  - 复杂角色扩角前，effect 资源也必须进入注册表，不再只登记 unit / skill / passive / field。

### 21. 总闸门追加 suite 可达性与 `battle_core` 内部分层静态约束（2026-03-30）

- `tests/run_with_gate.sh` 现在除断言、引擎错误、仓库一致性外，还必须跑 `check_suite_reachability.sh`。
- suite 可达性闸门只认 `run_all.gd` 与正式角色 wrapper 为根；子 suite 必须能沿 `preload(...)` 子树真正走到，不能靠旁路登记假装被覆盖。
- `check_architecture_constraints.sh` 额外收紧：
  - `content / contracts / runtime` 保持 L1 纯度，不得反向 import 上层服务
  - `commands / math` 保持 L2 纯度，不得 import runtime / orchestrator / coordinator / facade
  - `battle_core` 内层模块不得反向 import `facades/*`

### 22. 同回合双开领域时，先手 success 链延后到对拼结论后兑现（2026-03-31）

- 同回合双方都已入队施放领域时：
  - 先手领域若仍处于对拼窗口内，`field_apply_success` 链必须延后到对拼结果明确后再兑现
  - 若先手方最终被后手领域翻盘，则视为“未成功立住”，不得残留 `action_lock` 之类只应在成功立场后成立的附带效果
- 原因：
  - 旧时序会让先手领域先兑现 success 附带效果，再在后手领域翻盘时留下本不该成立的运行态残留。

### 23. 宿傩动态回蓝正式收口为“基础值 + 对位追加”（2026-03-31）

- 宿傩 `regen_per_turn = 12` 保持为基础面板值，不再允许被同一被动语义写成“更接近对位反而回得更少”。
- `sukuna_refresh_love_regen` 当前正式口径固定为：
  - `mp_regen add`
  - 动态表 `9 / 8 / 7 / 6 / 5 / 0`
  - 最终回蓝值按 `基础 12 + 对位追加` 读取
- 原因：
  - 旧的 `mp_regen set` 语义与宿傩面板基础回蓝 `12` 自相矛盾，会把接近对位下的被动补强写成实际削弱。

### 24. 内容快照 shape validator 继续保持“入口编排 + 子域校验”结构（2026-03-31）

- `ContentSnapshotShapeValidator.validate()` 只保留 shape 校验主流水线，不再回退成一个超长函数承载全部 unit / skill / passive / field / effect 规则。
- unit 相关 shape 校验当前下沉到独立 helper；后续若继续增长，应继续按内容子域拆，而不是把逻辑重新堆回入口。
- 原因：
  - 内容快照校验会随着扩角和 payload / field 变种增加持续膨胀；若继续集中在单函数内，后续每个角色接入都会把治理成本抬高。

### 25. `on_matchup_changed` 的签名比较与触发 owner 统一收口到 field lifecycle（2026-03-31）

- 初始化阶段与回合内阶段统一复用 `TurnFieldLifecycleService.execute_matchup_changed_if_needed()`。
- `BattleInitializer` 只保留初始化编排 owner，不再维护本地重复的 matchup signature 比较与 trigger 调度实现。
- 原因：
  - `on_matchup_changed` 已属于稳定对位变化的公共生命周期，不应该分别散落在初始化和回合推进两条链上各写一份。

### 26. Turn limit 计分与 battle result 落盘职责分离（2026-03-31）

- `BattleResultService` 保留 battle end 落盘、invalid / surrender / victory 编排与日志。
- turn limit 的 side 计分、排序与平局比较当前统一下沉到 `TurnLimitScoringService`。
- 原因：
  - 后续若补特殊胜利条件或追加更多 turn limit 规则，不应继续把评分细节堆进 battle result 主类。

### 27. 正式角色契约收口统一为“唯一 facade + 全量快照 + 共享回归回挂”（2026-03-31）

- `BattleCoreManager` 是外围唯一稳定 facade。
- `BattleCoreSession` 只作为 manager 内部会话壳，不属于外围稳定入口。
- facade 若需要装配容器，只能依赖 build-container callable / factory port，不再直接持有完整 composition root。
- 正式角色注册表除 wrapper `suite_path` 外，必须继续显式登记：
  - `required_suite_paths`
  - `required_test_names`
- 共享 suite 只要属于角色正式验收项，也必须回挂到角色注册表；当前 Gojo / Sukuna 都要显式挂住 `ultimate_field_suite.gd` 的共享领域回归。
- 正式角色必须各自拥有全量 snapshot suite，用字面量断言锁死单位面板、技能资源与关键 effect / field / passive 资源，不再只靠“从当前资源反推期望值”的测试。
- Gojo `苍 / 赫` 当前正式口径固定为速度能力阶段 `+1 / -1`，范围 `-2..+2`，离场清空，不改成 3 回合 buff / debuff。
- 宿傩对外类型文案统一写“恶魔”；内部资源 `combat_type_id = demon` 不改。

### 28. 扩角前运行时 helper 全部统一进 composition 装配（2026-03-31）

- 当前统一装配边界收口到“战斗运行时 helper”：
  - 行动链 helper
  - 数值 payload helper
  - 击倒/补位 helper
  - field apply helper
- 这些 helper 不再允许由 owner service 内部 `new()`，也不再允许 `_sync_*dependencies()` 这种手工灌依赖链继续存在。
- 原因：
  - 扩角后每新增一个运行时依赖，若还保留“composition wiring + owner 手工同步”双维护路径，极容易出现 helper 漏接线且只在运行到半截时才炸。
- 当前处理：
  - helper 统一注册进 `BattleCoreServiceSpecs` / `BattleCoreWiringSpecs`
  - `BattleCoreContainer` 显式持有 helper slot
  - `RuntimeGuardService` 递归检查这些 helper 的缺线问题

### 29. `BattleCoreManager` 公开 contract 统一为严格 envelope（2026-03-31）

- 当前所有公开方法统一返回：
  - `{"ok": bool, "data": ..., "error_code": String|null, "error_message": String|null}`
- 公开成功结果只允许把原 payload 放在 `data` 里；失败时必须 `data = null`。
- 原因：
  - 旧 contract 有的直接回对象，有的靠断言崩，外围调用方很难稳定判断“是业务失败、会话不存在，还是装配断了”。
- 当前处理：
  - `BattleCoreComposer` 装配失败不再靠断言暴露
  - `BattleCoreManager` 对 compose / session / replay / build_command 等失败路径全部统一转成结构化错误
  - manager contract suite 现在把 envelope 形状视为正式回归的一部分

### 30. 宿傩“灶”正式写死为 3 层硬上限，满层后忽略新层（2026-03-31）

- `sukuna_kamado_mark` 当前正式配置：
  - `stacking = stack`
  - `max_stacks = 3`
- 当目标已满 3 层灶时，再次命中 `开`：
  - 不新增第 4 层
  - 不刷新现有层数的剩余回合
  - 不顶掉旧层
  - 不额外写特殊日志
- 原因：
  - 当前回蓝与领域续航虽然通常不会把灶堆到失控，但扩角后只要出现多动、多段或复制触发，没有显式上限就会把数值边界重新炸开。

### 31. Effects/Lifecycle 受控运行时环只允许保留在 composition 属性注入层（2026-03-31）

- 当前已知受控闭环之一：
  - `trigger_batch_runner -> payload_executor -> payload_numeric_handler -> faint_resolver -> replacement_service -> trigger_batch_runner`
- 该闭环当前允许保留，前提是：
  - 只通过 composition root 统一属性注入接线
  - 运行时继续受 `invalid_battle` fail-fast 与 chain depth 守卫保护
- 明确禁止：
  - 把这条链直接改成构造器注入
  - 在 owner service 内局部 `new()` 出一段旁路 helper 来偷偷绕过 composition
- 原因：
  - 这条链是当前效果递归、击倒窗口与补位主链之间的稳定调用回路；贸然切装配方式比保留受控闭环更容易引入半初始化或递归死锁。

### 32. 正式角色若因 effect 触发差异必须双写共享伤害 payload，加载期必须做一致性校验（2026-03-31）

- 当前宿傩 `sukuna_kamado_mark`、`sukuna_kamado_explode`、`sukuna_domain_expire_burst` 都各自带一份 `20` 点火属性固定伤害 payload。
- 这三处独立定义暂时保留，因为它们分别挂在 `on_exit / on_expire / field_expire` 三条不同 effect 链上，直接抽成独立 content 资源会越过当前注册表支持范围。
- `ContentSnapshotShapeValidator` 现在继续通过 formal-character helper 在加载期强校验三处 `amount / use_formula / combat_type_id` 必须完全一致。
- 原因：
  - 不再只靠设计稿里的“手工同步点”提醒维护数值。
  - 保持现有 content schema 不扩新资源类型，同时让这类正式角色共享数值漂移能在加载时 fail-fast。

### 33. 正式角色 content 资源按角色子目录组织，继续复用递归 snapshot 收集（2026-03-31）

- 当前正式角色资源统一下沉到：
  - `content/units/{gojo,sukuna}/`
  - `content/skills/{gojo,sukuna}/`
  - `content/effects/{gojo,sukuna}/`
  - `content/passive_skills/{gojo,sukuna}/`
  - `content/fields/{gojo,sukuna}/`
- `SampleBattleFactory.content_snapshot_paths()` 继续保持“按大类目录递归收集 `.tres`”的策略，不为单个角色写特判路径。
- 原因：
  - 扩角后平铺目录会迅速退化成文件汤，查找和审查成本线性上升。
  - 现有 loader 已支持递归扫描，目录治理不需要改内容 schema 或运行时装配。

### 34. 正式角色命名继续沿用“术式罗马音 + 领域英文描述”的当前混合口径（2026-03-31）

- 当前 Gojo / Sukuna 的正式资源命名并不是“单角色全英文”：
  - 常规术式与术式衍生 effect 继续使用角色侧约定的罗马音命名，例如 `gojo_ao / gojo_aka / gojo_murasaki / sukuna_hiraku / sukuna_fukuma_mizushi`
  - 领域 skill / field 继续使用英文描述命名，例如 `gojo_unlimited_void / gojo_unlimited_void_field / sukuna_malevolent_shrine_field`
- 因此外部审查里“Gojo 全套用英文，所以宿傩命名风格不一致”这条判断不成立；当前不做只针对宿傩单角色的重命名。
- 若未来要统一成“全英文”或“全罗马音”，必须走一次仓库级命名规范任务，同时修改角色资源、文档、测试与注册表，不能单独改一个角色。

### 35. 生产路径里的 raw `assert()` 只允许保留给测试、抽象基类与程序员不变量（2026-03-31）

- 会直接受内容快照、战斗输入、运行态污染影响的生产路径，不再允许把 raw `assert()` 当成正式失败路径。
- 本轮已收口的路径：
  - `RuleModWriteService` 的 stacking key schema / stacking key field 异常改成 `INVALID_RULE_MOD_DEFINITION`
  - `BattleContentRegistry` 的 unsupported resource 改成显式内容加载失败，并由 `BattleContentIndex.load_snapshot()` 返回 `INVALID_CONTENT_SNAPSHOT`
- 当前明确允许保留 raw `assert()` 的位置：
  - `tests/support/formal_character_registry.gd`
  - `src/battle_core/lifecycle/replacement_selector.gd`
  - `src/battle_core/logging/log_event_builder.gd`
  - `src/battle_core/effects/effect_queue_service.gd`
  - `src/battle_core/turn/public_id_allocator.gd`
  - `src/battle_core/effects/payload_handlers/payload_damage_runtime_service.gd`
- 原因：
  - 上述点要么只服务测试装配，要么是必须 override 的抽象占位，要么属于纯程序员不变量；保留 raw `assert()` 比把它们包装成业务错误更清晰。

### 36. 核心源码 `220..250` 行进入非阻断预警，`>250` 仍维持硬门禁（2026-03-31）

- `tests/check_architecture_constraints.sh` 现在对 `src/battle_core` 与 `src/composition` 中落在 `220..250` 行的 `.gd` 输出 `ARCH_GATE_WARNING`，但不阻断闸门。
- `>250` 行源码与 `>600` 行测试的硬门禁不变。
- 原因：
  - 当前主线已经有若干文件长期贴近 `250` 行上限，只在超线后才治理会把拆分任务变成被动救火。
  - 提前预警能暴露热点，但不会把日常迭代变成机械拆文件。

### 37. `BattleCoreManager` 的公开读口与回合入口先做 runtime fail-fast（2026-03-31）

- `get_legal_actions / run_turn / get_public_snapshot / get_event_log_snapshot` 进入 session 后都必须先经过 `RuntimeGuardService` 校验。
- 若 active field 缺失 creator、field 定义漂移或其他运行态硬约束已经损坏，manager 只能返回结构化 `invalid_state_corruption`，不能继续构造 legal actions、公开快照或事件日志。
- 原因：
  - 旧口径虽然能在部分主链入口拦坏状态，但外围仍可能通过 facade 读到“半正常、半损坏”的公开结果，等于把内部污染继续泄漏给上层。

### 38. 正式角色共享内容校验由 formal registry 的可选 validator path 驱动（2026-03-31）

- `ContentSnapshotFormalCharacterValidator` 只负责编排；`content_snapshot_formal_character_registry.gd` 会从 `docs/records/formal_character_registry.json` 读取可选 `content_validator_script_path`，动态装配角色级 validator。
- `docs/records/formal_character_registry.json` 继续是正式角色交付面的单一真相；除设计稿、内容资源、suite 与关键回归锚点外，现在允许登记角色共享内容校验脚本路径。
- 原因：
  - 正式角色的共享内容约束本来就和交付面绑定；把 validator path 收回同一注册表后，文档、门禁与运行时加载可以共用一份 source of truth，同时仍由代码 loader 负责 fail-fast。

### 39. 宿傩正式回归拆成“灶生命周期”和“领域链路”两组 suite（2026-03-31）

- 原 `tests/suites/sukuna_kamado_domain_suite.gd` 现已拆分为：
  - `tests/suites/sukuna_kamado_suite.gd`
  - `tests/suites/sukuna_domain_suite.gd`
- `tests/suites/sukuna_suite.gd` 继续只做 wrapper；正式角色注册表里的 `required_suite_paths` 也同步改为两条子 suite。
- 原因：
  - 宿傩当前是最复杂的正式角色之一，灶层数生命周期与领域链路已经跨两个子域；继续堆在单一 suite 会拖慢定位回归与后续扩角复查。

### 40. 旧合法性口径从当前正式 contract 硬移除，只保留 `action_legality`（2026-04-01）

- 当前正式 `rule_mod` 合法性读取点只剩 `action_legality`；活动规则、设计文档、测试与运行时代码不再保留旧合法性双口径。
- `wait` 继续不受 `action_legality` 影响；技能 / 奥义 / 换人统一走单一匹配矩阵与统一排序链。
- 原因：
  - 旧双口径在代码已经硬切后，继续留在活动文档里只会制造“看起来还能用”的假象，直接抬高扩角时的误用风险。

### 41. `matchup_bst_gap_band` 正式冻结为包含 `max_mp` 的七维口径（2026-04-01）

- 当前 `dynamic_value_formula = matchup_bst_gap_band` 固定按双方 `max_hp + attack + defense + sp_attack + sp_defense + speed + max_mp` 的绝对差求值。
- `max_mp` 当前视为正式第七维；宿傩对位追加回蓝与相关角色回归都以此为准。
- 原因：
  - 这条公式已经进入正式角色资源与回归；若不把 `max_mp` 写成明文 contract，后续扩角时很容易有人按“六维 BST”误实现。

### 42. `BattleInitializer` 与 `BattleCoreManager` 继续通过内部 helper 留出治理余量（2026-04-01）

- `BattleInitializer` 当前把初始化阶段子流程下沉到 `BattleInitializerPhaseService`，`BattleCoreManager` 把 session/replay 容器编排下沉到 `BattleCoreManagerContainerService`。
- 这两类 helper 只负责 owner 内部编排，不升级成新的稳定 facade，也不改变原有模块边界。
- 原因：
  - 本轮目标不是“刚好压到线下”，而是给继续扩角留下安全余量，避免 owner 文件再次贴着 `220..250` 行预警区滚雪球。

### 43. 仓库一致性闸门按 `surface / formal_character / docs` 模块化拆分（2026-04-01）

- `tests/check_repo_consistency.sh` 当前只作为聚合入口，实际校验下沉到：
  - `tests/gates/repo_consistency_surface_gate.py`
  - `tests/gates/repo_consistency_formal_character_gate.py`
  - `tests/gates/repo_consistency_docs_gate.py`
- 原因：
  - 把 README、正式角色交付面、活动文档针脚全堆在单脚本里，维护时定位太慢，也容易让无关修改互相牵连。

### 44. `required_target_effects` 可选收紧到“必须由当前 owner 本人施加”（2026-04-01）

- `EffectDefinition` 当前新增可选字段 `required_target_same_owner`。
- 当 `required_target_same_owner = true` 时：
  - 前置不只检查目标身上是否存在 `required_target_effects`
  - 还要检查命中的 effect instance 记录的 `meta.source_owner_id == effect_event.owner_id`
- `apply_effect` 创建实例时，当前统一写入 `meta.source_owner_id`，供该前置守卫读取。
- 当前正式接线角色：
  - `gojo_murasaki_conditional_burst`
- 原因：
  - Gojo 的双标记爆发已经不该继续依赖“同队重复角色禁止”这种玩法前提兜语义。
  - 把来源绑定收口成 effect 级前置能力，比写角色特判更稳，也更利于后续扩角复用。

### 45. 高热点角色/规则 suite 继续按 wrapper + 子 suite 拆分（2026-04-01）

- 本轮已继续拆分的热点 suite：
  - `content_validation_contract_suite.gd`
  - `sukuna_setup_regen_suite.gd`
  - `action_guard_state_integrity_suite.gd`
  - `rule_mod_runtime_suite.gd`
  - `gojo_domain_suite.gd`
- wrapper 继续保留原路径与角色/模块归属；真实断言下沉到按主题拆开的子 suite。
- 原因：
  - 上述文件已经出现“角色资源、运行时路径、坏例 contract、多主题断言堆叠”的混杂趋势。
  - 继续扩角前先拆开，能降低回归定位成本，也避免单文件继续滚到新的屎山热点。

### 46. 持久 buff 在板凳上只掉时间，不跑普通每回合结算（2026-04-01）

- `persists_on_switch=true` 的 unit effect / unit rule mod 在 `manual_switch / forced_replace` 后继续保留；`faint` 仍然清空全部 unit effect / rule mod。
- owner 位于 bench 时，这类持久 effect 当前只继续扣 `remaining`，不进入普通 `turn_start / turn_end` trigger batch。
- 若持久 effect 在板凳上到期，只移除并写正常 remove log；当前不派发 `on_expire_effect_ids`。
- 原因：
  - 当前扩角主线只需要“换下后持续时间继续流动”，不需要把完整 off-field 结算链一起放开。
  - 先把板凳语义收成“只掉时间”能避免半场外结算把生命周期、日志和领域链路一起拉复杂。

### 47. `mp_regen / incoming_accuracy` 正式允许多来源并存，来源组内再走 stacking（2026-04-01）

- `mp_regen / incoming_accuracy` 当前不再默认按“同 owner + 同 mod_op”静默折叠。
- 来源分组优先级固定为：
  - `payload.stacking_source_key`
  - 否则当前 effect definition id
  - 再兜底到 `source_instance_id`
- 不同来源组可以并存；同一来源组内继续按 `none / refresh / replace` 处理。
- 原因：
  - 宿傩被动回蓝、装备回蓝、Gojo 无下限减命中、领域减命中这类来源后续都会并行出现，继续靠隐式 key 折叠会把扩角风险埋进运行时。
  - 把“是否合并”下放给内容层显式控制，比继续依赖隐式冲突键更清晰。

### 48. `power_bonus_source` 统一只在 `PowerBonusResolver` 注册与求值（2026-04-01）

- `ActionCastDirectDamagePipeline` 不再写角色专属 `power_bonus_source` 分支；共享伤害管线当前只调用 `PowerBonusResolver`。
- `ContentSnapshotSkillValidator` 与 `PowerBonusResolver` 统一读取共享的 `power_bonus_source` 注册表，不再各自本地硬编码白名单。
- 当前正式主线仍只开放两种来源：
  - 空串
  - `mp_diff_clamped`
- 原因：
  - 宿傩“捌”已经证明“额外威力来源”属于会继续扩张的共享能力；继续把公式硬编码在共享伤害管线里，会让后续扩角必然改到主线执行文件。

### 49. 离场保留判断统一下沉到 `LifecycleRetentionPolicy`，但 `faint` 当前行为不变（2026-04-01）

- `LeaveService` 当前不再自己展开“换人保留 / 击倒清空”的硬编码分支，而是统一委托给 `LifecycleRetentionPolicy`。
- 当前正式行为保持不变：
  - `manual_switch / forced_replace`：只保留 `persists_on_switch=true` 的 unit effect / unit rule mod
  - `faint`：一律清空全部 unit effect / unit rule mod
- 原因：
  - 这轮只需要给未来“死亡后仍保留某类持续物”预留接线位，不需要提前放开内容能力。
  - 先把判断入口收成单点，后续要扩新语义时才不必再散改 `LeaveService` 主链。

### 50. 领域对拼编排统一下沉到 `DomainClashOrchestrator`，BattleFormat 增加两条运行时常量（2026-04-01）

- `ActionQueueBuilder`、`DomainLegalityService`、`FieldApplyService` 当前都通过 `DomainClashOrchestrator` 读取同一套领域对拼编排逻辑。
- `field_apply_conflict_service.gd` 继续保留，但职责收窄为：
  - 领域 vs 领域 / 普通 field vs 领域 的低层冲突判定
  - 平 MP tie-break 结果生成
- `BattleFormatConfig` 当前新增：
  - `default_recoil_ratio`
  - `domain_clash_tie_threshold`
- 运行时快照固定复制到 `BattleState`，默认样例值继续是：
  - `default_recoil_ratio = 0.25`
  - `domain_clash_tie_threshold = 0.5`
- 原因：
  - 第三角色若继续带领域差异，原先“队列保护 / 合法性豁免 / field 冲突”散落在多处的写法会明显放大维护成本。
  - 默认反伤比例与领域平 MP 阈值已经属于格式级战斗常量，继续硬编码在执行路径里不利于复查与调参。

### 51. 鹿紫云一角色稿按最终讨论方向重写，不再默认沿用早期草稿降级语义（2026-04-01）

- `docs/design/kashimo_hajime_design.md` 当前冻结为 `v1.1`，并明确按以下口径收口：
  - 雷电抗性不再写成 `incoming_accuracy -15`，改为“雷属性攻击打到鹿紫云时伤害降低”
  - 水属性命中后的“咒力外泄”不再暂缓，正式写回角色主方案：鹿紫云自身流失 MP，并对攻击者造成等额毒属性固定伤害
  - 讨论中的四个常规技能概念，当前在既有战斗格式下按“4 选 3”落地；不静默扩成 4 常规技能槽
  - 幻兽琥珀按“不可逆强化形态”定义，主稿语义要求强化、自伤、奥义封锁都应跨换人保留
- 与上述语义不一致的实现层降级，不允许直接改主稿；若后续因为引擎能力不足需要临时降级，必须写进单独的 adjustment 文档。
- 原因：
  - 这轮复查已确认早期草稿里有几处内容虽然“能实现”，但已经偏离实际讨论方向，继续沿用只会让后续正式交付面建立在错口径上。
  - 先把角色主稿写回讨论原意，再把真正缺的引擎 / 内容扩展列清楚，后续实现与验收才不会一边开发一边改角色定义本身。
