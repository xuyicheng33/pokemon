extends RefCounted

const WIRING_SPECS := [
	{"owner": "leave_service", "dependency": "battle_logger", "source": "battle_logger"},
	{"owner": "leave_service", "dependency": "log_event_builder", "source": "log_event_builder"},
	{"owner": "leave_service", "dependency": "lifecycle_retention_policy", "source": "lifecycle_retention_policy"},
	{"owner": "replacement_service", "dependency": "battle_logger", "source": "battle_logger"},
	{"owner": "replacement_service", "dependency": "log_event_builder", "source": "log_event_builder"},
	{"owner": "replacement_service", "dependency": "replacement_selector", "source": "replacement_selector"},
	{"owner": "replacement_service", "dependency": "leave_service", "source": "leave_service"},
	{"owner": "replacement_service", "dependency": "field_service", "source": "field_service"},
	{"owner": "faint_resolver", "dependency": "trigger_batch_runner", "source": "trigger_batch_runner"},
	{"owner": "faint_resolver", "dependency": "battle_logger", "source": "battle_logger"},
	{"owner": "faint_resolver", "dependency": "log_event_builder", "source": "log_event_builder"},
	{"owner": "faint_resolver", "dependency": "faint_killer_attribution_service", "source": "faint_killer_attribution_service"},
	{"owner": "faint_resolver", "dependency": "faint_leave_replacement_service", "source": "faint_leave_replacement_service"},
	{"owner": "faint_resolver", "dependency": "field_service", "source": "field_service"},
	{"owner": "faint_killer_attribution_service", "dependency": "trigger_dispatcher", "source": "trigger_dispatcher"},
	{"owner": "faint_leave_replacement_service", "dependency": "leave_service", "source": "leave_service"},
	{"owner": "faint_leave_replacement_service", "dependency": "replacement_service", "source": "replacement_service"},
]
