# Tests Skeleton

本目录预留 deterministic / replay 测试脚手架。

- `fixtures/`: 样例输入与内容快照
- `helpers/`: 测试辅助脚本
- `replay_cases/`: 回放案例说明
- `run_all.gd`: Godot 原生测试入口（业务断言）
- `run_with_gate.sh`: 闸门脚本（业务断言 + 引擎错误日志）
