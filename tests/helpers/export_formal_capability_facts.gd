extends SceneTree

const FormalCharacterManifestScript := preload("res://src/shared/formal_character_manifest.gd")
const ManifestLoaderScript := preload("res://src/shared/formal_character_manifest/formal_character_manifest_loader.gd")
const ResourcePathHelperScript := preload("res://src/shared/resource_path_helper.gd")
const COLLECTOR_DIR := "res://tests/helpers/formal_capability_fact_collectors"
const COLLECTOR_SUFFIX := "_collector.gd"

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("EXPORT_FORMAL_CAPABILITY_FACTS_FAILED: missing output path")
		quit(1)
		return
	var output_path := String(args[0]).strip_edges()
	if output_path.is_empty():
		printerr("EXPORT_FORMAL_CAPABILITY_FACTS_FAILED: empty output path")
		quit(1)
		return
	var manifest_path := ""
	if args.size() >= 2:
		manifest_path = String(args[1]).strip_edges()
	var collectors_result := _load_collectors_result()
	if not bool(collectors_result.get("ok", false)):
		printerr("EXPORT_FORMAL_CAPABILITY_FACTS_FAILED: %s" % String(collectors_result.get("error_message", "collector load failed")))
		quit(1)
		return
	var manifest = FormalCharacterManifestScript.new()
	if manifest == null:
		printerr("EXPORT_FORMAL_CAPABILITY_FACTS_FAILED: missing manifest loader")
		quit(1)
		return
	if not manifest_path.is_empty():
		manifest.manifest_path_override = manifest_path
	var entries_result: Dictionary = manifest.build_character_entries_result()
	if not bool(entries_result.get("ok", false)):
		printerr("EXPORT_FORMAL_CAPABILITY_FACTS_FAILED: %s" % String(entries_result.get("error_message", "unknown error")))
		quit(1)
		return
	var facts_by_character: Dictionary = {}
	var fact_sources_by_character: Dictionary = {}
	for raw_entry in entries_result.get("data", []):
		if not (raw_entry is Dictionary):
			printerr("EXPORT_FORMAL_CAPABILITY_FACTS_FAILED: manifest entry must be dictionary")
			quit(1)
			return
		var entry: Dictionary = raw_entry
		var character_id := String(entry.get("character_id", "")).strip_edges()
		if character_id.is_empty():
			printerr("EXPORT_FORMAL_CAPABILITY_FACTS_FAILED: manifest entry missing character_id")
			quit(1)
			return
		var fact_sources_result := _collect_character_fact_sources_result(entry, collectors_result.get("data", []))
		if not bool(fact_sources_result.get("ok", false)):
			printerr("EXPORT_FORMAL_CAPABILITY_FACTS_FAILED: %s" % String(fact_sources_result.get("error_message", "fact collection failed")))
			quit(1)
			return
		var fact_sources: Dictionary = fact_sources_result.get("data", {})
		var sorted_facts: Array = fact_sources.keys()
		sorted_facts.sort()
		facts_by_character[character_id] = sorted_facts
		fact_sources_by_character[character_id] = _sorted_fact_sources_view(fact_sources)
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		printerr("EXPORT_FORMAL_CAPABILITY_FACTS_FAILED: cannot open output path: %s" % output_path)
		quit(1)
		return
	file.store_string(JSON.stringify({
		"facts_by_character": facts_by_character,
		"fact_sources_by_character": fact_sources_by_character,
	}, "  "))
	file.flush()
	file.close()
	quit(0)

func _load_collectors_result() -> Dictionary:
	var dir = DirAccess.open(COLLECTOR_DIR)
	if dir == null:
		return _error_result("missing collector directory: %s" % COLLECTOR_DIR)
	var collector_paths: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(COLLECTOR_SUFFIX):
			collector_paths.append("%s/%s" % [COLLECTOR_DIR, file_name])
		file_name = dir.get_next()
	dir.list_dir_end()
	collector_paths.sort()
	if collector_paths.is_empty():
		return _error_result("no collector scripts found under: %s" % COLLECTOR_DIR)
	var collectors: Array = []
	for collector_path in collector_paths:
		var collector_script = load(collector_path)
		if not (collector_script is Script) or not collector_script.can_instantiate():
			return _error_result("collector script is not instantiable: %s" % collector_path)
		var collector = collector_script.new()
		if collector == null or not collector.has_method("collect_resource_facts"):
			return _error_result("collector missing collect_resource_facts: %s" % collector_path)
		collectors.append(collector)
	return _ok_result(collectors)

func _collect_character_fact_sources_result(entry: Dictionary, collectors: Array) -> Dictionary:
	var fact_sources: Dictionary = {}
	for raw_rel_path in entry.get("required_content_paths", []):
		var rel_path := String(raw_rel_path).strip_edges()
		if rel_path.is_empty():
			continue
		var resolved_path := ResourcePathHelperScript.normalize(rel_path)
		var resource = ResourceLoader.load(resolved_path)
		if resource == null:
			return _error_result("missing resource %s" % resolved_path)
		for collector in collectors:
			collector.collect_resource_facts(fact_sources, rel_path, resource, Callable(self, "_register_fact"))
	return _ok_result(fact_sources)

func _register_fact(fact_sources: Dictionary, fact_id: String, rel_path: String) -> void:
	var normalized_fact_id := String(fact_id).strip_edges()
	var normalized_rel_path := String(rel_path).strip_edges()
	if normalized_fact_id.is_empty() or normalized_rel_path.is_empty():
		return
	var sources: Array = fact_sources.get(normalized_fact_id, [])
	if sources.has(normalized_rel_path):
		return
	sources.append(normalized_rel_path)
	fact_sources[normalized_fact_id] = sources

func _sorted_fact_sources_view(fact_sources: Dictionary) -> Dictionary:
	var view: Dictionary = {}
	var fact_ids := fact_sources.keys()
	fact_ids.sort()
	for raw_fact_id in fact_ids:
		var fact_id := String(raw_fact_id)
		var sources: Array = fact_sources.get(fact_id, []).duplicate()
		sources.sort()
		view[fact_id] = sources
	return view

func _ok_result(data) -> Dictionary:
	return {
		"ok": true,
		"data": data,
		"error_message": "",
	}

func _error_result(error_message: String) -> Dictionary:
	return {
		"ok": false,
		"data": null,
		"error_message": error_message,
	}
