extends Node3D
class_name WorldChunk

enum RuntimeState {
	ACTIVE,
	WARM,
	UNLOADED,
}

@export var coord := Vector2i.ZERO

var runtime_state := RuntimeState.UNLOADED


func set_runtime_state(value: RuntimeState) -> void:
	runtime_state = value
	visible = runtime_state != RuntimeState.UNLOADED
