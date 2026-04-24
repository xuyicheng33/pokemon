#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/tests/require_tools.sh"
source "$ROOT_DIR/tests/godot_headless_env.sh"
cd "$ROOT_DIR"

setup_godot_headless_home

require_command godot "exporting formal registry views"
require_command python3 "splitting exported formal registry views"

SOURCE_DIR="${1:-config/formal_character_sources}"
MANIFEST_PATH="${2:-config/formal_character_manifest.json}"
CAPABILITY_CATALOG_PATH="${3:-config/formal_character_capability_catalog.json}"

TMP_OUTPUT="$(mktemp)"
trap 'rm -f "$TMP_OUTPUT"; cleanup_godot_headless_home' EXIT

godot --headless --path . --script tests/helpers/export_formal_registry_views.gd -- "$TMP_OUTPUT" "$SOURCE_DIR"

python3 - "$TMP_OUTPUT" "$MANIFEST_PATH" "$CAPABILITY_CATALOG_PATH" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

views_path = Path(sys.argv[1])
manifest_path = Path(sys.argv[2])
capability_catalog_path = Path(sys.argv[3])

payload = json.loads(views_path.read_text(encoding="utf-8"))
if not isinstance(payload, dict):
    raise SystemExit("SYNC_FORMAL_REGISTRY_FAILED: exported views must be top-level object")

manifest = payload.get("manifest", None)
capability_catalog = payload.get("capability_catalog", None)
if not isinstance(manifest, dict):
    raise SystemExit("SYNC_FORMAL_REGISTRY_FAILED: exported manifest must be object")
if not isinstance(capability_catalog, dict):
    raise SystemExit("SYNC_FORMAL_REGISTRY_FAILED: exported capability_catalog must be object")

manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
capability_catalog_path.write_text(json.dumps(capability_catalog, ensure_ascii=False, indent=2), encoding="utf-8")
PY

echo "SYNC_FORMAL_REGISTRY_PASSED: ${SOURCE_DIR} -> ${MANIFEST_PATH}, ${CAPABILITY_CATALOG_PATH}"
