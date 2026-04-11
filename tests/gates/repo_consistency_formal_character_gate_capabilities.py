from __future__ import annotations

import json
import subprocess
import tempfile
from collections import defaultdict
from pathlib import Path


def validate_capability_catalog(
    ctx,
    *,
    capability_catalog_path: str,
    characters: list,
    manifest_path: str,
    export_script_path: str,
) -> None:
    payload = ctx.load_json_object(capability_catalog_path, "formal character capability catalog")
    raw_capabilities = payload.get("capabilities", [])
    if not isinstance(raw_capabilities, list):
        ctx.failures.append(f"{capability_catalog_path} missing capabilities array")
        return
    facts_payload = _load_capability_facts(ctx, export_script_path=export_script_path, manifest_path=manifest_path)
    facts_by_character = _normalized_fact_map(
        ctx,
        facts_payload.get("facts_by_character", {}),
        "facts_by_character",
    )
    fact_sources_by_character = _normalized_fact_sources_map(
        ctx,
        facts_payload.get("fact_sources_by_character", {}),
        "fact_sources_by_character",
    )

    character_entries: dict[str, dict] = {}
    declared_capabilities_by_character: dict[str, set[str]] = {}
    manifest_consumers: dict[str, list[str]] = defaultdict(list)

    for raw_entry in characters:
        if not isinstance(raw_entry, dict):
            continue
        entry = raw_entry
        character_id = str(entry.get("character_id", "")).strip()
        if not character_id:
            continue
        character_entries[character_id] = entry
        shared_capability_ids = _normalized_string_list(
            ctx,
            entry.get("shared_capability_ids", []),
            f"formal manifest[{character_id}] shared_capability_ids",
            allow_empty=True,
        )
        shared_capability_set = set(shared_capability_ids)
        if len(shared_capability_set) != len(shared_capability_ids):
            ctx.failures.append(f"formal manifest[{character_id}] shared_capability_ids contains duplicates")
        declared_capabilities_by_character[character_id] = shared_capability_set
        for capability_id in shared_capability_ids:
            manifest_consumers[capability_id].append(character_id)

    capability_entries: dict[str, dict[str, object]] = {}
    for capability_index, raw_capability in enumerate(raw_capabilities):
        if not isinstance(raw_capability, dict):
            ctx.failures.append(f"{capability_catalog_path} capabilities[{capability_index}] must be object")
            continue
        capability = raw_capability
        capability_id = str(capability.get("capability_id", "")).strip()
        if not capability_id:
            ctx.failures.append(f"{capability_catalog_path} capabilities[{capability_index}] missing capability_id")
            continue
        if capability_id in capability_entries:
            ctx.failures.append(f"{capability_catalog_path} duplicated capability_id: {capability_id}")
            continue
        rule_doc_paths = _normalized_string_list(
            ctx,
            capability.get("rule_doc_paths", []),
            f"{capability_catalog_path}[{capability_id}].rule_doc_paths",
        )
        required_suite_paths = _normalized_string_list(
            ctx,
            capability.get("required_suite_paths", []),
            f"{capability_catalog_path}[{capability_id}].required_suite_paths",
        )
        coverage_needles = _normalized_string_list(
            ctx,
            capability.get("coverage_needles", []),
            f"{capability_catalog_path}[{capability_id}].coverage_needles",
        )
        stop_and_specialize_when = str(capability.get("stop_and_specialize_when", "")).strip()
        if not stop_and_specialize_when:
            ctx.failures.append(f"{capability_catalog_path}[{capability_id}] missing stop_and_specialize_when")
        if len(set(required_suite_paths)) != len(required_suite_paths):
            ctx.failures.append(f"{capability_catalog_path}[{capability_id}].required_suite_paths contains duplicates")
        if len(set(coverage_needles)) != len(coverage_needles):
            ctx.failures.append(f"{capability_catalog_path}[{capability_id}].coverage_needles contains duplicates")
        for rel_path in rule_doc_paths:
            ctx.require_exists(rel_path, f"{capability_id} rule doc")
        for rel_path in required_suite_paths:
            ctx.require_exists(rel_path, f"{capability_id} required suite")
        capability_entries[capability_id] = {
            "required_suite_paths": required_suite_paths,
            "coverage_needles": coverage_needles,
        }

    for capability_id, capability in capability_entries.items():
        actual_consumers = sorted(manifest_consumers.get(capability_id, []))
        if not actual_consumers:
            ctx.failures.append(f"{capability_catalog_path}[{capability_id}] has no manifest consumers")

    for character_id, entry in character_entries.items():
        evidence_fact_set = set(facts_by_character.get(character_id, []))
        fact_sources = fact_sources_by_character.get(character_id, {})
        for capability_id, capability in capability_entries.items():
            coverage_needles = capability["coverage_needles"]
            matched_needles = [needle for needle in coverage_needles if needle in evidence_fact_set]
            declared = capability_id in declared_capabilities_by_character.get(character_id, set())
            if declared and not matched_needles:
                ctx.failures.append(
                    f"formal manifest[{character_id}] capability[{capability_id}] has no semantic evidence; available facts: {sorted(evidence_fact_set)}"
                )
            if matched_needles and not declared:
                matched_sources = {
                    needle: fact_sources.get(needle, [])
                    for needle in matched_needles
                }
                ctx.failures.append(
                    f"formal manifest[{character_id}] missing shared_capability_id for {capability_id}; matched facts: {matched_needles}; sources: {matched_sources}"
                )


def _normalized_string_list(ctx, raw_values, label: str, *, allow_empty: bool = False) -> list[str]:
    if not isinstance(raw_values, list):
        ctx.failures.append(f"{label} must be array")
        return []
    values: list[str] = []
    for raw_value in raw_values:
        value = str(raw_value).strip()
        if not value:
            ctx.failures.append(f"{label} contains empty value")
            continue
        values.append(value)
    if not allow_empty and not values:
        ctx.failures.append(f"{label} must not be empty")
    return values


def _load_capability_facts(ctx, *, export_script_path: str, manifest_path: str) -> dict:
    if not (ctx.root / export_script_path).exists():
        ctx.failures.append(f"missing capability fact export script: {export_script_path}")
        return {}
    with tempfile.NamedTemporaryFile(delete=False, suffix=".json") as handle:
        output_path = Path(handle.name)
    try:
        result = subprocess.run(
            [
                "godot",
                "--headless",
                "--path",
                ".",
                "--script",
                export_script_path,
                "--",
                str(output_path),
                manifest_path,
            ],
            cwd=ctx.root,
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            stderr = result.stderr.strip()
            stdout = result.stdout.strip()
            combined_output = " | ".join(chunk for chunk in [stderr, stdout] if chunk)
            ctx.failures.append(
                f"{export_script_path} failed to export capability facts: {combined_output or f'exit={result.returncode}'}"
            )
            return {}
        try:
            payload = json.loads(output_path.read_text(encoding="utf-8"))
        except Exception as exc:
            ctx.failures.append(f"{export_script_path} wrote invalid JSON: {exc}")
            return {}
        if not isinstance(payload, dict):
            ctx.failures.append(f"{export_script_path} must export top-level object")
            return {}
        return payload
    except FileNotFoundError:
        ctx.failures.append(f"{export_script_path} requires godot in PATH")
        return {}
    finally:
        output_path.unlink(missing_ok=True)


def _normalized_fact_map(ctx, raw_map, label: str) -> dict[str, list[str]]:
    if not isinstance(raw_map, dict):
        ctx.failures.append(f"{label} must be object")
        return {}
    normalized: dict[str, list[str]] = {}
    for raw_character_id, raw_facts in raw_map.items():
        character_id = str(raw_character_id).strip()
        if not character_id:
            ctx.failures.append(f"{label} contains empty character_id")
            continue
        normalized[character_id] = _normalized_string_list(
            ctx,
            raw_facts,
            f"{label}[{character_id}]",
            allow_empty=True,
        )
    return normalized


def _normalized_fact_sources_map(ctx, raw_map, label: str) -> dict[str, dict[str, list[str]]]:
    if not isinstance(raw_map, dict):
        ctx.failures.append(f"{label} must be object")
        return {}
    normalized: dict[str, dict[str, list[str]]] = {}
    for raw_character_id, raw_fact_sources in raw_map.items():
        character_id = str(raw_character_id).strip()
        if not character_id:
            ctx.failures.append(f"{label} contains empty character_id")
            continue
        if not isinstance(raw_fact_sources, dict):
            ctx.failures.append(f"{label}[{character_id}] must be object")
            continue
        normalized_fact_sources: dict[str, list[str]] = {}
        for raw_fact_id, raw_sources in raw_fact_sources.items():
            fact_id = str(raw_fact_id).strip()
            if not fact_id:
                ctx.failures.append(f"{label}[{character_id}] contains empty fact_id")
                continue
            normalized_fact_sources[fact_id] = _normalized_string_list(
                ctx,
                raw_sources,
                f"{label}[{character_id}][{fact_id}]",
                allow_empty=True,
            )
        normalized[character_id] = normalized_fact_sources
    return normalized
