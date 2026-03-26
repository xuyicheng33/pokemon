# 决策记录（精简版）

本文件只保留当前阶段仍需频繁引用的关键决策。
当前生效规则以 `docs/rules/` 为准；本文件只记录“为什么这样定”。

历史完整记录已归档到：

- `docs/records/archive/decisions_pre_v0.6.3.md`

## 2026-03-26

### 186. Battle Core 对外入口切换为 Manager + Session 显式生命周期
- 不再由单 facade 内部维护全局 `_sessions + 全局 id/rng reset` 语义。
- 对外统一为 `create_session / get_legal_actions / build_command / run_turn / get_public_snapshot / close_session / run_replay`。
- 每次 `create_session` 都独立 compose 容器，隔离 `id_factory / rng_service / battle_state / content_index`，避免跨局污染。

### 187. 回放执行固定使用临时容器，不读写活跃会话池
- `run_replay` 在临时容器中执行，结束后立即释放资源。
- 回放结果只通过返回值暴露，不注册到 manager 会话池。
- 现有活跃会话的快照和生命周期不得受回放过程影响。

### 188. 日志契约升级到 V3，并新增 `system:battle_header`
- `log_schema_version` 固定升级为 `3`，回放校验同步收紧到 V3。
- 初始化链新增 `system:battle_header`，位置固定在首条 `state:enter` 之前。
- V3 额外约束：完整日志必须存在且仅存在一条 `system:battle_header`。

### 189. 初始化日志头采用结构化公开快照，并禁止私有运行态 ID 泄露
- `header_snapshot` 字段固定为 `visibility_mode / prebattle_public_teams / initial_active_public_ids_by_side / initial_field`。
- `header_snapshot` 仅允许出现在 `system:battle_header` 事件，其余事件写 `null`。
- `header_snapshot` 递归禁止出现 `unit_instance_id` 等私有实例标识。

## 2026-03-24

### 106. 规则基线主动瘦身为极简闭环
- 当前先把目标收窄到“能快速实现、快速验证、玩家快速看懂”的最小战斗闭环。
- 不再为了未来扩展保留一整套暂时不用的复杂机制。

### 107. 当前移除通用状态包
- 中毒、灼伤、麻痹、睡眠、畏缩都不属于当前标准基线。
- 若以后某个技能要做持续效果，按技能定义单独补规则，不先假设一套默认状态系统。

### 108. 当前移除暴击、真伤、护盾、闪避率
- 这些机制全部暂时退出首版。
- 原因是它们会显著增加实现分叉、日志复杂度和新手理解成本。

### 109. 当前只保留一个信息可见性模式
- 只保留 `prototype_full_open`。
- 规则继续 full open，但 UI 必须做分层展示，避免玩家一上来信息爆炸。

### 110. `priority` 收敛为唯一数轴
- 全项目只有一个 `priority` 概念。
- 数值越大越先，默认值为 `0`，全局范围 `-5 ~ +5`。
- 行动排序和效果排序都共用这套语义，不再保留 `absolute_order / action_priority / skill_priority` 多层命名。

### 111. 行动侧 `priority` 保留值写死
- 绝对先手奥义固定 `+5`。
- 手动换人固定 `+4`。
- 普通技能允许 `-2 ~ +2`，默认 `0`。
- 绝对后手奥义固定 `-5`。

### 112. 标准模式只保留被动持有物
- 持有物是装备，不是指令。
- AI 和引擎都不需要处理“使用持有物”行动入口。

### 113. field 回归，但先压成全场唯一实例
- 当前同一时刻全场只允许 1 个 field 生效。
- 新 field 成功生效后直接替换旧 field。
- 具体效果必须写在技能描述里，不接受口头补充。

### 114. 伤害公式采用官方骨架简化版
- 保留等级、威力、攻防对抗的主骨架。
- 去掉暴击、随机伤害、真伤、护盾、属性克制、同属性加成。
- 先保证数值直觉像宝可梦系，但实现比官方简单得多。

### 115. 物理 / 特殊双轨保留
- 伤害类型保留物理和特殊的区分。
- 物理走攻击对防御；特殊走特攻对特防。

### 116. 命中率只看技能自身 `accuracy`
- 当前命中只看技能命中率。
- 没有闪避率，没有命中阶段，没有闪避阶段。

### 117. AI 不能自己试错找合法指令
- 引擎负责先产出合法指令列表。
- AI 只从合法列表中选一个，避免死循环和“试到合法为止”的脏逻辑。

### 118. 随机契约先压到最小集
- 当前最小随机只保留同速打平、命中判定、额外效果概率。
- 所有随机都必须可回放，并记录消费序号。

### 119. 持续效果继续维持极简持续模型
- 当前持续效果只允许“按回合”或“永久”两种持续方式。
- “按触发次数消耗”不属于当前基线，后续若真要加，先改效果模型和生命周期文档。

### 120. `turn_start` 的 MP 回复读取回合开始前已生效状态
- 本回合开始前已经存在的 field、常驻持有物和已落地规则修正，会参与本次 MP 回复。
- 同一个 `turn_start` 里新触发的 field / effect / rule_mod，不回头改写本次回复结果。

### 121. 超时默认动作命名统一
- 行动类型固定写 `timeout_default`。
- 触发来源固定写 `timeout_auto`。
- 不再保留 `timeout_auto_action` 这类并行命名。

### 122. 效果系统触发点删到当前最小集
- 当前基线只保留 `battle_init / turn_start / turn_end / on_cast / on_hit / on_miss / on_enter / on_exit / on_switch / on_faint / on_kill`。
- `on_action_attempt / before_action / after_action / on_resource_change` 不属于当前极简基线，先移出文档。
- 技能侧 `effects_on_cast` 明确对应 `on_cast`，不再靠近似命名猜含义。

### 123. 历史文档继续保留，但必须显式防误读
- `docs/records/archive/` 和已退役总表会继续保留，方便回溯讨论过程。
- 这些文件允许存在旧术语和已废弃机制，但必须在文件头明确标注“历史归档，不得直接实现”。
- 当前开发、评审、代码实现一律以 `docs/rules/` 为准；全局搜索规则关键字时默认排除 archive。

### 124. 玩家速览文档作为展示层补充，不参与权威判定
- 新增 `docs/rules/player_quick_start.md` 作为玩家一页说明，目标是“快速看懂玩法”。
- 该文档只做说明层总结，不定义新规则；若与模块细则有冲突，以 `docs/rules/00~06` 为准。

### 125. 极简基线终检结论
- 本轮终检确认：现行规则冲突已收口到可实现状态。
- 仍保留旧口径的文件仅限 `docs/records/archive/*` 和 `docs/records/battle_system_rules.md`，且都属于历史追溯用途。

## 2026-03-25

### 145. 战斗内容资源独立为 `content/`
- 战斗格式、单位、技能、被动、effect、field 等定义不再放进 `assets/`。
- `assets/` 继续只承载美术、音频、UI 静态资源。

### 146. 当前内容格式固定为 Godot `Resource`
- 原型期正式内容格式采用 `.tres`。
- 当前不走 JSON 与 Resource 双轨，避免 schema 漂移与导入逻辑翻倍。

### 147. 核心依赖采用 Scene + Composition Root 组装
- `Boot.tscn` 作为主场景入口，`BattleSandbox.tscn` 作为战斗骨架试跑入口。
- 核心服务由 `BattleCoreComposer` 显式 new 并组装，不以 autoload 作为主依赖模式。

### 148. 跨模块正式接口采用强类型 contract
- `QueuedAction`、`ActionResult`、`LogEvent`、`SelectionState`、`ReplayInput/Output` 等全部落成独立类。
- 裸 `Dictionary` 只允许保留在显式扩展字段或临时输入边界，不再作为长期正式 contract。

### 149. 本轮“骨架完成”的定义是决策完整，不是逻辑完整
- 本轮目标是补齐目录、文档、contract、模块入口、场景和测试脚手架。
- 具体战斗逻辑、角色技能、正式 AI、正式 UI 不属于当前完成标准。

### 126. 当前基线移除“行动开始前被拦下”失败类型
- 当前极简基线没有 `before_action` 触发点，也没有通用状态包。
- 因此现行文档不再保留 `action_failed_pre_start`；若以后确实需要“行动到窗口前被拦下”，必须先补明确触发点，再补扣 MP 与日志语义。

### 127. 换人、强制换下、强制补位的替补选择契约写死
- 手动换人在选择阶段锁定 bench 目标 `unit_id`，队列锁定后不允许改选。
- 强制换下与强制补位都不进入行动队列，但仍保留从合法 bench 列表选替补的权利；若只剩 1 名则自动锁定。

### 128. `HP = 0` 的中间态显式命名为 `fainted_pending_leave`
- 单位一旦 `HP = 0`，立即失去在场资格，并等待当前击倒窗口统一处理离场。
- 当前基线没有“可作用于倒下单位”的特例，因此后续普通 payload 不再对它生效。

### 129. 奥义继续复用普通技能字段
- 奥义不设独立资源槽，也不额外发明第二套命中或 payload 体系。
- 奥义只是主动技能中的一个受限分支：沿用 `mp_cost / accuracy / targeting / effects_on_cast` 等通用字段，只额外限制 `priority`。

### 130. 日志空值与自动来源口径统一写死
- `resource_forced_default` 固定搭配 `command_source = resource_auto`，`timeout_default` 固定搭配 `command_source = timeout_auto`。
- 非适用日志字段统一写 `null`，避免 `0 / 空串 / 省略` 三套口径并存。

### 131. 首发 `on_enter` 与 `battle_init` 明确分层
- 首发上场先走 `on_enter`，战斗开始统一效果再走 `battle_init`。
- 同一份效果不能因为“首发入场”同时挂在 `on_enter` 和 `battle_init` 两边重复结算。

### 132. 模块 06 再瘦一刀，只保留当前真正要用的作用域
- 当前 `EffectDefinition.scope` 只保留 `self / target / field`。
- `side`、多目标、自定义目标都不再作为现行保留位，后续若需要必须先补目标与生命周期规则。

### 133. `rule_mod` 继续保留，但禁止改写核心流程
- 当前只允许它修改已明文开放的倍率链、MP 回复规则或技能合法性。
- 不允许通过 `rule_mod` 绕开 `priority`、行动排序、击倒窗口、胜负判定等核心流程。

### 134. 首发 `on_enter` 与 `battle_init` 按固定阶段顺序执行，不跨触发点混排
- 初始化先结算首发 `on_enter` 及其引发的补位链，场面稳定后再统一结算 `battle_init`。
- 统一效果排序只在“同一触发点、同一批次”内生效，不把 `on_enter` 和 `battle_init` 混成一个排序池。

### 135. `fainted_pending_leave` 是当前唯一的倒下待离场运行态名
- 单位 `HP = 0` 后立即进入 `fainted_pending_leave`，直到当前击倒窗口完成离场清理。
- 当前文档不再使用独立 `fainted` 作为运行判定态，避免目标合法性与日志口径分叉。

### 136. 持续效果实例继承根来源排序元数据，不新开独立来源桶
- `apply_effect` 创建实例时必须复制根来源的 `source_instance_id / source_kind_order / source_order_speed_snapshot`。
- 后续持续效果触发继续沿用这套元数据，不额外发明 `status_effect` 之类的新排序桶。

### 137. 行动链日志字段按根行动继承，只有非行动系统链才写 `null`
- 行动根事件及其衍生效果事件统一继承 `action_id / action_queue_index / actor_id / command_type / command_source`。
- `battle_init / turn_start / turn_end / system_replace` 这类非行动系统链才把行动字段写 `null`，并统一使用 `system:*` 命名。

### 138. AI 不接收“空合法列表”，引擎直接生成默认动作
- 引擎先完成合法性判断；若技能、手动换人、奥义都不合法，直接替代为 `resource_forced_default`。
- AI 只在存在可执行结果时从中选择，不负责处理“没有任何合法主动方案”的兜底判定。

### 139. 行动执行起点、payload 顺序与自动动作链归属写死
- 技能、奥义、两类默认动作的执行起点固定为：`has_acted = true -> 扣 MP -> on_cast -> 命中判定 -> 后续 payload / on_hit / on_miss`。
- `payloads` 严格按声明顺序执行，后序 payload 读取前序写回的最新运行态。
- `resource_forced_default` 与 `timeout_default` 进入行动队列后仍属于 `action` 链，不额外发明 `timeout` 链。

### 140. 回合节点触发范围统一为“仅在场单位 + field”
- `turn_start / turn_end` 的回合节点触发只对当前在场单位和全场 field 生效。
- bench 单位不参与回合节点触发；其被动与持有物的回合节点效果同样不触发。

### 141. `action_failed_post_start` 只在执行起点判定
- 行动执行起点若目标无效或硬条件不满足，记为 `action_failed_post_start`。
- 行动已开始后，若后续 payload 目标无效，仅跳过该 payload，不改写行动状态。

### 142. 持续时间扣减起算点写死
- `turns` 模式的持续效果与 field 在创建后，遇到的第一个对应扣减节点即为首次扣减点。
- 若本回合该节点尚未结算，则本回合会立即扣减。

### 143. `rule_mod` 运行时模型与 payload 最小契约冻结
- `rule_mod` 必须显式声明 `mod_kind / mod_op / value / scope / duration_mode / duration / decrement_on / stacking`。
- 运行时统一创建 `RuleModInstance`，并在读取 `final_mod`、MP 回复与技能合法性时按稳定顺序应用。

### 144. 战斗日志新增 `event_type` 枚举与 `invalid_battle_code`
- 完整日志新增 `event_type` 字段，使用固定最小枚举。
- `invalid_battle` 终止必须写入 `invalid_battle_code`，避免回放与回归测试漂移。

### 150. 批次执行顺序固定为“先可执行骨架，再可信测试，再规则链，再文档收口”
- 先修编译和类型稳定，保证工程可加载。

### 151. 效果去重键改为 `source_instance_id + trigger + event_id`
- `event_step_id`/`step_counter` 在无日志或链路被折叠时会误判重复。
- 以 `event_id` 作为去重的一部分，可稳定对应同一事件实例。

### 152. 统一 `cause_event_id = event_chain_id:event_step_id`
- effect/system 事件不再写 `system:*` 或 `action_id` 作为归因。
- 统一用“当前事件自身的链路坐标”作为因果归因基线，保持回放可复原。
- 再修测试失败语义与引擎错误闸门，避免“假绿灯”掩盖实现问题。
- 规则链补齐后再做文档收口，避免先写文档后反复返工。

### 153. deterministic 契约必须显式重置 ID 与 RNG
- `ReplayRunner.run_replay()` 每次执行前重置 `id_factory`，并按输入种子重置 `rng_service`。
- 命令解析优先使用 `actor_public_id/target_public_id` 重映射运行时实例，避免历史运行残留污染回放。

### 154. 测试通过语义升级为“双闸门”
- 通过标准不再仅是业务断言全绿。
- 还必须同时满足引擎日志无 `SCRIPT ERROR / Compile Error / Parse Error / Failed to load script`。

### 155. 初始化链路按批次冻结
- 固定为首发 `on_enter` 批次 -> 击倒窗口稳定 -> `battle_init` 批次。
- 不允许跨触发点混排，不允许把两者塞进同一排序池。

### 156. `rule_mod` 读取点冻结为三入口
- 允许读取点只有：`final_mod`、`mp_regen`、`skill_legality`。
- 扣减节点只允许 `turn_start / turn_end`，到期即移除并写移除日志。

### 157. 非行动系统链日志字段采用 `null + system:*` 口径
- 非行动系统链的 `action_id / action_queue_index / actor_id / select_*` 一律写 `null`。
- `command_type` 必须写 `system:*`，`command_source` 必须写 `system`。

### 158. 文档、记录、实现三方收敛到 `docs/rules/00~06`
- `docs/rules/` 作为唯一规则权威，`docs/design/` 只描述实现落点。
- 任何口径变更必须同步更新记录文档，避免聊天口径漂移。

### 159. 启动阶段系统日志必须提前绑定系统链上下文
- 初始化最早的 `state:enter` 日志也必须满足“非行动系统链 = `null + system:*`”口径。
- 不允许落入 `system:orphan` 导致 `command_type` 为空或链路来源漂移。

### 160. 提交指令必须属于 legal_action_set，不能只靠结构校验
- `skill_legality` 不仅影响“展示给玩家/AI 的可选列表”，还必须拦截提交路径。
- 提交了不在 legal 集内的指令，直接按 `invalid_command_payload` fail-fast 终止并写日志。

### 161. 日志契约升级为 V2
- 新增 `log_schema_version = 2`，并补齐 `chain_origin / trigger_name / cause_event_id / killer_id` 字段。
- effect 事件必须携带 `trigger_name / cause_event_id`；其他事件允许 `null`。
- 回放器需校验 V2 字段完整性，未通过视为回放失败。

### 162. 回放必须完整跑到终局并强化成功判定
- `ReplayRunner` 运行至“战斗结束或回合上限触发”，不再允许半局成功返回。
- `ReplayOutput.succeeded` 需同时满足“执行完成 + V2 日志校验通过 + 终局结果有效”。

### 163. 持续效果实例接入统一触发链并补齐扣减移除日志
- 新增持续效果调度层，按触发点收集 `effect_instances` 并纳入统一排序链。
- `turn_start / turn_end` 触发后按 `decrement_on` 扣减，`remaining <= 0` 立即移除并写 `effect:remove_effect`。
- 离场时若未标记 `persists_on_switch`，则移除并写移除日志。

### 164. 内容快照加载时强制校验
- 内容层加载后立即校验，非法配置直接 fail-fast。
- 校验覆盖：技能优先级范围、奥义引用、目标/触发/作用域白名单、`rule_mod` 组合、跨资源引用完整性。

### 165. `battle_end` 日志严格归入系统链
- `result:battle_end` 事件的 `command_type` 必须为 `system:*`，禁止写入 `result:battle_end`。
- `chain_origin` 由系统链上下文提供，保持非行动链口径不变。

### 166. 选择阶段非法提交统一 fail-fast，不保留“拦截重选”
- 选择阶段收到非法提交（结构非法、side/actor 非法、重复提交、不在 legal 集）一律 `invalid_battle`。
- 统一错误码为 `invalid_command_payload`，并写 `system:invalid_battle` 日志。

### 167. 强制换下/强制补位统一走系统替补选择接口
- 引擎新增 `ReplacementSelector` 注入点：输入战斗态、side、合法候选、原因；输出目标 `unit_id`。
- 候选数 > 1 时必须调用接口；候选数 = 1 自动锁定。
- 接口返回空值、非法目标或超时，一律 `invalid_replacement_selection` fail-fast。

### 168. 内容层与组队阶段新增硬校验约束
- `unit.skill_ids` 固定为 3 槽；普通技能优先级只能是 `-2..+2`。
- `ultimate_skill_id` 对应技能优先级只能是 `+5/-5`，且不得出现在任意单位的 `skill_ids`。
- `BattleSetup` 维度新增“同队被动持有物不可重复”运行前校验，校验失败直接 fail-fast。

### 169. Battle Core 收口执行顺序固定为“先文档后代码”
- 先把规则文档、设计文档、记录文档统一到同一口径，再落代码与测试。
- 若实现中发现规则冲突，必须先改 `docs/rules/`，禁止跳过文档层直接拍板实现。

### 170. `PassiveItemDefinition.on_receive_effect_ids` 进入禁用迁移态
- 字段暂时保留用于资源迁移，但当前基线不允许其承载运行逻辑。
- 内容快照校验将收紧为“非空即失败”，避免“文档禁用但运行时悄悄生效”。

### 171. `forced_replace` 采用最小闭环落地策略
- 本轮只落地 1v1 单 active 槽位所需链路，不扩到多目标、多槽位。
- 执行顺序固定为 `on_switch -> on_exit -> leave(forced_replace) -> replace -> on_enter`，选择失败统一 `invalid_replacement_selection`。

### 172. 去除日志与依赖兜底，改为显式硬失败
- `LogEventBuilder` 不再自动构造 `system:orphan` 链；缺失 `chain_context` 时直接失败。
- 关键依赖（如 `effect_instance_dispatcher`）不允许“为空就跳过”，装配阶段必须断言完整性。

### 173. 内容快照对 `on_receive_effect_ids` 执行加载期硬拦截
- `PassiveItemDefinition.on_receive_effect_ids` 当前只作为迁移占位字段，运行时禁用。
- 校验策略固定为“字段可存在，但值非空立即失败”，错误应在加载期暴露，而非战斗中兜底。

### 174. `forced_replace` payload 以最小生命周期闭环接入主链
- 新增 `forced_replace` payload，执行起点先校验合法 bench，再按候选规则调用系统替补选择接口。
- 成功路径固定顺序为 `on_switch -> on_exit -> leave(forced_replace) -> state:replace -> state:enter -> on_enter`。
- 系统选择返回空值或非法目标时，统一以 `invalid_replacement_selection` 立即终止战斗。

### 175. 日志构建移除 `system:orphan` 自动兜底
- `LogEventBuilder` 不再在 `chain_context` 缺失时自动补链。
- `chain_context` 或 `event_chain_id` 缺失时直接硬失败，避免日志来源漂移被静默吞掉。

### 176. 关键依赖缺失统一视为状态破坏并立即终止
- 移除 `effect_instance_dispatcher`、`rule_mod_service` 等关键依赖的“为空就跳过”路径。
- 在 composition 增加依赖完整性断言，并在运行入口追加依赖完整性检查；缺失时立即 `invalid_state_corruption` 终止。

### 177. 依赖缺失终止链必须支持“无日志降级硬终止”
- 当缺失 `id_factory / battle_logger / log_event_builder` 这类终止链本身依赖时，不再尝试走完整日志终止流程。
- 统一改为“先保证 `battle_result/phase` 落到 finished，再按可用依赖决定是否写日志”，避免二次崩溃掩盖首个故障。

### 178. 生命周期触发批次执行收口到单一执行器
- 新增 `TriggerBatchRunner` 统一承载“收集事件 -> 排序 -> 执行 payload -> 传播 invalid code”流程。
- `battle_initializer / turn_loop_controller / action_executor / faint_resolver / replacement_service` 不再各自复制一套触发批次流水线，后续扩展只改一个点。

### 179. `battle_end` 与 `turn_limit` 必须继承真实系统来源
- `result:battle_end` 不允许因为先把 `phase` 改成 `finished` 而丢失真实来源阶段。
- `turn_start / turn_end / battle_init / turn_limit` 触发的终局日志，必须沿用对应系统链的 `command_type / chain_origin`。
- `system:turn_limit` 的 `chain_origin` 固定归入 `turn_end`。

### 180. 内容快照校验补齐字段边界与重复 ID 检查
- 内容资源加载期除跨引用校验外，还必须拦截重复 ID、空 ID、技能数值越界、效果优先级越界和 payload 字段非法。
- 重复资源 ID 不再允许“后加载静默覆盖前加载”，必须在内容加载期直接失败。
- `resource_mod.resource_key` 与 `stat_mod.stat_name` 这类字段必须在内容层就收紧白名单，不能等运行时默默兜底。

### 181. 系统锚点日志允许保留 `trigger_name`
- effect 事件仍然必须填写 `trigger_name / cause_event_id`。
- `system:battle_init / system:turn_start / system:turn_end` 这类系统锚点事件允许保留对应节点名到 `trigger_name`，用于日志诊断。
- 非 effect 事件不再强求 `trigger_name` 一律为 `null`；但 `cause_event_id` 仍只在 effect 事件中使用。

### 182. Battle Core 分层冻结为 6 层单向依赖
- 核心层次固定为：`content/contracts/runtime/shared constants -> pure domain -> subsystem coordinators -> orchestrators -> facades -> 外围层`。
- 依赖只能向下，外围层只能通过 facade 或明确 contract 进入核心。
- `runtime/math/logging/orchestrator` 的职责边界写死为硬约束，不做口头约定。

### 183. `rule_mod` 永久定位为“受限读取修正器”
- 白名单读取点冻结为：`final_mod / mp_regen / skill_legality`。
- 禁止通过 `rule_mod` 改排序、阶段顺序、击倒窗口、补位时机、胜负判定、目标模型、生命周期与日志链路语义。
- 新读取点必须先更新 `docs/rules/06` 与架构约束文档，再允许实现。

### 184. 大文件治理采用“职责优先 + 行数强预警”
- 核心服务超过 250 行触发职责复核；orchestrator/coordinator 超过 350 行默认拆分；单测试文件超过 600 行默认按子域拆分。
- 超阈值仍不拆必须在记录中写明“为什么合理 + 预计何时拆”。

### 185. 外围禁止直连 runtime，改由 facade 出口统一收口
- `adapters/composition/scenes` 不得直接 import `battle_core/runtime/*`。
- 对外只暴露 public snapshot，不暴露内部 `unit_instance_id` 与核心对象图。
- 架构闸门新增静态检查，发现外围直连 runtime 即失败。

### 186. 当前超阈值文件复核结果（保留并记录原因）
- `src/battle_core/content/battle_content_index.gd`：当前仍作为内容注册与快照校验集中点，待内容校验规则稳定后再拆分 schema 校验子服务。
- `src/battle_core/effects/rule_mod_service.gd`：当前刚完成 stacking key schema 收口，先保持单点实现，后续按读取点拆为 `rule_mod_read_service + rule_mod_instance_service`。
- `src/battle_core/effects/payload_executor.gd`：当前仍是 payload 主执行枢纽，后续按 payload 家族拆成 `resource/stat/field/rule_mod/lifecycle` 子执行器。

## 2026-03-26

### 187. `prototype_full_open` 对外快照在引擎层补齐全公开字段并保留旧字段
- `BattleCoreFacade` 统一输出 `team_units + field + prebattle_public_teams` 的 full-open 快照信息。
- 保留 `active_public_id / active_hp / active_mp / bench_public_ids` 等既有字段，避免外围读取契约断裂。
- 对外快照禁止泄露运行态私有实例 ID（如 `unit_instance_id`）。

### 188. effect 日志统一补齐 `effect_roll` 空值语义
- effect 事件日志的 `effect_roll` 一律来自 `EffectEvent.sort_random_roll`。
- 同排序组打平消耗随机时写具体值；未消费时固定写 `null`，禁止缺省或混写。

### 189. `ReplacementService` 依赖注入按最小职责瘦身
- 移除未使用依赖（被动/field/effect/rng 等）并同步清理 composer/container 接线。
- 保留 `replacement_selector + leave_service + trigger_batch_runner + logger` 最小闭环依赖，降低耦合面。

### 190. 回放输入口径收敛为 `ReplayInput`，日志定位为校验与诊断
- 回放执行输入固定为 `battle_seed + content_snapshot_paths + battle_setup + command_stream`。
- 完整日志用于可复现校验、问题定位与回归比对，不再描述为“单独可驱动重放”的唯一输入。

### 191. 超阈值文件维持单点实现，暂不拆分（2026-03-26 复核）
- `src/battle_core/effects/payload_executor.gd`（403 行）：当前承载 9 类 payload 的统一执行与链路日志语义，拆分会同时改执行边界与回归基线；待 payload 家族稳定后再拆。
- `src/battle_core/content/battle_content_index.gd`（328 行）：当前承载内容快照加载 + schema 强校验的 fail-fast 入口，拆分时机放在内容 schema 进入稳定期后。
- `src/battle_core/effects/rule_mod_service.gd`（292 行）：当前承载实例创建、读取排序、扣减与移除日志的完整闭环，待读取点新增需求明确后再拆 `read/instance` 子服务。
