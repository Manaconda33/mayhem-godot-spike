extends Camera3D
class_name KartChaseCamera

var follow_target: ArcadeKart
var _has_snapped := false


func snap_to_target() -> void:
	if follow_target == null:
		return
	_update_camera(KartTuning.CAMERA_SNAP_DELTA)
	_has_snapped = true


func _physics_process(delta: float) -> void:
	if follow_target == null:
		return
	if not _has_snapped:
		snap_to_target()
	_update_camera(delta)


func _update_camera(delta: float) -> void:
	var forward := Vector3(sin(follow_target.heading_yaw), 0.0, -cos(follow_target.heading_yaw))
	var speed_ratio := clampf(follow_target.speed_kph() / (KartTuning.MAX_SPEED * KartTuning.SPEED_DISPLAY_MULTIPLIER), 0.0, 1.0)
	var speed_ease := smoothstep(KartTuning.CAMERA_SPEED_EASE_START, 1.0, speed_ratio)
	var distance := lerpf(KartTuning.CAMERA_DISTANCE, KartTuning.CAMERA_DISTANCE_AT_SPEED, speed_ease)
	var height := lerpf(KartTuning.CAMERA_HEIGHT, KartTuning.CAMERA_HEIGHT_AT_SPEED, speed_ease)
	var look_lead := KartTuning.CAMERA_LOOK_AHEAD + speed_ratio * KartTuning.CAMERA_STEER_LOOK_AHEAD
	var steering_lead := follow_target.steering_input * speed_ratio * KartTuning.CAMERA_STEER_LOOK_AHEAD
	var desired_position := follow_target.global_position - forward * distance + Vector3.UP * height
	var desired_look := follow_target.global_position + forward * look_lead + Vector3.UP * KartTuning.CAMERA_LOOK_HEIGHT
	desired_look += Vector3(-forward.z, 0.0, forward.x) * steering_lead
	if _has_snapped:
		var follow_weight := 1.0 - exp(-KartTuning.CAMERA_SMOOTHING * delta)
		global_position = global_position.lerp(desired_position, follow_weight)
		var fov_weight := 1.0 - exp(-KartTuning.CAMERA_FOV_SMOOTHING * delta)
		fov = lerpf(fov, _target_fov(speed_ratio), fov_weight)
	else:
		global_position = desired_position
		fov = _target_fov(speed_ratio)
	look_at(desired_look, Vector3.UP)


func _target_fov(speed_ratio: float) -> float:
	var speed_fov := lerpf(KartTuning.CAMERA_FOV_BASE, KartTuning.CAMERA_FOV_SPEED, speed_ratio)
	if follow_target.boost_time_left > 0.0:
		speed_fov += KartTuning.CAMERA_FOV_BOOST
	return speed_fov
