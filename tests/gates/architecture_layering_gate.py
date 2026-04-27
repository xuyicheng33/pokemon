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
    {
        "label": "battle_state.phase 写入必须走 transition_phase / finalize_*_termination setter",
        "pattern": re.compile(r"battle_state\.phase\s*="),
        "search_roots": [
            "src/battle_core",
            "src/adapters",
            "src/composition",
            "src/dev_kit",
            "scenes",
        ],
        # battle_state.gd 自己是 setter 实现的归宿，注释中也会出现该字串。
        "drop_if_file_path": ["src/battle_core/runtime/battle_state.gd"],
    },
    {
        "label": "battle_state.battle_result.{finished,winner_side_id,result_type,reason} 写入必须走 finalize_*_termination setter",
        "pattern": re.compile(r"battle_state\.battle_result\.(finished|winner_side_id|result_type|reason)\s*="),
        "search_roots": [
            "src/battle_core",
            "src/adapters",
            "src/composition",
            "src/dev_kit",
            "scenes",
        ],
        "drop_if_file_path": ["src/battle_core/runtime/battle_state.gd"],
    },
    {
        "label": "adapter 不再直接 preload BattleCoreComposer / SampleBattleFactory（统一走 SessionFactory.compose_battle_runtime）",
        "pattern": re.compile(r"res://src/(?:composition/battle_core_composer\.gd|dev_kit/sample_battle/sample_battle_factory\.gd)"),
        "search_roots": ["src/adapters", "scenes"],
        # SessionFactory 自己是 adapter 层的装配收口，是该规则的唯一允许豁免点。
        "drop_if_file_path": ["src/adapters/session_factory.gd"],
    },
    {
        "label": "动态 load(path_var) 必须在白名单内（content registry / loader / resolver / portrait 共 11 处合理用途）",
        # 匹配 `load(var)` 与 `ResourceLoader.load(var)`：变量首字符为小写或下划线；
        # 不匹配 `load("res://...")`（引号不在 [a-z_] 中）；
        # 不匹配 `_payload(...)` 这类 helper（前缀 `\b` + 锚定 `load`）。
        "pattern": re.compile(r"\b(?:ResourceLoader\.)?load\(\s*[a-z_]\w*\s*[,)]"),
        "search_roots": [
            "src/battle_core",
            "src/adapters",
            "src/composition",
            "src/shared",
        ],
        # 现有合理动态 load 白名单。新增动态 load 必须先把使用场景登记到本列表。
        "drop_if_file_path": [
            "src/battle_core/content/content_snapshot_cache.gd",
            "src/battle_core/content/battle_content_index.gd",
            "src/battle_core/content/power_bonus_source_registry.gd",
            "src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_registry.gd",
            "src/battle_core/actions/power_bonus_resolver.gd",
            "src/shared/formal_character_manifest/formal_character_manifest_loader.gd",
            "src/shared/formal_character_baselines/formal_character_baseline_loader.gd",
            "src/adapters/sandbox_view_character_cards_renderer.gd",
            "src/adapters/player/player_content_lexicon.gd",
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
    drop_if_file_path: list[str] = rule.get("drop_if_file_path", [])
    matches: list[str] = []
    for root_rel in rule["search_roots"]:
        root_path = ROOT / root_rel
        for file_path in iter_files(root_path):
            rel = str(file_path.relative_to(ROOT))
            if any(drop in rel for drop in drop_if_file_path):
                continue
            try:
                lines = file_path.read_text(encoding="utf-8").splitlines()
            except UnicodeDecodeError:
                continue
            for line_number, line in enumerate(lines, start=1):
                if pattern.search(line) is None:
                    continue
                if any(drop in line for drop in drop_if_contains):
                    continue
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
        ROOT / "src/adapters",
        ROOT / "src/battle_core",
        ROOT / "src/composition",
        ROOT / "scenes/player",
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
