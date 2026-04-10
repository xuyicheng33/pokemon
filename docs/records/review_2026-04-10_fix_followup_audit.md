# 2026-04-10 修补后复查记录

## 结论

- 当前主线没有发现新的阻断问题。
- `FormalCharacterManifest` 已拆回稳定 facade + helper，且新 helper 已纳入架构体量闸门。
- payload 与 power bonus 的共享注册事实已经回收到单点注册表，新增同类扩展时不再需要在 validator、registry 和测试里反复手抄同一份名单。
- 四个正式角色的设计稿、资源、formal validator、runtime suite、manager smoke、pair smoke 与 pair interaction 复查未发现新的语义漂移。

## 本轮修补

### 1. `FormalCharacterManifest` 热点已拆分并进入 gate

- `src/shared/formal_character_manifest.gd` 当前只保留 facade 与公开视图入口。
- manifest 读取与顶层桶校验已下沉到 `src/shared/formal_character_manifest/formal_character_manifest_loader.gd`。
- runtime / delivery / pair interaction 视图校验已下沉到 `src/shared/formal_character_manifest/formal_character_manifest_views.gd`。
- `tests/check_architecture_constraints.sh` 已把 `src/shared/formal_character_manifest/**` 与入口文件一起纳入体量闸门。

### 2. payload 共享注册事实已收口

- payload script -> handler slot -> validator key 当前固定只维护在 `src/battle_core/content/payload_contract_registry.gd`。
- `ContentPayloadValidator` 与 `PayloadHandlerRegistry` 已统一从这份注册表派生，不再各写一份 payload 列表。
- `battle_core_wiring_specs_effects_core.gd` 里的 `payload_handler_registry` 注入边也改为从同一份注册表生成。
- 架构 gate 与 payload suite 已同步改成围绕注册表校验，避免名单漂移。

### 3. power bonus 共享注册事实已收口

- `src/battle_core/content/power_bonus_source_registry.gd` 当前同时收口 source 列表、schema 校验与运行时解析。
- `ContentSnapshotSkillValidator` 与 `PowerBonusResolver` 已统一走这份注册表，不再一边改 source 名单、一边改验证和结算分支。

### 4. 历史审查口径已补齐

- `docs/records/review_2026-04-10_post_refactor_alignment_audit.md` 已补成历史审查说明，不再继续充当现行判断依据。

## 验证

- `bash tests/check_architecture_constraints.sh`
- `bash tests/check_repo_consistency.sh`
- `bash tests/check_suite_reachability.sh`
- `bash tests/run_with_gate.sh`
