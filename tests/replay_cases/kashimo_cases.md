# 固定鹿紫云案例

本目录补一组鹿紫云专属固定案例，用来快速复查主循环、换人保留和弥虚葛笼对抗领域必中。

运行方式：

```bash
CASE=all godot --headless --path . --script tests/helpers/kashimo_case_runner.gd
```

可选 `CASE`：

- `charge_loop`
- `amber_switch_retention`
- `kyokyo_vs_domain`

当前每个案例都会打印结构化结果，用于快速确认：

- `charge_loop`：雷拳挂负电荷、蓄电叠正电荷、回授电击清空双方电荷
- `amber_switch_retention`：幻兽琥珀的强化、自伤暂停与奥义封锁跨换人保留
- `kyokyo_vs_domain`：弥虚葛笼在领域必中覆盖下恢复原始命中，而不是继续吃 `creator_accuracy_override`

这些案例是固定诊断入口，不替代 `tests/suites/*` 的正式断言。
