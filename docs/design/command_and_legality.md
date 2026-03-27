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
|`turn_index`|`int`|该指令所属回合号|
|`command_type`|`String`|`skill / switch / ultimate / wait / resource_forced_default / surrender`|
|`command_source`|`String`|`manual / ai / resource_auto / timeout_auto`|
|`side_id`|`String`|下达指令的 side|
|`actor_id`|`String`|行动者运行时 `unit_instance_id`|
|`actor_public_id`|`String`|行动者公开 ID（回放/外层输入推荐使用）|
|`skill_id`|`String`|技能或奥义 ID，非适用为 `""`|
|`target_unit_id`|`String`|换人目标的运行时 `unit_instance_id`，非适用为 `""`|
|`target_public_id`|`String`|目标公开 ID（外层输入可用），非适用为 `""`|
|`target_slot`|`String`|目标槽位，非适用为 `""`|

### 2.2 LegalActionSet

|字段|类型|说明|
|---|---|---|
|`actor_id`|`String`|当前行动者|
|`legal_skill_ids`|`PackedStringArray`|可用技能|
|`legal_switch_target_ids`|`PackedStringArray`|可换人列表|
|`legal_ultimate_ids`|`PackedStringArray`|可用奥义|
|`wait_allowed`|`bool`|当前是否允许主动选择 `wait`|
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
  - 计算所有合法主动方案，并区分“MP 不足”与“非 MP 阻断”。
  - 当存在合法主动方案或存在非 MP 阻断时，允许 `wait`。
  - 仅在“无合法主动方案且全部仅因 MP 不足”时给出 `forced_command_type`。
- `CommandBuilder`
  - 只做结构化，不做规则判断。
- `CommandValidator`
  - 负责硬非法拦截。
  - 失败直接 fail-fast：选择阶段立即 `invalid_battle`，不保留“拦截后重选”语义。

## 4. 校验规则

- MP 不足、目标不合法、奥义入口非法、提交内容不在 legal 集：选择阶段按 `invalid_command_payload` 直接 `invalid_battle`。
- `wait` 允许手动提交；超时自动替代时固定 `command_source = timeout_auto`。
- `resource_forced_default` 只能由合法性服务产出，不接受外部伪造。
- `surrender` 立即结束，不进入行动队列。
- 外层输入与回放默认优先提交 `actor_public_id / target_public_id`；`CommandValidator` 在选择阶段统一映射到运行时 `actor_id / target_unit_id`。

## 5. 非目标

- 本轮不实现 AI 选指令策略。
- 本轮不实现网络输入同步。
