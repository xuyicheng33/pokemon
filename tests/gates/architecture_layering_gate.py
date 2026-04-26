from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


# Each rule: (label, needle pattern, list of search roots, optional filter substrings to drop)
LAYERING_RULES: list[dict] = [
    {
        "label": "outer layers must not import battle_core/runtime/*",
        "pattern": re.compile(r"res://src/battle_core/runtime/"),
        "search_roots": ["src/adapters", "src/composition", "scenes"],
    },
    {
        "label": "adapters/scenes must not import battle_core internal services",
        "pattern": re.compile(
            r"res://src/battle_core/(actions|content|effects|lifecycle|logging|math|passives|turn)/"
        ),
        "search_roots": ["src/adapters", "scenes"],
    },
    {
        "label": "battle_core L1 modules (content/contracts/runtime) must not import upper-layer services",
        "pattern": re.compile(
            r"res://src/battle_core/(actions|commands|effects|lifecycle|logging|math|passives|turn|facades)/"
        ),
        "search_roots": [
            "src/battle_core/content",
            "src/battle_core/contracts",
            "src/battle_core/runtime",
        ],
    },
    {
        "label": "battle_core commands/math layer must remain L2-pure and must not import runtime/coordinators/orchestrators/facades",
        "pattern": re.compile(
            r"res://src/battle_core/(actions|effects|lifecycle|passives|turn|facades|runtime)/"
        ),
        "search_roots": ["src/battle_core/math", "src/battle_core/commands"],
    },
    {
        "label": "inner battle_core modules must not import facades",
        "pattern": re.compile(r"res://src/battle_core/facades/"),
        "search_roots": [
            "src/battle_core/actions",
            "src/battle_core/commands",
            "src/battle_core/content",
            "src/battle_core/contracts",
            "src/battle_core/effects",
            "src/battle_core/lifecycle",
            "src/battle_core/logging",
            "src/battle_core/math",
            "src/battle_core/passives",
            "src/battle_core/runtime",
            "src/battle_core/turn",
        ],
    },
    {
        "label": "BattleCoreManager facade must not reach through session.container outside session/container service",
        "pattern": re.compile(r"session\.container"),
        "search_roots": ["src/battle_core/facades"],
        "drop_if_contains": [
            "battle_core_session.gd",
            "battle_core_manager_container_service.gd",
        ],
    },
    {
        "label": "adapters/scenes must not import battle_core commands except command_types.gd",
        "pattern": re.compile(r"res://src/battle_core/commands/"),
        "search_roots": ["src/adapters", "scenes"],
        "drop_if_contains": ["res://src/battle_core/commands/command_types.gd"],
    },
    {
        "label": "battle_core must not import composition",
        "pattern": re.compile(r"res://src/composition/"),
        "search_roots": ["src/battle_core"],
    },
    {
        "label": "production layers (battle_core/composition/shared/scenes) must not import src/dev_kit/*",
        "pattern": re.compile(r"res://src/dev_kit/"),
        "search_roots": [
            "src/battle_core",
            "src/composition",
            "src/shared",
            "scenes",
        ],
    },
]


def iter_files(search_root: Path) -> list[Path]:
    if not search_root.exists():
        return []
    files: list[Path] = []
    for path in search_root.rglob("*"):
        if not path.is_file():
            continue
        suffix = path.suffix.lower()
        if suffix not in {".gd", ".tscn", ".tres"}:
            continue
        files.append(path)
    return files


def scan_rule(rule: dict) -> list[str]:
    pattern: re.Pattern[str] = rule["pattern"]
    drop_if_contains: list[str] = rule.get("drop_if_contains", [])
    matches: list[str] = []
    for root_rel in rule["search_roots"]:
        root_path = ROOT / root_rel
        for file_path in iter_files(root_path):
            try:
                lines = file_path.read_text(encoding="utf-8").splitlines()
            except UnicodeDecodeError:
                continue
            for line_number, line in enumerate(lines, start=1):
                if pattern.search(line) is None:
                    continue
                if any(drop in line for drop in drop_if_contains):
                    continue
                rel = file_path.relative_to(ROOT)
                matches.append(f"{rel}:{line_number}:{line.rstrip()}")
    return matches


def check_file_size_constraints() -> None:
    test_roots = [ROOT / "test", ROOT / "tests"]
    shared_support_patterns = ("tests/support/",)

    def is_shared_support(rel: str) -> bool:
        if rel.startswith(shared_support_patterns):
            return True
        filename = Path(rel).name
        return filename.startswith("shared") or filename.endswith("_shared.gd")

    TEST_SUPPORT_WARN_MIN = 220
    TEST_SUPPORT_HARD_MAX = 250
    TEST_FILE_HARD_MAX = 600
    SHELL_SUITE_MIN_LINES = 13
    func_test_pattern = re.compile(r"^func\s+test_\w+\s*\(", re.MULTILINE)

    for test_root in test_roots:
        if not test_root.exists():
            continue
        for path in test_root.rglob("*.gd"):
            rel = str(path.relative_to(ROOT))
            text = path.read_text(encoding="utf-8")
            line_count = len(text.splitlines())
            if is_shared_support(rel):
                if TEST_SUPPORT_WARN_MIN <= line_count <= TEST_SUPPORT_HARD_MAX:
                    print(
                        f"ARCH_GATE_WARNING: tests support file approaching {TEST_SUPPORT_HARD_MAX}-line split threshold: {rel} ({line_count} lines)"
                    )
                if line_count > TEST_SUPPORT_HARD_MAX:
                    print(
                        f"ARCH_GATE_FAILED: tests support file exceeds {TEST_SUPPORT_HARD_MAX} lines and must be split: {rel} ({line_count})",
                        file=sys.stderr,
                    )
                    sys.exit(1)
            if line_count > TEST_FILE_HARD_MAX:
                print(
                    f"ARCH_GATE_FAILED: test file exceeds {TEST_FILE_HARD_MAX} lines: {rel} ({line_count})",
                    file=sys.stderr,
                )
                sys.exit(1)
            if rel.endswith("suite.gd"):
                if line_count < SHELL_SUITE_MIN_LINES and func_test_pattern.search(text) is None:
                    print(
                        f"ARCH_GATE_FAILED: gdUnit shell suite has no func test_* entry and falls below {SHELL_SUITE_MIN_LINES} lines: {rel} ({line_count})",
                        file=sys.stderr,
                    )
                    sys.exit(1)

    SIZE_WARN_MIN = 500
    SIZE_HARD_MAX = 800

    review_roots = [
        ROOT / "src/battle_core",
        ROOT / "src/composition",
        ROOT / "src/shared/formal_character_baselines",
        ROOT / "src/shared/formal_character_manifest",
    ]
    extra_entries = [
        ROOT / "src/shared/formal_character_baselines.gd",
        ROOT / "src/shared/formal_character_manifest.gd",
    ]

    review_required: list[tuple[str, int]] = []
    warning_review: list[tuple[str, int]] = []
    for source_root in review_roots:
        if not source_root.exists():
            continue
        for path in source_root.rglob("*.gd"):
            rel = str(path.relative_to(ROOT))
            line_count = len(path.read_text(encoding="utf-8").splitlines())
            if SIZE_WARN_MIN <= line_count <= SIZE_HARD_MAX:
                warning_review.append((rel, line_count))
            if line_count > SIZE_HARD_MAX:
                review_required.append((rel, line_count))
    for extra_entry in extra_entries:
        if not extra_entry.exists():
            continue
        rel = str(extra_entry.relative_to(ROOT))
        line_count = len(extra_entry.read_text(encoding="utf-8").splitlines())
        if SIZE_WARN_MIN <= line_count <= SIZE_HARD_MAX:
            warning_review.append((rel, line_count))
        if line_count > SIZE_HARD_MAX:
            review_required.append((rel, line_count))

    if review_required:
        print(
            f"ARCH_GATE_FAILED: core files >{SIZE_HARD_MAX} lines require fresh split:",
            file=sys.stderr,
        )
        for rel, line_count in review_required:
            print(f"  - {rel} ({line_count} lines)", file=sys.stderr)
        sys.exit(1)

    if warning_review:
        print(
            f"ARCH_GATE_WARNING: core files approaching {SIZE_HARD_MAX}-line review threshold:"
        )
        for rel, line_count in warning_review:
            print(f"  - {rel} ({line_count} lines)")

    GATE_PY_WARN_MIN = 800
    GATE_PY_HARD_MAX = 1200
    for path in sorted((ROOT / "tests/gates").glob("*.py")):
        rel = str(path.relative_to(ROOT))
        line_count = len(path.read_text(encoding="utf-8").splitlines())
        if GATE_PY_WARN_MIN <= line_count <= GATE_PY_HARD_MAX:
            print(
                f"ARCH_GATE_WARNING: tests gate file approaching {GATE_PY_HARD_MAX}-line split threshold: {rel} ({line_count} lines)"
            )
        if line_count > GATE_PY_HARD_MAX:
            print(
                f"ARCH_GATE_FAILED: tests gate file exceeds {GATE_PY_HARD_MAX} lines and must be split: {rel} ({line_count})",
                file=sys.stderr,
            )
            sys.exit(1)


def main() -> None:
    failures: list[tuple[str, list[str]]] = []
    for rule in LAYERING_RULES:
        matches = scan_rule(rule)
        if matches:
            failures.append((rule["label"], matches))

    if failures:
        for label, matches in failures:
            print(f"ARCH_GATE_FAILED: {label}", file=sys.stderr)
            for line in matches:
                print(f"  {line}", file=sys.stderr)
        sys.exit(1)

    check_file_size_constraints()

    print(
        "ARCH_GATE_PASSED: outer/internal layering and size constraints are satisfied"
    )


if __name__ == "__main__":
    main()
