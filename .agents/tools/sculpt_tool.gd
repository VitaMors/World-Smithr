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

var world_document: WorldDocument
var chunks_by_key: Dictionary = {}
var mode := SculptMode.RAISE
var falloff_mode := FalloffMode.SMOOTH
var radius_m := 8.0
var strength_percent := 50.0

var _stroke_active := false
var _stroke_before: Dictionary = {}
var _affected_chunk_keys: Dictionary = {}
var _flatten_height := 0.0


func _init() -> void:
	display_name = "Sculpt"


func configure(p_world_document: WorldDocument, p_chunks_by_key: Dictionary) -> void:
	world_document = p_world_document
	chunks_by_key = p_chunks_by_key


func set_chunks(p_chunks_by_key: Dictionary) -> void:
	chunks_by_key = p_chunks_by_key


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
	_affected_chunk_keys.clear()
	_flatten_height = world_document.get_height_at_world(world_position)


func apply_at(world_position: Vector3, invert_raise_lower: bool) -> bool:
	if world_document == null:
		return false

	if not _stroke_active:
		begin_stroke(world_position)

	var min_x := floori((world_position.x - radius_m) / ChunkCoordinates.CELL_SIZE_M)
	var max_x := ceili((world_position.x + radius_m) / ChunkCoordinates.CELL_SIZE_M)
	var min_z := floori((world_position.z - radius_m) / ChunkCoordinates.CELL_SIZE_M)
	var max_z := ceili((world_position.z + radius_m) / ChunkCoordinates.CELL_SIZE_M)
	var strength := clampf(strength_percent / 100.0, 0.0, 1.0)
	var brush_xz := Vector2(world_position.x, world_position.z)
	var changed := false

	for z in range(min_z, max_z + 1):
		for x in range(min_x, max_x + 1):
			var sample_position := Vector2(float(x) * ChunkCoordinates.CELL_SIZE_M, float(z) * ChunkCoordinates.CELL_SIZE_M)
			var distance := sample_position.distance_to(brush_xz)
			if distance > radius_m:
				continue

			var weight := _falloff_weight(distance)
			if weight <= 0.0:
				continue

			var global_sample := Vector2i(x, z)
			var sample_key := ChunkCoordinates.sample_to_key(global_sample)
			var before := world_document.get_height_at_global_sample(global_sample)
			var after := _next_height(global_sample, before, strength, weight, invert_raise_lower)
			if is_equal_approx(before, after):
				continue

			if not _stroke_before.has(sample_key):
				_stroke_before[sample_key] = before
			world_document.set_height_at_global_sample(global_sample, after)
			_track_affected_chunks(global_sample)
			changed = true

	return changed


func end_stroke() -> TerrainStrokeCommand:
	if not _stroke_active:
		return null

	_stroke_active = false
	var keys := _stroke_before.keys()
	keys.sort()

	var sample_keys := PackedStringArray()
	var before_heights := PackedFloat32Array()
	var after_heights := PackedFloat32Array()
	for key in keys:
		var sample_key := str(key)
		var before := float(_stroke_before[sample_key])
		var after := world_document.get_height_at_sample_key(sample_key)
		if is_equal_approx(before, after):
			continue
		sample_keys.append(sample_key)
		before_heights.append(before)
		after_heights.append(after)

	var affected_keys := PackedStringArray()
	var chunk_keys := _affected_chunk_keys.keys()
	chunk_keys.sort()
	for chunk_key in chunk_keys:
		affected_keys.append(str(chunk_key))

	_stroke_before.clear()
	_affected_chunk_keys.clear()
	if sample_keys.size() == 0:
		return null

	return TerrainStrokeCommand.new(world_document, chunks_by_key, sample_keys, affected_keys, before_heights, after_heights)


func cancel_stroke() -> void:
	_stroke_active = false
	_stroke_before.clear()
	_affected_chunk_keys.clear()


func get_current_affected_coords() -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for chunk_key in _affected_chunk_keys.keys():
		coords.append(ChunkCoordinates.key_to_chunk(str(chunk_key)))
	return coords


func _next_height(global_sample: Vector2i, before: float, strength: float, weight: float, invert_raise_lower: bool) -> float:
	match mode:
		SculptMode.RAISE, SculptMode.LOWER:
			var direction := 1.0 if mode == SculptMode.RAISE else -1.0
			if invert_raise_lower:
				direction *= -1.0
			return before + direction * HEIGHT_DELTA_PER_STAMP_M * strength * weight
		SculptMode.SMOOTH:
			var average := world_document.get_average_height_at_global_sample(global_sample)
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


func _track_affected_chunks(global_sample: Vector2i) -> void:
	for coord in ChunkCoordinates.chunks_for_global_sample(global_sample):
		var chunk_key := ChunkCoordinates.chunk_to_key(coord)
		if chunks_by_key.has(chunk_key):
			_affected_chunk_keys[chunk_key] = true



