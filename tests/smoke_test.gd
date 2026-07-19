extends SceneTree

const ChunkCoordinatesScript := preload("res://world/chunk_coordinates.gd")
const ChunkDataScript := preload("res://world/chunk_data.gd")
const WorldDocumentScript := preload("res://world/world_document.gd")
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
	_expect_equal(ChunkCoordinatesScript.chunk_sample_to_global(Vector2i(0, 0), 32, 10), Vector2i(32, 10), errors, "east border global sample")
	_expect_equal(ChunkCoordinatesScript.chunk_sample_to_global(Vector2i(1, 0), 0, 10), Vector2i(32, 10), errors, "west border global sample")
	_expect_equal(ChunkCoordinatesScript.chunks_for_global_sample(Vector2i(32, 32)).size(), 4, errors, "four chunk corner ownership")

	var chunk_data := ChunkDataScript.new(Vector2i.ZERO)
	_expect_equal(chunk_data.heights.size(), ChunkDataScript.sample_count(), errors, "height sample count")
	chunk_data.set_height(0, 0, 250.0)
	_expect_equal(chunk_data.get_height(0, 0), ChunkDataScript.MAX_HEIGHT_M, errors, "height max clamp")
	chunk_data.set_height(0, 0, -80.0)
	_expect_equal(chunk_data.get_height(0, 0), ChunkDataScript.MIN_HEIGHT_M, errors, "height min clamp")
	chunk_data.reset_flat(4.0)
	_expect_equal(chunk_data.get_height_at_local(Vector3(1.0, 0.0, 1.0)), 4.0, errors, "flat bilinear height")

	var world_document := WorldDocumentScript.new()
	var west_chunk := world_document.get_chunk_data(Vector2i(0, 0))
	var east_chunk := world_document.get_chunk_data(Vector2i(1, 0))
	west_chunk.set_height(32, 10, 7.5)
	_expect_equal(east_chunk.get_height(0, 10), 7.5, errors, "shared east west border")
	west_chunk.set_height(32, 32, 9.0)
	_expect_equal(world_document.get_chunk_data(Vector2i(1, 1)).get_height(0, 0), 9.0, errors, "shared four chunk corner")

	var mesher := TerrainMesherScript.new()
	mesher.initialize(null)
	var mesh := mesher.build_mesh(west_chunk)
	_expect_equal(mesh.get_surface_count(), 1, errors, "terrain mesh surface count")
	mesher.queue_rebuild(Vector2i.ZERO)
	mesher.queue_rebuild(Vector2i.ZERO)
	_expect_equal(mesher.pending_rebuild_count(), 1, errors, "rebuild queue dedupe")
	_expect_equal(mesher.take_next_rebuild(), Vector2i.ZERO, errors, "rebuild queue pop")
	_expect_equal(mesher.take_next_rebuild(), TerrainMesherScript.INVALID_REBUILD_COORD, errors, "empty rebuild queue sentinel")
	mesher.free()

	var streamer := ChunkStreamerScript.new()
	var initial_diff := streamer.set_focus_chunk(Vector2i.ZERO, true)
	_expect_equal(streamer.active_chunks.size(), 9, errors, "active chunk count")
	_expect_equal(streamer.warm_chunks.size(), 16, errors, "warm ring count")
	_expect_equal(streamer.loaded_chunks.size(), 25, errors, "loaded chunk count")
	_expect_equal(initial_diff["entered_loaded"].size(), 25, errors, "initial loaded diff count")
	_expect_equal(streamer.get_state_for_chunk(Vector2i(2, 0)), ChunkStreamerScript.ChunkState.WARM, errors, "warm chunk state")
	_expect_equal(streamer.get_state_for_chunk(Vector2i(3, 0)), ChunkStreamerScript.ChunkState.UNLOADED, errors, "unloaded chunk state")

	var cardinal_diff := streamer.set_focus_chunk(Vector2i(1, 0))
	_expect_equal(cardinal_diff["entered_loaded"].size(), 5, errors, "cardinal entered loaded count")
	_expect_equal(cardinal_diff["exited_loaded"].size(), 5, errors, "cardinal exited loaded count")
	_expect_equal(cardinal_diff["entered_active"].size(), 3, errors, "cardinal entered active count")
	_expect_equal(cardinal_diff["exited_active"].size(), 3, errors, "cardinal exited active count")

	streamer.set_focus_chunk(Vector2i.ZERO, true)
	var diagonal_diff := streamer.set_focus_chunk(Vector2i(-1, -1))
	_expect_equal(diagonal_diff["entered_loaded"].size(), 9, errors, "diagonal entered loaded count")
	_expect_equal(diagonal_diff["exited_loaded"].size(), 9, errors, "diagonal exited loaded count")
	_expect_equal(diagonal_diff["entered_active"].size(), 5, errors, "diagonal entered active count")
	_expect_equal(diagonal_diff["exited_active"].size(), 5, errors, "diagonal exited active count")
	_expect_equal(streamer.is_active(Vector2i(-2, -2)), true, errors, "negative active chunk")
	_expect_equal(streamer.get_state_for_chunk(Vector2i(-3, -3)), ChunkStreamerScript.ChunkState.WARM, errors, "negative warm chunk")
	_expect_equal(streamer.get_state_for_chunk(Vector2i(-4, -1)), ChunkStreamerScript.ChunkState.UNLOADED, errors, "negative unloaded chunk")
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
