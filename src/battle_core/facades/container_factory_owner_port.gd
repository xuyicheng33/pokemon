extends RefCounted
class_name ContainerFactoryOwnerPort

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

func error_state() -> Dictionary:
	return {
		"code": ErrorCodesScript.INVALID_COMPOSITION,
		"message": "ContainerFactoryOwnerPort missing error_state implementation",
	}
