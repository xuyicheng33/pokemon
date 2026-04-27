from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from repo_consistency_common import GateContext


# 入口/路径锚定。Batch J 减负：旧 96 行版本对 design docs 的中文 heading 与
# 段落字面量做了 27 处 `require_contains` 镜像，作者一改 heading 就红，与
# 业务正确性无关。本次保留的是真业务约束：
#   1) design docs / records / archive 文件存在（11 处 `require_exists`）
#   2) README 与 design docs 之间的双向链接收口（4 处）
#   3) entrypoint 命令名 / config 路径锚（5 处）
# 其它中文短语镜像由作者自由调整，正确性靠 gdunit / smoke matrix / 单元 gate 守。

DESIGN_DOC_FILES = [
    ("docs/design/architecture_overview.md", "architecture overview"),
    ("docs/design/battle_core_architecture_constraints.md", "battle_core architecture constraints"),
    ("docs/design/log_and_replay_contract.md", "log and replay contract"),
    ("docs/design/formal_character_delivery_checklist.md", "formal character delivery checklist"),
    ("docs/design/formal_character_capability_catalog.md", "formal character capability catalog"),
    ("docs/design/battle_content_schema.md", "battle content schema"),
    ("docs/design/project_folder_structure.md", "project folder structure"),
    ("docs/design/current_development_workflow.md", "current development workflow"),
    ("docs/design/current_stage_regression_baseline.md", "current stage regression baseline"),
]

RECORD_FILES = [
    ("docs/records/decisions.md", "active decisions record"),
    ("docs/records/tasks.md", "active tasks record"),
    ("docs/records/archive/decisions_pre_2026-04-05_repair_wave.md", "decisions repair-wave archive"),
    ("docs/records/archive/tasks_pre_2026-04-05_repair_wave.md", "tasks repair-wave archive"),
]

# (file, anchor_text, label) — 必须保留的入口/路径锚定。这些是机器/CI 真正
# 依赖的字符串（命令名、config 路径、文档间链接），与中文 heading 流变性无关。
DOCS_ANCHOR_WORDS = [
    ("README.md", "docs/design/current_development_workflow.md", "README workflow entry link"),
    ("README.md", "docs/design/current_stage_regression_baseline.md", "README regression baseline link"),
    ("tests/README.md", "docs/design/current_development_workflow.md", "tests README workflow entry link"),
    ("tests/README.md", "docs/design/current_stage_regression_baseline.md", "tests README regression baseline link"),
    ("docs/design/current_development_workflow.md", "bash tests/sync_formal_registry.sh", "formal sync entrypoint"),
    ("docs/design/current_development_workflow.md", "tests/run_with_gate.sh", "quick gate entrypoint"),
    ("docs/design/current_development_workflow.md", "tests/run_extended_gate.sh", "extended gate entrypoint"),
    ("docs/design/formal_character_delivery_checklist.md", "config/formal_character_sources/", "formal source single source path"),
    ("docs/design/battle_content_schema.md", "config/formal_character_manifest.json", "schema generated manifest path"),
    ("docs/design/battle_content_schema.md", "config/formal_character_capability_catalog.json", "schema generated capability catalog path"),
]


ctx = GateContext()

for path, label in DESIGN_DOC_FILES + RECORD_FILES:
    ctx.require_exists(path, label)

for path, anchor, label in DOCS_ANCHOR_WORDS:
    ctx.require_contains(path, anchor, label)

ctx.finish("doc sources, workflow entrypoints, and active records are aligned")
