extends Node
class_name SelectionService

signal selection_changed(selection_count: int)

var selected_ids: Array[String] = []


func initialize(_main: Node) -> void:
	clear_selection()


func set_selection(ids: Array[String]) -> void:
	selected_ids = ids.duplicate()
	selection_changed.emit(selected_ids.size())


func clear_selection() -> void:
	selected_ids.clear()
	selection_changed.emit(0)
