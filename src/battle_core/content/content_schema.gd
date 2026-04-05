extends RefCounted
class_name ContentSchema

const DAMAGE_KIND_PHYSICAL := "physical"
const DAMAGE_KIND_SPECIAL := "special"
const DAMAGE_KIND_NONE := "none"

const TARGET_ENEMY_ACTIVE := "enemy_active_slot"
const TARGET_SELF := "self"
const TARGET_FIELD := "field"
const TARGET_NONE := "none"

const ACTIVE_SLOT_PRIMARY := "active_0"

const DURATION_TURNS := "turns"
const DURATION_PERMANENT := "permanent"

const STACKING_NONE := "none"
const STACKING_REFRESH := "refresh"
const STACKING_REPLACE := "replace"
const STACKING_STACK := "stack"

const FIELD_KIND_NORMAL := "normal"
const FIELD_KIND_DOMAIN := "domain"

const TRIGGER_FIELD_APPLY_SUCCESS := "field_apply_success"
const TRIGGER_ON_RECEIVE_ACTION_HIT := "on_receive_action_hit"
const TRIGGER_ON_RECEIVE_ACTION_DAMAGE_SEGMENT := "on_receive_action_damage_segment"

const RULE_MOD_FINAL_MOD := "final_mod"
const RULE_MOD_MP_REGEN := "mp_regen"
const RULE_MOD_ACTION_LEGALITY := "action_legality"
const RULE_MOD_INCOMING_ACCURACY := "incoming_accuracy"
const RULE_MOD_NULLIFY_FIELD_ACCURACY := "nullify_field_accuracy"
const RULE_MOD_INCOMING_ACTION_FINAL_MOD := "incoming_action_final_mod"
const RULE_MOD_INCOMING_HEAL_FINAL_MOD := "incoming_heal_final_mod"

const ACTION_LEGALITY_ALL := "all"
const ACTION_LEGALITY_SKILL := "skill"
const ACTION_LEGALITY_ULTIMATE := "ultimate"
const ACTION_LEGALITY_SWITCH := "switch"
static var MANAGED_ACTION_TYPES := PackedStringArray([
	ACTION_LEGALITY_SKILL,
	ACTION_LEGALITY_ULTIMATE,
	ACTION_LEGALITY_SWITCH,
])
static var ALWAYS_ALLOWED_ACTION_TYPES := PackedStringArray([
	"wait",
	"resource_forced_default",
	"surrender",
])

const RULE_MOD_VALUE_FORMULA_MATCHUP_BST_GAP_BAND := "matchup_bst_gap_band"
