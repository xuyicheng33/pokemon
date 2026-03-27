# Tests Skeleton

本目录承载当前业务回归闸门与测试支撑脚手架。

- `suites/`: 业务回归测试套件
- `support/`: 测试 harness 与公共构造器
- `run_all.gd`: Godot 原生测试入口（业务断言）
- `run_with_gate.sh`: 闸门脚本（业务断言 + 引擎错误日志）
- `check_architecture_constraints.sh`: 分层与大文件架构闸门
- `fixtures/`: 预留的样例输入与内容快照目录
- `helpers/`: 预留的测试辅助脚本目录
- `replay_cases/`: 预留的回放案例说明目录
