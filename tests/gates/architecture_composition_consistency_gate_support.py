from __future__ import annotations

import re
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]

SERVICE_SPECS_PATH = ROOT / "src/composition/battle_core_service_specs.gd"
WIRING_SPECS_PATH = ROOT / "src/composition/battle_core_wiring_specs.gd"
WIRING_SPECS_DIR = ROOT / "src/composition/battle_core_wiring_specs"
CONTAINER_PATH = ROOT / "src/composition/battle_core_container.gd"
COMPOSER_PATH = ROOT / "src/composition/battle_core_composer.gd"
PAYLOAD_CONTRACT_REGISTRY_PATH = ROOT / "src/battle_core/content/payload_contract_registry.gd"
CONTENT_PAYLOAD_VALIDATOR_PATH = ROOT / "src/battle_core/content/content_payload_validator.gd"
PAYLOAD_VALIDATOR_REGISTRY_PATH = ROOT / "src/battle_core/content/payload_validator_registry.gd"
PAYLOAD_VALIDATOR_DIR = ROOT / "src/battle_core/content/payload_validators"
PAYLOAD_SERVICE_SPECS_PATH = ROOT / "src/composition/battle_core_payload_service_specs.gd"
PAYLOAD_RUNTIME_SERVICE_REGISTRY_PATH = ROOT / "src/composition/battle_core_payload_runtime_service_registry.gd"
PAYLOAD_HANDLER_DIR = ROOT / "src/battle_core/effects/payload_handlers"


class GateFailure(RuntimeError):
    def __init__(self, message: str, details: list[str] | None = None) -> None:
        super().__init__(message)
        self.message = message
        self.details = list(details or [])


@dataclass(frozen=True)
class CompositionTexts:
    service_specs_text: str
    wiring_specs_text: str
    wiring_child_texts: list[str]
    container_text: str
    composer_text: str
    payload_contract_registry_text: str
    content_payload_validator_text: str
    payload_validator_registry_text: str
    payload_service_specs_text: str
    payload_runtime_service_registry_text: str


@dataclass(frozen=True)
class DescriptorFacts:
    service_slots: list[str]
    script_slots: list[tuple[str, str]]
    payload_handler_slots: list[str]
    payload_handler_script_slots: list[str]
    payload_validator_keys: list[str]
    payload_validator_registry_keys: list[str]
    payload_validator_registry_script_paths: list[str]
    payload_validator_file_paths: list[str]
    payload_runtime_service_slots: list[str]
    payload_runtime_service_registry_slots: list[str]
    wiring_owner_source_pairs: list[tuple[str, str, str]]
    reset_owner_pairs: list[tuple[str, str]]
    slot_pattern: str


def fail(message: str, details: list[str] | None = None) -> None:
    raise GateFailure(message, details)


def extract_named_block(text: str, pattern: str, label: str) -> str:
    match = re.search(pattern, text, re.S)
    if match is None:
        fail(f"missing {label} block", [label])
    return match.group(1)


def duplicate_names(names: list[str]) -> list[str]:
    counter = Counter(names)
    return sorted(name for name, count in counter.items() if count > 1)


def parse_payload_handler_dependency_edges(text: str) -> list[tuple[str, str, str]]:
    edges: list[tuple[str, str, str]] = []
    current_handler_slot: str | None = None
    in_handler_dependencies = False
    for raw_line in text.splitlines():
        line = raw_line.strip()
        slot_match = re.search(r'"handler_slot": "([^"]+)"', line)
        if slot_match is not None:
            current_handler_slot = slot_match.group(1)
        if '"handler_dependencies": []' in line:
            in_handler_dependencies = False
            continue
        if '"handler_dependencies": [' in line:
            in_handler_dependencies = True
            continue
        if not in_handler_dependencies:
            continue
        dependency_match = re.search(r'\{"dependency": "([^"]+)", "source": "([^"]+)"\}', line)
        if dependency_match is not None and current_handler_slot is not None:
            edges.append((current_handler_slot, dependency_match.group(1), dependency_match.group(2)))
        if line == "]," or line == "]":
            in_handler_dependencies = False
    return edges


def parse_payload_shared_service_slots(payload_service_specs_text: str) -> list[str]:
    block = extract_named_block(
        payload_service_specs_text,
        r"const SHARED_SERVICE_DESCRIPTORS := \[(.*?)\]\n\nstatic func service_descriptors",
        "SHARED_SERVICE_DESCRIPTORS",
    )
    return re.findall(r'"slot": "([^"]+)"', block)


def parse_payload_shared_service_descriptors(text: str) -> list[tuple[str, str]]:
    preload_constants = parse_preload_constants(text)
    block = extract_named_block(
        text,
        r"const SHARED_SERVICE_DESCRIPTORS := \[(.*?)\]\n\nstatic func service_descriptors",
        "SHARED_SERVICE_DESCRIPTORS",
    )
    descriptors: list[tuple[str, str]] = []
    for slot_name, constant_name in re.findall(
        r'\{\s*"slot": "([^"]+)",\s*"script": ([A-Za-z_][A-Za-z0-9_]*)\s*\}',
        block,
        re.S,
    ):
        script_path = preload_constants.get(constant_name, "")
        descriptors.append((slot_name, script_path.replace("res://", "") if script_path else ""))
    return descriptors


def parse_payload_runtime_service_dependency_edges(text: str) -> list[tuple[str, str, str]]:
    edges: list[tuple[str, str, str]] = []
    current_slot: str | None = None
    in_dependencies = False
    for raw_line in text.splitlines():
        line = raw_line.strip()
        slot_match = re.search(r'"slot": "([^"]+)"', line)
        if slot_match is not None:
            current_slot = slot_match.group(1)
        if '"dependencies": [' in line:
            in_dependencies = True
            continue
        if not in_dependencies:
            continue
        dependency_match = re.search(r'\{"dependency": "([^"]+)", "source": "([^"]+)"\}', line)
        if dependency_match is not None and current_slot is not None:
            edges.append((current_slot, dependency_match.group(1), dependency_match.group(2)))
        if line == "]," or line == "]":
            in_dependencies = False
    return edges


def scan_payload_handler_script_slots() -> list[str]:
    if not PAYLOAD_HANDLER_DIR.exists():
        fail("payload handler directory is missing", [str(PAYLOAD_HANDLER_DIR.relative_to(ROOT))])
    return sorted(path.stem for path in PAYLOAD_HANDLER_DIR.glob("payload_*_handler.gd"))


def payload_handler_script_path(handler_slot: str) -> str:
    return f"src/battle_core/effects/payload_handlers/{handler_slot}.gd"


def scan_payload_validator_script_paths() -> list[str]:
    if not PAYLOAD_VALIDATOR_DIR.exists():
        fail("payload validator directory is missing", [str(PAYLOAD_VALIDATOR_DIR.relative_to(ROOT))])
    return sorted(str(path.relative_to(ROOT)) for path in PAYLOAD_VALIDATOR_DIR.glob("*_payload_validator.gd"))


def parse_preload_constants(text: str) -> dict[str, str]:
    return dict(re.findall(r'const ([A-Za-z_][A-Za-z0-9_]*) := preload\("([^"]+)"\)', text))


def parse_payload_validator_descriptors(text: str) -> tuple[list[str], list[str]]:
    preload_constants = parse_preload_constants(text)
    keys: list[str] = []
    script_paths: list[str] = []
    for validator_key, constant_name in re.findall(r'\{"validator_key": "([^"]+)", "script": ([A-Za-z_][A-Za-z0-9_]*)\}', text):
        keys.append(validator_key)
        script_path = preload_constants.get(constant_name, "")
        if script_path:
            script_paths.append(script_path.replace("res://", ""))
    return keys, script_paths


def parse_payload_runtime_service_descriptors(text: str) -> list[tuple[str, str]]:
    preload_constants = parse_preload_constants(text)
    descriptors: list[tuple[str, str]] = []
    for slot_name, constant_name in re.findall(
        r'\{\s*"slot": "([^"]+)",\s*"script": ([A-Za-z_][A-Za-z0-9_]*)',
        text,
        re.S,
    ):
        script_path = preload_constants.get(constant_name, "")
        descriptors.append((slot_name, script_path.replace("res://", "") if script_path else ""))
    return descriptors


def parse_payload_service_descriptors(
    payload_service_specs_text: str,
    payload_runtime_service_registry_text: str,
) -> tuple[list[tuple[str, str]], list[str]]:
    script_slots = scan_payload_handler_script_slots()
    descriptors = parse_payload_shared_service_descriptors(payload_service_specs_text)
    descriptors.extend(parse_payload_runtime_service_descriptors(payload_runtime_service_registry_text))
    descriptors.extend((slot_name, payload_handler_script_path(slot_name)) for slot_name in script_slots)
    return descriptors, script_slots


def parse_extends_script_path(text: str) -> str:
    match = re.search(r'^extends "res://([^"]+)"', text, re.M)
    return "" if match is None else match.group(1)


def declared_field_names_for_script(script_rel_path: str, _seen: set[str] | None = None) -> set[str]:
    normalized_path = script_rel_path.strip()
    if not normalized_path:
        return set()
    seen = _seen if _seen is not None else set()
    if normalized_path in seen:
        return set()
    seen.add(normalized_path)
    script_path = ROOT / normalized_path
    if not script_path.exists():
        return set()
    text = script_path.read_text(encoding="utf-8")
    declared_fields = set(
        re.findall(r"^\s*(?:@[A-Za-z_][A-Za-z0-9_]*\s+)*var\s+([A-Za-z_][A-Za-z0-9_]*)\b", text, re.M)
    )
    parent_script_path = parse_extends_script_path(text)
    if parent_script_path:
        declared_fields |= declared_field_names_for_script(parent_script_path, seen)
    return declared_fields


def dynamic_declared_field_names_for_slot(slot_name: str, facts: DescriptorFacts) -> set[str]:
    if slot_name == "payload_handler_registry":
        return set(facts.payload_handler_slots)
    return set()


def load_composition_texts() -> CompositionTexts:
    wiring_child_texts = [path.read_text(encoding="utf-8") for path in sorted(WIRING_SPECS_DIR.glob("*.gd"))]
    if not wiring_child_texts:
        fail("battle_core_wiring_specs must aggregate child spec files", [str(WIRING_SPECS_DIR.relative_to(ROOT))])
    return CompositionTexts(
        service_specs_text=SERVICE_SPECS_PATH.read_text(encoding="utf-8"),
        wiring_specs_text=WIRING_SPECS_PATH.read_text(encoding="utf-8"),
        wiring_child_texts=wiring_child_texts,
        container_text=CONTAINER_PATH.read_text(encoding="utf-8"),
        composer_text=COMPOSER_PATH.read_text(encoding="utf-8"),
        payload_contract_registry_text=PAYLOAD_CONTRACT_REGISTRY_PATH.read_text(encoding="utf-8"),
        content_payload_validator_text=CONTENT_PAYLOAD_VALIDATOR_PATH.read_text(encoding="utf-8"),
        payload_validator_registry_text=PAYLOAD_VALIDATOR_REGISTRY_PATH.read_text(encoding="utf-8"),
        payload_service_specs_text=PAYLOAD_SERVICE_SPECS_PATH.read_text(encoding="utf-8"),
        payload_runtime_service_registry_text=PAYLOAD_RUNTIME_SERVICE_REGISTRY_PATH.read_text(encoding="utf-8"),
    )


def build_descriptor_facts(texts: CompositionTexts) -> DescriptorFacts:
    service_descriptors_block = extract_named_block(
        texts.service_specs_text,
        r"const SERVICE_DESCRIPTORS := \[(.*?)\]\n",
        "SERVICE_DESCRIPTORS",
    )
    payload_service_descriptors, payload_handler_script_slots = parse_payload_service_descriptors(
        texts.payload_service_specs_text,
        texts.payload_runtime_service_registry_text,
    )
    payload_validator_registry_keys, payload_validator_registry_script_paths = parse_payload_validator_descriptors(
        texts.payload_validator_registry_text,
    )
    payload_runtime_service_descriptors = parse_payload_runtime_service_descriptors(
        texts.payload_runtime_service_registry_text,
    )
    service_slots = re.findall(r'"slot": "([^"]+)"', service_descriptors_block)
    service_slots.extend(slot for slot, _script in payload_service_descriptors)
    script_slots = re.findall(
        r'"slot": "([^"]+)", "script": preload\("([^"]+)"\)',
        service_descriptors_block,
    )
    script_slots = [
        (slot_name, script_path.replace("res://", ""))
        for slot_name, script_path in script_slots
    ]
    script_slots.extend(payload_service_descriptors)
    payload_handler_slots = re.findall(r'"handler_slot": "([^"]+)"', texts.payload_contract_registry_text)
    payload_validator_keys = re.findall(r'"validator_key": "([^"]+)"', texts.payload_contract_registry_text)
    payload_runtime_service_slots = sorted({
        runtime_service_slot
        for raw_block in re.findall(r'"runtime_service_slots": \[([^\]]*)\]', texts.payload_contract_registry_text)
        for runtime_service_slot in re.findall(r'"([^"]+)"', raw_block)
    })
    wiring_owner_source_pairs: list[tuple[str, str, str]] = []
    for child_text in texts.wiring_child_texts:
        wiring_owner_source_pairs.extend(
            re.findall(r'\{"owner": "([^"]+)", "dependency": "([^"]+)", "source": "([^"]+)"\}', child_text)
        )
    wiring_owner_source_pairs.extend(
        ("payload_handler_registry", handler_slot, handler_slot)
        for handler_slot in payload_handler_slots
    )
    wiring_owner_source_pairs.extend(parse_payload_handler_dependency_edges(texts.payload_contract_registry_text))
    wiring_owner_source_pairs.extend(parse_payload_runtime_service_dependency_edges(texts.payload_runtime_service_registry_text))
    reset_owner_pairs = re.findall(
        r'\{"owner": "([^"]+)", "field": "([^"]+)", "value":',
        texts.wiring_specs_text,
    )
    return DescriptorFacts(
        service_slots=service_slots,
        script_slots=script_slots,
        payload_handler_slots=payload_handler_slots,
        payload_handler_script_slots=payload_handler_script_slots,
        payload_validator_keys=payload_validator_keys,
        payload_validator_registry_keys=payload_validator_registry_keys,
        payload_validator_registry_script_paths=payload_validator_registry_script_paths,
        payload_validator_file_paths=scan_payload_validator_script_paths(),
        payload_runtime_service_slots=payload_runtime_service_slots,
        payload_runtime_service_registry_slots=[slot for slot, _script in payload_runtime_service_descriptors],
        wiring_owner_source_pairs=wiring_owner_source_pairs,
        reset_owner_pairs=reset_owner_pairs,
        slot_pattern="|".join(re.escape(slot) for slot in service_slots),
    )
