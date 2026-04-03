from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from repo_consistency_common import GateContext


ctx = GateContext()
formal_character_registry = ctx.load_json_array("docs/records/formal_character_registry.json", "formal character registry")
if not formal_character_registry:
    ctx.failures.append("docs/records/formal_character_registry.json must list at least one formal character")
runtime_validator_registry = ctx.load_json_array(
    "src/battle_core/content/formal_character_validator_registry.json",
    "formal character validator registry",
)

sample_factory_text = ctx.read_text("src/composition/sample_battle_factory.gd")
docs_validator_paths: dict[str, str] = {}
runtime_validator_paths: dict[str, str] = {}
seen_formal_characters: set[str] = set()

for entry in runtime_validator_registry:
    character_id = str(entry.get("character_id", ""))
    content_validator_script_path = str(entry.get("content_validator_script_path", ""))
    if character_id == "":
        ctx.failures.append("src/battle_core/content/formal_character_validator_registry.json missing character_id")
        continue
    if character_id in runtime_validator_paths:
        ctx.failures.append(f"runtime validator registry duplicated character_id: {character_id}")
    runtime_validator_paths[character_id] = content_validator_script_path
    if content_validator_script_path == "":
        ctx.failures.append(f"runtime validator registry[{character_id}] missing content_validator_script_path")
    else:
        ctx.require_exists(content_validator_script_path, f"{character_id} runtime validator script")

for entry in formal_character_registry:
    character_id = str(entry.get("character_id", ""))
    unit_definition_id = str(entry.get("unit_definition_id", ""))
    design_doc = str(entry.get("design_doc", ""))
    adjustment_doc = str(entry.get("adjustment_doc", ""))
    suite_path = str(entry.get("suite_path", ""))
    sample_setup_method = str(entry.get("sample_setup_method", ""))
    content_validator_script_path = str(entry.get("content_validator_script_path", ""))
    required_content_paths = entry.get("required_content_paths", [])
    required_suite_paths = entry.get("required_suite_paths", [])
    required_test_names = entry.get("required_test_names", [])
    design_needles = entry.get("design_needles", [])
    adjustment_needles = entry.get("adjustment_needles", [])
    suite_scope_paths: list[str] = []
    if character_id == "":
        ctx.failures.append("formal character registry entry missing character_id")
        continue
    if character_id in seen_formal_characters:
        ctx.failures.append(f"formal character registry duplicated character_id: {character_id}")
    seen_formal_characters.add(character_id)
    if unit_definition_id == "":
        ctx.failures.append(f"formal character registry[{character_id}] missing unit_definition_id")
    if design_doc == "":
        ctx.failures.append(f"formal character registry[{character_id}] missing design_doc")
    else:
        ctx.require_exists(design_doc, f"{character_id} design doc")
    if adjustment_doc == "":
        ctx.failures.append(f"formal character registry[{character_id}] missing adjustment_doc")
    else:
        ctx.require_exists(adjustment_doc, f"{character_id} adjustment doc")
    if suite_path == "":
        ctx.failures.append(f"formal character registry[{character_id}] missing suite_path")
    else:
        ctx.require_exists(suite_path, f"{character_id} suite")
        suite_scope_paths.append(suite_path)
    if sample_setup_method == "":
        ctx.failures.append(f"formal character registry[{character_id}] missing sample_setup_method")
    elif f"func {sample_setup_method}(" not in sample_factory_text:
        ctx.failures.append(f"src/composition/sample_battle_factory.gd missing sample setup builder: {sample_setup_method}")
    if content_validator_script_path != "":
        docs_validator_paths[character_id] = content_validator_script_path
        ctx.require_exists(content_validator_script_path, f"{character_id} content validator script")
    if not isinstance(required_suite_paths, list) or not required_suite_paths:
        ctx.failures.append(f"formal character registry[{character_id}] missing required_suite_paths")
    else:
        for rel_path in required_suite_paths:
            ctx.require_exists(str(rel_path), f"{character_id} required suite")
            suite_scope_paths.append(str(rel_path))
    if not isinstance(required_test_names, list) or not required_test_names:
        ctx.failures.append(f"formal character registry[{character_id}] missing required_test_names")
    else:
        for test_name in required_test_names:
            ctx.require_contains_any(
                suite_scope_paths,
                'runner.run_test("%s"' % str(test_name),
                f"{character_id} regression anchor",
            )
    if not isinstance(required_content_paths, list) or not required_content_paths:
        ctx.failures.append(f"formal character registry[{character_id}] missing required_content_paths")
    else:
        for rel_path in required_content_paths:
            ctx.require_exists(str(rel_path), f"{character_id} content asset")
    if not isinstance(design_needles, list) or not design_needles:
        ctx.failures.append(f"formal character registry[{character_id}] missing design_needles")
    elif design_doc != "":
        for needle in design_needles:
            ctx.require_contains(design_doc, str(needle), f"{character_id} design anchor")
    if not isinstance(adjustment_needles, list) or not adjustment_needles:
        ctx.failures.append(f"formal character registry[{character_id}] missing adjustment_needles")
    elif adjustment_doc != "":
        for needle in adjustment_needles:
            ctx.require_contains(adjustment_doc, str(needle), f"{character_id} adjustment anchor")

for character_id, docs_path in docs_validator_paths.items():
    runtime_path = runtime_validator_paths.get(character_id, "")
    if runtime_path == "":
        ctx.failures.append(f"runtime validator registry missing character: {character_id}")
        continue
    if runtime_path != docs_path:
        ctx.failures.append(
            "validator registry path mismatch for %s: docs=%s runtime=%s"
            % (character_id, docs_path, runtime_path)
        )

for character_id in runtime_validator_paths:
    if character_id not in docs_validator_paths:
        ctx.failures.append(f"runtime validator registry contains undeclared character: {character_id}")

ctx.finish("formal character registry, suite tree, and asset delivery surface are aligned")
