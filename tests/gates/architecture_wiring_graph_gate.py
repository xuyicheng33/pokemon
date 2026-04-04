from __future__ import annotations

import re
import sys
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SERVICE_SPECS_PATH = ROOT / "src/composition/battle_core_service_specs.gd"
WIRING_SPECS_PATH = ROOT / "src/composition/battle_core_wiring_specs.gd"

def fail(message: str, details: list[str] | None = None) -> None:
    print(f"ARCH_GATE_FAILED: {message}", file=sys.stderr)
    for detail in details or []:
        print(f"  - {detail}", file=sys.stderr)
    sys.exit(1)


def parse_service_slots(text: str) -> set[str]:
    return set(re.findall(r'\{"slot": "([^"]+)"', text))


def parse_wiring_edges(text: str) -> list[tuple[str, str]]:
    return re.findall(r'\{"owner": "([^"]+)", "dependency": "[^"]+", "source": "([^"]+)"\}', text)


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
    service_slots = parse_service_slots(SERVICE_SPECS_PATH.read_text(encoding="utf-8"))
    edges = parse_wiring_edges(WIRING_SPECS_PATH.read_text(encoding="utf-8"))
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
