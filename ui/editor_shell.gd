extends Control
class_name EditorShell

const PRODUCT_NAME := "World Smithr"

var _status_label: Label
var _chunk_label: Label
var _autosave_label: Label
var _fps_label: Label
var _object_count_label: Label
var _tool_buttons: Dictionary = {}


func _ready() -> void:
	set_process(true)
	_build_shell()
	set_status("Ready", Vector2i.ZERO, "Idle", 0)


func _process(_delta: float) -> void:
	if _fps_label != null:
		_fps_label.text = "FPS %d" % Engine.get_frames_per_second()


func set_status(message: String, chunk: Vector2i, autosave_state: String, object_count: int) -> void:
	if _status_label != null:
		_status_label.text = message
	if _chunk_label != null:
		_chunk_label.text = "Chunk %d,%d" % [chunk.x, chunk.y]
	if _autosave_label != null:
		_autosave_label.text = "Autosave %s" % autosave_state
	if _object_count_label != null:
		_object_count_label.text = "Objects %d" % object_count


func _build_shell() -> void:
	_build_top_bar()
	_build_left_rail()
	_build_right_panel()
	_build_bottom_bar()


func _build_top_bar() -> void:
	var panel := _make_panel("TopBar", Color(0.07, 0.09, 0.10, 0.92))
	panel.anchor_right = 1.0
	panel.offset_bottom = 46.0

	var margin := _make_margin(10, 6, 10, 6)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(row)

	var title := Label.new()
	title.text = PRODUCT_NAME
	title.custom_minimum_size = Vector2(150.0, 0.0)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	row.add_child(title)

	for label in ["New", "Open", "Save", "Undo", "Redo"]:
		row.add_child(_make_button(label))

	row.add_child(_make_separator(true))
	row.add_child(_make_button("Build"))
	row.add_child(_make_button("Play"))
	row.add_child(_make_separator(true))
	row.add_child(_make_button("Export"))
	row.add_child(_make_button("Settings"))


func _build_left_rail() -> void:
	var panel := _make_panel("ToolRail", Color(0.08, 0.10, 0.11, 0.9))
	panel.anchor_bottom = 1.0
	panel.offset_top = 54.0
	panel.offset_right = 118.0
	panel.offset_bottom = -34.0

	var margin := _make_margin(8, 8, 8, 8)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)

	for tool_name in ["Select", "Sculpt", "Paint", "Path", "Water", "Place"]:
		var button := _make_button(tool_name, true)
		button.custom_minimum_size = Vector2(96.0, 34.0)
		button.pressed.connect(_on_tool_pressed.bind(tool_name))
		_tool_buttons[tool_name] = button
		column.add_child(button)

	(_tool_buttons["Select"] as Button).button_pressed = true


func _build_right_panel() -> void:
	var panel := _make_panel("InspectorPanel", Color(0.08, 0.10, 0.11, 0.9))
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -276.0
	panel.offset_top = 54.0
	panel.offset_bottom = -34.0

	var margin := _make_margin(12, 12, 12, 12)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var header := Label.new()
	header.text = "Tool Settings"
	header.add_theme_font_size_override("font_size", 16)
	column.add_child(header)

	column.add_child(_make_separator(false))
	column.add_child(_make_small_label("Mode: Build"))
	column.add_child(_make_small_label("Tool: Select"))
	column.add_child(_make_small_label("Selection: None"))
	column.add_child(_make_separator(false))
	column.add_child(_make_small_label("Brush radius: 8 m"))
	column.add_child(_make_small_label("Strength: 50%"))
	column.add_child(_make_small_label("Falloff: Smooth"))


func _build_bottom_bar() -> void:
	var panel := _make_panel("BottomStatusBar", Color(0.07, 0.09, 0.10, 0.94))
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -30.0

	var margin := _make_margin(10, 4, 10, 4)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)

	_status_label = _make_small_label("Ready")
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_status_label)

	_chunk_label = _make_small_label("Chunk 0,0")
	row.add_child(_chunk_label)

	_autosave_label = _make_small_label("Autosave Idle")
	row.add_child(_autosave_label)

	_fps_label = _make_small_label("FPS 0")
	row.add_child(_fps_label)

	_object_count_label = _make_small_label("Objects 0")
	row.add_child(_object_count_label)


func _make_button(label: String, toggle: bool = false) -> Button:
	var button := Button.new()
	button.text = label
	button.toggle_mode = toggle
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = label
	button.custom_minimum_size = Vector2(70.0, 30.0)
	if not toggle:
		button.pressed.connect(_on_action_pressed.bind(label))
	return button


func _make_small_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _make_panel(panel_name: String, color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = panel_name
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.22, 0.26, 0.25, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)

	add_child(panel)
	return panel


func _make_margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


func _make_separator(vertical: bool) -> Control:
	if vertical:
		var separator := VSeparator.new()
		separator.custom_minimum_size = Vector2(8.0, 0.0)
		return separator

	var separator := HSeparator.new()
	separator.custom_minimum_size = Vector2(0.0, 8.0)
	return separator


func _on_action_pressed(action_name: String) -> void:
	set_status("%s is queued for a later phase" % action_name, Vector2i.ZERO, "Idle", 0)


func _on_tool_pressed(tool_name: String) -> void:
	for key in _tool_buttons.keys():
		var button := _tool_buttons[key] as Button
		button.button_pressed = key == tool_name

	set_status("%s tool selected" % tool_name, Vector2i.ZERO, "Idle", 0)
