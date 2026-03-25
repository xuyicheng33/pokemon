# Command & Legality（指令与合法性）

本文件定义选择阶段 contract，目标是让玩家输入、AI 输入和引擎默认动作共用同一套结构。

## 1. 文件清单

|文件|职责|
|---|---|
|`command_builder.gd`|把外部输入组装成 `Command`|
|`command_validator.gd`|校验 `Command` 是否满足当前规则|
|`legal_action_service.gd`|产出 `LegalActionSet`|
|`command_types.gd`|集中定义行动类型常量|

## 2. Contract

### 2.1 Command

|字段|类型|说明|
|---|---|---|
|`command_id`|`String`|唯一 ID|
|`command_type`|`String`|`skill / switch / ultimate / resource_forced_default / timeout_default / surrender`|
|`command_source`|`String`|`manual / ai / resource_auto / timeout_auto`|
|`side_id`|`String`|下达指令的 side|
|`actor_id`|`String`|行动者实例 ID|
|`skill_id`|`String`|技能或奥义 ID，非适用为 `""`|
|`target_unit_id`|`String`|换人目标，非适用为 `""`|

### 2.2 LegalActionSet

|字段|类型|说明|
|---|---|---|
|`actor_id`|`String`|当前行动者|
|`legal_skill_ids`|`PackedStringArray`|可用技能|
|`legal_switch_target_ids`|`PackedStringArray`|可换人列表|
|`legal_ultimate_ids`|`PackedStringArray`|可用奥义|
|`forced_command_type`|`String`|无主动方案时写 `resource_forced_default`，否则为空串|

### 2.3 SelectionState

|字段|类型|说明|
|---|---|---|
|`selected_command`|`Command` 或 `null`|当前已锁定指令|
|`selection_locked`|`bool`|是否已锁定|
|`timed_out`|`bool`|是否超时自动选择|

## 3. 责任边界

- `LegalActionService`
  - 读取运行态与内容定义。
  - 计算所有合法主动方案。
  - 若技能、奥义、手动换人都为空，直接给出 `forced_command_type`。
- `CommandBuilder`
  - 只做结构化，不做规则判断。
- `CommandValidator`
  - 负责硬非法拦截。
  - 失败直接 fail-fast：选择阶段立即 `invalid_battle`，不保留“拦截后重选”语义。

## 4. 校验规则

- MP 不足、目标不合法、奥义入口非法、提交内容不在 legal 集：选择阶段按 `invalid_command_payload` 直接 `invalid_battle`。
- `timeout_default` 只能由回合控制器自动生成。
- `resource_forced_default` 只能由合法性服务产出，不接受外部伪造。
- `surrender` 立即结束，不进入行动队列。

## 5. 非目标

- 本轮不实现 AI 选指令策略。
- 本轮不实现网络输入同步。
