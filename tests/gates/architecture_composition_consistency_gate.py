from __future__ import annotations

import re
import sys
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]

SERVICE_SPECS_PATH = ROOT / "src/composition/battle_core_service_specs.gd"
WIRING_SPECS_PATH = ROOT / "src/composition/battle_core_wiring_specs.gd"
WIRING_SPECS_DIR = ROOT / "src/composition/battle_core_wiring_specs"
CONTAINER_PATH = ROOT / "src/composition/battle_core_container.gd"
COMPOSER_PATH = ROOT / "src/composition/battle_core_composer.gd"


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
wiring_child_texts = []
for path in sorted(WIRING_SPECS_DIR.glob("*.gd")):
    wiring_child_texts.append(path.read_text(encoding="utf-8"))
if not wiring_child_texts:
    fail("battle_core_wiring_specs must aggregate child spec files", [str(WIRING_SPECS_DIR.relative_to(ROOT))])
container_text = CONTAINER_PATH.read_text(encoding="utf-8")
composer_text = COMPOSER_PATH.read_text(encoding="utf-8")

service_descriptors_block = _extract_named_block(
    service_specs_text,
    r"const SERVICE_DESCRIPTORS := \[(.*?)\]\n",
    "SERVICE_DESCRIPTORS",
)
service_slots = re.findall(r'"slot": "([^"]+)"', service_descriptors_block)
script_slots = re.findall(r'"slot": "([^"]+)", "script": preload\("([^"]+)"\)', service_descriptors_block)
slot_pattern = "|".join(re.escape(slot) for slot in service_slots)

wiring_owner_source_pairs = []
for child_text in wiring_child_texts:
    wiring_owner_source_pairs.extend(
        re.findall(r'\{"owner": "([^"]+)", "dependency": "([^"]+)", "source": "([^"]+)"\}', child_text)
    )
reset_owner_pairs = re.findall(
    r'\{"owner": "([^"]+)", "field": "([^"]+)", "value":',
    wiring_specs_text,
)

required_wiring_specs_helpers = [
    "static func wiring_specs() -> Array:",
    "static func reset_specs() -> Array:",
]
missing_wiring_specs_helpers = [
    helper for helper in required_wiring_specs_helpers if helper not in wiring_specs_text
]
if missing_wiring_specs_helpers:
    fail(
        "battle_core_wiring_specs must expose aggregated helpers",
        missing_wiring_specs_helpers,
    )
if "src/composition/battle_core_wiring_specs/" not in wiring_specs_text:
    fail(
        "battle_core_wiring_specs must preload child spec files from the split directory",
        [str(WIRING_SPECS_DIR.relative_to(ROOT))],
    )

for label, names in [
    ("SERVICE_DESCRIPTORS slots", service_slots),
    ("SERVICE_DESCRIPTORS scripts", [slot for slot, _script in script_slots]),
]:
    duplicates = _duplicate_names(names)
    if duplicates:
        fail(f"{label} contains duplicate entries", duplicates)

slot_set = set(service_slots)
script_slot_set = {slot for slot, _script in script_slots}

missing_script_slots = sorted(slot_set - script_slot_set)
stale_script_slots = sorted(script_slot_set - slot_set)
if missing_script_slots or stale_script_slots:
    details: list[str] = []
    details.extend(f"SERVICE_DESCRIPTORS missing script: {slot}" for slot in missing_script_slots)
    details.extend(f"SERVICE_DESCRIPTORS stale script slot: {slot}" for slot in stale_script_slots)
    fail("battle_core_service_specs descriptors drifted apart", details)

required_service_specs_helpers = [
    "static func service_slots()",
    "static func script_by_slot(slot_name: String):",
]
missing_service_specs_helpers = [
    helper for helper in required_service_specs_helpers if helper not in service_specs_text
]
if missing_service_specs_helpers:
    fail(
        "battle_core_service_specs must expose helpers derived from SERVICE_DESCRIPTORS",
        missing_service_specs_helpers,
    )

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

required_container_api = [
    "set_service",
    "service",
    "has_service",
    "clear_service",
    "configure_dispose_specs",
    "dispose",
]
missing_container_api = [
    name for name in required_container_api if re.search(rf"func {name}\b", container_text) is None
]
if missing_container_api:
    fail("battle_core_container is missing required container API", missing_container_api)

if re.search(r"^var [a-zA-Z_][a-zA-Z0-9_]*\b", container_text, re.M):
    public_vars = [
        name
        for name in re.findall(r"^var ([a-zA-Z_][a-zA-Z0-9_]*)\b", container_text, re.M)
        if not name.startswith("_")
    ]
    if public_vars:
        fail("battle_core_container should not expose explicit service vars", public_vars)

composer_issues: list[str] = []
if "container.set_service(" not in composer_text:
    composer_issues.append("composer must instantiate services via container.set_service")
if "container.service(" not in composer_text:
    composer_issues.append("composer must read services via container.service")
if "_owner_declares_dependency(" not in composer_text:
    composer_issues.append("composer must validate dependency fields before wiring dynamic specs")
if "ServiceSpecsScript.service_slots()" not in composer_text:
    composer_issues.append("composer must iterate ServiceSpecsScript.service_slots()")
if "ServiceSpecsScript.script_by_slot(" not in composer_text:
    composer_issues.append("composer must resolve scripts via ServiceSpecsScript.script_by_slot()")
if "WiringSpecsScript.wiring_specs()" not in composer_text:
    composer_issues.append("composer must resolve wiring specs via WiringSpecsScript.wiring_specs()")
if "WiringSpecsScript.reset_specs()" not in composer_text:
    composer_issues.append("composer must resolve reset specs via WiringSpecsScript.reset_specs()")
if "container.get(" in composer_text:
    composer_issues.append("composer must not use container.get")
if "container.set(" in composer_text:
    composer_issues.append("composer must not use container.set")
if composer_issues:
    fail("battle_core_composer did not adopt the container API", composer_issues)

legacy_container_access: list[str] = []
legacy_access_pattern = re.compile(
    rf"\b(?:[A-Za-z_][A-Za-z0-9_]*(?:core|container)|core|container|session\.container)\.({slot_pattern})\b"
)
for source_root in [ROOT / "src", ROOT / "tests"]:
    for path in source_root.rglob("*.gd"):
        rel = path.relative_to(ROOT)
        for line_no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            match = legacy_access_pattern.search(line)
            if match is None:
                continue
            legacy_container_access.append(f"{rel}:{line_no}: {match.group(0)}")

if legacy_container_access:
    fail(
        "legacy BattleCoreContainer slot property access remains; use container.service(\"slot\") instead",
        legacy_container_access,
    )

invalid_service_literals: list[str] = []
for source_root in [ROOT / "src", ROOT / "tests"]:
    for path in source_root.rglob("*.gd"):
        rel = path.relative_to(ROOT)
        text = path.read_text(encoding="utf-8")
        for slot_name in re.findall(r'\.service\("([^"]+)"\)', text):
            if slot_name not in slot_set:
                invalid_service_literals.append(f"{rel}: unknown service literal {slot_name}")

if invalid_service_literals:
    fail("service(\"slot\") call sites reference unknown slots", sorted(invalid_service_literals))

print("ARCH_GATE_PASSED: composition descriptors, container API, and wiring specs are aligned")
