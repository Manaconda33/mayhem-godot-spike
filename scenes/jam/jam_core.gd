extends Node2D
class_name JamCore

enum PossessionState { HELD, IN_FLIGHT_PASS, IN_FLIGHT_SHOT, DUNKING, LOOSE, RESETTING }

var tuning := JamTuning.new()
var player_team: Array[JamPlayer] = []
var opponents: Array[JamPlayer] = []
var controlled_player: JamPlayer
var ball: JamBall
var score := 0
var possession_state := PossessionState.RESETTING
var attacked_hoop_position := JamTuning.HOOP_RIGHT_POSITION
var attack_direction := 1.0
var turbo_meter := JamTuning.TURBO_CAPACITY
var debug_visible := false

var _camera: JamCamera
var _hud_layer: CanvasLayer
var _flash_label: Label
var _debug_label: Label
var _score_label: Label
var _turbo_label: Label
var _back_button: Button
var _debug_button: Button
var _turbo_background: ColorRect
var _turbo_fill: ColorRect
var _reset_timer := 0.0
var _loose_timer := 0.0
var _flash_timer := 0.0
var _dribble_phase := 0.0
var _pending_shot_points := 2
var _pending_make_pct := 0.0
var _dunk_elapsed := 0.0


func _ready() -> void:
	_camera = $Camera
	_hud_layer = $HUDLayer
	_build_hud()
	_create_athletes()
	ball = JamBall.new()
	ball.name = "Ball"
	add_child(ball)
	_camera.snap_to(JamTuning.COURT_LENGTH * 0.5 + JamTuning.CAMERA_LEAD)
	_reset_formation()
	_update_hud()


func _physics_process(delta: float) -> void:
	_flash_timer = maxf(_flash_timer - delta, 0.0)
	if _flash_timer <= 0.0:
		_flash_label.text = ""

	if Input.is_action_just_pressed(JamTuning.DBG_ACTION):
		_toggle_debug()
	if Input.is_action_just_pressed(JamTuning.PASS_ACTION):
		on_pass_pressed()
	if Input.is_action_just_pressed(JamTuning.SHOOT_ACTION):
		on_shoot_pressed()
	if Input.is_action_just_released(JamTuning.SHOOT_ACTION):
		on_shoot_released()

	match possession_state:
		PossessionState.HELD:
			_tick_held(delta)
		PossessionState.IN_FLIGHT_PASS, PossessionState.IN_FLIGHT_SHOT:
			_tick_flight(delta)
		PossessionState.DUNKING:
			_tick_dunk(delta)
		PossessionState.LOOSE:
			_tick_loose(delta)
		PossessionState.RESETTING:
			_tick_reset(delta)

	_tick_camera_and_visuals(delta)
	_update_hud()
	queue_redraw()


func on_pass_pressed() -> void:
	if possession_state != PossessionState.HELD or not _controlled_player_has_ball():
		return
	var receiver := _other_teammate(controlled_player)
	if receiver == null:
		return
	var lead := receiver.velocity.normalized() * JamTuning.PASS_LEAD_DISTANCE
	var target := (receiver.court_position + lead).clamp(_court_bounds().position, _court_bounds().end)
	ball.start_flight(JamBall.State.IN_FLIGHT_PASS, ball.court_position, target, JamTuning.PASS_FLIGHT_TIME, JamTuning.PASS_ARC_HEIGHT, receiver)
	possession_state = PossessionState.IN_FLIGHT_PASS


func on_shoot_pressed() -> void:
	if possession_state != PossessionState.HELD or not _controlled_player_has_ball():
		return
	if controlled_player.court_position.distance_to(attacked_hoop_position) <= JamTuning.DUNK_RANGE:
		_start_dunk()
		return
	controlled_player.begin_jump()


func on_shoot_released() -> void:
	if possession_state != PossessionState.HELD or not _controlled_player_has_ball():
		return
	if controlled_player.state != JamPlayer.AthleteState.JUMPING:
		return
	var perfect_release := controlled_player.release_is_perfect()
	_pending_shot_points = JamTuning.THREE_POINT_SCORE if controlled_player.court_position.distance_to(attacked_hoop_position) > JamTuning.THREE_POINT_RADIUS else JamTuning.TWO_POINT_SCORE
	_pending_make_pct = JamTuning.SHOT_BASE_MAKE_PCT
	if perfect_release:
		_pending_make_pct += JamTuning.SHOT_PERFECT_BONUS_PCT
		_flash("PERFECT", JamTuning.FLASH_DURATION)
	_pending_make_pct = clampf(_pending_make_pct, JamTuning.SHOT_PERFECT_MIN_PCT, JamTuning.SHOT_MAKE_MAX_PCT)
	ball.start_flight(JamBall.State.IN_FLIGHT_SHOT, ball.court_position, attacked_hoop_position, JamTuning.SHOT_FLIGHT_TIME, JamTuning.SHOT_ARC_HEIGHT)
	controlled_player.finish_action()
	possession_state = PossessionState.IN_FLIGHT_SHOT


func get_staging_readings() -> Dictionary:
	if controlled_player == null:
		return {"visible_court_pct": 0.0, "controlled_height_pct": 0.0}
	return {
		"camera_zoom": _camera.pixels_per_world,
		"visible_court_pct": _camera.visible_court_pct(),
		"controlled_height_pct": controlled_player.screen_height_pct(_camera),
		"teammate_height_pct": _other_teammate(controlled_player).screen_height_pct(_camera),
		"attack_rim_screen_pct": _camera.world_to_screen(attacked_hoop_position).x / _camera.viewport_size.x,
		"viewport_size": _camera.viewport_size,
	}


func _create_athletes() -> void:
	var jam_roster: Array[Dictionary] = []
	for entry in App.roster:
		if entry is Dictionary:
			var modes: Array = entry.get("modes", [])
			if modes.has("jam"):
				jam_roster.append(entry)
	var team_colors := [Color("#28bdc8"), Color("#f5a343")]
	for index in mini(jam_roster.size(), JamTuning.PLAYER_TEAM_SIZE):
		var entry := jam_roster[index]
		var athlete := JamPlayer.new()
		athlete.name = "Player" + str(index + 1)
		var start_position := JamTuning.PLAYER_START_POSITION if index == 0 else JamTuning.TEAMMATE_START_POSITION
		athlete.configure(str(entry.get("name", "Athlete")), team_colors[index], start_position)
		add_child(athlete)
		player_team.append(athlete)

	for index in JamTuning.CPU_TEAM_SIZE:
		var defender := JamPlayer.new()
		defender.name = "CPU" + str(index + 1)
		defender.configure("CPU-" + str(index + 1), Color("#dc5368"), JamTuning.CPU_START_POSITIONS[index])
		add_child(defender)
		opponents.append(defender)


func _tick_held(delta: float) -> void:
	var move_direction := Input.get_vector(JamTuning.MOVE_LEFT_ACTION, JamTuning.MOVE_RIGHT_ACTION, JamTuning.MOVE_UP_ACTION, JamTuning.MOVE_DOWN_ACTION)
	var turbo_active := Input.is_action_pressed(JamTuning.TURBO_ACTION) and turbo_meter > JamTuning.TURBO_METER_LOW_THRESHOLD
	var move_speed := JamTuning.MOVE_SPEED
	if turbo_active:
		move_speed *= JamTuning.TURBO_MULT
		turbo_meter = maxf(turbo_meter - JamTuning.TURBO_DRAIN_PER_SECOND * delta, 0.0)
	else:
		turbo_meter = minf(turbo_meter + JamTuning.TURBO_REGEN_PER_SECOND * delta, JamTuning.TURBO_CAPACITY)
	controlled_player.move_with_input(move_direction, delta, move_speed, _court_bounds())
	_controlled_teammate().move_to_target(_teammate_target(), delta, JamTuning.TEAMMATE_AI_SPEED, JamTuning.TEAMMATE_AI_ACCEL, _court_bounds())
	_position_defenders(delta)
	_apply_separation(player_team)
	controlled_player.tick_jump(delta)
	_update_dribble(delta)


func _tick_flight(delta: float) -> void:
	ball.tick(delta)
	if not ball.flight_complete:
		return
	if possession_state == PossessionState.IN_FLIGHT_PASS:
		var receiver := ball.flight_receiver
		if is_instance_valid(receiver):
			_set_controlled(receiver)
			ball.set_held(receiver)
			possession_state = PossessionState.HELD
			return
	if possession_state == PossessionState.IN_FLIGHT_SHOT:
		if randf() < _pending_make_pct:
			_award_basket(_pending_shot_points, str(_pending_shot_points) + " PTS")
		else:
			_start_loose_ball()


func _tick_dunk(delta: float) -> void:
	_dunk_elapsed = minf(_dunk_elapsed + delta, JamTuning.DUNK_DURATION)
	var progress := _dunk_elapsed / JamTuning.DUNK_DURATION
	ball.tick(delta)
	controlled_player.court_position = ball.court_position
	controlled_player.set_dunking(progress)
	_camera.set_dunk_progress(progress)
	if progress >= 1.0:
		controlled_player.court_position = attacked_hoop_position
		_camera.set_dunk_progress(-1.0)
		_award_basket(JamTuning.TWO_POINT_SCORE, str(JamTuning.TWO_POINT_SCORE) + " PTS")


func _tick_loose(delta: float) -> void:
	ball.tick(delta)
	_loose_timer += delta
	ball.court_position = ball.court_position.clamp(_court_bounds().position, _court_bounds().end)
	for athlete in player_team:
		if athlete.court_position.distance_to(ball.court_position) <= JamTuning.LOOSE_PICKUP_RANGE:
			_set_controlled(athlete)
			ball.set_held(athlete)
			possession_state = PossessionState.HELD
			_flash("LOOSE BALL RECOVERED", JamTuning.LOOSE_RECOVERY_FLASH_TIME)
			return
	if _loose_timer >= JamTuning.LOOSE_RESET_TIMEOUT:
		_start_reset("INBOUND", false)


func _tick_reset(delta: float) -> void:
	_reset_timer -= delta
	if _reset_timer <= 0.0:
		_reset_formation()


func _position_defenders(delta: float) -> void:
	if opponents.is_empty():
		return
	var handler := controlled_player.court_position
	var to_hoop := (attacked_hoop_position - handler).normalized()
	var pressure_target := (handler + to_hoop * JamTuning.PRESSURE_DISTANCE).clamp(_court_bounds().position, _court_bounds().end)
	var pressure_index := 0
	if opponents.size() > 1 and opponents[1].court_position.distance_to(handler) < opponents[0].court_position.distance_to(handler):
		pressure_index = 1
	opponents[pressure_index].move_to_target(pressure_target, delta, JamTuning.DEFENDER_AI_SPEED, JamTuning.DEFENDER_AI_ACCEL, _court_bounds())
	if opponents.size() > 1:
		var teammate := _controlled_teammate()
		var sag_target := teammate.court_position + Vector2(-attack_direction * JamTuning.DEFENDER_SAG_X, 0.0)
		sag_target = sag_target.clamp(_court_bounds().position, _court_bounds().end)
		var sag_index := 1 - pressure_index
		opponents[sag_index].move_to_target(sag_target, delta, JamTuning.DEFENDER_AI_SPEED, JamTuning.DEFENDER_AI_ACCEL, _court_bounds())
	_apply_separation(opponents)


func _apply_separation(athletes: Array[JamPlayer]) -> void:
	for first_index in athletes.size():
		for second_index in range(first_index + 1, athletes.size()):
			var first := athletes[first_index]
			var second := athletes[second_index]
			var offset := second.court_position - first.court_position
			var distance := offset.length()
			if distance <= JamTuning.VECTOR_EPSILON or distance >= JamTuning.ATHLETE_SEPARATION_DISTANCE:
				continue
			var push := offset.normalized() * (JamTuning.ATHLETE_SEPARATION_DISTANCE - distance) * JamTuning.ATHLETE_SEPARATION_SPLIT_PCT
			var push_step := push.limit_length(JamTuning.ATHLETE_SEPARATION_SPEED * get_physics_process_delta_time())
			if first != controlled_player:
				first.court_position -= push_step
			if second != controlled_player:
				second.court_position += push_step


func _update_dribble(delta: float) -> void:
	if not _controlled_player_has_ball():
		return
	var speed_ratio := minf(controlled_player.velocity.length() / JamTuning.MOVE_SPEED, JamTuning.TURBO_MULT)
	var bounce_rate := JamTuning.DRIBBLE_BOUNCE_RATE + JamTuning.DRIBBLE_MOVE_BOUNCE_BONUS * speed_ratio
	_dribble_phase = fposmod(_dribble_phase + delta * bounce_rate, TAU)
	var handler := controlled_player
	ball.carrier = handler
	ball.court_position = handler.court_position + Vector2(handler.facing * JamTuning.DRIBBLE_SIDE_OFFSET, 0.0)
	ball.z_height = handler.jump_height() + absf(sin(_dribble_phase)) * JamTuning.DRIBBLE_BOUNCE_HEIGHT


func _tick_camera_and_visuals(delta: float) -> void:
	if controlled_player == null:
		return
	_camera.update_follow(controlled_player.court_position, attacked_hoop_position, attack_direction, delta)
	for athlete in player_team:
		athlete.update_screen_pose(_camera, athlete == controlled_player, athlete == controlled_player and _controlled_player_has_ball())
	for defender in opponents:
		defender.update_screen_pose(_camera, false, false)
	ball.update_screen_pose(_camera)
	var readings := get_staging_readings()
	_debug_label.text = "ZOOM %.3f  ·  COURT %.1f%%  ·  ATHLETE %.1f%%" % [readings.camera_zoom, readings.visible_court_pct * 100.0, readings.controlled_height_pct * 100.0]


func _update_hud() -> void:
	_score_label.text = "YOU " + str(score)
	var fill_ratio := turbo_meter / JamTuning.TURBO_CAPACITY
	_turbo_fill.size.x = JamTuning.HUD_TURBO_BAR_WIDTH * fill_ratio
	_turbo_fill.color = Color("#55e6b7").lerp(Color("#f2be48"), 1.0 - fill_ratio)
	_turbo_label.text = "TURBO"


func _start_dunk() -> void:
	_dunk_elapsed = 0.0
	controlled_player.set_dunking(0.0)
	ball.begin_dunk(controlled_player, attacked_hoop_position)
	possession_state = PossessionState.DUNKING


func _start_loose_ball() -> void:
	var attack_away := Vector2(-attack_direction * JamTuning.LOOSE_RIM_BOUNCE_SPEED, JamTuning.LOOSE_RIM_SIDEWAYS_SPEED)
	var miss_position := (attacked_hoop_position + JamTuning.SHOT_MISS_OFFSET + Vector2(0.0, JamTuning.SHOT_MISS_SIDE_OFFSET)).clamp(_court_bounds().position, _court_bounds().end)
	ball.start_loose(miss_position, attack_away)
	possession_state = PossessionState.LOOSE
	_loose_timer = 0.0
	_flash("NO GOOD", JamTuning.FLASH_DURATION)


func _award_basket(points: int, message: String) -> void:
	score += points
	_start_reset(message, true)


func _start_reset(message: String, scored: bool) -> void:
	possession_state = PossessionState.RESETTING
	ball.begin_reset()
	_reset_timer = JamTuning.SCORE_PAUSE_TIME if scored else 0.0
	for athlete in player_team + opponents:
		athlete.state = JamPlayer.AthleteState.RESETTING
		athlete.velocity = Vector2.ZERO
	_flash(message, _reset_timer)


func _reset_formation() -> void:
	for index in player_team.size():
		var athlete := player_team[index]
		athlete.finish_action()
		athlete.velocity = Vector2.ZERO
		if index == 0:
			athlete.court_position = JamTuning.PLAYER_START_POSITION
		else:
			athlete.court_position = JamTuning.TEAMMATE_START_POSITION
	for index in opponents.size():
		opponents[index].finish_action()
		opponents[index].court_position = JamTuning.CPU_START_POSITIONS[index]
		opponents[index].velocity = Vector2.ZERO
	if player_team.is_empty():
		return
	_set_controlled(player_team[0])
	ball.set_held(controlled_player)
	possession_state = PossessionState.HELD
	_loose_timer = 0.0
	_camera.set_dunk_progress(-1.0)


func _set_controlled(athlete: JamPlayer) -> void:
	for teammate in player_team:
		teammate.controlled = teammate == athlete
	controlled_player = athlete


func _controlled_player_has_ball() -> bool:
	return is_instance_valid(controlled_player) and ball.carrier == controlled_player and ball.state == JamBall.State.HELD


func _controlled_teammate() -> JamPlayer:
	return _other_teammate(controlled_player)


func _other_teammate(athlete: JamPlayer) -> JamPlayer:
	for teammate in player_team:
		if teammate != athlete:
			return teammate
	return null


func _teammate_target() -> Vector2:
	var teammate := _controlled_teammate()
	var mirrored_y := JamTuning.COURT_WIDTH - controlled_player.court_position.y
	var target := Vector2(controlled_player.court_position.x - attack_direction * JamTuning.TEAMMATE_OPEN_X_OFFSET, mirrored_y)
	if teammate != null and teammate == ball.carrier:
		target = teammate.court_position
	return target.clamp(_court_bounds().position, _court_bounds().end)


func _court_bounds() -> Rect2:
	var margin := JamTuning.PLAYER_BOUNDARY_MARGIN
	return Rect2(Vector2(margin, margin), Vector2(JamTuning.COURT_LENGTH - margin * 2.0, JamTuning.COURT_WIDTH - margin * 2.0))


func _flash(message: String, duration: float) -> void:
	_flash_label.text = message
	_flash_timer = duration


func _toggle_debug() -> void:
	debug_visible = not debug_visible
	_debug_label.visible = debug_visible


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/shell/main.tscn")


func _draw() -> void:
	var viewport := _camera.viewport_size
	var floor_top := viewport.y * JamTuning.FLOOR_TOP_PCT
	draw_rect(Rect2(Vector2.ZERO, Vector2(viewport.x, floor_top)), Color("#151a2b"))
	for dot_index in JamTuning.ARENA_DOT_COUNT:
		var dot_x := fposmod(dot_index * JamTuning.ARENA_DOT_X_STEP + JamTuning.ARENA_DOT_X_OFFSET, viewport.x)
		var dot_y := fposmod(dot_index * JamTuning.ARENA_DOT_Y_STEP + JamTuning.ARENA_DOT_Y_OFFSET, maxf(floor_top, JamTuning.ARENA_DOT_RADIUS))
		draw_circle(Vector2(dot_x, dot_y), JamTuning.ARENA_DOT_RADIUS, Color(0.65, 0.76, 0.9, 0.32))
	draw_rect(Rect2(Vector2(0.0, floor_top), Vector2(viewport.x, viewport.y - floor_top)), Color("#bf7948"))
	_draw_court_lines()
	_draw_hoop(JamTuning.HOOP_LEFT_POSITION, -1.0)
	_draw_hoop(JamTuning.HOOP_RIGHT_POSITION, 1.0)


func _draw_court_lines() -> void:
	var line_color := Color(1.0, 0.9, 0.74, JamTuning.COURT_LINE_ALPHA)
	_draw_projected_line(Vector2(0.0, 0.0), Vector2(JamTuning.COURT_LENGTH, 0.0), line_color)
	_draw_projected_line(Vector2(0.0, JamTuning.COURT_WIDTH), Vector2(JamTuning.COURT_LENGTH, JamTuning.COURT_WIDTH), line_color)
	_draw_projected_line(Vector2(0.0, 0.0), Vector2(0.0, JamTuning.COURT_WIDTH), line_color)
	_draw_projected_line(Vector2(JamTuning.COURT_LENGTH, 0.0), Vector2(JamTuning.COURT_LENGTH, JamTuning.COURT_WIDTH), line_color)
	_draw_projected_line(Vector2(JamTuning.COURT_CENTER_LINE_X, 0.0), Vector2(JamTuning.COURT_CENTER_LINE_X, JamTuning.COURT_WIDTH), line_color)
	_draw_world_arc(Vector2(JamTuning.COURT_CENTER_X, JamTuning.COURT_CENTER_Y), JamTuning.CENTER_CIRCLE_RADIUS, 0.0, TAU, line_color)
	_draw_world_arc(JamTuning.HOOP_RIGHT_POSITION, JamTuning.THREE_POINT_RADIUS, PI * 0.5, PI * 1.5, line_color)
	_draw_world_arc(JamTuning.HOOP_LEFT_POSITION, JamTuning.THREE_POINT_RADIUS, -PI * 0.5, PI * 0.5, line_color)


func _draw_projected_line(from: Vector2, to: Vector2, color: Color) -> void:
	draw_line(_camera.world_to_screen(from), _camera.world_to_screen(to), color, JamTuning.COURT_LINE_WIDTH, true)


func _draw_world_arc(center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color) -> void:
	var points := PackedVector2Array()
	for segment in JamTuning.THREE_POINT_ARC_SEGMENTS + 1:
		var angle := lerpf(start_angle, end_angle, float(segment) / JamTuning.THREE_POINT_ARC_SEGMENTS)
		var world_point := center + Vector2(cos(angle), sin(angle)) * radius
		points.append(_camera.world_to_screen(world_point))
	draw_polyline(points, color, JamTuning.COURT_LINE_WIDTH, true)


func _draw_hoop(hoop_position: Vector2, side: float) -> void:
	var viewport := _camera.viewport_size
	var base := _camera.world_to_screen(hoop_position)
	var assembly_width := viewport.x * JamTuning.HOOP_ASSEMBLY_WIDTH_PCT
	var assembly_height := viewport.y * JamTuning.HOOP_ASSEMBLY_HEIGHT_PCT
	var rim_y := _camera.world_to_screen(hoop_position, JamTuning.RIM_HEIGHT).y
	var post_x := base.x + side * assembly_width * JamTuning.HOOP_POST_OFFSET_PCT
	var board_center_x := base.x - side * assembly_width * JamTuning.HOOP_BACKBOARD_OFFSET_PCT
	var board_size := Vector2(viewport.x * JamTuning.HOOP_BACKBOARD_WIDTH_PCT, viewport.y * JamTuning.HOOP_BACKBOARD_HEIGHT_PCT)
	var board_rect := Rect2(Vector2(board_center_x - board_size.x * 0.5, base.y - assembly_height * JamTuning.HOOP_BACKBOARD_TOP_PCT), board_size)
	var hoop_color := Color("#e6e9f0")
	draw_line(Vector2(post_x, base.y), Vector2(post_x, base.y - assembly_height * JamTuning.HOOP_POST_TOP_PCT), Color("#353b4e"), assembly_width * JamTuning.HOOP_POST_WIDTH_PCT, true)
	draw_line(Vector2(post_x, rim_y), Vector2(board_center_x + side * board_size.x * JamTuning.HOOP_BRACE_BACKBOARD_PCT, rim_y - board_size.y * JamTuning.HOOP_BACKBOARD_BRACE_PCT), Color("#353b4e"), JamTuning.HOOP_LINE_WIDTH, true)
	draw_rect(board_rect, Color("#b8d6de"), true)
	draw_rect(board_rect, hoop_color, false, JamTuning.COURT_LINE_WIDTH)
	draw_line(Vector2(board_center_x - side * board_size.x * JamTuning.HOOP_RIM_LINE_WIDTH_PCT, rim_y), Vector2(board_center_x + side * board_size.x * JamTuning.HOOP_RIM_LINE_WIDTH_PCT, rim_y), Color("#f2984c"), JamTuning.RIM_LINE_WIDTH, true)
	var rim_radius := viewport.x * JamTuning.HOOP_RIM_RADIUS_PCT
	draw_arc(Vector2(base.x, rim_y), rim_radius, 0.0, TAU, JamTuning.THREE_POINT_ARC_SEGMENTS, Color("#f0543e"), JamTuning.RIM_LINE_WIDTH, true)


func _build_hud() -> void:
	var overlay := Control.new()
	overlay.name = "Overlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(overlay)

	_score_label = Label.new()
	_score_label.add_theme_font_size_override("font_size", JamTuning.HUD_SCORE_FONT_SIZE)
	_score_label.add_theme_color_override("font_color", Color.WHITE)
	overlay.add_child(_score_label)

	_turbo_label = Label.new()
	_turbo_label.add_theme_font_size_override("font_size", JamTuning.HUD_BUTTON_FONT_SIZE)
	_turbo_label.add_theme_color_override("font_color", Color("#e8f5ff"))
	overlay.add_child(_turbo_label)

	_turbo_background = ColorRect.new()
	_turbo_background.color = Color(0.05, 0.08, 0.12, 0.78)
	_turbo_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(_turbo_background)
	_turbo_fill = ColorRect.new()
	_turbo_fill.color = Color("#55e6b7")
	_turbo_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turbo_background.add_child(_turbo_fill)

	_flash_label = Label.new()
	_flash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash_label.add_theme_font_size_override("font_size", JamTuning.HUD_MESSAGE_FONT_SIZE)
	_flash_label.add_theme_color_override("font_color", Color("#fff1a7"))
	_flash_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	_flash_label.add_theme_constant_override("shadow_offset_x", JamTuning.COURT_LINE_WIDTH)
	_flash_label.add_theme_constant_override("shadow_offset_y", JamTuning.COURT_LINE_WIDTH)
	overlay.add_child(_flash_label)

	_back_button = _make_hud_button("Back", JamTuning.HUD_BACK_BUTTON_WIDTH, JamTuning.HUD_BACK_BUTTON_HEIGHT)
	_back_button.pressed.connect(_on_back_pressed)
	overlay.add_child(_back_button)
	_debug_button = _make_hud_button("DBG", JamTuning.HUD_DEBUG_BUTTON_WIDTH, JamTuning.HUD_DEBUG_BUTTON_HEIGHT)
	_debug_button.pressed.connect(_toggle_debug)
	overlay.add_child(_debug_button)

	_debug_label = Label.new()
	_debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_debug_label.add_theme_font_size_override("font_size", JamTuning.HUD_DEBUG_FONT_SIZE)
	_debug_label.add_theme_color_override("font_color", Color("#c8f5ff"))
	_debug_label.visible = false
	overlay.add_child(_debug_label)
	get_viewport().size_changed.connect(_layout_hud)
	_layout_hud()


func _make_hud_button(caption: String, width: float, height: float) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(width, height)
	button.add_theme_font_size_override("font_size", JamTuning.HUD_BUTTON_FONT_SIZE)
	return button


func _layout_hud() -> void:
	if _score_label == null:
		return
	var viewport := _camera.viewport_size
	_score_label.position = Vector2(JamTuning.HUD_EDGE_MARGIN, JamTuning.HUD_SCORE_TOP)
	_score_label.size = Vector2(JamTuning.HUD_SCORE_WIDTH, JamTuning.HUD_SCORE_HEIGHT)
	_turbo_label.position = Vector2(JamTuning.HUD_EDGE_MARGIN, JamTuning.HUD_TURBO_TOP)
	_turbo_label.size = Vector2(JamTuning.HUD_TURBO_LABEL_WIDTH, JamTuning.HUD_TURBO_BAR_HEIGHT)
	_turbo_background.position = Vector2(JamTuning.HUD_EDGE_MARGIN + JamTuning.HUD_TURBO_LABEL_WIDTH, JamTuning.HUD_TURBO_BAR_TOP)
	_turbo_background.size = Vector2(JamTuning.HUD_TURBO_BAR_WIDTH, JamTuning.HUD_TURBO_BAR_HEIGHT)
	_turbo_fill.position = Vector2.ZERO
	_turbo_fill.size = Vector2(_turbo_background.size.x, _turbo_background.size.y)
	_flash_label.position = Vector2(viewport.x * (1.0 - JamTuning.HUD_FLASH_WIDTH_PCT) * 0.5, viewport.y * JamTuning.HUD_FLASH_TOP_PCT)
	_flash_label.size = Vector2(viewport.x * JamTuning.HUD_FLASH_WIDTH_PCT, JamTuning.HUD_FLASH_HEIGHT)
	_back_button.position = Vector2(viewport.x - JamTuning.HUD_BACK_BUTTON_WIDTH - JamTuning.HUD_EDGE_MARGIN, JamTuning.HUD_EDGE_MARGIN)
	_back_button.size = Vector2(JamTuning.HUD_BACK_BUTTON_WIDTH, JamTuning.HUD_BACK_BUTTON_HEIGHT)
	_debug_button.position = Vector2(viewport.x - JamTuning.HUD_DEBUG_BUTTON_WIDTH - JamTuning.HUD_EDGE_MARGIN, JamTuning.HUD_DEBUG_TOP)
	_debug_button.size = Vector2(JamTuning.HUD_DEBUG_BUTTON_WIDTH, JamTuning.HUD_DEBUG_BUTTON_HEIGHT)
	_debug_label.position = Vector2(viewport.x - JamTuning.HUD_DEBUG_LABEL_WIDTH - JamTuning.HUD_EDGE_MARGIN, JamTuning.HUD_DEBUG_LABEL_TOP)
	_debug_label.size = Vector2(JamTuning.HUD_DEBUG_LABEL_WIDTH, JamTuning.HUD_DEBUG_LABEL_HEIGHT)
