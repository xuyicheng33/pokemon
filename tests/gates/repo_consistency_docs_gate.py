from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from repo_consistency_common import GateContext
from repo_consistency_docs_gate_module_self_check import run as run_docs_gate_module_self_check
from repo_consistency_docs_gate_content_formal_delivery import run as run_content_formal_delivery
from repo_consistency_docs_gate_records_archive_wording import run as run_records_archive_wording
from repo_consistency_docs_gate_runtime_contracts import run as run_runtime_contracts
from repo_consistency_docs_gate_sandbox_testing_surface import run as run_sandbox_testing_surface


ctx = GateContext()

run_docs_gate_module_self_check(ctx)
run_runtime_contracts(ctx)
run_content_formal_delivery(ctx)
run_sandbox_testing_surface(ctx)
run_records_archive_wording(ctx)

ctx.finish("doc sources, workflow entrypoints, and active records are aligned")
