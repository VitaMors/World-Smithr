extends Node
class_name ChunkStreamer

signal focus_chunk_changed(coord: Vector2i)

enum ChunkState {
	ACTIVE,
	WARM,
	UNLOADED,
}

var focus_chunk := Vector2i.ZERO
var active_chunks: Array[Vector2i] = []
var warm_chunks: Array[Vector2i] = []


func initialize(_main: Node) -> void:
	set_focus_chunk(Vector2i.ZERO)


func set_focus_chunk(coord: Vector2i) -> void:
	if focus_chunk == coord and not active_chunks.is_empty():
		return

	focus_chunk = coord
	active_chunks = _coords_at_distance(1, true)
	warm_chunks = _coords_at_distance(2, false)
	focus_chunk_changed.emit(focus_chunk)


func get_state_for_chunk(coord: Vector2i) -> ChunkState:
	var distance := ChunkCoordinates.chebyshev_distance(coord, focus_chunk)
	if distance <= 1:
		return ChunkState.ACTIVE
	if distance == 2:
		return ChunkState.WARM
	return ChunkState.UNLOADED


func _coords_at_distance(radius: int, include_inner: bool) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for z in range(focus_chunk.y - radius, focus_chunk.y + radius + 1):
		for x in range(focus_chunk.x - radius, focus_chunk.x + radius + 1):
			var coord := Vector2i(x, z)
			var distance := ChunkCoordinates.chebyshev_distance(coord, focus_chunk)
			if distance == radius or (include_inner and distance < radius):
				coords.append(coord)
	return coords
