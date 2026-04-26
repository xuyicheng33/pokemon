extends "res://tests/support/gdunit_suite_bridge.gd"

const EventTypesScript := preload("res://src/shared/event_types.gd")
const SukunaTestSupportScript := preload("res://tests/support/sukuna_test_support.gd")

var _support = SukunaTestSupportScript.new()


func test_sukuna_domain_expire_chain_path() -> void:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var content_index = _harness.build_loaded_content_index(sample_factory)
	var battle_setup = _build_sukuna_setup(sample_factory)
	var battle_state = _build_battle_state(core, content_index, battle_setup, 704)
	var sukuna_unit = battle_state.get_side("P1").get_active_unit()
	var target_unit = battle_state.get_side("P2").get_active_unit()
	if sukuna_unit == null or target_unit == null:
		fail("missing active units for domain expire test")
		return
	sukuna_unit.current_mp = sukuna_unit.max_mp
	sukuna_unit.ultimate_points = sukuna_unit.ultimate_points_cap
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_build_manual_ultimate_command(core, 1, "P1", "P1-A", "sukuna_fukuma_mizushi"),
		_build_manual_wait_command(core, 1, "P2", "P2-A"),
	])
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_build_manual_wait_command(core, 2, "P1", "P1-A"),
		_build_manual_wait_command(core, 2, "P2", "P2-A"),
	])
	var hp_before_expire: int = target_unit.current_hp
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_build_manual_wait_command(core, 3, "P1", "P1-A"),
		_build_manual_wait_command(core, 3, "P2", "P2-A"),
	])
	if battle_state.field_state != null:
		fail("malevolent shrine should expire after third turn")
		return
	var expected_expire_damage := _calc_expected_fixed_effect_damage(core, content_index, "sukuna_domain_expire_burst", target_unit)
	if hp_before_expire - target_unit.current_hp != expected_expire_damage:
		fail("malevolent shrine expire burst damage mismatch: delta=%d expected=%d" % [
			hp_before_expire - target_unit.current_hp,
			expected_expire_damage,
		])
		return
	if int(sukuna_unit.stat_stages.get("attack", 0)) != 0 or int(sukuna_unit.stat_stages.get("sp_attack", 0)) != 0:
		fail("malevolent shrine 自然到期后应移除领域绑定增幅")
		return
	var legal_action_set = core.service("legal_action_service").get_legal_actions(battle_state, "P1", content_index)
	if not legal_action_set.legal_skill_ids.has("sukuna_kai") \
	or not legal_action_set.legal_skill_ids.has("sukuna_hatsu") \
	or not legal_action_set.legal_skill_ids.has("sukuna_hiraku"):
		fail("domain expire should not seal sukuna normal skills after removing post-domain cooldown")
		return
	var has_field_expire_log: bool = false
	for log_event in core.service("battle_logger").event_log:
		if log_event.event_type == EventTypesScript.EFFECT_FIELD_EXPIRE:
			has_field_expire_log = true
			break
	if not has_field_expire_log:
		fail("domain expire log missing")
		return

func test_sukuna_domain_break_chain_path() -> void:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var content_index = _harness.build_loaded_content_index(sample_factory)
	var battle_setup = _build_sukuna_setup(sample_factory)
	var battle_state = _build_battle_state(core, content_index, battle_setup, 705)
	var sukuna_unit = battle_state.get_side("P1").get_active_unit()
	var target_unit = battle_state.get_side("P2").get_active_unit()
	if sukuna_unit == null or target_unit == null:
		fail("missing active units for domain break test")
		return
	sukuna_unit.current_mp = sukuna_unit.max_mp
	sukuna_unit.ultimate_points = sukuna_unit.ultimate_points_cap
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_build_manual_ultimate_command(core, 1, "P1", "P1-A", "sukuna_fukuma_mizushi"),
		_build_manual_wait_command(core, 1, "P2", "P2-A"),
	])
	var hp_before_break: int = target_unit.current_hp
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_build_manual_switch_command(core, 2, "P1", "P1-A", "P1-B"),
		_build_manual_wait_command(core, 2, "P2", "P2-A"),
	])
	if battle_state.field_state != null:
		fail("malevolent shrine should break when creator leaves active slot")
		return
	if target_unit.current_hp != hp_before_break:
		fail("field break should not trigger expire burst damage")
		return
	if int(sukuna_unit.stat_stages.get("attack", 0)) != 0 or int(sukuna_unit.stat_stages.get("sp_attack", 0)) != 0:
		fail("malevolent shrine 打断后领域绑定增幅必须消失")
		return
	for log_event in core.service("battle_logger").event_log:
		if log_event.event_type == EventTypesScript.EFFECT_FIELD_EXPIRE:
			fail("field break should not emit natural expire log")
			return
		if log_event.event_type == EventTypesScript.EFFECT_RULE_MOD_APPLY and String(log_event.payload_summary).find("action_legality") != -1:
			fail("field break should not apply any post-domain seal rule_mod")
			return

func test_sukuna_domain_break_on_faint_path() -> void:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var content_index = _harness.build_loaded_content_index(sample_factory)
	var battle_setup = _build_sukuna_setup(sample_factory)
	var battle_state = _build_battle_state(core, content_index, battle_setup, 709)
	var sukuna_unit = battle_state.get_side("P1").get_active_unit()
	var target_unit = battle_state.get_side("P2").get_active_unit()
	if sukuna_unit == null or target_unit == null:
		fail("missing active units for domain faint break test")
		return
	sukuna_unit.current_mp = sukuna_unit.max_mp
	sukuna_unit.ultimate_points = sukuna_unit.ultimate_points_cap
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_build_manual_ultimate_command(core, 1, "P1", "P1-A", "sukuna_fukuma_mizushi"),
		_build_manual_wait_command(core, 1, "P2", "P2-A"),
	])
	sukuna_unit.current_hp = 1
	var target_hp_before_faint_break: int = target_unit.current_hp
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_build_manual_wait_command(core, 2, "P1", "P1-A"),
		_build_manual_skill_command(core, 2, "P2", "P2-A", "sample_strike"),
	])
	if battle_state.field_state != null:
		fail("malevolent shrine should break immediately when creator faints")
		return
	if target_unit.current_hp != target_hp_before_faint_break:
		fail("creator faint break should not trigger domain natural expire burst")
		return
	for log_event in core.service("battle_logger").event_log:
		if log_event.event_type == EventTypesScript.EFFECT_FIELD_EXPIRE:
			fail("creator faint break should not emit natural field expire log")
			return

func test_sukuna_field_accuracy_override_path() -> void:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var content_index = _harness.build_loaded_content_index(sample_factory)
	content_index.skills["sukuna_hiraku"].accuracy = 0
	var battle_setup = _build_sukuna_setup(sample_factory)
	var battle_state = _build_battle_state(core, content_index, battle_setup, 706)
	var sukuna_unit = battle_state.get_side("P1").get_active_unit()
	var target_unit = battle_state.get_side("P2").get_active_unit()
	if sukuna_unit == null or target_unit == null:
		fail("missing active units for field accuracy override test")
		return
	sukuna_unit.current_mp = sukuna_unit.max_mp
	sukuna_unit.ultimate_points = sukuna_unit.ultimate_points_cap
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_build_manual_ultimate_command(core, 1, "P1", "P1-A", "sukuna_fukuma_mizushi"),
		_build_manual_wait_command(core, 1, "P2", "P2-A"),
	])
	var hp_before_cast: int = target_unit.current_hp
	sukuna_unit.current_mp = sukuna_unit.max_mp
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_build_manual_skill_command(core, 2, "P1", "P1-A", "sukuna_hiraku"),
		_build_manual_wait_command(core, 2, "P2", "P2-A"),
	])
	if target_unit.current_hp >= hp_before_cast:
		fail("field accuracy override should let zero-accuracy hiraku hit while domain is active")
		return

func test_sukuna_domain_failed_clash_no_field_no_buff_no_expire_burst_contract() -> void:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var content_index = _harness.build_loaded_content_index(sample_factory)
	var battle_setup = _build_sukuna_vs_gojo_setup(sample_factory)
	var battle_state = _build_battle_state(core, content_index, battle_setup, 710)
	var sukuna_unit = battle_state.get_side("P1").get_active_unit()
	var gojo_unit = battle_state.get_side("P2").get_active_unit()
	if sukuna_unit == null or gojo_unit == null:
		fail("missing active units for sukuna failed clash contract")
		return
	sukuna_unit.current_mp = 80
	sukuna_unit.ultimate_points = sukuna_unit.ultimate_points_cap
	gojo_unit.current_mp = gojo_unit.max_mp
	gojo_unit.ultimate_points = gojo_unit.ultimate_points_cap
	gojo_unit.base_speed = 999
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_build_manual_ultimate_command(core, 1, "P1", "P1-A", "sukuna_fukuma_mizushi"),
		_build_manual_ultimate_command(core, 1, "P2", "P2-A", "gojo_unlimited_void"),
	])
	if battle_state.field_state == null or battle_state.field_state.field_def_id != "gojo_unlimited_void_field":
		fail("宿傩对拼失败后，场上不应留下伏魔御厨子")
		return
	if int(sukuna_unit.stat_stages.get("attack", 0)) != 0 or int(sukuna_unit.stat_stages.get("sp_attack", 0)) != 0:
		fail("宿傩对拼失败后，不应保留领域双攻增幅")
		return
	var gojo_hp_before_expire_window: int = gojo_unit.current_hp
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_build_manual_wait_command(core, 2, "P1", "P1-A"),
		_build_manual_wait_command(core, 2, "P2", "P2-A"),
	])
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_build_manual_wait_command(core, 3, "P1", "P1-A"),
		_build_manual_wait_command(core, 3, "P2", "P2-A"),
	])
	if gojo_unit.current_hp != gojo_hp_before_expire_window:
		fail("宿傩对拼失败后，不应残留领域自然到期终爆")
		return


func _build_sukuna_setup(sample_factory, p1_regular_skill_overrides: Dictionary = {}):
	return _support.build_sukuna_setup(sample_factory, p1_regular_skill_overrides)

func _build_sukuna_vs_gojo_setup(sample_factory, p1_regular_skill_overrides: Dictionary = {}, p2_regular_skill_overrides: Dictionary = {}):
	return _support.build_sukuna_vs_gojo_setup(sample_factory, p1_regular_skill_overrides, p2_regular_skill_overrides)

@warning_ignore("shadowed_global_identifier")
func _build_battle_state(core, content_index, battle_setup, seed: int):
	return _support.build_battle_state(core, content_index, battle_setup, seed)

func _build_manual_skill_command(core, turn_index: int, side_id: String, actor_public_id: String, skill_id: String):
	return _support.build_manual_skill_command(core, turn_index, side_id, actor_public_id, skill_id)

func _build_manual_ultimate_command(core, turn_index: int, side_id: String, actor_public_id: String, skill_id: String):
	return _support.build_manual_ultimate_command(core, turn_index, side_id, actor_public_id, skill_id)

func _build_manual_wait_command(core, turn_index: int, side_id: String, actor_public_id: String):
	return _support.build_manual_wait_command(core, turn_index, side_id, actor_public_id)

func _build_manual_switch_command(core, turn_index: int, side_id: String, actor_public_id: String, target_public_id: String):
	return _support.build_manual_switch_command(core, turn_index, side_id, actor_public_id, target_public_id)

func _calc_expected_fixed_effect_damage(core, content_index, effect_id: String, target_unit) -> int:
	return _support.calc_expected_fixed_effect_damage(core, content_index, effect_id, target_unit)
