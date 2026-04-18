from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCAN_ROOTS = [
    ROOT / "src",
    ROOT / "test",
    ROOT / "tests",
    ROOT / "scenes",
]
LEADING_WHITESPACE_RE = re.compile(r"^([ \t]+)")


def main() -> None:
    mixed_indent: list[str] = []
    space_indent: list[str] = []

    for scan_root in SCAN_ROOTS:
        if not scan_root.exists():
            continue
        for path in scan_root.rglob("*.gd"):
            rel = str(path.relative_to(ROOT))
            for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
                if not line.strip():
                    continue
                match = LEADING_WHITESPACE_RE.match(line)
                if match is None:
                    continue
                leading = match.group(1)
                if "\t" in leading and " " in leading:
                    mixed_indent.append(f"{rel}:{line_number}")
                    break
                if "\t" not in leading and " " in leading:
                    space_indent.append(f"{rel}:{line_number}")
                    break

    if mixed_indent or space_indent:
        print("ARCH_GATE_FAILED: GDScript files must use tab-only leading indentation", file=sys.stderr)
        for location in mixed_indent:
            print(f"  - mixed tab/space indent: {location}", file=sys.stderr)
        for location in space_indent:
            print(f"  - space-only indent: {location}", file=sys.stderr)
        sys.exit(1)

    print("ARCH_GATE_PASSED: GDScript leading indentation uses tabs only")


if __name__ == "__main__":
    main()
