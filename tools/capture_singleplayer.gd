extends SceneTree

var game: Node3D

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await _capture("polish_menu")
	game.pause_menu.open_settings()
	await _capture("polish_settings")
	game.pause_menu.resume()
	game._start_round()
	for actor in game.combatants:
		actor.set_physics_process(false)
	game.player.position = game._expanded(Vector3(6.8, 0.05, 5.55))
	game.player.rotation.y = 0
	game.player.register_toilet_flush(1)
	game.player.register_toilet_flush(2)
	game.player.register_toilet_flush(3)
	game._show_banner("TRIPLE-SHIT!", 5)
	await _capture("polish_gameplay")
	game.pause_menu.open_pause()
	await _capture("polish_pause")
	game.pause_menu.resume()
	var settings: Node = root.get_node("Settings")
	settings.apply_values({"floorplan_floor": false}, false)
	game.banner_time = 0
	await _capture("polish_floors")
	var toilet: Node3D = game.get_toilets()[0]
	game.player.global_position = toilet.to_global(Vector3(0, 0.05, -2.1))
	game.player.camera.look_at(toilet.global_position + Vector3.UP * 1.05)
	await _capture("polish_bathroom")
	game.round_stats.elapsed = 85
	game.round_stats.kills = 3
	game.round_stats.shots = 12
	for shot in range(1, 10):
		game.round_stats.record_hit(shot)
	game._show_singleplayer_results(true)
	await _capture("polish_results")
	game._show_main_menu()
	game._load_floor_plan("2nd floor")
	game._start_round()
	for actor in game.combatants:
		actor.set_physics_process(false)
	game.player.global_position = game.SecondFloor.point(280, 750) + Vector3.UP * 0.05
	game.player.rotation.y = 0
	await _capture("polish_second_floor")
	settings.load_settings()
	root.get_node("Music").stop()
	root.get_node("SoundEffects").stop_all()
	game.queue_free()
	await process_frame
	quit()

func _capture(file_name: String) -> void:
	for _frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://artifacts/" + file_name + ".png")
	print("QA_POLISH_CAPTURE ", file_name, " ", result)
