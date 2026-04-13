from __future__ import annotations


FORMAL_VALIDATOR_BUCKETS = [
    "unit_passive_contracts",
    "skill_effect_contracts",
    "ultimate_domain_contracts",
]

RULE_MOD_WHITELIST = [
    "final_mod",
    "mp_regen",
    "action_legality",
    "incoming_accuracy",
    "nullify_field_accuracy",
    "incoming_action_final_mod",
    "incoming_heal_final_mod",
]

SOURCE_GROUP_RULE_MODS = [
    "mp_regen",
    "incoming_accuracy",
    "nullify_field_accuracy",
    "incoming_action_final_mod",
    "incoming_heal_final_mod",
]

INCOMING_FILTER_TRIGGERS = [
    "on_receive_action_hit",
    "on_receive_action_damage_segment",
]

CURRENT_WORKFLOW_DOC = "docs/design/current_development_workflow.md"
CURRENT_REGRESSION_BASELINE_DOC = "docs/design/current_stage_regression_baseline.md"
