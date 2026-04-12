extends RefCounted
class_name FormalPairInteractionScenarioRegistry

const GojoCasesScript := preload("res://tests/support/formal_pair_interaction/gojo_cases.gd")
const KashimoCasesScript := preload("res://tests/support/formal_pair_interaction/kashimo_cases.gd")
const ObitoCasesScript := preload("res://tests/support/formal_pair_interaction/obito_cases.gd")

var _gojo_cases = GojoCasesScript.new()
var _kashimo_cases = KashimoCasesScript.new()
var _obito_cases = ObitoCasesScript.new()

func build_runners() -> Dictionary:
	return {
		"gojo_sukuna_domain_cleanup": Callable(_gojo_cases, "run_gojo_vs_sukuna_domain_cleanup"),
		"gojo_kashimo_kyokyo_nullify_domain_accuracy": Callable(_gojo_cases, "run_gojo_vs_kashimo_kyokyo_nullify_domain_accuracy"),
		"gojo_obito_heal_block_public_contract": Callable(_gojo_cases, "run_gojo_vs_obito_heal_block_public_contract"),
		"sukuna_kashimo_domain_accuracy_nullified": Callable(_kashimo_cases, "run_sukuna_vs_kashimo_domain_accuracy_nullified"),
		"sukuna_obito_field_seal_and_kamado_lifecycle": Callable(_obito_cases, "run_sukuna_vs_obito_field_seal_and_kamado_lifecycle"),
		"kashimo_obito_yinyang_and_amber_persistence": Callable(_kashimo_cases, "run_kashimo_vs_obito_yinyang_and_amber_persistence"),
	}
