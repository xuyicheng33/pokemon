from __future__ import annotations

from repo_consistency_common import GateContext


def run(ctx: GateContext) -> None:
    ctx.require_exists("docs/records/decisions.md", "active decisions record")
    ctx.require_exists("docs/records/tasks.md", "active tasks record")
    ctx.require_exists("docs/records/archive/decisions_pre_2026-04-05_repair_wave.md", "decisions repair-wave archive")
    ctx.require_exists("docs/records/archive/tasks_pre_2026-04-05_repair_wave.md", "tasks repair-wave archive")
    ctx.require_exists("docs/records/review_2026-04-04_foundation_stabilization_audit.md", "foundation stabilization review record")
    ctx.require_contains("docs/records/review_2026-04-10_four_character_architecture_audit.md", "历史审查，不再作为现行依据。", "four-character architecture review history marker")
    ctx.require_contains("docs/records/decisions.md", "2026-04-12", "decisions schema cutover date marker")
    ctx.require_contains("docs/records/decisions.md", "pair_token", "decisions pair token wording")
    ctx.require_contains("docs/records/decisions.md", "baseline_script_path", "decisions baseline path wording")
    ctx.require_contains("docs/records/decisions.md", "owned_pair_interaction_specs", "decisions owned pair interaction wording")
    ctx.require_contains("docs/records/tasks.md", "pair_token", "tasks pair token wording")
    ctx.require_contains("docs/records/tasks.md", "baseline_script_path", "tasks baseline path wording")
    ctx.require_contains("docs/records/tasks.md", "owned_pair_interaction_specs", "tasks owned pair interaction wording")
    ctx.require_contains("docs/records/tasks.md", "## 当前波次：formal contract 扩角前硬收口（2026-04-10）\n\n- 状态：已完成", "formal contract hard-closeout completion status")

    for rel_path in [
        "README.md",
        "tests/README.md",
        "docs/design/formal_character_delivery_checklist.md",
        "docs/design/battle_content_schema.md",
        "docs/design/formal_character_design_template.md",
        "docs/design/project_folder_structure.md",
    ]:
        ctx.require_absent(rel_path, "formal_character_validator_registry.json", "removed code-side validator registry wording")

    for rel_path in [
        "README.md",
        "tests/README.md",
        "docs/design/formal_character_delivery_checklist.md",
        "docs/design/battle_content_schema.md",
        "docs/design/formal_character_design_template.md",
        "docs/design/project_folder_structure.md",
    ]:
        ctx.require_absent(rel_path, "config/formal_character_runtime_registry.json", "removed split runtime registry wording")
        ctx.require_absent(rel_path, "config/formal_character_delivery_registry.json", "removed split delivery registry wording")
        ctx.require_absent(rel_path, "config/formal_matchup_catalog.json", "removed split matchup catalog wording")

    for rel_path in [
        "README.md",
        "tests/README.md",
        "docs/design/formal_character_delivery_checklist.md",
        "docs/design/battle_content_schema.md",
        "docs/design/formal_character_design_template.md",
        "docs/design/project_folder_structure.md",
        "docs/design/kashimo_hajime_adjustments.md",
    ]:
        ctx.require_absent(rel_path, "docs/records/formal_character_registry.json", "stale docs-side formal registry path")

    for rel_path in [
        "README.md",
        "tests/README.md",
        "docs/design/formal_character_delivery_checklist.md",
        "docs/design/battle_content_schema.md",
        "docs/design/formal_character_design_template.md",
        "docs/design/project_folder_structure.md",
        "docs/design/kashimo_hajime_adjustments.md",
    ]:
        ctx.require_absent(rel_path, "config/formal_character_registry.json", "stale single formal registry path")

    for rel_path in [
        "README.md",
        "tests/README.md",
        "docs/design/formal_character_delivery_checklist.md",
        "docs/design/battle_content_schema.md",
    ]:
        ctx.require_absent(rel_path, "代码侧描述源", "stale code-side formal registry wording")

    ctx.require_absent("docs/design/formal_character_delivery_checklist.md", "sample_setup_method", "retired sample_setup_method wording")

    for rel_path in [
        "README.md",
        "tests/README.md",
        "docs/design/formal_character_delivery_checklist.md",
        "docs/design/battle_content_schema.md",
    ]:
        ctx.require_absent(rel_path, "characters / matchups / pair_interaction_cases", "stale raw pair interaction case bucket wording")

    for rel_path in [
        "README.md",
        "tests/README.md",
        "docs/design/formal_character_delivery_checklist.md",
        "docs/design/battle_content_schema.md",
        "docs/design/formal_character_design_template.md",
        "docs/records/decisions.md",
        "docs/records/tasks.md",
    ]:
        ctx.require_absent(rel_path, "`pair_interaction_specs`", "stale top-level pair interaction spec wording")
        ctx.require_absent(rel_path, "`pair_interaction_cases`", "stale pair interaction case wording")
        ctx.require_absent(rel_path, "`scenario_id`", "stale scenario id wording")

    for rel_path in [
        "README.md",
        "docs/design/battle_content_schema.md",
        "docs/design/formal_character_capability_catalog.md",
    ]:
        ctx.require_absent(rel_path, "coverage_needles", "stale capability coverage needle wording")

    ctx.require_absent("README.md", "6 个无向 pair case", "stale undirected pair case README wording")
    ctx.require_absent(
        "docs/design/formal_character_delivery_checklist.md",
        "`SampleBattleFactory` 正式快照路径读取统一走 `content_snapshot_paths_result()`",
        "stale full-snapshot formal checklist wording",
    )
    ctx.require_absent(
        "docs/rules/06_effect_schema_and_extension.md",
        "只允许按目标 owner 上的精确 `def_id` 移除单个效果实例",
        "stale remove_effect single-only wording",
    )

    stale_candidate_wording = [
        "schema 暂不扩候选技能池字段",
        "当前 schema 不单独编码",
        "写死在 README 与内容说明文档里",
        "当前允许空串或 `mp_diff_clamped`",
        "只开放空串与 `mp_diff_clamped`",
    ]
    for rel_path in [
        "README.md",
        "content/README.md",
        "docs/design/battle_content_schema.md",
    ]:
        for needle in stale_candidate_wording:
            ctx.require_absent(rel_path, needle, "candidate skill pool drift wording")

    domain_matrix_redundant_wording = [
        "比较双方**扣费后的当前 MP**；MP 高者留场；平 MP 随机决定胜者",
        "比较双方扣费后的当前 MP；高者留场；平 MP 随机决定胜者",
    ]
    for rel_path in [
        "docs/design/gojo_satoru_design.md",
        "docs/design/sukuna_design.md",
    ]:
        for needle in domain_matrix_redundant_wording:
            ctx.require_absent(rel_path, needle, "role design duplicated public domain matrix wording")
