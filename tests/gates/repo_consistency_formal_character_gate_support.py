from __future__ import annotations

import json
import re
import subprocess
import tempfile
from pathlib import Path

from repo_consistency_common import GateContext


LEGACY_FORMAL_CHARACTER_ID_RULES = [
    (re.compile(r'FormalCharacterBaselines(?:Script)?\.[A-Za-z_]+\("gojo"(?:,|\))'), "legacy short formal character id gojo"),
    (re.compile(r'FormalCharacterBaselines(?:Script)?\.[A-Za-z_]+\("kashimo"(?:,|\))'), "legacy short formal character id kashimo"),
    (re.compile(r'FormalCharacterBaselines(?:Script)?\.[A-Za-z_]+\("obito"(?:,|\))'), "legacy short formal character id obito"),
    (re.compile(r"formal\[gojo\]"), "legacy short formal contract label gojo"),
    (re.compile(r"formal\[kashimo\]"), "legacy short formal contract label kashimo"),
    (re.compile(r"formal\[obito\]"), "legacy short formal contract label obito"),
    (re.compile(r'"snapshot_label": "gojo"'), "legacy short formal snapshot label gojo"),
    (re.compile(r'"snapshot_label": "kashimo"'), "legacy short formal snapshot label kashimo"),
    (re.compile(r'"snapshot_label": "obito"'), "legacy short formal snapshot label obito"),
]


def contract_field_list(ctx: GateContext, bucket: dict, field_key: str, label: str, *, required: bool = True) -> list[str]:
    values = bucket.get(field_key, [])
    if not isinstance(values, list):
        ctx.failures.append(f"{label} must be an array")
        return []
    normalized: list[str] = []
    for raw_value in values:
        value = str(raw_value).strip()
        if not value:
            ctx.failures.append(f"{label} contains empty field name")
            continue
        normalized.append(value)
    if required and not normalized:
        ctx.failures.append(f"{label} must not be empty")
    return normalized


def validate_required_contract_fields(
    ctx: GateContext,
    entry: dict,
    required_string_fields: list[str],
    required_array_fields: list[str],
    entry_label: str,
    required_positive_int_fields: list[str] | None = None,
) -> None:
    for field_name in required_string_fields:
        if not str(entry.get(field_name, "")).strip():
            ctx.failures.append(f"{entry_label} missing {field_name}")
    for field_name in required_array_fields:
        if not isinstance(entry.get(field_name, None), list):
            ctx.failures.append(f"{entry_label} missing {field_name}")
    for field_name in required_positive_int_fields or []:
        if not _is_positive_int_like(entry.get(field_name, None)):
            ctx.failures.append(f"{entry_label} {field_name} must be positive integer")


def _is_positive_int_like(value: object) -> bool:
    if isinstance(value, bool):
        return False
    if isinstance(value, int):
        return value > 0
    if isinstance(value, float):
        return value.is_integer() and value > 0
    return False


def validator_test_prefix(script_path: str) -> str:
    stem = Path(script_path).stem
    match = re.fullmatch(r"content_snapshot_formal_(.+)_validator", stem)
    return "" if match is None else match.group(1)


def baseline_script_path_for_character_id(character_id: str) -> str:
    normalized_id = character_id.strip()
    return f"src/shared/formal_character_baselines/{normalized_id}/{normalized_id}_formal_character_baseline.gd"


def load_delivery_registry_entries(ctx: GateContext, *, export_script_path: str, manifest_path: str) -> list[dict]:
    if not (ctx.root / export_script_path).exists():
        ctx.failures.append(f"missing delivery registry export script: {export_script_path}")
        return []
    with tempfile.NamedTemporaryFile(delete=False, suffix=".json") as handle:
        output_path = Path(handle.name)
    try:
        result = subprocess.run(
            [
                "godot",
                "--headless",
                "--path",
                ".",
                "--script",
                export_script_path,
                "--",
                str(output_path),
                manifest_path,
            ],
            cwd=ctx.root,
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            stderr = result.stderr.strip()
            stdout = result.stdout.strip()
            combined_output = " | ".join(chunk for chunk in [stderr, stdout] if chunk)
            ctx.failures.append(
                f"{export_script_path} failed to export delivery registry view: {combined_output or f'exit={result.returncode}'}"
            )
            return []
        try:
            payload = json.loads(output_path.read_text(encoding="utf-8"))
        except Exception as exc:
            ctx.failures.append(f"{export_script_path} wrote invalid JSON: {exc}")
            return []
        if not isinstance(payload, dict):
            ctx.failures.append(f"{export_script_path} must export top-level object")
            return []
        entries = payload.get("entries", [])
        if not isinstance(entries, list):
            ctx.failures.append(f"{export_script_path} missing entries array")
            return []
        normalized_entries: list[dict] = []
        for entry_index, raw_entry in enumerate(entries):
            if not isinstance(raw_entry, dict):
                ctx.failures.append(f"{export_script_path} entries[{entry_index}] must be object")
                continue
            normalized_entries.append(raw_entry)
        return normalized_entries
    except FileNotFoundError:
        ctx.failures.append(f"{export_script_path} requires godot in PATH")
        return []
    finally:
        output_path.unlink(missing_ok=True)


def scan_legacy_formal_character_id_refs(ctx: GateContext) -> list[str]:
    failures: list[str] = []
    scan_specs = [
        (ctx.root / "src" / "shared", "*.gd"),
        (ctx.root / "src" / "battle_core" / "content" / "formal_validators", "*.gd"),
        (ctx.root / "tests" / "suites", "*.gd"),
        (ctx.root / "tests" / "support", "*.gd"),
        (ctx.root / "tests" / "gates", "*.py"),
    ]
    for scan_root, pattern in scan_specs:
        for path in sorted(scan_root.rglob(pattern)):
            rel_path = str(path.relative_to(ctx.root))
            if rel_path == "tests/gates/repo_consistency_formal_character_gate_support.py":
                continue
            for line_no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
                for regex, label in LEGACY_FORMAL_CHARACTER_ID_RULES:
                    if regex.search(line):
                        failures.append(f"{rel_path}:{line_no} still contains {label}: {line.strip()}")
    return failures


def collect_gd_refs(text: str, prefix: str) -> list[str]:
    refs: list[str] = []
    for pattern in [
        re.compile(rf'preload\("res://({prefix}/[^"]+\.gd)"\)'),
        re.compile(rf'extends "res://({prefix}/[^"]+\.gd)"'),
    ]:
        refs.extend(pattern.findall(text))
    return refs


def collect_suite_refs(text: str) -> list[str]:
    return collect_gd_refs(text, "tests/suites")


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


def scan_legacy_sample_factory_calls(ctx: GateContext) -> list[str]:
    legacy_call_patterns = [
        r"\bsample_factory\.build_setup_by_matchup_id\(",
        r"\bsample_factory\.content_snapshot_paths\(",
        r"\bsample_factory\.content_snapshot_paths_for_setup\(",
        r"\bsample_factory\.collect_tres_paths\(",
        r"\bsample_factory\.collect_tres_paths_recursive\(",
        r"\bsample_factory\.formal_character_ids\(",
        r"\bsample_factory\.formal_unit_definition_ids\(",
        r"\bsample_factory\.build_formal_character_setup\(",
        r"\bsample_factory\.build_sample_setup\(",
        r"\bsample_factory\.build_demo_replay_input\(",
        r"\bsample_factory\.build_passive_item_demo_replay_input\(",
    ]
    failures: list[str] = []
    for top_level_dir in ["src", "tests"]:
        for path in sorted((ctx.root / top_level_dir).rglob("*.gd")):
            rel_path = str(path.relative_to(ctx.root))
            text = path.read_text(encoding="utf-8")
            for pattern in legacy_call_patterns:
                if re.search(pattern, text):
                    failures.append(f"{rel_path} still calls removed SampleBattleFactory wrapper: {pattern}")
    return failures


def scan_legacy_registry_refs(ctx: GateContext, legacy_registry_path: str) -> list[str]:
    failures: list[str] = []
    scan_specs = [
        ("src", "*.gd"),
        ("tests", "*.gd"),
        ("tests", "*.sh"),
    ]
    for top_level_dir, pattern in scan_specs:
        for path in sorted((ctx.root / top_level_dir).rglob(pattern)):
            rel_path = str(path.relative_to(ctx.root))
            text = path.read_text(encoding="utf-8")
            if legacy_registry_path in text:
                failures.append(f"{rel_path} still references removed legacy registry path: {legacy_registry_path}")
    return failures


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


def scan_pair_interaction_support_regressions(ctx: GateContext) -> list[str]:
    failures: list[str] = []
    support_scope_paths = collect_support_scope_tree(ctx, [
        "tests/suites/formal_character_pair_smoke/interaction_support.gd",
        "tests/support/formal_pair_interaction_test_support.gd",
    ])
    sample_only_tokens = [
        '"gojo_vs_sample"',
        '"sample_vs_gojo"',
        "build_gojo_vs_sample_state(",
        "build_sample_vs_gojo_state(",
        "build_formal_character_setup(",
        "build_formal_character_setup_result(",
    ]
    for rel_path in support_scope_paths:
        if rel_path.endswith("_test_support.gd"):
            continue
        text = ctx.read_text(rel_path)
        for token in sample_only_tokens:
            if token in text:
                failures.append(f"{rel_path} must not keep sample-only pair builder token in formal pair interaction support: {token}")
    for rel_path in support_scope_paths:
        text = ctx.read_text(rel_path)
        for mutation in _scan_formal_skill_mutations(text):
            failures.append(f"{rel_path} must not mutate authored formal skill {mutation} inside pair interaction support")
    return failures


def _scan_formal_skill_mutations(text: str) -> list[str]:
    failures: list[str] = []
    loaded_skill_vars: set[str] = set()
    for line in text.splitlines():
        direct_match = re.search(r"content_index\.skills\[[^\]]+\]\.(accuracy|power)\s*=", line)
        if direct_match is not None:
            failures.append(f"field {direct_match.group(1)} via direct content_index.skills assignment")
        get_match = re.search(r"\bvar\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?::=|=)\s*.*content_index\.skills\.get\(", line)
        if get_match is not None:
            loaded_skill_vars.add(get_match.group(1))
        index_match = re.search(r"\bvar\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?::=|=)\s*.*content_index\.skills\[[^\]]+\]", line)
        if index_match is not None:
            loaded_skill_vars.add(index_match.group(1))
        mutation_match = re.search(r"\b([A-Za-z_][A-Za-z0-9_]*)\.(accuracy|power)\s*=", line)
        if mutation_match is None:
            continue
        var_name = mutation_match.group(1)
        if var_name in loaded_skill_vars:
            failures.append(f"field {mutation_match.group(2)} via loaded skill variable '{var_name}'")
    return failures
