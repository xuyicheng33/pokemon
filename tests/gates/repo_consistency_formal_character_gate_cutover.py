from __future__ import annotations

from repo_consistency_formal_character_gate_support import (
    scan_legacy_registry_refs,
    scan_legacy_sample_factory_calls,
    scan_pair_interaction_support_regressions,
)


def validate_manifest_cutover(
    ctx,
    *,
    manifest_path: str,
    legacy_registry_path: str,
    legacy_runtime_registry_path: str,
    legacy_delivery_registry_path: str,
    legacy_matchup_catalog_path: str,
    runtime_registry_helper_path: str,
    runtime_registry_loader_path: str,
    delivery_registry_loader_path: str,
    delivery_registry_helper_path: str,
    formal_manifest_script_path: str,
    formal_access_script_path: str,
    pair_interaction_suite_path: str,
    pair_interaction_support_path: str,
) -> None:
    for legacy_path in [
        legacy_registry_path,
        legacy_runtime_registry_path,
        legacy_delivery_registry_path,
        legacy_matchup_catalog_path,
    ]:
        if (ctx.root / legacy_path).exists():
            ctx.failures.append(f"{legacy_path} must be removed after manifest cutover")

    runtime_registry_text = ctx.read_text(runtime_registry_helper_path)
    if f'REGISTRY_PATH := "res://{manifest_path}"' not in runtime_registry_text:
        ctx.failures.append(f"runtime formal character loader must read {manifest_path} directly")
    runtime_registry_loader_text = ctx.read_text(runtime_registry_loader_path)
    if f'preload("res://{formal_manifest_script_path}")' not in runtime_registry_loader_text:
        ctx.failures.append(f"{runtime_registry_loader_path} must preload {formal_manifest_script_path}")
    if "build_runtime_entries_result" not in runtime_registry_loader_text:
        ctx.failures.append(f"{runtime_registry_loader_path} must derive runtime entries from manifest")

    delivery_registry_loader_text = ctx.read_text(delivery_registry_loader_path)
    if f'preload("res://{formal_manifest_script_path}")' not in delivery_registry_loader_text:
        ctx.failures.append(f"{delivery_registry_loader_path} must preload {formal_manifest_script_path}")
    if "build_delivery_entries_result" not in delivery_registry_loader_text:
        ctx.failures.append(f"{delivery_registry_loader_path} must derive delivery entries from manifest")

    delivery_registry_helper_text = ctx.read_text(delivery_registry_helper_path)
    if f'const REGISTRY_PATH := "res://{manifest_path}"' not in delivery_registry_helper_text:
        ctx.failures.append(f"{delivery_registry_helper_path} must read {manifest_path} directly")

    sample_factory_text = ctx.read_text("src/composition/sample_battle_factory.gd")
    formal_access_text = ctx.read_text(formal_access_script_path)
    if 'preload("res://%s"' % formal_access_script_path not in sample_factory_text:
        ctx.failures.append(f"SampleBattleFactory must delegate formal setup orchestration via {formal_access_script_path}")
    if 'entry.get("formal_setup_matchup_id"' not in formal_access_text:
        ctx.failures.append("SampleBattleFactory formal setup helper must read formal_setup_matchup_id from manifest-derived runtime entry")
    if "func configure_formal_manifest_path_override(" not in sample_factory_text:
        ctx.failures.append("SampleBattleFactory must expose configure_formal_manifest_path_override for manifest-based test overrides")
    for legacy_wrapper in [
        "func build_setup_from_side_specs(",
        "func content_snapshot_paths(",
        "func content_snapshot_paths_for_setup(",
        "func collect_tres_paths(",
        "func collect_tres_paths_recursive(",
        "func build_setup_by_matchup_id(",
        "func formal_character_ids(",
        "func formal_unit_definition_ids(",
        "func build_formal_character_setup(",
        "func build_sample_setup(",
        "func build_demo_replay_input(",
        "func build_passive_item_demo_replay_input(",
    ]:
        if legacy_wrapper in sample_factory_text:
            ctx.failures.append(f"SampleBattleFactory still exposes removed legacy wrapper: {legacy_wrapper}")

    pair_interaction_text = ctx.read_text(pair_interaction_suite_path)
    if f'preload("res://{pair_interaction_support_path}")' not in pair_interaction_text:
        ctx.failures.append("formal pair interaction wrapper must preload tests/suites/formal_character_pair_smoke/interaction_support.gd")
    for stale_needle, label in [
        ("EXPECTED_SCENARIO_IDS", "local scenario list"),
        ("match scenario_id", "local scenario dispatch"),
        ("._test_", "cross-suite private _test_* call"),
    ]:
        if stale_needle in pair_interaction_text:
            ctx.failures.append(f"{pair_interaction_suite_path} must not keep stale {label}")

    pair_interaction_support_text = ctx.read_text(pair_interaction_support_path)
    if 'preload("res://tests/suites/' in pair_interaction_support_text:
        ctx.failures.append(f"{pair_interaction_support_path} must not preload suite files directly")
    if "._test_" in pair_interaction_support_text:
        ctx.failures.append(f"{pair_interaction_support_path} must not call suite private _test_* helpers")

    for rel_path in [
        runtime_registry_helper_path,
        runtime_registry_loader_path,
        delivery_registry_loader_path,
        delivery_registry_helper_path,
        "tests/check_suite_reachability.sh",
    ]:
        ctx.require_absent(rel_path, legacy_registry_path, "legacy single formal registry path")

    for legacy_path in [legacy_runtime_registry_path, legacy_delivery_registry_path, legacy_matchup_catalog_path]:
        for rel_path in [
            runtime_registry_helper_path,
            runtime_registry_loader_path,
            delivery_registry_loader_path,
            delivery_registry_helper_path,
            "tests/check_suite_reachability.sh",
        ]:
            ctx.require_absent(rel_path, legacy_path, "legacy split formal config path")
        for failure in scan_legacy_registry_refs(ctx, legacy_path):
            ctx.failures.append(failure)

    for failure in scan_legacy_sample_factory_calls(ctx):
        ctx.failures.append(failure)
    for failure in scan_legacy_registry_refs(ctx, legacy_registry_path):
        ctx.failures.append(failure)
    for failure in scan_pair_interaction_support_regressions(ctx):
        ctx.failures.append(failure)
