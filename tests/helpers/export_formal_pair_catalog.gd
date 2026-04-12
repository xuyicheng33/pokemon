extends SceneTree

const FormalCharacterManifestScript := preload("res://src/shared/formal_character_manifest.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("EXPORT_FORMAL_PAIR_CATALOG_FAILED: missing output path")
		quit(1)
		return
	var output_path := String(args[0]).strip_edges()
	if output_path.is_empty():
		printerr("EXPORT_FORMAL_PAIR_CATALOG_FAILED: empty output path")
		quit(1)
		return
	var manifest_path := ""
	if args.size() >= 2:
		manifest_path = String(args[1]).strip_edges()
	var manifest = FormalCharacterManifestScript.new()
	if manifest == null:
		printerr("EXPORT_FORMAL_PAIR_CATALOG_FAILED: missing manifest helper")
		quit(1)
		return
	if not manifest_path.is_empty():
		manifest.manifest_path_override = manifest_path
	var catalog_result: Dictionary = manifest.build_catalog_result()
	if not bool(catalog_result.get("ok", false)):
		printerr(
			"EXPORT_FORMAL_PAIR_CATALOG_FAILED: %s" % String(catalog_result.get("error_message", "unknown error"))
		)
		quit(1)
		return
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		printerr("EXPORT_FORMAL_PAIR_CATALOG_FAILED: cannot open output path: %s" % output_path)
		quit(1)
		return
	file.store_string(JSON.stringify(catalog_result.get("data", {}), "  "))
	file.flush()
	file.close()
	quit(0)
