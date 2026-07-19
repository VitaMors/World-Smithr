extends BaseTool
class_name SculptTool

enum SculptMode {
	RAISE,
	LOWER,
	SMOOTH,
	FLATTEN,
}

enum FalloffMode {
	HARD,
	LINEAR,
	SMOOTH,
}

const HEIGHT_DELTA_PER_STAMP_M := 0.75
const SMOOTH_BLEND_PER_STAMP := 0.45
const FLATTEN_BLEND_PER_STAMP := 0.55

var chunk_data: ChunkData
var world_chunk: WorldChunk
var mode := SculptMode.RAISE
var falloff_mode := FalloffMode.SMOOTH
var radius_m := 8.0
var strength_percent := 50.0

var _stroke_active := false
var _stroke_before: Dictionary = {}
var _flatten_height := 0.0


func _init() -> void:
	display_name = "Sculpt"


func configure(p_chunk_data: ChunkData, p_world_chunk: WorldChunk) -> void:
	chunk_data = p_chunk_data
	world_chunk = p_world_chunk


func set_mode_from_name(mode_name: String) -> void:
	match mode_name.to_lower():
		"raise":
			mode = SculptMode.RAISE
		"lower":
			mode = SculptMode.LOWER
		"smooth":
			mode = SculptMode.SMOOTH
		"flatten":
			mode = SculptMode.FLATTEN


func set_falloff_from_name(falloff_name: String) -> void:
	match falloff_name.to_lower():
		"hard":
			falloff_mode = FalloffMode.HARD
		"linear":
			falloff_mode = FalloffMode.LINEAR
		"smooth":
			falloff_mode = FalloffMode.SMOOTH


func begin_stroke(world_position: Vector3) -> void:
	_stroke_active = true
	_stroke_before.clear()
	_flatten_height = world_chunk.get_height_at_world(world_position)


func apply_at(world_position: Vector3, invert_raise_lower: bool) -> bool:
	if chunk_data == null or world_chunk == null:
		return false

	if not _stroke_active:
		begin_stroke(world_position)

	var local := world_chunk.to_local(world_position)
	var min_x := maxi(floori((local.x - radius_m) / ChunkCoordinates.CELL_SIZE_M), 0)
	var max_x := mini(ceili((local.x + radius_m) / ChunkCoordinates.CELL_SIZE_M), ChunkCoordinates.TERRAIN_CELLS)
	var min_z := maxi(floori((local.z - radius_m) / ChunkCoordinates.CELL_SIZE_M), 0)
	var max_z := mini(ceili((local.z + radius_m) / ChunkCoordinates.CELL_SIZE_M), ChunkCoordinates.TERRAIN_CELLS)
	var strength := clampf(strength_percent / 100.0, 0.0, 1.0)
	var changed := false

	for z in range(min_z, max_z + 1):
		for x in range(min_x, max_x + 1):
			var sample_xz := Vector2(float(x) * ChunkCoordinates.CELL_SIZE_M, float(z) * ChunkCoordinates.CELL_SIZE_M)
			var distance := sample_xz.distance_to(Vector2(local.x, local.z))
			if distance > radius_m:
				continue

			var weight := _falloff_weight(distance)
			if weight <= 0.0:
				continue

			var sample_index := ChunkData.index(x, z)
			var before := chunk_data.get_height(x, z)
			var after := _next_height(x, z, before, strength, weight, invert_raise_lower)
			if is_equal_approx(before, after):
				continue

			if not _stroke_before.has(sample_index):
				_stroke_before[sample_index] = before
			chunk_data.set_height(x, z, after)
			changed = true

	return changed


func end_stroke() -> TerrainStrokeCommand:
	if not _stroke_active:
		return null

	_stroke_active = false
	var keys := _stroke_before.keys()
	keys.sort()

	var changed_indices := PackedInt32Array()
	var before_heights := PackedFloat32Array()
	var after_heights := PackedFloat32Array()
	for key in keys:
		var sample_index := int(key)
		var before := float(_stroke_before[key])
		var after := chunk_data.get_height_by_index(sample_index)
		if is_equal_approx(before, after):
			continue
		changed_indices.append(sample_index)
		before_heights.append(before)
		after_heights.append(after)

	_stroke_before.clear()
	if changed_indices.is_empty():
		return null

	return TerrainStrokeCommand.new(chunk_data, world_chunk, changed_indices, before_heights, after_heights)


func cancel_stroke() -> void:
	_stroke_active = false
	_stroke_before.clear()


func _next_height(sample_x: int, sample_z: int, before: float, strength: float, weight: float, invert_raise_lower: bool) -> float:
	match mode:
		SculptMode.RAISE, SculptMode.LOWER:
			var direction := 1.0 if mode == SculptMode.RAISE else -1.0
			if invert_raise_lower:
				direction *= -1.0
			return before + direction * HEIGHT_DELTA_PER_STAMP_M * strength * weight
		SculptMode.SMOOTH:
			var average := chunk_data.get_average_height(sample_x, sample_z)
			return lerpf(before, average, SMOOTH_BLEND_PER_STAMP * strength * weight)
		SculptMode.FLATTEN:
			return lerpf(before, _flatten_height, FLATTEN_BLEND_PER_STAMP * strength * weight)

	return before


func _falloff_weight(distance: float) -> float:
	var normalised := clampf(distance / radius_m, 0.0, 1.0)
	var remaining := 1.0 - normalised
	match falloff_mode:
		FalloffMode.HARD:
			return 1.0
		FalloffMode.LINEAR:
			return remaining
		FalloffMode.SMOOTH:
			return remaining * remaining * (3.0 - 2.0 * remaining)

	return remaining
