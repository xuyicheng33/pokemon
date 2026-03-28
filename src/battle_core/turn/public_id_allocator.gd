extends RefCounted
class_name PublicIdAllocator

func build_public_id(side_id: String, slot_index: int) -> String:
    var normalized_side_id := side_id.strip_edges()
    assert(not normalized_side_id.is_empty(), "PublicIdAllocator requires non-empty side_id")
    assert(slot_index >= 0, "PublicIdAllocator requires slot_index >= 0, got %d" % slot_index)
    return "%s-%s" % [normalized_side_id, _build_label(slot_index)]

func _build_label(slot_index: int) -> String:
    var alphabet_size := 26
    var value := slot_index
    var reversed_chars: Array[String] = []
    while true:
        var remainder := value % alphabet_size
        reversed_chars.append(char(65 + remainder))
        value = int(value / alphabet_size) - 1
        if value < 0:
            break
    reversed_chars.reverse()
    return "".join(reversed_chars)
