extends RefCounted

const WIRING_SPECS := [
	{"owner": "command_builder", "dependency": "id_factory", "source": "id_factory"},
	{"owner": "legal_action_service", "dependency": "rule_mod_service", "source": "rule_mod_service"},
	{"owner": "legal_action_service", "dependency": "domain_legality_service", "source": "domain_legality_service"},
	{"owner": "domain_legality_service", "dependency": "domain_clash_orchestrator", "source": "domain_clash_orchestrator"},
]
