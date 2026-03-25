extends RefCounted
class_name UnitState

var unit_instance_id: String = ""
var public_id: String = ""
var definition_id: String = ""
var current_hp: int = 0
var current_mp: int = 0
var stat_stages: Dictionary = {}
var effect_instances: Array = []
var rule_mod_instances: Array = []
var has_acted: bool = false
var action_window_passed: bool = false
var leave_state: String = "active"
