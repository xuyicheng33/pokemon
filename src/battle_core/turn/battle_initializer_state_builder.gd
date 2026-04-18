extends RefCounted
class_name BattleInitializerStateBuilder

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const SideStateScript := preload("res://src/battle_core/runtime/side_state.gd")
const SelectionStateScript := preload("res://src/battle_core/contracts/selection_state.gd")
const UnitStateScript := preload("res://src/battle_core/runtime/unit_state.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const ErrorStateHelperScript := preload("res://src/shared/error_state_helper.gd")

var last_error_code: Variant = null
var last_error_message: String = ""

func error_state() -> Dictionary:
	return ErrorStateHelperScript.error_state(self)

func build_side_state(side_setup, format_config, content_index, id_factory, public_id_allocator) -> Variant:
	ErrorStateHelperScript.clear(self)
	if side_setup == null:
		return _fail(ErrorCodesScript.INVALID_BATTLE_SETUP, "BattleInitializerStateBuilder requires side_setup")
	if format_config == null:
		return _fail(ErrorCodesScript.INVALID_BATTLE_SETUP, "BattleInitializerStateBuilder requires format_config")
	if content_index == null:
		return _fail(ErrorCodesScript.INVALID_CONTENT_SNAPSHOT, "BattleInitializerStateBuilder requires content_index")
	if id_factory == null:
		return _fail(ErrorCodesScript.INVALID_STATE_CORRUPTION, "BattleInitializerStateBuilder requires id_factory")
	if public_id_allocator == null:
		return _fail(ErrorCodesScript.INVALID_STATE_CORRUPTION, "BattleInitializerStateBuilder requires public_id_allocator")
	if side_setup.unit_definition_ids.size() != format_config.team_size:
		return _fail(ErrorCodesScript.INVALID_BATTLE_SETUP, "Side %s must provide exactly %d units" % [side_setup.side_id, format_config.team_size])
	if side_setup.starting_index < 0 or side_setup.starting_index >= side_setup.unit_definition_ids.size():
		return _fail(ErrorCodesScript.INVALID_BATTLE_SETUP, "Invalid starting index for %s" % side_setup.side_id)
	var side_state = SideStateScript.new()
	side_state.side_id = side_setup.side_id
	side_state.selection_state = SelectionStateScript.new()
	for unit_index in range(side_setup.unit_definition_ids.size()):
		var unit_definition_id = side_setup.unit_definition_ids[unit_index]
		var unit_definition = content_index.units.get(unit_definition_id)
		if unit_definition == null:
			return _fail(ErrorCodesScript.INVALID_CONTENT_SNAPSHOT, "Missing unit definition: %s" % unit_definition_id)
		var unit_state = UnitStateScript.new()
		unit_state.unit_instance_id = id_factory.next_id("unit")
		unit_state.public_id = public_id_allocator.build_public_id(side_setup.side_id, unit_index)
		unit_state.definition_id = unit_definition.id
		unit_state.display_name = unit_definition.display_name
		unit_state.max_hp = unit_definition.base_hp
		unit_state.current_hp = unit_definition.base_hp
		unit_state.max_mp = unit_definition.max_mp
		unit_state.current_mp = unit_definition.init_mp
		unit_state.regen_per_turn = unit_definition.regen_per_turn
		unit_state.ultimate_points = 0
		unit_state.ultimate_points_cap = unit_definition.ultimate_points_cap
		unit_state.ultimate_points_required = unit_definition.ultimate_points_required
		unit_state.ultimate_point_gain_on_regular_skill_cast = unit_definition.ultimate_point_gain_on_regular_skill_cast
		unit_state.regular_skill_ids = _resolve_regular_skill_loadout(side_setup, unit_index, unit_definition)
		if last_error_code != null:
			return null
		unit_state.combat_type_ids = unit_definition.combat_type_ids.duplicate()
		unit_state.base_attack = unit_definition.base_attack
		unit_state.base_defense = unit_definition.base_defense
		unit_state.base_sp_attack = unit_definition.base_sp_attack
		unit_state.base_sp_defense = unit_definition.base_sp_defense
		unit_state.base_speed = unit_definition.base_speed
		unit_state.last_effective_speed = unit_definition.base_speed
		side_state.public_labels[unit_state.unit_instance_id] = unit_state.public_id
		side_state.team_units.append(unit_state)
		if unit_index == side_setup.starting_index:
			side_state.set_active_unit(ContentSchemaScript.ACTIVE_SLOT_PRIMARY, unit_state.unit_instance_id)
		else:
			side_state.bench_order.append(unit_state.unit_instance_id)
	return side_state

func _resolve_regular_skill_loadout(side_setup, unit_index: int, unit_definition) -> PackedStringArray:
	if side_setup.regular_skill_loadout_overrides.has(unit_index):
		var override_loadout: PackedStringArray = side_setup.regular_skill_loadout_overrides[unit_index]
		if override_loadout.size() != 3:
			ErrorStateHelperScript.fail(self, ErrorCodesScript.INVALID_BATTLE_SETUP, "Invalid regular skill loadout size for side %s slot %d" % [side_setup.side_id, unit_index])
			return PackedStringArray()
		return override_loadout.duplicate()
	if unit_definition.skill_ids.size() != 3:
		ErrorStateHelperScript.fail(self, ErrorCodesScript.INVALID_CONTENT_SNAPSHOT, "UnitDefinition.skill_ids must remain 3-slot default loadout for %s" % unit_definition.id)
		return PackedStringArray()
	return unit_definition.skill_ids.duplicate()

func _fail(error_code: String, message: String) -> Variant:
	ErrorStateHelperScript.fail(self, error_code, message)
	return null
