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

    def require_regex(self, rel_path: str, pattern: str, label: str) -> None:
        if re.search(pattern, self.read_text(rel_path), re.M) is None:
            self.failures.append(f"{rel_path} missing {label}: /{pattern}/")

    def require_regex_any(self, rel_paths: list[str], pattern: str, label: str) -> None:
        for rel_path in rel_paths:
            if re.search(pattern, self.read_text(rel_path), re.M) is not None:
                return
        self.failures.append(f"{', '.join(rel_paths)} missing {label}: /{pattern}/")

    def require_anchor(self, rel_path: str, anchor_id: str, label: str) -> None:
        normalized_anchor_id = anchor_id.removeprefix("anchor:")
        anchor_token = f"anchor:{normalized_anchor_id}"
        if anchor_token not in self.read_text(rel_path):
            self.failures.append(f"{rel_path} missing {label}: {anchor_token}")

    def require_absent(self, rel_path: str, needle: str, label: str) -> None:
        if needle in self.read_text(rel_path):
            self.failures.append(f"{rel_path} still contains stale {label}: {needle}")

    def require_exists(self, rel_path: str, label: str) -> None:
        if not (self.root / rel_path).exists():
            self.failures.append(f"missing {label}: {rel_path}")

    def require_not_exists(self, rel_path: str, label: str) -> None:
        if (self.root / rel_path).exists():
            self.failures.append(f"stale {label} must be removed: {rel_path}")

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

    def load_json_object(self, rel_path: str, label: str) -> dict:
        try:
            payload = json.loads(self.read_text(rel_path))
        except Exception as exc:
            self.failures.append(f"{rel_path} invalid {label}: {exc}")
            return {}
        if not isinstance(payload, dict):
            self.failures.append(f"{rel_path} invalid {label}: expected top-level object")
            return {}
        return payload

    def finish(self, label: str) -> None:
        if self.failures:
            for failure in self.failures:
                print(failure, file=sys.stderr)
            sys.exit(1)
        print(f"REPO_CONSISTENCY_GATE_PASSED: {label}")
