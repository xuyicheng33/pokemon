from __future__ import annotations

import re

from repo_consistency_common import GateContext
from repo_consistency_formal_character_suite_needle_support import collect_support_scope_tree


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

LEGACY_SCAN_EXCLUDE_PATHS = {
    "tests/gates/repo_consistency_formal_character_gate_support.py",
    "tests/gates/repo_consistency_formal_character_pair_capability_support.py",
}


def scan_legacy_formal_character_id_refs(ctx: GateContext) -> list[str]:
    failures: list[str] = []
    scan_specs = [
        (ctx.root / "src" / "shared", "*.gd"),
        (ctx.root / "src" / "battle_core" / "content" / "formal_validators", "*.gd"),
        (ctx.root / "test" / "suites", "*.gd"),
        (ctx.root / "test" / "support", "*.gd"),
        (ctx.root / "tests" / "support", "*.gd"),
        (ctx.root / "tests" / "gates", "*.py"),
    ]
    for scan_root, pattern in scan_specs:
        for path in sorted(scan_root.rglob(pattern)):
            rel_path = str(path.relative_to(ctx.root))
            if rel_path in LEGACY_SCAN_EXCLUDE_PATHS:
                continue
            for line_no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
                for regex, label in LEGACY_FORMAL_CHARACTER_ID_RULES:
                    if regex.search(line):
                        failures.append(f"{rel_path}:{line_no} still contains {label}: {line.strip()}")
    return failures


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
    for top_level_dir in ["src", "test", "tests"]:
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
        ("test", "*.gd"),
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


def scan_pair_interaction_shared_regressions(ctx: GateContext) -> list[str]:
    failures: list[str] = []
    support_scope_paths = collect_support_scope_tree(ctx, [
        "test/suites/formal_character_pair_smoke/interaction_shared.gd",
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
