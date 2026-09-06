extends RefCounted
## Run with --headless --path . -- --qa-singleplayer.

class InteractableTarget extends StaticBody3D:
	var used := false
	func interact(_actor: Node) -> void:
		used = true
	func interaction_text(_actor: Node) -> String:
		return "TEST USE"

func run(game: Node3D) -> void:
	var stats := preload("res://scripts/round_stats.gd").new()
	stats.start("basment", "normal", 1)
	stats.record_shot()
	stats.record_shot()
	stats.record_shot()
	stats.record_hit(1)
	stats.record_hit(1)
	stats.record_hit(3)
	stats.record_hit(-1)
	stats.tick(65)
	assert(stats.accuracy() == 67 and stats.clock_text() == "01:05", "Accuracy counts trigger pulls, not pellets")
	var summary := stats.finish(true, 3, false)
	stats.tick(5)
	assert(stats.elapsed == 65 and "3 / 3" in summary, "Results freeze the clock and toilet count")
	assert(stats.finish(false, 0, false) == summary, "Finishing twice must not change the result")
	for map_name in ["basment", "2nd floor"]:
		game._load_floor_plan(map_name)
		game.selected_lives = 2
		game.selected_difficulty = "normal"
		game._start_round()
		for actor in game.combatants:
			actor.set_physics_process(false)
		await _frames(game, 6)
		assert(game.get_toilets().size() == 3)
		assert(game.combatants.size() == 4 and game.player.lives_remaining == 1)
		game.minimap.refresh_map()
		for toilet in game.get_toilets():
			assert(game.minimap.map_rect.has_point(game.minimap.map_position(toilet.global_position)), "Toilet markers must align on both maps")
		var old_floor_setting: bool = Settings.floorplan_floor
		Settings.floorplan_floor = false
		game._apply_floor_style()
		assert(not game.get_node("FloorplanOverlay").visible)
		assert(game.minimap.floor_texture != null, "Minimap must remain when the floor drawing is hidden")
		for finish in game.get_tree().get_nodes_in_group("optional_room_floors"):
			assert(finish.visible)
		Settings.floorplan_floor = old_floor_setting
		game._apply_floor_style()
		var spawn: Vector3 = game._choose_respawn_position(game.combatants[1])
		assert(game.spawn_positions.has(spawn), "Respawn must choose a known position")
		assert(game.get_world_3d().direct_space_state.intersect_shape(game._walk_query(spawn)).is_empty(), "Respawn footprint must be clear")
		# Test the actual player query in an isolated part of the physics world.
		var actor: FpsPlayer = game.player
		actor.global_position = Vector3(100, 0, 100)
		actor.rotation = Vector3.ZERO
		actor.neck.rotation = Vector3.ZERO
		var target := InteractableTarget.new()
		target.collision_layer = 5
		target.position = Vector3(100, 1.34, 98)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.6, 1, 0.3)
		shape.shape = box
		target.add_child(shape)
		game.add_child(target)
		await _frames(game, 2)
		assert(actor.get_interaction_prompt() == "TEST USE", "Visible interaction must remain usable")
		var blocker: Node3D = game._create_box("TestOccluder", Vector3(100, 1.34, 99), Vector3(1, 2, 0.12), game.white_material, true)
		await _frames(game, 2)
		assert(actor.get_interaction_prompt().is_empty(), "A wall must block the interaction prompt")
		actor._interact()
		assert(not target.used, "A wall must block the actual interaction")
		blocker.queue_free()
		await _frames(game, 2)
		actor._interact()
		assert(target.used)
		target.queue_free()
		# Replay/menu must remove rockets, even if a projectile is still in flight.
		game.spawn_rocket(actor.camera.global_position, Vector3.FORWARD, actor, 90)
		assert(not game.get_tree().get_nodes_in_group("singleplayer_round_effects").is_empty())
		game._show_main_menu()
		await _frames(game, 2)
		assert(game.combatants.is_empty() and game.player == null)
		assert(game.get_tree().get_nodes_in_group("singleplayer_round_effects").is_empty())
		assert(not game.round_stats.active and not game.get_tree().paused)
		print("QA_SINGLEPLAYER_OK ", map_name, " stats objectives floor-style interaction respawn cleanup")
	game.get_tree().quit()

func _frames(game: Node, count: int) -> void:
	for _index in count:
		await game.get_tree().physics_frame
