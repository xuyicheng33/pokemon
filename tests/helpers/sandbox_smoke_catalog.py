"""Sandbox smoke catalog parser.

Reads the catalog JSON exported by `tests/helpers/export_sandbox_smoke_catalog.gd`
and emits shell-friendly key/value lines so that `check_sandbox_smoke_matrix.sh`
can drive the matrix without re-parsing the same payload from five different
heredocs.

Output format (one record per logical key, blank line separated):

    KEY default_matchup_id
    <value>

    KEY visible_matchup_ids
    <value>
    <value>
    ...

    KEY recommended_matchup_ids
    ...

    KEY quick_anchor_matchup_ids
    ...

    KEY demo_profiles
    <demo_profile_id>\t<matchup_id>\t<battle_seed>
    ...

A consumer also drives summary validation through this script via subcommands
(`validate-summary` / `validate-demo-summary`) so the shell stays a thin
matrix runner.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path


def _load_payload(catalog_path: str) -> dict:
    payload = json.loads(Path(catalog_path).read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise SystemExit("SANDBOX_SMOKE_FAILED: sandbox smoke catalog must be a JSON object")
    return payload


def _emit_block(key: str, lines: list[str]) -> None:
    print(f"KEY {key}")
    for line in lines:
        print(line)
    print("")


def _stringify_id_list(payload: dict, field: str) -> list[str]:
    out: list[str] = []
    for raw in payload.get(field, []) or []:
        text = str(raw).strip()
        if text:
            out.append(text)
    return out


def cmd_dump(catalog_path: str) -> None:
    payload = _load_payload(catalog_path)

    default_matchup_id = str(payload.get("default_matchup_id", "")).strip()
    _emit_block("default_matchup_id", [default_matchup_id] if default_matchup_id else [])

    _emit_block("visible_matchup_ids", _stringify_id_list(payload, "visible_matchup_ids"))
    _emit_block(
        "recommended_matchup_ids",
        _stringify_id_list(payload, "recommended_matchup_ids"),
    )
    _emit_block(
        "quick_anchor_matchup_ids",
        _stringify_id_list(payload, "quick_anchor_matchup_ids"),
    )

    demo_rows: list[str] = []
    for raw_profile in payload.get("demo_profiles", []) or []:
        if not isinstance(raw_profile, dict):
            continue
        demo_profile_id = str(raw_profile.get("demo_profile_id", "")).strip()
        matchup_id = str(raw_profile.get("matchup_id", "")).strip()
        try:
            battle_seed = int(raw_profile.get("battle_seed", 0))
        except (TypeError, ValueError):
            battle_seed = 0
        if demo_profile_id and matchup_id and battle_seed > 0:
            demo_rows.append(f"{demo_profile_id}\t{matchup_id}\t{battle_seed}")
    _emit_block("demo_profiles", demo_rows)


def _last_json_line(log_path: str) -> dict:
    json_line = None
    for raw_line in Path(log_path).read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw_line.strip()
        if line.startswith("{") and line.endswith("}"):
            json_line = line
    if json_line is None:
        raise SystemExit("missing summary JSON")
    try:
        return json.loads(json_line)
    except Exception as exc:  # noqa: BLE001
        raise SystemExit(f"invalid summary JSON: {exc}")


def cmd_validate_summary(args: list[str]) -> None:
    if len(args) != 5:
        raise SystemExit(
            "usage: validate-summary <label> <log_path> <expected_matchup_id> <expected_p1_mode> <expected_p2_mode>"
        )
    label, log_path, expected_matchup_id, expected_p1_mode, expected_p2_mode = args

    try:
        payload = _last_json_line(log_path)
    except SystemExit as exc:
        raise SystemExit(f"SANDBOX_SMOKE_FAILED: {label} {exc}")

    required_keys = [
        "matchup_id",
        "battle_seed",
        "p1_control_mode",
        "p2_control_mode",
        "winner_side_id",
        "reason",
        "result_type",
        "turn_index",
        "event_log_cursor",
        "command_steps",
    ]
    missing_keys = [key for key in required_keys if key not in payload]
    if missing_keys:
        raise SystemExit(
            f"SANDBOX_SMOKE_FAILED: {label} missing keys: {', '.join(missing_keys)}"
        )

    if payload["matchup_id"] != expected_matchup_id:
        raise SystemExit(
            f"SANDBOX_SMOKE_FAILED: {label} matchup drifted: {payload['matchup_id']} != {expected_matchup_id}"
        )
    if payload["p1_control_mode"] != expected_p1_mode:
        raise SystemExit(
            f"SANDBOX_SMOKE_FAILED: {label} P1 mode drifted: {payload['p1_control_mode']} != {expected_p1_mode}"
        )
    if payload["p2_control_mode"] != expected_p2_mode:
        raise SystemExit(
            f"SANDBOX_SMOKE_FAILED: {label} P2 mode drifted: {payload['p2_control_mode']} != {expected_p2_mode}"
        )
    if int(payload["battle_seed"]) <= 0:
        raise SystemExit(
            f"SANDBOX_SMOKE_FAILED: {label} invalid battle_seed: {payload['battle_seed']}"
        )
    if not str(payload["reason"]).strip():
        raise SystemExit(f"SANDBOX_SMOKE_FAILED: {label} reason is empty")
    if not str(payload["result_type"]).strip():
        raise SystemExit(f"SANDBOX_SMOKE_FAILED: {label} result_type is empty")
    if payload["result_type"] == "win" and not str(payload["winner_side_id"]).strip():
        raise SystemExit(
            f"SANDBOX_SMOKE_FAILED: {label} win result requires non-empty winner_side_id"
        )
    if payload["result_type"] in ("draw", "no_winner") and str(payload["winner_side_id"]).strip():
        raise SystemExit(
            f"SANDBOX_SMOKE_FAILED: {label} {payload['result_type']} result must keep winner_side_id empty"
        )
    if int(payload["turn_index"]) <= 0:
        raise SystemExit(
            f"SANDBOX_SMOKE_FAILED: {label} invalid turn_index: {payload['turn_index']}"
        )
    if int(payload["event_log_cursor"]) <= 0:
        raise SystemExit(
            f"SANDBOX_SMOKE_FAILED: {label} invalid event_log_cursor: {payload['event_log_cursor']}"
        )
    if int(payload["command_steps"]) <= 0:
        raise SystemExit(
            f"SANDBOX_SMOKE_FAILED: {label} invalid command_steps: {payload['command_steps']}"
        )

    print(
        "SANDBOX_SMOKE_CASE_PASSED: "
        f"{label} matchup={payload['matchup_id']} "
        f"modes={payload['p1_control_mode']}/{payload['p2_control_mode']} "
        f"turn={payload['turn_index']} commands={payload['command_steps']}"
    )


def cmd_validate_demo_summary(args: list[str]) -> None:
    if len(args) != 5:
        raise SystemExit(
            "usage: validate-demo-summary <label> <log_path> <expected_profile_id> <expected_matchup_id> <expected_battle_seed>"
        )
    label, log_path, expected_profile_id, expected_matchup_id, expected_battle_seed_raw = args
    try:
        expected_battle_seed = int(expected_battle_seed_raw)
    except ValueError:
        raise SystemExit(
            f"SANDBOX_SMOKE_FAILED: {label} invalid expected_battle_seed: {expected_battle_seed_raw}"
        )

    try:
        payload = _last_json_line(log_path)
    except SystemExit as exc:
        raise SystemExit(f"SANDBOX_SMOKE_FAILED: {label} {exc}")

    required_keys = [
        "demo_profile_id",
        "matchup_id",
        "battle_seed",
        "p1_control_mode",
        "p2_control_mode",
        "turn_index",
        "event_log_cursor",
        "command_steps",
    ]
    missing_keys = [key for key in required_keys if key not in payload]
    if missing_keys:
        raise SystemExit(
            f"SANDBOX_SMOKE_FAILED: {label} missing keys: {', '.join(missing_keys)}"
        )

    if payload["demo_profile_id"] != expected_profile_id:
        raise SystemExit(
            f"SANDBOX_SMOKE_FAILED: {label} profile drifted: {payload['demo_profile_id']} != {expected_profile_id}"
        )
    if payload["matchup_id"] != expected_matchup_id:
        raise SystemExit(
            f"SANDBOX_SMOKE_FAILED: {label} matchup drifted: {payload['matchup_id']} != {expected_matchup_id}"
        )
    if int(payload["battle_seed"]) != expected_battle_seed:
        raise SystemExit(
            f"SANDBOX_SMOKE_FAILED: {label} battle_seed drifted: {payload['battle_seed']} != {expected_battle_seed}"
        )
    if int(payload["turn_index"]) <= 0:
        raise SystemExit(
            f"SANDBOX_SMOKE_FAILED: {label} invalid turn_index: {payload['turn_index']}"
        )
    if int(payload["event_log_cursor"]) <= 0:
        raise SystemExit(
            f"SANDBOX_SMOKE_FAILED: {label} invalid event_log_cursor: {payload['event_log_cursor']}"
        )

    print(
        "SANDBOX_SMOKE_CASE_PASSED: "
        f"{label} demo={payload['demo_profile_id']} "
        f"matchup={payload['matchup_id']} seed={payload['battle_seed']} "
        f"turn={payload['turn_index']} events={payload['event_log_cursor']}"
    )


def main(argv: list[str]) -> None:
    if len(argv) < 2:
        raise SystemExit("usage: sandbox_smoke_catalog.py <dump|validate-summary|validate-demo-summary> ...")
    cmd = argv[1]
    rest = argv[2:]
    if cmd == "dump":
        if len(rest) != 1:
            raise SystemExit("usage: sandbox_smoke_catalog.py dump <catalog_path>")
        cmd_dump(rest[0])
    elif cmd == "validate-summary":
        cmd_validate_summary(rest)
    elif cmd == "validate-demo-summary":
        cmd_validate_demo_summary(rest)
    else:
        raise SystemExit(f"unknown subcommand: {cmd}")


if __name__ == "__main__":
    main(sys.argv)
