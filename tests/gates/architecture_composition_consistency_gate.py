from __future__ import annotations

import re
import sys
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]

SERVICE_SPECS_PATH = ROOT / "src/composition/battle_core_service_specs.gd"
WIRING_SPECS_PATH = ROOT / "src/composition/battle_core_wiring_specs.gd"
CONTAINER_PATH = ROOT / "src/composition/battle_core_container.gd"


def fail(message: str, details: list[str] | None = None) -> None:
    print(f"ARCH_GATE_FAILED: {message}", file=sys.stderr)
    for detail in details or []:
        print(f"  - {detail}", file=sys.stderr)
    sys.exit(1)


def _extract_named_block(text: str, pattern: str, label: str) -> str:
    match = re.search(pattern, text, re.S)
    if match is None:
        fail(f"missing {label} block", [label])
    return match.group(1)


def _extract_quoted_names(block: str, pattern: str) -> list[str]:
    return re.findall(pattern, block)


def _duplicate_names(names: list[str]) -> list[str]:
    counter = Counter(names)
    return sorted(name for name, count in counter.items() if count > 1)


service_specs_text = SERVICE_SPECS_PATH.read_text(encoding="utf-8")
wiring_specs_text = WIRING_SPECS_PATH.read_text(encoding="utf-8")
container_text = CONTAINER_PATH.read_text(encoding="utf-8")

service_slots_block = _extract_named_block(
    service_specs_text,
    r"const SERVICE_SLOTS := \[(.*?)\]",
    "SERVICE_SLOTS",
)
service_slots = _extract_quoted_names(service_slots_block, r'"([^"]+)"')

script_by_slot_block = _extract_named_block(
    service_specs_text,
    r"const SCRIPT_BY_SLOT := \{(.*?)\n\}",
    "SCRIPT_BY_SLOT",
)
script_slots = _extract_quoted_names(script_by_slot_block, r'"([^"]+)"\s*:')

container_slots = [
    name
    for name in re.findall(r"^var ([a-zA-Z_][a-zA-Z0-9_]*)\b", container_text, re.M)
    if not name.startswith("_")
]

wiring_owner_source_pairs = re.findall(
    r'\{"owner": "([^"]+)", "dependency": "([^"]+)", "source": "([^"]+)"\}',
    wiring_specs_text,
)
reset_owner_pairs = re.findall(
    r'\{"owner": "([^"]+)", "field": "([^"]+)", "value":',
    wiring_specs_text,
)

for label, names in [
    ("SERVICE_SLOTS", service_slots),
    ("SCRIPT_BY_SLOT", script_slots),
    ("BattleCoreContainer service vars", container_slots),
]:
    duplicates = _duplicate_names(names)
    if duplicates:
        fail(f"{label} contains duplicate entries", duplicates)

slot_set = set(service_slots)
script_slot_set = set(script_slots)
container_slot_set = set(container_slots)

missing_script_slots = sorted(slot_set - script_slot_set)
stale_script_slots = sorted(script_slot_set - slot_set)
if missing_script_slots or stale_script_slots:
    details: list[str] = []
    details.extend(f"SERVICE_SLOTS missing script: {slot}" for slot in missing_script_slots)
    details.extend(f"SCRIPT_BY_SLOT stale key: {slot}" for slot in stale_script_slots)
    fail("battle_core_service_specs slot list and script map drifted apart", details)

missing_container_slots = sorted(slot_set - container_slot_set)
stale_container_slots = sorted(container_slot_set - slot_set)
if missing_container_slots or stale_container_slots:
    details = []
    details.extend(f"container missing service slot var: {slot}" for slot in missing_container_slots)
    details.extend(f"container has stale service slot var: {slot}" for slot in stale_container_slots)
    fail("battle_core_container service slot surface drifted apart from service specs", details)

unknown_wiring_slots: list[str] = []
duplicate_wiring_keys = _duplicate_names(
    [f"{owner}.{dependency}" for owner, dependency, _source in wiring_owner_source_pairs]
)

for owner, dependency, source in wiring_owner_source_pairs:
    if owner not in slot_set:
        unknown_wiring_slots.append(f"unknown wiring owner: {owner}.{dependency}")
    if source not in slot_set:
        unknown_wiring_slots.append(f"unknown wiring source: {owner}.{dependency} -> {source}")

for owner, field_name in reset_owner_pairs:
    if owner not in slot_set:
        unknown_wiring_slots.append(f"unknown reset owner: {owner}.{field_name}")

if duplicate_wiring_keys:
    fail("duplicate wiring owner/dependency pairs found", duplicate_wiring_keys)

if unknown_wiring_slots:
    fail("composition wiring specs reference unknown service slots", sorted(unknown_wiring_slots))

print("ARCH_GATE_PASSED: composition service slots, container surface, and wiring specs are aligned")
