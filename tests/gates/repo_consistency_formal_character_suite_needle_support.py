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
    preload_paths = re.findall(
        r'^const [A-Za-z_][A-Za-z0-9_]* := preload\("res://([^"]+)"\)',
        text,
        re.M,
    )
    allowed_suffixes = {
        "_unit_passive_contracts.gd": "unit_passive_contracts",
        "_skill_effect_contracts.gd": "skill_effect_contracts",
        "_ultimate_domain_contracts.gd": "ultimate_domain_contracts",
    }
    preload_buckets: list[str] = []
    for preload_path in preload_paths:
        matched_bucket = next(
            (bucket for suffix, bucket in allowed_suffixes.items() if preload_path.endswith(suffix)),
            "",
        )
        if not matched_bucket:
            ctx.failures.append(
                f"{validator_script_path} entry validator may only preload unit_passive_contracts / skill_effect_contracts / ultimate_domain_contracts buckets"
            )
            continue
        preload_buckets.append(matched_bucket)
    if sorted(preload_buckets) != [
        "skill_effect_contracts",
        "ultimate_domain_contracts",
        "unit_passive_contracts",
    ]:
        ctx.failures.append(
            f"{validator_script_path} must preload exactly the three formal validator buckets for {character_id}"
        )
    expected_var_needles = [
        "var _unit_passive_contracts = ",
        "var _skill_effect_contracts = ",
        "var _ultimate_domain_contracts = ",
    ]
    for needle in expected_var_needles:
        if needle not in text:
            ctx.failures.append(f"{validator_script_path} missing registry bucket instance: {needle.strip()}")
    validate_signature = "func validate(content_index, errors: Array) -> void:"
    if validate_signature not in text:
        ctx.failures.append(f"{validator_script_path} must expose validate(content_index, errors: Array)")
        return
    validate_block = _function_block(text, validate_signature)
    normalized_validate_lines = [line.strip() for line in validate_block if line.strip()]
    expected_validate_lines = [
        "_unit_passive_contracts.validate(self, content_index, errors)",
        "_skill_effect_contracts.validate(self, content_index, errors)",
        "_ultimate_domain_contracts.validate(self, content_index, errors)",
    ]
    if normalized_validate_lines != expected_validate_lines:
        ctx.failures.append(
            f"{validator_script_path} validate() must only chain unit_passive_contracts -> skill_effect_contracts -> ultimate_domain_contracts"
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


def _function_block(text: str, signature: str) -> list[str]:
    lines = text.splitlines()
    capture = False
    block: list[str] = []
    for line in lines:
        if not capture:
            if line.strip() == signature:
                capture = True
            continue
        if line.startswith("func "):
            break
        if line and not line.startswith((" ", "\t")):
            break
        block.append(line)
    return block
