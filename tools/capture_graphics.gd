extends SceneTree
## Render and inspect the first Blender graphics slice, including weapon swaps.
var game: Node3D

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game._start_round()
	for actor in game.combatants:
		actor.set_physics_process(false)
	game.player.position = game._expanded(Vector3(6.8, 0.05, 5.55))
	game.player.rotation.y = 0
	game.banner_time = 0
	var settings := root.get_node("Settings")
	settings.apply_values({"floorplan_floor": false}, false)
	await create_timer(0.3).timeout
	await capture("graphics_living_room")
	var model: Node = game.player.weapon_root.get_child(-1)
	assert(model.slide != null, "Imported pistol must retain its sliding upper")
	assert(model.overlay.visible, "Local pistol must render its hands")
	game.player.input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.action_press("aim")
	game.player._update_aim(1)
	await capture("graphics_pistol_aim")
	Input.action_release("aim")
	game.player._update_aim(1)
	game.player._fire()
	await capture("graphics_pistol_fire")
	for weapon in ["shotgun", "rifle", "bazooka", "rainbow_rifle", "pistol"]:
		game.player.equip_weapon(weapon)
		await process_frame
		await process_frame
		var layers := game.find_children("*", "CanvasLayer", true, false)
		assert(layers.size() == (2 if weapon == "pistol" else 1), "Weapon changes must remove old viewmodel overlays")
	game.player.recoil = 0
	game.player.weapon_root.rotation = Vector3.ZERO
	game.pause_menu.open_pause()
	await capture("graphics_pause")
	game.pause_menu.resume()
	game._show_main_menu()
	await process_frame
	assert(game.find_children("*", "SubViewport", true, false).is_empty(), "Main menu must free the viewmodel render pass")
	settings.load_settings()
	root.get_node("Music").stop()
	root.get_node("SoundEffects").stop_all()
	game.queue_free()
	await process_frame
	print("GRAPHICS_QA_OK imported pistol sights swaps overlay cleanup")
	quit()

func capture(file_name: String) -> void:
	for _frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://artifacts/" + file_name + ".png")
	assert(error == OK)
	print("GRAPHICS_CAPTURE ", file_name)
