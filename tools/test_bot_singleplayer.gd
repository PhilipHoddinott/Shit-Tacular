extends SceneTree
## Run with Godot --headless --path . --script res://tools/test_bot_singleplayer.gd.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(73419)
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for map_name in ["basment", "2nd floor"]:
		game._load_floor_plan(map_name)
		game._start_round()
		for actor in game.combatants:
			actor.set_physics_process(false)
			actor.set_process(false)
			actor.collision_layer = 0
		var bot := game.combatants[1] as ApartmentBot
		bot.collision_layer = 2
		var saved: Array = game.combatants.duplicate()
		game.combatants.assign([bot])
		for frame in 6:
			await physics_frame
		assert(not game.navigation_pending, "Navigation must be ready for toilet route checks")
		bot.difficulty = "easy"
		var easy_reaction := bot.reaction_delay()
		var easy_spread := bot.aiming_spread()
		var easy_cadence := bot.shot_interval()
		bot.difficulty = "hard"
		assert(bot.reaction_delay() < easy_reaction and bot.aiming_spread() < easy_spread and bot.shot_interval() < easy_cadence, "Difficulty must affect reaction, spread and cadence")
		bot.difficulty = "normal"
		assert(bot.health == 100 and bot.current_weapon == "pistol" and bot.damage == 24, "All bots must begin with 100 health and 24-damage pistols")
		for count in 3:
			bot._choose_toilet_objective()
			assert(is_instance_valid(bot.toilet_target), "Every unflushed toilet needs a reachable approach on %s" % map_name)
			var toilet: Node3D = bot.toilet_target
			var route: PackedVector3Array = game.find_apartment_path(bot.global_position, bot.destination)
			assert(not route.is_empty() and route[route.size() - 1].distance_to(bot.destination) < 0.4, "Toilet objectives must end at a physically clear approach")
			bot.global_position = bot.destination
			await physics_frame
			await physics_frame
			assert(bot._can_flush_toilet(toilet), "Bot must be able to see and reach its chosen toilet")
			toilet.interact(bot)
			assert(bot.flushed_toilets.size() == count + 1, "Each unique toilet must count once")
			var reward := bot.current_weapon
			toilet.interact(bot)
			assert(bot.flushed_toilets.size() == count + 1 and bot.current_weapon == reward, "Repeated flushing must not farm weapons")
			bot.toilet_target = null
		assert(bot.current_weapon == "rainbow_rifle" and bot.damage == 40, "Three unique flushes must grant a 40-damage rainbow rifle")
		bot.respawn_at(bot.global_position, 0.0)
		assert(bot.flushed_toilets.size() == 3 and bot.current_weapon == "rainbow_rifle", "Respawn must preserve toilet progress and weapon reward")
		bot.apply_damage(100)
		assert(bot.is_alive and bot.health == 100 and bot.spawn_ring.visible, "Respawn grace must block incoming damage and display a ring")
		var fire_before := bot.fire_time
		bot._shoot(bot.global_position + Vector3.FORWARD * 3.0)
		assert(bot.fire_time == fire_before, "Respawn grace must block outgoing shots")
		bot.set_physics_process(true)
		var grace_before := bot.spawn_protection_remaining
		var position_before := bot.global_position
		paused = true
		for frame in 3:
			await process_frame
		assert(bot.spawn_protection_remaining == grace_before and bot.global_position == position_before, "Pausing must freeze bot behavior and the spawn protection timer")
		paused = false
		bot.set_physics_process(false)
		bot._physics_process(ApartmentBot.SPAWN_GRACE + 0.01)
		assert(bot.spawn_protection_remaining == 0.0 and not bot.spawn_ring.visible, "Protection must expire after 1.2 gameplay seconds")
		bot.apply_damage(1)
		assert(bot.health == 99, "Damage must work after spawn protection expires")
		# Isolate the strafe check from apartment furniture placement.
		var arena := Node3D.new()
		game.add_child(arena)
		_add_solid(arena, Vector3(100, -0.1, 100), Vector3(6, 0.2, 6))
		_add_solid(arena, Vector3(100.55, 1.0, 100), Vector3(0.2, 2, 4))
		var blocked_toilet := FlushableToilet.new()
		blocked_toilet.setup(99, StandardMaterial3D.new())
		arena.add_child(blocked_toilet)
		blocked_toilet.global_position = Vector3(101.2, 0, 100)
		bot.global_position = Vector3(100, 0.05, 100)
		bot.rotation = Vector3.ZERO
		bot.velocity = Vector3.ZERO
		await physics_frame
		await physics_frame
		assert(not bot._can_strafe(Vector3.RIGHT), "Bot strafe must reject a nearby wall")
		assert(bot._can_strafe(Vector3.LEFT), "Bot strafe must accept an open floor")
		assert(not bot._can_flush_toilet(blocked_toilet), "Bots cannot flush a toilet through a wall even within interaction range")
		bot.strafe_time = 10.0
		bot.strafe_sign = 1.0
		bot._strafe(0.1)
		assert(bot.velocity.x < 0.0, "Blocked strafing must choose the clear opposite side")
		bot.global_position = Vector3(97.35, 0.05, 100)
		await physics_frame
		assert(not bot._can_strafe(Vector3.LEFT), "Bot strafe must reject a floor edge")
		arena.queue_free()
		game.combatants.assign(saved)
		game._clear_combatants()
		game._show_main_menu()
		print("QA_BOT_SINGLEPLAYER_OK ", map_name)
	root.get_node("SoundEffects").stop_all()
	root.get_node("Music").stop()
	game.queue_free()
	await process_frame
	await create_timer(0.05).timeout
	quit()


func _add_solid(parent: Node3D, location: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = location
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
