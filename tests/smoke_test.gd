extends SceneTree

const ChunkCoordinatesScript := preload("res://world/chunk_coordinates.gd")
const ChunkStreamerScript := preload("res://world/chunk_streamer.gd")


func _init() -> void:
	var errors: Array[String] = []

	_expect_equal(ChunkCoordinatesScript.world_to_chunk(Vector3.ZERO), Vector2i.ZERO, errors, "origin chunk")
	_expect_equal(ChunkCoordinatesScript.world_to_chunk(Vector3(63.99, 0.0, 63.99)), Vector2i.ZERO, errors, "positive inner border")
	_expect_equal(ChunkCoordinatesScript.world_to_chunk(Vector3(64.0, 0.0, 64.0)), Vector2i(1, 1), errors, "positive exact border")
	_expect_equal(ChunkCoordinatesScript.world_to_chunk(Vector3(-0.01, 0.0, -0.01)), Vector2i(-1, -1), errors, "negative inner border")
	_expect_equal(ChunkCoordinatesScript.chunk_to_key(Vector2i(-2, 5)), "-2,5", errors, "chunk key")
	_expect_equal(ChunkCoordinatesScript.key_to_chunk("-2,5"), Vector2i(-2, 5), errors, "chunk key parse")

	var streamer := ChunkStreamerScript.new()
	streamer.set_focus_chunk(Vector2i.ZERO)
	_expect_equal(streamer.active_chunks.size(), 9, errors, "active chunk count")
	_expect_equal(streamer.warm_chunks.size(), 16, errors, "warm ring count")
	_expect_equal(streamer.get_state_for_chunk(Vector2i(2, 0)), streamer.ChunkState.WARM, errors, "warm chunk state")
	_expect_equal(streamer.get_state_for_chunk(Vector2i(3, 0)), streamer.ChunkState.UNLOADED, errors, "unloaded chunk state")
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
