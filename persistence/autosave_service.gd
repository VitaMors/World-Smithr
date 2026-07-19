extends Node
class_name AutosaveService

signal autosave_due

@export var settle_delay_seconds := 1.5

var _dirty := false
var _elapsed := 0.0


func initialize(_main: Node) -> void:
	set_process(false)


func mark_dirty() -> void:
	_dirty = true
	_elapsed = 0.0
	set_process(true)


func clear_dirty() -> void:
	_dirty = false
	_elapsed = 0.0
	set_process(false)


func _process(delta: float) -> void:
	if not _dirty:
		return

	_elapsed += delta
	if _elapsed >= settle_delay_seconds:
		autosave_due.emit()
		clear_dirty()
