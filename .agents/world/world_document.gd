extends RefCounted
class_name WorldDocument

const DEFAULT_HEIGHT_M := 0.0

var id := "local_dev_world"
var name := "Untitled World"
var _height_samples: Dictionary = {}
var _chunks: Dictionary = {}


func get_chunk_data(coord: Vector2i) -> ChunkData:
	var key := ChunkCoordinates.chunk_to_key(coord)
	if not _chunks.has(key):
		_chunks[key] = ChunkData.new(coord, self)
	return _chunks[key]


func get_height_at_global_sample(global_sample: Vector2i) -> float:
	var key := ChunkCoordinates.sample_to_key(global_sample)
	if not _height_samples.has(key):
		return DEFAULT_HEIGHT_M
	return float(_height_samples[key])


func set_height_at_global_sample(global_sample: Vector2i, height_m: float) -> void:
	var key := ChunkCoordinates.sample_to_key(global_sample)
	_height_samples[key] = clampf(height_m, ChunkData.MIN_HEIGHT_M, ChunkData.MAX_HEIGHT_M)


func get_height_at_sample_key(sample_key: String) -> float:
	return get_height_at_global_sample(ChunkCoordinates.key_to_sample(sample_key))


func set_height_at_sample_key(sample_key: String, height_m: float) -> void:
	set_height_at_global_sample(ChunkCoordinates.key_to_sample(sample_key), height_m)


func serialize_height_samples() -> Dictionary:
	return _height_samples.duplicate(true)


func load_height_samples(serialized_samples: Dictionary) -> void:
	_height_samples.clear()
	_chunks.clear()
	for key in serialized_samples.keys():
		_height_samples[str(key)] = clampf(float(serialized_samples[key]), ChunkData.MIN_HEIGHT_M, ChunkData.MAX_HEIGHT_M)


func get_height_at_world(world_position: Vector3) -> float:
	var sample_x := world_position.x / ChunkCoordinates.CELL_SIZE_M
	var sample_z := world_position.z / ChunkCoordinates.CELL_SIZE_M
	var x0 := floori(sample_x)
	var z0 := floori(sample_z)
	var x1 := x0 + 1
	var z1 := z0 + 1
	var tx := sample_x - float(x0)
	var tz := sample_z - float(z0)

	var h00 := get_height_at_global_sample(Vector2i(x0, z0))
	var h10 := get_height_at_global_sample(Vector2i(x1, z0))
	var h01 := get_height_at_global_sample(Vector2i(x0, z1))
	var h11 := get_height_at_global_sample(Vector2i(x1, z1))
	var north := lerpf(h00, h10, tx)
	var south := lerpf(h01, h11, tx)
	return lerpf(north, south, tz)


func get_average_height_at_global_sample(global_sample: Vector2i) -> float:
	var total := 0.0
	var count := 0
	for z in range(global_sample.y - 1, global_sample.y + 2):
		for x in range(global_sample.x - 1, global_sample.x + 2):
			total += get_height_at_global_sample(Vector2i(x, z))
			count += 1
	return total / float(count)


func changed_chunk_keys_for_sample(global_sample: Vector2i) -> PackedStringArray:
	var keys := PackedStringArray()
	for coord in ChunkCoordinates.chunks_for_global_sample(global_sample):
		keys.append(ChunkCoordinates.chunk_to_key(coord))
	return keys
