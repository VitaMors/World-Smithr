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


static func chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))
