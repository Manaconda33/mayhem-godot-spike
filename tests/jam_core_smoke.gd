extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _expect(FileAccess.file_exists("res://scenes/jam/jam_core.tscn"), "Jam core scene must exist"):
		return
	if not _expect(FileAccess.file_exists("res://shared/jam_tuning.gd"), "Central Jam tuning must exist"):
		return
	var jam_scene: PackedScene = load("res://scenes/jam/jam_core.tscn")
	if not _expect(jam_scene != null, "Jam core scene must load"):
		return
	var game = jam_scene.instantiate()
	root.add_child(game)
	await process_frame

	if not _expect(game.player_team.size() == 2, "Jam roster must create two player athletes"):
		return
	if not _expect(game.opponents.size() == 2, "Jam scene must create two CPU defenders"):
		return
	if not _expect(game.controlled_player.character_name == "Manaconda", "Manaconda must start controlled"):
		return
	if not _expect(game.ball.state_name() == "HELD", "The player team must inbound with the ball"):
		return

	var staging: Dictionary = game.get_staging_readings()
	print("Staging readings: ", staging)
	if not _expect(absf(staging.visible_court_pct - 0.50) <= 0.02, "Rest camera must show half the court"):
		return
	if not _expect(absf(staging.controlled_height_pct - 0.33) <= 0.03, "Near-side athlete must meet staging height"):
		return
	if not _expect(absf(staging.teammate_height_pct - 0.28) <= 0.03, "Far-side athlete must meet staging height"):
		return
	game._toggle_debug()
	await process_frame
	print("Near-sideline debug overlay: ", game._debug_label.text)
	if not _expect(game._debug_label.visible and game._debug_label.text.contains("COURT 50.0%") and game._debug_label.text.contains("ATHLETE 32.8%"), "Debug overlay must show accurate camera, coverage, and athlete metrics"):
		return

	var start_x: float = game.controlled_player.court_position.x
	Input.action_press("move_right")
	Input.action_press("turbo")
	await create_timer(0.25).timeout
	Input.action_release("move_right")
	Input.action_release("turbo")
	if not _expect(game.controlled_player.court_position.x > start_x, "Movement action must move the controlled athlete"):
		return
	if not _expect(game.turbo_meter < game.tuning.TURBO_CAPACITY, "Held turbo action must drain its meter"):
		return

	var first_handler = game.controlled_player
	game.on_pass_pressed()
	if not _expect(game.ball.state_name() == "IN_FLIGHT_PASS", "Pass input must launch the ball"):
		return
	await create_timer(game.tuning.PASS_FLIGHT_TIME + 0.1).timeout
	if not _expect(game.ball.state_name() == "HELD", "Completed pass must return the ball to HELD"):
		return
	if not _expect(game.controlled_player != first_handler, "Pass catch must transfer control to the receiver"):
		return

	game.controlled_player.court_position = game.attacked_hoop_position - Vector2(game.tuning.DUNK_RANGE * 0.45, 0.0)
	for frame in 120:
		game._camera.update_follow(game.controlled_player.court_position, game.attacked_hoop_position, game.attack_direction, 1.0 / 60.0)
	var hoop_staging: Dictionary = game.get_staging_readings()
	if not _expect(hoop_staging.attack_rim_screen_pct >= 0.70 and hoop_staging.attack_rim_screen_pct <= 0.80, "Framed right rim must sit within the 70–80% viewport band"):
		return
	game.on_shoot_pressed()
	if not _expect(game.ball.state_name() == "DUNKING", "A close-range shoot press must begin a dunk"):
		return
	await create_timer(game.tuning.DUNK_DURATION + game.tuning.SCORE_PAUSE_TIME + 0.2).timeout
	if not _expect(game.score == game.tuning.TWO_POINT_SCORE, "Dunk must deterministically score two points"):
		return
	if not _expect(game.ball.state_name() == "HELD", "Dunk score and reset must return to live possession"):
		return
	if not _expect(game.controlled_player.character_name == "Manaconda", "Made basket reset must restore Manaconda as inbound handler"):
		return

	game.on_shoot_pressed()
	if not _expect(game.controlled_player.state_name() == "JUMPING", "Shoot press must start the jump"):
		return
	await create_timer(game.tuning.JUMP_RISE_TIME * 0.9).timeout
	game.on_shoot_released()
	if not _expect(game.ball.state_name() == "IN_FLIGHT_SHOT", "Shoot release must launch the ball"):
		return
	game._pending_make_pct = game.tuning.SHOT_PERFECT_MIN_PCT
	await create_timer(game.tuning.SHOT_FLIGHT_TIME + 0.1).timeout
	if not _expect(game.ball.state_name() == "LOOSE", "Forced miss must exit shot flight into LOOSE"):
		return
	await create_timer(game.tuning.LOOSE_RESET_TIMEOUT + 0.2).timeout
	if not _expect(game.ball.state_name() == "HELD", "Untouched loose ball must time out through RESETTING into HELD"):
		return

	game.on_shoot_pressed()
	await create_timer(game.tuning.JUMP_RISE_TIME + game.tuning.JUMP_FALL_TIME + 0.1).timeout
	if not _expect(game.controlled_player.state_name() == "READY", "Unreleased jump must land cleanly as a pump fake"):
		return
	game.on_shoot_released()
	if not _expect(game.ball.state_name() == "HELD", "Pump fake must retain possession"):
		return

	game.free()
	game = null
	jam_scene = null
	await process_frame
	print("Jam core smoke test passed")
	quit(0)


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("Jam core smoke test failed: " + message)
	quit(1)
	return false
