extends SceneTree

## 固定 Obito 案例 runner（与 domain_case_runner / kashimo_case_runner 形态一致）。
##
## 当前 case：`yinyang_dun_segment_guard`——Obito 开阴阳遁吃下敌方 2 段 multihit
## skill，对照 baseline（不开阴阳遁）验证：(1) 受到伤害严格更小；(2) 阴阳之力
## 叠到 3 层（cast 期 1 + 2 段命中各 1）；(3) 防御 +1 / 特防 +1。这与
## `test/suites/obito_runtime_yinyang_suite.gd::test_obito_yinyang_dun_segment_mitigation_and_stack_contract`
## 同形态，但 case runner 是独立 SceneTree 入口，便于 sandbox smoke matrix
## 在不启动 gdUnit4 的情况下快速复查 deterministic 行为。

const BattleCoreTestHarnessScript := preload("res://tests/support/battle_core_test_harness.gd")
const ObitoTestSupportScript := preload("res://tests/support/obito_test_support.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const SkillDamageSegmentScript := preload("res://src/battle_core/content/skill_damage_segment.gd")

const FAIL_PREFIX := "BATTLE_OBITO_CASE_FAILED:"

var _harness := BattleCoreTestHarnessScript.new()
var _support := ObitoTestSupportScript.new()


func _init() -> void:
	var case_name := str(OS.get_environment("CASE")).strip_edges().to_lower()
	if case_name.is_empty():
		case_name = "all"
	var any_failed := _run_cases(case_name)
	_dispose_harness()
	if any_failed:
		quit(1)
	else:
		quit(0)


func _dispose_harness() -> void:
	_harness.dispose_sample_factories()
	_harness.dispose_core_pool()


func _run_cases(case_name: String) -> bool:
	var cases := [
		"yinyang_dun_segment_guard",
	]
	var any_failed := false
	for fixed_case in cases:
		if case_name != "all" and case_name != fixed_case:
			continue
		var result := _run_case(fixed_case)
		print("%s %s" % [fixed_case, JSON.stringify(result)])
		if not bool(result.get("ok", false)):
			push_error("%s case=%s payload=%s" % [FAIL_PREFIX, fixed_case, JSON.stringify(result)])
			any_failed = true
	return any_failed


func _run_case(case_name: String) -> Dictionary:
	match case_name:
		"yinyang_dun_segment_guard":
			return _run_yinyang_dun_segment_guard()
		_:
			return {"ok": false, "error": "unknown case: %s" % case_name}


func _run_yinyang_dun_segment_guard() -> Dictionary:
	var baseline_result := _run_yinyang_guard_inner(false, 1521)
	if not bool(baseline_result.get("ok", false)):
		return baseline_result
	var guarded_result := _run_yinyang_guard_inner(true, 1522)
	if not bool(guarded_result.get("ok", false)):
		return guarded_result
	var baseline_hp_loss: int = int(baseline_result.get("hp_loss", -1))
	var guarded_hp_loss: int = int(guarded_result.get("hp_loss", -1))
	if guarded_hp_loss >= baseline_hp_loss:
		return {
			"ok": false,
			"error": "obito_yinyang_dun should reduce incoming multihit damage (baseline=%d guarded=%d)" % [baseline_hp_loss, guarded_hp_loss],
			"hp_loss_baseline": baseline_hp_loss,
			"hp_loss_guarded": guarded_hp_loss,
		}
	if int(guarded_result.get("yinyang_count", -1)) != 3:
		return {
			"ok": false,
			"error": "obito_yinyang_dun should leave obito at 3 stacks after cast + 2 received segments",
			"yinyang_count": guarded_result.get("yinyang_count"),
		}
	if int(guarded_result.get("defense_stage", -1)) != 1 or int(guarded_result.get("sp_defense_stage", -1)) != 1:
		return {
			"ok": false,
			"error": "obito_yinyang_dun should grant defense+1 / sp_defense+1",
			"defense_stage": guarded_result.get("defense_stage"),
			"sp_defense_stage": guarded_result.get("sp_defense_stage"),
		}
	return {
		"ok": true,
		"hp_loss_baseline": baseline_hp_loss,
		"hp_loss_guarded": guarded_hp_loss,
		"yinyang_count": int(guarded_result.get("yinyang_count", 0)),
		"defense_stage": int(guarded_result.get("defense_stage", 0)),
		"sp_defense_stage": int(guarded_result.get("sp_defense_stage", 0)),
		"log_size": int(guarded_result.get("log_size", 0)),
	}


func _run_yinyang_guard_inner(use_guard: bool, battle_seed: int) -> Dictionary:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		return {"ok": false, "error": str(core_payload["error"])}
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		return {"ok": false, "error": "SampleBattleFactory init failed"}
	var content_index = _harness.build_loaded_content_index(sample_factory)
	var skill = _build_enemy_multihit_skill("test_obito_case_runner_multihit_skill")
	content_index.register_resource(skill)
	content_index.units["sample_pyron"].skill_ids[0] = skill.id
	var battle_state = _support.build_battle_state(core, content_index, _support.build_obito_setup(sample_factory), battle_seed)
	var obito = battle_state.get_side("P1").get_active_unit()
	var target = battle_state.get_side("P2").get_active_unit()
	if obito == null or target == null:
		return {"ok": false, "error": "missing active units for obito case runner"}
	var before_hp := int(obito.current_hp)
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_skill_command(core, 1, "P1", "P1-A", "obito_yinyang_dun") if use_guard else _support.build_manual_wait_command(core, 1, "P1", "P1-A"),
		_support.build_manual_skill_command(core, 1, "P2", "P2-A", skill.id),
	])
	return {
		"ok": true,
		"hp_loss": before_hp - int(obito.current_hp),
		"yinyang_count": _support.count_effect_instances(obito, "obito_yinyang_zhili"),
		"defense_stage": int(obito.get_effective_stage("defense")),
		"sp_defense_stage": int(obito.get_effective_stage("sp_defense")),
		"log_size": core.service("battle_logger").event_log.size(),
	}


func _build_enemy_multihit_skill(skill_id: String):
	var skill = SkillDefinitionScript.new()
	skill.id = skill_id
	skill.display_name = skill_id
	skill.damage_kind = "special"
	skill.power = 20
	skill.accuracy = 100
	skill.mp_cost = 0
	skill.priority = 0
	skill.combat_type_id = ""
	skill.targeting = "enemy_active_slot"
	var segment = SkillDamageSegmentScript.new()
	segment.repeat_count = 2
	segment.power = 20
	segment.combat_type_id = "fire"
	segment.damage_kind = "special"
	skill.damage_segments.append(segment)
	return skill
