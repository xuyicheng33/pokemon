extends RefCounted
class_name UnitBstHelper

static func sum_unit_bst(unit_state) -> int:
	if unit_state == null:
		return 0
	# 正式 BST 口径把 max_mp 视为第七维；宿傩回蓝公式与设计稿都依赖这个假设。
	return int(unit_state.max_hp) \
	+ int(unit_state.base_attack) \
	+ int(unit_state.base_defense) \
	+ int(unit_state.base_sp_attack) \
	+ int(unit_state.base_sp_defense) \
	+ int(unit_state.base_speed) \
	+ int(unit_state.max_mp)
