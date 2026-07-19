extends Node
class_name Main

const PRODUCT_NAME := "World Smithr"
const TERRAIN_RAY_LENGTH_M := 512.0
const WORLD_CHUNK_SCENE := preload("res://world/world_chunk.tscn")

@onready var _editor_shell: EditorShell = $UI/EditorShell
@onready var _services: Node = $Services
@onready var _editor_camera_rig: EditorCameraRig = $EditorCameraRig
@onready var _camera: Camera3D = $EditorCameraRig/Pivot/Camera3D
@onready var _chunk_container: Node3D = $WorldRoot/ChunkContainer
@onready var _chunk_streamer: ChunkStreamer = $Services/ChunkStreamer
@onready var _terrain_mesher: TerrainMesher = $Services/TerrainMesher
@onready var _command_history: CommandHistory = $Services/CommandHistory
@onready var _autosave_service: AutosaveService = $Services/AutosaveService

var _world_document: WorldDocument
var _chunks_by_key: Dictionary = {}
var _sculpt_tool: SculptTool
var _active_tool := "Select"
var _is_sculpting := false
var _focus_chunk := Vector2i.ZERO
var _last_terrain_hit := Vector3(32.0, 0.0, 32.0)


func _ready() -> void:
	DisplayServer.window_set_title(PRODUCT_NAME)
	set_process(true)
	_initialize_services()
	_setup_phase_three_streaming()
	_connect_editor_shell()
	_editor_shell.set_status("Phase 3 streaming 5x5 ready", _focus_chunk, "Idle", _chunks_by_key.size())


func _process(_delta: float) -> void:
	_update_streaming_focus()
	_process_rebuild_queue()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)


func _initialize_services() -> void:
	for child: Node in _services.get_children():
		if child.has_method("initialize"):
			child.call("initialize", self)


func _setup_phase_three_streaming() -> void:
	_world_document = WorldDocument.new()
	_chunks_by_key.clear()
	for child in _chunk_container.get_children():
		child.queue_free()

	_sculpt_tool = SculptTool.new()
	_sculpt_tool.configure(_world_document, _chunks_by_key)
	_sculpt_tool.set_mode_from_name("Raise")
	_sculpt_tool.set_falloff_from_name("Smooth")
	_sculpt_tool.radius_m = 8.0
	_sculpt_tool.strength_percent = 50.0

	var initial_diff := _chunk_streamer.set_focus_chunk(_focus_chunk, true)
	_apply_streaming_diff(initial_diff)


func _connect_editor_shell() -> void:
	_editor_shell.action_requested.connect(_on_action_requested)
	_editor_shell.tool_selected.connect(_on_tool_selected)
	_editor_shell.sculpt_mode_selected.connect(_on_sculpt_mode_selected)
	_editor_shell.brush_radius_changed.connect(_on_brush_radius_changed)
	_editor_shell.brush_strength_changed.connect(_on_brush_strength_changed)
	_editor_shell.brush_falloff_selected.connect(_on_brush_falloff_selected)
	_editor_shell.set_active_tool(_active_tool)
	_editor_shell.set_sculpt_settings("Raise", _sculpt_tool.radius_m, _sculpt_tool.strength_percent, "Smooth")


func _update_streaming_focus() -> void:
	var next_focus := ChunkCoordinates.world_to_chunk(_editor_camera_rig.global_position)
	if next_focus == _focus_chunk:
		return

	_focus_chunk = next_focus
	var diff := _chunk_streamer.set_focus_chunk(_focus_chunk)
	_apply_streaming_diff(diff)
	_editor_shell.set_status("Streaming focus changed", _focus_chunk, "Idle", _chunks_by_key.size())


func _apply_streaming_diff(diff: Dictionary) -> void:
	for coord in diff["entered_loaded"]:
		var state := _chunk_streamer.get_state_for_chunk(coord)
		var build_now := state == ChunkStreamer.ChunkState.ACTIVE
		_ensure_chunk(coord, state, build_now)

	for coord in _chunk_streamer.loaded_chunks:
		var state := _chunk_streamer.get_state_for_chunk(coord)
		var chunk := _ensure_chunk(coord, state, false)
		chunk.set_runtime_state(state)
		if not chunk.has_mesh():
			if state == ChunkStreamer.ChunkState.ACTIVE:
				if chunk.is_node_ready():
					chunk.rebuild_terrain(true)
				else:
					chunk.build_on_ready = true
			else:
				_queue_chunk_rebuild(coord)
		elif state == ChunkStreamer.ChunkState.ACTIVE and not chunk.has_collision():
			_queue_chunk_rebuild(coord)
		elif state == ChunkStreamer.ChunkState.WARM and chunk.has_collision():
			_queue_chunk_rebuild(coord)

	for coord in diff["exited_loaded"]:
		_unload_chunk(coord)

	_sculpt_tool.set_chunks(_chunks_by_key)


func _ensure_chunk(coord: Vector2i, state: int, build_now: bool) -> WorldChunk:
	var key := ChunkCoordinates.chunk_to_key(coord)
	if _chunks_by_key.has(key):
		return _chunks_by_key[key] as WorldChunk

	var chunk := WORLD_CHUNK_SCENE.instantiate() as WorldChunk
	chunk.configure(_world_document.get_chunk_data(coord), _terrain_mesher, build_now)
	chunk.set_runtime_state(state)
	chunk.set_debug_visible(true)
	_chunk_container.add_child(chunk)
	_chunks_by_key[key] = chunk
	return chunk


func _unload_chunk(coord: Vector2i) -> void:
	var key := ChunkCoordinates.chunk_to_key(coord)
	if not _chunks_by_key.has(key):
		return

	var chunk := _chunks_by_key[key] as WorldChunk
	chunk.set_runtime_state(WorldChunk.RuntimeState.UNLOADED)
	chunk.queue_free()
	_chunks_by_key.erase(key)


func _queue_chunk_rebuild(coord: Vector2i) -> void:
	if _chunks_by_key.has(ChunkCoordinates.chunk_to_key(coord)):
		_terrain_mesher.queue_rebuild(coord)


func _queue_chunk_rebuilds(coords: Array[Vector2i]) -> void:
	for coord in coords:
		_queue_chunk_rebuild(coord)


func _process_rebuild_queue() -> void:
	var rebuilt := 0
	for _i in range(_terrain_mesher.max_rebuilds_per_frame):
		var coord := _terrain_mesher.take_next_rebuild()
		if coord == TerrainMesher.INVALID_REBUILD_COORD:
			break

		var key := ChunkCoordinates.chunk_to_key(coord)
		if not _chunks_by_key.has(key):
			continue

		var chunk := _chunks_by_key[key] as WorldChunk
		if not chunk.is_node_ready():
			_queue_chunk_rebuild(coord)
			continue
		if chunk.runtime_state == WorldChunk.RuntimeState.UNLOADED:
			continue

		chunk.rebuild_terrain(chunk.runtime_state == WorldChunk.RuntimeState.ACTIVE)
		rebuilt += 1

	if rebuilt > 0:
		_editor_shell.set_status(
			"Rebuilt %d chunk mesh" % rebuilt,
			_focus_chunk,
			"Dirty" if _is_sculpting else "Idle",
			_chunks_by_key.size()
		)


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
		_queue_chunk_rebuilds(_sculpt_tool.get_current_affected_coords())
		_process_rebuild_queue()
		_editor_shell.set_status("Sculpting terrain", ChunkCoordinates.world_to_chunk(world_position), "Dirty", _chunks_by_key.size())


func _finish_sculpt_stroke() -> void:
	_is_sculpting = false
	var command := _sculpt_tool.end_stroke()
	if command == null:
		_editor_shell.set_status("Sculpt stroke had no terrain changes", _focus_chunk, "Idle", _chunks_by_key.size())
		return

	_command_history.record_executed_command(command)
	_autosave_service.mark_dirty()
	_editor_shell.set_status("Sculpt stroke committed", _focus_chunk, "Dirty", _chunks_by_key.size())


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
	var direction := end - origin
	if is_zero_approx(direction.y):
		return {}

	var t := -origin.y / direction.y
	if t < 0.0 or t > 1.0:
		return {}

	var world_hit := origin + direction * t
	if not _is_world_position_in_active_chunks(world_hit):
		return {}

	world_hit.y = _world_document.get_height_at_world(world_hit)
	_last_terrain_hit = world_hit
	return {"position": world_hit}


func _is_world_position_in_active_chunks(world_position: Vector3) -> bool:
	var coord := ChunkCoordinates.world_to_chunk(world_position)
	return _chunk_streamer.is_active(coord)


func _on_action_requested(action_name: String) -> void:
	match action_name:
		"Undo":
			if _command_history.can_undo():
				_command_history.undo()
				_autosave_service.mark_dirty()
				_editor_shell.set_status("Undo terrain stroke", _focus_chunk, "Dirty", _chunks_by_key.size())
			else:
				_editor_shell.set_status("Nothing to undo", _focus_chunk, "Idle", _chunks_by_key.size())
		"Redo":
			if _command_history.can_redo():
				_command_history.redo()
				_autosave_service.mark_dirty()
				_editor_shell.set_status("Redo terrain stroke", _focus_chunk, "Dirty", _chunks_by_key.size())
			else:
				_editor_shell.set_status("Nothing to redo", _focus_chunk, "Idle", _chunks_by_key.size())


func _on_tool_selected(tool_name: String) -> void:
	_active_tool = tool_name


func _on_sculpt_mode_selected(mode_name: String) -> void:
	_sculpt_tool.set_mode_from_name(mode_name)
	_editor_shell.set_status("Sculpt mode: %s" % mode_name, _focus_chunk, "Idle", _chunks_by_key.size())


func _on_brush_radius_changed(value: float) -> void:
	_sculpt_tool.radius_m = value


func _on_brush_strength_changed(value: float) -> void:
	_sculpt_tool.strength_percent = value


func _on_brush_falloff_selected(falloff_name: String) -> void:
	_sculpt_tool.set_falloff_from_name(falloff_name)



