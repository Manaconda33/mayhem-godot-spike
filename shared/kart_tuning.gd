extends RefCounted
class_name KartTuning

# Flat road and closed-track layout. Distances and speed use Godot world units/second.
const GROUND_HEIGHT := 0.0
const GROUND_SIZE := Vector2(1800.0, 1500.0)
const GROUND_CENTER := Vector3(264.0, -0.16, -64.0)
const TRACK_HALF_WIDTH := 7.2
const TRACK_SEGMENT_LENGTH := 3.5
const TRACK_TANGENT_SAMPLE := 1.0
const TRACK_CONTROL_HANDLE_FRACTION := 0.28
const TRACK_POINTS := [
	Vector3(0.0, GROUND_HEIGHT, 0.0),
	Vector3(496.0, GROUND_HEIGHT, 0.0),
	Vector3(604.0, GROUND_HEIGHT, -48.0),
	Vector3(624.0, GROUND_HEIGHT, -164.0),
	Vector3(536.0, GROUND_HEIGHT, -264.0),
	Vector3(412.0, GROUND_HEIGHT, -228.0),
	Vector3(340.0, GROUND_HEIGHT, -312.0),
	Vector3(196.0, GROUND_HEIGHT, -292.0),
	Vector3(68.0, GROUND_HEIGHT, -196.0),
	Vector3(36.0, GROUND_HEIGHT, -28.0),
	Vector3(116.0, GROUND_HEIGHT, 124.0),
	Vector3(312.0, GROUND_HEIGHT, 156.0),
	Vector3(484.0, GROUND_HEIGHT, 100.0),
	Vector3(524.0, GROUND_HEIGHT, 28.0),
	Vector3(-72.0, GROUND_HEIGHT, 0.0),
]
const TRACK_GATE_FRACTIONS := [0.0, 0.25, 0.5, 0.75]
const TRACK_GATE_COUNT := 4
const START_FINISH_GATE_INDEX := 0
const FIRST_CHECKPOINT_GATE_INDEX := 1
const TRACK_START_OFFSET := 18.0
const TRACK_RESPAWN_OFFSET := 7.0
const TRACK_PROGRESS_JITTER := 0.75
const TRACK_BACKWARDS_SPEED_THRESHOLD := 1.5
const WRONG_WAY_PERSIST_TIME := 0.7
const TRACK_GATE_MARKING_DEPTH := 0.72
const TRACK_GATE_MARKING_HEIGHT := 0.09
const TRACK_GATE_HEIGHT := 2.8
const TRACK_GATE_POST_WIDTH := 0.22

# Arcade drivetrain and steering response. Steering response is radians/second; grip is lateral speed reduction.
const ENGINE_ACCELERATION := 27.5
const BRAKE_DECELERATION := 52.0
const REVERSE_ACCELERATION := 21.0
const REVERSE_MAX_SPEED := 18.0
const MAX_SPEED := 54.0
const COAST_DRAG := 7.0
const STEER_RESPONSE := 2.05
const STEER_SPEED_FALLOFF := 0.48
const STEER_LOW_SPEED_MULT := 0.64
const STEER_WHEEL_MAX_ANGLE := 0.55
const LATERAL_GRIP := 8.5
const OFFTRACK_ENGINE_MULT := 0.62
const OFFTRACK_MAX_SPEED := 23.0
const OFFTRACK_DRAG := 17.0
const OFFTRACK_GRIP := 10.5

# Handbrake drift and the single deterministic release boost. Charge is normalized from zero to one.
const DRIFT_MIN_SPEED := 12.0
const DRIFT_MIN_STEER := 0.22
const DRIFT_CHARGE_RATE := 0.52
const DRIFT_MAX_CHARGE := 1.0
const DRIFT_LATERAL_GRIP := 0.85
const DRIFT_SLIDE_ACCELERATION := 0.92
const DRIFT_YAW_MULTIPLIER := 1.34
const DRIFT_BODY_YAW := 0.32
const DRIFT_BOOST_MULT := 1.42
const DRIFT_BOOST_TIME := 1.1
const DRIFT_BOOST_MAX_SPEED := 67.0

# Ghost pace is in world units/second; lap state durations are in seconds.
const GHOST_SPEED := 49.0
const GHOST_START_GAP := 92.0
const LAP_START_COUNT := 0
const LAP_FLASH_TIME := 1.35
const LAP_WRONG_WAY_FLASH_TIME := 1.0
const LAP_TIMER_PRECISION := 2
const WORLD_LIGHT_ROTATION := Vector3(-0.92, -0.62, 0.0)
const WORLD_LIGHT_ENERGY := 1.15

# Kart placeholder dimensions and visual response.
const KART_BODY_LENGTH := 2.8
const KART_BODY_WIDTH := 1.55
const KART_BODY_HEIGHT := 0.62
const KART_BODY_CENTER_HEIGHT := 0.83
const KART_FRONT_AXLE_OFFSET := 0.88
const KART_REAR_AXLE_OFFSET := 0.91
const KART_AXLE_HEIGHT := 0.48
const KART_WHEEL_RADIUS := 0.34
const KART_WHEEL_WIDTH := 0.24
const KART_WHEEL_SIDE_OFFSET := 0.84
const KART_REAR_OFFSET := 1.0
const KART_DRIVER_RADIUS := 0.34
const KART_DRIVER_HEIGHT := 0.8
const KART_DRIVER_CENTER_HEIGHT := 1.45
const KART_DRIVER_FORWARD_OFFSET := 0.1
const KART_LABEL_HEIGHT := 2.25
const KART_LABEL_PIXEL_SIZE := 0.012
const KART_LABEL_FONT_SIZE := 72
const KART_WHEEL_SPIN_DIVISOR := 1.0
const KART_BODY_DRIFT_YAW_SPEED := 8.0
const KART_PARTICLE_AMOUNT := 28
const KART_PARTICLE_LIFETIME := 0.48
const KART_PARTICLE_EMISSION_RADIUS := 0.36
const KART_PARTICLE_INITIAL_SPEED_MIN := 0.7
const KART_PARTICLE_INITIAL_SPEED_MAX := 2.3
const KART_PARTICLE_SPREAD := 38.0
const KART_PARTICLE_GRAVITY := Vector3(0.0, 2.4, 0.0)
const KART_PARTICLE_SCALE_MIN := 0.11
const KART_PARTICLE_SCALE_MAX := 0.25
const KART_PARTICLE_VISIBILITY_SIZE := 3.5

# Chase-camera distances are world units, smoothing is exponential rate, and FOV values are degrees.
const CAMERA_DISTANCE := 8.2
const CAMERA_DISTANCE_AT_SPEED := 10.0
const CAMERA_HEIGHT := 5.7
const CAMERA_HEIGHT_AT_SPEED := 6.4
const CAMERA_SMOOTHING := 5.0
const CAMERA_LOOK_AHEAD := 7.0
const CAMERA_STEER_LOOK_AHEAD := 5.0
const CAMERA_LOOK_HEIGHT := 0.95
const CAMERA_FOV_BASE := 67.0
const CAMERA_FOV_SPEED := 77.0
const CAMERA_FOV_BOOST := 7.0
const CAMERA_FOV_SMOOTHING := 4.0
const CAMERA_SPEED_EASE_START := 0.55
const CAMERA_SNAP_DELTA := 0.0

# On-screen HUD and touch-control layout at the 1280x720 design viewport.
const HUD_TIME_POSITION := Vector2(22.0, 16.0)
const HUD_TIME_SIZE := Vector2(250.0, 58.0)
const HUD_TIME_FONT := 34
const HUD_LAP_POSITION := Vector2(22.0, 74.0)
const HUD_LAP_SIZE := Vector2(260.0, 28.0)
const HUD_STATS_POSITION := Vector2(282.0, 23.0)
const HUD_STATS_SIZE := Vector2(380.0, 68.0)
const HUD_STATS_FONT := 17
const HUD_SPEED_POSITION := Vector2(22.0, 110.0)
const HUD_SPEED_SIZE := Vector2(180.0, 32.0)
const HUD_SPEED_FONT := 23
const HUD_MESSAGE_TOP := 105.0
const HUD_MESSAGE_SIZE := Vector2(520.0, 52.0)
const HUD_MESSAGE_FONT := 32
const HUD_RIGHT_MARGIN := 22.0
const HUD_BACK_TOP := 17.0
const HUD_BACK_SIZE := Vector2(170.0, 48.0)
const HUD_DEBUG_BUTTON_TOP := 75.0
const HUD_DEBUG_BUTTON_SIZE := Vector2(68.0, 36.0)
const HUD_DEBUG_TEXT_GAP := 16.0
const HUD_DEBUG_TEXT_TOP := 17.0
const HUD_DEBUG_TEXT_SIZE := Vector2(410.0, 76.0)
const HUD_DEBUG_FONT := 14
const HUD_BUTTON_FONT := 16
const HUD_TOUCH_BORDER_WIDTH := 2
const HUD_TOUCH_CORNER_RADIUS := 16
const HUD_MESSAGE_DURATION := 1.2
const HUD_CANVAS_LAYER := 4
const HUD_TOUCH_BUTTON_SIZE := Vector2(112.0, 112.0)
const HUD_TOUCH_STEER_LEFT_POSITION := Vector2(22.0, -136.0)
const HUD_TOUCH_STEER_RIGHT_POSITION := Vector2(146.0, -136.0)
const HUD_TOUCH_GAS_POSITION := Vector2(-392.0, -136.0)
const HUD_TOUCH_BRAKE_POSITION := Vector2(-268.0, -136.0)
const HUD_TOUCH_DRIFT_POSITION := Vector2(-144.0, -136.0)
const HUD_TOUCH_RESET_POSITION := Vector2(-144.0, -190.0)
const HUD_TOUCH_RESET_SIZE := Vector2(112.0, 44.0)

# Action names keep keyboard and touch on the same Input path.
const STEER_LEFT_ACTION := "steer_left"
const STEER_RIGHT_ACTION := "steer_right"
const ACCELERATE_ACTION := "accelerate"
const BRAKE_ACTION := "brake_reverse"
const DRIFT_ACTION := "drift"
const RESPAWN_ACTION := "respawn"
const DEBUG_ACTION := "debug_overlay"

# Stable numerical guards and display thresholds.
const SPEED_DISPLAY_MULTIPLIER := 3.6
const MIN_USEFUL_SPEED := 0.01
const MIN_TRACK_DELTA := 0.0001
const HALF_TRACK_RATIO := 0.5
const MIN_LAP_TIME := 0.001
