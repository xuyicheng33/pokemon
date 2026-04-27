# 固定 Obito 案例

本文件记录与 Obito 阴阳遁防反相关的固定诊断入口，与 `domain_cases.md` / `kashimo_cases.md` 形态一致。Batch J 把它接入 `tests/check_sandbox_smoke_matrix.sh` 的 `replay_cases_runner` 段，让 quick gate 在 Obito 阴阳遁逐段防反契约漂移时立即报红。

运行方式：

```bash
CASE=all godot --headless --path . --script tests/helpers/obito_case_runner.gd
```

可选 `CASE`：

- `yinyang_dun_segment_guard` — Obito `obito_yinyang_dun` 后吃下敌方 2 段 multihit skill：每段补 1 层阴阳之力（cast 期 1 层 + 2 段命中 = 3 层），同时受到的伤害走 `incoming_action_final_mod ×0.5` 减伤；与 baseline（不开阴阳遁）对比 hp_loss 严格更小。

每个案例会打印结构化结果，用于快速确认：

- `hp_loss_baseline` / `hp_loss_guarded`：减伤对比，guarded 必须更小
- `yinyang_count`：阴阳之力层数（cast 1 + 段数）
- `defense_stage` / `sp_defense_stage`：阴阳遁附带 +1/+1 是否生效
- `log_size`：本回合事件日志规模

这些案例是固定诊断入口，不替代 `test/suites/obito_runtime_yinyang_suite.gd` 的 `gdUnit4` 正式断言；该 runner 与 yinyang_suite 共享 `tests/support/obito_test_support.gd` 的 setup helper，但作为独立 SceneTree 入口存在，便于 sandbox smoke matrix 在不启动 gdUnit4 的情况下快速验证 deterministic 行为。
