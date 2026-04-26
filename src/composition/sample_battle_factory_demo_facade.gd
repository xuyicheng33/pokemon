extends RefCounted
class_name SampleBattleFactoryDemoFacade

var demo_catalog: SampleBattleFactoryDemoCatalog = null
var demo_input_builder: SampleBattleFactoryDemoInputBuilder = null

func default_demo_profile_id_result() -> Dictionary:
	return demo_catalog.default_profile_id_result()

func demo_profile_result(profile_id: String) -> Dictionary:
	return demo_catalog.profile_result(profile_id)

func demo_profile_ids_result() -> Dictionary:
	return demo_catalog.profile_ids_result()

func build_demo_replay_input_result(command_port, side_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	return demo_input_builder.build_demo_replay_input_result(command_port, side_regular_skill_overrides)

func build_demo_replay_input_for_profile_result(command_port, demo_profile_id: String, side_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	return demo_input_builder.build_demo_replay_input_for_profile_result(command_port, demo_profile_id, side_regular_skill_overrides)

func build_passive_item_demo_replay_input_result(command_port) -> Dictionary:
	return demo_input_builder.build_passive_item_demo_replay_input_result(command_port)
