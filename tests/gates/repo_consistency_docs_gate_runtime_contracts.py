from __future__ import annotations

from repo_consistency_common import GateContext


def run(ctx: GateContext) -> None:
    ctx.require_contains("docs/design/architecture_overview.md", "BattleCoreManager", "architecture manager facade entry")
    ctx.require_contains("docs/design/architecture_overview.md", "{\"ok\": true, \"data\": ... , \"error_code\": null, \"error_message\": null}", "architecture manager envelope")
    ctx.require_contains("docs/design/architecture_overview.md", "BattleCoreServiceSpecs.SERVICE_DESCRIPTORS", "architecture service descriptor source")
    ctx.require_contains("docs/design/battle_core_architecture_constraints.md", "strict DAG", "architecture wiring DAG wording")
    ctx.require_contains("docs/design/battle_core_architecture_constraints.md", "owner 私有 helper", "architecture owner-private helper wording")
    ctx.require_contains("docs/design/battle_core_architecture_constraints.md", "BattleCoreServiceSpecs", "architecture service slot governance wording")
    ctx.require_contains("docs/design/log_and_replay_contract.md", "ContentSnapshotCache", "log/replay cache contract doc")
    ctx.require_contains("docs/design/log_and_replay_contract.md", "预分组", "log/replay turn grouping doc")
    ctx.require_contains("docs/design/log_and_replay_contract.md", "turn_timeline", "log/replay turn timeline doc")
    ctx.require_contains("docs/design/log_and_replay_contract.md", "初始 frame", "log/replay initial frame wording")
