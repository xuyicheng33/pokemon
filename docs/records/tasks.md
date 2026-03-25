# 任务清单（精简版）

本文件只保留最近任务与当前回归要点，避免历史条目干扰实现。

历史完整记录已归档到：

- `docs/records/archive/tasks_pre_v0.6.3.md`

当前生效规则以 `docs/rules/` 为准。

## 2026-03-25

### 复查问题全量修复计划（核心契约优先，4 批次）
- 目标：统一规则文档、设计文档、核心实现与测试闸门，优先消除会导致分叉的核心契约冲突。
- 范围：仅核心契约与测试；不接 UI/AI 真实交互；不做双轨兼容，直接迁移新契约。
- 验收标准：非法提交/替补选择/field 归属/内容校验均按新口径 fail-fast；`tests/run_with_gate.sh` 全绿且引擎错误日志为 0。

#### 批次执行与提交

|批次|结果|提交|
|---|---|---|
|批次 1：文档口径收口（非法提交 fail-fast + 替补选择契约）|已完成|`135b962`|
|批次 2：核心契约改造（ReplacementSelector + 关键逻辑修正）|已完成|`858780f`|
|批次 3：内容校验强约束前置|已完成|`7850505`|
|批次 4：测试与闸门升级|已完成|本批次提交|

#### 最小可玩性检查清单（本计划）
- 可启动：headless 测试可完整运行到结束。
- 可操作：强制补位链在显式选择契约下可闭环。
- 无致命错误：非法输入立即终止并给出明确错误码，无静默回退。

#### 回归检查要点（本计划）
- 规则/设计/记录三层文档对非法提交与替补选择语义完全一致。
- `double_faint` 平局原因、`apply_field` 来源归属、内容校验新增约束都有回归覆盖。
- `tests/run_with_gate.sh` 是唯一闸门，必须断言全绿且引擎错误日志为 0。

### 战斗核心修复总方案（V2 契约保持，四批次落地）
- 目标：修复回放与日志契约、持续效果主链、内容校验、测试与 CI 闸门，并收口文档与记录。
- 范围：批次 1（回放与日志契约对齐）+ 批次 2（持续效果实例主链）+ 批次 3（内容校验 fail-fast）+ 批次 4（测试/CI/文档/记录）。
- 验收标准：回放完整终局；日志 V2 字段合规；持续效果生命周期完整；非法内容加载期失败；CI 闸门拦截回归。

#### 批次执行与提交

|批次|结果|提交|
|---|---|---|
|批次 1：回放与日志契约硬对齐|已完成|`2199835`（合并提交）|
|批次 2：持续效果实例接入主链|已完成|`2199835`（合并提交）|
|批次 3：内容层校验与失败前置|已完成|`2199835`（合并提交）|
|批次 4：测试、CI、文档与记录收口|已完成|`2199835`（合并提交）|

#### 最小可玩性检查清单（本轮）
- 可启动：`tests/run_with_gate.sh` 可完整运行并通过。
- 可操作：回放在无后续输入时仍能自动打到终局。
- 无致命错误：引擎日志无 `SCRIPT ERROR / Compile Error / Parse Error / Failed to load script`。

#### 回归检查要点（本轮）
- `result:battle_end` 事件 `command_type` 必须为 `system:*`，且 `ReplayOutput.succeeded` 判定收紧。
- `apply_effect` 产生的持续效果在 `turn_start / turn_end / on_enter / on_exit / on_faint / on_kill` 触发并可扣减移除。
- 内容加载期非法配置直接 fail-fast（优先级、`rule_mod` 组合、断引用）。
- CI 默认执行 `tests/run_with_gate.sh` 并阻断失败。

### Battle Core 全量修复计划（严格验收版，4 批次）
- 目标：一次性修复“编译断裂、测试假绿灯、规则链未落地、文档口径漂移”，并把代码、规则文档、记录文档收敛到同一口径。
- 范围：批次 1（编译与类型稳定）+ 批次 2（测试闸门与 deterministic）+ 批次 3（规则链与生命周期）+ 批次 4（文档收口与回归封板）。
- 验收标准：`godot --headless` 无脚本错误；测试通过同时满足“断言全绿 + 引擎错误日志为 0”；规则关键路径与 `docs/rules/00~06` 最小全集一致；记录落盘可追溯。

#### 批次执行与提交

|批次|结果|提交|
|---|---|---|
|批次 1：编译与类型系统修复|已完成|`8989750` (`fix: batch1 compile-type stabilization`)|
|批次 2：测试可信化与 deterministic 基线|已完成|`924a542` (`fix: batch2 deterministic test gate`)|
|批次 3：规则最小全集补齐|已完成|`845e7d1` (`fix: batch3 rule chain and lifecycle parity`)|
|批次 4：文档收口 + 回归矩阵 + 封板|已完成|`0df94fb` + `f9abe49` + `c3174fd`|

#### 本轮已落地内容（批次 1~3）
- 批次 1：修复 headless 脚本加载断裂、类型推断不稳定、跨脚本类型依赖问题，恢复可执行骨架。
- 批次 2：重构 `tests/run_all.gd` 失败语义，新增 `tests/run_with_gate.sh` 引擎错误闸门，固化 `ReplayRunner` 与 `IdFactory` 的 deterministic 重置。
- 批次 3：补齐 `battle_init/on_enter` 批次边界、`turn_start/turn_end` active+field 触发链、`on_faint/on_kill/on_exit/on_enter` 生命周期调度、`rule_mod` 三读取点与扣减移除日志、invalid code fail-fast 终止链路。

#### 严格验收回归矩阵（2026-03-25）

|项|结果|
|---|---|
|编译健康（headless 脚本加载）|通过：`godot --headless --path . --script tests/run_all.gd`，0 个 `SCRIPT ERROR`|
|回放确定性（同输入哈希一致）|通过：`PASS deterministic_replay`|
|默认动作链（`timeout_default` / `resource_forced_default`）|通过：`PASS timeout_default_path` + `PASS resource_forced_default_path`|
|初始化时序（`on_enter` -> 击倒窗口 -> `battle_init`）|通过：`PASS init_chain_order`|
|回合节点范围（仅 active + field）|通过：`PASS turn_scope_active_and_field`|
|生命周期（倒下窗口、补位、`on_faint/on_kill/on_exit/on_enter`）|通过：`PASS lifecycle_faint_replace_chain`|
|field（替换、扣减、到期移除）|通过：`PASS field_expire_path`|
|rule_mod（三读取点、扣减、过期移除）|通过：`PASS rule_mod_paths` + `PASS rule_mod_skill_legality_enforced`|
|非法终止（`invalid_battle_code` 即停）|通过：`PASS invalid_battle_rule_mod_definition`|
|日志契约（`null` 语义、`event_type`、`command_type/source`）|通过：`PASS log_contract_semantics`|

#### 本轮最终命令结果
- `tests/run_with_gate.sh`：通过，输出 `GATE PASSED: assertions and engine logs are clean`。
- `godot --headless --path . --script tests/run_all.gd`：通过，输出 `ALL TESTS PASSED`。

### Battle Core 深度修复计划（后续收口：日志链路与资源释放）
- 目标：补齐 V2 日志链路的去重与归因口径，修复测试残留导致的资源泄露告警。
- 范围：effect 去重键改为 `source_instance_id + trigger + event_id`；所有 effect/system 事件写入 `cause_event_id = event_chain_id:event_step_id`；测试流程在结束后统一 dispose battle core；内容快照加载改为显式 `ResourceLoader`。
- 验收标准：`tests/run_with_gate.sh` 通过且引擎日志干净；`invalid_chain_depth_dedupe_guard` 保持稳定；日志 V2 字段不再出现链路归因缺口。

#### 批次执行与提交

|批次|结果|提交|
|---|---|---|
|后续收口：日志链路与资源释放|已完成|`a84bca4` (`fix: log v2 follow-up and cleanup`)|

#### 最小可玩性检查清单（后续收口）
- 可启动：测试脚本无解析错误，可完整跑完并退出。
- 可操作：触发链去重不再依赖 `step_counter`，同事件重复触发仍可稳定 fail-fast。
- 无致命错误：引擎不再报告 `ObjectDB` 泄露告警。

#### 回归检查要点
- `effect` 去重键是否为 `source_instance_id + trigger + event_id`。
- `cause_event_id` 是否统一为 `event_chain_id:event_step_id`。
- 测试结束是否显式释放 core，且引擎日志为 0 错误。

### 工程骨架补全 + 强类型契约落盘（已完成：v0.8.0 骨架补丁）
- 目标：把战斗核心从“提纲式文档 + 半截目录”升级为“决策完整骨架”，让后续实现者不再需要自行决定目录、contract、场景入口和内容资源格式。
- 范围：`content/` 根目录、`docs/design/` 修订、`src/battle_core/contracts/`、runtime 强类型化、各模块 service skeleton、`src/composition/`、`Boot/BattleSandbox` 场景、测试脚手架占位。
- 验收标准：目录结构、设计文档、强类型 contract、模块入口类、主场景接线与记录文档全部一致；仓库中不再存在“文档提到但没有对应类/目录”的骨架缺口。

#### 已完成内容
- 新增独立 `content/` 根目录，明确战斗定义资源与 `assets/` 分离。
- 把 `docs/design/` 从提纲式文档修订为实现级骨架方案，写死 `contracts/`、`composition/`、Scene Composition Root 与 Resource 方向。
- 新增强类型 contract：`Command / LegalActionSet / SelectionState / ChainContext / EffectEvent / QueuedAction / ActionResult / LogEvent / ReplayInput / ReplayOutput / BattleResult`。
- 把 runtime 层升级为强类型对象，`BattleState / SideState / UnitState` 不再继续使用长期裸 `Dictionary` 口径。
- 新增内容 `Resource` 类与 payload 基类，确立 `.tres` 为正式内容格式。
- 补齐 `commands / turn / actions / math / lifecycle / effects / passives / logging / adapters` 的模块入口类。
- 新增 `BattleCoreComposer` 与 `BattleCoreContainer`，确立显式装配方式。
- 新增 `Boot.tscn`、`BattleSandbox.tscn` 并将 `project.godot` 主场景指向 boot。
- 新增 `content/README.md`、样例 `sample_battle_format.tres`、`tests/README.md` 与空目录占位文件。
- 通过 Godot 4.6.1 本地运行自检：项目能正常进入 `BattleSandbox`，输出 `Battle sandbox ready: battle_1`，无解析错误。

#### 最小可玩性检查清单（骨架基线）
- 可启动：Godot 工程有明确主场景，启动后可进入 `BattleSandbox`。
- 可操作：核心服务可被 `BattleCoreComposer` 一次性装配，sandbox 可创建空 `BattleState`。
- 无致命错误：不会再出现“文档提到 contract 但仓库里没有类”“内容资源和美术资源混放”“只有目录没有入口类”的结构分叉。

#### 回归检查要点
- `project.godot` 是否已指向 `scenes/boot/Boot.tscn`。
- `docs/design/` 是否与当前目录、contract、composition root 口径一致。
- `src/battle_core/contracts/` 是否覆盖文档中提到的核心 contract。
- `content/` 是否已经独立于 `assets/`。
- 各模块空目录是否都已变成“至少有一个明确入口类”。

### 规则歧义补齐 + 日志事件枚举收口（已完成：v0.7.2 文档补丁）
- 目标：补齐剩余歧义点，避免实现分叉，并把日志事件类型与非法终止错误码写死。
- 范围：回合节点触发范围、`action_failed_post_start` 触发点、持续时间扣减起算、`rule_mod` 运行时模型、日志 `event_type` 与 `invalid_battle_code`、`invalid_battle` 错误码表。
- 验收标准：实现者只读现行文档，就能唯一确定回合节点触发范围、行动失败语义、持续时间扣减起算、`rule_mod` 应用顺序与日志事件类型。

#### 已完成内容
- 写死回合节点触发范围：仅在场单位与 field 生效，bench 不参与。
- 收口 `action_failed_post_start`：仅在执行起点判定，后续 payload 目标无效只跳过该 payload。
- 明确 `turns` 持续时间扣减起算点：创建后遇到的第一个对应节点即为首次扣减。
- 补齐 `rule_mod` payload 最小字段与 `RuleModInstance` 运行时模型与应用顺序。
- 日志新增 `event_type` 最小枚举与 `invalid_battle_code` 字段，补齐错误码表。

#### 最小可玩性检查清单（文档基线）
- 可启动：实现者能唯一实现回合节点触发范围、持续时间扣减与 `rule_mod` 应用顺序。
- 可操作：行动失败语义与日志事件类型只有一套口径，不会分叉。
- 无致命错误：不会出现 bench 触发回合节点、`action_failed_post_start` 乱用、field 回合数起算不一致等实现歧义。

#### 回归检查要点
- 模块 04/06 是否一致声明回合节点只对在场单位与 field 生效。
- 模块 02 是否将 `action_failed_post_start` 限定为执行起点判定，并补齐 payload 跳过口径。
- 模块 05/06 是否写死持续时间扣减起算点。
- 模块 06 是否补齐 `rule_mod` payload 字段与运行时应用顺序。
- 模块 05 是否新增 `event_type` 枚举与 `invalid_battle_code` 字段。

### 规则执行契约补齐 + 运行时日志收口（已完成：v0.7.2 文档补丁）
- 目标：把现行文档里还会逼实现者临场拍板的执行契约补齐，并修掉剩余术语漂移。
- 范围：首发 `on_enter / battle_init` 时序、`fainted_pending_leave` 统一命名、持续效果排序继承、行动链日志字段继承、AI 合法列表边界、`on_cast` / payload 顺序、field 扣减节点、技能对接字段收口。
- 验收标准：实现者只读现行文档，就能唯一写出初始化、行动链日志、持续效果排序和 AI 选指令接口，不需要再靠聊天补口径。

#### 已完成内容
- 把战斗开始初始化顺序拆成 `on_enter` 阶段和 `battle_init` 阶段，写死它们之间先后与击倒窗口位置，不再允许跨触发点混排。
- 统一双倒下流程里的状态名，明确当前运行态只使用 `fainted_pending_leave`。
- 为持续效果实例补上 `source_kind_order` 继承规则，避免 `apply_effect` 落地后出现“到底归哪个排序桶”的实现分叉。
- 把行动链日志字段继承规则写清：同一行动链里的衍生效果事件继续沿用根行动的 `action_id / command_type / command_source`。
- 收紧 AI 合法性契约，不再把“空合法列表”丢给 AI；无合法主动方案时由引擎直接生成 `resource_forced_default`。
- 写死技能、奥义、默认动作的执行起点顺序，并补齐 `payloads` 声明顺序、`effects_on_cast / effects_on_hit / effects_on_miss / effects_on_kill` 的精确落点。
- 写明 field 剩余回合固定在 `turn_end` 扣减，并删除主动技能对接字段里多余的 `effects_on_enter` 口子。
- 同步更新 `docs/records/decisions.md`，把本轮新增契约和裁剪原则落盘。

#### 最小可玩性检查清单（文档基线）
- 可启动：实现者能唯一实现战斗初始化、行动链日志、默认动作和持续效果排序。
- 可操作：AI 和玩家端都能围绕同一套合法指令契约工作，不会在“空列表”或自动动作上各做一套逻辑。
- 无致命错误：不会再出现 `on_enter` 和 `battle_init` 混排、双倒状态名不一致、持续效果排序无来源桶、日志字段继承靠猜的分叉。

#### 回归检查要点
- 模块 01 是否已把初始化拆成 `on_enter` 阶段和 `battle_init` 阶段，并写明两者不跨触发点混排。
- 模块 04 是否已只使用 `fainted_pending_leave` 作为运行态名。
- 模块 05 是否已写明持续效果继承根来源类型、AI 不接收空合法列表、行动链日志字段继承规则、field 在 `turn_end` 扣减。
- 模块 06 是否已补齐 `source_kind_order`、`chain_origin`、payload 顺序与技能触发字段时序。
- 模块 03 是否已写明 `on_cast` 在扣 MP 之后、命中之前，以及命中侧 payload 与 `effects_on_hit` 的先后。

### 执行契约收口 + 效果模型再瘦身（已完成：v0.7.1 文档补丁）
- 目标：把上一轮审查里真正会阻断实现的规则口补齐，同时把还能再瘦的保留口继续收紧。
- 范围：行动失败分类、换人/补位选择契约、`HP = 0` 中间态、日志空值与自动来源、首发 `on_enter` / `battle_init` 分工、模块 06 的作用域与 `rule_mod` 约束。
- 验收标准：实现者只看现行文档，就能唯一确定这些关键边界；不会再因为“文档里留太宽”而临场拍板。

#### 已完成内容
- 删除当前基线里没有触发接口支撑的 `action_failed_pre_start`，避免失败分类先于触发模型落地。
- 补齐手动换人、强制换下、强制补位的替补选择规则，写死锁定时机、自动锁定条件与非法运行态处理。
- 为 `HP = 0` 增加 `fainted_pending_leave` 中间态，明确它在击倒窗口前就已失去在场资格，不再接受普通 payload。
- 把超时比较的 HP 占比公式补成唯一口径：倒下单位按 `current_hp = 0` 计入，全队 `max_hp` 总和固定作分母。
- 补齐日志空值策略和自动来源命名：`resource_forced_default / resource_auto`、`timeout_default / timeout_auto`，非适用字段统一写 `null`。
- 拆清首发 `on_enter` 与 `battle_init` 的先后与职责，避免同一份效果双触发。
- 继续收紧模块 06：移除 `scope = side` 的现行保留位，删除 `custom targeting` 的现行保留位，并限制 `rule_mod` 不能改写核心流程。
- 同步更新 `docs/records/decisions.md`，把本轮收口原则落盘。

#### 最小可玩性检查清单（文档基线）
- 可启动：实现者能唯一写出换人、补位、击倒窗口、首发初始化和默认动作日志。
- 可操作：玩家和 AI 都有明确的替补选择入口，不会在补位或强制换下时卡在“到底谁来选”。
- 无致命错误：不会再出现“动作前拦下没有触发点”“倒下单位还能不能吃后续效果”“日志里 null 到底怎么写”这类实现分叉。

#### 回归检查要点
- 模块 02 是否已不存在 `action_failed_pre_start`，且手动换人目标锁定规则已写明。
- 模块 04 是否已写明 `fainted_pending_leave`、强制换下失败口径、强制补位选择权。
- 模块 05 是否已写明 `resource_auto` 与非适用字段统一写 `null`。
- 模块 06 是否已不再保留 `scope = side` 与 `custom targeting` 这类现行宽口。
- 模块 01 的首发初始化与超时比较是否都已有唯一时序和数学口径。

## 2026-03-24

### 极简基线终检 + 玩家一页说明（已完成：v0.7.0 审查补丁）
- 目标：确认“极简基线”在现行文档中已经完整落地，并给玩家提供一眼可懂的玩法说明。
- 范围：全量审查 `docs/rules/` 与 `docs/records/`（排除历史归档），补充玩家速览文档，标注仍保留旧口径的文件边界。
- 验收标准：开发者不会把旧口径误当现行规则；玩家不读实现细节也能看懂怎么打。

#### 已完成内容
- 逐份复查现行规则文档，确认 `priority`、命中、物理/特殊伤害、被动持有物、单全局 field 的口径一致。
- 复查记录文档，确认旧机制口径仅存在于 `docs/records/archive/*` 与退役总表，且都已显式标注“不可直接实现”。
- 在规则目录新增 `docs/rules/player_quick_start.md`，整理玩家一页速览：回合流程、行动先后、命中与伤害、field 与持有物、当前未启用机制。
- 在 `docs/rules/README.md` 补充审查提醒，明确哪些文档是历史追溯用途。

#### 最小可玩性检查清单（文档基线）
- 可启动：实现者只看 `docs/rules/` 就能开始写代码，不需要回头翻历史条目。
- 可操作：玩家只看一页速览就知道每回合要做什么、为什么先后手会这样排。
- 无致命错误：不会再把 archive 或退役总表里的旧口径当成当前实现依据。

#### 回归检查要点
- `docs/rules/player_quick_start.md` 是否与 `00~06` 当前规则一致。
- `docs/rules/README.md` 是否明确标注历史文档边界。
- 现行文档里是否仍不存在旧的多层 priority 命名和已移除机制的“现行条款”。

### 极简战斗基线收口（已完成：v0.7.0 文档冻结）
- 目标：把战斗规则收成最小可玩闭环，为后续属性系统接入打稳定底板。
- 范围：统一 `priority`、保留被动持有物与单全局 field、保留命中与物理/特殊伤害、移除通用状态包、移除暴击/真伤/护盾/闪避、多档可见性、主动道具。
- 验收标准：开发者只读 `docs/rules/` 即可开始实现，不需要再靠聊天补规则。

#### 已完成内容
- 把总则改为“极简闭环优先”，并清掉旧的复杂机制定位。
- 只保留 `prototype_full_open` 一个可见性模式。
- `priority` 收敛成唯一数轴：`-5 ~ +5`，数值越大越先。
- 写死行动侧取值：绝对先手奥义 `+5`，换人 `+4`，普通技能 `-2 ~ +2`，绝对后手奥义 `-5`。
- 标准模式只保留被动持有物，不再存在主动使用持有物指令。
- field 改为“全场唯一实例”，由技能描述决定具体效果。
- 命中率只看技能自身 `accuracy`，移除闪避相关全部口径。
- 伤害改为官方骨架简化版，并保留物理 / 特殊双轨。
- 当前基线移除通用状态包、暴击、真伤、护盾、属性克制、同属性加成。
- AI 改为从引擎提供的合法指令列表中选指令。
- 日志字段同步删去 `crit_roll`、`damage_roll` 等已移除机制。

#### 最小可玩性检查清单（文档基线）
- 可启动：按文档可以从开战一路走到胜负结算。
- 可操作：玩家能完成选技能、换人、奥义、击倒补位这一整轮循环。
- 无致命错误：不会再出现“到底该看哪套 priority”“有没有闪避”“护盾先不先扣”这种口径分叉。

#### 回归检查要点
- 文档里是否已经不存在 `absolute_order / action_priority / skill_priority` 这类旧排序口径。
- 文档里是否已经不存在暴击、真伤、护盾、闪避率、通用状态包的现行条款。
- 标准模式下是否只保留 `prototype_full_open`。
- field 是否被统一写成“全场最多 1 个”。
- 被动持有物是否始终被描述成装备，不是行动指令。
- AI 是否明确是“合法列表内选择”，不是反复试错。

### 文档口径冲突收口（已完成：v0.7.0 一致性补丁）
- 目标：在不增加机制的前提下，把现行文档里的冲突项和松口项全部收紧到极简基线。
- 范围：持续效果持续模型、`turn_start` MP 回复与 field/rule_mod 时序、超时默认动作命名、`source_instance_id` 的排序与日志口径。
- 验收标准：开发者不会再因为这些条目写出两套实现；现行文档里只保留一套最小规则。

#### 已完成内容
- 把持续效果持续模型统一收紧为“按回合 / 永久”两种，移除“按触发次数”这类未落地模型口子。
- 写死 `turn_start` MP 回复读取“本回合开始前已生效状态”，同节点新触发的 field / effect / rule_mod 不回头改写本次回复。
- 把超时默认动作命名统一为 `command_type = timeout_default`、`command_source = timeout_auto`。
- 补齐 `source_instance_id` 的最小生成口径，并要求进入完整日志。
- 明确模块 06 是“当前最小效果框架 + 扩展纪律”，不是首版一次性全做完的清单。

#### 最小可玩性检查清单（文档基线）
- 可启动：实现者只看现行规则，就能唯一确定持续效果和 MP 回复时序。
- 可操作：超时默认动作、field 替换、效果排序都只有一套日志命名和触发源口径。
- 无致命错误：不会再出现“这个 field 到底算不算本回合回复”“timeout 到底写哪种名字”“持续效果能不能按次数扣”这类文档分叉。

#### 回归检查要点
- `duration_mode` 是否仍只允许 `turns / permanent`。
- 模块 04 与模块 06 对持续时间描述是否一致。
- `turn_start` MP 回复是否只读取本回合开始前已经生效的状态。
- `timeout_default / timeout_auto` 是否已替代 `timeout_auto_action`。
- `source_instance_id` 是否同时出现在排序口径与完整日志口径里。

### 未用触发点清理（已完成：v0.7.0 极简触发点补丁）
- 目标：删掉当前基线没落地需求的触发点，避免效果系统文档看起来比真实目标更重。
- 范围：模块 06 的当前基线触发点表、技能对接字段说明、对应决策记录。
- 验收标准：现行文档里，技能字段和触发点表一一对应；不再保留当前没使用的触发点名字。

#### 已完成内容
- 从当前基线触发点中移除 `on_action_attempt / before_action / after_action / on_resource_change`。
- 新增并明确使用 `on_cast`，与 `effects_on_cast` 直接对应。
- 把“只保留当前最小触发点集合”同步写入决策记录。

#### 最小可玩性检查清单（文档基线）
- 可启动：实现者只需支持当前最小触发点集合，就能覆盖现行技能、换人、倒下和回合节点。
- 可操作：技能侧 `effects_on_cast / effects_on_hit / effects_on_miss` 都能找到唯一对应触发点。
- 无致命错误：不会再出现“字段叫 cast、触发点却没有 cast”这种文档自相矛盾。

#### 回归检查要点
- 模块 06 的触发点表里是否已不存在 `on_action_attempt / before_action / after_action / on_resource_change`。
- `effects_on_cast` 是否已明确对应 `on_cast`。

### 极简基线审查与历史文档防误读（已完成：v0.7.0 审查补丁）
- 目标：确认当前极简基线已经自洽，同时把仍然保留旧口径的历史文档明确标成“只能追溯，不能实现”。
- 范围：`docs/rules/README.md`、退役总表、`docs/records/archive/` 抬头警告、决策记录补充。
- 验收标准：开发者全局搜规则时，不会把 archive 里的旧机制误当成当前生效规则。

#### 已完成内容
- 复查现行 `docs/rules/`，确认极简基线仍以 `prototype_full_open + 被动持有物 + 单全局 field + 统一 priority + 简化命中与伤害` 为唯一口径。
- 为 `docs/records/archive/` 两个历史文件补上“含已废弃口径，不得直接实现”的显式提醒。
- 为退役总表补上“命中这里不能直接实现”的警告。
- 在规则导航中新增“全局搜索默认排除 archive”的使用约束。
- 在决策记录中补充“历史文档保留但必须显式防误读”的约束。

#### 最小可玩性检查清单（文档基线）
- 可启动：新开发者只看 `docs/rules/` 就能开始实现，不会被 archive 带偏。
- 可操作：全局搜索 `priority / field / 状态 / 暴击` 这类词时，能一眼分清现行规则和历史归档。
- 无致命错误：不会再出现“旧文档里写过，所以现在也算数”的误读。

#### 回归检查要点
- `docs/rules/README.md` 是否明确要求全局搜索时排除 `docs/records/archive/`。
- `docs/records/archive/` 的文件头是否明确标注“历史归档，不能直接实现”。
- 退役总表是否已明确声明“只读 `docs/rules/`，不要据此实现”。
