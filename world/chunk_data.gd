extends RefCounted
class_name ChunkData

const MIN_HEIGHT_M := -32.0
const MAX_HEIGHT_M := 96.0

var coord := Vector2i.ZERO
var revision := 0
var dirty := false
var heights := PackedFloat32Array()


func _init(p_coord := Vector2i.ZERO) -> void:
	coord = p_coord
	heights.resize(sample_count())
	reset_flat(0.0)


static func sample_count() -> int:
	return ChunkCoordinates.HEIGHT_SAMPLES * ChunkCoordinates.HEIGHT_SAMPLES


static func index(sample_x: int, sample_z: int) -> int:
	return sample_z * ChunkCoordinates.HEIGHT_SAMPLES + sample_x


static func sample_x_from_index(sample_index: int) -> int:
	return sample_index % ChunkCoordinates.HEIGHT_SAMPLES


static func sample_z_from_index(sample_index: int) -> int:
	return floori(float(sample_index) / float(ChunkCoordinates.HEIGHT_SAMPLES))


func reset_flat(height_m: float) -> void:
	var clamped_height := clampf(height_m, MIN_HEIGHT_M, MAX_HEIGHT_M)
	for i in range(heights.size()):
		heights[i] = clamped_height
	mark_dirty()


func get_height(sample_x: int, sample_z: int) -> float:
	return heights[index(sample_x, sample_z)]


func set_height(sample_x: int, sample_z: int, height_m: float) -> void:
	heights[index(sample_x, sample_z)] = clampf(height_m, MIN_HEIGHT_M, MAX_HEIGHT_M)
	mark_dirty()


func get_height_by_index(sample_index: int) -> float:
	return heights[sample_index]


func set_height_by_index(sample_index: int, height_m: float) -> void:
	heights[sample_index] = clampf(height_m, MIN_HEIGHT_M, MAX_HEIGHT_M)
	mark_dirty()


func duplicate_heights() -> PackedFloat32Array:
	return heights.duplicate()


func get_height_at_local(local_position: Vector3) -> float:
	var sample_x := clampf(local_position.x / ChunkCoordinates.CELL_SIZE_M, 0.0, float(ChunkCoordinates.TERRAIN_CELLS))
	var sample_z := clampf(local_position.z / ChunkCoordinates.CELL_SIZE_M, 0.0, float(ChunkCoordinates.TERRAIN_CELLS))
	var x0 := floori(sample_x)
	var z0 := floori(sample_z)
	var x1 := mini(x0 + 1, ChunkCoordinates.TERRAIN_CELLS)
	var z1 := mini(z0 + 1, ChunkCoordinates.TERRAIN_CELLS)
	var tx := sample_x - float(x0)
	var tz := sample_z - float(z0)

	var h00 := get_height(x0, z0)
	var h10 := get_height(x1, z0)
	var h01 := get_height(x0, z1)
	var h11 := get_height(x1, z1)
	var north := lerpf(h00, h10, tx)
	var south := lerpf(h01, h11, tx)
	return lerpf(north, south, tz)


func get_average_height(sample_x: int, sample_z: int) -> float:
	var total := 0.0
	var count := 0
	for z in range(maxi(sample_z - 1, 0), mini(sample_z + 2, ChunkCoordinates.HEIGHT_SAMPLES)):
		for x in range(maxi(sample_x - 1, 0), mini(sample_x + 2, ChunkCoordinates.HEIGHT_SAMPLES)):
			total += get_height(x, z)
			count += 1

	if count == 0:
		return get_height(sample_x, sample_z)
	return total / float(count)


func mark_dirty() -> void:
	dirty = true
	revision += 1


func clear_dirty() -> void:
	dirty = false

