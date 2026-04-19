from __future__ import annotations

import re
from pathlib import Path

from repo_consistency_common import GateContext


def validator_test_prefix(script_path: str) -> str:
    stem = Path(script_path).stem
    match = re.fullmatch(r"content_snapshot_formal_(.+)_validator", stem)
    return "" if match is None else match.group(1)


def baseline_script_path_for_character_id(character_id: str) -> str:
    normalized_id = character_id.strip()
    return f"src/shared/formal_character_baselines/{normalized_id}/{normalized_id}_formal_character_baseline.gd"


def validate_entry_validator_structure(ctx: GateContext, *, character_id: str, validator_script_path: str) -> None:
    text = ctx.read_text(validator_script_path)
    validator_base_extends = (
        'extends "res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_validator_base.gd"'
    )
    if validator_base_extends not in text:
        ctx.failures.append(
            f"{validator_script_path} entry validator must extend content_snapshot_formal_character_validator_base"
        )
    validate_signature = "func validate(content_index: BattleContentIndex, errors: Array) -> void:"
    if validate_signature not in text:
        ctx.failures.append(
            f"{validator_script_path} must expose validate(content_index: BattleContentIndex, errors: Array) for {character_id}"
        )


def collect_gd_refs(text: str, prefix: str) -> list[str]:
    refs: list[str] = []
    for pattern in [
        re.compile(rf'preload\("res://({prefix}/[^"]+\.gd)"\)'),
        re.compile(rf'extends "res://({prefix}/[^"]+\.gd)"'),
    ]:
        refs.extend(pattern.findall(text))
    return refs


def collect_suite_refs(text: str) -> list[str]:
    return collect_gd_refs(text, "test/suites")


def collect_scope_tree(ctx: GateContext, start_paths: list[str]) -> list[str]:
    discovered: set[str] = set()
    pending_paths: list[str] = list(start_paths)
    while pending_paths:
        rel_path = pending_paths.pop()
        if rel_path in discovered:
            continue
        if not (ctx.root / rel_path).exists():
            continue
        discovered.add(rel_path)
        for child_rel_path in collect_suite_refs(ctx.read_text(rel_path)):
            pending_paths.append(child_rel_path)
    return sorted(discovered)


def collect_support_scope_tree(ctx: GateContext, start_paths: list[str]) -> list[str]:
    discovered: set[str] = set()
    pending_paths: list[str] = list(start_paths)
    while pending_paths:
        rel_path = pending_paths.pop()
        if rel_path in discovered:
            continue
        if not (ctx.root / rel_path).exists():
            continue
        discovered.add(rel_path)
        text = ctx.read_text(rel_path)
        for child_rel_path in collect_gd_refs(text, "tests/support"):
            pending_paths.append(child_rel_path)
    return sorted(discovered)


