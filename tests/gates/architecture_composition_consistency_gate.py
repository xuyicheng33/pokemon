from __future__ import annotations

import sys

from architecture_composition_consistency_gate_checks import run
from architecture_composition_consistency_gate_support import GateFailure


try:
    run()
except GateFailure as exc:
    print(f"ARCH_GATE_FAILED: {exc.message}", file=sys.stderr)
    for detail in exc.details:
        print(f"  - {detail}", file=sys.stderr)
    sys.exit(1)

print("ARCH_GATE_PASSED: composition descriptors, container API, and wiring specs are aligned")
