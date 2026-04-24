#!/usr/bin/env python3
"""Scaffold generator for a new formal character.

Usage:
    python3 scripts/new_formal_character.py <character_id> <display_name> [options]

Example:
    python3 scripts/new_formal_character.py itadori_yuji "虎杖悠仁" --pair-token itadori
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SOURCE_DIR = REPO_ROOT / "config" / "formal_character_sources"
DRAFTS_DIR = REPO_ROOT / "scripts" / "drafts"
SAFE_ID_PATTERN = re.compile(r"^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$")


# ---------------------------------------------------------------------------
# Naming helpers
# ---------------------------------------------------------------------------

def to_pascal_case(snake: str) -> str:
    """Convert 'gojo_satoru' to 'GojoSatoru'."""
    return "".join(word.capitalize() for word in snake.split("_"))


def validate_safe_id(value: str, label: str) -> None:
    if SAFE_ID_PATTERN.fullmatch(value):
        return
    print(
        f"ERROR: {label} must be lower snake_case and start with a letter: {value}",
        file=sys.stderr,
    )
    sys.exit(1)


def next_source_index() -> int:
    """Scan existing 0N_*.json and return max+1."""
    pattern = re.compile(r"^(\d+)_.+\.json$")
    max_index = 0
    for search_dir in [SOURCE_DIR, DRAFTS_DIR]:
        if not search_dir.exists():
            continue
        for f in search_dir.iterdir():
            m = pattern.match(f.name)
            if m:
                max_index = max(max_index, int(m.group(1)))
    return max_index + 1


def _iter_source_descriptors():
    """Yield (path, parsed_data) for every source descriptor JSON."""
    for search_dir in [SOURCE_DIR, DRAFTS_DIR]:
        if not search_dir.exists():
            continue
        for f in search_dir.iterdir():
            if not f.name.endswith(".json") or f.name == "00_shared_registry.json":
                continue
            try:
                data = json.loads(f.read_text(encoding="utf-8"))
            except (json.JSONDecodeError, OSError) as exc:
                print(f"ERROR: failed to read source descriptor {f.relative_to(REPO_ROOT)}: {exc}", file=sys.stderr)
                sys.exit(1)
            if data.get("descriptor_kind") == "formal_character_source":
                yield f, data


def find_existing_source_descriptor(char_id: str) -> Path | None:
    """Return existing source descriptor path for char_id, or None."""
    for f, data in _iter_source_descriptors():
        if data.get("character", {}).get("character_id") == char_id:
            return f
    return None


def find_pair_token_owner(pair_token: str) -> str | None:
    """Return character_id that already owns this pair_token, or None."""
    for _f, data in _iter_source_descriptors():
        char = data.get("character", {})
        if char.get("pair_token") == pair_token:
            return str(char.get("character_id", ""))
    return None


def collect_existing_characters() -> list[dict]:
    """Return list of {character_id, pair_token} for all existing formal characters, sorted by source index."""
    entries: list[tuple[int, dict]] = []
    pattern = re.compile(r"^(\d+)_.+\.json$")
    for f, data in _iter_source_descriptors():
        m = pattern.match(f.name)
        idx = int(m.group(1)) if m else 999
        char = data.get("character", {})
        character_id = str(char.get("character_id", "")).strip()
        pair_token = str(char.get("pair_token", "")).strip()
        if character_id and pair_token:
            entries.append((idx, {"character_id": character_id, "pair_token": pair_token}))
    entries.sort(key=lambda x: x[0])
    return [e[1] for e in entries]


# ---------------------------------------------------------------------------
# Template generators
# ---------------------------------------------------------------------------

def generate_source_descriptor(
    char_id: str,
    display_name: str,
    pair_token: str,
    unit_definition_id: str,
    index: int,
) -> tuple[str, str]:
    """Return (filename, json_content) for the source descriptor.

    Generated as a draft — delivery-required fields are left with
    placeholder markers so the user fills them before moving the file
    into config/formal_character_sources/.
    """
    filename = f"{index:02d}_{char_id}.json"
    data = {
        "descriptor_kind": "formal_character_source",
        "character": {
            "character_id": char_id,
            "display_name": display_name,
            "unit_definition_id": unit_definition_id,
            "formal_setup_matchup_id": f"{pair_token}_vs_sample",
            "pair_token": pair_token,
            "baseline_script_path": f"src/shared/formal_character_baselines/{char_id}/{char_id}_formal_character_baseline.gd",
            "pair_initiator_bench_unit_ids": [
                "sample_mossaur",
                "sample_pyron"
            ],
            "pair_responder_bench_unit_ids": [
                "sample_tidekit",
                "sample_mossaur"
            ],
            "owned_pair_interaction_specs": _build_interaction_spec_placeholders(pair_token),
            "content_roots": [
                f"content/units/{pair_token}",
                f"content/skills/{pair_token}",
                f"content/effects/{pair_token}",
                f"content/passive_skills/{pair_token}",
                f"content/fields/{pair_token}",
            ],
            "content_validator_script_path": f"src/battle_core/content/formal_validators/{pair_token}/content_snapshot_formal_{pair_token}_validator.gd",
            "design_doc": f"docs/design/{char_id}_design.md",
            "adjustment_doc": f"docs/design/{char_id}_adjustments.md",
            "design_needles": ["FILL_IN_design_anchor"],
            "adjustment_needles": ["FILL_IN_adjustment_anchor"],
            "shared_capability_ids": [],
            "suite_path": f"test/suites/{pair_token}_suite.gd",
            "required_suite_paths": [
                f"test/suites/{pair_token}_snapshot_suite.gd",
                f"test/suites/{pair_token}_manager_smoke_suite.gd",
            ],
            "required_test_names": ["FILL_IN_test_name"],
            "surface_smoke_skill_id": "FILL_IN_skill_id",
        },
    }
    content = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    return filename, content


def _build_interaction_spec_placeholders(pair_token: str) -> list[dict]:
    """Build owned_pair_interaction_specs placeholders for all existing characters."""
    existing = collect_existing_characters()
    specs: list[dict] = []
    base_seed = 3001
    for i, entry in enumerate(existing):
        specs.append({
            "other_character_id": entry["character_id"],
            "scenario_key": f"FILL_IN_{entry['pair_token']}_{pair_token}_scenario",
            "owner_as_initiator_battle_seed": base_seed + i * 2,
            "owner_as_responder_battle_seed": base_seed + i * 2 + 1,
        })
    return specs


def generate_baseline(char_id: str, display_name: str) -> str:
    """Generate the formal character baseline GDScript."""
    pascal = to_pascal_case(char_id)
    return f'''\
extends RefCounted
class_name {pascal}FormalCharacterBaseline

func unit_contract() -> Dictionary:
\treturn {{
\t\t"label": "formal[{char_id}].unit",
\t\t"snapshot_label": "{char_id}",
\t\t"unit_id": "{char_id}",
\t\t"fields": {{
\t\t\t"draft_marker": "FORMAL_DRAFT_BASELINE_REPLACE_BEFORE_LIVE",
\t\t\t"display_name": "{display_name}",
\t\t\t"base_hp": 0,
\t\t\t"base_attack": 0,
\t\t\t"base_defense": 0,
\t\t\t"base_sp_attack": 0,
\t\t\t"base_sp_defense": 0,
\t\t\t"base_speed": 0,
\t\t\t"max_mp": 100,
\t\t\t"init_mp": 50,
\t\t\t"regen_per_turn": 0,
\t\t\t"ultimate_points_required": 3,
\t\t\t"ultimate_points_cap": 3,
\t\t\t"ultimate_point_gain_on_regular_skill_cast": 1,
\t\t\t"combat_type_ids": PackedStringArray([]),
\t\t\t"skill_ids": PackedStringArray([]),
\t\t\t"candidate_skill_ids": PackedStringArray([]),
\t\t\t"ultimate_skill_id": "",
\t\t\t"passive_skill_id": "",
\t\t}},
\t}}

func regular_skill_contracts() -> Array[Dictionary]:
\treturn []

func ultimate_skill_contract() -> Dictionary:
\treturn {{}}

func passive_skill_contract() -> Dictionary:
\treturn {{}}

func effect_contracts() -> Array[Dictionary]:
\treturn []

func field_contracts() -> Array[Dictionary]:
\treturn []
'''


def generate_validator(char_id: str, pair_token: str) -> str:
    """Generate the formal character validator GDScript."""
    pascal_token = to_pascal_case(pair_token)
    return f'''\
extends "res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_validator_base.gd"
class_name ContentSnapshotFormal{pascal_token}Validator

const ContractHelperScript := preload("res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_contract_helper.gd")
const FormalCharacterBaselinesScript := preload("res://src/shared/formal_character_baselines.gd")

var _helper = ContractHelperScript.new()

func validate(content_index: BattleContentIndex, errors: Array) -> void:
\t_validate_unit_passive(content_index, errors)
\t_validate_skill_effect(content_index, errors)
\t_validate_ultimate_domain(content_index, errors)

func _validate_unit_passive(content_index: BattleContentIndex, errors: Array) -> void:
\t_helper.validate_unit_contract_descriptor(
\t\tself,
\t\tcontent_index,
\t\terrors,
\t\tFormalCharacterBaselinesScript.unit_contract("{char_id}")
\t)

func _validate_skill_effect(content_index: BattleContentIndex, errors: Array) -> void:
\terrors.append("FORMAL_DRAFT_VALIDATOR_REPLACE_BEFORE_LIVE: {char_id} skill/effect assertions are incomplete")

func _validate_ultimate_domain(content_index: BattleContentIndex, errors: Array) -> void:
\terrors.append("FORMAL_DRAFT_VALIDATOR_REPLACE_BEFORE_LIVE: {char_id} ultimate/domain assertions are incomplete")
'''


def generate_snapshot_suite(char_id: str, pair_token: str, display_name: str) -> str:
    """Generate the snapshot test suite shell."""
    return f'''\
extends "res://test/support/gdunit_suite_bridge.gd"

const FormalCharacterBaselinesScript := preload("res://src/shared/formal_character_baselines.gd")
const FormalCharacterSnapshotTestHelperScript := preload("res://tests/support/formal_character_snapshot_test_helper.gd")

var _helper = FormalCharacterSnapshotTestHelperScript.new()


func test_{pair_token}_unit_snapshot_contract() -> void:
\t_assert_legacy_result(_test_{pair_token}_unit_snapshot_contract(_harness))

func test_{pair_token}_skill_snapshot_contract() -> void:
\t_assert_legacy_result(_test_{pair_token}_skill_snapshot_contract(_harness))

func test_{pair_token}_effect_snapshot_contract() -> void:
\t_assert_legacy_result(_test_{pair_token}_effect_snapshot_contract(_harness))

func _test_{pair_token}_unit_snapshot_contract(harness) -> Dictionary:
\tvar content_index = _helper.build_content_index(harness)
\tif content_index == null:
\t\treturn harness.fail_result("failed to load content snapshot for {display_name} unit snapshot")
\treturn _helper.run_descriptor_checks(
\t\tharness,
\t\tcontent_index.units,
\t\t[FormalCharacterBaselinesScript.unit_contract("{char_id}")],
\t\t"unit_id",
\t\t"missing {pair_token} unit definition"
\t)

func _test_{pair_token}_skill_snapshot_contract(harness) -> Dictionary:
\tvar content_index = _helper.build_content_index(harness)
\tif content_index == null:
\t\treturn harness.fail_result("failed to load content snapshot for {display_name} skill snapshot")
\treturn _helper.run_descriptor_checks(
\t\tharness,
\t\tcontent_index.skills,
\t\tFormalCharacterBaselinesScript.skill_contracts("{char_id}"),
\t\t"skill_id",
\t\t"missing {pair_token} snapshot skill resource"
\t)

func _test_{pair_token}_effect_snapshot_contract(harness) -> Dictionary:
\tvar content_index = _helper.build_content_index(harness)
\tif content_index == null:
\t\treturn harness.fail_result("failed to load content snapshot for {display_name} effect snapshot")
\treturn _helper.run_descriptor_checks(
\t\tharness,
\t\tcontent_index.effects,
\t\tFormalCharacterBaselinesScript.effect_contracts("{char_id}"),
\t\t"effect_id",
\t\t"missing {pair_token} snapshot effect resource"
\t)
'''


def generate_runtime_suite(pair_token: str) -> str:
    """Generate the runtime suite wrapper shell."""
    pascal_token = to_pascal_case(pair_token)
    return f'''\
extends GdUnitTestSuite

const {pascal_token}SnapshotSuiteScript := preload("res://test/suites/{pair_token}_snapshot_suite.gd")
const {pascal_token}ManagerSmokeSuiteScript := preload("res://test/suites/{pair_token}_manager_smoke_suite.gd")
'''


def generate_manager_smoke_suite(char_id: str, pair_token: str) -> str:
    """Generate the manager smoke suite shell."""
    return f'''\
extends "res://test/support/gdunit_suite_bridge.gd"

const FormalCharacterManagerSmokeHelperScript := preload("res://tests/support/formal_character_manager_smoke_helper.gd")

var _smoke_helper = null
var _helper = null
var _case_specs: Array = []

func _ensure_suite_state() -> void:
\tif _smoke_helper == null or _helper == null:
\t\t_smoke_helper = FormalCharacterManagerSmokeHelperScript.new()
\t\t_helper = _smoke_helper.contracts()
\tif _case_specs.is_empty():
\t\t_case_specs = [
\t\t\t{{
\t\t\t\t"test_name": "test_{pair_token}_manager_smoke_contract",
\t\t\t\t"battle_seed": 9999,
\t\t\t\t"build_battle_setup": Callable(self, "_build_{pair_token}_manager_smoke_setup"),
\t\t\t\t"run_case": Callable(self, "_run_{pair_token}_manager_smoke_case"),
\t\t\t}},
\t\t]

func before_test() -> void:
\t_ensure_suite_state()

func test_{pair_token}_manager_smoke_contract() -> void:
\t_assert_legacy_result(_test_{pair_token}_manager_smoke_contract(_harness))

func _test_{pair_token}_manager_smoke_contract(harness) -> Dictionary:
\treturn _smoke_helper.run_named_case(harness, _case_specs, "test_{pair_token}_manager_smoke_contract")

func _build_{pair_token}_manager_smoke_setup(harness, sample_factory, _case_spec: Dictionary):
\treturn harness.build_setup_by_matchup_id(sample_factory, "{pair_token}_vs_sample")

func _run_{pair_token}_manager_smoke_case(state: Dictionary) -> Dictionary:
\tvar harness = state["harness"]
\tvar manager = state["manager"]
\tvar session_id := String(state["session_id"])
\tvar legal_actions_unwrap = _smoke_helper.get_legal_actions_result(manager, session_id, "P1", "get_legal_actions")
\tif not bool(legal_actions_unwrap.get("ok", false)):
\t\treturn harness.fail_result(str(legal_actions_unwrap.get("error", "manager get_legal_actions failed")))
\treturn harness.pass_result("{pair_token} manager smoke passed")
'''


def generate_interaction_cases(char_id: str, pair_token: str) -> str:
    """Generate the pair interaction cases GDScript shell."""
    pascal_token = to_pascal_case(pair_token)
    existing = collect_existing_characters()
    if not existing:
        return f'''\
extends RefCounted
class_name FormalPairInteraction{pascal_token}Cases

func build_runners() -> Dictionary:
\treturn {{}}
'''
    runner_methods: list[str] = []
    runner_entries: list[str] = []
    for entry in existing:
        other_token = entry["pair_token"]
        scenario_key = f"FILL_IN_{other_token}_{pair_token}_scenario"
        runner_entries.append(f'\t\t"{scenario_key}": Callable(self, "run_{scenario_key}")')
        runner_methods.append(f'''\
func run_{scenario_key}(harness, case_spec: Dictionary) -> Dictionary:
\tvar matchup_id := String(case_spec.get("matchup_id", "")).strip_edges()
\tif matchup_id.is_empty():
\t\treturn harness.fail_result("formal pair interaction case missing matchup_id")
\tvar battle_seed = case_spec.get("battle_seed", null)
\tif typeof(battle_seed) != TYPE_INT or int(battle_seed) <= 0:
\t\treturn harness.fail_result("formal pair interaction case missing positive integer battle_seed")
\t# TODO: implement {pair_token} vs {other_token} interaction contract
\treturn harness.pass_result("{pair_token} vs {other_token} interaction placeholder")''')

    runners_block = ",\n".join(runner_entries)
    methods_block = "\n\n".join(runner_methods)
    return f'''\
extends RefCounted
class_name FormalPairInteraction{pascal_token}Cases

func build_runners() -> Dictionary:
\treturn {{
{runners_block}
\t}}

{methods_block}
'''


# ---------------------------------------------------------------------------
# File writer
# ---------------------------------------------------------------------------

def write_file(path: Path, content: str) -> None:
    """Write content to path, creating parent dirs as needed. Refuse to overwrite."""
    if path.exists():
        print(f"  SKIP (exists): {path.relative_to(REPO_ROOT)}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    print(f"  CREATE: {path.relative_to(REPO_ROOT)}")


def ensure_dir(path: Path) -> None:
    """Create directory if it doesn't exist."""
    if path.exists():
        print(f"  SKIP (exists): {path.relative_to(REPO_ROOT)}/")
        return
    path.mkdir(parents=True, exist_ok=True)
    print(f"  CREATE: {path.relative_to(REPO_ROOT)}/")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(description="Scaffold a new formal character.")
    parser.add_argument("character_id", help="Snake_case character id, e.g. itadori_yuji")
    parser.add_argument("display_name", help="Display name (Chinese), e.g. 虎杖悠仁")
    parser.add_argument("--pair-token", dest="pair_token", default=None,
                        help="Short name for suites/validator dirs (default: first segment of character_id)")
    parser.add_argument("--unit-definition-id", dest="unit_definition_id", default=None,
                        help="Unit resource id (default: same as character_id)")
    args = parser.parse_args()

    char_id: str = args.character_id.strip()
    display_name: str = args.display_name.strip()
    pair_token: str = (args.pair_token or char_id.split("_")[0]).strip()
    unit_def_id: str = (args.unit_definition_id or char_id).strip()

    if not char_id or not display_name:
        print("ERROR: character_id and display_name are required.", file=sys.stderr)
        sys.exit(1)
    validate_safe_id(char_id, "character_id")
    validate_safe_id(pair_token, "pair_token")
    validate_safe_id(unit_def_id, "unit_definition_id")

    # --- pair_token collision check ---
    existing_owner = find_pair_token_owner(pair_token)
    if existing_owner and existing_owner != char_id:
        print(
            f"ERROR: pair_token '{pair_token}' is already used by character "
            f"'{existing_owner}'. Choose a different --pair-token.",
            file=sys.stderr,
        )
        sys.exit(1)

    index = next_source_index()
    pascal = to_pascal_case(char_id)
    print(f"\n=== Scaffolding formal character: {char_id} ({display_name}) ===")
    print(f"  pair_token     = {pair_token}")
    print(f"  PascalCase     = {pascal}")
    print(f"  source index   = {index:02d}")
    print()

    # 1. Source descriptor (staged to scripts/drafts/, NOT live config)
    print("[1/8] Source descriptor (draft)")
    existing_sd = find_existing_source_descriptor(char_id)
    if existing_sd:
        sd_filename = existing_sd.name
        sd_location = str(existing_sd.relative_to(REPO_ROOT))
        # Verify current args match the existing descriptor
        existing_data = json.loads(existing_sd.read_text(encoding="utf-8"))
        existing_char = existing_data.get("character", {})
        existing_token = str(existing_char.get("pair_token", "")).strip()
        existing_unit_def = str(existing_char.get("unit_definition_id", "")).strip()
        mismatches: list[str] = []
        if existing_token and existing_token != pair_token:
            mismatches.append(
                f"pair_token: descriptor has '{existing_token}', args say '{pair_token}'"
            )
        if existing_unit_def and existing_unit_def != unit_def_id:
            mismatches.append(
                f"unit_definition_id: descriptor has '{existing_unit_def}', args say '{unit_def_id}'"
            )
        if mismatches:
            print(
                f"ERROR: existing descriptor at {sd_location} conflicts with current args:\n  "
                + "\n  ".join(mismatches)
                + "\nDelete or manually update the existing descriptor first.",
                file=sys.stderr,
            )
            sys.exit(1)
        print(f"  SKIP (exists): {sd_location}")
    else:
        sd_filename, sd_content = generate_source_descriptor(
            char_id, display_name, pair_token, unit_def_id, index,
        )
        write_file(DRAFTS_DIR / sd_filename, sd_content)
        sd_location = f"scripts/drafts/{sd_filename}"

    # 2. Content directories
    print("[2/8] Content directories")
    for sub in ["units", "skills", "effects", "passive_skills", "fields"]:
        ensure_dir(REPO_ROOT / "content" / sub / pair_token)

    # 3. Baseline
    print("[3/8] Baseline script (draft)")
    baseline_dir = DRAFTS_DIR / "src" / "shared" / "formal_character_baselines" / char_id
    write_file(baseline_dir / f"{char_id}_formal_character_baseline.gd",
               generate_baseline(char_id, display_name))

    # 4. Validator
    print("[4/8] Validator script (draft)")
    validator_dir = DRAFTS_DIR / "src" / "battle_core" / "content" / "formal_validators" / pair_token
    write_file(validator_dir / f"content_snapshot_formal_{pair_token}_validator.gd",
               generate_validator(char_id, pair_token))

    # 5. Test suites
    print("[5/8] Test suite shells (draft)")
    suites_dir = DRAFTS_DIR / "test" / "suites"
    write_file(suites_dir / f"{pair_token}_snapshot_suite.gd",
               generate_snapshot_suite(char_id, pair_token, display_name))
    write_file(suites_dir / f"{pair_token}_suite.gd",
               generate_runtime_suite(pair_token))
    write_file(suites_dir / f"{pair_token}_manager_smoke_suite.gd",
               generate_manager_smoke_suite(char_id, pair_token))

    # 6. Design doc placeholders
    print("[6/8] Design doc placeholders (draft)")
    write_file(DRAFTS_DIR / "docs" / "design" / f"{char_id}_design.md",
               f"# {display_name} 设计稿\n\n（待补充）\n")
    write_file(DRAFTS_DIR / "docs" / "design" / f"{char_id}_adjustments.md",
               f"# {display_name} 调整记录\n\n（待补充）\n")

    # 7. Pair interaction cases shell
    existing_characters = collect_existing_characters()
    interaction_location = ""
    if existing_characters:
        print("[7/8] Pair interaction cases shell (draft)")
        interaction_dir = DRAFTS_DIR / "formal_pair_interaction"
        interaction_location = str((interaction_dir / f"{pair_token}_cases.gd").relative_to(REPO_ROOT))
        write_file(interaction_dir / f"{pair_token}_cases.gd",
                   generate_interaction_cases(char_id, pair_token))
    else:
        print("[7/8] Pair interaction cases shell (skipped — no existing characters)")

    # Checklist
    print(f"""
=== Scaffold complete ===

!! Source descriptor is in scripts/drafts/, NOT in config/.
!! DO NOT run sync_formal_registry.sh until you complete steps 1-7 below.

Next steps:

  1. Fill in .tres content resources under:
     - content/units/{pair_token}/
     - content/skills/{pair_token}/
     - content/effects/{pair_token}/
     - content/passive_skills/{pair_token}/
     - content/fields/{pair_token}/ (if character has domain/field)

  2. Fill in baseline data values:
     - scripts/drafts/src/shared/formal_character_baselines/{char_id}/{char_id}_formal_character_baseline.gd

  3. Fill in validator assertions:
     - scripts/drafts/src/battle_core/content/formal_validators/{pair_token}/content_snapshot_formal_{pair_token}_validator.gd

  4. Fill in manager smoke suite:
     - scripts/drafts/test/suites/{pair_token}_manager_smoke_suite.gd
     - Update battle_seed, skill assertions, etc.

  5. Complete the source descriptor (currently at {sd_location}):
     - Replace FILL_IN_skill_id with actual surface_smoke_skill_id
     - Replace FILL_IN_test_name entries with actual required_test_names
     - Replace FILL_IN_design_anchor / FILL_IN_adjustment_anchor with actual doc anchors
     - Add shared_capability_ids if the character uses shared capabilities

  6. Review shared matchup needs:
     - Default "{pair_token}_vs_sample" is now auto-derived from pair_initiator_bench_unit_ids
     - Only update config/formal_character_sources/00_shared_registry.json if you need:
       a. custom formal_setup_matchup_id
       b. custom sample team composition
       c. extra shared/test_only matchup

  7. Complete pair interaction layer:
     - Fill in scenario_key values in owned_pair_interaction_specs (replace FILL_IN_* placeholders)
     - Fill in battle_seed values (must be positive integers, unique per directed case)
     - Implement runner methods in {interaction_location if interaction_location else "the generated pair case draft"}
     - Move the finished runner to tests/support/formal_pair_interaction/{pair_token}_cases.gd only when the source descriptor moves into live config
     - scenario_registry.gd auto-discovers live *_cases.gd files; draft files are intentionally not discovered

  8. Move completed draft files into live paths:
     - scripts/drafts/src/shared/formal_character_baselines/{char_id}/ -> src/shared/formal_character_baselines/{char_id}/
     - scripts/drafts/src/battle_core/content/formal_validators/{pair_token}/ -> src/battle_core/content/formal_validators/{pair_token}/
     - scripts/drafts/test/suites/{pair_token}_*.gd -> test/suites/
     - scripts/drafts/docs/design/{char_id}_*.md -> docs/design/

  9. Move source descriptor into live config:
     mv {sd_location} config/formal_character_sources/{sd_filename}

  10. Sync formal registry:
     bash tests/sync_formal_registry.sh

  11. Run validation:
      bash tests/run_with_gate.sh
""")


if __name__ == "__main__":
    main()
