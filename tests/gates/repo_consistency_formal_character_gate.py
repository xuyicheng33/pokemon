from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from repo_consistency_common import GateContext


ctx = GateContext()
formal_character_registry = ctx.load_json_array("docs/records/formal_character_registry.json", "formal character registry")
if not formal_character_registry:
    ctx.failures.append("docs/records/formal_character_registry.json must list at least one formal character")
runtime_registry_text = ctx.read_text("src/battle_core/content/content_snapshot_formal_character_registry.gd")
runtime_validator_entries = dict(
    re.findall(
        r'"character_id": "([^"]+)",\s*"validator_script": preload\("([^"]+)"\)',
        runtime_registry_text,
        re.S,
    )
)
if not runtime_validator_entries:
    ctx.failures.append("runtime formal character validator registry must declare at least one descriptor")

sample_factory_text = ctx.read_text("src/composition/sample_battle_factory.gd")
run_all_text = ctx.read_text("tests/run_all.gd")
suite_preload_pattern = re.compile(r'preload\("res://(tests/suites/[^"]+\.gd)"\)')
seen_formal_characters: set[str] = set()
reachable_suite_paths: set[str] = set()
pending_suite_paths: list[str] = suite_preload_pattern.findall(run_all_text)

for entry in formal_character_registry:
    if not isinstance(entry, dict):
        continue
    suite_path = str(entry.get("suite_path", ""))
    if suite_path != "":
        pending_suite_paths.append(suite_path)

while pending_suite_paths:
    suite_path = pending_suite_paths.pop()
    if suite_path in reachable_suite_paths:
        continue
    if not Path(suite_path).exists():
        continue
    reachable_suite_paths.add(suite_path)
    for child_suite in suite_preload_pattern.findall(ctx.read_text(suite_path)):
        pending_suite_paths.append(child_suite)

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
        ctx.require_exists(content_validator_script_path, f"{character_id} content validator script")
        runtime_validator_path = runtime_validator_entries.get(character_id, "")
        expected_runtime_path = content_validator_script_path if content_validator_script_path.startswith("res://") else "res://%s" % content_validator_script_path
        if runtime_validator_path == "":
            ctx.failures.append(
                f"runtime formal character validator registry missing descriptor for {character_id}"
            )
        elif runtime_validator_path != expected_runtime_path:
            ctx.failures.append(
                f"runtime formal character validator registry drift for {character_id}: expected {expected_runtime_path} got {runtime_validator_path}"
            )
    if not isinstance(required_suite_paths, list) or not required_suite_paths:
        ctx.failures.append(f"formal character registry[{character_id}] missing required_suite_paths")
    else:
        for rel_path in required_suite_paths:
            ctx.require_exists(str(rel_path), f"{character_id} required suite")
            suite_scope_paths.append(str(rel_path))
            if str(rel_path) not in reachable_suite_paths:
                ctx.failures.append(
                    f"formal character registry[{character_id}] required_suite_path is not reachable from tests/run_all.gd wrapper tree: {rel_path}"
                )
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

stale_runtime_descriptors = sorted(set(runtime_validator_entries.keys()) - seen_formal_characters)
for character_id in stale_runtime_descriptors:
    ctx.failures.append(
        f"runtime formal character validator registry has stale descriptor without docs registry entry: {character_id}"
    )

ctx.finish("formal character registry, suite tree, and asset delivery surface are aligned")
