from __future__ import annotations

import re
import sys
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SERVICE_SPECS_PATH = ROOT / "src/composition/battle_core_service_specs.gd"
WIRING_SPECS_DIR = ROOT / "src/composition/battle_core_wiring_specs"
PAYLOAD_CONTRACT_REGISTRY_PATH = ROOT / "src/battle_core/content/payload_contract_registry.gd"
PAYLOAD_SERVICE_SPECS_PATH = ROOT / "src/composition/battle_core_payload_service_specs.gd"

def fail(message: str, details: list[str] | None = None) -> None:
    print(f"ARCH_GATE_FAILED: {message}", file=sys.stderr)
    for detail in details or []:
        print(f"  - {detail}", file=sys.stderr)
    sys.exit(1)


def parse_service_slots(text: str) -> set[str]:
    return set(re.findall(r'\{"slot": "([^"]+)"', text))


def extract_named_block(text: str, pattern: str, label: str) -> str:
    match = re.search(pattern, text, re.S)
    if match is None:
        fail(f"missing {label} block", [label])
    return match.group(1)


def parse_payload_shared_service_slots(payload_service_specs_text: str) -> set[str]:
    block = extract_named_block(
        payload_service_specs_text,
        r"const SHARED_SERVICE_DESCRIPTORS := \[(.*?)\]\n\nconst HANDLER_SCRIPTS_BY_SLOT",
        "SHARED_SERVICE_DESCRIPTORS",
    )
    return set(re.findall(r'"slot": "([^"]+)"', block))


def parse_payload_handler_script_slots(payload_service_specs_text: str) -> set[str]:
    block = extract_named_block(
        payload_service_specs_text,
        r"const HANDLER_SCRIPTS_BY_SLOT := \{(.*?)\}\n",
        "HANDLER_SCRIPTS_BY_SLOT",
    )
    return set(re.findall(r'"([^"]+)": [A-Za-z_][A-Za-z0-9_]*', block))


def parse_payload_service_slots(payload_registry_text: str, payload_service_specs_text: str) -> set[str]:
    del payload_registry_text
    return parse_payload_shared_service_slots(payload_service_specs_text) | parse_payload_handler_script_slots(payload_service_specs_text)


def parse_wiring_edges(text: str) -> list[tuple[str, str]]:
    return re.findall(r'\{"owner": "([^"]+)", "dependency": "[^"]+", "source": "([^"]+)"\}', text)


def parse_payload_registry_edges(text: str) -> list[tuple[str, str]]:
    return [("payload_handler_registry", slot) for slot in re.findall(r'"handler_slot": "([^"]+)"', text)]


def parse_payload_handler_dependency_edges(text: str) -> list[tuple[str, str]]:
    edges: list[tuple[str, str]] = []
    current_handler_slot: str | None = None
    in_handler_dependencies = False
    for raw_line in text.splitlines():
        line = raw_line.strip()
        slot_match = re.search(r'"handler_slot": "([^"]+)"', line)
        if slot_match is not None:
            current_handler_slot = slot_match.group(1)
        if '"handler_dependencies": [' in line:
            in_handler_dependencies = True
            continue
        if not in_handler_dependencies:
            continue
        dependency_match = re.search(r'\{"dependency": "([^"]+)", "source": "([^"]+)"\}', line)
        if dependency_match is not None and current_handler_slot is not None:
            edges.append((current_handler_slot, dependency_match.group(2)))
        if line == "]," or line == "]":
            in_handler_dependencies = False
    return edges


def parse_payload_shared_service_dependency_edges(text: str) -> list[tuple[str, str]]:
    edges: list[tuple[str, str]] = []
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
            edges.append((current_slot, dependency_match.group(2)))
        if line == "]," or line == "]":
            in_dependencies = False
    return edges


def build_graph(nodes: set[str], edges: list[tuple[str, str]]) -> dict[str, set[str]]:
    graph: dict[str, set[str]] = defaultdict(set)
    for node in nodes:
        graph[node]
    for owner, source in edges:
        graph[owner].add(source)
        graph[source]
    return graph


def strongly_connected_components(graph: dict[str, set[str]]) -> list[tuple[str, ...]]:
    index = 0
    stack: list[str] = []
    indices: dict[str, int] = {}
    lowlinks: dict[str, int] = {}
    on_stack: set[str] = set()
    components: list[tuple[str, ...]] = []

    def visit(node: str) -> None:
        nonlocal index
        indices[node] = index
        lowlinks[node] = index
        index += 1
        stack.append(node)
        on_stack.add(node)

        for neighbor in graph[node]:
            if neighbor not in indices:
                visit(neighbor)
                lowlinks[node] = min(lowlinks[node], lowlinks[neighbor])
            elif neighbor in on_stack:
                lowlinks[node] = min(lowlinks[node], indices[neighbor])

        if lowlinks[node] != indices[node]:
            return

        component: list[str] = []
        while stack:
            popped = stack.pop()
            on_stack.remove(popped)
            component.append(popped)
            if popped == node:
                break
        components.append(tuple(sorted(component)))

    for node in sorted(graph.keys()):
        if node not in indices:
            visit(node)
    return components


def extract_runtime_sccs(graph: dict[str, set[str]]) -> set[tuple[str, ...]]:
    runtime_sccs: set[tuple[str, ...]] = set()
    for component in strongly_connected_components(graph):
        if len(component) > 1:
            runtime_sccs.add(component)
            continue
        node = component[0]
        if node in graph[node]:
            runtime_sccs.add(component)
    return runtime_sccs


def format_runtime_sccs(runtime_sccs: set[tuple[str, ...]]) -> list[str]:
    return ["{" + ", ".join(component) + "}" for component in sorted(runtime_sccs)]


def run_self_test() -> None:
    graph = {
        "__self_test_a__": {"__self_test_b__"},
        "__self_test_b__": {"__self_test_a__"},
    }
    runtime_sccs = extract_runtime_sccs(graph)
    if not runtime_sccs:
        fail("wiring DAG gate self-test did not detect a synthetic cycle")


def main() -> None:
    service_specs_text = SERVICE_SPECS_PATH.read_text(encoding="utf-8")
    payload_registry_text = PAYLOAD_CONTRACT_REGISTRY_PATH.read_text(encoding="utf-8")
    payload_service_specs_text = PAYLOAD_SERVICE_SPECS_PATH.read_text(encoding="utf-8")
    payload_handler_slots = set(re.findall(r'"handler_slot": "([^"]+)"', payload_registry_text))
    payload_handler_script_slots = parse_payload_handler_script_slots(payload_service_specs_text)
    missing_payload_handler_scripts = sorted(payload_handler_slots - payload_handler_script_slots)
    stale_payload_handler_scripts = sorted(payload_handler_script_slots - payload_handler_slots)
    if missing_payload_handler_scripts or stale_payload_handler_scripts:
        details: list[str] = []
        details.extend(
            f"payload handler slot missing HANDLER_SCRIPTS_BY_SLOT mapping: {slot}"
            for slot in missing_payload_handler_scripts
        )
        details.extend(
            f"HANDLER_SCRIPTS_BY_SLOT stale mapping without payload registry slot: {slot}"
            for slot in stale_payload_handler_scripts
        )
        fail("payload handler slot/script mappings drifted apart", details)
    service_slots = parse_service_slots(service_specs_text) | parse_payload_service_slots(payload_registry_text, payload_service_specs_text)
    wiring_spec_paths = sorted(WIRING_SPECS_DIR.glob("*.gd"))
    if not wiring_spec_paths:
        fail("failed to find split wiring spec files", [str(WIRING_SPECS_DIR.relative_to(ROOT))])
    edges: list[tuple[str, str]] = []
    for path in wiring_spec_paths:
        edges.extend(parse_wiring_edges(path.read_text(encoding="utf-8")))
    edges.extend(parse_payload_registry_edges(payload_registry_text))
    edges.extend(parse_payload_handler_dependency_edges(payload_registry_text))
    edges.extend(parse_payload_shared_service_dependency_edges(payload_service_specs_text))
    if not service_slots:
        fail("failed to parse service slots for runtime wiring graph gate")
    if not edges:
        fail("failed to parse runtime wiring edges")

    unknown_nodes = sorted({node for edge in edges for node in edge if node not in service_slots})
    if unknown_nodes:
        fail("runtime wiring graph references unknown services", unknown_nodes)

    runtime_sccs = extract_runtime_sccs(build_graph(service_slots, edges))
    if runtime_sccs:
        fail("runtime wiring graph must be acyclic", format_runtime_sccs(runtime_sccs))

    run_self_test()
    print("ARCH_GATE_PASSED: runtime wiring graph is acyclic")


if __name__ == "__main__":
    main()
