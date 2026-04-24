# 当前研发工作流

本文件定义当前的日常研发入口、允许改动边界，以及文档更新顺序。规则权威仍以 `docs/rules/` 为准；这里不重复写玩法规则，只收口“现在该怎么开发”。

## 1. 文档治理基线

- `docs/rules/` 只承载当前生效的规则权威。
- `docs/design/` 只承载工程结构、测试矩阵、Sandbox 使用方式、开发工作流和治理规则。
- `docs/records/` 只承载活跃任务、活跃决策、阶段审查记录和归档索引。
- `README.md` 与 `tests/README.md` 只承担入口与操作说明，不再镜像 formal 字段清单或长段 contract 正文。
- 若 `docs/records/` 的历史说法与 `docs/rules/`、`docs/design/` 冲突，以后两者为准；记录文件不再补写“现行真相正文”。

当前文档真相固定为：

- 哪些文档是规范源：
  - `docs/rules/`：玩法规则、字段语义、流程口径
  - `docs/design/`：结构、接线、测试矩阵、Sandbox 与交付工作流
  - `docs/records/`：阶段任务、长期决定、审查处置与 archive 索引
- 哪些文档只是入口说明：
  - `README.md`
  - `tests/README.md`
- 哪些产物是生成物：
  - `config/formal_character_manifest.json`
  - `config/formal_character_capability_catalog.json`
- 哪些文件必须纳入版本管理：
  - 所有有效 `.gd.uid`
- 哪些 gate 主要校验结构：
  - `repo_consistency_formal_character_gate.py`
  - `architecture_composition_consistency_gate.py`
  - `architecture_wiring_graph_gate.py`
  - `repo_consistency_uid_gate.py`
  - `architecture_gdscript_style_gate.py`
- 哪些 gate 不再负责措辞镜像：
  - docs gate 不再要求 `README / tests README / design` 三处重复维护同一 formal 字段正文

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

当前波次为长期工程化重构，允许动 composition 主链路、错误体系、类型标注和测试治理层；但 `BattleCoreManager` 外部 envelope 合同、replay 语义、formal manifest / capability catalog / content schema 继续视为稳定边界。详见 `docs/records/tasks.md` 阶段计划。

## 3. Sandbox 日常试玩路径

`BattleSandbox` 是当前主试玩入口。

日常本地路径固定为：

1. `godot --path .`
2. 默认进入 `scenes/sandbox/BattleSandbox.tscn`
3. 当前 launch config 基线为 `gojo_vs_sample + 9101 + manual/policy`
4. HUD 上只通过 `matchup / battle_seed / P1 mode / P2 mode` 重开，不走历史 wrapper 或旧 runner；`manual/manual` 与 `policy/policy` 只作为显式模式保留
5. 可见 matchup 的推荐顺序从 formal manifest 的 `formal_setup_matchup_id` 派生，新增正式角色不再手工维护 sandbox 推荐名单

headless 复查入口固定为：

- `godot --headless --path . --script tests/helpers/manual_battle_full_run.gd`
- `godot --headless --path . --script tests/helpers/manual_battle_submit_full_run.gd`
- `MATCHUP_ID=kashimo_vs_sample P1_MODE=manual P2_MODE=policy godot --headless --path . --script tests/helpers/manual_battle_full_run.gd`
- `P1_MODE=policy P2_MODE=policy godot --headless --path . --script tests/helpers/manual_battle_full_run.gd`

`manual_battle_full_run.gd` 当前统一输出稳定的 `battle_summary` JSON，固定字段至少包含 `matchup_id / battle_seed / p1_control_mode / p2_control_mode / winner_side_id / reason / result_type / turn_index / event_log_cursor / command_steps`。`manual_battle_submit_full_run.gd` 继续复用同一份摘要契约，作为 submit 链路的显式命令入口；当前两者都通过 `BattleSandboxController.submit_action()` 推进。

若要复查 demo replay，继续显式走 `demo=<profile>` CLI 路径；`BattleSandbox` 会进入只读回放浏览态，固定展示 `turn_timeline`，并只允许用“上一回合 / 下一回合”浏览 frame。

## 4. 测试入口与推荐跑法

- `tests/run_with_gate.sh` 是唯一总入口。
- `gdUnit4 + test/` 是唯一 Godot 业务测试树。
- `tests/run_gdunit.sh` 只作为 `gdUnit4` CLI 快跑入口，不替代总 gate。
- `tests/check_gdunit_gate.sh` 与 `tests/check_boot_smoke.sh` 是总 gate / CI 共享的子入口。
- 当前阶段回归基线文档固定为 `docs/design/current_stage_regression_baseline.md`。

推荐顺序：

1. 快速改单点：`TEST_PATH=res://test/suites/<suite>.gd bash tests/run_gdunit.sh`
2. 复查 launch-config 与推荐排序：`TEST_PATH=res://test/suites/battle_sandbox_launch_config_contract_suite.gd bash tests/run_gdunit.sh`
3. 复查 BattleSandbox boot：运行 `bash tests/check_boot_smoke.sh`
4. 复查 BattleSandbox 主路径：运行 `bash tests/check_sandbox_smoke_matrix.sh`
5. 阶段收口：`bash tests/run_with_gate.sh`
6. 需要清本地旧报告或 scratch 目录时：运行 `bash tests/cleanup_local_artifacts.sh`

当前总 gate 内部顺序固定为：`gdUnit4 -> boot smoke -> suite reachability -> architecture constraints -> repo consistency -> sandbox smoke matrix`。新增日常 smoke 或 contract 时，先写到 `docs/design/`，再进 gate，再接到总入口。

CI 当前固定拆成 3 个并行 job：

- `gdunit`
- `repo_and_arch_gates`
- `boot_and_sandbox_smoke`

测试分类口径固定为：

- `sandbox`：BattleSandbox 场景、launch-config、试玩主路径
- `characters/<role>`：角色私有 runtime / snapshot / smoke
- `engine_core`：回合、行动、生命周期、内容快照与核心合同
- `extensions`：payload、rule_mod、targeting、shared extension
- `manager_contract`：manager facade、公开快照、事件日志、session guard
- `replay`：replay input / summary / determinism / 浏览回归

继续沿用“顶层 wrapper + 子目录断言本体”的组织方式；对外稳定引用的顶层 wrapper 文件名不改。

本地产物与仓库卫生固定约束：

- `tests/run_gdunit.sh` 的默认 HTML/JUnit 输出目录继续只认 `reports/gdunit`
- `reports/gdunit_compose`、`reports/gdunit_gojo_smoke`、`reports/gdunit_manual`、`reports/gdunit_smoke` 视为废弃本地产物，不再作为任何现行入口
- `tmp/`、`.tmp/` 只允许作为本地临时目录存在，不保留到仓库
- `.gd.uid` 不再忽略；有效 `.gd.uid` 必须随同对应 `.gd` 一起提交，孤儿 `.gd.uid` 必须删除
- GDScript 前导缩进固定只允许 tab，不接受 space-only 或 tab/space 混用

## 5. formal 产物同步入口

formal 单源继续固定为 `config/formal_character_sources/`。
人工改动 source descriptor 后，只允许通过下面这条入口同步生成产物：

草稿晋升前先检查：

```bash
bash scripts/check_formal_character_draft_ready.sh
```

正式同步：

```bash
bash tests/sync_formal_registry.sh
```

同步结果固定回写：

- `config/formal_character_manifest.json`
- `config/formal_character_capability_catalog.json`

日常要求：

- 不手改这两份生成产物
- source 改了就先同步，再跑 formal gate
- gate 报 source / 产物漂移时，先重新执行同步入口

## 6. 文档更新顺序与记录要求

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
