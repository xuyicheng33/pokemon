# 正式角色共享能力目录

本文件只定义共享能力目录的职责、字段和接入方式，不复制具体角色条目。当前开放入口的单一真相固定在 `config/formal_character_capability_catalog.json`。

## 1. 目标

- 把“多个正式角色正在复用的共享机制”收成单一登记面。
- 在角色接入时明确：规则归属文档、当前消费者、必挂回归、以及什么时候不该继续给共享入口加能力。
- 阻断“先在角色稿或 suite 里偷偷扩规则，后面再补目录”的做法。

## 2. 单一真相

- 角色级声明：`config/formal_character_manifest.json.characters[*].shared_capability_ids`
- 共享能力目录：`config/formal_character_capability_catalog.json`
- 角色接入模板：`docs/design/formal_character_delivery_checklist.md`
- 角色稿引用方式：`docs/design/formal_character_design_template.md`

共享能力目录不是另一个角色注册表，它只描述“哪些共享入口允许继续复用，以及它们现在由谁在用”。

## 3. catalog entry 合同

每个 capability entry 固定包含：

- `capability_id`
- `rule_doc_paths`
- `consumer_character_ids`
- `required_suite_paths`
- `coverage_needles`
- `stop_and_specialize_when`

字段语义：

- `capability_id`：共享入口正式 ID；manifest 的 `shared_capability_ids` 只能引用这里已有的值。
- `rule_doc_paths`：这项能力的规则归属文档；角色稿只写“怎么用”，共享规则本体回到这些文档。
- `consumer_character_ids`：当前实际消费该能力的正式角色 ID，必须和 manifest 双向一致。
- `required_suite_paths`：只要角色声明消费该能力，就必须把这些共享 suite 挂回自己的 `required_suite_paths`。
- `coverage_needles`：repo consistency gate 用来反查角色内容、validator、设计稿、调整记录或 wrapper 是否真的在用这项能力。
- `stop_and_specialize_when`：扩权止损线；一旦新需求越过这条线，就停止继续给共享入口堆规则，改做专用机制。

## 4. 角色接入规则

新增或调整正式角色时，按这个顺序处理：

1. 先判断角色需求是否属于现有 `capability_id`。
2. 若属于现有入口，把该 ID 写进 `shared_capability_ids`，并补齐 catalog 要求的 `required_suite_paths`。
3. 若不属于现有入口，先更新 capability catalog，写清规则归属、消费者、回归和 `stop_and_specialize_when`，再继续改角色资源与 suite。
4. 若需求已经越过某个入口的 `stop_and_specialize_when`，不要继续往共享入口里加分支，直接立新的专用机制。

## 5. gate 硬约束

repo consistency gate 当前固定检查：

- manifest 的 `shared_capability_ids` 必须引用已登记的 `capability_id`
- capability catalog 的 `consumer_character_ids` 必须和 manifest 完全一致
- capability catalog 要求的 `required_suite_paths` 必须全部挂回角色 manifest 条目
- `coverage_needles` 必须能在角色内容、validator、设计稿、调整记录或 wrapper 的扫描范围里找到实际使用证据
- 新共享入口未登记、已登记但没人用、或角色在用却没声明，都会直接失败

## 6. 维护边界

- 共享能力目录只登记“共享入口”和“边界”，不抄角色玩法细节。
- 具体资源字段、payload、触发链和运行时读写路径，仍以 `docs/design/battle_content_schema.md`、`docs/design/effect_engine.md` 与 `docs/rules/*.md` 为准。
- 当前开放的 capability entry 列表以 `config/formal_character_capability_catalog.json` 为准；如果这里只再抄一遍名单，很快又会漂。
