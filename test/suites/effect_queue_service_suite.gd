extends GdUnitTestSuite

const EffectQueueServiceScript := preload("res://src/battle_core/effects/effect_queue_service.gd")
const EffectEventScript := preload("res://src/battle_core/contracts/effect_event.gd")

class SequenceRngService:
	extends "res://src/shared/rng_service.gd"

	var rolls: Array = []
	var next_index: int = 0

	func next_float() -> float:
		var roll := float(rolls[next_index])
		next_index += 1
		return roll

func test_sort_events_cross_source_speed_tie_uses_source_instance_id_contract() -> void:
	var service = EffectQueueServiceScript.new()
	var rng := SequenceRngService.new()
	rng.rolls = []
	var left = _build_effect_event("event_a", "source_b")
	var right = _build_effect_event("event_b", "source_a")
	var sorted_events: Array = service.sort_events([left, right], rng)
	assert_int(sorted_events.size()).is_equal(2)
	assert_str(String(sorted_events[0].event_id)).is_equal("event_b")
	assert_str(String(sorted_events[1].event_id)).is_equal("event_a")

func test_sort_events_same_source_speed_tie_uses_random_tiebreak_contract() -> void:
	var service = EffectQueueServiceScript.new()
	var rng := SequenceRngService.new()
	rng.rolls = [0.8, 0.2]
	var left = _build_effect_event("event_a", "shared_source")
	var right = _build_effect_event("event_b", "shared_source")
	var sorted_events: Array = service.sort_events([left, right], rng)
	assert_int(sorted_events.size()).is_equal(2)
	assert_str(String(sorted_events[0].event_id)).is_equal("event_b")
	assert_str(String(sorted_events[1].event_id)).is_equal("event_a")
	assert_float(float(left.sort_random_roll)).is_equal(0.8)
	assert_float(float(right.sort_random_roll)).is_equal(0.2)

func _build_effect_event(event_id: String, source_instance_id: String):
	var effect_event = EffectEventScript.new()
	effect_event.event_id = event_id
	effect_event.priority = 0
	effect_event.source_order_speed_snapshot = 120
	effect_event.source_kind_order = 1
	effect_event.source_instance_id = source_instance_id
	return effect_event
