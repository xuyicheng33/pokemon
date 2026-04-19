extends RefCounted

const ALLOWED_STAT_NAMES := [
	"attack",
	"defense",
	"sp_attack",
	"sp_defense",
	"speed",
]
const ALLOWED_STAT_RETENTION_MODES := ["normal", "persist_on_switch"]

func validate(errors: Array, effect_id: String, payload, _content_index: BattleContentIndex, _dispatcher) -> void:
	if not ALLOWED_STAT_NAMES.has(String(payload.stat_name)):
		errors.append("effect[%s].stat_mod invalid stat_name: %s" % [effect_id, payload.stat_name])
	if not ALLOWED_STAT_RETENTION_MODES.has(String(payload.retention_mode)):
		errors.append("effect[%s].stat_mod invalid retention_mode: %s" % [effect_id, String(payload.retention_mode)])
