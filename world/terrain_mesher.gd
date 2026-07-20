extends Node
class_name TerrainMesher

const INVALID_REBUILD_COORD := Vector2i(2147483647, 2147483647)

@export var max_rebuilds_per_frame := 1

var pending_rebuilds: Array[Vector2i] = []
var terrain_material: Material


func initialize(_main: Node) -> void:
	pending_rebuilds.clear()
	terrain_material = _create_default_material()


func queue_rebuild(coord: Vector2i) -> void:
	if not pending_rebuilds.has(coord):
		pending_rebuilds.append(coord)


func queue_rebuilds(coords: Array[Vector2i]) -> void:
	for coord in coords:
		queue_rebuild(coord)


func take_next_rebuild() -> Vector2i:
	if pending_rebuilds.is_empty():
		return INVALID_REBUILD_COORD

	return pending_rebuilds.pop_front()


func has_pending_rebuilds() -> bool:
	return not pending_rebuilds.is_empty()


func pending_rebuild_count() -> int:
	return pending_rebuilds.size()


func build_mesh(chunk_data: ChunkData) -> ArrayMesh:
	if terrain_material == null:
		terrain_material = _create_default_material()

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var sample_total := ChunkCoordinates.HEIGHT_SAMPLES * ChunkCoordinates.HEIGHT_SAMPLES
	vertices.resize(sample_total)
	normals.resize(sample_total)
	uvs.resize(sample_total)

	var origin := ChunkCoordinates.chunk_to_world_origin(chunk_data.coord)
	for z in range(ChunkCoordinates.HEIGHT_SAMPLES):
		for x in range(ChunkCoordinates.HEIGHT_SAMPLES):
			var sample_index := ChunkData.index(x, z)
			var local_x := float(x) * ChunkCoordinates.CELL_SIZE_M
			var local_z := float(z) * ChunkCoordinates.CELL_SIZE_M
			var height := chunk_data.get_height(x, z)
			vertices[sample_index] = Vector3(local_x, height, local_z)
			normals[sample_index] = _calculate_normal(chunk_data, x, z)
			uvs[sample_index] = Vector2(
				(origin.x + local_x) / ChunkCoordinates.CHUNK_SIZE_M,
				(origin.z + local_z) / ChunkCoordinates.CHUNK_SIZE_M
			)

	indices.resize(ChunkCoordinates.TERRAIN_CELLS * ChunkCoordinates.TERRAIN_CELLS * 6)
	var write_index := 0
	for z in range(ChunkCoordinates.TERRAIN_CELLS):
		for x in range(ChunkCoordinates.TERRAIN_CELLS):
			var i0 := ChunkData.index(x, z)
			var i1 := ChunkData.index(x + 1, z)
			var i2 := ChunkData.index(x, z + 1)
			var i3 := ChunkData.index(x + 1, z + 1)

			indices[write_index] = i0
			indices[write_index + 1] = i2
			indices[write_index + 2] = i1
			indices[write_index + 3] = i1
			indices[write_index + 4] = i2
			indices[write_index + 5] = i3
			write_index += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, terrain_material)
	return mesh


func _calculate_normal(chunk_data: ChunkData, sample_x: int, sample_z: int) -> Vector3:
	var west := chunk_data.get_height_at_sample_offset(sample_x, sample_z, -1, 0)
	var east := chunk_data.get_height_at_sample_offset(sample_x, sample_z, 1, 0)
	var north := chunk_data.get_height_at_sample_offset(sample_x, sample_z, 0, -1)
	var south := chunk_data.get_height_at_sample_offset(sample_x, sample_z, 0, 1)
	return Vector3(west - east, 2.0 * ChunkCoordinates.CELL_SIZE_M, north - south).normalized()


func _create_default_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.34, 0.55, 0.32, 1.0)
	material.roughness = 1.0
	return material
