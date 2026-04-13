# 当前研发工作流

本文件定义当前原型期的日常研发入口、允许改动边界，以及文档更新顺序。规则权威仍以 `docs/rules/` 为准；这里不重复写玩法规则，只收口“现在该怎么开发”。

## 1. 文档治理基线

- `docs/rules/` 只承载当前生效的规则权威。
- `docs/design/` 只承载工程结构、测试矩阵、Sandbox 使用方式、开发工作流和治理规则。
- `docs/records/` 只承载活跃任务、活跃决策、阶段审查记录和归档索引。
- 若 `docs/records/` 的历史说法与 `docs/rules/`、`docs/design/` 冲突，以后两者为准；记录文件不再补写“现行真相正文”。

## 2. 代码分层与允许改动边界

当前代码改动边界按下面理解：

|层级|路径|当前职责|允许改动|不允许直接做的事|
|---|---|---|---|---|
|规则权威|`docs/rules/`|玩法规则、字段语义、流程口径|新规则、规则修订|跳过文档直接改 battle core 语义|
|工程设计|`docs/design/`|结构、接线、测试矩阵、Sandbox 路径、治理规则|新增入口、拆 owner、改测试组织|把规则正文写回 records|
|核心引擎|`src/battle_core/`|运行态、合同、回合编排、执行与日志|只在规则/合同已更新后改实现|外围层绕过 facade 直接改 runtime|
|外围装配|`src/composition/`|服务装配、SampleBattleFactory、导出/复查入口接线|拆 helper、收口 descriptor、维护入口|引入 battle core 新语义分支|
|外围适配|`src/adapters/`|BattleSandbox、UI、输入适配、sandbox-local policy|改试玩入口、重构 controller、view/policy/session 协作|修改 battle core contract 语义|
|场景与测试|`scenes/`、`test/`、`tests/`|试玩场景、gdUnit suite、gate、helper|补 smoke、补 contract、拆 support|把历史 wrapper 再变成正式入口|

当前这一轮默认只动外围层、测试治理层和文档治理层；`BattleCoreManager` 合同、replay 语义、formal manifest / capability catalog / content schema 都继续视为稳定边界。

## 3. Sandbox 日常试玩路径

`BattleSandbox` 是当前主试玩入口。

日常本地路径固定为：

1. `godot --path .`
2. 默认进入 `scenes/sandbox/BattleSandbox.tscn`
3. 当前 launch config 基线为 `gojo_vs_sample + 9101 + manual/policy`
4. HUD 上只通过 `matchup / battle_seed / P1 mode / P2 mode` 重开，不走历史 wrapper 或旧 runner；`manual/manual` 与 `policy/policy` 只作为显式模式保留

headless 复查入口固定为：

- `godot --headless --path . --script tests/helpers/manual_battle_full_run.gd`
- `MATCHUP_ID=kashimo_vs_sample P1_MODE=manual P2_MODE=policy godot --headless --path . --script tests/helpers/manual_battle_full_run.gd`
- `P1_MODE=policy P2_MODE=policy godot --headless --path . --script tests/helpers/manual_battle_full_run.gd`

`manual_battle_full_run.gd` 当前统一输出稳定的 `battle_summary` JSON，固定字段至少包含 `matchup_id / battle_seed / p1_control_mode / p2_control_mode / winner_side_id / reason / result_type / turn_index / event_log_cursor / command_steps`。

若只是复查旧 demo replay，继续显式走 `demo=<profile>` CLI 路径；这条线不再算当前 HUD 的主流程。

## 4. 测试入口与推荐跑法

- `tests/run_with_gate.sh` 是唯一总入口。
- `gdUnit4 + test/` 是唯一 Godot 业务测试树。
- `tests/run_gdunit.sh` 只作为 `gdUnit4` CLI 快跑入口，不替代总 gate。

推荐顺序：

1. 快速改单点：`TEST_PATH=res://test/suites/<suite>.gd bash tests/run_gdunit.sh`
2. 复查 BattleSandbox：运行 `manual_battle_full_run.gd` 的三条主路径
3. 阶段收口：`bash tests/run_with_gate.sh`

当前总 gate 内部顺序以 `tests/run_with_gate.sh` 为准；新增日常 smoke 或 contract 时，先写到 `docs/design/`，再进 gate，再接到总入口。

## 5. 文档更新顺序与记录要求

涉及规则、结构、测试或入口变动时，统一按这个顺序更新：

1. 若改 battle 规则、字段语义或玩法流程，先改 `docs/rules/`
2. 再改 `docs/design/`，写清结构落点、入口、测试矩阵和治理规则
3. 再补 gate / suite / helper
4. 最后再改调用面与实现
5. 完成阶段后更新 `docs/records/tasks.md`
6. 若形成新的长期边界、默认入口或治理规则，再更新 `docs/records/decisions.md`

记录要求固定为：

- 活跃任务写入 `docs/records/tasks.md`
- 关键决定写入 `docs/records/decisions.md`
- 历史长流水继续放在 `docs/records/archive/`
- 聊天内容不算正式记录
