extends SceneTree
## Run with --headless --path . --script res://tools/test_round_results.gd -- --qa-results-marker.
## The marker disables personal-record saves; use an isolated APPDATA for settings/logs.

var game: Node3D
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		push_error("FAIL: " + message)
		failures += 1


func _frames(count: int) -> void:
	for index in count:
		await physics_frame


func _freeze_actors() -> void:
	for index in game.combatants.size():
		var actor: Node3D = game.combatants[index]
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.global_position = Vector3(150 + index * 8, 0, 100)
		if actor != game.player:
			actor.spawn_protection_remaining = 0.0
	game.player.global_position = Vector3(100, 0, 100)
	game.player.rotation = Vector3.ZERO
	game.player.neck.rotation = Vector3.ZERO
	game.player.fire_cooldown = 0.0


func _run() -> void:
	if "--qa-results-marker" not in OS.get_cmdline_user_args():
		push_error("Refusing results test without --qa-results-marker; user records must remain untouched.")
		quit(1)
		return
	seed(46537)
	var music := root.get_node_or_null("Music") as AudioStreamPlayer
	if music:
		music.stop()
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.selected_lives = 3
	game.selected_difficulty = "hard"
	game._start_round()
	_freeze_actors()
	await _frames(6)
	_expect(game.round_stats.shots == 0 and game.round_stats.accuracy() == 0, "zero-shot accuracy is safe")
	var shooter: Node3D = game.player
	var target: Node3D = game.combatants[1]
	for index in [2, 3]:
		var other: Node3D = game.combatants[index]
		other.lives_remaining = 0
		other.is_alive = false
		other.collision_layer = 0
	target.lives_remaining = 1
	target.health = 90
	target.global_position = Vector3(100, 0, 95)
	shooter.equip_weapon("bazooka")
	shooter.neck.rotation.x = -atan(0.59 / 5.0)
	await _frames(2)
	shooter._fire()
	_expect(target.health == 90 and game.round_stats.shots == 1, "actual player launch records one shot before delayed impact")
	await create_timer(0.85, false).timeout
	_expect(game.result_title.text == "YOU WIN!" and game.loss_root.visible, "final travelling rocket opens actual win screen")
	_expect(game.round_stats.kills == 1 and game.round_stats.accuracy() == 100, "winning delayed rocket receives kill and 100% accuracy credit")
	_expect("1 KILLS" in game.loss_note.text and "100% ACCURACY" in game.loss_note.text, "win summary includes final projectile hit")
	_expect(not FileAccess.file_exists("user://singleplayer_records.cfg"), "QA win never writes personal records")
	game._play_again_after_loss()
	_freeze_actors()
	await _frames(3)
	_expect(game.round_stats.shots == 0 and game.round_stats.kills == 0 and game.round_stats.successful_shots.is_empty() and game.round_stats.active, "replay resets counters and starts a new stats session")
	_expect(game.selected_difficulty == "hard" and game.selected_lives == 3, "replay preserves difficulty and bot lives")
	for actor in game.combatants:
		if actor != game.player:
			_expect(actor.difficulty == "hard" and actor.lives_remaining == 3, "replayed bots use selected rules")
	shooter = game.player
	target = game.combatants[1]
	target.global_position = Vector3(100, 0, 98)
	shooter.neck.rotation.x = -atan(0.59 / 2.0)
	shooter.equip_weapon("shotgun")
	await _frames(2)
	shooter._fire()
	_expect(target.health <= 76, "actual shotgun hits opponent with multiple pellets")
	_expect(game.round_stats.shots == 1 and game.round_stats.successful_shots.size() == 1 and game.round_stats.accuracy() == 100, "shotgun pellets count as one successful trigger pull")
	shooter.register_toilet_flush(0)
	shooter.register_toilet_flush(1)
	game.round_stats.elapsed = 65.0
	shooter.apply_damage(100, target)
	await _frames(3)
	_expect(game.result_title.text == "YOU LOST" and game.loss_root.visible, "actual human death opens loss screen")
	_expect(game.player == null and game.combatants.is_empty(), "loss clears actors after collecting results")
	_expect("100% ACCURACY" in game.loss_note.text and "2 / 3 TOILETS FLUSHED" in game.loss_note.text and "01:05" in game.loss_note.text, "loss preserves accuracy, toilet count and elapsed time")
	game._play_again_after_loss()
	_freeze_actors()
	await _frames(3)
	target = game.combatants[1]
	var pending_bot: WeakRef = weakref(target)
	target.apply_damage(100, game.player)
	_expect(target.lives_remaining == 2 and not target.is_alive, "bot death schedules remaining-life respawn")
	game._show_main_menu()
	await create_timer(1.3, false).timeout
	_expect(game.menu_root.visible and game.combatants.is_empty() and game.player == null, "returning to menu cancels pending respawn")
	_expect(pending_bot.get_ref() == null, "pending dead bot is freed without later resurrection")
	_expect(not game.round_stats.active and not paused and get_nodes_in_group("singleplayer_round_effects").is_empty(), "menu leaves stats, pause and effects clean")
	game.queue_free()
	var sound := root.get_node_or_null("SoundEffects")
	if sound:
		sound.stop_all()
	await _frames(2)
	print("Round results QA: %d failures" % failures)
	quit(1 if failures else 0)
