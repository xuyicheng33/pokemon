# 固定领域案例

本目录不再只是占位。当前保留一组固定领域案例，用于在 batch probe 统计异常时快速复查具体局面。

运行方式：

```bash
CASE=all godot --headless --path . --script tests/helpers/domain_case_runner.gd
```

可选 `CASE`：

- `gojo_domain_success`
- `sukuna_domain_break`
- `tied_domain_clash`
- `normal_field_blocked_by_domain`
- `same_turn_dual_domain_clash`

当前每个案例都会打印结构化结果，用于快速确认：

- 当前 field 是否按预期存在或消失
- 领域相关增幅是否被正确回收
- `field_clash` / `field_blocked` 是否写出
- 同回合同步开领域时，对手领域动作是否被误取消

这些案例是固定诊断入口，不替代 `tests/suites/*` 的正式断言，也不替代 batch probe 的胜率统计。
