extends RefCounted
class_name RngService

const RNG_PROFILE := "godot_random_number_generator_v1"

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _seed: int = 0
var _stream_index: int = 0

func reset(seed_value: int) -> void:
    _seed = seed_value
    _stream_index = 0
    _rng.seed = seed_value

func next_float() -> float:
    _stream_index += 1
    return _rng.randf()

func get_profile() -> String:
    return RNG_PROFILE

func get_stream_index() -> int:
    return _stream_index

func get_seed() -> int:
    return _seed
