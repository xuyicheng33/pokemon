#!/usr/bin/env python3
"""Validate formal character draft files before moving them into live paths."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_DRAFTS_DIR = REPO_ROOT / "scripts" / "drafts"
DRAFT_RUNTIME_PATTERN = re.compile(r"^\d+_.+\.runtime\.json$")
PLACEHOLDER_NEEDLES = [
    "FILL_IN",
    "FORMAL_DRAFT_",
    "draft_marker",
    "TODO: implement",
    "interaction placeholder",
]
OPTIONAL_EMPTY_CONTENT_ROOTS = {"fields"}
REQUIRED_CONTENT_ROOTS = {"units", "skills", "effects", "passive_skills"}


def main() -> None:
    drafts_dir = _resolve_drafts_dir()
    failures: list[str] = []
    if not drafts_dir.exists():
        print(f"DRAFT_READY_SKIPPED: no draft directory found: {_rel(drafts_dir)}")
        return
    runtime_paths = [
        path for path in sorted(drafts_dir.glob("*.json"))
        if DRAFT_RUNTIME_PATTERN.fullmatch(path.name)
    ]
    if not runtime_paths:
        print(f"DRAFT_READY_SKIPPED: no formal character runtime drafts under {_rel(drafts_dir)}")
        return
    for runtime_path in runtime_paths:
        _validate_source_draft(drafts_dir, runtime_path, failures)
    if failures:
        print("DRAFT_READY_FAILED:")
        for failure in failures:
            print(f"  - {failure}")
        raise SystemExit(1)
    print(f"DRAFT_READY_PASSED: {len(runtime_paths)} formal character draft(s) are ready for live promotion")


def _resolve_drafts_dir() -> Path:
    if len(sys.argv) <= 1:
        return DEFAULT_DRAFTS_DIR
    raw_path = sys.argv[1].strip()
    if not raw_path:
        return DEFAULT_DRAFTS_DIR
    path = Path(raw_path)
    return path if path.is_absolute() else REPO_ROOT / path


def _validate_source_draft(drafts_dir: Path, runtime_path: Path, failures: list[str]) -> None:
    runtime_descriptor = _load_descriptor(runtime_path, failures)
    if not runtime_descriptor:
        return
    if runtime_descriptor.get("descriptor_kind") != "formal_character_runtime":
        failures.append(f"{_rel(runtime_path)} descriptor_kind must be formal_character_runtime")
        return
    delivery_path = runtime_path.with_name(runtime_path.name.removesuffix(".runtime.json") + ".delivery.json")
    delivery_descriptor = _load_descriptor(delivery_path, failures)
    if not delivery_descriptor:
        return
    if delivery_descriptor.get("descriptor_kind") != "formal_character_delivery":
        failures.append(f"{_rel(delivery_path)} descriptor_kind must be formal_character_delivery")
        return
    character_id = _field(runtime_descriptor, "character_id")
    pair_token = _field(runtime_descriptor, "pair_token")
    if not character_id or not pair_token:
        failures.append(f"{_rel(runtime_path)} missing character_id or pair_token")
        return
    if _field(delivery_descriptor, "character_id") != character_id:
        failures.append(f"{_rel(delivery_path)} character_id must match {_rel(runtime_path)}")
    _scan_file_for_placeholders(runtime_path, failures)
    _scan_file_for_placeholders(delivery_path, failures)
    expected_files = [
        drafts_dir / "src" / "shared" / "formal_character_baselines" / character_id / f"{character_id}_formal_character_baseline.gd",
        drafts_dir / "src" / "battle_core" / "content" / "formal_validators" / pair_token / f"content_snapshot_formal_{pair_token}_validator.gd",
        drafts_dir / "docs" / "design" / f"{character_id}_design.md",
        drafts_dir / "docs" / "design" / f"{character_id}_adjustments.md",
    ]
    for raw_suite_path in _draft_suite_paths(delivery_descriptor):
        expected_files.append(drafts_dir / raw_suite_path)
    owned_specs = runtime_descriptor.get("owned_pair_interaction_specs", [])
    if isinstance(owned_specs, list) and owned_specs:
        expected_files.append(drafts_dir / "formal_pair_interaction" / f"{pair_token}_cases.gd")
    for path in expected_files:
        _require_ready_file(path, failures)
        if path.suffix == ".gd" and "/test/suites/" in path.as_posix():
            _require_gdunit_tests(path, failures)
    for raw_content_root in runtime_descriptor.get("content_roots", []):
        content_root = REPO_ROOT / str(raw_content_root).strip()
        if not content_root.exists():
            failures.append(f"{_rel(runtime_path)} content_root does not exist: {_rel(content_root)}")
            continue
        _validate_content_root_not_empty(runtime_path, content_root, failures)
    for raw_live_path in _live_target_paths(runtime_descriptor, delivery_descriptor, runtime_path.name):
        live_path = REPO_ROOT / raw_live_path
        if live_path.exists():
            failures.append(f"{_rel(runtime_path)} live target already exists; move/merge manually: {raw_live_path}")


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


def _require_gdunit_tests(path: Path, failures: list[str]) -> None:
    if not path.exists():
        return
    text = path.read_text(encoding="utf-8")
    if not re.search(r"(?m)^\s*func\s+test_[A-Za-z0-9_]*\s*\(", text):
        failures.append(f"{_rel(path)} must contain at least one func test_*")


def _validate_content_root_not_empty(source_path: Path, content_root: Path, failures: list[str]) -> None:
    root_kind = _content_root_kind(content_root)
    if root_kind in OPTIONAL_EMPTY_CONTENT_ROOTS:
        return
    if root_kind not in REQUIRED_CONTENT_ROOTS:
        failures.append(f"{_rel(source_path)} content_root has unsupported kind: {_rel(content_root)}")
        return
    if not any(content_root.rglob("*.tres")):
        failures.append(f"{_rel(source_path)} content_root has no .tres resources: {_rel(content_root)}")


def _content_root_kind(content_root: Path) -> str:
    try:
        relative_parts = content_root.relative_to(REPO_ROOT / "content").parts
    except ValueError:
        return ""
    return relative_parts[0] if relative_parts else ""


def _draft_suite_paths(character: dict) -> list[Path]:
    suite_paths: list[Path] = []
    seen: set[str] = set()
    for raw_suite_path in [character.get("suite_path", ""), *character.get("required_suite_paths", [])]:
        suite_path = str(raw_suite_path).strip()
        if not suite_path or suite_path in seen:
            continue
        seen.add(suite_path)
        suite_paths.append(Path(suite_path))
    return suite_paths


def _scan_file_for_placeholders(path: Path, failures: list[str]) -> None:
    if path.suffix not in {".gd", ".json", ".md"}:
        return
    text = path.read_text(encoding="utf-8")
    for needle in PLACEHOLDER_NEEDLES:
        if needle in text:
            failures.append(f"{_rel(path)} contains unresolved placeholder: {needle}")


def _live_target_paths(runtime_descriptor: dict, delivery_descriptor: dict, runtime_filename: str) -> list[str]:
    character_id = _field(runtime_descriptor, "character_id")
    pair_token = _field(runtime_descriptor, "pair_token")
    delivery_filename = runtime_filename.removesuffix(".runtime.json") + ".delivery.json"
    paths = [
        f"config/formal_character_sources/{runtime_filename}",
        f"config/formal_character_sources/{delivery_filename}",
        f"src/shared/formal_character_baselines/{character_id}/{character_id}_formal_character_baseline.gd",
        f"src/battle_core/content/formal_validators/{pair_token}/content_snapshot_formal_{pair_token}_validator.gd",
        f"docs/design/{character_id}_design.md",
        f"docs/design/{character_id}_adjustments.md",
    ]
    for suite_path in _draft_suite_paths(delivery_descriptor):
        paths.append(str(suite_path))
    owned_specs = runtime_descriptor.get("owned_pair_interaction_specs", [])
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
