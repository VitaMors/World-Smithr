extends Node3D
class_name WorldChunk

enum RuntimeState {
	ACTIVE,
	WARM,
	UNLOADED,
}

@export var coord := Vector2i.ZERO
@export var debug_visible := true

var runtime_state := RuntimeState.ACTIVE
var data: ChunkData
var mesher: TerrainMesher
var build_on_ready := true

var _debug_material: StandardMaterial3D
var _coord_label: Label3D
var _mesh_ready := false

@onready var _terrain: MeshInstance3D = $Terrain
@onready var _terrain_body: StaticBody3D = $TerrainBody
@onready var _collision_shape: CollisionShape3D = $TerrainBody/CollisionShape3D
@onready var _debug_overlay: Node3D = $DebugOverlay


func _ready() -> void:
	if data == null:
		data = ChunkData.new(coord)
		build_on_ready = true
	if mesher == null:
		mesher = TerrainMesher.new()
	_update_debug_material()
	_update_debug_label()
	_apply_runtime_state()
	if build_on_ready:
		rebuild_terrain(runtime_state == RuntimeState.ACTIVE)


func configure(chunk_data: ChunkData, terrain_mesher: TerrainMesher, build_immediately: bool = false) -> void:
	data = chunk_data
	coord = data.coord
	mesher = terrain_mesher
	build_on_ready = build_immediately
	position = ChunkCoordinates.chunk_to_world_origin(coord)
	_update_debug_material()
	if is_node_ready():
		_update_debug_label()
		_apply_runtime_state()
		if build_immediately:
			rebuild_terrain(runtime_state == RuntimeState.ACTIVE)


func set_runtime_state(value: int) -> void:
	runtime_state = value
	if is_node_ready():
		_update_debug_label()
		_apply_runtime_state()


func rebuild_terrain(include_collision: bool = true) -> void:
	if not is_node_ready():
		build_on_ready = true
		return
	if data == null:
		return

	var mesh := mesher.build_mesh(data)
	if _debug_material != null and mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, _debug_material)
	_terrain.mesh = mesh
	_mesh_ready = true
	if include_collision:
		_collision_shape.shape = mesh.create_trimesh_shape()
	else:
		_collision_shape.shape = null
	_apply_runtime_state()


func has_mesh() -> bool:
	return _mesh_ready


func has_collision() -> bool:
	return is_node_ready() and _collision_shape != null and _collision_shape.shape != null


func get_height_at_world(world_position: Vector3) -> float:
	if data == null:
		return 0.0

	return data.get_height_at_local(to_local(world_position))


func set_debug_visible(value: bool) -> void:
	debug_visible = value
	if is_node_ready():
		_debug_overlay.visible = debug_visible


func _apply_runtime_state() -> void:
	visible = runtime_state != RuntimeState.UNLOADED
	_terrain_body.process_mode = Node.PROCESS_MODE_INHERIT if runtime_state == RuntimeState.ACTIVE else Node.PROCESS_MODE_DISABLED
	_debug_overlay.visible = debug_visible and runtime_state != RuntimeState.UNLOADED


func _update_debug_material() -> void:
	_debug_material = StandardMaterial3D.new()
	_debug_material.albedo_color = _debug_colour_for_coord(coord)
	_debug_material.roughness = 1.0


func _debug_colour_for_coord(chunk_coord: Vector2i) -> Color:
	var hash := absi(chunk_coord.x * 928371 + chunk_coord.y * 689287)
	var hue := float(hash % 360) / 360.0
	return Color.from_hsv(hue, 0.24, 0.68, 1.0)


func _update_debug_label() -> void:
	if not is_node_ready():
		return

	if _coord_label == null:
		_coord_label = Label3D.new()
		_coord_label.name = "CoordinateLabel"
		_coord_label.font_size = 28
		_coord_label.modulate = Color(1.0, 1.0, 1.0, 0.9)
		_coord_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.75)
		_coord_label.outline_size = 8
		_debug_overlay.add_child(_coord_label)

	_coord_label.text = "%s %s" % [_state_label(), ChunkCoordinates.chunk_to_key(coord)]
	_coord_label.position = Vector3(ChunkCoordinates.CHUNK_SIZE_M * 0.5, 2.0, ChunkCoordinates.CHUNK_SIZE_M * 0.5)
	_debug_overlay.visible = debug_visible and runtime_state != RuntimeState.UNLOADED


func _state_label() -> String:
	match runtime_state:
		RuntimeState.ACTIVE:
			return "A"
		RuntimeState.WARM:
			return "W"
	return "U"

