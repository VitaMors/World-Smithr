extends Node
class_name CommandHistory

const DEFAULT_MEMORY_LIMIT_BYTES := 64 * 1024 * 1024

var memory_limit_bytes := DEFAULT_MEMORY_LIMIT_BYTES
var _undo_stack: Array[EditCommand] = []
var _redo_stack: Array[EditCommand] = []
var _estimated_bytes := 0


func initialize(_main: Node) -> void:
	clear()


func execute_command(command: EditCommand) -> void:
	command.execute()
	_undo_stack.append(command)
	_estimated_bytes += command.estimated_bytes()
	_redo_stack.clear()
	_trim_to_limit()


func can_undo() -> bool:
	return not _undo_stack.is_empty()


func can_redo() -> bool:
	return not _redo_stack.is_empty()


func undo() -> void:
	if _undo_stack.is_empty():
		return

	var command := _undo_stack.pop_back()
	command.undo()
	_redo_stack.append(command)


func redo() -> void:
	if _redo_stack.is_empty():
		return

	var command := _redo_stack.pop_back()
	command.execute()
	_undo_stack.append(command)


func estimated_bytes() -> int:
	return _estimated_bytes


func clear() -> void:
	_undo_stack.clear()
	_redo_stack.clear()
	_estimated_bytes = 0


func _trim_to_limit() -> void:
	while _estimated_bytes > memory_limit_bytes and not _undo_stack.is_empty():
		var command := _undo_stack.pop_front()
		_estimated_bytes -= command.estimated_bytes()
