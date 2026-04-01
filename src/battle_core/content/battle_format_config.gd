extends Resource
class_name BattleFormatConfig

@export var format_id: String = ""
@export var visibility_mode: String = "prototype_full_open"
@export var max_turn: int = 40
@export var team_size: int = 3
@export var level: int = 50
@export var selection_deadline_ms: int = 30000
@export var max_chain_depth: int = 32
@export_range(0.0, 1.0, 0.01) var default_recoil_ratio: float = 0.25
@export_range(0.0, 1.0, 0.01) var domain_clash_tie_threshold: float = 0.5
@export var combat_type_chart: Array[Resource] = []
