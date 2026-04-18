from __future__ import annotations

import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def _git_ignored_uid_patterns() -> list[str]:
    gitignore_path = ROOT / ".gitignore"
    if not gitignore_path.exists():
        return []
    ignored: list[str] = []
    for raw_line in gitignore_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        normalized = line.replace("\\", "/")
        if normalized in {"*.uid", "*.gd.uid", "/**/*.uid", "/**/*.gd.uid"}:
            ignored.append(line)
    return ignored


def _tracked_paths(pattern: str) -> set[Path]:
    completed = subprocess.run(
        ["git", "ls-files", pattern],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return {
        ROOT / line.strip()
        for line in completed.stdout.splitlines()
        if line.strip()
    }


def _all_uid_paths() -> list[Path]:
    return sorted(ROOT.rglob("*.gd.uid"))


def main() -> None:
    ignored_patterns = _git_ignored_uid_patterns()
    if ignored_patterns:
        print("REPO_CONSISTENCY_FAILED: .gitignore must not ignore .gd.uid files", file=sys.stderr)
        for pattern in ignored_patterns:
            print(f"  - {pattern}", file=sys.stderr)
        raise SystemExit(1)

    tracked_uid_paths = _tracked_paths("*.gd.uid")
    orphan_uid_paths: list[Path] = []
    untracked_uid_paths: list[Path] = []
    for uid_path in _all_uid_paths():
        gd_path = uid_path.with_suffix("")
        if not gd_path.exists():
            orphan_uid_paths.append(uid_path)
        if uid_path not in tracked_uid_paths:
            untracked_uid_paths.append(uid_path)

    if orphan_uid_paths:
        print("REPO_CONSISTENCY_FAILED: orphan .gd.uid files must be removed", file=sys.stderr)
        for path in orphan_uid_paths:
            print(f"  - {path.relative_to(ROOT)}", file=sys.stderr)
        raise SystemExit(1)

    if untracked_uid_paths:
        print("REPO_CONSISTENCY_FAILED: valid .gd.uid files must be tracked", file=sys.stderr)
        for path in untracked_uid_paths:
            print(f"  - {path.relative_to(ROOT)}", file=sys.stderr)
        raise SystemExit(1)

    print("REPO_CONSISTENCY_GATE_PASSED: .gd.uid tracking and orphan cleanup are aligned")


if __name__ == "__main__":
    main()
