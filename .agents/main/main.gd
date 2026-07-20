extends Node
class_name Main

const PRODUCT_NAME := "World Smithr"
const TERRAIN_RAY_LENGTH_M := 512.0
const TERRAIN_COLLISION_MASK := 1
const PROP_COLLISION_LAYER := 2
const QUICK_SAVE_PATH := "user://worlds/world_smithr_quick_save.json"
const WORLD_CHUNK_SCENE := preload("res://world/world_chunk.tscn")

@onready var _editor_shell: EditorShell = $UI/EditorShell
@onready var _services: Node = $Services
@onready var _world_root: Node3D = $WorldRoot
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
var _active_tool := "Sculpt"
var _is_sculpting := false
var _focus_chunk := Vector2i.ZERO
var _last_terrain_hit := Vector3(32.0, 0.0, 32.0)
var _props_root: Node3D
var _placed_prop_count := 0
var _selected_prop: Node3D
var _debug_chunks_visible := true
var _prop_materials: Dictionary = {}


func _ready() -> void:
	DisplayServer.window_set_title(PRODUCT_NAME)
	set_process(true)
	_initialize_services()
	_setup_props_root()
	_setup_phase_three_streaming()
	_connect_editor_shell()
	_editor_shell.set_status("Sculpt ready: drag the land, or pick Place and click", _focus_chunk, "Idle", _placed_prop_count)


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


func _setup_props_root() -> void:
	_props_root = Node3D.new()
	_props_root.name = "PlacedProps"
	_world_root.add_child(_props_root)


func _setup_phase_three_streaming() -> void:
	_world_document = WorldDocument.new()
	_reset_streaming_for_current_document()


func _reset_streaming_for_current_document() -> void:
	_chunks_by_key.clear()
	_terrain_mesher.pending_rebuilds.clear()
	_focus_chunk = Vector2i.ZERO
	_editor_camera_rig.frame_origin()
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
	_editor_shell.set_tool_hint(_hint_for_tool(_active_tool))
	_editor_shell.set_sculpt_settings("Raise", _sculpt_tool.radius_m, _sculpt_tool.strength_percent, "Smooth")
	_editor_shell.set_selection_summary("None")


func _update_streaming_focus() -> void:
	var next_focus := ChunkCoordinates.world_to_chunk(_editor_camera_rig.global_position)
	if next_focus == _focus_chunk:
		return

	_focus_chunk = next_focus
	var diff := _chunk_streamer.set_focus_chunk(_focus_chunk)
	_apply_streaming_diff(diff)
	_editor_shell.set_status("Streaming focus changed", _focus_chunk, _autosave_label(), _placed_prop_count)


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
	chunk.set_debug_visible(_debug_chunks_visible)
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
			"Dirty" if _is_sculpting else _autosave_label(),
			_placed_prop_count
		)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if event.pressed:
		match _active_tool:
			"Sculpt":
				_begin_sculpt_at_screen(event.position, event.shift_pressed)
			"Place":
				_place_prop_at_screen(event.position)
			"Select":
				_select_prop_at_screen(event.position)
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


func _begin_sculpt_at_screen(screen_position: Vector2, invert_raise_lower: bool) -> void:
	var hit := _pick_terrain(screen_position)
	if hit.is_empty():
		return

	_is_sculpting = true
	var position := hit["position"] as Vector3
	_sculpt_tool.begin_stroke(position)
	_stamp_sculpt(position, invert_raise_lower)
	get_viewport().set_input_as_handled()


func _place_prop_at_screen(screen_position: Vector2) -> void:
	var hit := _pick_terrain(screen_position)
	if hit.is_empty():
		_editor_shell.set_status("Place needs visible active terrain under the cursor", _focus_chunk, _autosave_label(), _placed_prop_count)
		return

	var prop := _create_tree_prop(hit["position"] as Vector3)
	_selected_prop = prop
	_placed_prop_count = _props_root.get_child_count()
	_autosave_service.mark_dirty()
	_editor_shell.set_selection_summary(prop.name)
	_editor_shell.set_status("Placed %s" % prop.name, ChunkCoordinates.world_to_chunk(prop.global_position), "Dirty", _placed_prop_count)
	get_viewport().set_input_as_handled()


func _select_prop_at_screen(screen_position: Vector2) -> void:
	_selected_prop = _pick_prop(screen_position)
	if _selected_prop == null:
		_editor_shell.set_selection_summary("None")
		_editor_shell.set_status("No placed object under cursor", _focus_chunk, _autosave_label(), _placed_prop_count)
	else:
		_editor_shell.set_selection_summary(_selected_prop.name)
		_editor_shell.set_status("Selected %s" % _selected_prop.name, ChunkCoordinates.world_to_chunk(_selected_prop.global_position), _autosave_label(), _placed_prop_count)
	get_viewport().set_input_as_handled()


func _stamp_sculpt(world_position: Vector3, invert_raise_lower: bool) -> void:
	if _sculpt_tool.apply_at(world_position, invert_raise_lower):
		_last_terrain_hit = world_position
		_queue_chunk_rebuilds(_sculpt_tool.get_current_affected_coords())
		_process_rebuild_queue()
		_editor_shell.set_status("Sculpting terrain", ChunkCoordinates.world_to_chunk(world_position), "Dirty", _placed_prop_count)


func _finish_sculpt_stroke() -> void:
	_is_sculpting = false
	var command := _sculpt_tool.end_stroke()
	if command == null:
		_editor_shell.set_status("Sculpt stroke had no terrain changes", _focus_chunk, _autosave_label(), _placed_prop_count)
		return

	_command_history.record_executed_command(command)
	_autosave_service.mark_dirty()
	_editor_shell.set_status("Sculpt stroke committed", _focus_chunk, "Dirty", _placed_prop_count)


func _pick_terrain(screen_position: Vector2) -> Dictionary:
	var origin := _camera.project_ray_origin(screen_position)
	var end := origin + _camera.project_ray_normal(screen_position) * TERRAIN_RAY_LENGTH_M
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = TERRAIN_COLLISION_MASK
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		_last_terrain_hit = result["position"] as Vector3
		return result

	return _pick_terrain_math_fallback(origin, end)


func _pick_prop(screen_position: Vector2) -> Node3D:
	var origin := _camera.project_ray_origin(screen_position)
	var end := origin + _camera.project_ray_normal(screen_position) * TERRAIN_RAY_LENGTH_M
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = PROP_COLLISION_LAYER
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return null

	var node := result["collider"] as Node
	while node != null:
		if node.has_meta("prop_type"):
			return node as Node3D
		node = node.get_parent()
	return null


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


func _create_tree_prop(world_position: Vector3) -> Node3D:
	var prop := Node3D.new()
	var next_index := _props_root.get_child_count() + 1
	prop.name = "Tree_%03d" % next_index
	prop.global_position = world_position
	prop.rotation.y = deg_to_rad(float((next_index * 37) % 360))
	var scale_variation := 0.86 + float((next_index * 13) % 24) / 100.0
	prop.scale = Vector3.ONE * scale_variation
	prop.set_meta("prop_type", "Tree")

	var trunk := MeshInstance3D.new()
	trunk.name = "Trunk"
	var trunk_mesh := BoxMesh.new()
	trunk_mesh.size = Vector3(0.8, 3.0, 0.8)
	trunk.mesh = trunk_mesh
	trunk.position = Vector3(0.0, 1.5, 0.0)
	trunk.material_override = _get_prop_material("trunk", Color(0.45, 0.27, 0.14, 1.0))
	prop.add_child(trunk)

	var canopy := MeshInstance3D.new()
	canopy.name = "Canopy"
	var canopy_mesh := SphereMesh.new()
	canopy_mesh.radius = 2.1
	canopy_mesh.height = 3.0
	canopy.mesh = canopy_mesh
	canopy.position = Vector3(0.0, 3.6, 0.0)
	canopy.scale = Vector3(1.0, 0.82, 1.0)
	canopy.material_override = _get_prop_material("canopy", Color(0.17, 0.42, 0.20, 1.0))
	prop.add_child(canopy)

	var pick_body := StaticBody3D.new()
	pick_body.name = "PickBody"
	pick_body.collision_layer = PROP_COLLISION_LAYER
	pick_body.collision_mask = 0
	var pick_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.8, 5.4, 4.8)
	pick_shape.shape = shape
	pick_shape.position = Vector3(0.0, 2.7, 0.0)
	pick_body.add_child(pick_shape)
	prop.add_child(pick_body)

	_props_root.add_child(prop)
	_placed_prop_count = _props_root.get_child_count()
	return prop


func _get_prop_material(key: String, color: Color) -> StandardMaterial3D:
	if _prop_materials.has(key):
		return _prop_materials[key] as StandardMaterial3D

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	_prop_materials[key] = material
	return material


func _on_action_requested(action_name: String) -> void:
	match action_name:
		"New":
			_new_world()
		"Open":
			_open_quick_save()
		"Save":
			_save_quick_snapshot("Saved quick world snapshot")
		"Undo":
			_undo()
		"Redo":
			_redo()
		"Build":
			_editor_shell.set_status("Build mode active: Sculpt and Place are live", _focus_chunk, _autosave_label(), _placed_prop_count)
		"Play":
			_editor_shell.set_status("Play mode needs the character pass; edit mode stays live", _focus_chunk, _autosave_label(), _placed_prop_count)
		"Export":
			_save_quick_snapshot("Quick save refreshed; GitHub Pages exports on push")
		"Settings":
			_toggle_debug_chunks()


func _new_world() -> void:
	_clear_props()
	_selected_prop = null
	_command_history.clear()
	_autosave_service.clear_dirty()
	_world_document = WorldDocument.new()
	_reset_streaming_for_current_document()
	_editor_shell.set_selection_summary("None")
	_editor_shell.set_status("New world ready", _focus_chunk, "Idle", _placed_prop_count)


func _undo() -> void:
	if _command_history.can_undo():
		_command_history.undo()
		_autosave_service.mark_dirty()
		_editor_shell.set_status("Undo terrain stroke", _focus_chunk, "Dirty", _placed_prop_count)
	else:
		_editor_shell.set_status("Nothing to undo", _focus_chunk, _autosave_label(), _placed_prop_count)


func _redo() -> void:
	if _command_history.can_redo():
		_command_history.redo()
		_autosave_service.mark_dirty()
		_editor_shell.set_status("Redo terrain stroke", _focus_chunk, "Dirty", _placed_prop_count)
	else:
		_editor_shell.set_status("Nothing to redo", _focus_chunk, _autosave_label(), _placed_prop_count)


func _save_quick_snapshot(success_message: String) -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		_editor_shell.set_status("Save failed: user storage is unavailable", _focus_chunk, _autosave_label(), _placed_prop_count)
		return

	var dir_error := dir.make_dir_recursive("worlds")
	if dir_error != OK:
		_editor_shell.set_status("Save failed: %s" % error_string(dir_error), _focus_chunk, _autosave_label(), _placed_prop_count)
		return

	var file := FileAccess.open(QUICK_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_editor_shell.set_status("Save failed: %s" % error_string(FileAccess.get_open_error()), _focus_chunk, _autosave_label(), _placed_prop_count)
		return

	var payload := {
		"format": "world_smithr",
		"version": 1,
		"name": _world_document.name,
		"heights": _world_document.serialize_height_samples(),
		"props": _serialize_props(),
	}
	file.store_string(JSON.stringify(payload, "\t"))
	_autosave_service.clear_dirty()
	_editor_shell.set_status(success_message, _focus_chunk, "Idle", _placed_prop_count)


func _open_quick_save() -> void:
	if not FileAccess.file_exists(QUICK_SAVE_PATH):
		_editor_shell.set_status("No quick save found yet", _focus_chunk, _autosave_label(), _placed_prop_count)
		return

	var file := FileAccess.open(QUICK_SAVE_PATH, FileAccess.READ)
	if file == null:
		_editor_shell.set_status("Open failed: %s" % error_string(FileAccess.get_open_error()), _focus_chunk, _autosave_label(), _placed_prop_count)
		return

	var parsed := JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		_editor_shell.set_status("Open failed: save file is not valid JSON", _focus_chunk, _autosave_label(), _placed_prop_count)
		return

	var save_data := parsed as Dictionary
	_world_document = WorldDocument.new()
	_world_document.name = str(save_data.get("name", "Untitled World"))
	var heights_variant = save_data.get("heights", {})
	if heights_variant is Dictionary:
		_world_document.load_height_samples(heights_variant as Dictionary)

	_clear_props()
	_reset_streaming_for_current_document()
	var props_variant = save_data.get("props", [])
	if props_variant is Array:
		_restore_props(props_variant as Array)
	_command_history.clear()
	_autosave_service.clear_dirty()
	_editor_shell.set_selection_summary("None")
	_editor_shell.set_status("Opened quick save", _focus_chunk, "Idle", _placed_prop_count)


func _serialize_props() -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	for child in _props_root.get_children():
		if child is Node3D and child.has_meta("prop_type"):
			var prop := child as Node3D
			props.append({
				"type": str(prop.get_meta("prop_type")),
				"x": prop.global_position.x,
				"y": prop.global_position.y,
				"z": prop.global_position.z,
				"rotation_y": prop.rotation.y,
				"scale": prop.scale.x,
			})
	return props


func _restore_props(prop_data: Array) -> void:
	for item in prop_data:
		if not (item is Dictionary):
			continue
		var prop_dict := item as Dictionary
		var position := Vector3(float(prop_dict.get("x", 0.0)), float(prop_dict.get("y", 0.0)), float(prop_dict.get("z", 0.0)))
		var prop := _create_tree_prop(position)
		prop.rotation.y = float(prop_dict.get("rotation_y", prop.rotation.y))
		var saved_scale := float(prop_dict.get("scale", prop.scale.x))
		prop.scale = Vector3.ONE * saved_scale
	_placed_prop_count = _props_root.get_child_count()


func _clear_props() -> void:
	if _props_root == null:
		return

	for child in _props_root.get_children():
		child.free()
	_placed_prop_count = 0


func _toggle_debug_chunks() -> void:
	_debug_chunks_visible = not _debug_chunks_visible
	for key in _chunks_by_key.keys():
		var chunk := _chunks_by_key[key] as WorldChunk
		chunk.set_debug_visible(_debug_chunks_visible)
	var state := "shown" if _debug_chunks_visible else "hidden"
	_editor_shell.set_status("Chunk labels and borders %s" % state, _focus_chunk, _autosave_label(), _placed_prop_count)


func _on_tool_selected(tool_name: String) -> void:
	_active_tool = tool_name
	_editor_shell.set_tool_hint(_hint_for_tool(tool_name))
	if tool_name == "Sculpt":
		_editor_shell.set_status("Sculpt: drag terrain; Shift inverts Raise/Lower", _focus_chunk, _autosave_label(), _placed_prop_count)
	elif tool_name == "Place":
		_editor_shell.set_status("Place: click terrain to drop trees", _focus_chunk, _autosave_label(), _placed_prop_count)
	elif tool_name == "Select":
		_editor_shell.set_status("Select: click placed trees", _focus_chunk, _autosave_label(), _placed_prop_count)


func _hint_for_tool(tool_name: String) -> String:
	match tool_name:
		"Sculpt":
			return "Drag on terrain to shape it. Shift flips Raise and Lower."
		"Place":
			return "Click visible terrain to place a low-poly tree."
		"Select":
			return "Click a placed tree to inspect it."
	return "Sculpt and Place are live in this build."


func _on_sculpt_mode_selected(mode_name: String) -> void:
	_sculpt_tool.set_mode_from_name(mode_name)
	_editor_shell.set_status("Sculpt mode: %s" % mode_name, _focus_chunk, _autosave_label(), _placed_prop_count)


func _on_brush_radius_changed(value: float) -> void:
	_sculpt_tool.radius_m = value


func _on_brush_strength_changed(value: float) -> void:
	_sculpt_tool.strength_percent = value


func _on_brush_falloff_selected(falloff_name: String) -> void:
	_sculpt_tool.set_falloff_from_name(falloff_name)


func _autosave_label() -> String:
	return "Dirty" if _autosave_service.is_processing() else "Idle"

