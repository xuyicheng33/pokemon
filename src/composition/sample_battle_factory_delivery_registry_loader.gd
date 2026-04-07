extends RefCounted
class_name SampleBattleFactoryDeliveryRegistryLoader

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const FormalCharacterManifestScript := preload("res://src/shared/formal_character_manifest.gd")

var registry_path_override: String = ""
var _manifest = FormalCharacterManifestScript.new()

func load_entries_result() -> Dictionary:
	_manifest.manifest_path_override = registry_path_override
	var entries_result := _manifest.build_delivery_entries_result()
	if bool(entries_result.get("ok", false)):
		return _ok_result(entries_result.get("data", []))
	return _error_result(
		ErrorCodesScript.INVALID_BATTLE_SETUP,
		String(entries_result.get("error_message", "unknown manifest error"))
	)

func _ok_result(data) -> Dictionary:
	return {
		"ok": true,
		"data": data,
		"error_code": null,
		"error_message": null,
	}

func _error_result(error_code: String, error_message: String) -> Dictionary:
	return {
		"ok": false,
		"data": null,
		"error_code": error_code,
		"error_message": error_message,
	}
