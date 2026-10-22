extends Node
class_name JamCamera

var viewport_size := Vector2(JamTuning.VIEWPORT_WIDTH, JamTuning.VIEWPORT_HEIGHT)
var camera_x := JamTuning.COURT_LENGTH * 0.5
var camera_velocity := 0.0
var pixels_per_world := JamTuning.CAMERA_PIXELS_PER_WORLD_AT_REST
var dunk_progress := -1.0


func refresh_viewport() -> void:
	if DisplayServer.get_name() == "headless":
		viewport_size = JamTuning.DESIGN_VIEWPORT_SIZE
	else:
		viewport_size = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = JamTuning.DESIGN_VIEWPORT_SIZE
	_update_zoom()


func snap_to(world_x: float) -> void:
	refresh_viewport()
	camera_x = world_x
	camera_velocity = 0.0


func update_follow(player_position: Vector2, hoop_position: Vector2, attack_direction: float, delta: float) -> void:
	refresh_viewport()
	var visible_world := viewport_size.x / pixels_per_world
	var follow_target := player_position.x + attack_direction * JamTuning.CAMERA_LEAD
	var hoop_screen_pct := JamTuning.CAMERA_NEAR_HOOP_SCREEN_PCT if attack_direction > 0.0 else 1.0 - JamTuning.CAMERA_NEAR_HOOP_SCREEN_PCT
	var hoop_frame_target := hoop_position.x - (hoop_screen_pct - 0.5) * visible_world
	var hoop_distance := absf(hoop_position.x - player_position.x)
	var frame_weight := clampf(1.0 - hoop_distance / JamTuning.CAMERA_HOOP_FRAME_DISTANCE, 0.0, 1.0)
	if hoop_distance <= JamTuning.DUNK_RANGE:
		frame_weight = 1.0
	var target_x := lerpf(follow_target, hoop_frame_target, frame_weight)
	var edge_overscan := JamTuning.CAMERA_EDGE_OVERSCAN
	target_x = clampf(target_x, -visible_world * 0.5 - edge_overscan, JamTuning.COURT_LENGTH + visible_world * 0.5 + edge_overscan)
	var target_velocity := (target_x - camera_x) * JamTuning.CAMERA_LAG_SPEED
	camera_velocity = move_toward(camera_velocity, target_velocity, JamTuning.CAMERA_ACCEL * delta)
	camera_velocity = clampf(camera_velocity, -JamTuning.CAMERA_MAX_SPEED, JamTuning.CAMERA_MAX_SPEED)
	camera_x += camera_velocity * delta
	_update_zoom()


func set_dunk_progress(progress: float) -> void:
	dunk_progress = progress
	_update_zoom()


func depth_scale_at(world_y: float) -> float:
	return lerpf(JamTuning.FAR_DEPTH_SCALE, JamTuning.NEAR_DEPTH_SCALE, clampf(world_y / JamTuning.COURT_WIDTH, 0.0, 1.0))


func world_to_screen(world_position: Vector2, z_height: float = 0.0) -> Vector2:
	var floor_top := viewport_size.y * JamTuning.FLOOR_TOP_PCT
	var floor_height := viewport_size.y * JamTuning.FLOOR_BAND_PCT
	var projected_x := viewport_size.x * 0.5 + (world_position.x - camera_x) * pixels_per_world
	var projected_y := floor_top + world_position.y / JamTuning.COURT_WIDTH * floor_height
	projected_y -= z_height * pixels_per_world * depth_scale_at(world_position.y)
	return Vector2(projected_x, projected_y)


func visible_court_pct() -> float:
	return viewport_size.x / pixels_per_world / JamTuning.COURT_LENGTH


func _update_zoom() -> void:
	var push_pct := 0.0
	if JamTuning.DUNK_CAM_ENABLED and dunk_progress >= 0.0:
		push_pct = sin(clampf(dunk_progress, 0.0, 1.0) * PI) * JamTuning.DUNK_CAM_PUSH_PCT
	pixels_per_world = viewport_size.x / (JamTuning.COURT_LENGTH * JamTuning.CAMERA_REST_VISIBLE_COURT_PCT) * (1.0 + push_pct)
