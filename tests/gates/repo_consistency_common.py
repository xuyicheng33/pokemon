from __future__ import annotations

from pathlib import Path
import json
import re
import sys


class GateContext:
    def __init__(self) -> None:
        self.root = Path(__file__).resolve().parents[2]
        self.failures: list[str] = []

    def read_text(self, rel_path: str) -> str:
        return (self.root / rel_path).read_text(encoding="utf-8")

    def require_contains(self, rel_path: str, needle: str, label: str) -> None:
        if needle not in self.read_text(rel_path):
            self.failures.append(f"{rel_path} missing {label}: {needle}")

    def require_contains_any(self, rel_paths: list[str], needle: str, label: str) -> None:
        for rel_path in rel_paths:
            if needle in self.read_text(rel_path):
                return
        self.failures.append(f"{', '.join(rel_paths)} missing {label}: {needle}")

    def require_absent(self, rel_path: str, needle: str, label: str) -> None:
        if needle in self.read_text(rel_path):
            self.failures.append(f"{rel_path} still contains stale {label}: {needle}")

    def require_exists(self, rel_path: str, label: str) -> None:
        if not (self.root / rel_path).exists():
            self.failures.append(f"missing {label}: {rel_path}")

    def gd_line_count(self, top_level_dir: str) -> int:
        total = 0
        for path in sorted((self.root / top_level_dir).rglob("*.gd")):
            total += path.read_bytes().count(b"\n")
        return total

    def require_readme_count(self, label: str, pattern: str, actual: int) -> None:
        readme_text = self.read_text("README.md")
        match = re.search(pattern, readme_text)
        if match is None:
            self.failures.append(f"README.md missing code size entry for {label}")
            return
        documented = int(match.group(1))
        if documented != actual:
            self.failures.append(f"README.md {label} count mismatch: documented={documented}, actual={actual}")

    def load_json_array(self, rel_path: str, label: str) -> list[dict]:
        try:
            payload = json.loads(self.read_text(rel_path))
        except Exception as exc:
            self.failures.append(f"{rel_path} invalid {label}: {exc}")
            return []
        if not isinstance(payload, list):
            self.failures.append(f"{rel_path} invalid {label}: expected top-level array")
            return []
        result: list[dict] = []
        for idx, raw_entry in enumerate(payload):
            if not isinstance(raw_entry, dict):
                self.failures.append(f"{rel_path} invalid {label}[{idx}]: expected object")
                continue
            result.append(raw_entry)
        return result

    def finish(self, label: str) -> None:
        if self.failures:
            for failure in self.failures:
                print(failure, file=sys.stderr)
            sys.exit(1)
        print(f"REPO_CONSISTENCY_GATE_PASSED: {label}")
