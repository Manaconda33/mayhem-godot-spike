extends Node2D
class_name JamBall

enum State { HELD, IN_FLIGHT_PASS, IN_FLIGHT_SHOT, DUNKING, LOOSE, RESETTING }

var state := State.HELD
var carrier: JamPlayer
var court_position := Vector2.ZERO
var z_height := 0.0
var loose_velocity := Vector2.ZERO
var loose_z_velocity := 0.0
var flight_start := Vector2.ZERO
var flight_end := Vector2.ZERO
var flight_elapsed := 0.0
var flight_duration := 0.0
var flight_arc_height := 0.0
var flight_receiver: JamPlayer
var flight_complete := false
var rendered_depth_scale := JamTuning.NEAR_DEPTH_SCALE


func set_held(new_carrier: JamPlayer) -> void:
	state = State.HELD
	carrier = new_carrier
	if is_instance_valid(carrier):
		court_position = carrier.court_position
	z_height = 0.0
	flight_complete = false


func start_flight(flight_state: State, from: Vector2, to: Vector2, duration: float, arc_height: float, receiver: JamPlayer = null) -> void:
	state = flight_state
	carrier = null
	flight_start = from
	flight_end = to
	court_position = from
	z_height = 0.0
	flight_elapsed = 0.0
	flight_duration = duration
	flight_arc_height = arc_height
	flight_receiver = receiver
	flight_complete = false


func start_loose(start_position: Vector2, horizontal_velocity: Vector2) -> void:
	state = State.LOOSE
	carrier = null
	court_position = start_position
	loose_velocity = horizontal_velocity
	loose_z_velocity = JamTuning.LOOSE_BOUNCE_SPEED
	z_height = 0.0
	flight_complete = false


func begin_dunk(handler: JamPlayer, rim_position: Vector2) -> void:
	state = State.DUNKING
	carrier = null
	flight_start = handler.court_position
	flight_end = rim_position
	court_position = flight_start
	z_height = 0.0
	flight_elapsed = 0.0
	flight_duration = JamTuning.DUNK_DURATION
	flight_arc_height = JamTuning.DUNK_ARC_HEIGHT
	flight_receiver = null
	flight_complete = false


func begin_reset() -> void:
	state = State.RESETTING
	carrier = null
	z_height = 0.0
	flight_complete = false


func tick(delta: float) -> void:
	if state == State.IN_FLIGHT_PASS or state == State.IN_FLIGHT_SHOT or state == State.DUNKING:
		flight_elapsed = minf(flight_elapsed + delta, flight_duration)
		var progress := flight_elapsed / flight_duration
		court_position = flight_start.lerp(flight_end, progress)
		z_height = sin(progress * PI) * flight_arc_height
		if state == State.IN_FLIGHT_SHOT or state == State.DUNKING:
			z_height += progress * JamTuning.RIM_HEIGHT
		flight_complete = progress >= 1.0
	elif state == State.LOOSE:
		loose_velocity *= exp(-JamTuning.LOOSE_FRICTION * delta)
		court_position += loose_velocity * delta
		loose_z_velocity -= JamTuning.LOOSE_GRAVITY * delta
		z_height += loose_z_velocity * delta
		if z_height <= 0.0:
			z_height = 0.0
			loose_z_velocity = maxf(loose_z_velocity * -JamTuning.LOOSE_BOUNCE_RETURN_PCT, 0.0)
	queue_redraw()


func state_name() -> String:
	match state:
		State.HELD:
			return "HELD"
		State.IN_FLIGHT_PASS:
			return "IN_FLIGHT_PASS"
		State.IN_FLIGHT_SHOT:
			return "IN_FLIGHT_SHOT"
		State.DUNKING:
			return "DUNKING"
		State.LOOSE:
			return "LOOSE"
		State.RESETTING:
			return "RESETTING"
	return "UNKNOWN"


func update_screen_pose(camera: Node) -> void:
	rendered_depth_scale = camera.depth_scale_at(court_position.y)
	position = camera.world_to_screen(court_position)
	scale = Vector2(camera.pixels_per_world, camera.pixels_per_world)
	z_index = int(court_position.y) + JamTuning.ATHLETE_SEPARATION_DISTANCE
	queue_redraw()


func _draw() -> void:
	var shadow_color := Color(0.0, 0.0, 0.0, 0.28)
	draw_set_transform(Vector2(0.0, z_height), 0.0, Vector2(1.0, rendered_depth_scale * JamTuning.BALL_SHADOW_SCALE))
	draw_circle(Vector2.ZERO, JamTuning.BALL_RADIUS, shadow_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var ball_center := Vector2(0.0, -z_height)
	draw_circle(ball_center + Vector2(0.0, JamTuning.BALL_RADIUS * JamTuning.BALL_SHADOW_OFFSET_PCT), JamTuning.BALL_RADIUS, Color("#b84425"))
	draw_arc(ball_center, JamTuning.BALL_RADIUS * JamTuning.BALL_SEAM_RADIUS_PCT, -PI * JamTuning.BALL_SEAM_ARC_START_PCT, PI * JamTuning.BALL_SEAM_ARC_START_PCT, JamTuning.THREE_POINT_ARC_SEGMENTS, Color("#3d241d"), JamTuning.ATHLETE_OUTLINE_WIDTH, true)
	draw_arc(ball_center, JamTuning.BALL_RADIUS * JamTuning.BALL_SEAM_RADIUS_PCT, PI * JamTuning.BALL_SEAM_ARC_END_START_PCT, PI * JamTuning.BALL_SEAM_ARC_END_PCT, JamTuning.THREE_POINT_ARC_SEGMENTS, Color("#3d241d"), JamTuning.ATHLETE_OUTLINE_WIDTH, true)
