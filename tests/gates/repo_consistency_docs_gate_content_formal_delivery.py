from __future__ import annotations

from repo_consistency_common import GateContext


def run(ctx: GateContext) -> None:
    ctx.require_exists("docs/design/formal_character_delivery_checklist.md", "formal character delivery checklist")
    ctx.require_exists("docs/design/formal_character_capability_catalog.md", "formal character capability catalog doc")
    ctx.require_contains("docs/design/formal_character_delivery_checklist.md", "config/formal_character_sources/", "formal source single source wording")
    ctx.require_contains("docs/design/formal_character_delivery_checklist.md", "bash tests/sync_formal_registry.sh", "formal sync command wording")
    ctx.require_contains("docs/design/formal_character_delivery_checklist.md", "生成并提交", "formal generated artifact wording")
    ctx.require_contains("docs/design/formal_character_delivery_checklist.md", "content_validator_script_path", "formal validator path wording")
    ctx.require_contains("docs/design/formal_character_delivery_checklist.md", "shared_capability_ids", "formal shared capability wording")
    ctx.require_contains("docs/design/project_folder_structure.md", "formal_character_sources/", "project folder formal source dir wording")
    ctx.require_contains("docs/design/project_folder_structure.md", "tests/sync_formal_registry.sh", "project folder formal sync script wording")
    ctx.require_contains("docs/design/battle_content_schema.md", "config/formal_character_sources/", "schema formal source dir wording")
    ctx.require_contains("docs/design/battle_content_schema.md", "config/formal_character_manifest.json", "schema generated manifest wording")
    ctx.require_contains("docs/design/battle_content_schema.md", "config/formal_character_capability_catalog.json", "schema generated capability catalog wording")
    ctx.require_contains("docs/design/formal_character_capability_catalog.md", "00_shared_registry.json", "capability catalog shared registry wording")
