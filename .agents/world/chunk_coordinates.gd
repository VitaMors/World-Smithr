extends RefCounted
class_name ChunkCoordinates

const CHUNK_SIZE_M := 64.0
const TERRAIN_CELLS := 32
const HEIGHT_SAMPLES := TERRAIN_CELLS + 1
const CELL_SIZE_M := CHUNK_SIZE_M / float(TERRAIN_CELLS)


static func world_to_chunk(position: Vector3) -> Vector2i:
	return Vector2i(
		floori(position.x / CHUNK_SIZE_M),
		floori(position.z / CHUNK_SIZE_M)
	)


static func chunk_to_world_origin(coord: Vector2i) -> Vector3:
	return Vector3(coord.x * CHUNK_SIZE_M, 0.0, coord.y * CHUNK_SIZE_M)


static func chunk_to_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]


static func key_to_chunk(key: String) -> Vector2i:
	var parts := key.split(",", false)
	if parts.size() != 2:
		push_error("Invalid chunk key: %s" % key)
		return Vector2i.ZERO

	return Vector2i(int(parts[0]), int(parts[1]))


static func sample_to_key(global_sample: Vector2i) -> String:
	return "%d,%d" % [global_sample.x, global_sample.y]


static func key_to_sample(key: String) -> Vector2i:
	var parts := key.split(",", false)
	if parts.size() != 2:
		push_error("Invalid sample key: %s" % key)
		return Vector2i.ZERO

	return Vector2i(int(parts[0]), int(parts[1]))


static func chunk_sample_to_global(coord: Vector2i, sample_x: int, sample_z: int) -> Vector2i:
	return Vector2i(
		coord.x * TERRAIN_CELLS + sample_x,
		coord.y * TERRAIN_CELLS + sample_z
	)


static func global_sample_to_chunk_sample(global_sample: Vector2i, coord: Vector2i) -> Vector2i:
	return Vector2i(
		global_sample.x - coord.x * TERRAIN_CELLS,
		global_sample.y - coord.y * TERRAIN_CELLS
	)


static func world_to_global_sample(position: Vector3) -> Vector2i:
	return Vector2i(
		roundi(position.x / CELL_SIZE_M),
		roundi(position.z / CELL_SIZE_M)
	)


static func chunks_for_global_sample(global_sample: Vector2i) -> Array[Vector2i]:
	var chunk_x := floori(float(global_sample.x) / float(TERRAIN_CELLS))
	var chunk_z := floori(float(global_sample.y) / float(TERRAIN_CELLS))
	var x_coords: Array[int] = [chunk_x]
	var z_coords: Array[int] = [chunk_z]
	if posmod(global_sample.x, TERRAIN_CELLS) == 0:
		x_coords.append(chunk_x - 1)
	if posmod(global_sample.y, TERRAIN_CELLS) == 0:
		z_coords.append(chunk_z - 1)

	var coords: Array[Vector2i] = []
	for z in z_coords:
		for x in x_coords:
			coords.append(Vector2i(x, z))
	return coords


static func chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))
