extends SceneTree

const ChunkCoordinatesScript := preload("res://world/chunk_coordinates.gd")
const ChunkDataScript := preload("res://world/chunk_data.gd")
const ChunkStreamerScript := preload("res://world/chunk_streamer.gd")
const TerrainMesherScript := preload("res://world/terrain_mesher.gd")


func _init() -> void:
	var errors: Array[String] = []

	_expect_equal(ChunkCoordinatesScript.world_to_chunk(Vector3.ZERO), Vector2i.ZERO, errors, "origin chunk")
	_expect_equal(ChunkCoordinatesScript.world_to_chunk(Vector3(63.99, 0.0, 63.99)), Vector2i.ZERO, errors, "positive inner border")
	_expect_equal(ChunkCoordinatesScript.world_to_chunk(Vector3(64.0, 0.0, 64.0)), Vector2i(1, 1), errors, "positive exact border")
	_expect_equal(ChunkCoordinatesScript.world_to_chunk(Vector3(-0.01, 0.0, -0.01)), Vector2i(-1, -1), errors, "negative inner border")
	_expect_equal(ChunkCoordinatesScript.chunk_to_key(Vector2i(-2, 5)), "-2,5", errors, "chunk key")
	_expect_equal(ChunkCoordinatesScript.key_to_chunk("-2,5"), Vector2i(-2, 5), errors, "chunk key parse")

	var chunk_data := ChunkDataScript.new(Vector2i.ZERO)
	_expect_equal(chunk_data.heights.size(), ChunkDataScript.sample_count(), errors, "height sample count")
	chunk_data.set_height(0, 0, 250.0)
	_expect_equal(chunk_data.get_height(0, 0), ChunkDataScript.MAX_HEIGHT_M, errors, "height max clamp")
	chunk_data.set_height(0, 0, -80.0)
	_expect_equal(chunk_data.get_height(0, 0), ChunkDataScript.MIN_HEIGHT_M, errors, "height min clamp")
	chunk_data.reset_flat(4.0)
	_expect_equal(chunk_data.get_height_at_local(Vector3(1.0, 0.0, 1.0)), 4.0, errors, "flat bilinear height")

	var mesher := TerrainMesherScript.new()
	mesher.initialize(null)
	var mesh := mesher.build_mesh(chunk_data)
	_expect_equal(mesh.get_surface_count(), 1, errors, "terrain mesh surface count")
	mesher.free()

	var streamer := ChunkStreamerScript.new()
	streamer.set_focus_chunk(Vector2i.ZERO)
	_expect_equal(streamer.active_chunks.size(), 9, errors, "active chunk count")
	_expect_equal(streamer.warm_chunks.size(), 16, errors, "warm ring count")
	_expect_equal(streamer.get_state_for_chunk(Vector2i(2, 0)), ChunkStreamerScript.ChunkState.WARM, errors, "warm chunk state")
	_expect_equal(streamer.get_state_for_chunk(Vector2i(3, 0)), ChunkStreamerScript.ChunkState.UNLOADED, errors, "unloaded chunk state")
	streamer.free()

	if errors.is_empty():
		print("World Smithr smoke test passed.")
		quit(0)
	else:
		for error in errors:
			printerr(error)
		quit(1)


func _expect_equal(actual: Variant, expected: Variant, errors: Array[String], label: String) -> void:
	if actual != expected:
		errors.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
