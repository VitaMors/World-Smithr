extends Node

const PRODUCT_NAME = "World Smithr"
const BOARD_SIZE = 128.0
const RAY_LENGTH = 600.0
const PROP_LAYER = 2
const QUICK_SAVE_PATH = "user://worlds/world_smithr_quick_save.json"

@onready var ui = $UI/EditorShell
@onready var world_root = $WorldRoot
@onready var camera_rig = $EditorCameraRig
@onready var camera_pivot = $EditorCameraRig/Pivot
@onready var camera = $EditorCameraRig/Pivot/Camera3D

var active_tool = "Sculpt"
var runtime_root = null
var selected_object = null
var next_id = 1
var undo_stack = []
var redo_stack = []
var dirty = false
var sculpting = false
var last_sculpt_position = Vector3.ZERO
var has_last_sculpt_position = false
var materials = {}


func _ready():
	DisplayServer.window_set_title(PRODUCT_NAME)
	_setup_camera()
	_setup_runtime_root()
	_connect_ui()
	_update_status("Ready: Sculpt stamps hills, Place drops trees")


func _setup_camera():
	camera_rig.global_position = Vector3(64.0, 0.0, 64.0)
	camera_pivot.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(45.0), 0.0)
	camera.position = Vector3(0.0, 0.0, 120.0)
	camera.current = true
	camera.far = 420.0


func _setup_runtime_root():
	runtime_root = world_root.get_node_or_null("RuntimeBuilderObjects")
	if runtime_root == null:
		runtime_root = Node3D.new()
		runtime_root.name = "RuntimeBuilderObjects"
		world_root.add_child(runtime_root)


func _connect_ui():
	ui.action_requested.connect(_on_action_requested)
	ui.tool_selected.connect(_on_tool_selected)
	ui.set_active_tool(active_tool)
	ui.set_tool_hint("Drag on the terrain to stamp hills.")
	ui.set_selection_summary("None")


func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_handle_left_down(event.position)
			else:
				sculpting = false
				has_last_sculpt_position = false
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if sculpting:
			var hit = _ground_hit(event.position)
			if hit.has("position"):
				var position = hit["position"]
				if not has_last_sculpt_position or position.distance_to(last_sculpt_position) >= 5.0:
					_create_mound(position, true)
					last_sculpt_position = position
					has_last_sculpt_position = true
					get_viewport().set_input_as_handled()


func _handle_left_down(screen_position):
	var hit = _ground_hit(screen_position)
	if not hit.has("position"):
		_update_status("Click inside the visible terrain board")
		return

	var position = hit["position"]
	if active_tool == "Place":
		_create_tree(position, true)
		get_viewport().set_input_as_handled()
	elif active_tool == "Sculpt":
		sculpting = true
		_create_mound(position, true)
		last_sculpt_position = position
		has_last_sculpt_position = true
		get_viewport().set_input_as_handled()
	elif active_tool == "Select":
		_select_at_screen(screen_position)
		get_viewport().set_input_as_handled()


func _ground_hit(screen_position):
	var origin = camera.project_ray_origin(screen_position)
	var direction = camera.project_ray_normal(screen_position)
	if abs(direction.y) < 0.0001:
		return {}

	var t = -origin.y / direction.y
	if t < 0.0 or t > RAY_LENGTH:
		return {}

	var position = origin + direction * t
	if position.x < 0.0 or position.z < 0.0 or position.x > BOARD_SIZE or position.z > BOARD_SIZE:
		return {}

	position.y = 0.2
	return {"position": position}


func _create_tree(position, record_history):
	var root = Node3D.new()
	root.name = _next_name("Tree")
	root.global_position = position
	root.rotation.y = deg_to_rad(float((next_id * 41) % 360))
	root.set_meta("builder_kind", "tree")

	var trunk = MeshInstance3D.new()
	var trunk_mesh = BoxMesh.new()
	trunk_mesh.size = Vector3(1.0, 4.0, 1.0)
	trunk.mesh = trunk_mesh
	trunk.position = Vector3(0.0, 2.0, 0.0)
	trunk.material_override = _material("trunk", Color(0.43, 0.25, 0.13, 1.0))
	root.add_child(trunk)

	var leaves = MeshInstance3D.new()
	var leaf_mesh = SphereMesh.new()
	leaf_mesh.radius = 2.6
	leaf_mesh.height = 3.8
	leaf_mesh.radial_segments = 12
	leaf_mesh.rings = 6
	leaves.mesh = leaf_mesh
	leaves.position = Vector3(0.0, 5.0, 0.0)
	leaves.material_override = _material("leaf", Color(0.12, 0.37, 0.16, 1.0))
	root.add_child(leaves)

	_add_pick_body(root, Vector3(5.5, 7.0, 5.5), Vector3(0.0, 3.5, 0.0))
	runtime_root.add_child(root)
	_select_object(root)
	_finish_create(root, record_history, "Placed tree")


func _create_mound(position, record_history):
	var root = Node3D.new()
	root.name = _next_name("Mound")
	root.global_position = Vector3(position.x, 0.95, position.z)
	root.scale = Vector3(6.0, 1.2, 6.0)
	root.set_meta("builder_kind", "mound")

	var mesh_instance = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 1.6
	mesh.radial_segments = 16
	mesh.rings = 8
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material("mound", Color(0.38, 0.63, 0.30, 1.0))
	root.add_child(mesh_instance)

	_add_pick_body(root, Vector3(2.0, 1.8, 2.0), Vector3.ZERO)
	runtime_root.add_child(root)
	_select_object(root)
	_finish_create(root, record_history, "Sculpted hill")


func _add_pick_body(root, size, offset):
	var body = StaticBody3D.new()
	body.name = "PickBody"
	body.collision_layer = PROP_LAYER
	body.collision_mask = 0
	var shape_node = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	shape_node.position = offset
	body.add_child(shape_node)
	root.add_child(body)


func _finish_create(root, record_history, message):
	dirty = true
	if record_history:
		undo_stack.append(_serialize_object(root))
		redo_stack.clear()
	_update_status(message, "Dirty")


func _select_at_screen(screen_position):
	var origin = camera.project_ray_origin(screen_position)
	var end = origin + camera.project_ray_normal(screen_position) * RAY_LENGTH
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = PROP_LAYER
	var result = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		_select_object(null)
		_update_status("Nothing selected")
		return

	var node = result["collider"] as Node
	while node != null:
		if node.has_meta("builder_kind"):
			_select_object(node)
			_update_status("Selected %s" % node.name)
			return
		node = node.get_parent()
	_select_object(null)
	_update_status("Nothing selected")


func _select_object(node):
	selected_object = node
	if node == null:
		ui.set_selection_summary("None")
	else:
		ui.set_selection_summary(node.name)


func _on_tool_selected(tool_name):
	active_tool = tool_name
	if active_tool == "Place":
		ui.set_tool_hint("Click terrain to place a tree.")
		_update_status("Place: click terrain to drop trees")
	elif active_tool == "Select":
		ui.set_tool_hint("Click a tree or mound to select it.")
		_update_status("Select: click an object")
	else:
		active_tool = "Sculpt"
		ui.set_tool_hint("Drag on terrain to stamp hills.")
		_update_status("Sculpt: drag terrain to stamp hills")


func _on_action_requested(action_name):
	if action_name == "New":
		_clear_runtime_objects()
		undo_stack.clear()
		redo_stack.clear()
		dirty = false
		_update_status("Cleared editable objects")
	elif action_name == "Undo":
		_undo()
	elif action_name == "Redo":
		_redo()
	elif action_name == "Save":
		_save_world()
	elif action_name == "Open":
		_open_world()
	elif action_name == "Settings":
		_toggle_starter_world()
	elif action_name == "Play":
		_update_status("Play comes after the builder works")
	elif action_name == "Build":
		_update_status("Build mode is active")
	elif action_name == "Export":
		_save_world()


func _undo():
	if undo_stack.is_empty():
		_update_status("Nothing to undo")
		return
	var data = undo_stack.pop_back()
	var node = runtime_root.get_node_or_null(str(data.get("name", "")))
	if node != null:
		node.queue_free()
	redo_stack.append(data)
	dirty = true
	_select_object(null)
	_update_status("Undo", "Dirty")


func _redo():
	if redo_stack.is_empty():
		_update_status("Nothing to redo")
		return
	var data = redo_stack.pop_back()
	_restore_object(data, false)
	undo_stack.append(data)
	dirty = true
	_update_status("Redo", "Dirty")


func _save_world():
	var dir = DirAccess.open("user://")
	if dir == null:
		_update_status("Save failed: storage unavailable")
		return
	dir.make_dir_recursive("worlds")
	var file = FileAccess.open(QUICK_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_update_status("Save failed")
		return
	var objects = []
	for child in runtime_root.get_children():
		objects.append(_serialize_object(child))
	file.store_string(JSON.stringify({"format": "world_smithr", "version": 3, "objects": objects}, "\t"))
	dirty = false
	_update_status("Saved local world")


func _open_world():
	if not FileAccess.file_exists(QUICK_SAVE_PATH):
		_update_status("No local save yet")
		return
	var file = FileAccess.open(QUICK_SAVE_PATH, FileAccess.READ)
	if file == null:
		_update_status("Open failed")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		_update_status("Open failed: bad save")
		return
	_clear_runtime_objects()
	var objects = parsed.get("objects", [])
	if objects is Array:
		for item in objects:
			if item is Dictionary:
				_restore_object(item, false)
	undo_stack.clear()
	redo_stack.clear()
	dirty = false
	_update_status("Opened local world")


func _serialize_object(node):
	return {
		"name": node.name,
		"kind": str(node.get_meta("builder_kind", "tree")),
		"x": node.global_position.x,
		"y": node.global_position.y,
		"z": node.global_position.z,
		"scale_x": node.scale.x,
		"scale_y": node.scale.y,
		"scale_z": node.scale.z,
		"rotation_y": node.rotation.y
	}


func _restore_object(data, record_history):
	var position = Vector3(float(data.get("x", 64.0)), float(data.get("y", 0.2)), float(data.get("z", 64.0)))
	var kind = str(data.get("kind", "tree"))
	if kind == "mound":
		_create_mound(position, record_history)
	else:
		_create_tree(position, record_history)
	var node = selected_object
	if node != null:
		node.name = str(data.get("name", node.name))
		node.scale = Vector3(float(data.get("scale_x", node.scale.x)), float(data.get("scale_y", node.scale.y)), float(data.get("scale_z", node.scale.z)))
		node.rotation.y = float(data.get("rotation_y", node.rotation.y))


func _clear_runtime_objects():
	_select_object(null)
	for child in runtime_root.get_children():
		child.queue_free()


func _toggle_starter_world():
	var starter = world_root.get_node_or_null("StarterWorld")
	if starter == null:
		_update_status("Starter world is not available")
		return
	starter.visible = not starter.visible
	var state = "shown"
	if not starter.visible:
		state = "hidden"
	_update_status("Starter world %s" % state)


func _next_name(prefix):
	var name = "%s_%03d" % [prefix, next_id]
	next_id += 1
	return name


func _material(key, color):
	if materials.has(key):
		return materials[key]
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	materials[key] = material
	return material


func _update_status(message, autosave_state = ""):
	var state = autosave_state
	if state == "":
		if dirty:
			state = "Dirty"
		else:
			state = "Idle"
	ui.set_status(message, Vector2i.ZERO, state, runtime_root.get_child_count())