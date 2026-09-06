extends SceneTree

const Combat := preload("res://scripts/singleplayer_combat.gd")

class Arena extends Node3D:
	var combatants: Array = []
	var round_over := false
	var explosions := 0
	var recorded_hits: Array[int] = []
	func emit_world_sound(_effect: String, _position: Vector3) -> void:
		pass
	func record_projectile_hit(_attacker: Node, shot_id: int) -> void:
		recorded_hits.append(shot_id)
	func spawn_explosion(position: Vector3, attacker: Node, radius: float, max_damage: int, direct_hit: Node = null, normal: Vector3 = Vector3.ZERO, shot_id: int = -1) -> void:
		explosions += 1
		Combat.explode(self, position, attacker, radius, max_damage, direct_hit, normal, shot_id)

class Dummy extends CharacterBody3D:
	var health := 100
	var is_alive := true
	var active_shot_id := 7
	var hit_count := 0
	var spawn_grace := false
	func _ready() -> void:
		collision_layer = 2
		collision_mask = 0
		var collider := CollisionShape3D.new()
		var shape := CapsuleShape3D.new()
		shape.height = 1.5
		shape.radius = 0.25
		collider.shape = shape
		collider.position.y = 0.75
		add_child(collider)
	func apply_damage(amount: int, _attacker: Node) -> void:
		if spawn_grace:
			return
		hit_count += 1
		health = maxi(health - amount, 0)
		is_alive = health > 0

var failures := 0
var arena: Arena


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		push_error("FAIL: " + message)
		failures += 1


func _dummy(position: Vector3) -> Dummy:
	var dummy := Dummy.new()
	arena.add_child(dummy)
	dummy.position = position
	arena.combatants.append(dummy)
	return dummy


func _wall(position: Vector3, size: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	wall.add_child(collider)
	arena.add_child(wall)
	wall.position = position
	return wall


func _run() -> void:
	var music := root.get_node_or_null("Music") as AudioStreamPlayer
	if music:
		music.stop()
	arena = Arena.new()
	root.add_child(arena)
	var shooter := _dummy(Vector3(0, 0, 2))
	var direct := _dummy(Vector3.ZERO)
	var exposed := _dummy(Vector3(-1.0, 0, 0))
	var hidden := _dummy(Vector3(1.0, 0, 0))
	var wall := _wall(Vector3(0.55, 0.8, 0), Vector3(0.08, 2.0, 4.0))
	await physics_frame
	await physics_frame
	Combat.explode(arena, Vector3(0, 1.1, 0.25), shooter, 2.6, 90, direct, Vector3.BACK, 7)
	_expect(direct.health == 10 and direct.hit_count == 1, "direct rocket hit does full 90 exactly once")
	_expect(shooter.health == 100, "shooter immunity preserved")
	_expect(exposed.health < 100 and exposed.health > 10, "nearby exposed target receives falloff splash")
	_expect(hidden.health == 100, "thin wall blocks splash")
	_expect(arena.recorded_hits.size() == 2 and arena.recorded_hits[0] == 7, "delayed hit accounting carries launch shot id")
	_expect(not arena.has_meta("projectile_damage"), "damage context restored")
	exposed.spawn_grace = true
	var grace_health := exposed.health
	var grace_hit_count := arena.recorded_hits.size()
	Combat.explode(arena, exposed.position + Vector3.UP * 0.75, shooter, 0.2, 90, exposed, Vector3.BACK, 8)
	_expect(exposed.health == grace_health and arena.recorded_hits.size() == grace_hit_count, "spawn grace blocks damage and accuracy credit")
	for body in [direct, exposed, hidden, wall]:
		body.queue_free()
	arena.combatants = [shooter]
	await physics_frame
	await physics_frame
	var target := _dummy(Vector3(0, 0, -4))
	await physics_frame
	await physics_frame
	var rocket := Combat.spawn_rocket(arena, Vector3(0, 0.75, 1), Vector3.FORWARD, shooter, 90)
	_expect(target.health == 100, "launch does not deal instant damage")
	_expect((-rocket.global_basis.z).dot(Vector3.FORWARD) > 0.999, "rocket nose points along trajectory")
	shooter.is_alive = false
	for frame in 40:
		await physics_frame
		if not is_instance_valid(rocket):
			break
	_expect(target.health == 10 and target.hit_count == 1, "travelling rocket still hits after shooter dies while round continues")
	shooter.is_alive = true
	target.queue_free()
	arena.combatants = [shooter]
	await physics_frame
	await physics_frame
	_wall(Vector3(0, 0.8, -0.5), Vector3(4, 2, 0.015))
	var behind := _dummy(Vector3(0, 0, -1.2))
	await physics_frame
	await physics_frame
	var before := arena.explosions
	rocket = Combat.spawn_rocket(arena, Vector3(0, 0.75, 1), Vector3.FORWARD, shooter, 90)
	for frame in 25:
		await physics_frame
		if not is_instance_valid(rocket):
			break
	_expect(arena.explosions == before + 1, "swept collision catches 15 mm wall")
	_expect(behind.health == 100, "rocket cannot damage target through thin wall")
	var multi_a := _dummy(Vector3(-3, 0, 0))
	var multi_b := _dummy(Vector3(-3.6, 0, 0))
	multi_a.health = 20
	multi_b.health = 20
	await physics_frame
	await physics_frame
	Combat.explode(arena, Vector3(-3, 0.75, 0), shooter, 2.6, 90, multi_a, Vector3.ZERO, 9)
	_expect(not multi_a.is_alive and not multi_b.is_alive and multi_a.hit_count == 1 and multi_b.hit_count == 1, "one explosion can eliminate multiple opponents exactly once")
	rocket = Combat.spawn_rocket(arena, Vector3(0, 0.75, 1), Vector3.RIGHT, shooter, 90)
	paused = true
	var paused_position := rocket.global_position
	await create_timer(0.1, true).timeout
	_expect(rocket.global_position == paused_position, "pause freezes travelling rocket")
	paused = false
	arena.round_over = true
	await physics_frame
	await physics_frame
	_expect(not is_instance_valid(rocket), "round over cancels in-flight rocket")
	for effect in get_nodes_in_group("singleplayer_round_effects"):
		effect.queue_free()
	arena.queue_free()
	await process_frame
	await process_frame
	_expect(get_nodes_in_group("singleplayer_round_effects").is_empty(), "round effects clean up without orphaned smoke or captions")
	print("Rocket QA: %d failures" % failures)
	quit(1 if failures else 0)
