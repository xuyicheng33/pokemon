extends RefCounted
class_name FormalCharacterManifestPairCatalog

const PairInteractionsScript := preload("res://src/shared/formal_character_manifest/formal_character_manifest_pair_interactions.gd")
const PairMatchupsScript := preload("res://src/shared/formal_character_manifest/formal_character_manifest_pair_matchups.gd")

var _pair_interactions = PairInteractionsScript.new()
var _pair_matchups = PairMatchupsScript.new()

func build_catalog_result(characters: Array, raw_matchups, pair_interaction_specs: Array, manifest_path: String) -> Dictionary:
	var pair_maps_result := _pair_matchups.build_pair_maps_result(characters, manifest_path)
	if not bool(pair_maps_result.get("ok", false)):
		return pair_maps_result
	var pair_maps: Dictionary = pair_maps_result.get("data", {})
	var explicit_matchups_result := _pair_matchups.normalize_explicit_matchups_result(raw_matchups, pair_maps, manifest_path)
	if not bool(explicit_matchups_result.get("ok", false)):
		return explicit_matchups_result
	var merged_matchups_result := _pair_matchups.merged_matchups_result(
		pair_maps,
		explicit_matchups_result.get("data", {}),
		manifest_path
	)
	if not bool(merged_matchups_result.get("ok", false)):
		return merged_matchups_result
	var merged_matchups: Dictionary = merged_matchups_result.get("data", {})
	var interaction_cases_result := _pair_interactions.derive_pair_interaction_cases_result(
		pair_interaction_specs,
		pair_maps,
		merged_matchups,
		manifest_path
	)
	if not bool(interaction_cases_result.get("ok", false)):
		return interaction_cases_result
	return _ok_result({
		"matchups": merged_matchups,
		"pair_interaction_cases": interaction_cases_result.get("data", []).duplicate(true),
	})

func _ok_result(data) -> Dictionary:
	return {
		"ok": true,
		"data": data,
		"error_code": null,
		"error_message": null,
	}
