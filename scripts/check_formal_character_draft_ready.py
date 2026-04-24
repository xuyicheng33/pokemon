#!/usr/bin/env python3
"""Validate formal character draft files before moving them into live paths."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_DRAFTS_DIR = REPO_ROOT / "scripts" / "drafts"
DRAFT_SOURCE_PATTERN = re.compile(r"^\d+_.+\.json$")
PLACEHOLDER_NEEDLES = [
    "FILL_IN",
    "FORMAL_DRAFT_",
    "draft_marker",
    "TODO: implement",
    "interaction placeholder",
]


def main() -> None:
    drafts_dir = _resolve_drafts_dir()
    failures: list[str] = []
    if not drafts_dir.exists():
        print(f"DRAFT_READY_SKIPPED: no draft directory found: {_rel(drafts_dir)}")
        return
    source_paths = [
        path for path in sorted(drafts_dir.glob("*.json"))
        if DRAFT_SOURCE_PATTERN.fullmatch(path.name)
    ]
    if not source_paths:
        print(f"DRAFT_READY_SKIPPED: no formal character source drafts under {_rel(drafts_dir)}")
        return
    for source_path in source_paths:
        _validate_source_draft(drafts_dir, source_path, failures)
    if failures:
        print("DRAFT_READY_FAILED:")
        for failure in failures:
            print(f"  - {failure}")
        raise SystemExit(1)
    print(f"DRAFT_READY_PASSED: {len(source_paths)} formal character draft(s) are ready for live promotion")


def _resolve_drafts_dir() -> Path:
    if len(sys.argv) <= 1:
        return DEFAULT_DRAFTS_DIR
    raw_path = sys.argv[1].strip()
    if not raw_path:
        return DEFAULT_DRAFTS_DIR
    path = Path(raw_path)
    return path if path.is_absolute() else REPO_ROOT / path


def _validate_source_draft(drafts_dir: Path, source_path: Path, failures: list[str]) -> None:
    descriptor = _load_descriptor(source_path, failures)
    if not descriptor:
        return
    if descriptor.get("descriptor_kind") != "formal_character_source":
        failures.append(f"{_rel(source_path)} descriptor_kind must be formal_character_source")
        return
    character = descriptor.get("character", {})
    if not isinstance(character, dict):
        failures.append(f"{_rel(source_path)} missing character object")
        return
    character_id = _field(character, "character_id")
    pair_token = _field(character, "pair_token")
    if not character_id or not pair_token:
        failures.append(f"{_rel(source_path)} missing character_id or pair_token")
        return
    _scan_file_for_placeholders(source_path, failures)
    expected_files = [
        drafts_dir / "src" / "shared" / "formal_character_baselines" / character_id / f"{character_id}_formal_character_baseline.gd",
        drafts_dir / "src" / "battle_core" / "content" / "formal_validators" / pair_token / f"content_snapshot_formal_{pair_token}_validator.gd",
        drafts_dir / "test" / "suites" / f"{pair_token}_snapshot_suite.gd",
        drafts_dir / "test" / "suites" / f"{pair_token}_suite.gd",
        drafts_dir / "test" / "suites" / f"{pair_token}_manager_smoke_suite.gd",
        drafts_dir / "docs" / "design" / f"{character_id}_design.md",
        drafts_dir / "docs" / "design" / f"{character_id}_adjustments.md",
    ]
    owned_specs = character.get("owned_pair_interaction_specs", [])
    if isinstance(owned_specs, list) and owned_specs:
        expected_files.append(drafts_dir / "formal_pair_interaction" / f"{pair_token}_cases.gd")
    for path in expected_files:
        _require_ready_file(path, failures)
    for raw_content_root in character.get("content_roots", []):
        content_root = REPO_ROOT / str(raw_content_root).strip()
        if not content_root.exists():
            failures.append(f"{_rel(source_path)} content_root does not exist: {_rel(content_root)}")
    for raw_live_path in _live_target_paths(character, source_path.name):
        live_path = REPO_ROOT / raw_live_path
        if live_path.exists():
            failures.append(f"{_rel(source_path)} live target already exists; move/merge manually: {raw_live_path}")


def _load_descriptor(source_path: Path, failures: list[str]) -> dict:
    try:
        parsed = json.loads(source_path.read_text(encoding="utf-8"))
    except Exception as exc:
        failures.append(f"{_rel(source_path)} invalid JSON: {exc}")
        return {}
    if not isinstance(parsed, dict):
        failures.append(f"{_rel(source_path)} must be a JSON object")
        return {}
    return parsed


def _require_ready_file(path: Path, failures: list[str]) -> None:
    if not path.exists():
        failures.append(f"missing draft file: {_rel(path)}")
        return
    _scan_file_for_placeholders(path, failures)


def _scan_file_for_placeholders(path: Path, failures: list[str]) -> None:
    if path.suffix not in {".gd", ".json", ".md"}:
        return
    text = path.read_text(encoding="utf-8")
    for needle in PLACEHOLDER_NEEDLES:
        if needle in text:
            failures.append(f"{_rel(path)} contains unresolved placeholder: {needle}")


def _live_target_paths(character: dict, source_filename: str) -> list[str]:
    character_id = _field(character, "character_id")
    pair_token = _field(character, "pair_token")
    paths = [
        f"config/formal_character_sources/{source_filename}",
        f"src/shared/formal_character_baselines/{character_id}/{character_id}_formal_character_baseline.gd",
        f"src/battle_core/content/formal_validators/{pair_token}/content_snapshot_formal_{pair_token}_validator.gd",
        f"test/suites/{pair_token}_snapshot_suite.gd",
        f"test/suites/{pair_token}_suite.gd",
        f"test/suites/{pair_token}_manager_smoke_suite.gd",
        f"docs/design/{character_id}_design.md",
        f"docs/design/{character_id}_adjustments.md",
    ]
    owned_specs = character.get("owned_pair_interaction_specs", [])
    if isinstance(owned_specs, list) and owned_specs:
        paths.append(f"tests/support/formal_pair_interaction/{pair_token}_cases.gd")
    return paths


def _field(data: dict, key: str) -> str:
    return str(data.get(key, "")).strip()


def _rel(path: Path) -> str:
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


if __name__ == "__main__":
    main()
