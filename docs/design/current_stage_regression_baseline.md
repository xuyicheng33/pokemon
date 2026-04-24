# 当前阶段回归基线

本文件只记录当前推荐复查命令、当前主 smoke matchup 和最小可玩性检查，不保留历史长流水。

## 1. 推荐复查命令

1. `TEST_PATH=res://test/suites/manual_battle_scene/manual_flow_suite.gd bash tests/run_gdunit.sh`
2. `TEST_PATH=res://test/suites/manual_battle_scene/demo_replay_suite.gd bash tests/run_gdunit.sh`
3. `TEST_PATH=res://test/suites/battle_sandbox_launch_config_contract_suite.gd bash tests/run_gdunit.sh`
4. `bash tests/check_boot_smoke.sh`
5. `bash tests/check_sandbox_smoke_matrix.sh`
6. `bash tests/run_with_gate.sh`

## 2. 当前主 smoke matchup

- 默认主路径：`gojo_vs_sample + 9101 + manual/policy`
- 可见 matchup 变体：`tests/check_sandbox_smoke_matrix.sh` 默认 `SANDBOX_SMOKE_SCOPE=quick`，动态覆盖推荐 matchup 与所有 `<pair>_vs_sample` 主路径的 `manual/policy`
- 全量 matchup 变体：`SANDBOX_SMOKE_SCOPE=full bash tests/check_sandbox_smoke_matrix.sh` 覆盖当前全部非 `test_only` matchup 的 `manual/policy`
- 默认模式变体：默认可见 matchup 额外覆盖 `policy/policy` 与 `manual/manual`
- submit 命令入口变体：默认可见 matchup 额外覆盖 `tests/helpers/manual_battle_submit_full_run.gd`
- demo 变体：动态覆盖 `config/demo_replay_catalog.json` 中全部 demo profile
- headless 统一入口：`godot --headless --path . --script tests/helpers/manual_battle_full_run.gd`
- submit 入口：`godot --headless --path . --script tests/helpers/manual_battle_submit_full_run.gd`
- demo replay 入口：`DEMO_PROFILE=legacy godot --headless --path . --script tests/helpers/demo_replay_full_run.gd`

## 3. 最小可玩性检查

- 可启动：`BattleSandbox` 能进入主流程，`bash tests/run_with_gate.sh` 与 `bash tests/check_boot_smoke.sh` 不报阻断错误
- 可操作：默认 `manual/policy` 路径能完成至少一轮人工选指与 policy 自动推进
- 能跑完一局：动态 smoke matrix 覆盖的主路径都能稳定打到终局
- 无阻断报错：不得出现 `BATTLE_SANDBOX_FAILED:`、`SCRIPT ERROR:`、`Compile Error:`、`Parse Error:`
- 统一终局摘要：`manual_battle_full_run.gd` 固定输出同一套 `battle_summary` JSON
