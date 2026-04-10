extends RefCounted

const WIRING_SPECS := [
	{"owner": "passive_skill_service", "dependency": "trigger_dispatcher", "source": "trigger_dispatcher"},
	{"owner": "passive_item_service", "dependency": "trigger_dispatcher", "source": "trigger_dispatcher"},
	{"owner": "field_service", "dependency": "trigger_dispatcher", "source": "trigger_dispatcher"},
	{"owner": "field_apply_service", "dependency": "field_service", "source": "field_service"},
	{"owner": "field_apply_service", "dependency": "domain_clash_orchestrator", "source": "domain_clash_orchestrator"},
	{"owner": "field_apply_service", "dependency": "field_apply_log_service", "source": "field_apply_log_service"},
	{"owner": "field_apply_service", "dependency": "field_apply_effect_runner", "source": "field_apply_effect_runner"},
	{"owner": "domain_clash_orchestrator", "dependency": "field_apply_conflict_service", "source": "field_apply_conflict_service"},
	{"owner": "field_apply_conflict_service", "dependency": "rng_service", "source": "rng_service"},
	{"owner": "field_apply_conflict_service", "dependency": "context_resolver", "source": "field_apply_context_resolver"},
	{"owner": "field_apply_log_service", "dependency": "battle_logger", "source": "battle_logger"},
	{"owner": "field_apply_log_service", "dependency": "log_event_builder", "source": "log_event_builder"},
	{"owner": "field_apply_log_service", "dependency": "context_resolver", "source": "field_apply_context_resolver"},
	{"owner": "field_apply_effect_runner", "dependency": "field_service", "source": "field_service"},
	{"owner": "field_apply_effect_runner", "dependency": "trigger_dispatcher", "source": "trigger_dispatcher"},
	{"owner": "field_apply_effect_runner", "dependency": "id_factory", "source": "id_factory"},
	{"owner": "field_apply_effect_runner", "dependency": "context_resolver", "source": "field_apply_context_resolver"},
]
