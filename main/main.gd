extends Node
class_name Main

const PRODUCT_NAME := "World Smithr"

@onready var _editor_shell: EditorShell = $UI/EditorShell
@onready var _services: Node = $Services


func _ready() -> void:
	DisplayServer.window_set_title(PRODUCT_NAME)
	_initialize_services()
	_editor_shell.set_status("Phase 0 shell ready", Vector2i.ZERO, "Idle", 0)


func _initialize_services() -> void:
	for child: Node in _services.get_children():
		if child.has_method("initialize"):
			child.call("initialize", self)
