extends SceneTree
## Run headlessly with an isolated APPDATA directory; never uses real preferences.

var failures := 0
var timer_fired := false


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	var settings := root.get_node("Settings")
	var original: Dictionary = settings.snapshot()
	settings.apply_values({"sensitivity": 1.45, "fov": 96.0, "music_volume": 0.35, "sfx_volume": 0.6, "music_enabled": false, "floorplan_floor": false})
	settings.apply_values(settings.DEFAULTS, false)
	settings.load_settings()
	_expect(is_equal_approx(settings.sensitivity, 1.45) and is_equal_approx(settings.fov, 96.0), "Sensitivity and FOV survive save/load")
	_expect(is_equal_approx(settings.music_volume, 0.35) and is_equal_approx(settings.sfx_volume, 0.6) and not settings.music_enabled and not settings.floorplan_floor, "Audio and floor preferences survive save/load")
	settings.apply_values({"sensitivity": -5, "fov": 400, "music_volume": -1, "sfx_volume": 5}, false)
	_expect(is_equal_approx(settings.sensitivity, 0.25) and is_equal_approx(settings.fov, 110.0), "Camera preferences are clamped")
	_expect(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")) and is_equal_approx(settings.sfx_volume, 1.0), "Volume clamps and zero volume mutes its bus")
	settings.apply_values({"sensitivity": "bad", "fov": NAN}, false)
	_expect(is_equal_approx(settings.sensitivity, 1.0) and is_equal_approx(settings.fov, 78.0), "Invalid numeric preferences fall back safely")
	settings.reset_defaults()
	_expect(settings.snapshot() == settings.DEFAULTS, "Reset restores every default")
	var scene := load("res://main.tscn") as PackedScene
	if not scene:
		settings.apply_values(original)
		quit(1)
		return
	var game := scene.instantiate()
	root.add_child(game)
	current_scene = game
	for frame in range(5):
		await physics_frame
	var overlay: Control = game.pause_menu
	overlay.open_settings()
	_expect(overlay.visible and not paused and overlay.resume_button.text == "BACK", "Main-menu settings do not pause or start a round")
	_expect(overlay.resume_button.has_focus(), "Opening settings establishes keyboard focus")
	overlay.resume()
	_expect(not overlay.visible and not paused and game.menu_root.visible, "Back returns to the main menu")
	game.selected_lives = 2
	game._start_round()
	await physics_frame
	var human: Node3D = game.player
	settings.set_fov(96.0)
	human._update_aim(1.0)
	_expect(is_equal_approx(human.camera.fov, 96.0), "FOV preference changes the live camera")
	if DisplayServer.get_name() != "headless":
		Input.action_press("aim")
		human._update_aim(1.0)
		_expect(is_equal_approx(human.camera.fov, 55.0 * 96.0 / 78.0), "Aiming preserves the weapon zoom ratio with a custom FOV")
		Input.action_release("aim")
		settings.set_sensitivity(2.0)
		human.camera.fov = settings.fov
		var yaw_before := human.rotation.y
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(10.0, 0.0)
		human._unhandled_input(motion)
		_expect(is_equal_approx(human.rotation.y - yaw_before, -10.0 * 0.0021 * 2.0), "Sensitivity preference scales actual mouse-look")
	else:
		print("SKIP: Mouse-capture-dependent zoom/look checks require a graphical display server")
	settings.reset_defaults()
	var dead_bot: Node = game.combatants[1]
	dead_bot.apply_damage(1000, human)
	_expect(not dead_bot.is_alive and dead_bot.lives_remaining == 1, "Bot is waiting for its actual respawn timer")
	human.health = 40
	human.regeneration.cooldown = 0.8
	human.fire_cooldown = 0.7
	var health_before: int = human.health
	var position_before := human.global_position
	var bot_position: Vector3 = game.combatants[2].global_position
	create_timer(0.1, false).timeout.connect(func(): timer_fired = true)
	_send_key(KEY_ESCAPE)
	_expect(paused and overlay.visible and not human.input_enabled, "Escape pauses the scene tree and disables player input")
	await create_timer(1.35, true).timeout
	_expect(human.global_position.is_equal_approx(position_before) and game.combatants[2].global_position.is_equal_approx(bot_position), "Player and bots stay frozen during pause")
	_expect(human.health == health_before and is_equal_approx(human.regeneration.cooldown, 0.8) and is_equal_approx(human.fire_cooldown, 0.7), "Health regeneration and weapon cooldown stay frozen")
	_expect(not timer_fired and not dead_bot.is_alive, "Gameplay timers and real bot respawn stay frozen")
	var was_enabled: bool = settings.music_enabled
	_send_key(KEY_M)
	_expect(settings.music_enabled != was_enabled and overlay.music_checkbox.button_pressed == settings.music_enabled, "M toggles persistent music and updates the paused checkbox")
	_expect(root.get_node("Music").stream_paused == (not settings.music_enabled), "Soundtrack follows the M toggle while paused")
	Input.action_press("fire")
	Input.action_press("aim")
	_send_key(KEY_ESCAPE)
	_expect(not paused and not overlay.visible and human.input_enabled, "Escape resumes gameplay")
	_expect(not Input.is_action_pressed("fire") and not Input.is_action_pressed("aim"), "Resume clears fire and aim so the menu click cannot shoot")
	human.input_enabled = false
	for actor in game.combatants:
		if actor != human:
			actor.set_physics_process(false)
	await create_timer(1.25).timeout
	_expect(timer_fired and dead_bot.is_alive, "Gameplay timers and the pending bot respawn continue after resume")
	game.network_match_started = true
	_expect(not overlay.open_pause() and not paused, "A network match cannot pause the scene tree")
	overlay.open_settings()
	_expect(not overlay.visible and not paused, "Network matches cannot enter the single-player settings overlay")
	game.network_match_started = false
	game._show_main_menu()
	await process_frame
	overlay.open_settings()
	settings.set_fov(90)
	_expect(is_equal_approx(overlay.sliders.fov.value, 90.0), "Changing a preference synchronizes its visible slider")
	overlay.size = Vector2(640, 480)
	overlay._fit_panel()
	await process_frame
	_expect(overlay.panel.position.x >= 0 and overlay.panel.position.y >= 0 and overlay.panel.size.x <= 640 and overlay.panel.size.y <= 480, "Pause/settings panel fits a 640x480 layout")
	overlay.close_for_transition()
	settings.apply_values(original)
	settings.load_settings()
	_expect(settings.snapshot() == original, "Original preferences restored after the test")
	game.queue_free()
	await process_frame
	print("PAUSE_SETTINGS_QA: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)


func _send_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
