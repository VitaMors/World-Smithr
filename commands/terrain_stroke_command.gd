extends EditCommand
class_name TerrainStrokeCommand

var chunk_data: ChunkData
var world_chunk: WorldChunk
var changed_indices := PackedInt32Array()
var before_heights := PackedFloat32Array()
var after_heights := PackedFloat32Array()


func _init(
	p_chunk_data: ChunkData,
	p_world_chunk: WorldChunk,
	p_changed_indices: PackedInt32Array,
	p_before_heights: PackedFloat32Array,
	p_after_heights: PackedFloat32Array
) -> void:
	chunk_data = p_chunk_data
	world_chunk = p_world_chunk
	changed_indices = p_changed_indices.duplicate()
	before_heights = p_before_heights.duplicate()
	after_heights = p_after_heights.duplicate()


func execute() -> void:
	_apply(after_heights)


func undo() -> void:
	_apply(before_heights)


func estimated_bytes() -> int:
	return changed_indices.size() * 12


func _apply(values: PackedFloat32Array) -> void:
	for i in range(changed_indices.size()):
		chunk_data.set_height_by_index(changed_indices[i], values[i])
	world_chunk.rebuild_terrain(true)
