# 决策记录（精简版）

本文件只保留当前阶段仍需频繁引用的关键决策。
当前生效规则以 `docs/rules/` 为准；本文件只记录“为什么这样定”。

历史完整记录已归档到：

- `docs/records/archive/decisions_pre_v0.6.3.md`

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
- 再修测试失败语义与引擎错误闸门，避免“假绿灯”掩盖实现问题。
- 规则链补齐后再做文档收口，避免先写文档后反复返工。

### 151. deterministic 契约必须显式重置 ID 与 RNG
- `ReplayRunner.run_replay()` 每次执行前重置 `id_factory`，并按输入种子重置 `rng_service`。
- 命令解析优先使用 `actor_public_id/target_public_id` 重映射运行时实例，避免历史运行残留污染回放。

### 152. 测试通过语义升级为“双闸门”
- 通过标准不再仅是业务断言全绿。
- 还必须同时满足引擎日志无 `SCRIPT ERROR / Compile Error / Parse Error / Failed to load script`。

### 153. 初始化链路按批次冻结
- 固定为首发 `on_enter` 批次 -> 击倒窗口稳定 -> `battle_init` 批次。
- 不允许跨触发点混排，不允许把两者塞进同一排序池。

### 154. `rule_mod` 读取点冻结为三入口
- 允许读取点只有：`final_mod`、`mp_regen`、`skill_legality`。
- 扣减节点只允许 `turn_start / turn_end`，到期即移除并写移除日志。

### 155. 非行动系统链日志字段采用 `null + system:*` 口径
- 非行动系统链的 `action_id / action_queue_index / actor_id / select_*` 一律写 `null`。
- `command_type` 必须写 `system:*`，`command_source` 必须写 `system`。

### 156. 文档、记录、实现三方收敛到 `docs/rules/00~06`
- `docs/rules/` 作为唯一规则权威，`docs/design/` 只描述实现落点。
- 任何口径变更必须同步更新记录文档，避免聊天口径漂移。
