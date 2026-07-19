extends Node3D
class_name WorldChunk

enum RuntimeState {
	ACTIVE,
	WARM,
	UNLOADED,
}

@export var coord := Vector2i.ZERO

var runtime_state := RuntimeState.ACTIVE
var data: ChunkData
var mesher: TerrainMesher

@onready var _terrain: MeshInstance3D = $Terrain
@onready var _terrain_body: StaticBody3D = $TerrainBody
@onready var _collision_shape: CollisionShape3D = $TerrainBody/CollisionShape3D


func _ready() -> void:
	if data == null:
		data = ChunkData.new(coord)
	if mesher == null:
		mesher = TerrainMesher.new()
	rebuild_terrain(true)


func configure(chunk_data: ChunkData, terrain_mesher: TerrainMesher) -> void:
	data = chunk_data
	coord = data.coord
	mesher = terrain_mesher
	position = ChunkCoordinates.chunk_to_world_origin(coord)
	if is_node_ready():
		rebuild_terrain(true)


func set_runtime_state(value: RuntimeState) -> void:
	runtime_state = value
	visible = runtime_state != RuntimeState.UNLOADED
	if is_node_ready():
		_terrain_body.process_mode = Node.PROCESS_MODE_INHERIT if runtime_state == RuntimeState.ACTIVE else Node.PROCESS_MODE_DISABLED


func rebuild_terrain(include_collision: bool = true) -> void:
	if data == null:
		return

	var mesh := mesher.build_mesh(data)
	_terrain.mesh = mesh
	if include_collision:
		_collision_shape.shape = mesh.create_trimesh_shape()


func get_height_at_world(world_position: Vector3) -> float:
	if data == null:
		return 0.0

	return data.get_height_at_local(to_local(world_position))
