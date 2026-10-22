extends Node3D
class_name ArcadeKart

var driver_name := "Manaconda"
var body_color := Color("#27b6bd")
var is_ghost := false
var track: KartTrack
var longitudinal_speed := 0.0
var lateral_speed := 0.0
var heading_yaw := 0.0
var steering_input := 0.0
var drift_charge := 0.0
var drift_active := false
var boost_time_left := 0.0
var boost_release_count := 0
var off_track := false

var _body_pivot: Node3D
var _front_wheel_pivots: Array[Node3D] = []
var _wheels: Array[MeshInstance3D] = []
var _drift_particles: GPUParticles3D


func configure(name_text: String, color: Color, ghost: bool = false) -> void:
	driver_name = name_text
	body_color = color
	is_ghost = ghost
	_build_visual()


func set_track(value: KartTrack) -> void:
	track = value


func place_at_pose(world_position: Vector3, forward: Vector3) -> void:
	global_position = Vector3(world_position.x, KartTuning.GROUND_HEIGHT, world_position.z)
	heading_yaw = atan2(forward.x, -forward.z)
	rotation.y = heading_yaw
	longitudinal_speed = 0.0
	lateral_speed = 0.0
	drift_charge = 0.0
	drift_active = false
	boost_time_left = 0.0


func speed_kph() -> float:
	return absf(longitudinal_speed) * KartTuning.SPEED_DISPLAY_MULTIPLIER


func _physics_process(delta: float) -> void:
	if is_ghost or track == null:
		return
	_drive(delta)


func _process(delta: float) -> void:
	if not is_inside_tree():
		return
	_update_visuals(delta)


func _drive(delta: float) -> void:
	steering_input = Input.get_axis(KartTuning.STEER_LEFT_ACTION, KartTuning.STEER_RIGHT_ACTION)
	off_track = not track.is_on_road(global_position)
	var engine_scale := KartTuning.OFFTRACK_ENGINE_MULT if off_track else 1.0
	var drag := KartTuning.OFFTRACK_DRAG if off_track else KartTuning.COAST_DRAG
	var speed_limit := KartTuning.MAX_SPEED
	if not off_track and boost_time_left > 0.0:
		var boost_fraction := clampf(boost_time_left / KartTuning.DRIFT_BOOST_TIME, 0.0, 1.0)
		speed_limit = lerpf(KartTuning.MAX_SPEED, KartTuning.DRIFT_BOOST_MAX_SPEED, boost_fraction)
	var braking := Input.is_action_pressed(KartTuning.BRAKE_ACTION)
	var accelerating := Input.is_action_pressed(KartTuning.ACCELERATE_ACTION)
	if accelerating and not braking:
		longitudinal_speed += KartTuning.ENGINE_ACCELERATION * engine_scale * delta
	elif braking:
		if longitudinal_speed > KartTuning.MIN_USEFUL_SPEED:
			longitudinal_speed = move_toward(longitudinal_speed, 0.0, KartTuning.BRAKE_DECELERATION * delta)
		else:
			longitudinal_speed -= KartTuning.REVERSE_ACCELERATION * delta
			longitudinal_speed = maxf(longitudinal_speed, -KartTuning.REVERSE_MAX_SPEED)
	else:
		longitudinal_speed = move_toward(longitudinal_speed, 0.0, drag * delta)
	longitudinal_speed = clampf(longitudinal_speed, -KartTuning.REVERSE_MAX_SPEED, KartTuning.MAX_SPEED)
	if off_track and longitudinal_speed > KartTuning.OFFTRACK_MAX_SPEED:
		longitudinal_speed = move_toward(longitudinal_speed, KartTuning.OFFTRACK_MAX_SPEED, KartTuning.OFFTRACK_DRAG * delta)
	else:
		longitudinal_speed = clampf(longitudinal_speed, -KartTuning.REVERSE_MAX_SPEED, speed_limit)
	boost_time_left = maxf(boost_time_left - delta, 0.0)

	var speed_ratio := clampf(absf(longitudinal_speed) / KartTuning.MAX_SPEED, 0.0, 1.0)
	var steering_factor := lerpf(KartTuning.STEER_LOW_SPEED_MULT, 1.0, speed_ratio)
	steering_factor *= 1.0 - speed_ratio * KartTuning.STEER_SPEED_FALLOFF
	var wants_drift := Input.is_action_pressed(KartTuning.DRIFT_ACTION) \
		and longitudinal_speed >= KartTuning.DRIFT_MIN_SPEED \
		and absf(steering_input) >= KartTuning.DRIFT_MIN_STEER
	if drift_active and not wants_drift:
		_release_drift()
	drift_active = wants_drift
	if drift_active:
		drift_charge = minf(drift_charge + absf(steering_input) * KartTuning.DRIFT_CHARGE_RATE * delta, KartTuning.DRIFT_MAX_CHARGE)
	var yaw_multiplier := KartTuning.DRIFT_YAW_MULTIPLIER if drift_active else 1.0
	heading_yaw += steering_input * KartTuning.STEER_RESPONSE * steering_factor * yaw_multiplier * delta
	rotation.y = heading_yaw

	var forward := _forward_vector()
	var right := Vector3(-forward.z, 0.0, forward.x)
	if drift_active:
		lateral_speed += -steering_input * absf(longitudinal_speed) * KartTuning.DRIFT_SLIDE_ACCELERATION * delta
		lateral_speed = move_toward(lateral_speed, 0.0, KartTuning.DRIFT_LATERAL_GRIP * delta)
		lateral_speed = clampf(lateral_speed, -KartTuning.MAX_SPEED, KartTuning.MAX_SPEED)
	else:
		var grip := KartTuning.OFFTRACK_GRIP if off_track else KartTuning.LATERAL_GRIP
		lateral_speed = move_toward(lateral_speed, 0.0, grip * delta)
	global_position += (forward * longitudinal_speed + right * lateral_speed) * delta
	global_position.y = KartTuning.GROUND_HEIGHT
	if is_on_floor_road_edge():
		lateral_speed = move_toward(lateral_speed, 0.0, KartTuning.OFFTRACK_GRIP * delta)


func is_on_floor_road_edge() -> bool:
	return not track.is_on_road(global_position)


func _release_drift() -> void:
	if drift_charge <= KartTuning.MIN_USEFUL_SPEED:
		return
	var charge_ratio := clampf(drift_charge / KartTuning.DRIFT_MAX_CHARGE, 0.0, 1.0)
	var speed_multiplier := lerpf(1.0, KartTuning.DRIFT_BOOST_MULT, charge_ratio)
	longitudinal_speed = minf(longitudinal_speed * speed_multiplier, KartTuning.DRIFT_BOOST_MAX_SPEED)
	boost_time_left = KartTuning.DRIFT_BOOST_TIME
	boost_release_count += 1
	drift_charge = 0.0


func _forward_vector() -> Vector3:
	return Vector3(sin(heading_yaw), 0.0, -cos(heading_yaw))


func _build_visual() -> void:
	if _body_pivot != null:
		_body_pivot.queue_free()
	_body_pivot = Node3D.new()
	_body_pivot.name = "Visual"
	add_child(_body_pivot)
	var kart_material := StandardMaterial3D.new()
	kart_material.albedo_color = body_color
	kart_material.roughness = 0.72
	if is_ghost:
		kart_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		kart_material.albedo_color.a = 0.52
	var body := MeshInstance3D.new()
	body.name = "BoxBody"
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(KartTuning.KART_BODY_WIDTH, KartTuning.KART_BODY_HEIGHT, KartTuning.KART_BODY_LENGTH)
	body.mesh = body_mesh
	body.position.y = KartTuning.KART_BODY_CENTER_HEIGHT
	body.material_override = kart_material
	_body_pivot.add_child(body)
	var driver := MeshInstance3D.new()
	driver.name = "CapsuleDriver"
	var driver_mesh := CapsuleMesh.new()
	driver_mesh.radius = KartTuning.KART_DRIVER_RADIUS
	driver_mesh.height = KartTuning.KART_DRIVER_HEIGHT
	driver.mesh = driver_mesh
	driver.position = Vector3(0.0, KartTuning.KART_DRIVER_CENTER_HEIGHT, KartTuning.KART_DRIVER_FORWARD_OFFSET)
	var driver_material := StandardMaterial3D.new()
	driver_material.albedo_color = Color("#f4d9ad") if driver_name == "Manaconda" else Color("#d4cff5")
	driver.material_override = driver_material
	_body_pivot.add_child(driver)
	_create_wheel(KartTuning.KART_FRONT_AXLE_OFFSET, -1.0, true)
	_create_wheel(KartTuning.KART_FRONT_AXLE_OFFSET, 1.0, true)
	_create_wheel(-KartTuning.KART_REAR_AXLE_OFFSET, -1.0, false)
	_create_wheel(-KartTuning.KART_REAR_AXLE_OFFSET, 1.0, false)
	var label := Label3D.new()
	label.name = "DriverName"
	label.text = driver_name
	label.font_size = KartTuning.KART_LABEL_FONT_SIZE
	label.pixel_size = KartTuning.KART_LABEL_PIXEL_SIZE
	label.position.y = KartTuning.KART_LABEL_HEIGHT
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("#f8f7e9")
	_body_pivot.add_child(label)
	if not is_ghost:
		_create_drift_particles()


func _create_wheel(axle_offset: float, side: float, front: bool) -> void:
	var pivot := Node3D.new()
	pivot.name = "FrontWheelPivot" if front else "RearWheelPivot"
	pivot.position = Vector3(axle_offset, KartTuning.KART_AXLE_HEIGHT, side * KartTuning.KART_WHEEL_SIDE_OFFSET)
	add_child(pivot)
	if front:
		_front_wheel_pivots.append(pivot)
	var wheel := MeshInstance3D.new()
	wheel.name = "Wheel"
	var wheel_mesh := CylinderMesh.new()
	wheel_mesh.top_radius = KartTuning.KART_WHEEL_RADIUS
	wheel_mesh.bottom_radius = KartTuning.KART_WHEEL_RADIUS
	wheel_mesh.height = KartTuning.KART_WHEEL_WIDTH
	wheel.mesh = wheel_mesh
	wheel.rotation.z = PI * 0.5
	var wheel_material := StandardMaterial3D.new()
	wheel_material.albedo_color = Color("#15191d")
	wheel_material.roughness = 0.92
	wheel.material_override = wheel_material
	pivot.add_child(wheel)
	_wheels.append(wheel)


func _create_drift_particles() -> void:
	_drift_particles = GPUParticles3D.new()
	_drift_particles.name = "DriftSmoke"
	_drift_particles.amount = KartTuning.KART_PARTICLE_AMOUNT
	_drift_particles.lifetime = KartTuning.KART_PARTICLE_LIFETIME
	_drift_particles.emitting = false
	_drift_particles.position = Vector3(0.0, KartTuning.KART_AXLE_HEIGHT, KartTuning.KART_REAR_OFFSET)
	var particle_material := ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_material.emission_sphere_radius = KartTuning.KART_PARTICLE_EMISSION_RADIUS
	particle_material.direction = Vector3.UP
	particle_material.spread = KartTuning.KART_PARTICLE_SPREAD
	particle_material.initial_velocity_min = KartTuning.KART_PARTICLE_INITIAL_SPEED_MIN
	particle_material.initial_velocity_max = KartTuning.KART_PARTICLE_INITIAL_SPEED_MAX
	particle_material.gravity = KartTuning.KART_PARTICLE_GRAVITY
	particle_material.scale_min = KartTuning.KART_PARTICLE_SCALE_MIN
	particle_material.scale_max = KartTuning.KART_PARTICLE_SCALE_MAX
	_drift_particles.process_material = particle_material
	var particle_mesh := SphereMesh.new()
	particle_mesh.radius = KartTuning.KART_PARTICLE_SCALE_MAX
	particle_mesh.height = KartTuning.KART_PARTICLE_SCALE_MAX * 2.0
	var particle_material_override := StandardMaterial3D.new()
	particle_material_override.albedo_color = Color("#e3d8c8", 0.7)
	particle_material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_drift_particles.draw_pass_1 = particle_mesh
	_drift_particles.material_override = particle_material_override
	var bounds := KartTuning.KART_PARTICLE_VISIBILITY_SIZE
	_drift_particles.visibility_aabb = AABB(Vector3(-bounds, -bounds, -bounds), Vector3(bounds * 2.0, bounds * 2.0, bounds * 2.0))
	add_child(_drift_particles)


func _update_visuals(delta: float) -> void:
	var normalized_steer := steering_input if not is_ghost else 0.0
	if not _front_wheel_pivots.is_empty():
		for pivot in _front_wheel_pivots:
			pivot.rotation.y = normalized_steer * KartTuning.STEER_WHEEL_MAX_ANGLE
	for wheel in _wheels:
		wheel.rotation.x += longitudinal_speed * delta / (KartTuning.KART_WHEEL_RADIUS * KartTuning.KART_WHEEL_SPIN_DIVISOR)
	if _body_pivot != null:
		var target_yaw := -normalized_steer * KartTuning.DRIFT_BODY_YAW if drift_active else 0.0
		_body_pivot.rotation.y = move_toward(_body_pivot.rotation.y, target_yaw, KartTuning.KART_BODY_DRIFT_YAW_SPEED * delta)
	if _drift_particles != null:
		_drift_particles.emitting = drift_active and not is_ghost
