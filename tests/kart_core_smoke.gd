extends SceneTree

const SMOKE_FRAME_DELTA := 0.1

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if root.get_node_or_null("App") == null:
		var app_script: Script = load("res://shared/app.gd")
		var app_node: Node = app_script.new()
		app_node.name = "App"
		root.add_child(app_node)
		await process_frame
	var packed_scene: PackedScene = load("res://scenes/kart/kart_core.tscn")
	if packed_scene == null:
		push_error("Kart core scene must load")
		quit(1)
		return
	var kart_scene := packed_scene.instantiate()
	root.add_child(kart_scene)
	await process_frame
	await process_frame
	var core := kart_scene as KartCore
	if not _expect(core != null, "Kart scene must use KartCore"):
		return
	if not _expect(core.player_kart != null and core.player_kart.driver_name == "Manaconda", "Player kart must use the kart roster entry"):
		return
	if not _expect(core.ghost_kart != null and core.ghost_kart.driver_name == "Myth", "Pace ghost must use Myth from the roster"):
		return
	if not _expect(core.track.curve.closed and core.track.track_length > KartTuning.TRACK_GATE_COUNT, "Track must be a generated closed curve"):
		return
	if not _expect(core.current_gate_index == 1 and core.last_passed_gate_index == 0 and core.lap_count == 0, "Race must start at gate 1 with start/finish as the last passed gate"):
		return
	var simulated_offset := core._previous_offset
	for _frame in ceili(KartTuning.WRONG_WAY_PERSIST_TIME / SMOKE_FRAME_DELTA):
		simulated_offset = fposmod(simulated_offset - KartTuning.TRACK_BACKWARDS_SPEED_THRESHOLD * SMOKE_FRAME_DELTA * 1.5, core.track.track_length)
		core._update_race_progress(simulated_offset, SMOKE_FRAME_DELTA)
		core._previous_offset = simulated_offset
	if not _expect(core.race_state == KartCore.RaceState.WRONG_WAY, "Persistent backwards progress must enter WRONG_WAY"):
		return
	simulated_offset = fposmod(simulated_offset + KartTuning.TRACK_PROGRESS_JITTER, core.track.track_length)
	core._update_race_progress(simulated_offset, SMOKE_FRAME_DELTA)
	core._previous_offset = simulated_offset
	if not _expect(core.race_state == KartCore.RaceState.RACING, "Forward progress must exit WRONG_WAY"):
		return
	for gate_index in [1, 2]:
		simulated_offset = _feed_next_gate(core, gate_index, simulated_offset)
	if not _expect(core.current_gate_index == 3 and core.last_passed_gate_index == 2, "Gates 1 and 2 must advance in order"):
		return
	core.player_kart.longitudinal_speed = KartTuning.DRIFT_MIN_SPEED
	core.player_kart.lateral_speed = KartTuning.DRIFT_MIN_SPEED
	core.player_kart.drift_charge = KartTuning.DRIFT_MAX_CHARGE
	core._respawn()
	if not _expect(core.current_gate_index == 3 and core.last_passed_gate_index == 2 and core.player_kart.longitudinal_speed == 0.0 and core.player_kart.lateral_speed == 0.0, "Respawn must preserve the gate state and zero kart velocity"):
		return
	simulated_offset = core._previous_offset
	simulated_offset = _feed_next_gate(core, 3, simulated_offset)
	simulated_offset = _feed_next_gate(core, 0, simulated_offset)
	if not _expect(core.lap_count == 1 and core.last_passed_gate_index == 0 and core.current_gate_index == 1, "A lap must finish only after ordered gates 1, 2, 3, and start/finish"):
		return
	var player := core.player_kart
	Input.action_press(KartTuning.STEER_RIGHT_ACTION)
	Input.action_press(KartTuning.DRIFT_ACTION)
	player.longitudinal_speed = KartTuning.DRIFT_MIN_SPEED - KartTuning.TRACK_PROGRESS_JITTER
	player._drive(SMOKE_FRAME_DELTA)
	if not _expect(not player.drift_active and player.drift_charge == 0.0, "Drift must not charge below minimum speed"):
		return
	player.longitudinal_speed = KartTuning.DRIFT_MIN_SPEED * 1.5
	player._drive(SMOKE_FRAME_DELTA)
	if not _expect(player.drift_active and player.drift_charge > 0.0, "Drift charge must accrue only while the drift conditions are met"):
		return
	Input.action_release(KartTuning.DRIFT_ACTION)
	player._drive(SMOKE_FRAME_DELTA)
	var boost_count := player.boost_release_count
	if not _expect(boost_count == 1 and player.drift_charge == 0.0 and player.boost_time_left > 0.0, "A drift release must trigger exactly one boost and clear charge"):
		return
	player._drive(SMOKE_FRAME_DELTA)
	if not _expect(player.boost_release_count == boost_count, "A completed drift release must not fire another boost"):
		return
	Input.action_press(KartTuning.DRIFT_ACTION)
	player.longitudinal_speed = KartTuning.DRIFT_MIN_SPEED * 1.5
	player._drive(SMOKE_FRAME_DELTA)
	Input.action_press(KartTuning.STEER_LEFT_ACTION)
	player._drive(SMOKE_FRAME_DELTA)
	if not _expect(player.boost_release_count == boost_count + 1 and not player.drift_active, "Straightening out must release one charged drift boost"):
		return
	Input.action_release(KartTuning.STEER_LEFT_ACTION)
	Input.action_release(KartTuning.STEER_RIGHT_ACTION)
	Input.action_release(KartTuning.DRIFT_ACTION)
	var touch_controls: KartTouchControls = core.get_node("HUD/KartTouchControls")
	var steer_left_button: Button = touch_controls._buttons[KartTuning.STEER_LEFT_ACTION]["control"]
	var steer_right_button: Button = touch_controls._buttons[KartTuning.STEER_RIGHT_ACTION]["control"]
	touch_controls._update_pointer(101, steer_left_button.get_global_rect().get_center(), true)
	touch_controls._update_pointer(202, steer_right_button.get_global_rect().get_center(), true)
	if not _expect(Input.is_action_pressed(KartTuning.STEER_LEFT_ACTION) and Input.is_action_pressed(KartTuning.STEER_RIGHT_ACTION), "Touch steering buttons must support simultaneous holds"):
		return
	touch_controls._update_pointer(101, Vector2.ZERO, false)
	if not _expect(not Input.is_action_pressed(KartTuning.STEER_LEFT_ACTION) and Input.is_action_pressed(KartTuning.STEER_RIGHT_ACTION), "Releasing one steering pointer must leave the other held"):
		return
	touch_controls._update_pointer(202, Vector2.ZERO, false)
	var gas_button: Button = touch_controls._buttons[KartTuning.ACCELERATE_ACTION]["control"]
	var drift_button: Button = touch_controls._buttons[KartTuning.DRIFT_ACTION]["control"]
	touch_controls._update_pointer(303, gas_button.get_global_rect().get_center(), true)
	touch_controls._update_pointer(404, drift_button.get_global_rect().get_center(), true)
	if not _expect(Input.is_action_pressed(KartTuning.ACCELERATE_ACTION) and Input.is_action_pressed(KartTuning.DRIFT_ACTION), "Touch must allow GAS and DRIFT to be held together"):
		return
	touch_controls._update_pointer(303, Vector2.ZERO, false)
	touch_controls._update_pointer(404, Vector2.ZERO, false)
	print("KART_CORE_SMOKE_OK")
	print("TRACK_LENGTH %.1f | FULL_SPEED_LAP_SECONDS %.1f" % [core.track.track_length, core.track.track_length / KartTuning.MAX_SPEED])
	kart_scene.queue_free()
	await process_frame
	quit(0)


func _feed_next_gate(core: KartCore, gate_index: int, from_offset: float) -> float:
	var target_offset := core.track.get_gate_offset(gate_index)
	var distance_forward := fposmod(target_offset - from_offset, core.track.track_length)
	var overshoot := KartTuning.MIN_TRACK_DELTA * 2.0
	core._advance_ordered_gates(from_offset, distance_forward + overshoot)
	return fposmod(target_offset + overshoot, core.track.track_length)


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
