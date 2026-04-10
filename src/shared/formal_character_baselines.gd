extends RefCounted
class_name FormalCharacterBaselines

const GojoSatoruBaselineScript := preload("res://src/shared/formal_character_baselines/gojo_satoru/gojo_satoru_formal_character_baseline.gd")
const SukunaBaselineScript := preload("res://src/shared/formal_character_baselines/sukuna/sukuna_formal_character_baseline.gd")
const KashimoHajimeBaselineScript := preload("res://src/shared/formal_character_baselines/kashimo_hajime/kashimo_hajime_formal_character_baseline.gd")
const ObitoJuubiJinchurikiBaselineScript := preload("res://src/shared/formal_character_baselines/obito_juubi_jinchuriki/obito_juubi_jinchuriki_formal_character_baseline.gd")

const CHARACTER_IDS := [
	"gojo_satoru",
	"sukuna",
	"kashimo_hajime",
	"obito_juubi_jinchuriki",
]

const BASELINE_SCRIPT_BY_CHARACTER_ID := {
	"gojo_satoru": GojoSatoruBaselineScript,
	"sukuna": SukunaBaselineScript,
	"kashimo_hajime": KashimoHajimeBaselineScript,
	"obito_juubi_jinchuriki": ObitoJuubiJinchurikiBaselineScript,
}

static func character_ids() -> PackedStringArray:
	return PackedStringArray(CHARACTER_IDS)

static func unit_contract(character_id: String, label_override: String = "") -> Dictionary:
	return _resolve_descriptor(_character_baseline(character_id).unit_contract(), label_override)

static func skill_contract(character_id: String, skill_id: String, label_override: String = "") -> Dictionary:
	return _resolve_descriptor(_find_descriptor(_skill_contract_pool(character_id), "skill_id", skill_id), label_override)

static func skill_contracts(character_id: String, skill_ids = []) -> Array[Dictionary]:
	return _resolve_descriptor_array(_skill_contract_pool(character_id), "skill_id", skill_ids)

static func passive_contract(character_id: String, passive_skill_id: String, label_override: String = "") -> Dictionary:
	return _resolve_descriptor(_find_descriptor(_passive_contract_pool(character_id), "passive_skill_id", passive_skill_id), label_override)

static func passive_contracts(character_id: String, passive_skill_ids = []) -> Array[Dictionary]:
	return _resolve_descriptor_array(_passive_contract_pool(character_id), "passive_skill_id", passive_skill_ids)

static func effect_contract(character_id: String, effect_id: String, label_override: String = "") -> Dictionary:
	return _resolve_descriptor(_find_descriptor(_character_baseline(character_id).effect_contracts(), "effect_id", effect_id), label_override)

static func effect_contracts(character_id: String, effect_ids = []) -> Array[Dictionary]:
	return _resolve_descriptor_array(_character_baseline(character_id).effect_contracts(), "effect_id", effect_ids)

static func field_contract(character_id: String, field_id: String, label_override: String = "") -> Dictionary:
	return _resolve_descriptor(_find_descriptor(_character_baseline(character_id).field_contracts(), "field_id", field_id), label_override)

static func field_contracts(character_id: String, field_ids = []) -> Array[Dictionary]:
	return _resolve_descriptor_array(_character_baseline(character_id).field_contracts(), "field_id", field_ids)

static func _character_baseline(character_id: String):
	var baseline_script = BASELINE_SCRIPT_BY_CHARACTER_ID.get(character_id, null)
	if baseline_script != null:
		return baseline_script.new()
	assert(false, "Unknown formal character baseline: %s" % character_id)
	return null

static func _skill_contract_pool(character_id: String) -> Array[Dictionary]:
	var baseline = _character_baseline(character_id)
	var descriptors: Array[Dictionary] = baseline.regular_skill_contracts()
	descriptors.append(baseline.ultimate_skill_contract())
	return descriptors

static func _passive_contract_pool(character_id: String) -> Array[Dictionary]:
	return [_character_baseline(character_id).passive_skill_contract()]

static func _resolve_descriptor(raw_descriptor: Dictionary, label_override: String = "") -> Dictionary:
	assert(not raw_descriptor.is_empty(), "Formal character baseline descriptor must not be empty")
	var descriptor: Dictionary = raw_descriptor.duplicate(true)
	if not label_override.is_empty():
		descriptor["label"] = label_override
	return descriptor

static func _resolve_descriptor_array(descriptor_pool: Array[Dictionary], id_key: String, requested_ids) -> Array[Dictionary]:
	var resolved_ids := PackedStringArray(requested_ids)
	if resolved_ids.is_empty():
		for raw_descriptor in descriptor_pool:
			var descriptor: Dictionary = raw_descriptor
			resolved_ids.append(String(descriptor.get(id_key, "")))
	var descriptors: Array[Dictionary] = []
	for raw_id in resolved_ids:
		descriptors.append(_resolve_descriptor(_find_descriptor(descriptor_pool, id_key, String(raw_id))))
	return descriptors

static func _find_descriptor(descriptor_pool: Array[Dictionary], id_key: String, requested_id: String) -> Dictionary:
	var normalized_id := requested_id.strip_edges()
	assert(not normalized_id.is_empty(), "Formal character baseline lookup id must not be empty")
	for raw_descriptor in descriptor_pool:
		var descriptor: Dictionary = raw_descriptor
		if String(descriptor.get(id_key, "")) == normalized_id:
			return descriptor
	return {}
