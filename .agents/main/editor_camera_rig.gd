extends Node3D
class_name EditorCameraRig

@export_range(8.0, 80.0, 1.0) var min_distance := 14.0
@export_range(80.0, 220.0, 1.0) var max_distance := 150.0
@export var orbit_sensitivity := 0.008
@export var pan_sensitivity := 0.0015
@export var zoom_step := 5.0

@onready var _pivot: Node3D = $Pivot
@onready var _camera: Camera3D = $Pivot/Camera3D

var _distance := 96.0
var _yaw := deg_to_rad(45.0)
var _pitch := deg_to_rad(-55.0)
var _orbiting := false
var _panning := false


func _ready() -> void:
	_camera.far = 320.0
	_apply_camera_transform()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)
	elif event is InputEventKey:
		_handle_key(event as InputEventKey)


func frame_origin() -> void:
	global_position = Vector3(32.0, 0.0, 32.0)
	_distance = clampf(96.0, min_distance, max_distance)
	_apply_camera_transform()


func set_perspective_view() -> void:
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_yaw = deg_to_rad(45.0)
	_pitch = deg_to_rad(-55.0)
	_distance = clampf(96.0, min_distance, max_distance)
	_apply_camera_transform()


func set_top_view() -> void:
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 128.0
	_yaw = 0.0
	_pitch = deg_to_rad(-89.0)
	_distance = clampf(120.0, min_distance, max_distance)
	_apply_camera_transform()


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_MIDDLE:
		_orbiting = event.pressed and not event.shift_pressed
		_panning = event.pressed and event.shift_pressed
		get_viewport().set_input_as_handled()
	elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		_distance = clampf(_distance - zoom_step, min_distance, max_distance)
		_apply_camera_transform()
		get_viewport().set_input_as_handled()
	elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		_distance = clampf(_distance + zoom_step, min_distance, max_distance)
		_apply_camera_transform()
		get_viewport().set_input_as_handled()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _orbiting:
		_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		_yaw -= event.relative.x * orbit_sensitivity
		_pitch = clampf(_pitch - event.relative.y * orbit_sensitivity, deg_to_rad(-82.0), deg_to_rad(-8.0))
		_apply_camera_transform()
		get_viewport().set_input_as_handled()
	elif _panning:
		var basis := _camera.global_transform.basis
		var scale := pan_sensitivity * _distance
		global_position += (-basis.x * event.relative.x + basis.y * event.relative.y) * scale
		get_viewport().set_input_as_handled()


func _handle_key(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return

	if event.keycode == KEY_F:
		frame_origin()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_1:
		set_perspective_view()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_2:
		set_top_view()
		get_viewport().set_input_as_handled()


func _apply_camera_transform() -> void:
	_pivot.rotation = Vector3(_pitch, _yaw, 0.0)
	_camera.position = Vector3(0.0, 0.0, _distance)
