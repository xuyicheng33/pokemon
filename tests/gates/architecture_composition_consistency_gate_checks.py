from __future__ import annotations

import re

from architecture_composition_consistency_gate_support import (
    ROOT,
    CompositionTexts,
    DescriptorFacts,
    build_descriptor_facts,
    declared_field_names_for_script,
    dynamic_declared_field_names_for_slot,
    duplicate_names,
    fail,
    load_composition_texts,
)


def validate_wiring_specs_entry_points(texts: CompositionTexts) -> None:
    required_wiring_specs_helpers = [
        "static func wiring_specs() -> Array:",
        "static func reset_specs() -> Array:",
    ]
    missing_wiring_specs_helpers = [
        helper for helper in required_wiring_specs_helpers if helper not in texts.wiring_specs_text
    ]
    if missing_wiring_specs_helpers:
        fail("battle_core_wiring_specs must expose aggregated helpers", missing_wiring_specs_helpers)
    if "src/composition/battle_core_wiring_specs/" not in texts.wiring_specs_text:
        fail("battle_core_wiring_specs must preload child spec files from the split directory", ["src/composition/battle_core_wiring_specs"])
    if "EffectsCoreWiringSpecsScript.wiring_specs()" not in texts.wiring_specs_text:
        fail("battle_core_wiring_specs must build effects-core wiring through the helper", ["EffectsCoreWiringSpecsScript.wiring_specs()"])
    if "registry_wiring_specs" not in texts.payload_contract_registry_text:
        fail("payload contract registry must expose payload_handler_registry wiring facts", ["src/battle_core/content/payload_contract_registry.gd"])
    if "handler_wiring_specs" not in texts.payload_contract_registry_text:
        fail("payload contract registry must expose payload handler wiring facts", ["src/battle_core/content/payload_contract_registry.gd"])
    if "runtime_service_slots" not in texts.payload_contract_registry_text:
        fail("payload contract registry must expose runtime service slots", ["src/battle_core/content/payload_contract_registry.gd"])
    if "shared_service_wiring_specs" not in texts.payload_service_specs_text:
        fail("payload service specs helper must expose shared service wiring facts", ["src/composition/battle_core_payload_service_specs.gd"])
    if "PayloadRuntimeServiceRegistryScript" not in texts.payload_service_specs_text:
        fail("payload service specs helper must aggregate runtime service registry descriptors", ["src/composition/battle_core_payload_runtime_service_registry.gd"])
    if "PayloadValidatorRegistryScript" not in texts.content_payload_validator_text:
        fail("content payload validator must dispatch through payload validator registry", ["src/battle_core/content/payload_validator_registry.gd"])


def validate_service_descriptors(texts: CompositionTexts, facts: DescriptorFacts) -> tuple[set[str], set[str]]:
    for label, names in [
        ("SERVICE_DESCRIPTORS slots", facts.service_slots),
        ("SERVICE_DESCRIPTORS scripts", [slot for slot, _script in facts.script_slots]),
    ]:
        duplicates = duplicate_names(names)
        if duplicates:
            fail(f"{label} contains duplicate entries", duplicates)
    slot_set = set(facts.service_slots)
    script_slot_set = {slot for slot, _script in facts.script_slots}
    missing_script_slots = sorted(slot_set - script_slot_set)
    stale_script_slots = sorted(script_slot_set - slot_set)
    if missing_script_slots or stale_script_slots:
        details = [f"SERVICE_DESCRIPTORS missing script: {slot}" for slot in missing_script_slots]
        details.extend(f"SERVICE_DESCRIPTORS stale script slot: {slot}" for slot in stale_script_slots)
        fail("battle_core_service_specs descriptors drifted apart", details)
    required_service_specs_helpers = [
        "static func payload_service_descriptors() -> Array:",
        "static func all_service_descriptors() -> Array:",
        "static func service_slots()",
        "static func script_by_slot(slot_name: String):",
    ]
    missing_service_specs_helpers = [
        helper for helper in required_service_specs_helpers if helper not in texts.service_specs_text
    ]
    if missing_service_specs_helpers:
        fail("battle_core_service_specs must expose helpers derived from SERVICE_DESCRIPTORS", missing_service_specs_helpers)
    if "PayloadServiceSpecsScript.service_descriptors()" not in texts.service_specs_text:
        fail("battle_core_service_specs must derive payload service descriptors from payload service specs helper", ["src/composition/battle_core_payload_service_specs.gd"])
    return slot_set, script_slot_set


def validate_payload_seams(texts: CompositionTexts, facts: DescriptorFacts) -> None:
    payload_handler_slot_set = set(facts.payload_handler_slots)
    payload_handler_script_slot_set = set(facts.payload_handler_script_slots)
    missing_payload_handler_scripts = sorted(payload_handler_slot_set - payload_handler_script_slot_set)
    stale_payload_handler_scripts = sorted(payload_handler_script_slot_set - payload_handler_slot_set)
    if missing_payload_handler_scripts or stale_payload_handler_scripts:
        details = [
            f"payload handler slot missing convention-based script file: {slot}"
            for slot in missing_payload_handler_scripts
        ]
        details.extend(
            f"payload handler script file missing payload registry slot: {slot}"
            for slot in stale_payload_handler_scripts
        )
        fail("payload handler slot/script coverage drifted apart", details)
    payload_validator_key_set = set(facts.payload_validator_keys)
    payload_validator_registry_key_set = set(facts.payload_validator_registry_keys)
    missing_payload_validator_registry_keys = sorted(payload_validator_key_set - payload_validator_registry_key_set)
    stale_payload_validator_registry_keys = sorted(payload_validator_registry_key_set - payload_validator_key_set)
    payload_validator_registry_script_path_set = set(facts.payload_validator_registry_script_paths)
    payload_validator_file_path_set = set(facts.payload_validator_file_paths)
    missing_payload_validator_files = sorted(payload_validator_registry_script_path_set - payload_validator_file_path_set)
    stale_payload_validator_files = sorted(payload_validator_file_path_set - payload_validator_registry_script_path_set)
    payload_runtime_service_slot_set = set(facts.payload_runtime_service_slots)
    payload_runtime_service_registry_slot_set = set(facts.payload_runtime_service_registry_slots)
    missing_payload_runtime_service_registry_slots = sorted(payload_runtime_service_slot_set - payload_runtime_service_registry_slot_set)
    stale_payload_runtime_service_registry_slots = sorted(payload_runtime_service_registry_slot_set - payload_runtime_service_slot_set)
    script_by_slot = dict(facts.script_slots)
    missing_payload_runtime_service_scripts = sorted(
        slot
        for slot in facts.payload_runtime_service_registry_slots
        if not script_by_slot.get(slot) or not (ROOT / script_by_slot[slot]).exists()
    )
    if (
        missing_payload_validator_registry_keys
        or stale_payload_validator_registry_keys
        or missing_payload_validator_files
        or stale_payload_validator_files
        or missing_payload_runtime_service_registry_slots
        or stale_payload_runtime_service_registry_slots
        or missing_payload_runtime_service_scripts
    ):
        details = [
            f"payload validator key missing validator registry entry: {validator_key}"
            for validator_key in missing_payload_validator_registry_keys
        ]
        details.extend(
            f"payload validator registry key missing payload contract entry: {validator_key}"
            for validator_key in stale_payload_validator_registry_keys
        )
        details.extend(
            f"payload validator registry script missing file: {script_path}"
            for script_path in missing_payload_validator_files
        )
        details.extend(
            f"payload validator file missing registry entry: {script_path}"
            for script_path in stale_payload_validator_files
        )
        details.extend(
            f"payload runtime service slot missing runtime service registry entry: {slot}"
            for slot in missing_payload_runtime_service_registry_slots
        )
        details.extend(
            f"payload runtime service registry slot missing payload contract entry: {slot}"
            for slot in stale_payload_runtime_service_registry_slots
        )
        details.extend(
            f"payload runtime service registry slot missing script file: {slot}"
            for slot in missing_payload_runtime_service_scripts
        )
        fail("payload registry closure drifted apart", details)


def validate_wiring_slots(facts: DescriptorFacts, slot_set: set[str]) -> None:
    duplicate_wiring_keys = duplicate_names([f"{owner}.{dependency}" for owner, dependency, _source in facts.wiring_owner_source_pairs])
    if duplicate_wiring_keys:
        fail("duplicate wiring owner/dependency pairs found", duplicate_wiring_keys)
    unknown_wiring_slots: list[str] = []
    for owner, dependency, source in facts.wiring_owner_source_pairs:
        if owner not in slot_set:
            unknown_wiring_slots.append(f"unknown wiring owner: {owner}.{dependency}")
        if source not in slot_set:
            unknown_wiring_slots.append(f"unknown wiring source: {owner}.{dependency} -> {source}")
    for owner, field_name in facts.reset_owner_pairs:
        if owner not in slot_set:
            unknown_wiring_slots.append(f"unknown reset owner: {owner}.{field_name}")
    if unknown_wiring_slots:
        fail("composition wiring specs reference unknown service slots", sorted(unknown_wiring_slots))


def validate_declared_owner_fields(facts: DescriptorFacts) -> None:
    issues: list[str] = []
    script_by_slot = {
        slot_name: script_path
        for slot_name, script_path in facts.script_slots
        if script_path
    }
    declared_fields_cache: dict[str, set[str]] = {}

    def declared_fields_for_slot(slot_name: str) -> set[str]:
        script_path = script_by_slot.get(slot_name, "")
        declared_fields = dynamic_declared_field_names_for_slot(slot_name, facts)
        if not script_path:
            return declared_fields
        if script_path not in declared_fields_cache:
            declared_fields_cache[script_path] = declared_field_names_for_script(script_path)
        return declared_fields | declared_fields_cache[script_path]

    for owner, dependency, _source in facts.wiring_owner_source_pairs:
        script_path = script_by_slot.get(owner, "")
        if not script_path:
            issues.append(f"wiring owner missing script descriptor: {owner}.{dependency}")
            continue
        if not (ROOT / script_path).exists():
            issues.append(f"wiring owner script is missing: {owner} -> {script_path}")
            continue
        if dependency not in declared_fields_for_slot(owner):
            issues.append(f"wiring dependency is not a declared owner field: {owner}.{dependency} ({script_path})")

    for owner, field_name in facts.reset_owner_pairs:
        script_path = script_by_slot.get(owner, "")
        if not script_path:
            issues.append(f"reset owner missing script descriptor: {owner}.{field_name}")
            continue
        if not (ROOT / script_path).exists():
            issues.append(f"reset owner script is missing: {owner} -> {script_path}")
            continue
        if field_name not in declared_fields_for_slot(owner):
            issues.append(f"reset field is not declared on owner script: {owner}.{field_name} ({script_path})")

    if issues:
        fail("composition wiring specs must target declared owner fields", sorted(issues))


def validate_container_api(texts: CompositionTexts) -> None:
    required_container_api = [
        "set_service",
        "service",
        "has_service",
        "clear_service",
        "configure_dispose_specs",
        "dispose",
    ]
    missing_container_api = [
        name for name in required_container_api if re.search(rf"func {name}\b", texts.container_text) is None
    ]
    if missing_container_api:
        fail("battle_core_container is missing required container API", missing_container_api)
    public_vars = [
        name
        for name in re.findall(r"^var ([a-zA-Z_][a-zA-Z0-9_]*)\b", texts.container_text, re.M)
        if not name.startswith("_")
    ]
    if public_vars:
        fail("battle_core_container should not expose explicit service vars", public_vars)


def validate_composer_api(texts: CompositionTexts) -> None:
    composer_issues: list[str] = []
    expected_snippets = {
        "container.set_service(": "composer must instantiate services via container.set_service",
        "container.service(": "composer must read services via container.service",
        "_owner_declares_dependency(": "composer must validate dependency fields before wiring dynamic specs",
        "ServiceSpecsScript.service_slots()": "composer must iterate ServiceSpecsScript.service_slots()",
        "ServiceSpecsScript.script_by_slot(": "composer must resolve scripts via ServiceSpecsScript.script_by_slot()",
        "WiringSpecsScript.wiring_specs()": "composer must resolve wiring specs via WiringSpecsScript.wiring_specs()",
        "WiringSpecsScript.reset_specs()": "composer must resolve reset specs via WiringSpecsScript.reset_specs()",
    }
    for snippet, issue in expected_snippets.items():
        if snippet not in texts.composer_text:
            composer_issues.append(issue)
    for forbidden_snippet, issue in {
        "container.get(": "composer must not use container.get",
        "container.set(": "composer must not use container.set",
    }.items():
        if forbidden_snippet in texts.composer_text:
            composer_issues.append(issue)
    if composer_issues:
        fail("battle_core_composer did not adopt the container API", composer_issues)


def validate_container_usage(facts: DescriptorFacts, slot_set: set[str]) -> None:
    legacy_access_pattern = re.compile(
        rf"\b(?:[A-Za-z_][A-Za-z0-9_]*(?:core|container)|core|container|session\.container)\.({facts.slot_pattern})\b"
    )
    legacy_container_access: list[str] = []
    invalid_service_literals: list[str] = []
    for source_root in [ROOT / "src", ROOT / "tests"]:
        for path in source_root.rglob("*.gd"):
            rel = path.relative_to(ROOT)
            text = path.read_text(encoding="utf-8")
            for line_no, line in enumerate(text.splitlines(), start=1):
                match = legacy_access_pattern.search(line)
                if match is not None:
                    legacy_container_access.append(f"{rel}:{line_no}: {match.group(0)}")
            for slot_name in re.findall(r'\.service\("([^"]+)"\)', text):
                if slot_name not in slot_set:
                    invalid_service_literals.append(f"{rel}: unknown service literal {slot_name}")
    if legacy_container_access:
        fail('legacy BattleCoreContainer slot property access remains; use container.service("slot") instead', legacy_container_access)
    if invalid_service_literals:
        fail('service("slot") call sites reference unknown slots', sorted(invalid_service_literals))


def run() -> None:
    texts = load_composition_texts()
    facts = build_descriptor_facts(texts)
    validate_wiring_specs_entry_points(texts)
    slot_set, _script_slot_set = validate_service_descriptors(texts, facts)
    validate_payload_seams(texts, facts)
    validate_wiring_slots(facts, slot_set)
    validate_declared_owner_fields(facts)
    validate_container_api(texts)
    validate_composer_api(texts)
    validate_container_usage(facts, slot_set)
