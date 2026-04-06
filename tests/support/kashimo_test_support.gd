extends "res://tests/support/formal_character_test_support.gd"
class_name KashimoTestSupport

const DomainAccuracyProbeSupportScript := preload("res://tests/support/kashimo_test_support/domain_accuracy_probe_support.gd")

var _domain_accuracy_probe_support = DomainAccuracyProbeSupportScript.new()

func build_kashimo_setup_result(sample_factory, p1_regular_skill_overrides: Dictionary = {}, p2_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	return build_formal_character_setup_result(sample_factory, "kashimo_hajime", {
		"P1": p1_regular_skill_overrides,
		"P2": p2_regular_skill_overrides,
	})

func build_kashimo_setup(sample_factory, p1_regular_skill_overrides: Dictionary = {}, p2_regular_skill_overrides: Dictionary = {}):
	return _unwrap_setup_result(build_kashimo_setup_result(sample_factory, p1_regular_skill_overrides, p2_regular_skill_overrides))

func build_kashimo_vs_gojo_setup_result(sample_factory, p1_regular_skill_overrides: Dictionary = {}, p2_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	return build_matchup_setup_result(sample_factory, "kashimo_vs_gojo", {
		"P1": p1_regular_skill_overrides,
		"P2": p2_regular_skill_overrides,
	})

func build_kashimo_vs_gojo_setup(sample_factory, p1_regular_skill_overrides: Dictionary = {}, p2_regular_skill_overrides: Dictionary = {}):
	return _unwrap_setup_result(build_kashimo_vs_gojo_setup_result(sample_factory, p1_regular_skill_overrides, p2_regular_skill_overrides))

func build_kashimo_vs_sukuna_setup_result(sample_factory, p1_regular_skill_overrides: Dictionary = {}, p2_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	return build_matchup_setup_result(sample_factory, "kashimo_vs_sukuna", {
		"P1": p1_regular_skill_overrides,
		"P2": p2_regular_skill_overrides,
	})

func build_kashimo_vs_sukuna_setup(sample_factory, p1_regular_skill_overrides: Dictionary = {}, p2_regular_skill_overrides: Dictionary = {}):
	return _unwrap_setup_result(build_kashimo_vs_sukuna_setup_result(sample_factory, p1_regular_skill_overrides, p2_regular_skill_overrides))

func run_gojo_domain_accuracy_case(harness, sample_factory, use_kyokyo: bool, seed: int) -> Dictionary:
	return run_domain_accuracy_case_for_matchup(
		harness,
		sample_factory,
		use_kyokyo,
		seed,
		"kashimo_vs_gojo",
		"gojo_unlimited_void",
		"gojo_ao",
		"gojo_unlimited_void_field"
	)

func run_domain_accuracy_case_for_matchup(
	harness,
	sample_factory,
	use_kyokyo: bool,
	seed: int,
	matchup_id: String,
	domain_skill_id: String,
	attack_skill_id: String,
	expected_field_id: String
) -> Dictionary:
	return _domain_accuracy_probe_support.run_domain_accuracy_case_for_matchup(
		self,
		harness,
		sample_factory,
		use_kyokyo,
		seed,
		matchup_id,
		domain_skill_id,
		attack_skill_id,
		expected_field_id
	)

func run_sukuna_domain_accuracy_case(harness, sample_factory, use_kyokyo: bool, seed: int) -> Dictionary:
	return run_domain_accuracy_case_for_matchup(
		harness,
		sample_factory,
		use_kyokyo,
		seed,
		"kashimo_vs_sukuna",
		"sukuna_fukuma_mizushi",
		"sukuna_hiraku",
		"sukuna_malevolent_shrine_field"
	)

func find_gojo_domain_accuracy_probe_seed(harness, sample_factory, seed_start: int, search_window: int = 128) -> Dictionary:
	return find_domain_accuracy_probe_seed_for_matchup(
		harness,
		sample_factory,
		seed_start,
		search_window,
		"kashimo_vs_gojo",
		"gojo_unlimited_void",
		"gojo_ao",
		"gojo_unlimited_void_field"
	)

func find_sukuna_domain_accuracy_probe_seed(harness, sample_factory, seed_start: int, search_window: int = 128) -> Dictionary:
	return find_domain_accuracy_probe_seed_for_matchup(
		harness,
		sample_factory,
		seed_start,
		search_window,
		"kashimo_vs_sukuna",
		"sukuna_fukuma_mizushi",
		"sukuna_hiraku",
		"sukuna_malevolent_shrine_field"
	)

func find_domain_accuracy_probe_seed_for_matchup(
	harness,
	sample_factory,
	seed_start: int,
	search_window: int,
	matchup_id: String,
	domain_skill_id: String,
	attack_skill_id: String,
	expected_field_id: String
) -> Dictionary:
	return _domain_accuracy_probe_support.find_domain_accuracy_probe_seed_for_matchup(
		self,
		harness,
		sample_factory,
		seed_start,
		search_window,
		matchup_id,
		domain_skill_id,
		attack_skill_id,
		expected_field_id
	)

func calc_expected_fixed_effect_damage(core, content_index, effect_id: String, target_unit) -> int:
	var effect_definition = content_index.effects.get(effect_id, null)
	if effect_definition == null or effect_definition.payloads.is_empty():
		return -1
	var payload = effect_definition.payloads[0]
	var type_effectiveness := 1.0
	if not String(payload.combat_type_id).is_empty():
		type_effectiveness = core.service("combat_type_service").calc_effectiveness(String(payload.combat_type_id), target_unit.combat_type_ids)
	return core.service("damage_service").apply_final_mod(max(1, int(payload.amount)), type_effectiveness)

func collect_trigger_damage_deltas(event_log: Array, target_instance_id: String, trigger_name: String) -> Array[int]:
	var deltas: Array[int] = []
	for event in event_log:
		if event.event_type != EventTypesScript.EFFECT_DAMAGE:
			continue
		if String(event.target_instance_id) != target_instance_id:
			continue
		if String(event.trigger_name) != trigger_name:
			continue
		if event.value_changes.is_empty():
			continue
		deltas.append(abs(int(event.value_changes[0].delta)))
	return deltas

func has_rule_mod(unit_state, mod_kind: String, value: Variant = null) -> bool:
	for rule_mod_instance in unit_state.rule_mod_instances:
		if String(rule_mod_instance.mod_kind) != mod_kind:
			continue
		if value != null and String(rule_mod_instance.value) != String(value):
			continue
		return true
	return false
