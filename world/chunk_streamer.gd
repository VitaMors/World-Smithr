extends Node
class_name ChunkStreamer

signal focus_chunk_changed(coord: Vector2i)
signal chunk_sets_changed(diff: Dictionary)

enum ChunkState {
	ACTIVE,
	WARM,
	UNLOADED,
}

var focus_chunk := Vector2i.ZERO
var active_chunks: Array[Vector2i] = []
var warm_chunks: Array[Vector2i] = []
var loaded_chunks: Array[Vector2i] = []

var _active_keys: Dictionary = {}
var _warm_keys: Dictionary = {}
var _loaded_keys: Dictionary = {}
var _initialized := false


func initialize(_main: Node) -> void:
	set_focus_chunk(Vector2i.ZERO, true)


func set_focus_chunk(coord: Vector2i, force: bool = false) -> Dictionary:
	if not force and _initialized and focus_chunk == coord:
		return _empty_diff()

	var old_active := _active_keys.duplicate()
	var old_warm := _warm_keys.duplicate()
	var old_loaded := _loaded_keys.duplicate()

	focus_chunk = coord
	active_chunks = _coords_within_radius(1)
	warm_chunks = _coords_at_exact_radius(2)
	loaded_chunks = _coords_within_radius(2)
	_active_keys = _keys_from_coords(active_chunks)
	_warm_keys = _keys_from_coords(warm_chunks)
	_loaded_keys = _keys_from_coords(loaded_chunks)
	_initialized = true

	var diff := {
		"focus_chunk": focus_chunk,
		"entered_active": _coords_added(_active_keys, old_active),
		"exited_active": _coords_removed(_active_keys, old_active),
		"entered_warm": _coords_added(_warm_keys, old_warm),
		"exited_warm": _coords_removed(_warm_keys, old_warm),
		"entered_loaded": _coords_added(_loaded_keys, old_loaded),
		"exited_loaded": _coords_removed(_loaded_keys, old_loaded),
	}

	focus_chunk_changed.emit(focus_chunk)
	chunk_sets_changed.emit(diff)
	return diff


func get_state_for_chunk(coord: Vector2i) -> int:
	var distance := ChunkCoordinates.chebyshev_distance(coord, focus_chunk)
	if distance <= 1:
		return ChunkState.ACTIVE
	if distance == 2:
		return ChunkState.WARM
	return ChunkState.UNLOADED


func is_loaded(coord: Vector2i) -> bool:
	return _loaded_keys.has(ChunkCoordinates.chunk_to_key(coord))


func is_active(coord: Vector2i) -> bool:
	return _active_keys.has(ChunkCoordinates.chunk_to_key(coord))


func get_active_count() -> int:
	return active_chunks.size()


func get_warm_count() -> int:
	return warm_chunks.size()


func get_loaded_count() -> int:
	return loaded_chunks.size()


func _coords_within_radius(radius: int) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for z in range(focus_chunk.y - radius, focus_chunk.y + radius + 1):
		for x in range(focus_chunk.x - radius, focus_chunk.x + radius + 1):
			coords.append(Vector2i(x, z))
	return coords


func _coords_at_exact_radius(radius: int) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for z in range(focus_chunk.y - radius, focus_chunk.y + radius + 1):
		for x in range(focus_chunk.x - radius, focus_chunk.x + radius + 1):
			var coord := Vector2i(x, z)
			if ChunkCoordinates.chebyshev_distance(coord, focus_chunk) == radius:
				coords.append(coord)
	return coords


func _keys_from_coords(coords: Array[Vector2i]) -> Dictionary:
	var keys := {}
	for coord in coords:
		keys[ChunkCoordinates.chunk_to_key(coord)] = coord
	return keys


func _coords_added(new_keys: Dictionary, old_keys: Dictionary) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for key in new_keys.keys():
		if not old_keys.has(key):
			coords.append(new_keys[key])
	return coords


func _coords_removed(new_keys: Dictionary, old_keys: Dictionary) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for key in old_keys.keys():
		if not new_keys.has(key):
			coords.append(old_keys[key])
	return coords


func _empty_diff() -> Dictionary:
	return {
		"focus_chunk": focus_chunk,
		"entered_active": [],
		"exited_active": [],
		"entered_warm": [],
		"exited_warm": [],
		"entered_loaded": [],
		"exited_loaded": [],
	}
