from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path

from repo_consistency_common import GateContext


def contract_field_list(
    ctx: GateContext,
    bucket: dict,
    field_key: str,
    label: str,
    *,
    required: bool = True,
    allow_empty: bool = False,
) -> list[str]:
    values = bucket.get(field_key, [])
    if not isinstance(values, list):
        ctx.failures.append(f"{label} must be an array")
        return []
    normalized: list[str] = []
    for raw_value in values:
        value = str(raw_value).strip()
        if not value:
            ctx.failures.append(f"{label} contains empty field name")
            continue
        normalized.append(value)
    if required and not allow_empty and not normalized:
        ctx.failures.append(f"{label} must not be empty")
    return normalized


def validate_required_contract_fields(
    ctx: GateContext,
    entry: dict,
    required_string_fields: list[str],
    required_array_fields: list[str],
    entry_label: str,
    required_positive_int_fields: list[str] | None = None,
) -> None:
    for field_name in required_string_fields:
        if not str(entry.get(field_name, "")).strip():
            ctx.failures.append(f"{entry_label} missing {field_name}")
    for field_name in required_array_fields:
        if not isinstance(entry.get(field_name, None), list):
            ctx.failures.append(f"{entry_label} missing {field_name}")
    for field_name in required_positive_int_fields or []:
        if not _is_positive_int_like(entry.get(field_name, None)):
            ctx.failures.append(f"{entry_label} {field_name} must be positive integer")


def load_delivery_registry_entries(ctx: GateContext, *, export_script_path: str, manifest_path: str) -> list[dict]:
    payload = run_godot_json_export(
        ctx,
        export_script_path=export_script_path,
        input_path=manifest_path,
        failure_label="delivery registry view",
    )
    if not isinstance(payload, dict):
        return []
    entries = payload.get("entries", [])
    if not isinstance(entries, list):
        ctx.failures.append(f"{export_script_path} missing entries array")
        return []
    normalized_entries: list[dict] = []
    for entry_index, raw_entry in enumerate(entries):
        if not isinstance(raw_entry, dict):
            ctx.failures.append(f"{export_script_path} entries[{entry_index}] must be object")
            continue
        normalized_entries.append(raw_entry)
    return normalized_entries


def load_pair_catalog(ctx: GateContext, *, export_script_path: str, manifest_path: str) -> dict:
    payload = run_godot_json_export(
        ctx,
        export_script_path=export_script_path,
        input_path=manifest_path,
        failure_label="formal pair catalog",
    )
    return payload if isinstance(payload, dict) else {}


def load_generated_registry_views(ctx: GateContext, *, export_script_path: str, source_dir: str) -> dict:
    payload = run_godot_json_export(
        ctx,
        export_script_path=export_script_path,
        input_path=source_dir,
        failure_label="generated formal registry views",
    )
    if not isinstance(payload, dict):
        return {}
    manifest = payload.get("manifest", {})
    capability_catalog = payload.get("capability_catalog", {})
    if not isinstance(manifest, dict):
        ctx.failures.append(f"{export_script_path} missing manifest object")
        manifest = {}
    if not isinstance(capability_catalog, dict):
        ctx.failures.append(f"{export_script_path} missing capability_catalog object")
        capability_catalog = {}
    return {
        "manifest": manifest,
        "capability_catalog": capability_catalog,
    }


def validate_generated_registry_views(
    ctx: GateContext,
    *,
    generated_views: dict,
    committed_manifest: dict,
    committed_capability_catalog: dict,
    manifest_path: str,
    capability_catalog_path: str,
    source_dir: str,
) -> None:
    generated_manifest = generated_views.get("manifest", {})
    generated_capability_catalog = generated_views.get("capability_catalog", {})
    if not isinstance(generated_manifest, dict):
        ctx.failures.append(f"generated manifest from {source_dir} must be object")
        generated_manifest = {}
    if not isinstance(generated_capability_catalog, dict):
        ctx.failures.append(f"generated capability catalog from {source_dir} must be object")
        generated_capability_catalog = {}
    _validate_generated_view_matches_committed(
        ctx,
        generated_view=generated_manifest,
        committed_view=committed_manifest,
        committed_path=manifest_path,
        source_dir=source_dir,
    )
    _validate_generated_view_matches_committed(
        ctx,
        generated_view=generated_capability_catalog,
        committed_view=committed_capability_catalog,
        committed_path=capability_catalog_path,
        source_dir=source_dir,
    )


def run_godot_json_export(
    ctx: GateContext,
    *,
    export_script_path: str,
    input_path: str,
    failure_label: str,
) -> dict:
    if not (ctx.root / export_script_path).exists():
        ctx.failures.append(f"missing export script: {export_script_path}")
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
                input_path,
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
                f"{export_script_path} failed to export {failure_label}: {combined_output or f'exit={result.returncode}'}"
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


def _is_positive_int_like(value: object) -> bool:
    if isinstance(value, bool):
        return False
    if isinstance(value, int):
        return value > 0
    if isinstance(value, float):
        return value.is_integer() and value > 0
    return False


def _validate_generated_view_matches_committed(
    ctx: GateContext,
    *,
    generated_view: dict,
    committed_view: dict,
    committed_path: str,
    source_dir: str,
) -> None:
    generated_text = _render_json_text(generated_view)
    committed_text = ctx.read_text(committed_path)
    if generated_text == committed_text:
        return
    diff_path = _first_difference_path(generated_view, committed_view)
    if not diff_path:
        diff_path = "$.__serialized_text__"
    ctx.failures.append(
        f"{committed_path} differs from generated view under {source_dir}; first mismatch at {diff_path}. Regenerate committed artifacts from tests/helpers/export_formal_registry_views.gd"
    )


def _first_difference_path(expected: object, actual: object, path: str = "$") -> str:
    if type(expected) is not type(actual):
        return path
    if isinstance(expected, dict):
        expected_keys = list(expected.keys())
        actual_keys = list(actual.keys())
        if expected_keys != actual_keys:
            expected_key_set = set(expected_keys)
            actual_key_set = set(actual_keys)
            for key in expected_keys:
                if key not in actual_key_set:
                    return f"{path}.{key}"
            for key in actual_keys:
                if key not in expected_key_set:
                    return f"{path}.{key}"
            for key in expected_keys:
                if actual_keys.index(key) != expected_keys.index(key):
                    return f"{path}.{key}"
        for key in expected_keys:
            diff_path = _first_difference_path(expected[key], actual[key], f"{path}.{key}")
            if diff_path != "":
                return diff_path
        return ""
    if isinstance(expected, list):
        if len(expected) != len(actual):
            return path
        for index, expected_item in enumerate(expected):
            diff_path = _first_difference_path(expected_item, actual[index], f"{path}[{index}]")
            if diff_path != "":
                return diff_path
        return ""
    if expected != actual:
        return path
    return ""


def _render_json_text(payload: object) -> str:
    return json.dumps(payload, ensure_ascii=False, indent=2)
