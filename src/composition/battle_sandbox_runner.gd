extends Node
class_name BattleSandboxRunner

const BattleCoreComposerScript := preload("res://src/composition/battle_core_composer.gd")
const SampleBattleFactoryScript := preload("res://src/composition/sample_battle_factory.gd")
const BattleUIViewModelBuilderScript := preload("res://src/adapters/battle_ui_view_model_builder.gd")

var composer
var facade

func _ready() -> void:
    composer = BattleCoreComposerScript.new()
    facade = composer.compose_facade()
    var sample_factory: Variant = SampleBattleFactoryScript.new()
    var replay_input = sample_factory.build_demo_replay_input(facade)
    var replay_result: Dictionary = facade.run_replay(replay_input)
    var replay_output = replay_result["replay_output"]
    var view_model = BattleUIViewModelBuilderScript.new().build_view_model(replay_result["public_snapshot"])
    print("Battle sandbox ready: %s hash=%s events=%d phase=%s" % [
        view_model["battle_id"],
        replay_output.final_state_hash.substr(0, 12),
        replay_output.event_log.size(),
        view_model["phase"],
    ])
