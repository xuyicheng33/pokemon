from __future__ import annotations

from collections import defaultdict


def validate_capability_catalog(
    ctx,
    *,
    capability_catalog_path: str,
    characters: list,
) -> None:
    payload = ctx.load_json_object(capability_catalog_path, "formal character capability catalog")
    raw_capabilities = payload.get("capabilities", [])
    if not isinstance(raw_capabilities, list):
        ctx.failures.append(f"{capability_catalog_path} missing capabilities array")
        return

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
        evidence_paths = _capability_evidence_paths(entry)
        evidence_text = _joined_existing_text(ctx, evidence_paths)
        for capability_id, capability in capability_entries.items():
            coverage_needles = capability["coverage_needles"]
            matched_needles = [needle for needle in coverage_needles if needle in evidence_text]
            declared = capability_id in declared_capabilities_by_character.get(character_id, set())
            if declared and not matched_needles:
                ctx.failures.append(
                    f"formal manifest[{character_id}] capability[{capability_id}] has no evidence in content/validator/docs scan scope"
                )
            if matched_needles and not declared:
                ctx.failures.append(
                    f"formal manifest[{character_id}] missing shared_capability_id for {capability_id}; matched needles: {matched_needles}"
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


def _capability_evidence_paths(entry: dict) -> list[str]:
    paths: list[str] = []
    for rel_path in entry.get("required_content_paths", []):
        path = str(rel_path).strip()
        if path:
            paths.append(path)
    for path_key in ["content_validator_script_path", "design_doc", "adjustment_doc", "suite_path"]:
        rel_path = str(entry.get(path_key, "")).strip()
        if rel_path:
            paths.append(rel_path)
    deduped_paths: list[str] = []
    seen_paths: set[str] = set()
    for rel_path in paths:
        if rel_path in seen_paths:
            continue
        seen_paths.add(rel_path)
        deduped_paths.append(rel_path)
    return deduped_paths


def _joined_existing_text(ctx, rel_paths: list[str]) -> str:
    chunks: list[str] = []
    for rel_path in rel_paths:
        abs_path = ctx.root / rel_path
        if not abs_path.exists() or abs_path.is_dir():
            continue
        chunks.append(abs_path.read_text(encoding="utf-8"))
    return "\n".join(chunks)
