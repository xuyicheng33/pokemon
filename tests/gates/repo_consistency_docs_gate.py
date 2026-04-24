from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from repo_consistency_common import GateContext


CURRENT_WORKFLOW_DOC = "docs/design/current_development_workflow.md"
CURRENT_REGRESSION_BASELINE_DOC = "docs/design/current_stage_regression_baseline.md"


def _run_runtime_contracts(ctx: GateContext) -> None:
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


def _run_content_formal_delivery(ctx: GateContext) -> None:
    ctx.require_exists("docs/design/formal_character_delivery_checklist.md", "formal character delivery checklist")
    ctx.require_exists("docs/design/formal_character_capability_catalog.md", "formal character capability catalog doc")
    ctx.require_contains("docs/design/formal_character_delivery_checklist.md", "config/formal_character_sources/", "formal source single source wording")
    ctx.require_contains("docs/design/formal_character_delivery_checklist.md", "bash tests/sync_formal_registry.sh", "formal sync command wording")
    ctx.require_contains("docs/design/formal_character_delivery_checklist.md", "生成并提交", "formal generated artifact wording")
    ctx.require_contains("docs/design/formal_character_delivery_checklist.md", "content_validator_script_path", "formal validator path wording")
    ctx.require_contains("docs/design/formal_character_delivery_checklist.md", "shared_capability_ids", "formal shared capability wording")
    ctx.require_contains("docs/design/formal_character_delivery_checklist.md", "manifest 角色顺序是 pair interaction ownership 的正式输入", "formal pair ownership ordering wording")
    ctx.require_contains("docs/design/battle_content_schema.md", "manifest 角色顺序是 pair interaction ownership 的稳定输入", "schema pair ownership ordering wording")
    ctx.require_contains("docs/records/decisions.md", "manifest 角色顺序继续作为 pair interaction ownership 的稳定输入", "decision pair ownership ordering wording")
    ctx.require_contains("docs/design/project_folder_structure.md", "formal_character_sources/", "project folder formal source dir wording")
    ctx.require_contains("docs/design/project_folder_structure.md", "tests/sync_formal_registry.sh", "project folder formal sync script wording")
    ctx.require_contains("docs/design/battle_content_schema.md", "config/formal_character_sources/", "schema formal source dir wording")
    ctx.require_contains("docs/design/battle_content_schema.md", "config/formal_character_manifest.json", "schema generated manifest wording")
    ctx.require_contains("docs/design/battle_content_schema.md", "config/formal_character_capability_catalog.json", "schema generated capability catalog wording")
    ctx.require_contains("docs/design/formal_character_capability_catalog.md", "00_shared_registry.json", "capability catalog shared registry wording")


def _run_sandbox_testing_surface(ctx: GateContext) -> None:
    ctx.require_exists(CURRENT_WORKFLOW_DOC, "current development workflow design doc")
    ctx.require_exists(CURRENT_REGRESSION_BASELINE_DOC, "current stage regression baseline design doc")
    ctx.require_contains(CURRENT_WORKFLOW_DOC, "文档治理基线", "workflow documentation baseline section")
    ctx.require_contains(CURRENT_WORKFLOW_DOC, "哪些文档是规范源", "workflow source-of-truth wording")
    ctx.require_contains(CURRENT_WORKFLOW_DOC, "formal 产物同步入口", "workflow formal sync section")
    ctx.require_contains(CURRENT_WORKFLOW_DOC, "测试分类口径", "workflow test taxonomy section")
    ctx.require_contains(CURRENT_WORKFLOW_DOC, "Sandbox 日常试玩路径", "workflow sandbox section")
    ctx.require_contains(CURRENT_WORKFLOW_DOC, "测试入口与推荐跑法", "workflow test section")
    ctx.require_contains(CURRENT_WORKFLOW_DOC, "文档更新顺序与记录要求", "workflow documentation update section")
    ctx.require_contains(CURRENT_WORKFLOW_DOC, "BattleSandbox", "workflow sandbox main entry wording")
    ctx.require_contains(CURRENT_WORKFLOW_DOC, "bash tests/sync_formal_registry.sh", "workflow formal sync command wording")
    ctx.require_contains(CURRENT_WORKFLOW_DOC, "tests/run_with_gate.sh", "workflow unique total gate wording")
    ctx.require_contains(CURRENT_WORKFLOW_DOC, "gdUnit4 -> boot smoke -> suite reachability -> architecture constraints -> repo consistency -> sandbox smoke matrix", "workflow fixed total gate order wording")
    ctx.require_contains(CURRENT_WORKFLOW_DOC, "docs/design/current_stage_regression_baseline.md", "workflow regression baseline doc wording")
    ctx.require_contains(CURRENT_WORKFLOW_DOC, "gdUnit4 + test/", "workflow gdunit test tree wording")
    ctx.require_contains(CURRENT_WORKFLOW_DOC, "docs/records/tasks.md", "workflow tasks record wording")
    ctx.require_contains(CURRENT_WORKFLOW_DOC, "docs/records/decisions.md", "workflow decisions record wording")
    ctx.require_contains("README.md", "docs/design/current_development_workflow.md", "README workflow entry doc")
    ctx.require_contains("README.md", "docs/design/current_stage_regression_baseline.md", "README regression baseline doc")
    ctx.require_contains("README.md", "tests/check_sandbox_smoke_matrix.sh", "README sandbox smoke matrix doc")
    ctx.require_contains("README.md", "BattleSandbox", "README sandbox main entry wording")
    ctx.require_contains("README.md", "tests/run_with_gate.sh", "README unique total gate wording")
    ctx.require_contains("README.md", "tests/sync_formal_registry.sh", "README formal sync command doc")
    ctx.require_contains("tests/README.md", "docs/design/current_development_workflow.md", "tests README workflow entry doc")
    ctx.require_contains("tests/README.md", "docs/design/current_stage_regression_baseline.md", "tests README regression baseline doc")
    ctx.require_contains("tests/README.md", "tests/check_sandbox_smoke_matrix.sh", "tests README sandbox smoke matrix doc")
    ctx.require_contains("tests/README.md", "tests/sync_formal_registry.sh", "tests README formal sync command doc")
    ctx.require_contains("tests/README.md", "测试分类口径", "tests README test taxonomy wording")
    ctx.require_contains("tests/README.md", "tests/run_with_gate.sh", "tests README unique total gate wording")
    ctx.require_contains("tests/README.md", "BattleSandbox", "tests README sandbox wording")
    ctx.require_contains(CURRENT_REGRESSION_BASELINE_DOC, "tests/run_with_gate.sh", "regression baseline total gate command")
    ctx.require_contains(CURRENT_REGRESSION_BASELINE_DOC, "tests/check_sandbox_smoke_matrix.sh", "regression baseline smoke matrix command")
    ctx.require_contains(CURRENT_REGRESSION_BASELINE_DOC, "manual_battle_full_run.gd", "regression baseline headless helper command")
    ctx.require_contains(CURRENT_REGRESSION_BASELINE_DOC, "可启动", "regression baseline playability launch check")
    ctx.require_contains(CURRENT_REGRESSION_BASELINE_DOC, "能跑完一局", "regression baseline playability finish check")
    ctx.require_contains(CURRENT_REGRESSION_BASELINE_DOC, "统一终局摘要", "regression baseline summary wording")
    ctx.require_contains("docs/design/project_folder_structure.md", "test/suites", "project folder test suite tree wording")
    ctx.require_contains("docs/rules/README.md", "`docs/design/`", "rules README design reference wording")


def _run_records_archive_wording(ctx: GateContext) -> None:
    ctx.require_exists("docs/records/decisions.md", "active decisions record")
    ctx.require_exists("docs/records/tasks.md", "active tasks record")
    ctx.require_exists("docs/records/archive/decisions_pre_2026-04-05_repair_wave.md", "decisions repair-wave archive")
    ctx.require_exists("docs/records/archive/tasks_pre_2026-04-05_repair_wave.md", "tasks repair-wave archive")
    ctx.require_contains("docs/records/tasks.md", "当前验证基线", "tasks active validation baseline section")
    ctx.require_contains("docs/records/decisions.md", "README", "decisions README role wording")
    ctx.require_contains("docs/records/decisions.md", "tests/sync_formal_registry.sh", "decisions formal sync command wording")


ctx = GateContext()

_run_runtime_contracts(ctx)
_run_content_formal_delivery(ctx)
_run_sandbox_testing_surface(ctx)
_run_records_archive_wording(ctx)

ctx.finish("doc sources, workflow entrypoints, and active records are aligned")
