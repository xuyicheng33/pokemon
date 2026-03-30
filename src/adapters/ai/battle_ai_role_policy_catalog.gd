extends RefCounted
class_name BattleAIRolePolicyCatalog

const GojoDoubleMarkModeHandlerScript := preload("res://src/adapters/ai/modes/gojo_double_mark_mode_handler.gd")
const SukunaKamadoCycleModeHandlerScript := preload("res://src/adapters/ai/modes/sukuna_kamado_cycle_mode_handler.gd")

const MODE_HANDLER_REGISTRY := {
    "gojo_double_mark_combo": GojoDoubleMarkModeHandlerScript,
    "sukuna_kamado_cycle": SukunaKamadoCycleModeHandlerScript,
}

const ROLE_POLICY_CONFIG := {
    "gojo_satoru": {
        "mode_handler_id": "gojo_double_mark_combo",
        "domain_ultimate_id": "gojo_unlimited_void",
        "heal_skill_id": "gojo_reverse_ritual",
        "heal_threshold": 0.35,
        "combo_skill_id": "gojo_murasaki",
        "combo_marks": ["gojo_ao_mark", "gojo_aka_mark"],
        "mark_build_order": ["gojo_ao", "gojo_aka"],
        "low_hp_finish_skill_id": "gojo_murasaki",
        "low_hp_finish_threshold": 0.45,
        "fallback_skill_order": ["gojo_aka", "gojo_ao"],
    },
    "sukuna": {
        "mode_handler_id": "sukuna_kamado_cycle",
        "domain_ultimate_id": "sukuna_fukuma_mizushi",
        "heal_skill_id": "sukuna_reverse_ritual",
        "heal_threshold": 0.40,
        "point_rush_skill_order": ["sukuna_kai", "sukuna_hatsu", "sukuna_hiraku"],
        "kamado_mark_id": "sukuna_kamado_mark",
        "kamado_skill_id": "sukuna_hiraku",
        "kamado_prefer_max_stacks": 2,
        "kamado_target_hp_min": 0.25,
        "kamado_self_hp_min": 0.45,
        "mp_adv_skill_id": "sukuna_hatsu",
        "mp_adv_margin": 8,
        "fallback_skill_order": ["sukuna_kai", "sukuna_hatsu", "sukuna_hiraku"],
    },
}

static func get_policy(actor_def_id: String) -> Dictionary:
    return ROLE_POLICY_CONFIG.get(actor_def_id, {})

static func choose_mode_action(actor: Dictionary, target: Dictionary, legal_action_set, role_policy: Dictionary) -> Dictionary:
    var handler_id := str(role_policy.get("mode_handler_id", ""))
    var handler_script = MODE_HANDLER_REGISTRY.get(handler_id, null)
    if handler_script == null:
        return {}
    return handler_script.choose_action(actor, target, legal_action_set, role_policy)
