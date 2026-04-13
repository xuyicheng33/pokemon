# 当前阶段回归基线

本文件只记录当前推荐复查命令、当前主 smoke matchup 和最小可玩性检查，不保留历史长流水。

## 1. 推荐复查命令

1. `TEST_PATH=res://test/suites/manual_battle_scene_suite.gd bash tests/run_gdunit.sh`
2. `TEST_PATH=res://test/suites/battle_sandbox_launch_config_contract_suite.gd bash tests/run_gdunit.sh`
3. `bash tests/check_sandbox_smoke_matrix.sh`
4. `bash tests/run_with_gate.sh`

## 2. 当前主 smoke matchup

- 默认主路径：`gojo_vs_sample + 9101 + manual/policy`
- 变体一：`kashimo_vs_sample + manual/policy`
- 变体二：`gojo_vs_sample + policy/policy`
- headless 统一入口：`godot --headless --path . --script tests/helpers/manual_battle_full_run.gd`

## 3. 最小可玩性检查

- 可启动：`BattleSandbox` 能进入主流程，`bash tests/run_with_gate.sh` 与 `godot --headless --path . --quit-after 20` 不报阻断错误
- 可操作：默认 `manual/policy` 路径能完成至少一轮人工选指与 policy 自动推进
- 能跑完一局：三条主 smoke 路径都能稳定打到终局
- 无阻断报错：不得出现 `BATTLE_SANDBOX_FAILED:`、`SCRIPT ERROR:`、`Compile Error:`、`Parse Error:`
- 统一终局摘要：`manual_battle_full_run.gd` 固定输出同一套 `battle_summary` JSON
