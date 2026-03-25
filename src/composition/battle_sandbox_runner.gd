extends Node
class_name BattleSandboxRunner

const BattleCoreComposerScript := preload("res://src/composition/battle_core_composer.gd")
const SampleBattleFactoryScript := preload("res://src/composition/sample_battle_factory.gd")
const BattleUIViewModelBuilderScript := preload("res://src/adapters/battle_ui_view_model_builder.gd")

var composer
var core

func _ready() -> void:
    composer = BattleCoreComposerScript.new()
    core = composer.compose()
    var sample_factory: Variant = SampleBattleFactoryScript.new()
    var replay_input = sample_factory.build_demo_replay_input(core.command_builder)
    var replay_output = core.replay_runner.run_replay(replay_input)
    var view_model = BattleUIViewModelBuilderScript.new().build_view_model(replay_output.final_battle_state)
    print("Battle sandbox ready: %s hash=%s events=%d phase=%s" % [
        replay_output.final_battle_state.battle_id,
        replay_output.final_state_hash.substr(0, 12),
        replay_output.event_log.size(),
        view_model["phase"],
    ])
