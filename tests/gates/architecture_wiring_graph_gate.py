from __future__ import annotations

import sys
from collections import defaultdict

from architecture_composition_consistency_gate_support import (
    GateFailure,
    build_descriptor_facts,
    fail,
    load_composition_texts,
)


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
    facts = build_descriptor_facts(load_composition_texts())
    service_slots = set(facts.service_slots)
    edges = [
        (owner, source)
        for owner, _dependency, source in facts.compose_owner_source_pairs
        if source
    ]
    if not service_slots:
        fail("failed to parse service slots for runtime compose graph gate")
    if not edges:
        fail("failed to parse runtime compose dependency edges")

    unknown_nodes = sorted({node for edge in edges for node in edge if node not in service_slots})
    if unknown_nodes:
        fail("runtime compose dependency graph references unknown services", unknown_nodes)

    runtime_sccs = extract_runtime_sccs(build_graph(service_slots, edges))
    if runtime_sccs:
        fail("runtime compose dependency graph must be acyclic", format_runtime_sccs(runtime_sccs))

    run_self_test()
    print("ARCH_GATE_PASSED: runtime compose dependency graph is acyclic")


if __name__ == "__main__":
    try:
        main()
    except GateFailure as exc:
        print(f"ARCH_GATE_FAILED: {exc.message}", file=sys.stderr)
        for detail in exc.details:
            print(f"  - {detail}", file=sys.stderr)
        sys.exit(1)
