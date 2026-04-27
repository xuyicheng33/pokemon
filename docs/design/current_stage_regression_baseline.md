# 当前阶段回归基线

本文件只记录当前推荐复查命令、当前主 smoke matchup 和最小可玩性检查，不保留历史长流水。

## 1. 推荐复查命令

1. `TEST_PATH=res://test/suites/manual_battle_scene/manual_flow_suite.gd bash tests/run_gdunit.sh`
2. `TEST_PATH=res://test/suites/manual_battle_scene/demo_replay_suite.gd bash tests/run_gdunit.sh`
3. `TEST_PATH=res://test/suites/battle_sandbox_launch_config_contract_suite.gd bash tests/run_gdunit.sh`
4. `bash tests/check_boot_smoke.sh`
5. `bash tests/check_sandbox_smoke_matrix.sh`
6. `bash tests/run_with_gate.sh`
7. `bash tests/run_extended_gate.sh`
8. `TEST_PROFILE=full bash tests/run_with_gate.sh`

## 2. 当前主 smoke matchup

- 默认主路径：`gojo_vs_sample + 9101 + manual/policy`
- quick scope（`tests/check_sandbox_smoke_matrix.sh` 默认 `SANDBOX_SMOKE_SCOPE=quick`）：每个 formal 角色 1 条 quick anchor matchup × `manual/policy`（由 `FormalCharacterManifest` 自动派生 `formal_setup_matchup_id`）+ 默认 demo profile 的 demo replay
- extended scope（`SANDBOX_SMOKE_SCOPE=extended bash tests/check_sandbox_smoke_matrix.sh`，由 `tests/run_extended_gate.sh` 在 quick 后自动调用）：quick 之外的余量——推荐 matchup 与其余 visible matchup 的 `manual/policy` + 默认 matchup 的 `policy/policy`、`manual/manual` + 其余 demo profile 的 demo replay
- full scope（`SANDBOX_SMOKE_SCOPE=full bash tests/check_sandbox_smoke_matrix.sh` 或 `TEST_PROFILE=full bash tests/run_with_gate.sh`）：全集 superset，覆盖全部 visible matchup × 全控制模式 + 全 demo profile
- quick 与 extended 在单 profile 层面互补；`tests/run_extended_gate.sh` 串起 quick + extended，`full` 是独立执行的全集
- headless 统一入口：`godot --headless --path . --script tests/helpers/manual_battle_full_run.gd`（直接通过 `BattleSandboxController.submit_action()` 推进整局）
- demo replay 入口：`DEMO_PROFILE=legacy godot --headless --path . --script tests/helpers/demo_replay_full_run.gd`

## 3. 最小可玩性检查

- 可启动：`BattleSandbox` 能进入主流程，`bash tests/run_with_gate.sh`、`bash tests/run_extended_gate.sh` 与 `bash tests/check_boot_smoke.sh` 不报阻断错误
- 可操作：默认 `manual/policy` 路径能完成至少一轮人工选指与 policy 自动推进
- 能跑完一局：动态 smoke matrix 覆盖的主路径都能稳定打到终局
- 无阻断报错：不得出现 `BATTLE_SANDBOX_FAILED:`、`SCRIPT ERROR:`、`Compile Error:`、`Parse Error:`
- 统一终局摘要：`manual_battle_full_run.gd` 固定输出同一套 `battle_summary` JSON
