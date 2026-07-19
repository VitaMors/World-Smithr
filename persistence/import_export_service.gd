extends Node
class_name ImportExportService

const PACKAGE_EXTENSION := "worldsmithr.zip"
const PACKAGE_MIME_TYPE := "application/zip"


func initialize(_main: Node) -> void:
	pass


func get_export_extension() -> String:
	return PACKAGE_EXTENSION
