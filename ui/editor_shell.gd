extends Control
class_name EditorShell

signal action_requested(action_name: String)
signal tool_selected(tool_name: String)
signal sculpt_mode_selected(mode_name: String)
signal brush_radius_changed(value: float)
signal brush_strength_changed(value: float)
signal brush_falloff_selected(falloff_name: String)

const PRODUCT_NAME := "World Smithr"
const LIVE_TOOLS := ["Select", "Sculpt", "Place"]

var _status_label: Label
var _chunk_label: Label
var _autosave_label: Label
var _fps_label: Label
var _object_count_label: Label
var _tool_value_label: Label
var _selection_value_label: Label
var _tool_hint_label: Label
var _radius_value_label: Label
var _strength_value_label: Label
var _falloff_options: OptionButton
var _mode_options: OptionButton
var _sculpt_settings_group: VBoxContainer
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


func set_active_tool(tool_name: String) -> void:
	for key in _tool_buttons.keys():
		var button := _tool_buttons[key] as Button
		button.button_pressed = key == tool_name
	if _tool_value_label != null:
		_tool_value_label.text = "Tool: %s" % tool_name
	if _sculpt_settings_group != null:
		_sculpt_settings_group.visible = tool_name == "Sculpt"


func set_tool_hint(summary: String) -> void:
	if _tool_hint_label != null:
		_tool_hint_label.text = summary


func set_selection_summary(summary: String) -> void:
	if _selection_value_label != null:
		_selection_value_label.text = "Selection: %s" % summary


func set_sculpt_settings(mode_name: String, radius_m: float, strength_percent: float, falloff_name: String) -> void:
	if _mode_options != null:
		_select_option_by_text(_mode_options, mode_name)
	if _radius_value_label != null:
		_radius_value_label.text = "Brush radius: %d m" % roundi(radius_m)
	if _strength_value_label != null:
		_strength_value_label.text = "Strength: %d%%" % roundi(strength_percent)
	if _falloff_options != null:
		_select_option_by_text(_falloff_options, falloff_name)


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
		if LIVE_TOOLS.has(tool_name):
			button.pressed.connect(_on_tool_pressed.bind(tool_name))
		else:
			button.disabled = true
			button.tooltip_text = "%s comes after Sculpt and Place" % tool_name
		_tool_buttons[tool_name] = button
		column.add_child(button)

	set_active_tool("Sculpt")


func _build_right_panel() -> void:
	var panel := _make_panel("InspectorPanel", Color(0.08, 0.10, 0.11, 0.9))
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -286.0
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
	_tool_value_label = _make_small_label("Tool: Sculpt")
	column.add_child(_tool_value_label)
	_selection_value_label = _make_small_label("Selection: None")
	column.add_child(_selection_value_label)
	_tool_hint_label = _make_small_label("Brush: terrain sculpt")
	column.add_child(_tool_hint_label)
	column.add_child(_make_separator(false))

	_sculpt_settings_group = VBoxContainer.new()
	_sculpt_settings_group.add_theme_constant_override("separation", 8)
	column.add_child(_sculpt_settings_group)

	_sculpt_settings_group.add_child(_make_small_label("Sculpt mode"))
	_mode_options = OptionButton.new()
	for mode_name in ["Raise", "Lower", "Smooth", "Flatten"]:
		_mode_options.add_item(mode_name)
	_mode_options.item_selected.connect(_on_sculpt_mode_item_selected)
	_sculpt_settings_group.add_child(_mode_options)

	_radius_value_label = _make_small_label("Brush radius: 8 m")
	_sculpt_settings_group.add_child(_radius_value_label)
	var radius_slider := HSlider.new()
	radius_slider.min_value = 2.0
	radius_slider.max_value = 24.0
	radius_slider.step = 1.0
	radius_slider.value = 8.0
	radius_slider.value_changed.connect(_on_radius_changed)
	_sculpt_settings_group.add_child(radius_slider)

	_strength_value_label = _make_small_label("Strength: 50%")
	_sculpt_settings_group.add_child(_strength_value_label)
	var strength_slider := HSlider.new()
	strength_slider.min_value = 0.0
	strength_slider.max_value = 100.0
	strength_slider.step = 1.0
	strength_slider.value = 50.0
	strength_slider.value_changed.connect(_on_strength_changed)
	_sculpt_settings_group.add_child(strength_slider)

	_sculpt_settings_group.add_child(_make_small_label("Falloff"))
	_falloff_options = OptionButton.new()
	for falloff_name in ["Hard", "Linear", "Smooth"]:
		_falloff_options.add_item(falloff_name)
	_select_option_by_text(_falloff_options, "Smooth")
	_falloff_options.item_selected.connect(_on_falloff_item_selected)
	_sculpt_settings_group.add_child(_falloff_options)


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


func _select_option_by_text(options: OptionButton, text: String) -> void:
	for index in range(options.get_item_count()):
		if options.get_item_text(index) == text:
			options.select(index)
			return


func _on_action_pressed(action_name: String) -> void:
	set_status("%s requested" % action_name, Vector2i.ZERO, "Idle", 0)
	action_requested.emit(action_name)


func _on_tool_pressed(tool_name: String) -> void:
	set_active_tool(tool_name)
	set_tool_hint(_fallback_hint_for_tool(tool_name))
	set_status(_fallback_status_for_tool(tool_name), Vector2i.ZERO, "Idle", 0)
	tool_selected.emit(tool_name)


func _fallback_hint_for_tool(tool_name: String) -> String:
	match tool_name:
		"Sculpt":
			return "Drag on terrain to shape it."
		"Place":
			return "Click terrain to place a low-poly tree."
		"Select":
			return "Click a placed tree to inspect it."
	return "%s comes after the core builder." % tool_name


func _fallback_status_for_tool(tool_name: String) -> String:
	match tool_name:
		"Sculpt":
			return "Sculpt selected"
		"Place":
			return "Place selected"
		"Select":
			return "Select selected"
	return "%s is not active yet" % tool_name


func _on_sculpt_mode_item_selected(index: int) -> void:
	var mode_name := _mode_options.get_item_text(index)
	sculpt_mode_selected.emit(mode_name)


func _on_radius_changed(value: float) -> void:
	_radius_value_label.text = "Brush radius: %d m" % roundi(value)
	brush_radius_changed.emit(value)


func _on_strength_changed(value: float) -> void:
	_strength_value_label.text = "Strength: %d%%" % roundi(value)
	brush_strength_changed.emit(value)


func _on_falloff_item_selected(index: int) -> void:
	brush_falloff_selected.emit(_falloff_options.get_item_text(index))
