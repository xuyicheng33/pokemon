extends SceneTree

const BattleSandboxLaunchConfigScript := preload("res://src/adapters/battle_sandbox_launch_config.gd")
const FormalCharacterManifestScript := preload("res://src/shared/formal_character_manifest.gd")
const SampleBattleFactoryScript := preload("res://src/composition/sample_battle_factory.gd")

var _launch_config_helper = BattleSandboxLaunchConfigScript.new()

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("EXPORT_SANDBOX_SMOKE_CATALOG_FAILED: missing output path")
		quit(1)
		return
	var output_path := String(args[0]).strip_edges()
	if output_path.is_empty():
		printerr("EXPORT_SANDBOX_SMOKE_CATALOG_FAILED: empty output path")
		quit(1)
		return
	var sample_factory = SampleBattleFactoryScript.new()
	if sample_factory == null:
		printerr("EXPORT_SANDBOX_SMOKE_CATALOG_FAILED: missing SampleBattleFactory")
		quit(1)
		return
	var available_result: Dictionary = sample_factory.available_matchups_result()
	if not bool(available_result.get("ok", false)):
		_print_and_quit("EXPORT_SANDBOX_SMOKE_CATALOG_FAILED: %s" % String(available_result.get("error_message", "failed to load available matchups")), sample_factory)
		return
	var visible_matchups: Array = _launch_config_helper.visible_matchup_descriptors(available_result.get("data", []))
	if visible_matchups.is_empty():
		_print_and_quit("EXPORT_SANDBOX_SMOKE_CATALOG_FAILED: no visible matchups", sample_factory)
		return
	var normalized_default_config := _launch_config_helper.normalize_config(_launch_config_helper.default_config(), available_result.get("data", []))
	var default_matchup_id := String(normalized_default_config.get("matchup_id", "")).strip_edges()
	if default_matchup_id.is_empty():
		_print_and_quit("EXPORT_SANDBOX_SMOKE_CATALOG_FAILED: failed to resolve default visible matchup", sample_factory)
		return
	var visible_matchup_ids: Array = []
	for raw_descriptor in visible_matchups:
		var descriptor: Dictionary = raw_descriptor
		visible_matchup_ids.append(String(descriptor.get("matchup_id", "")).strip_edges())
	var recommended_matchup_ids: Array = []
	for raw_matchup_id in _launch_config_helper.recommended_matchup_ids():
		var matchup_id := String(raw_matchup_id).strip_edges()
		if matchup_id.is_empty():
			continue
		recommended_matchup_ids.append(matchup_id)
	var demo_profile_ids_result: Dictionary = sample_factory.demo_profile_ids_result()
	if not bool(demo_profile_ids_result.get("ok", false)):
		_print_and_quit("EXPORT_SANDBOX_SMOKE_CATALOG_FAILED: %s" % String(demo_profile_ids_result.get("error_message", "failed to load demo profile ids")), sample_factory)
		return
	var demo_profiles: Array = []
	for raw_profile_id in demo_profile_ids_result.get("data", []):
		var profile_id := String(raw_profile_id).strip_edges()
		if profile_id.is_empty():
			continue
		var profile_result: Dictionary = sample_factory.demo_profile_result(profile_id)
		if not bool(profile_result.get("ok", false)):
			_print_and_quit("EXPORT_SANDBOX_SMOKE_CATALOG_FAILED: %s" % String(profile_result.get("error_message", "failed to load demo profile")), sample_factory)
			return
		var profile: Dictionary = profile_result.get("data", {})
		demo_profiles.append({
			"demo_profile_id": profile_id,
			"matchup_id": String(profile.get("matchup_id", "")).strip_edges(),
			"battle_seed": int(profile.get("battle_seed", 0)),
		})
	var manifest = FormalCharacterManifestScript.new()
	var runtime_entries_result: Dictionary = manifest.build_runtime_entries_result()
	if not bool(runtime_entries_result.get("ok", false)):
		_print_and_quit("EXPORT_SANDBOX_SMOKE_CATALOG_FAILED: %s" % String(runtime_entries_result.get("error_message", "failed to load formal manifest runtime entries")), sample_factory)
		return
	var visible_matchup_lookup: Dictionary = {}
	for matchup_id in visible_matchup_ids:
		visible_matchup_lookup[String(matchup_id)] = true
	var quick_anchor_matchup_ids: Array = []
	var seen_anchor_ids: Dictionary = {}
	for raw_entry in runtime_entries_result.get("data", []):
		if not (raw_entry is Dictionary):
			continue
		var formal_setup_matchup_id := String(raw_entry.get("formal_setup_matchup_id", "")).strip_edges()
		if formal_setup_matchup_id.is_empty():
			_print_and_quit("EXPORT_SANDBOX_SMOKE_CATALOG_FAILED: formal runtime entry missing formal_setup_matchup_id: %s" % String(raw_entry.get("character_id", "<unknown>")), sample_factory)
			return
		if not visible_matchup_lookup.has(formal_setup_matchup_id):
			_print_and_quit("EXPORT_SANDBOX_SMOKE_CATALOG_FAILED: quick anchor matchup not visible: %s" % formal_setup_matchup_id, sample_factory)
			return
		if seen_anchor_ids.has(formal_setup_matchup_id):
			continue
		seen_anchor_ids[formal_setup_matchup_id] = true
		quick_anchor_matchup_ids.append(formal_setup_matchup_id)
	if quick_anchor_matchup_ids.is_empty():
		_print_and_quit("EXPORT_SANDBOX_SMOKE_CATALOG_FAILED: no quick anchor matchups derived from manifest", sample_factory)
		return
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		_print_and_quit("EXPORT_SANDBOX_SMOKE_CATALOG_FAILED: cannot open output path: %s" % output_path, sample_factory)
		return
	file.store_string(JSON.stringify({
		"default_matchup_id": default_matchup_id,
		"visible_matchup_ids": visible_matchup_ids,
		"recommended_matchup_ids": recommended_matchup_ids,
		"quick_anchor_matchup_ids": quick_anchor_matchup_ids,
		"demo_profiles": demo_profiles,
	}, "  "))
	file.flush()
	file.close()
	sample_factory.dispose()
	quit(0)

func _print_and_quit(message: String, sample_factory) -> void:
	if sample_factory != null and sample_factory.has_method("dispose"):
		sample_factory.dispose()
	printerr(message)
	quit(1)
