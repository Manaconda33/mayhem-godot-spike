extends CanvasLayer
class_name KartTouchControls

var _control_root: Control
var _buttons: Dictionary = {}
var _pointer_actions: Dictionary = {}


func _ready() -> void:
	_control_root = Control.new()
	_control_root.name = "TouchButtons"
	_control_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_control_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_control_root)
	get_viewport().size_changed.connect(_layout_buttons)
	_create_button("◀", KartTuning.STEER_LEFT_ACTION, KartTuning.HUD_TOUCH_STEER_LEFT_POSITION, KartTuning.HUD_TOUCH_BUTTON_SIZE)
	_create_button("▶", KartTuning.STEER_RIGHT_ACTION, KartTuning.HUD_TOUCH_STEER_RIGHT_POSITION, KartTuning.HUD_TOUCH_BUTTON_SIZE)
	_create_button("GAS", KartTuning.ACCELERATE_ACTION, KartTuning.HUD_TOUCH_GAS_POSITION, KartTuning.HUD_TOUCH_BUTTON_SIZE)
	_create_button("BRAKE", KartTuning.BRAKE_ACTION, KartTuning.HUD_TOUCH_BRAKE_POSITION, KartTuning.HUD_TOUCH_BUTTON_SIZE)
	_create_button("DRIFT", KartTuning.DRIFT_ACTION, KartTuning.HUD_TOUCH_DRIFT_POSITION, KartTuning.HUD_TOUCH_BUTTON_SIZE)
	_create_button("RESET", KartTuning.RESPAWN_ACTION, KartTuning.HUD_TOUCH_RESET_POSITION, KartTuning.HUD_TOUCH_RESET_SIZE)
	_layout_buttons()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_all_pointers()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_update_pointer(event.index, event.position, event.pressed)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if _pointer_actions.has(event.index):
			_update_pointer(event.index, event.position, true)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# On touch devices, keep separate screen pointers; the emulated mouse is for ordinary Buttons.
		if DisplayServer.is_touchscreen_available():
			return
		_update_pointer(-1, event.position, event.pressed)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _pointer_actions.has(-1) and not DisplayServer.is_touchscreen_available():
		_update_pointer(-1, event.position, true)
		get_viewport().set_input_as_handled()


func _create_button(label_text: String, action: String, offset_position: Vector2, size: Vector2) -> void:
	var button := Button.new()
	button.name = action
	button.text = label_text
	button.custom_minimum_size = size
	button.size = size
	button.add_theme_font_size_override("font_size", KartTuning.HUD_BUTTON_FONT)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.modulate = Color(1.0, 1.0, 1.0, 0.76)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.11, 0.14, 0.68)
	normal.border_color = Color(0.92, 0.95, 0.96, 0.45)
	normal.set_border_width_all(KartTuning.HUD_TOUCH_BORDER_WIDTH)
	normal.set_corner_radius_all(KartTuning.HUD_TOUCH_CORNER_RADIUS)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", normal)
	_control_root.add_child(button)
	_buttons[action] = {"control": button, "offset": offset_position, "size": size}


func _layout_buttons() -> void:
	if _control_root == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	for action in _buttons:
		var entry: Dictionary = _buttons[action]
		var button: Button = entry["control"]
		var offset: Vector2 = entry["offset"]
		var size: Vector2 = entry["size"]
		var x := offset.x if offset.x >= 0.0 else viewport_size.x + offset.x
		var y := viewport_size.y + offset.y
		button.position = Vector2(x, y)
		button.size = size
		button.custom_minimum_size = size


func _update_pointer(pointer_id: int, position: Vector2, pressed: bool) -> void:
	var old_action: String = _pointer_actions.get(pointer_id, "")
	if not pressed:
		if not old_action.is_empty():
			Input.action_release(old_action)
			_pointer_actions.erase(pointer_id)
		return
	var new_action := _action_at(position)
	if new_action == old_action:
		return
	if not old_action.is_empty():
		Input.action_release(old_action)
		_pointer_actions.erase(pointer_id)
	if not new_action.is_empty():
		Input.action_press(new_action)
		_pointer_actions[pointer_id] = new_action


func _action_at(position: Vector2) -> String:
	for action in _buttons:
		var button: Button = _buttons[action]["control"]
		if button.get_global_rect().has_point(position):
			return action
	return ""


func _release_all_pointers() -> void:
	for action in _pointer_actions.values():
		Input.action_release(action)
	_pointer_actions.clear()
