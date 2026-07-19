extends Node
class_name Main

const PRODUCT_NAME := "World Smithr"
const TERRAIN_RAY_LENGTH_M := 512.0

@onready var _editor_shell: EditorShell = $UI/EditorShell
@onready var _services: Node = $Services
@onready var _camera: Camera3D = $EditorCameraRig/Pivot/Camera3D
@onready var _world_chunk: WorldChunk = $WorldRoot/ChunkContainer/StarterChunk
@onready var _terrain_mesher: TerrainMesher = $Services/TerrainMesher
@onready var _command_history: CommandHistory = $Services/CommandHistory
@onready var _autosave_service: AutosaveService = $Services/AutosaveService

var _chunk_data: ChunkData
var _sculpt_tool: SculptTool
var _active_tool := "Select"
var _is_sculpting := false
var _last_terrain_hit := Vector3(32.0, 0.0, 32.0)


func _ready() -> void:
	DisplayServer.window_set_title(PRODUCT_NAME)
	_initialize_services()
	_setup_phase_one_chunk()
	_connect_editor_shell()
	_editor_shell.set_status("Phase 1 terrain ready", Vector2i.ZERO, "Idle", 0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)


func _initialize_services() -> void:
	for child: Node in _services.get_children():
		if child.has_method("initialize"):
			child.call("initialize", self)


func _setup_phase_one_chunk() -> void:
	_chunk_data = ChunkData.new(Vector2i.ZERO)
	_world_chunk.configure(_chunk_data, _terrain_mesher)
	_world_chunk.set_runtime_state(WorldChunk.RuntimeState.ACTIVE)

	_sculpt_tool = SculptTool.new()
	_sculpt_tool.configure(_chunk_data, _world_chunk)
	_sculpt_tool.set_mode_from_name("Raise")
	_sculpt_tool.set_falloff_from_name("Smooth")
	_sculpt_tool.radius_m = 8.0
	_sculpt_tool.strength_percent = 50.0


func _connect_editor_shell() -> void:
	_editor_shell.action_requested.connect(_on_action_requested)
	_editor_shell.tool_selected.connect(_on_tool_selected)
	_editor_shell.sculpt_mode_selected.connect(_on_sculpt_mode_selected)
	_editor_shell.brush_radius_changed.connect(_on_brush_radius_changed)
	_editor_shell.brush_strength_changed.connect(_on_brush_strength_changed)
	_editor_shell.brush_falloff_selected.connect(_on_brush_falloff_selected)
	_editor_shell.set_active_tool(_active_tool)
	_editor_shell.set_sculpt_settings("Raise", _sculpt_tool.radius_m, _sculpt_tool.strength_percent, "Smooth")


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if event.pressed:
		if _active_tool != "Sculpt":
			return

		var hit := _pick_terrain(event.position)
		if hit.is_empty():
			return

		_is_sculpting = true
		var position := hit["position"] as Vector3
		_sculpt_tool.begin_stroke(position)
		_stamp_sculpt(position, event.shift_pressed)
		get_viewport().set_input_as_handled()
	elif _is_sculpting:
		_finish_sculpt_stroke()
		get_viewport().set_input_as_handled()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if not _is_sculpting:
		return

	var hit := _pick_terrain(event.position)
	if hit.is_empty():
		_stamp_sculpt(_last_terrain_hit, event.shift_pressed)
	else:
		_stamp_sculpt(hit["position"] as Vector3, event.shift_pressed)
	get_viewport().set_input_as_handled()


func _stamp_sculpt(world_position: Vector3, invert_raise_lower: bool) -> void:
	if _sculpt_tool.apply_at(world_position, invert_raise_lower):
		_last_terrain_hit = world_position
		_world_chunk.rebuild_terrain(true)
		_editor_shell.set_status("Sculpting terrain", Vector2i.ZERO, "Dirty", 0)


func _finish_sculpt_stroke() -> void:
	_is_sculpting = false
	var command := _sculpt_tool.end_stroke()
	if command == null:
		_editor_shell.set_status("Sculpt stroke had no terrain changes", Vector2i.ZERO, "Idle", 0)
		return

	_command_history.execute_command(command)
	_autosave_service.mark_dirty()
	_editor_shell.set_status("Sculpt stroke committed", Vector2i.ZERO, "Dirty", 0)


func _pick_terrain(screen_position: Vector2) -> Dictionary:
	var origin := _camera.project_ray_origin(screen_position)
	var end := origin + _camera.project_ray_normal(screen_position) * TERRAIN_RAY_LENGTH_M
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		_last_terrain_hit = result["position"] as Vector3
		return result

	return _pick_terrain_math_fallback(origin, end)


func _pick_terrain_math_fallback(origin: Vector3, end: Vector3) -> Dictionary:
	var local_origin := _world_chunk.to_local(origin)
	var local_end := _world_chunk.to_local(end)
	var local_direction := local_end - local_origin
	if is_zero_approx(local_direction.y):
		return {}

	var t := -local_origin.y / local_direction.y
	if t < 0.0 or t > 1.0:
		return {}

	var local_hit := local_origin + local_direction * t
	if local_hit.x < 0.0 or local_hit.z < 0.0:
		return {}
	if local_hit.x > ChunkCoordinates.CHUNK_SIZE_M or local_hit.z > ChunkCoordinates.CHUNK_SIZE_M:
		return {}

	local_hit.y = _chunk_data.get_height_at_local(local_hit)
	var world_hit := _world_chunk.to_global(local_hit)
	_last_terrain_hit = world_hit
	return {"position": world_hit, "collider": _world_chunk}


func _on_action_requested(action_name: String) -> void:
	match action_name:
		"Undo":
			if _command_history.can_undo():
				_command_history.undo()
				_autosave_service.mark_dirty()
				_editor_shell.set_status("Undo terrain stroke", Vector2i.ZERO, "Dirty", 0)
			else:
				_editor_shell.set_status("Nothing to undo", Vector2i.ZERO, "Idle", 0)
		"Redo":
			if _command_history.can_redo():
				_command_history.redo()
				_autosave_service.mark_dirty()
				_editor_shell.set_status("Redo terrain stroke", Vector2i.ZERO, "Dirty", 0)
			else:
				_editor_shell.set_status("Nothing to redo", Vector2i.ZERO, "Idle", 0)


func _on_tool_selected(tool_name: String) -> void:
	_active_tool = tool_name


func _on_sculpt_mode_selected(mode_name: String) -> void:
	_sculpt_tool.set_mode_from_name(mode_name)
	_editor_shell.set_status("Sculpt mode: %s" % mode_name, Vector2i.ZERO, "Idle", 0)


func _on_brush_radius_changed(value: float) -> void:
	_sculpt_tool.radius_m = value


func _on_brush_strength_changed(value: float) -> void:
	_sculpt_tool.strength_percent = value


func _on_brush_falloff_selected(falloff_name: String) -> void:
	_sculpt_tool.set_falloff_from_name(falloff_name)
