extends RefCounted
class_name ChainContext

var event_chain_id: String = ""
var root_action_id: Variant = null
var chain_origin: String = ""
var step_counter: int = 0
var action_queue_index: Variant = null
var actor_id: Variant = null
var command_type: Variant = null
var command_source: Variant = null
var select_timeout: Variant = null
var select_deadline_ms: Variant = null
var target_unit_id: Variant = null
var target_slot: Variant = null

func copy_shallow():
    var clone = self.get_script().new()
    clone.event_chain_id = event_chain_id
    clone.root_action_id = root_action_id
    clone.chain_origin = chain_origin
    clone.step_counter = step_counter
    clone.action_queue_index = action_queue_index
    clone.actor_id = actor_id
    clone.command_type = command_type
    clone.command_source = command_source
    clone.select_timeout = select_timeout
    clone.select_deadline_ms = select_deadline_ms
    clone.target_unit_id = target_unit_id
    clone.target_slot = target_slot
    return clone
