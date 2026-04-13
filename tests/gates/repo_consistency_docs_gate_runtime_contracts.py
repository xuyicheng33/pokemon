from __future__ import annotations

from repo_consistency_common import GateContext
from repo_consistency_docs_gate_shared import INCOMING_FILTER_TRIGGERS, RULE_MOD_WHITELIST, SOURCE_GROUP_RULE_MODS


def run(ctx: GateContext) -> None:
    ctx.require_contains("docs/design/architecture_overview.md", "get_event_log_snapshot", "architecture facade event log snapshot contract")
    ctx.require_contains("docs/design/architecture_overview.md", "{\"ok\": true, \"data\": ... , \"error_code\": null, \"error_message\": null}", "manager envelope doc")
    ctx.require_contains("docs/design/battle_core_architecture_constraints.md", "220", "architecture early warning threshold")
    ctx.require_contains("docs/design/battle_core_architecture_constraints.md", "incoming_heal_final_mod", "architecture incoming heal final whitelist")
    ctx.require_contains("docs/design/battle_core_architecture_constraints.md", "nullify_field_accuracy", "architecture nullify field accuracy whitelist")
    ctx.require_contains("docs/design/battle_core_architecture_constraints.md", "incoming_action_final_mod", "architecture incoming action final whitelist")
    ctx.require_contains("docs/design/battle_core_architecture_constraints.md", "strict DAG", "architecture runtime DAG wording")
    ctx.require_contains("docs/design/battle_core_architecture_constraints.md", "architecture_wiring_graph_gate.py", "architecture wiring gate doc")
    ctx.require_contains("docs/design/battle_runtime_model.md", "regular_skill_ids", "runtime equipped skill mirror contract")
    ctx.require_contains("docs/design/battle_runtime_model.md", "used_once_per_battle_skill_ids", "runtime once-per-battle internal record contract")
    ctx.require_contains("docs/design/battle_runtime_model.md", "persistent_stat_stages", "runtime persistent stat stage contract")
    ctx.require_contains("docs/design/battle_runtime_model.md", "action_legality", "runtime action legality contract")
    ctx.require_contains("docs/design/battle_runtime_model.md", "incoming_accuracy", "runtime incoming accuracy contract")
    ctx.require_contains("docs/design/battle_runtime_model.md", "nullify_field_accuracy", "runtime nullify field accuracy contract")
    ctx.require_contains("docs/design/battle_runtime_model.md", "incoming_action_final_mod", "runtime incoming action final mod contract")
    ctx.require_contains("docs/design/battle_runtime_model.md", "mp_regen / incoming_accuracy / nullify_field_accuracy / incoming_action_final_mod / incoming_heal_final_mod", "runtime source stacking key scope contract")
    ctx.require_contains("docs/design/battle_runtime_model.md", "action_actor_id", "runtime action actor chain context contract")
    ctx.require_contains("docs/design/battle_runtime_model.md", "action_combat_type_id", "runtime action combat type chain context contract")
    ctx.require_contains("docs/design/battle_runtime_model.md", "FieldState.creator", "runtime field creator contract")
    ctx.require_contains("docs/design/battle_runtime_model.md", "creator_public_id", "runtime field creator public snapshot contract")
    ctx.require_contains("docs/design/battle_runtime_model.md", "dedupe_discriminator", "runtime effect dedupe discriminator contract")
    ctx.require_contains("docs/design/command_and_legality.md", "regular_skill_ids", "legality runtime equipped skill contract")
    ctx.require_contains("docs/design/command_and_legality.md", "domain_legality_service.gd", "domain legality helper doc")
    ctx.require_contains("docs/design/command_and_legality.md", "once_per_battle", "legality once-per-battle doc")
    ctx.require_contains("docs/design/log_and_replay_contract.md", "ContentSnapshotCache", "log/replay cache contract doc")
    ctx.require_contains("docs/design/log_and_replay_contract.md", "预分组", "log/replay turn grouping doc")
    ctx.require_contains("docs/design/log_and_replay_contract.md", "外部修改不得回写到 event log", "log/replay detached public snapshot wording")
    ctx.require_contains("docs/design/log_and_replay_contract.md", "creator_public_id", "log/replay field creator public id contract")
    ctx.require_contains("docs/design/log_and_replay_contract.md", "不返回首帧公开快照", "log/replay create_session runtime guard doc")
    ctx.require_contains("docs/design/lifecycle_and_replacement.md", "faint_killer_attribution_service.gd", "lifecycle helper doc")
    ctx.require_contains("docs/design/lifecycle_and_replacement.md", "faint_leave_replacement_service.gd", "lifecycle replacement helper doc")
    ctx.require_contains("docs/design/passive_and_field.md", "field_apply_context_resolver.gd", "field helper doc")
    ctx.require_contains("docs/design/passive_and_field.md", "field_apply_conflict_service.gd", "field conflict helper doc")
    ctx.require_contains("docs/design/passive_and_field.md", "field_apply_log_service.gd", "field log helper doc")
    ctx.require_contains("docs/design/passive_and_field.md", "field_apply_effect_runner.gd", "field effect runner helper doc")
    ctx.require_contains("docs/design/effect_engine.md", "nullify_field_accuracy", "effect engine nullify field accuracy read-path")
    ctx.require_contains("docs/design/effect_engine.md", "incoming_action_final_mod", "effect engine incoming action final read-path")
    ctx.require_contains("docs/design/domain_field_template.md", "field_apply_success", "domain template success trigger contract")
    ctx.require_contains("docs/design/domain_field_template.md", "同回合双方都已排队施放领域时", "domain template dual-domain contract")
    ctx.require_contains("docs/rules/05_items_field_input_and_logging.md", "当前正式角色交付面不再包含自动选指策略、自动选指回归或批量模拟案例。", "auto-selection removal rule wording")
    ctx.require_contains("docs/rules/05_items_field_input_and_logging.md", "creator_public_id", "rules field creator public id contract")
    ctx.require_contains("docs/rules/05_items_field_input_and_logging.md", "不返回任何公开快照", "rules create_session runtime guard wording")
    ctx.require_contains("docs/rules/04_status_switch_and_lifecycle.md", "reentered_turn_index = 当前 turn_index", "rules replacement reentry state wording")

    for rel_path in [
        "docs/design/battle_content_schema.md",
        "docs/design/battle_core_architecture_constraints.md",
        "docs/rules/06_effect_schema_and_extension.md",
    ]:
        for mod_kind in RULE_MOD_WHITELIST:
            ctx.require_contains(rel_path, mod_kind, "complete rule_mod whitelist wording")

    for rel_path in [
        "docs/design/battle_content_schema.md",
        "docs/design/battle_runtime_model.md",
        "docs/rules/06_effect_schema_and_extension.md",
    ]:
        for mod_kind in SOURCE_GROUP_RULE_MODS:
            ctx.require_contains(rel_path, mod_kind, "complete stacking source group wording")

    for rel_path in [
        "docs/design/battle_content_schema.md",
        "docs/design/effect_engine.md",
        "docs/rules/06_effect_schema_and_extension.md",
    ]:
        for trigger_name in INCOMING_FILTER_TRIGGERS:
            ctx.require_contains(rel_path, trigger_name, "complete incoming trigger filter wording")
