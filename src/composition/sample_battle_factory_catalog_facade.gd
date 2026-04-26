extends RefCounted
class_name SampleBattleFactoryCatalogFacade

var available_matchup_aggregator: SampleBattleFactoryAvailableMatchupAggregator = null
var formal_access: SampleBattleFactoryFormalAccess = null

func available_matchups_result() -> Dictionary:
	return available_matchup_aggregator.available_matchups_result()

func formal_character_ids_result() -> Dictionary:
	return formal_access.formal_ids_result("character_id")

func formal_unit_definition_ids_result() -> Dictionary:
	return formal_access.formal_ids_result("unit_definition_id")

func formal_pair_smoke_cases_result() -> Dictionary:
	return formal_access.formal_pair_smoke_cases_result()

func formal_pair_surface_cases_result() -> Dictionary:
	return formal_access.formal_pair_surface_cases_result()

func formal_pair_interaction_cases_result() -> Dictionary:
	return formal_access.formal_pair_interaction_cases_result()
