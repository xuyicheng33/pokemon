extends RefCounted
class_name AIPolicyDecisionSuite

const BattleAIAdapterScript := preload("res://src/adapters/battle_ai_adapter.gd")
const BattleAIPolicyServiceScript := preload("res://src/adapters/ai/battle_ai_policy_service.gd")
const LegalActionSetScript := preload("res://src/battle_core/contracts/legal_action_set.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("ai_policy_forced_command_contract", failures, Callable(self, "_test_forced_command_contract").bind(harness))
    runner.run_test("ai_policy_gojo_double_mark_prefers_murasaki", failures, Callable(self, "_test_gojo_double_mark_prefers_murasaki").bind(harness))
    runner.run_test("ai_policy_sukuna_points_rush_prefers_kai", failures, Callable(self, "_test_sukuna_points_rush_prefers_kai").bind(harness))
    runner.run_test("ai_policy_sukuna_ultimate_when_ready", failures, Callable(self, "_test_sukuna_ultimate_when_ready").bind(harness))
    runner.run_test("ai_policy_sukuna_ultimate_beats_heal_when_ready", failures, Callable(self, "_test_sukuna_ultimate_beats_heal_when_ready").bind(harness))
    runner.run_test("ai_policy_gojo_ultimate_beats_heal_when_ready", failures, Callable(self, "_test_gojo_ultimate_beats_heal_when_ready").bind(harness))
    runner.run_test("ai_policy_domain_not_blocked_by_owned_normal_field", failures, Callable(self, "_test_domain_not_blocked_by_owned_normal_field").bind(harness))
    runner.run_test("ai_policy_domain_blocked_by_owned_domain_field", failures, Callable(self, "_test_domain_blocked_by_owned_domain_field").bind(harness))
    runner.run_test("ai_policy_adapter_service_alignment", failures, Callable(self, "_test_adapter_service_alignment").bind(harness))

func _test_forced_command_contract(harness) -> Dictionary:
    var legal_actions = _build_legal_action_set()
    legal_actions.forced_command_type = CommandTypesScript.RESOURCE_FORCED_DEFAULT
    legal_actions.wait_allowed = false
    var snapshot := _build_snapshot("gojo_satoru", "sukuna")
    var adapter_choice: Dictionary = BattleAIAdapterScript.new().choose_command(legal_actions, snapshot, "P1", "heuristic")
    if not adapter_choice.is_empty():
        return _fail(harness, "forced_command_type 非空时 AI 必须返回空命令，交给 resolver 注入")
    return _pass(harness)

func _test_gojo_double_mark_prefers_murasaki(harness) -> Dictionary:
    var legal_actions = _build_legal_action_set()
    legal_actions.legal_skill_ids = PackedStringArray(["gojo_ao", "gojo_aka", "gojo_murasaki"])
    var snapshot := _build_snapshot("gojo_satoru", "sukuna")
    snapshot["sides"][1]["team_units"][0]["effect_instances"] = [
        {"effect_definition_id": "gojo_ao_mark"},
        {"effect_definition_id": "gojo_aka_mark"},
    ]
    var choice: Dictionary = BattleAIPolicyServiceScript.new().choose_command(legal_actions, snapshot, "P1", "heuristic")
    if str(choice.get("skill_id", "")) != "gojo_murasaki":
        return _fail(harness, "Gojo 双标记时应优先使用 gojo_murasaki")
    return _pass(harness)

func _test_sukuna_points_rush_prefers_kai(harness) -> Dictionary:
    var legal_actions = _build_legal_action_set()
    legal_actions.legal_skill_ids = PackedStringArray(["sukuna_hatsu", "sukuna_hiraku", "sukuna_kai"])
    var snapshot := _build_snapshot("sukuna", "gojo_satoru")
    snapshot["sides"][0]["team_units"][0]["ultimate_points"] = 0
    snapshot["sides"][0]["team_units"][0]["ultimate_points_required"] = 3
    var choice: Dictionary = BattleAIPolicyServiceScript.new().choose_command(legal_actions, snapshot, "P1", "heuristic")
    if str(choice.get("skill_id", "")) != "sukuna_kai":
        return _fail(harness, "宿傩点数未满时应优先用 sukuna_kai 稳定攒点")
    return _pass(harness)

func _test_sukuna_ultimate_when_ready(harness) -> Dictionary:
    var legal_actions = _build_legal_action_set()
    legal_actions.legal_skill_ids = PackedStringArray(["sukuna_kai"])
    legal_actions.legal_ultimate_ids = PackedStringArray(["sukuna_fukuma_mizushi"])
    var snapshot := _build_snapshot("sukuna", "gojo_satoru")
    snapshot["sides"][0]["team_units"][0]["ultimate_points"] = 3
    snapshot["sides"][0]["team_units"][0]["ultimate_points_required"] = 3
    var choice: Dictionary = BattleAIPolicyServiceScript.new().choose_command(legal_actions, snapshot, "P1", "heuristic")
    if str(choice.get("command_type", "")) != CommandTypesScript.ULTIMATE or str(choice.get("skill_id", "")) != "sukuna_fukuma_mizushi":
        return _fail(harness, "宿傩奥义合法且己方无领域时应优先开领域")
    return _pass(harness)

func _test_sukuna_ultimate_beats_heal_when_ready(harness) -> Dictionary:
    var legal_actions = _build_legal_action_set()
    legal_actions.legal_skill_ids = PackedStringArray(["sukuna_reverse_ritual", "sukuna_kai"])
    legal_actions.legal_ultimate_ids = PackedStringArray(["sukuna_fukuma_mizushi"])
    var snapshot := _build_snapshot("sukuna", "gojo_satoru")
    snapshot["sides"][0]["team_units"][0]["current_hp"] = 30
    snapshot["sides"][0]["team_units"][0]["max_hp"] = 100
    snapshot["sides"][0]["team_units"][0]["ultimate_points"] = 3
    snapshot["sides"][0]["team_units"][0]["ultimate_points_required"] = 3
    var choice: Dictionary = BattleAIPolicyServiceScript.new().choose_command(legal_actions, snapshot, "P1", "heuristic")
    if str(choice.get("command_type", "")) != CommandTypesScript.ULTIMATE or str(choice.get("skill_id", "")) != "sukuna_fukuma_mizushi":
        return _fail(harness, "宿傩已满足开领域条件时，不应被治疗优先级截走")
    return _pass(harness)

func _test_gojo_ultimate_beats_heal_when_ready(harness) -> Dictionary:
    var legal_actions = _build_legal_action_set()
    legal_actions.legal_skill_ids = PackedStringArray(["gojo_reverse_ritual", "gojo_ao"])
    legal_actions.legal_ultimate_ids = PackedStringArray(["gojo_unlimited_void"])
    var snapshot := _build_snapshot("gojo_satoru", "sukuna")
    snapshot["sides"][0]["team_units"][0]["current_hp"] = 25
    snapshot["sides"][0]["team_units"][0]["max_hp"] = 100
    snapshot["sides"][0]["team_units"][0]["ultimate_points"] = 3
    snapshot["sides"][0]["team_units"][0]["ultimate_points_required"] = 3
    var choice: Dictionary = BattleAIPolicyServiceScript.new().choose_command(legal_actions, snapshot, "P1", "heuristic")
    if str(choice.get("command_type", "")) != CommandTypesScript.ULTIMATE or str(choice.get("skill_id", "")) != "gojo_unlimited_void":
        return _fail(harness, "领域角色已满足开大条件时，不应被治疗优先级截走")
    return _pass(harness)

func _test_domain_not_blocked_by_owned_normal_field(harness) -> Dictionary:
    var legal_actions = _build_legal_action_set()
    legal_actions.legal_skill_ids = PackedStringArray(["gojo_ao"])
    legal_actions.legal_ultimate_ids = PackedStringArray(["gojo_unlimited_void"])
    var snapshot := _build_snapshot("gojo_satoru", "sukuna")
    snapshot["field"] = {
        "field_id": "sample_focus_field",
        "field_kind": "normal",
        "creator_public_id": "P1-A",
        "creator_side_id": "P1",
    }
    var choice: Dictionary = BattleAIPolicyServiceScript.new().choose_command(legal_actions, snapshot, "P1", "heuristic")
    if str(choice.get("command_type", "")) != CommandTypesScript.ULTIMATE or str(choice.get("skill_id", "")) != "gojo_unlimited_void":
        return _fail(harness, "己方普通field在场时，领域奥义不应被误判为己方领域重开")
    return _pass(harness)

func _test_domain_blocked_by_owned_domain_field(harness) -> Dictionary:
    var legal_actions = _build_legal_action_set()
    legal_actions.legal_skill_ids = PackedStringArray(["gojo_ao"])
    legal_actions.legal_ultimate_ids = PackedStringArray(["gojo_unlimited_void"])
    var snapshot := _build_snapshot("gojo_satoru", "sukuna")
    snapshot["field"] = {
        "field_id": "gojo_unlimited_void_field",
        "field_kind": "domain",
        "creator_public_id": "P1-A",
        "creator_side_id": "P1",
    }
    var choice: Dictionary = BattleAIPolicyServiceScript.new().choose_command(legal_actions, snapshot, "P1", "heuristic")
    if str(choice.get("skill_id", "")) == "gojo_unlimited_void":
        return _fail(harness, "己方领域在场时不应重复选择己方领域奥义")
    return _pass(harness)

func _test_adapter_service_alignment(harness) -> Dictionary:
    var legal_actions = _build_legal_action_set()
    legal_actions.legal_skill_ids = PackedStringArray(["gojo_ao", "gojo_aka"])
    var snapshot := _build_snapshot("gojo_satoru", "sukuna")
    var adapter_choice: Dictionary = BattleAIAdapterScript.new().choose_command(legal_actions, snapshot, "P1", "heuristic")
    var service_choice: Dictionary = BattleAIPolicyServiceScript.new().choose_command(legal_actions, snapshot, "P1", "heuristic")
    if adapter_choice != service_choice:
        return _fail(harness, "BattleAIAdapter 与共享策略服务输出不一致")
    return _pass(harness)

func _build_legal_action_set():
    var legal_actions = LegalActionSetScript.new()
    legal_actions.actor_public_id = "P1-A"
    legal_actions.wait_allowed = true
    return legal_actions

func _build_snapshot(p1_def_id: String, p2_def_id: String) -> Dictionary:
    return {
        "field": {
            "field_id": null,
            "field_kind": null,
            "creator_public_id": null,
            "creator_side_id": null,
        },
        "sides": [
            {
                "side_id": "P1",
                "active_public_id": "P1-A",
                "team_units": [
                    {
                        "public_id": "P1-A",
                        "definition_id": p1_def_id,
                        "current_hp": 100,
                        "max_hp": 100,
                        "current_mp": 80,
                        "ultimate_points": 0,
                        "ultimate_points_required": 3,
                        "effect_instances": [],
                    },
                    {
                        "public_id": "P1-B",
                        "definition_id": "sample_mossaur",
                        "current_hp": 70,
                        "max_hp": 100,
                        "current_mp": 50,
                        "ultimate_points": 0,
                        "ultimate_points_required": 0,
                        "effect_instances": [],
                    },
                ],
            },
            {
                "side_id": "P2",
                "active_public_id": "P2-A",
                "team_units": [
                    {
                        "public_id": "P2-A",
                        "definition_id": p2_def_id,
                        "current_hp": 100,
                        "max_hp": 100,
                        "current_mp": 80,
                        "ultimate_points": 0,
                        "ultimate_points_required": 3,
                        "effect_instances": [],
                    },
                ],
            },
        ],
    }

func _pass(harness) -> Dictionary:
    if harness == null:
        return {"ok": true}
    return harness.pass_result()

func _fail(harness, message: String) -> Dictionary:
    if harness == null:
        return {"ok": false, "error": message}
    return harness.fail_result(message)
