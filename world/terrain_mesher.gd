extends Node
class_name TerrainMesher

var pending_rebuilds: Array[Vector2i] = []


func initialize(_main: Node) -> void:
	pending_rebuilds.clear()


func queue_rebuild(coord: Vector2i) -> void:
	if not pending_rebuilds.has(coord):
		pending_rebuilds.append(coord)


func take_next_rebuild() -> Vector2i:
	if pending_rebuilds.is_empty():
		return Vector2i(2147483647, 2147483647)

	return pending_rebuilds.pop_front()
