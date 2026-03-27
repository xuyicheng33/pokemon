extends RefCounted
class_name LegalActionSet

var actor_id: String = ""
var legal_skill_ids: PackedStringArray = PackedStringArray()
var legal_switch_target_ids: PackedStringArray = PackedStringArray()
var legal_ultimate_ids: PackedStringArray = PackedStringArray()
var wait_allowed: bool = false
var forced_command_type: String = ""
