extends Node3D
class_name KartCore

enum RaceState { RACING, WRONG_WAY }

var race_state := RaceState.RACING
var current_gate_index := KartTuning.FIRST_CHECKPOINT_GATE_INDEX
var last_passed_gate_index := KartTuning.START_FINISH_GATE_INDEX
var lap_count := KartTuning.LAP_START_COUNT
var current_lap_time := 0.0
var last_lap_time := 0.0
var best_lap_time := 0.0
var debug_visible := false

var track: KartTrack
var player_kart: ArcadeKart
var ghost_kart: ArcadeKart
var ghost_path_follow: PathFollow3D

var _previous_offset := 0.0
var _wrong_way_time := 0.0
var _flash_time := 0.0
var _message := ""
var _seen_boost_release_count := 0
var _hud_layer: CanvasLayer
var _hud_root: Control
var _time_label: Label
var _lap_label: Label
var _stats_label: Label
var _speed_label: Label
var _message_label: Label
var _debug_label: Label
var _back_button: Button
var _debug_button: Button


func _ready() -> void:
	track = $Track
	_build_lighting()
	_create_karts()
	var start_pose := track.get_gate_pose(KartTuning.START_FINISH_GATE_INDEX, KartTuning.TRACK_START_OFFSET)
	player_kart.place_at_pose(start_pose["position"], start_pose["forward"])
	_previous_offset = track.get_closest_offset(player_kart.global_position)
	_create_camera()
	_build_hud()
	_create_touch_controls()
	_update_hud()


func _physics_process(delta: float) -> void:
	current_lap_time += delta
	_flash_time = maxf(_flash_time - delta, 0.0)
	if Input.is_action_just_pressed(KartTuning.DEBUG_ACTION):
		_toggle_debug()
	if Input.is_action_just_pressed(KartTuning.RESPAWN_ACTION):
		_respawn()
	if player_kart.boost_release_count != _seen_boost_release_count:
		_seen_boost_release_count = player_kart.boost_release_count
		_flash("BOOST", KartTuning.HUD_MESSAGE_DURATION)
	var current_offset := track.get_closest_offset(player_kart.global_position)
	_update_race_progress(current_offset, delta)
	_previous_offset = current_offset
	if ghost_path_follow != null:
		ghost_path_follow.progress = fposmod(ghost_path_follow.progress + KartTuning.GHOST_SPEED * delta, track.track_length)
	_update_hud()


func _update_race_progress(current_offset: float, delta: float) -> void:
	var movement := current_offset - _previous_offset
	if movement > track.track_length * KartTuning.HALF_TRACK_RATIO:
		movement -= track.track_length
	elif movement < -track.track_length * KartTuning.HALF_TRACK_RATIO:
		movement += track.track_length
	if movement < -KartTuning.TRACK_BACKWARDS_SPEED_THRESHOLD * delta:
		_wrong_way_time += delta
		if _wrong_way_time >= KartTuning.WRONG_WAY_PERSIST_TIME and race_state != RaceState.WRONG_WAY:
			race_state = RaceState.WRONG_WAY
			_flash("WRONG WAY", KartTuning.LAP_WRONG_WAY_FLASH_TIME)
		return
	if movement > KartTuning.MIN_TRACK_DELTA and race_state == RaceState.WRONG_WAY:
		race_state = RaceState.RACING
	if movement > KartTuning.TRACK_PROGRESS_JITTER:
		_wrong_way_time = 0.0
	elif absf(movement) <= KartTuning.TRACK_PROGRESS_JITTER:
		_wrong_way_time = 0.0
	if movement > KartTuning.MIN_TRACK_DELTA:
		_advance_ordered_gates(_previous_offset, movement)


func _advance_ordered_gates(from_offset: float, distance_forward: float) -> void:
	var cursor := from_offset
	var remaining := distance_forward
	for _crossing in KartTuning.TRACK_GATE_COUNT:
		var target_offset := track.get_gate_offset(current_gate_index)
		var distance_to_gate := target_offset - cursor
		if distance_to_gate <= KartTuning.MIN_TRACK_DELTA:
			distance_to_gate += track.track_length
		if distance_to_gate > remaining + KartTuning.MIN_TRACK_DELTA:
			break
		cursor = target_offset
		remaining -= distance_to_gate
		last_passed_gate_index = current_gate_index
		if current_gate_index == KartTuning.START_FINISH_GATE_INDEX:
			_finish_lap()
		current_gate_index = (current_gate_index + 1) % KartTuning.TRACK_GATE_COUNT
		if remaining <= KartTuning.MIN_TRACK_DELTA:
			break


func _finish_lap() -> void:
	last_lap_time = current_lap_time
	if best_lap_time <= KartTuning.MIN_LAP_TIME or last_lap_time < best_lap_time:
		best_lap_time = last_lap_time
	lap_count += 1
	current_lap_time = 0.0
	race_state = RaceState.RACING
	_wrong_way_time = 0.0
	_flash("LAP!", KartTuning.LAP_FLASH_TIME)


func _respawn() -> void:
	var pose := track.get_gate_pose(last_passed_gate_index, KartTuning.TRACK_RESPAWN_OFFSET)
	player_kart.place_at_pose(pose["position"], pose["forward"])
	_previous_offset = track.get_closest_offset(player_kart.global_position)
	_wrong_way_time = 0.0
	race_state = RaceState.RACING


func _create_karts() -> void:
	var kart_roster: Array[Dictionary] = []
	var roster_data: Array = get_node("/root/App").roster
	for entry in roster_data:
		if entry is Dictionary:
			var modes: Array = entry.get("modes", [])
			if modes.has("kart"):
				kart_roster.append(entry)
	var player_entry: Dictionary = _find_roster_entry(kart_roster, "Manaconda")
	var ghost_entry: Dictionary = _find_roster_entry(kart_roster, "Myth")
	player_kart = ArcadeKart.new()
	player_kart.name = "PlayerKart"
	player_kart.configure(str(player_entry.get("name", "Manaconda")), Color("#27b6bd"))
	player_kart.set_track(track)
	add_child(player_kart)
	ghost_path_follow = PathFollow3D.new()
	ghost_path_follow.name = "GhostPathFollow"
	ghost_path_follow.loop = true
	ghost_path_follow.rotation_mode = PathFollow3D.ROTATION_Y
	track.path.add_child(ghost_path_follow)
	ghost_kart = ArcadeKart.new()
	ghost_kart.name = "GhostKart"
	ghost_kart.configure(str(ghost_entry.get("name", "Myth")), Color("#e6923d"), true)
	ghost_kart.longitudinal_speed = KartTuning.GHOST_SPEED
	ghost_kart.set_track(track)
	ghost_path_follow.add_child(ghost_kart)
	ghost_path_follow.progress = fposmod(KartTuning.TRACK_START_OFFSET + KartTuning.GHOST_START_GAP, track.track_length)


func _find_roster_entry(entries: Array[Dictionary], wanted_name: String) -> Dictionary:
	for entry in entries:
		if str(entry.get("name", "")) == wanted_name:
			return entry
	return {}


func _create_camera() -> void:
	var camera := KartChaseCamera.new()
	camera.name = "KartCamera"
	camera.follow_target = player_kart
	add_child(camera)
	camera.current = true
	camera.snap_to_target()


func _build_lighting() -> void:
	var light := DirectionalLight3D.new()
	light.name = "ArenaLight"
	light.rotation = KartTuning.WORLD_LIGHT_ROTATION
	light.light_energy = KartTuning.WORLD_LIGHT_ENERGY
	add_child(light)


func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "HUD"
	_hud_layer.layer = KartTuning.HUD_CANVAS_LAYER
	add_child(_hud_layer)
	_hud_root = Control.new()
	_hud_root.name = "Overlay"
	_hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(_hud_root)
	get_viewport().size_changed.connect(_layout_hud)
	_time_label = _make_label("CurrentLapTime", "0.00", KartTuning.HUD_TIME_POSITION, KartTuning.HUD_TIME_SIZE, KartTuning.HUD_TIME_FONT)
	_lap_label = _make_label("LapAndGate", "LAP 1", KartTuning.HUD_LAP_POSITION, KartTuning.HUD_LAP_SIZE, KartTuning.HUD_STATS_FONT)
	_stats_label = _make_label("LapStats", "LAST --.--   BEST --.--", KartTuning.HUD_STATS_POSITION, KartTuning.HUD_STATS_SIZE, KartTuning.HUD_STATS_FONT)
	_speed_label = _make_label("Speed", "SPEED 000 km/h", KartTuning.HUD_SPEED_POSITION, KartTuning.HUD_SPEED_SIZE, KartTuning.HUD_SPEED_FONT)
	_message_label = _make_label("Message", "", Vector2.ZERO, KartTuning.HUD_MESSAGE_SIZE, KartTuning.HUD_MESSAGE_FONT)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_color_override("font_color", Color("#ffe477"))
	_debug_label = _make_label("DebugReadout", "", Vector2.ZERO, KartTuning.HUD_DEBUG_TEXT_SIZE, KartTuning.HUD_DEBUG_FONT)
	_debug_label.visible = false
	_back_button = Button.new()
	_back_button.name = "BackToHub"
	_back_button.text = "BACK"
	_back_button.size = KartTuning.HUD_BACK_SIZE
	_back_button.add_theme_font_size_override("font_size", KartTuning.HUD_BUTTON_FONT)
	_back_button.pressed.connect(_return_to_hub)
	_hud_root.add_child(_back_button)
	_debug_button = Button.new()
	_debug_button.name = "DebugToggle"
	_debug_button.text = "DBG"
	_debug_button.size = KartTuning.HUD_DEBUG_BUTTON_SIZE
	_debug_button.add_theme_font_size_override("font_size", KartTuning.HUD_BUTTON_FONT)
	_debug_button.pressed.connect(_toggle_debug)
	_hud_root.add_child(_debug_button)
	_layout_hud()


func _layout_hud() -> void:
	if _hud_root == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if _back_button != null:
		_back_button.position = Vector2(viewport_size.x - KartTuning.HUD_RIGHT_MARGIN - KartTuning.HUD_BACK_SIZE.x, KartTuning.HUD_BACK_TOP)
	if _debug_button != null:
		_debug_button.position = Vector2(viewport_size.x - KartTuning.HUD_RIGHT_MARGIN - KartTuning.HUD_DEBUG_BUTTON_SIZE.x, KartTuning.HUD_DEBUG_BUTTON_TOP)
	if _debug_label != null:
		_debug_label.position = Vector2(_debug_button.position.x - KartTuning.HUD_DEBUG_TEXT_GAP - KartTuning.HUD_DEBUG_TEXT_SIZE.x, KartTuning.HUD_DEBUG_TEXT_TOP)
	if _message_label != null:
		_message_label.position = Vector2((viewport_size.x - KartTuning.HUD_MESSAGE_SIZE.x) * 0.5, KartTuning.HUD_MESSAGE_TOP)


func _make_label(node_name: String, text_value: String, position: Vector2, size: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text_value
	label.position = position
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(label)
	return label


func _create_touch_controls() -> void:
	var controls_scene: PackedScene = load("res://scenes/kart/kart_touch_controls.tscn")
	if controls_scene == null:
		push_error("Kart touch controls scene could not be loaded")
		return
	_hud_layer.add_child(controls_scene.instantiate())


func _update_hud() -> void:
	if _time_label == null:
		return
	_time_label.text = _format_time(current_lap_time)
	_lap_label.text = "LAP %d   NEXT GATE %d" % [lap_count + 1, current_gate_index]
	_stats_label.text = "LAST %s   BEST %s" % [_format_optional_time(last_lap_time), _format_optional_time(best_lap_time)]
	_speed_label.text = "SPEED %03d km/h" % roundi(player_kart.speed_kph())
	if race_state == RaceState.WRONG_WAY:
		_message_label.text = "WRONG WAY"
	elif _flash_time <= 0.0:
		_message_label.text = ""
	else:
		_message_label.text = _message
	_debug_label.visible = debug_visible
	if debug_visible:
		var drift_state := "DRIFT" if player_kart.drift_active else "GRIP"
		_debug_label.text = "SPEED %.1f | %s %.2f\nGATE %d | LAP %s | FPS %d" % [
			player_kart.speed_kph(), drift_state, player_kart.drift_charge,
			current_gate_index, _format_time(current_lap_time), Engine.get_frames_per_second()
		]


func _format_time(seconds: float) -> String:
	return String.num(seconds, KartTuning.LAP_TIMER_PRECISION)


func _format_optional_time(seconds: float) -> String:
	if seconds <= KartTuning.MIN_LAP_TIME:
		return "--.--"
	return _format_time(seconds)


func _flash(text_value: String, duration: float) -> void:
	_message = text_value
	_flash_time = duration


func _toggle_debug() -> void:
	debug_visible = not debug_visible
	if _debug_button != null:
		_debug_button.button_pressed = debug_visible
	_update_hud()


func _return_to_hub() -> void:
	get_tree().change_scene_to_file("res://scenes/shell/main.tscn")
