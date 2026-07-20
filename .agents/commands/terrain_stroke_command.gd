extends EditCommand
class_name TerrainStrokeCommand

var world_document: WorldDocument
var chunks_by_key: Dictionary
var sample_keys := PackedStringArray()
var affected_chunk_keys := PackedStringArray()
var before_heights := PackedFloat32Array()
var after_heights := PackedFloat32Array()


func _init(
	p_world_document: WorldDocument,
	p_chunks_by_key: Dictionary,
	p_sample_keys: PackedStringArray,
	p_affected_chunk_keys: PackedStringArray,
	p_before_heights: PackedFloat32Array,
	p_after_heights: PackedFloat32Array
) -> void:
	world_document = p_world_document
	chunks_by_key = p_chunks_by_key
	sample_keys = p_sample_keys.duplicate()
	affected_chunk_keys = p_affected_chunk_keys.duplicate()
	before_heights = p_before_heights.duplicate()
	after_heights = p_after_heights.duplicate()


func execute() -> void:
	_apply(after_heights)


func undo() -> void:
	_apply(before_heights)


func estimated_bytes() -> int:
	return sample_keys.size() * 20


func _apply(values: PackedFloat32Array) -> void:
	for i in range(sample_keys.size()):
		world_document.set_height_at_sample_key(sample_keys[i], values[i])
	_rebuild_affected_chunks()


func _rebuild_affected_chunks() -> void:
	for chunk_key in affected_chunk_keys:
		if not chunks_by_key.has(chunk_key):
			continue
		var chunk := chunks_by_key[chunk_key] as WorldChunk
		chunk.rebuild_terrain(true)
