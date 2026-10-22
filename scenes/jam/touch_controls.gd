extends Control
class_name JamTouchControls

var _button_nodes: Array[Button] = []
var _joystick_vector := Vector2.ZERO
var _touch_index := -1
var _mouse_dragging := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_buttons()
	_resized()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_resized()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index < 0 and _joystick_rect().has_point(event.position):
			_touch_index = event.index
			_update_joystick(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			_set_joystick(Vector2.ZERO)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update_joystick(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# On touch devices, avoid the synthetic mouse moving the joystick when another finger presses a button.
		if DisplayServer.is_touchscreen_available():
			return
		if event.pressed and _joystick_rect().has_point(event.position):
			_mouse_dragging = true
			_update_joystick(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and _mouse_dragging:
			_mouse_dragging = false
			_set_joystick(Vector2.ZERO)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _mouse_dragging and not DisplayServer.is_touchscreen_available():
		_update_joystick(event.position)
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	_set_joystick(Vector2.ZERO)
	for action in [JamTuning.PASS_ACTION, JamTuning.SHOOT_ACTION, JamTuning.TURBO_ACTION]:
		Input.action_release(action)


func _build_buttons() -> void:
	var pass_button := _make_button("PASS")
	var shoot_button := _make_button("SHOOT")
	var turbo_button := _make_button("TURBO")
	pass_button.button_down.connect(_set_action.bind(JamTuning.PASS_ACTION, true))
	pass_button.button_up.connect(_set_action.bind(JamTuning.PASS_ACTION, false))
	shoot_button.button_down.connect(_set_action.bind(JamTuning.SHOOT_ACTION, true))
	shoot_button.button_up.connect(_set_action.bind(JamTuning.SHOOT_ACTION, false))
	turbo_button.button_down.connect(_set_action.bind(JamTuning.TURBO_ACTION, true))
	turbo_button.button_up.connect(_set_action.bind(JamTuning.TURBO_ACTION, false))
	_button_nodes = [pass_button, shoot_button, turbo_button]


func _make_button(caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(JamTuning.TOUCH_BUTTON_SIZE, JamTuning.TOUCH_BUTTON_SIZE)
	button.size = button.custom_minimum_size
	button.modulate = Color(1.0, 1.0, 1.0, 0.72)
	button.add_theme_font_size_override("font_size", JamTuning.HUD_BUTTON_FONT_SIZE)
	button.focus_mode = Control.FOCUS_NONE
	add_child(button)
	return button


func _resized() -> void:
	var button_y := size.y - JamTuning.TOUCH_BUTTON_SIZE - JamTuning.TOUCH_BUTTON_BOTTOM_MARGIN
	var group_width := JamTuning.TOUCH_BUTTON_SIZE * _button_nodes.size() + JamTuning.TOUCH_BUTTON_GAP * (_button_nodes.size() - 1)
	var first_x := size.x - group_width - JamTuning.TOUCH_JOYSTICK_MARGIN
	for index in _button_nodes.size():
		_button_nodes[index].position = Vector2(first_x + index * (JamTuning.TOUCH_BUTTON_SIZE + JamTuning.TOUCH_BUTTON_GAP), button_y)
	queue_redraw()


func _joystick_rect() -> Rect2:
	var diameter := JamTuning.TOUCH_JOYSTICK_DIAMETER
	return Rect2(JamTuning.TOUCH_JOYSTICK_MARGIN, size.y - diameter - JamTuning.TOUCH_JOYSTICK_MARGIN, diameter, diameter)


func _update_joystick(screen_position: Vector2) -> void:
	var center := _joystick_rect().get_center()
	var local_position: Vector2 = get_global_transform_with_canvas().affine_inverse() * screen_position
	var offset := local_position - center
	_set_joystick(offset.limit_length(JamTuning.JOYSTICK_MAX_DISTANCE) / JamTuning.JOYSTICK_MAX_DISTANCE)


func _set_joystick(vector: Vector2) -> void:
	_joystick_vector = vector.limit_length(1.0)
	_set_action(JamTuning.MOVE_LEFT_ACTION, _joystick_vector.x < -JamTuning.JOYSTICK_DEADZONE)
	_set_action(JamTuning.MOVE_RIGHT_ACTION, _joystick_vector.x > JamTuning.JOYSTICK_DEADZONE)
	_set_action(JamTuning.MOVE_UP_ACTION, _joystick_vector.y < -JamTuning.JOYSTICK_DEADZONE)
	_set_action(JamTuning.MOVE_DOWN_ACTION, _joystick_vector.y > JamTuning.JOYSTICK_DEADZONE)
	queue_redraw()


func _set_action(action: String, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _draw() -> void:
	var base := _joystick_rect()
	var center := base.get_center()
	var radius := JamTuning.TOUCH_JOYSTICK_DIAMETER * 0.5
	draw_circle(center, radius, Color(0.02, 0.05, 0.09, 0.28))
	draw_arc(center, radius, 0.0, TAU, JamTuning.THREE_POINT_ARC_SEGMENTS, Color(1.0, 1.0, 1.0, 0.62), JamTuning.COURT_LINE_WIDTH, true)
	var knob_center := center + _joystick_vector * JamTuning.JOYSTICK_MAX_DISTANCE
	draw_circle(knob_center, radius * 0.36, Color(0.88, 0.94, 1.0, 0.48))
