extends Node
class_name Main

const PRODUCT_NAME := "World Smithr"
const TERRAIN_SIZE_M := 128.0
const TERRAIN_CELLS := 64
const TERRAIN_SAMPLES := TERRAIN_CELLS + 1
const CELL_SIZE_M := TERRAIN_SIZE_M / float(TERRAIN_CELLS)
const TERRAIN_RAY_LENGTH_M := 512.0
const TERRAIN_COLLISION_LAYER := 1
const PROP_COLLISION_LAYER := 2
const QUICK_SAVE_PATH := "user://worlds/world_smithr_quick_save.json"

@onready var _editor_shell = $UI/EditorShell
@onready var _world_root: Node3D = $WorldRoot
@onready var _camera_rig: Node3D = $EditorCameraRig
@onready var _camera_pivot: Node3D = $EditorCameraRig/Pivot
@onready var _camera: Camera3D = $EditorCameraRig/Pivot/Camera3D

var _terrain_mesh_instance: MeshInstance3D
var _terrain_body: StaticBody3D
var _terrain_collision: CollisionShape3D
var _grid_mesh_instance: MeshInstance3D
var _props_root: Node3D
var _terrain_material: StandardMaterial3D
var _grid_material: StandardMaterial3D
var _height_samples := PackedFloat32Array()
var _active_tool := "Sculpt"
var _sculpt_mode := "Raise"
var _brush_radius_m := 8.0
var _brush_strength_percent := 50.0
var _brush_falloff := "Smooth"
var _is_sculpting := false
var _stroke_before := PackedFloat32Array()
var _stroke_changed := false
var _stroke_flatten_height := 0.0
var _dirty := false
var _undo_stack: Array = []
var _redo_stack: Array = []
var _selected_prop: Node3D
var _prop_materials: Dictionary = {}
var _debug_grid_visible := true


func _ready() -> void:
	DisplayServer.window_set_title(PRODUCT_NAME)
	_configure_camera()
	_create_editor_world_nodes()
	_generate_starter_terrain()
	_rebuild_terrain_mesh()
	_create_starter_props()
	_connect_editor_shell()
	_update_status("Starter terrain ready: sculpt, place, save")
	call_deferred("_announce_ready")


func _announce_ready() -> void:
	_update_status("Starter terrain ready: sculpt, place, save")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)


func _configure_camera() -> void:
	_camera_rig.global_position = Vector3(64.0, 0.0, 64.0)
	_camera_pivot.rotation = Vector3(deg_to_rad(-56.0), deg_to_rad(45.0), 0.0)
	_camera.position = Vector3(0.0, 0.0, 120.0)
	_camera.current = true
	_camera.far = 420.0
	_camera.fov = 50.0


func _create_editor_world_nodes() -> void:
	_terrain_material = StandardMaterial3D.new()
	_terrain_material.albedo_color = Color(0.34, 0.58, 0.31, 1.0)
	_terrain_material.roughness = 1.0

	_grid_material = StandardMaterial3D.new()
	_grid_material.albedo_color = Color(0.03, 0.04, 0.035, 0.88)
	_grid_material.roughness = 1.0

	_terrain_mesh_instance = MeshInstance3D.new()
	_terrain_mesh_instance.name = "LiveTerrain"
	_world_root.add_child(_terrain_mesh_instance)

	_terrain_body = StaticBody3D.new()
	_terrain_body.name = "LiveTerrainBody"
	_terrain_body.collision_layer = TERRAIN_COLLISION_LAYER
	_terrain_body.collision_mask = 0
	_world_root.add_child(_terrain_body)

	_terrain_collision = CollisionShape3D.new()
	_terrain_collision.name = "LiveTerrainCollision"
	_terrain_body.add_child(_terrain_collision)

	_grid_mesh_instance = MeshInstance3D.new()
	_grid_mesh_instance.name = "TerrainGrid"
	_grid_mesh_instance.mesh = _build_grid_mesh()
	_grid_mesh_instance.material_override = _grid_material
	_world_root.add_child(_grid_mesh_instance)

	_props_root = Node3D.new()
	_props_root.name = "PlacedProps"
	_world_root.add_child(_props_root)


func _connect_editor_shell() -> void:
	_editor_shell.action_requested.connect(_on_action_requested)
	_editor_shell.tool_selected.connect(_on_tool_selected)
	_editor_shell.sculpt_mode_selected.connect(_on_sculpt_mode_selected)
	_editor_shell.brush_radius_changed.connect(_on_brush_radius_changed)
	_editor_shell.brush_strength_changed.connect(_on_brush_strength_changed)
	_editor_shell.brush_falloff_selected.connect(_on_brush_falloff_selected)
	_editor_shell.set_active_tool(_active_tool)
	_editor_shell.set_tool_hint(_hint_for_tool(_active_tool))
	_editor_shell.set_sculpt_settings(_sculpt_mode, _brush_radius_m, _brush_strength_percent, _brush_falloff)
	_editor_shell.set_selection_summary("None")


func _generate_starter_terrain() -> void:
	_height_samples.resize(TERRAIN_SAMPLES * TERRAIN_SAMPLES)
	for z in range(TERRAIN_SAMPLES):
		for x in range(TERRAIN_SAMPLES):
			var world_x := float(x) * CELL_SIZE_M
			var world_z := float(z) * CELL_SIZE_M
			var hill_a := _hill_height(world_x, world_z, Vector2(42.0, 44.0), 28.0, 7.0)
			var hill_b := _hill_height(world_x, world_z, Vector2(86.0, 74.0), 34.0, 5.0)
			var basin := _hill_height(world_x, world_z, Vector2(82.0, 32.0), 22.0, -2.0)
			_height_samples[_sample_index(x, z)] = hill_a + hill_b + basin
	_dirty = false
	_undo_stack.clear()
	_redo_stack.clear()


func _hill_height(world_x: float, world_z: float, center: Vector2, radius: float, height: float) -> float:
	var distance := Vector2(world_x, world_z).distance_to(center)
	var t := clampf(1.0 - distance / radius, 0.0, 1.0)
	return height * t * t * (3.0 - 2.0 * t)


func _rebuild_terrain_mesh(update_collision: bool = true) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	vertices.resize(TERRAIN_SAMPLES * TERRAIN_SAMPLES)
	normals.resize(TERRAIN_SAMPLES * TERRAIN_SAMPLES)
	uvs.resize(TERRAIN_SAMPLES * TERRAIN_SAMPLES)

	for z in range(TERRAIN_SAMPLES):
		for x in range(TERRAIN_SAMPLES):
			var index := _sample_index(x, z)
			vertices[index] = Vector3(float(x) * CELL_SIZE_M, _height_samples[index], float(z) * CELL_SIZE_M)
			normals[index] = _calculate_normal(x, z)
			uvs[index] = Vector2(float(x) / float(TERRAIN_CELLS), float(z) / float(TERRAIN_CELLS))

	for z in range(TERRAIN_CELLS):
		for x in range(TERRAIN_CELLS):
			var i0 := _sample_index(x, z)
			var i1 := _sample_index(x + 1, z)
			var i2 := _sample_index(x, z + 1)
			var i3 := _sample_index(x + 1, z + 1)
			indices.append(i0)
			indices.append(i2)
			indices.append(i1)
			indices.append(i1)
			indices.append(i2)
			indices.append(i3)
			indices.append(i0)
			indices.append(i1)
			indices.append(i2)
			indices.append(i1)
			indices.append(i3)
			indices.append(i2)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _terrain_material)
	_terrain_mesh_instance.mesh = mesh
	if update_collision:
		_terrain_collision.shape = mesh.create_trimesh_shape()


func _build_grid_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var y := 0.12
	for line in range(0, TERRAIN_CELLS + 1, 4):
		var p := float(line) * CELL_SIZE_M
		vertices.append(Vector3(p, y, 0.0))
		vertices.append(Vector3(p, y, TERRAIN_SIZE_M))
		vertices.append(Vector3(0.0, y, p))
		vertices.append(Vector3(TERRAIN_SIZE_M, y, p))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return mesh


func _calculate_normal(sample_x: int, sample_z: int) -> Vector3:
	var west := _height_at_sample(sample_x - 1, sample_z)
	var east := _height_at_sample(sample_x + 1, sample_z)
	var north := _height_at_sample(sample_x, sample_z - 1)
	var south := _height_at_sample(sample_x, sample_z + 1)
	return Vector3(west - east, 2.0 * CELL_SIZE_M, north - south).normalized()


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

	var hit := _terrain_hit_from_screen(event.position)
	if hit.is_empty():
		return
	_stamp_sculpt(hit["position"], event.shift_pressed)
	get_viewport().set_input_as_handled()


func _begin_sculpt_at_screen(screen_position: Vector2, invert_raise_lower: bool) -> void:
	var hit := _terrain_hit_from_screen(screen_position)
	if hit.is_empty():
		_update_status("Point at the visible terrain to sculpt")
		return

	var position: Vector3 = hit["position"]
	_is_sculpting = true
	_stroke_before = _height_samples.duplicate()
	_stroke_changed = false
	_stroke_flatten_height = _height_at_world(position)
	_stamp_sculpt(position, invert_raise_lower)
	get_viewport().set_input_as_handled()


func _stamp_sculpt(world_position: Vector3, invert_raise_lower: bool) -> void:
	var sample_center := _world_to_sample(world_position)
	var sample_radius := ceili(_brush_radius_m / CELL_SIZE_M)
	var source := _height_samples.duplicate()
	var strength := clampf(_brush_strength_percent / 100.0, 0.0, 1.0)
	var direction := -1.0 if invert_raise_lower else 1.0
	if _sculpt_mode == "Lower":
		direction *= -1.0

	for z in range(maxi(0, sample_center.y - sample_radius), mini(TERRAIN_SAMPLES, sample_center.y + sample_radius + 1)):
		for x in range(maxi(0, sample_center.x - sample_radius), mini(TERRAIN_SAMPLES, sample_center.x + sample_radius + 1)):
			var sample_position := Vector2(float(x) * CELL_SIZE_M, float(z) * CELL_SIZE_M)
			var center_position := Vector2(world_position.x, world_position.z)
			var distance := sample_position.distance_to(center_position)
			if distance > _brush_radius_m:
				continue

			var radius_denominator := _brush_radius_m
			if radius_denominator < 0.001:
				radius_denominator = 0.001
			var weight := _falloff_weight(distance / radius_denominator)
			var index := _sample_index(x, z)
			var current := source[index]
			var next := current
			match _sculpt_mode:
				"Raise", "Lower":
					next = current + direction * strength * weight * 1.25
				"Smooth":
					next = lerpf(current, _average_height_from(source, x, z), strength * weight * 0.45)
				"Flatten":
					next = lerpf(current, _stroke_flatten_height, strength * weight * 0.55)

			next = clampf(next, -24.0, 48.0)
			if absf(next - _height_samples[index]) > 0.001:
				_height_samples[index] = next
				_stroke_changed = true

	_rebuild_terrain_mesh(false)
	_update_status("Sculpting terrain", "Dirty")


func _finish_sculpt_stroke() -> void:
	_is_sculpting = false
	if not _stroke_changed:
		_update_status("Sculpt stroke had no terrain changes")
		return

	_undo_stack.append({"before": _packed_heights_to_array(_stroke_before), "after": _serialize_heights()})
	_redo_stack.clear()
	_dirty = true
	_rebuild_terrain_mesh(true)
	_update_status("Sculpt stroke committed", "Dirty")


func _place_prop_at_screen(screen_position: Vector2) -> void:
	var hit := _terrain_hit_from_screen(screen_position)
	if hit.is_empty():
		_update_status("Point at the visible terrain to place")
		return

	var prop := _create_tree_prop(hit["position"])
	_selected_prop = prop
	_dirty = true
	_editor_shell.set_selection_summary(prop.name)
	_update_status("Placed %s" % prop.name, "Dirty")
	get_viewport().set_input_as_handled()


func _select_prop_at_screen(screen_position: Vector2) -> void:
	_selected_prop = _pick_prop(screen_position)
	if _selected_prop == null:
		_editor_shell.set_selection_summary("None")
		_update_status("No placed object under cursor")
	else:
		_editor_shell.set_selection_summary(_selected_prop.name)
		_update_status("Selected %s" % _selected_prop.name)
	get_viewport().set_input_as_handled()


func _terrain_hit_from_screen(screen_position: Vector2) -> Dictionary:
	var origin := _camera.project_ray_origin(screen_position)
	var direction := _camera.project_ray_normal(screen_position)
	if is_zero_approx(direction.y):
		return {}

	var t := -origin.y / direction.y
	if t < 0.0 or t > TERRAIN_RAY_LENGTH_M:
		return {}

	var world_hit := origin + direction * t
	if world_hit.x < 0.0 or world_hit.x > TERRAIN_SIZE_M or world_hit.z < 0.0 or world_hit.z > TERRAIN_SIZE_M:
		return {}

	world_hit.y = _height_at_world(world_hit)
	return {"position": world_hit}


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


func _create_starter_props() -> void:
	_clear_props()
	_create_tree_prop(Vector3(34.0, _height_at_world_xz(34.0, 38.0), 38.0))
	_create_tree_prop(Vector3(54.0, _height_at_world_xz(54.0, 46.0), 46.0))
	_create_tree_prop(Vector3(92.0, _height_at_world_xz(92.0, 80.0), 80.0))


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
	canopy.position = Vector3(0.0, 3.7, 0.0)
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
	return prop


func _get_prop_material(key: String, color: Color) -> StandardMaterial3D:
	if _prop_materials.has(key):
		return _prop_materials[key]

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	_prop_materials[key] = material
	return material


func _on_action_requested(action_name: String) -> void:
	match action_name:
		"New":
			_generate_starter_terrain()
			_rebuild_terrain_mesh()
			_create_starter_props()
			_editor_shell.set_selection_summary("None")
			_update_status("New starter world ready")
		"Open":
			_open_quick_save()
		"Save":
			_save_quick_snapshot("Saved quick world snapshot")
		"Undo":
			_undo()
		"Redo":
			_redo()
		"Build":
			_update_status("Build mode: Sculpt and Place are live")
		"Play":
			_update_status("Play view comes after editing feels good")
		"Export":
			_save_quick_snapshot("Quick save refreshed; GitHub Pages exports on push")
		"Settings":
			_toggle_grid()


func _undo() -> void:
	if _undo_stack.is_empty():
		_update_status("Nothing to undo")
		return

	var command := _undo_stack.pop_back() as Dictionary
	var before = command.get("before", [])
	if not (before is Array):
		_update_status("Undo data was invalid")
		return
	_redo_stack.append(command)
	_load_heights(before)
	_dirty = true
	_rebuild_terrain_mesh()
	_update_status("Undo terrain stroke", "Dirty")


func _redo() -> void:
	if _redo_stack.is_empty():
		_update_status("Nothing to redo")
		return

	var command := _redo_stack.pop_back() as Dictionary
	var after = command.get("after", [])
	if not (after is Array):
		_update_status("Redo data was invalid")
		return
	_undo_stack.append(command)
	_load_heights(after)
	_dirty = true
	_rebuild_terrain_mesh()
	_update_status("Redo terrain stroke", "Dirty")


func _save_quick_snapshot(success_message: String) -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		_update_status("Save failed: user storage unavailable")
		return

	var dir_error := dir.make_dir_recursive("worlds")
	if dir_error != OK:
		_update_status("Save failed: %s" % error_string(dir_error))
		return

	var file := FileAccess.open(QUICK_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_update_status("Save failed: %s" % error_string(FileAccess.get_open_error()))
		return

	var payload := {
		"format": "world_smithr",
		"version": 2,
		"heights": _serialize_heights(),
		"props": _serialize_props(),
	}
	file.store_string(JSON.stringify(payload, "\t"))
	_dirty = false
	_update_status(success_message)


func _open_quick_save() -> void:
	if not FileAccess.file_exists(QUICK_SAVE_PATH):
		_update_status("No quick save found yet")
		return

	var file := FileAccess.open(QUICK_SAVE_PATH, FileAccess.READ)
	if file == null:
		_update_status("Open failed: %s" % error_string(FileAccess.get_open_error()))
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		_update_status("Open failed: save file is not JSON")
		return

	var save_data := parsed as Dictionary
	var heights_value = save_data.get("heights", [])
	if heights_value is Array:
		_load_heights(heights_value)
		_rebuild_terrain_mesh()

	_clear_props()
	var props_value = save_data.get("props", [])
	if props_value is Array:
		_restore_props(props_value)
	_dirty = false
	_undo_stack.clear()
	_redo_stack.clear()
	_editor_shell.set_selection_summary("None")
	_update_status("Opened quick save")


func _serialize_heights() -> Array:
	return _packed_heights_to_array(_height_samples)


func _packed_heights_to_array(source: PackedFloat32Array) -> Array:
	var values := []
	values.resize(source.size())
	for i in range(source.size()):
		values[i] = source[i]
	return values


func _load_heights(values: Array) -> void:
	_height_samples.resize(TERRAIN_SAMPLES * TERRAIN_SAMPLES)
	for i in range(_height_samples.size()):
		if i < values.size():
			_height_samples[i] = float(values[i])
		else:
			_height_samples[i] = 0.0


func _serialize_props() -> Array:
	var props := []
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


func _clear_props() -> void:
	_selected_prop = null
	if _props_root == null:
		return
	for child in _props_root.get_children():
		child.free()


func _toggle_grid() -> void:
	_debug_grid_visible = not _debug_grid_visible
	_grid_mesh_instance.visible = _debug_grid_visible
	var state := "shown" if _debug_grid_visible else "hidden"
	_update_status("Terrain grid %s" % state)


func _on_tool_selected(tool_name: String) -> void:
	_active_tool = tool_name
	_editor_shell.set_tool_hint(_hint_for_tool(tool_name))
	match tool_name:
		"Sculpt":
			_update_status("Sculpt: drag terrain; Shift flips Raise/Lower")
		"Place":
			_update_status("Place: click terrain to drop trees")
		"Select":
			_update_status("Select: click a tree")


func _hint_for_tool(tool_name: String) -> String:
	match tool_name:
		"Sculpt":
			return "Drag on terrain to shape it. Shift flips Raise and Lower."
		"Place":
			return "Click terrain to place a low-poly tree."
		"Select":
			return "Click a placed tree to inspect it."
	return "Sculpt, Place, Save, and Open are live."


func _on_sculpt_mode_selected(mode_name: String) -> void:
	_sculpt_mode = mode_name
	_update_status("Sculpt mode: %s" % mode_name)


func _on_brush_radius_changed(value: float) -> void:
	_brush_radius_m = value


func _on_brush_strength_changed(value: float) -> void:
	_brush_strength_percent = value


func _on_brush_falloff_selected(falloff_name: String) -> void:
	_brush_falloff = falloff_name


func _falloff_weight(normalized_distance: float) -> float:
	var t := clampf(normalized_distance, 0.0, 1.0)
	match _brush_falloff:
		"Hard":
			return 1.0
		"Linear":
			return 1.0 - t
	return 1.0 - (t * t * (3.0 - 2.0 * t))


func _average_height_from(source: PackedFloat32Array, sample_x: int, sample_z: int) -> float:
	var total := 0.0
	var count := 0
	for z in range(maxi(0, sample_z - 1), mini(TERRAIN_SAMPLES, sample_z + 2)):
		for x in range(maxi(0, sample_x - 1), mini(TERRAIN_SAMPLES, sample_x + 2)):
			total += source[_sample_index(x, z)]
			count += 1
	return total / float(maxi(count, 1))


func _height_at_world(world_position: Vector3) -> float:
	return _height_at_world_xz(world_position.x, world_position.z)


func _height_at_world_xz(world_x: float, world_z: float) -> float:
	var sample_x := clampf(world_x / CELL_SIZE_M, 0.0, float(TERRAIN_CELLS))
	var sample_z := clampf(world_z / CELL_SIZE_M, 0.0, float(TERRAIN_CELLS))
	var x0 := floori(sample_x)
	var z0 := floori(sample_z)
	var x1 := mini(x0 + 1, TERRAIN_CELLS)
	var z1 := mini(z0 + 1, TERRAIN_CELLS)
	var tx := sample_x - float(x0)
	var tz := sample_z - float(z0)
	var north := lerpf(_height_at_sample(x0, z0), _height_at_sample(x1, z0), tx)
	var south := lerpf(_height_at_sample(x0, z1), _height_at_sample(x1, z1), tx)
	return lerpf(north, south, tz)


func _world_to_sample(world_position: Vector3) -> Vector2i:
	return Vector2i(
		mini(maxi(roundi(world_position.x / CELL_SIZE_M), 0), TERRAIN_CELLS),
		mini(maxi(roundi(world_position.z / CELL_SIZE_M), 0), TERRAIN_CELLS)
	)


func _height_at_sample(sample_x: int, sample_z: int) -> float:
	var x := mini(maxi(sample_x, 0), TERRAIN_CELLS)
	var z := mini(maxi(sample_z, 0), TERRAIN_CELLS)
	return _height_samples[_sample_index(x, z)]


func _sample_index(sample_x: int, sample_z: int) -> int:
	return sample_z * TERRAIN_SAMPLES + sample_x


func _update_status(message: String, autosave_state: String = "") -> void:
	var state := autosave_state
	if state.is_empty():
		state = "Dirty" if _dirty else "Idle"
	_editor_shell.set_status(message, Vector2i.ZERO, state, _props_root.get_child_count())
