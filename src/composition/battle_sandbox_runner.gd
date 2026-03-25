extends Node
class_name BattleSandboxRunner

const BattleCoreComposerScript := preload("res://src/composition/battle_core_composer.gd")
const BattleStateScript := preload("res://src/battle_core/runtime/battle_state.gd")
const BattleContentIndexScript := preload("res://src/battle_core/content/battle_content_index.gd")

var composer
var core
var battle_state
var content_index

func _ready() -> void:
    composer = BattleCoreComposerScript.new()
    core = composer.compose()
    battle_state = BattleStateScript.new()
    content_index = BattleContentIndexScript.new()
    battle_state.battle_id = core.id_factory.next_id("battle")
    battle_state.seed = 1
    core.rng_service.reset(battle_state.seed)
    battle_state.rng_stream_index = core.rng_service.get_stream_index()
    print("Battle sandbox ready: %s" % battle_state.battle_id)
