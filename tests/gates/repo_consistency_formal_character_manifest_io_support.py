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
        manifest_path=manifest_path,
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
        manifest_path=manifest_path,
        failure_label="formal pair catalog",
    )
    return payload if isinstance(payload, dict) else {}


def run_godot_json_export(
    ctx: GateContext,
    *,
    export_script_path: str,
    manifest_path: str,
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
