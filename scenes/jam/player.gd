extends Node2D
class_name JamPlayer

enum AthleteState { READY, JUMPING, DUNKING, RESETTING }

var character_name := "Athlete"
var team_color := Color("#32c7ce")
var court_position := Vector2.ZERO
var velocity := Vector2.ZERO
var facing := 1.0
var state := AthleteState.READY
var controlled := false
var carries_ball := false
var jump_elapsed := 0.0
var dunk_progress := 0.0
var rendered_depth_scale := JamTuning.NEAR_DEPTH_SCALE
var rendered_height_scale := 1.0


func configure(display_name: String, color: Color, start_position: Vector2) -> void:
	character_name = display_name
	team_color = color
	court_position = start_position
	queue_redraw()


func move_with_input(direction: Vector2, delta: float, speed: float, bounds: Rect2) -> void:
	if state == AthleteState.DUNKING or state == AthleteState.RESETTING:
		velocity = Vector2.ZERO
		return
	var target_velocity := direction.normalized() * speed
	var response := JamTuning.MOVE_ACCEL if not direction.is_zero_approx() else JamTuning.MOVE_DECEL
	velocity = velocity.move_toward(target_velocity, response * delta)
	court_position = (court_position + velocity * delta).clamp(bounds.position, bounds.end)
	_update_facing(velocity.x)


func move_to_target(target: Vector2, delta: float, speed: float, acceleration: float, bounds: Rect2) -> void:
	if state == AthleteState.DUNKING or state == AthleteState.RESETTING:
		velocity = Vector2.ZERO
		return
	var offset := target - court_position
	var target_velocity := Vector2.ZERO
	if offset.length() > JamTuning.VECTOR_EPSILON:
		target_velocity = offset.normalized() * minf(speed, offset.length() / maxf(delta, JamTuning.VECTOR_EPSILON))
	velocity = velocity.move_toward(target_velocity, acceleration * delta)
	court_position = (court_position + velocity * delta).clamp(bounds.position, bounds.end)
	_update_facing(velocity.x)


func begin_jump() -> void:
	if state == AthleteState.DUNKING or state == AthleteState.RESETTING:
		return
	jump_elapsed = 0.0
	state = AthleteState.JUMPING


func tick_jump(delta: float) -> bool:
	if state != AthleteState.JUMPING:
		return false
	jump_elapsed += delta
	if jump_elapsed >= JamTuning.JUMP_RISE_TIME + JamTuning.JUMP_FALL_TIME:
		jump_elapsed = JamTuning.JUMP_RISE_TIME + JamTuning.JUMP_FALL_TIME
		state = AthleteState.READY
		return true
	return false


func jump_height() -> float:
	if state != AthleteState.JUMPING:
		return 0.0
	if jump_elapsed <= JamTuning.JUMP_RISE_TIME:
		return JamTuning.JUMP_HEIGHT * jump_elapsed / JamTuning.JUMP_RISE_TIME
	var fall_fraction := (jump_elapsed - JamTuning.JUMP_RISE_TIME) / JamTuning.JUMP_FALL_TIME
	return JamTuning.JUMP_HEIGHT * (1.0 - fall_fraction)


func release_is_perfect() -> bool:
	if state != AthleteState.JUMPING:
		return false
	var total_time := JamTuning.JUMP_RISE_TIME + JamTuning.JUMP_FALL_TIME
	var phase := jump_elapsed / total_time
	var apex_phase := JamTuning.JUMP_RISE_TIME / total_time
	return absf(phase - apex_phase) <= JamTuning.PERFECT_WINDOW_FRACTION * 0.5


func set_dunking(progress: float) -> void:
	state = AthleteState.DUNKING
	dunk_progress = progress


func current_air_height() -> float:
	if state == AthleteState.DUNKING:
		return sin(dunk_progress * PI) * JamTuning.DUNK_ARC_HEIGHT + dunk_progress * JamTuning.RIM_HEIGHT
	return jump_height()


func finish_action() -> void:
	state = AthleteState.READY
	jump_elapsed = 0.0
	dunk_progress = 0.0


func state_name() -> String:
	match state:
		AthleteState.READY:
			return "READY"
		AthleteState.JUMPING:
			return "JUMPING"
		AthleteState.DUNKING:
			return "DUNKING"
		AthleteState.RESETTING:
			return "RESETTING"
	return "UNKNOWN"


func update_screen_pose(camera: Node, is_controlled: bool, has_ball: bool) -> void:
	controlled = is_controlled
	carries_ball = has_ball
	var height := current_air_height()
	rendered_depth_scale = camera.depth_scale_at(court_position.y)
	rendered_height_scale = camera.viewport_size.y / JamTuning.VIEWPORT_HEIGHT * JamTuning.CAMERA_PIXELS_PER_WORLD_AT_REST / camera.pixels_per_world
	position = camera.world_to_screen(court_position) - Vector2(0.0, height * camera.pixels_per_world * rendered_depth_scale * rendered_height_scale)
	scale = Vector2(camera.pixels_per_world * rendered_height_scale, camera.pixels_per_world * rendered_depth_scale * rendered_height_scale)
	z_index = int(court_position.y)
	queue_redraw()


func screen_height_pct(camera: Node) -> float:
	var responsive_height: float = JamTuning.ATHLETE_HEIGHT * camera.viewport_size.y / JamTuning.VIEWPORT_HEIGHT * JamTuning.CAMERA_PIXELS_PER_WORLD_AT_REST / camera.pixels_per_world
	return responsive_height * camera.pixels_per_world * camera.depth_scale_at(court_position.y) / camera.viewport_size.y


func _update_facing(horizontal_velocity: float) -> void:
	if absf(horizontal_velocity) > JamTuning.VECTOR_EPSILON:
		facing = signf(horizontal_velocity)


func _draw() -> void:
	var athlete_height := JamTuning.ATHLETE_HEIGHT
	var half_width := JamTuning.ATHLETE_WIDTH * 0.5
	var neck_y := -athlete_height * JamTuning.ATHLETE_NECK_CENTER_PCT
	var torso_bottom := -athlete_height * JamTuning.ATHLETE_TORSO_BOTTOM_PCT
	var head_radius := athlete_height * JamTuning.ATHLETE_HEAD_RADIUS_PCT
	var head_center := -athlete_height * JamTuning.ATHLETE_HEAD_CENTER_PCT

	if controlled:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, JamTuning.CONTROL_RING_RADIUS_Y / JamTuning.CONTROL_RING_RADIUS_X))
		draw_arc(Vector2.ZERO, JamTuning.CONTROL_RING_RADIUS_X, 0.0, TAU, JamTuning.THREE_POINT_ARC_SEGMENTS, Color("#fff2a1"), JamTuning.ATHLETE_OUTLINE_WIDTH, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var torso_width := half_width * JamTuning.ATHLETE_TORSO_WIDTH_PCT
	var torso_top := -athlete_height * JamTuning.ATHLETE_TORSO_TOP_PCT
	draw_circle(Vector2(0.0, neck_y), torso_width, team_color)
	draw_rect(Rect2(-torso_width, torso_top, torso_width * 2.0, torso_bottom - torso_top), team_color, true)
	draw_circle(Vector2(0.0, torso_bottom), torso_width, team_color)
	draw_circle(Vector2(0.0, head_center), head_radius, Color("#f2d5ae"))
	draw_circle(Vector2(facing * head_radius * JamTuning.ATHLETE_EYE_X_PCT, head_center - head_radius * JamTuning.ATHLETE_EYE_Y_PCT), JamTuning.ATHLETE_OUTLINE_WIDTH, Color("#202332"))
	draw_line(Vector2(-half_width * JamTuning.ATHLETE_ARM_TOP_X_PCT, torso_top), Vector2(-half_width * JamTuning.ATHLETE_ARM_BOTTOM_X_PCT, torso_bottom), team_color.darkened(0.18), half_width * JamTuning.ATHLETE_LIMB_WIDTH_PCT, true)
	draw_line(Vector2(half_width * JamTuning.ATHLETE_ARM_TOP_X_PCT, torso_top), Vector2(half_width * JamTuning.ATHLETE_ARM_BOTTOM_X_PCT, torso_bottom), team_color.darkened(0.18), half_width * JamTuning.ATHLETE_LIMB_WIDTH_PCT, true)
	draw_line(Vector2(-half_width * JamTuning.ATHLETE_LEG_TOP_X_PCT, torso_bottom), Vector2(-half_width * JamTuning.ATHLETE_LEG_BOTTOM_X_PCT, -athlete_height * JamTuning.ATHLETE_LEG_BOTTOM_Y_PCT), Color("#252a3c"), half_width * JamTuning.ATHLETE_LEG_WIDTH_PCT, true)
	draw_line(Vector2(half_width * JamTuning.ATHLETE_LEG_TOP_X_PCT, torso_bottom), Vector2(half_width * JamTuning.ATHLETE_LEG_BOTTOM_X_PCT, -athlete_height * JamTuning.ATHLETE_LEG_BOTTOM_Y_PCT), Color("#252a3c"), half_width * JamTuning.ATHLETE_LEG_WIDTH_PCT, true)

	var font := ThemeDB.fallback_font
	if font != null:
		draw_string(font, Vector2(-JamTuning.ATHLETE_WIDTH * 2.0, -athlete_height * JamTuning.ATHLETE_LABEL_HEIGHT_PCT), character_name, HORIZONTAL_ALIGNMENT_CENTER, JamTuning.ATHLETE_WIDTH * 4.0, JamTuning.PLAYER_NAME_FONT_SIZE, Color.WHITE)
