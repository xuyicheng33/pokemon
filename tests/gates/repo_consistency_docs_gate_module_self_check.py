from __future__ import annotations

from repo_consistency_common import GateContext


DOCS_GATE_ENTRY = "tests/gates/repo_consistency_docs_gate.py"
EXPECTED_DOCS_GATE_MODULES = [
    ("repo_consistency_docs_gate_module_self_check", "run_docs_gate_module_self_check"),
    ("repo_consistency_docs_gate_runtime_contracts", "run_runtime_contracts"),
    ("repo_consistency_docs_gate_content_formal_delivery", "run_content_formal_delivery"),
    ("repo_consistency_docs_gate_sandbox_testing_surface", "run_sandbox_testing_surface"),
    ("repo_consistency_docs_gate_records_archive_wording", "run_records_archive_wording"),
]


def run(ctx: GateContext) -> None:
    ctx.require_exists(DOCS_GATE_ENTRY, "docs gate aggregate entry")
    for module_name, run_alias in EXPECTED_DOCS_GATE_MODULES:
        ctx.require_exists(f"tests/gates/{module_name}.py", f"docs gate module {module_name}")
        ctx.require_contains(
            DOCS_GATE_ENTRY,
            f"from {module_name} import run as {run_alias}",
            f"docs gate import {module_name}",
        )
        ctx.require_contains(
            DOCS_GATE_ENTRY,
            f"{run_alias}(ctx)",
            f"docs gate dispatch {run_alias}",
        )
