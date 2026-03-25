extends RefCounted
class_name BattleState

var battle_id: String = ""
@warning_ignore("shadowed_global_identifier")
var seed: int = 0
var rng_state: Dictionary = {}
var turn_index: int = 0
var phase: String = "init"
var sides: Array = []
var field_state = null
var pending_effect_queue: Array = []
var chain_context = null
var battle_result = null
var rng_stream_index: int = 0
