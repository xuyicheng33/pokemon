from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from repo_consistency_common import GateContext


ctx = GateContext()

decision_record_paths = [
    "docs/records/decisions.md",
    "docs/records/archive/decisions_pre_2026-04-05_repair_wave.md",
]
formal_validator_buckets = [
    "unit_passive_contracts",
    "skill_effect_contracts",
    "ultimate_domain_contracts",
]
rule_mod_whitelist = [
    "final_mod",
    "mp_regen",
    "action_legality",
    "incoming_accuracy",
    "nullify_field_accuracy",
    "incoming_action_final_mod",
    "incoming_heal_final_mod",
]
source_group_rule_mods = [
    "mp_regen",
    "incoming_accuracy",
    "nullify_field_accuracy",
    "incoming_action_final_mod",
    "incoming_heal_final_mod",
]
incoming_filter_triggers = [
    "on_receive_action_hit",
    "on_receive_action_damage_segment",
]

ctx.require_contains("docs/design/architecture_overview.md", "get_event_log_snapshot", "architecture facade event log snapshot contract")
ctx.require_contains("docs/design/architecture_overview.md", "{\"ok\": true, \"data\": ... , \"error_code\": null, \"error_message\": null}", "manager envelope doc")
ctx.require_contains("docs/design/battle_content_schema.md", "Gojo / Sukuna / Kashimo / Obito", "schema four formal characters wording")
ctx.require_contains("docs/design/battle_content_schema.md", "candidate_skill_ids", "schema candidate skill pool contract")
ctx.require_contains("docs/design/battle_content_schema.md", "regular_skill_loadout_overrides", "schema setup override contract")
ctx.require_contains("docs/design/battle_content_schema.md", "max_stacks", "schema stack cap contract")
ctx.require_contains("docs/design/battle_content_schema.md", "once_per_battle", "schema once-per-battle skill contract")
ctx.require_contains("docs/design/battle_content_schema.md", "required_target_effects", "schema effect precondition contract")
ctx.require_contains("docs/design/battle_content_schema.md", "required_target_same_owner", "schema effect same-owner precondition contract")
ctx.require_contains("docs/design/battle_content_schema.md", "action_legality", "schema action legality contract")
ctx.require_contains("docs/design/battle_content_schema.md", "incoming_accuracy", "schema incoming accuracy contract")
ctx.require_contains("docs/design/battle_content_schema.md", "incoming_heal_final_mod", "schema incoming heal final mod contract")
ctx.require_contains("docs/design/battle_content_schema.md", "effect_stack_sum", "schema effect stack sum contract")
ctx.require_contains("docs/design/battle_content_schema.md", "power_bonus_self_effect_ids", "schema power bonus self effect ids contract")
ctx.require_contains("docs/design/battle_content_schema.md", "power_bonus_target_effect_ids", "schema power bonus target effect ids contract")
ctx.require_contains("docs/design/battle_content_schema.md", "power_bonus_per_stack", "schema power bonus per stack contract")
ctx.require_contains("docs/design/battle_content_schema.md", "config/formal_character_registry.json", "schema formal character single source wording")
ctx.require_contains("docs/design/battle_content_schema.md", "formal_validators/shared/content_snapshot_formal_character_registry.gd", "schema runtime validator loader wording")
ctx.require_contains("docs/design/battle_content_schema.md", "当前 snapshot 实际出现的正式角色", "schema scoped formal validator wording")
ctx.require_contains("docs/design/battle_content_schema.md", "content_validator_script_path", "schema formal character validator path wording")
ctx.require_contains("docs/design/battle_content_schema.md", "nullify_field_accuracy", "schema field accuracy nullify contract")
ctx.require_contains("docs/design/battle_content_schema.md", "incoming_action_final_mod", "schema incoming action final mod contract")
ctx.require_contains("docs/design/battle_content_schema.md", "required_incoming_command_types", "schema incoming action command filter contract")
ctx.require_contains("docs/design/battle_content_schema.md", "required_incoming_combat_type_ids", "schema incoming action combat type filter contract")
ctx.require_contains("docs/design/battle_content_schema.md", "action_actor", "schema action actor scope contract")
ctx.require_contains("docs/design/battle_content_schema.md", "`apply_field` payload requires `scope=field`", "schema apply_field scope contract")
ctx.require_contains("docs/design/battle_content_schema.md", "damage / heal / resource_mod / stat_mod / apply_effect / remove_effect", "schema unit-target payload scope contract")
ctx.require_contains("docs/design/battle_content_schema.md", "retention_mode", "schema stat retention contract")
ctx.require_contains("docs/design/battle_content_schema.md", "persistent_stat_stages", "schema persistent stat stage contract")
ctx.require_contains("docs/design/formal_character_delivery_checklist.md", "sample_setup_method", "formal character setup method checklist wording")
ctx.require_contains("docs/design/formal_character_delivery_checklist.md", "formal_setup_matchup_id", "formal character setup matchup checklist wording")
ctx.require_contains("docs/design/formal_character_delivery_checklist.md", "content_validator_script_path", "formal character validator registry checklist wording")
ctx.require_contains("docs/design/formal_character_delivery_checklist.md", "unit_passive_contracts / skill_effect_contracts / ultimate_domain_contracts", "formal character tri-bucket checklist wording")
ctx.require_contains("docs/design/formal_character_design_template.md", "unit_passive_contracts / skill_effect_contracts / ultimate_domain_contracts", "formal character tri-bucket template wording")
ctx.require_contains("docs/design/kashimo_hajime_design.md", "kashimo_manager_smoke_suite.gd", "kashimo manager smoke delivery doc")
ctx.require_contains("docs/design/kashimo_hajime_design.md", "tests/replay_cases/kashimo_cases.md", "kashimo fixed case delivery doc")
ctx.require_contains("docs/design/kashimo_hajime_design.md", "kashimo_apply_water_leak_listeners", "kashimo water leak listener entry doc")
ctx.require_contains("docs/design/kashimo_hajime_design.md", "kashimo_water_leak_self_listener", "kashimo water leak self listener doc")
ctx.require_contains("docs/design/kashimo_hajime_design.md", "kashimo_water_leak_counter_listener", "kashimo water leak counter listener doc")
ctx.require_contains("docs/design/battle_core_architecture_constraints.md", "220", "architecture early warning threshold")
ctx.require_contains("docs/design/battle_core_architecture_constraints.md", "incoming_heal_final_mod", "architecture incoming heal final whitelist")
ctx.require_contains("docs/design/battle_core_architecture_constraints.md", "nullify_field_accuracy", "architecture nullify field accuracy whitelist")
ctx.require_contains("docs/design/battle_core_architecture_constraints.md", "incoming_action_final_mod", "architecture incoming action final whitelist")
ctx.require_contains("docs/design/battle_core_architecture_constraints.md", "strict DAG", "architecture runtime DAG wording")
ctx.require_contains("docs/design/battle_core_architecture_constraints.md", "architecture_wiring_graph_gate.py", "architecture wiring gate doc")
ctx.require_contains("docs/design/battle_runtime_model.md", "regular_skill_ids", "runtime equipped skill mirror contract")
ctx.require_contains("docs/design/battle_runtime_model.md", "used_once_per_battle_skill_ids", "runtime once-per-battle internal record contract")
ctx.require_contains("docs/design/battle_runtime_model.md", "action_legality", "runtime action legality contract")
ctx.require_contains("docs/design/battle_runtime_model.md", "incoming_accuracy", "runtime incoming accuracy contract")
ctx.require_contains("docs/design/battle_runtime_model.md", "nullify_field_accuracy", "runtime nullify field accuracy contract")
ctx.require_contains("docs/design/battle_runtime_model.md", "incoming_action_final_mod", "runtime incoming action final mod contract")
ctx.require_contains("docs/design/battle_runtime_model.md", "mp_regen / incoming_accuracy / nullify_field_accuracy / incoming_action_final_mod / incoming_heal_final_mod", "runtime source stacking key scope contract")
ctx.require_contains("docs/design/battle_runtime_model.md", "action_actor_id", "runtime action actor chain context contract")
ctx.require_contains("docs/design/battle_runtime_model.md", "action_combat_type_id", "runtime action combat type chain context contract")
ctx.require_contains("docs/design/command_and_legality.md", "regular_skill_ids", "legality runtime equipped skill contract")
ctx.require_contains("docs/design/command_and_legality.md", "domain_legality_service.gd", "domain legality helper doc")
ctx.require_contains("docs/design/command_and_legality.md", "once_per_battle", "legality once-per-battle doc")
ctx.require_contains("docs/design/log_and_replay_contract.md", "ContentSnapshotCache", "log/replay cache contract doc")
ctx.require_contains("docs/design/log_and_replay_contract.md", "预分组", "log/replay turn grouping doc")
ctx.require_contains("docs/design/log_and_replay_contract.md", "外部修改不得回写到 event log", "log/replay detached public snapshot wording")
ctx.require_contains("docs/design/lifecycle_and_replacement.md", "faint_killer_attribution_service.gd", "lifecycle helper doc")
ctx.require_contains("docs/design/lifecycle_and_replacement.md", "faint_leave_replacement_service.gd", "lifecycle replacement helper doc")
ctx.require_contains("docs/design/passive_and_field.md", "field_apply_context_resolver.gd", "field helper doc")
ctx.require_contains("docs/design/passive_and_field.md", "field_apply_conflict_service.gd", "field conflict helper doc")
ctx.require_contains("docs/design/passive_and_field.md", "field_apply_log_service.gd", "field log helper doc")
ctx.require_contains("docs/design/passive_and_field.md", "field_apply_effect_runner.gd", "field effect runner helper doc")
ctx.require_contains("docs/design/project_folder_structure.md", "facades/", "project folder facades doc")
ctx.require_contains("docs/design/sukuna_design.md", "max_stacks = 3", "sukuna kamado hard cap doc")
ctx.require_contains("docs/design/sukuna_design.md", "不新增第 4 层", "sukuna kamado overflow ignore doc")
ctx.require_contains("docs/design/sukuna_design.md", "max_mp", "sukuna matchup bst max_mp contract")
ctx.require_contains("docs/rules/01_battle_format_and_visibility.md", "candidate_skill_ids", "rules candidate skill pool contract")
ctx.require_contains("docs/rules/01_battle_format_and_visibility.md", "regular_skill_loadout_overrides", "rules setup override contract")
ctx.require_contains("docs/rules/06_effect_schema_and_extension.md", "required_target_effects", "rules effect precondition contract")
ctx.require_contains("docs/rules/06_effect_schema_and_extension.md", "required_target_same_owner", "rules effect same-owner precondition contract")
ctx.require_contains("docs/rules/06_effect_schema_and_extension.md", "max_stacks", "rules stack cap contract")
ctx.require_contains("docs/rules/06_effect_schema_and_extension.md", "on_receive_action_hit", "rules incoming action trigger contract")
ctx.require_contains("docs/rules/06_effect_schema_and_extension.md", "on_receive_action_damage_segment", "rules damage-segment trigger contract")
ctx.require_contains("docs/rules/06_effect_schema_and_extension.md", "retention_mode", "rules stat retention contract")
ctx.require_contains("docs/rules/06_effect_schema_and_extension.md", "persistent_stat_stages", "rules persistent stat stage contract")
ctx.require_contains("docs/rules/06_effect_schema_and_extension.md", "action_legality", "rules action legality contract")
ctx.require_contains("docs/rules/06_effect_schema_and_extension.md", "incoming_accuracy", "rules incoming accuracy contract")
ctx.require_contains("docs/rules/06_effect_schema_and_extension.md", "nullify_field_accuracy", "rules field accuracy nullify contract")
ctx.require_contains("docs/rules/06_effect_schema_and_extension.md", "incoming_action_final_mod", "rules incoming action final mod contract")
ctx.require_contains("docs/rules/06_effect_schema_and_extension.md", "incoming_heal_final_mod", "rules incoming heal final mod contract")
ctx.require_contains("docs/rules/06_effect_schema_and_extension.md", "required_incoming_command_types", "rules incoming action command filter contract")
ctx.require_contains("docs/rules/06_effect_schema_and_extension.md", "required_incoming_combat_type_ids", "rules incoming action combat type filter contract")
ctx.require_contains("docs/rules/06_effect_schema_and_extension.md", "action_actor", "rules action actor scope contract")
ctx.require_contains("docs/rules/06_effect_schema_and_extension.md", "`apply_field` payload requires `scope=field`", "rules apply_field scope contract")
ctx.require_contains("docs/rules/03_stats_resources_and_damage.md", "incoming_accuracy", "rules incoming accuracy read-path")
ctx.require_contains("docs/rules/03_stats_resources_and_damage.md", "max_mp", "rules sukuna matchup bst max_mp contract")
ctx.require_contains("docs/design/effect_engine.md", "nullify_field_accuracy", "effect engine nullify field accuracy read-path")
ctx.require_contains("docs/design/effect_engine.md", "incoming_action_final_mod", "effect engine incoming action final read-path")
ctx.require_contains("docs/design/domain_field_template.md", "field_apply_success", "domain template success trigger contract")
ctx.require_contains("docs/design/domain_field_template.md", "同回合双方都已排队施放领域时", "domain template dual-domain contract")
ctx.require_contains("docs/rules/05_items_field_input_and_logging.md", "当前正式角色交付面不再包含自动选指策略、自动选指回归或批量模拟案例。", "auto-selection removal rule wording")
ctx.require_exists("docs/records/archive/decisions_pre_2026-04-05_repair_wave.md", "decisions repair-wave archive")
ctx.require_exists("docs/records/archive/tasks_pre_2026-04-05_repair_wave.md", "tasks repair-wave archive")
ctx.require_contains("docs/records/decisions.md", "decisions_pre_2026-04-05_repair_wave.md", "active decisions archive pointer")
ctx.require_contains("docs/records/tasks.md", "tasks_pre_2026-04-05_repair_wave.md", "active tasks archive pointer")
ctx.require_contains("docs/records/decisions.md", "entry validator 固定采用三桶模板", "active decision tri-bucket wording")
ctx.require_contains("docs/records/decisions.md", "on_receive_action_damage_segment", "active decision damage-segment filter wording")
ctx.require_contains("docs/records/decisions.md", "once_per_battle", "active decision once-per-battle wording")
ctx.require_contains("docs/records/decisions.md", "duration_mode = permanent", "active decision sukuna permanent regen wording")
ctx.require_contains_any(decision_record_paths, "固定可复查案例作为角色与规则复查入口", "fixed-case decision wording")
ctx.require_contains_any(decision_record_paths, "外层输入与公开快照继续只使用 `public_id`。", "public input decision wording")
ctx.require_contains_any(decision_record_paths, "若未来恢复自动选指，必须重新补齐规则、设计文档与接线任务，不得直接回填历史实现。", "future auto-selection recovery gate")
ctx.require_contains_any(decision_record_paths, "effect dedupe key 必须包含 effect_instance_id", "effect-instance dedupe decision wording")
ctx.require_contains_any(decision_record_paths, "field_break / field_expire 链上创建的 successor field 必须保留", "field successor cleanup decision wording")
ctx.require_contains_any(decision_record_paths, "正式角色注册表当前必须登记角色 effect 资源、wrapper 下属 suite 与关键回归测试名", "formal registry expansion decision wording")
ctx.require_contains_any(decision_record_paths, "BattleCoreManager` 公开 contract 统一为严格 envelope", "manager envelope decision wording")
ctx.require_contains_any(decision_record_paths, "宿傩“灶”正式写死为 3 层硬上限，满层后忽略新层", "sukuna kamado cap decision wording")
ctx.require_contains_any(decision_record_paths, "运行时 helper 全部统一进 composition 装配", "runtime helper composition decision wording")
ctx.require_contains_any(decision_record_paths, "suite 可达性闸门", "suite reachability decision wording")
ctx.require_contains_any(decision_record_paths, "跨模块用户可见错误读取统一走 `error_state()` / `invalid_battle_code()`", "explicit error-state decision wording")
ctx.require_contains_any(decision_record_paths, "Runtime wiring 图重新收口为严格 DAG", "runtime DAG decision wording")
ctx.require_contains_any(decision_record_paths, "composer 级共享 cache + 每次 fresh index", "content snapshot cache decision wording")
ctx.require_contains("docs/records/review_2026-04-04_foundation_stabilization_audit.md", "基础稳定化审查记录", "foundation stabilization review record")
ctx.require_contains("README.md", "content_validator_script_path", "README runtime validator registry doc")
ctx.require_contains("README.md", "formal_setup_matchup_id", "README formal setup matchup doc")
ctx.require_contains("README.md", "当前 content snapshot 实际已出现的正式角色", "README scoped formal validator doc")
ctx.require_contains("README.md", "BATTLE_SANDBOX_FAILED:", "README sandbox failure gate wording")
ctx.require_contains("README.md", "与内部日志断引用", "README detached event log wording")
ctx.require_contains("README.md", "unit_passive_contracts / skill_effect_contracts / ultimate_domain_contracts", "README formal validator tri-bucket wording")
ctx.require_contains("tests/README.md", "run_all.gd` 会直接注册核心公共 suite", "tests README current run_all wording")
ctx.require_contains("tests/README.md", "formal_setup_matchup_id", "tests README formal setup matchup doc")
ctx.require_contains("tests/README.md", "只校验当前快照里实际出现的正式角色", "tests README scoped formal validator wording")
ctx.require_contains("tests/README.md", "unit_passive_contracts / skill_effect_contracts / ultimate_domain_contracts", "tests README formal validator tri-bucket wording")
ctx.require_contains("tests/check_architecture_constraints.sh", "ARCH_GATE_WARNING", "architecture warning marker")
ctx.require_absent("tests/README.md", "只注册顶层 wrapper，不直接注册子套件", "stale wrapper-only tests README wording")
for rel_path in [
    "README.md",
    "tests/README.md",
    "docs/design/formal_character_delivery_checklist.md",
    "docs/design/battle_content_schema.md",
]:
    ctx.require_absent(rel_path, "formal_character_validator_registry.json", "removed code-side validator registry wording")
for rel_path in [
    "README.md",
    "tests/README.md",
    "docs/design/formal_character_delivery_checklist.md",
    "docs/design/battle_content_schema.md",
    "docs/design/formal_character_design_template.md",
    "docs/records/decisions.md",
    "docs/records/tasks.md",
]:
    ctx.require_absent(rel_path, "docs/records/formal_character_registry.json", "stale docs-side formal registry path")
for rel_path in [
    "README.md",
    "tests/README.md",
    "docs/design/formal_character_delivery_checklist.md",
    "docs/design/battle_content_schema.md",
    "docs/records/decisions.md",
]:
    ctx.require_absent(rel_path, "代码侧描述源", "stale code-side formal registry wording")
ctx.require_absent("docs/records/decisions.md", "runtime formal validator 改由 code-side registry 装配", "stale dual-registry decision wording")

stale_candidate_wording = [
    "schema 暂不扩候选技能池字段",
    "当前 schema 不单独编码",
    "写死在 README 与内容说明文档里",
    "当前允许空串或 `mp_diff_clamped`",
    "只开放空串与 `mp_diff_clamped`",
]
for rel_path in [
    "README.md",
    "content/README.md",
    "docs/design/battle_content_schema.md",
    "docs/records/decisions.md",
]:
    for needle in stale_candidate_wording:
        ctx.require_absent(rel_path, needle, "candidate skill pool drift wording")

domain_matrix_redundant_wording = [
    "比较双方**扣费后的当前 MP**；MP 高者留场；平 MP 随机决定胜者",
    "比较双方扣费后的当前 MP；高者留场；平 MP 随机决定胜者",
]
for rel_path in [
    "docs/design/gojo_satoru_design.md",
    "docs/design/sukuna_design.md",
]:
    for needle in domain_matrix_redundant_wording:
        ctx.require_absent(rel_path, needle, "role design duplicated public domain matrix wording")

for rel_path in [
    "docs/design/battle_content_schema.md",
    "docs/design/battle_core_architecture_constraints.md",
    "docs/rules/06_effect_schema_and_extension.md",
]:
    for mod_kind in rule_mod_whitelist:
        ctx.require_contains(rel_path, mod_kind, "complete rule_mod whitelist wording")

for rel_path in [
    "docs/design/battle_content_schema.md",
    "docs/design/battle_runtime_model.md",
    "docs/rules/06_effect_schema_and_extension.md",
]:
    for mod_kind in source_group_rule_mods:
        ctx.require_contains(rel_path, mod_kind, "complete stacking source group wording")

for rel_path in [
    "docs/design/battle_content_schema.md",
    "docs/design/effect_engine.md",
    "docs/rules/06_effect_schema_and_extension.md",
]:
    for trigger_name in incoming_filter_triggers:
        ctx.require_contains(rel_path, trigger_name, "complete incoming trigger filter wording")

for rel_path in [
    "README.md",
    "tests/README.md",
    "docs/design/formal_character_delivery_checklist.md",
    "docs/design/formal_character_design_template.md",
]:
    for bucket_name in formal_validator_buckets:
        ctx.require_contains(rel_path, bucket_name, "complete formal validator bucket wording")

ctx.finish("design/rules/decisions wording and stale phrasing are aligned")
