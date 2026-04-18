from __future__ import annotations

from repo_consistency_common import GateContext


def run(ctx: GateContext) -> None:
    ctx.require_exists("docs/records/decisions.md", "active decisions record")
    ctx.require_exists("docs/records/tasks.md", "active tasks record")
    ctx.require_exists("docs/records/archive/decisions_pre_2026-04-05_repair_wave.md", "decisions repair-wave archive")
    ctx.require_exists("docs/records/archive/tasks_pre_2026-04-05_repair_wave.md", "tasks repair-wave archive")
    ctx.require_contains("docs/records/tasks.md", "当前验证基线", "tasks active validation baseline section")
    ctx.require_contains("docs/records/decisions.md", "README", "decisions README role wording")
    ctx.require_contains("docs/records/decisions.md", "tests/sync_formal_registry.sh", "decisions formal sync command wording")
