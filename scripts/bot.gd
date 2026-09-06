class_name ApartmentBot
extends CharacterBody3D

signal died(combatant: Node)

const MAX_HEALTH := 100
const DAMAGE := 24
const MOVE_SPEED := 2.8
const WEAPONS := ["pistol", "shotgun", "rifle", "bazooka"]
const SPAWN_GRACE := 1.2

var health := MAX_HEALTH
var regeneration := preload("res://scripts/health_regeneration.gd").new()
var lives_remaining := 1
var is_alive := true
var game: Node
var bot_number := 1
var difficulty := "normal"
var current_weapon := "pistol"
var damage := DAMAGE
var flushed_toilets: Dictionary = {}
var spawn_protection_remaining := 0.0
var reaction_time := 0.0
var strafe_time := 0.0
var strafe_sign := 1.0
var toilet_check_time := 12.0
var toilet_target: Node3D
var toilet_trip_time := 0.0
var rainbow_time := 0.0
var gun: MeshInstance3D
var spawn_ring: MeshInstance3D
var target: Node3D
var retarget_time := 0.0
var fire_time := 0.7
var path_refresh := 0.0
var current_path: PackedVector3Array = []
var path_index := 0
var body_material: StandardMaterial3D
var weapon_material: StandardMaterial3D
var base_body_color := Color.WHITE
var behavior := "patrol"
var destination := Vector3.ZERO
var memory_time := 0.0
var cover_time := 0.0
var death_tween: Tween
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func setup(number: int, color: Color) -> void:
	bot_number = number
	name = "Bot_%d" % number
	base_body_color = color
	body_material = StandardMaterial3D.new()
	body_material.albedo_color = color
	body_material.roughness = 0.75
	weapon_material = StandardMaterial3D.new()
	weapon_material.albedo_color = Color("242830")
	weapon_material.metallic = 0.65
	_create_body()
	toilet_check_time = 10.0 + number * 2.0


func _create_body() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.2

	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.25
	shape.height = 1.5
	collider.shape = shape
	collider.position.y = 0.75
	add_child(collider)

	var torso := MeshInstance3D.new()
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.27
	torso_mesh.height = 1.02
	torso.mesh = torso_mesh
	torso.position.y = 0.72
	torso.material_override = body_material
	add_child(torso)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.2
	head_mesh.height = 0.4
	head.mesh = head_mesh
	head.position.y = 1.4
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color("d69a74").lerp(body_material.albedo_color, 0.12)
	head.material_override = skin
	add_child(head)

	# Oversized eyes and crooked eyebrows keep even distant roommates readable.
	var eye_white := StandardMaterial3D.new()
	eye_white.albedo_color = Color("fff8e4")
	var pupil_material := StandardMaterial3D.new()
	pupil_material.albedo_color = Color("202439")
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.066
		eye_mesh.height = 0.15
		eye.mesh = eye_mesh
		eye.position = Vector3(side * 0.086, 1.43, -0.169)
		eye.material_override = eye_white
		add_child(eye)
		var pupil := MeshInstance3D.new()
		var pupil_mesh := SphereMesh.new()
		pupil_mesh.radius = 0.03
		pupil_mesh.height = 0.07
		pupil.mesh = pupil_mesh
		pupil.position = Vector3(side * 0.086, 1.43, -0.226)
		pupil.material_override = pupil_material
		add_child(pupil)
		var eyebrow := MeshInstance3D.new()
		var eyebrow_mesh := BoxMesh.new()
		eyebrow_mesh.size = Vector3(0.105, 0.025, 0.025)
		eyebrow.mesh = eyebrow_mesh
		eyebrow.position = Vector3(side * 0.088, 1.535, -0.182)
		eyebrow.rotation.z = side * 0.22
		eyebrow.material_override = pupil_material
		add_child(eyebrow)

	gun = MeshInstance3D.new()
	var gun_mesh := BoxMesh.new()
	gun_mesh.size = Vector3(0.13, 0.13, 0.43)
	gun.mesh = gun_mesh
	gun.position = Vector3(0.23, 1.02, -0.28)
	gun.material_override = weapon_material
	add_child(gun)
	spawn_ring = MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.31
	ring_mesh.outer_radius = 0.38
	spawn_ring.mesh = ring_mesh
	spawn_ring.position.y = 0.08
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color("60f5ff")
	ring_material.emission_enabled = true
	ring_material.emission = Color("60f5ff")
	ring_material.emission_energy_multiplier = 2.0
	spawn_ring.material_override = ring_material
	spawn_ring.visible = false
	add_child(spawn_ring)


func _physics_process(delta: float) -> void:
	if not is_alive or not game or game.round_over or game.navigation_pending:
		return
	spawn_protection_remaining = maxf(0.0, spawn_protection_remaining - delta)
	spawn_ring.visible = spawn_protection_remaining > 0.0
	if spawn_ring.visible:
		spawn_ring.scale = Vector3.ONE * (1.0 + 0.14 * sin(spawn_protection_remaining * 18.0))
	if current_weapon == "rainbow_rifle":
		rainbow_time += delta
		weapon_material.albedo_color = Color.from_hsv(fmod(rainbow_time * 0.1, 1.0), 0.82, 1.0)
		weapon_material.emission = weapon_material.albedo_color
	health = regeneration.tick(delta, health, is_alive)
	if not is_on_floor():
		velocity.y -= gravity * delta
	retarget_time -= delta
	path_refresh -= delta
	fire_time -= delta
	reaction_time = maxf(0.0, reaction_time - delta)
	strafe_time -= delta
	toilet_check_time -= delta
	toilet_trip_time -= delta
	memory_time = maxf(0.0,memory_time-delta)
	cover_time = maxf(0.0,cover_time-delta)
	if retarget_time <= 0.0:
		var new_target := _find_visible_opponent()
		if new_target != target and is_instance_valid(new_target):
			reaction_time = reaction_delay()
		target = new_target
		retarget_time = 0.25
	var can_see: bool = is_instance_valid(target) and target.is_alive and _has_line_of_sight(target.global_position+Vector3.UP*1.05)
	if can_see and cover_time <= 0.0:
		toilet_target = null
		memory_time = 4.0
		destination = target.global_position
		behavior = "engage"
		if health <= 44:
			var cover: Vector3 = game.find_cover_position(global_position,target.global_position)
			if cover.distance_to(global_position) > 0.8:
				destination = cover
				cover_time = 7.0
				behavior = "cover"
				path_refresh = 0.0
	if behavior == "cover" and cover_time <= 0.0:
		behavior = "investigate"
	if behavior == "engage" and not can_see:
		behavior = "investigate"
	if not can_see and memory_time <= 0.0 and cover_time <= 0.0:
		if behavior == "toilet" and (not is_instance_valid(toilet_target) or toilet_trip_time <= 0.0):
			toilet_target = null
			behavior = "patrol"
		if not is_instance_valid(toilet_target) and toilet_check_time <= 0.0:
			_choose_toilet_objective()
		if is_instance_valid(toilet_target):
			behavior = "toilet"
			if _can_flush_toilet(toilet_target):
				toilet_target.interact(self)
				toilet_target = null
				behavior = "patrol"
				current_path.clear()
		else:
			if behavior != "patrol" or global_position.distance_to(destination) < 0.7 or current_path.is_empty():
				destination = game.choose_patrol_position(global_position)
				path_refresh = 0.0
			behavior = "patrol"
	if behavior == "engage" and can_see:
		if global_position.distance_squared_to(target.global_position) > 0.01:
			look_at(Vector3(target.global_position.x,global_position.y,target.global_position.z),Vector3.UP)
		if fire_time <= 0.0 and reaction_time <= 0.0 and spawn_protection_remaining <= 0.0:
			_shoot(target.global_position+Vector3.UP*1.05)
		_strafe(delta)
	else:
		if path_refresh <= 0.0:
			current_path = game.find_apartment_path(global_position,destination)
			path_index = 0
			path_refresh = 1.0
		_follow_path(delta)
	move_and_slide()


func _find_visible_opponent() -> Node3D:
	var nearest: Node3D
	var best := 18.0
	for candidate in game.combatants:
		if candidate == self or not is_instance_valid(candidate) or not candidate.is_alive:
			continue
		var grace: Variant = candidate.get("spawn_protection_remaining")
		if grace != null and float(grace) > 0.0:
			continue
		var offset: Vector3 = candidate.global_position-global_position
		if offset.length() >= best:
			continue
		if behavior in ["patrol", "toilet"] and (-global_basis.z).dot(offset.normalized()) < 0.15:
			continue
		var query := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*1.3,candidate.global_position+Vector3.UP*1.05,3,[self])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit and hit.collider == candidate:
			nearest = candidate
			best = offset.length()
	return nearest


func hear_gunshot(location: Vector3) -> void:
	if not is_alive or behavior in ["engage","cover"] or global_position.distance_to(location) > 14.0 or global_position.distance_to(location) < 1.5:
		return
	destination = location
	toilet_target = null
	memory_time = 5.0
	behavior = "investigate"
	path_refresh = 0.0


func _move_toward(destination: Vector3, delta: float) -> void:
	var flat := destination - global_position
	flat.y = 0.0
	if flat.length() < 0.1:
		return
	flat = flat.normalized()
	rotation.y = lerp_angle(rotation.y,atan2(-flat.x,-flat.z),minf(1.0,delta*7.0))
	velocity.x = move_toward(velocity.x, flat.x * MOVE_SPEED, delta * 12.0)
	velocity.z = move_toward(velocity.z, flat.z * MOVE_SPEED, delta * 12.0)


func _follow_path(delta: float) -> void:
	if current_path.is_empty():
		velocity.x = move_toward(velocity.x,0.0,delta*12.0)
		velocity.z = move_toward(velocity.z,0.0,delta*12.0)
		return
	while path_index < current_path.size() and global_position.distance_to(current_path[path_index]) < 0.28:
		path_index += 1
	if path_index < current_path.size():
		_move_toward(current_path[path_index], delta)
	else:
		velocity.x = move_toward(velocity.x,0.0,delta*12.0)
		velocity.z = move_toward(velocity.z,0.0,delta*12.0)


func _has_line_of_sight(aim_position: Vector3) -> bool:
	var origin := global_position + Vector3.UP * 1.3
	var query := PhysicsRayQueryParameters3D.create(origin, aim_position, 3, [self])
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return result and result.collider == target


func _shoot(aim_position: Vector3) -> void:
	if spawn_protection_remaining > 0.0:
		return
	game.emit_world_sound(current_weapon, global_position + Vector3.UP)
	fire_time = shot_interval() * randf_range(0.9, 1.2)
	var origin := global_position + Vector3.UP * 1.28
	var distance := origin.distance_to(aim_position)
	var spread := aiming_spread() * distance
	var inaccuracy := Vector3(randf_range(-spread, spread), randf_range(-spread, spread) * 0.7, randf_range(-spread, spread))
	var direction := (aim_position + inaccuracy - origin).normalized()
	if current_weapon == "bazooka":
		game.spawn_rocket(origin, direction, self, damage)
	elif current_weapon == "shotgun":
		for pellet in 8:
			var pellet_direction := (direction + global_basis.x * randf_range(-0.075, 0.075) + Vector3.UP * randf_range(-0.075, 0.075)).normalized()
			_fire_ray(origin, pellet_direction)
	else:
		_fire_ray(origin, direction)


func _fire_ray(origin: Vector3, direction: Vector3) -> void:
	var end := origin + direction * 40.0
	var query := PhysicsRayQueryParameters3D.create(origin, end, 3, [self])
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result and result.collider.has_method("apply_damage"):
		result.collider.apply_damage(damage, self)
	if result:
		game.spawn_impact(result.position, result.normal, current_weapon == "rainbow_rifle")


func reaction_delay() -> float:
	return 0.75 if difficulty == "easy" else (0.23 if difficulty == "hard" else 0.45)


func aiming_spread() -> float:
	return 0.055 if difficulty == "easy" else (0.018 if difficulty == "hard" else 0.035)


func shot_interval() -> float:
	var interval := 0.9
	match current_weapon:
		"shotgun": interval = 1.4
		"rifle", "rainbow_rifle": interval = 0.34
		"bazooka": interval = 2.0
	return interval * (1.4 if difficulty == "easy" else (0.8 if difficulty == "hard" else 1.0))


func _strafe(delta: float) -> void:
	if strafe_time <= 0.0:
		strafe_sign = -1.0 if randf() < 0.5 else 1.0
		strafe_time = randf_range(1.1, 2.2)
	var direction := global_basis.x * strafe_sign
	if not _can_strafe(direction):
		strafe_sign *= -1.0
		direction = global_basis.x * strafe_sign
		if not _can_strafe(direction):
			direction = Vector3.ZERO
	var speed := 0.65 if difficulty == "easy" else (1.3 if difficulty == "hard" else 1.0)
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * 8.0)
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * 8.0)


func _can_strafe(direction: Vector3) -> bool:
	if test_move(global_transform, direction * 0.65):
		return false
	var edge := global_position + direction * 0.65
	var query := PhysicsRayQueryParameters3D.create(edge + Vector3.UP * 0.3, edge - Vector3.UP * 0.35, 1, [self])
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _choose_toilet_objective() -> void:
	toilet_check_time = randf_range(13.0, 20.0)
	if flushed_toilets.size() >= 3:
		return
	var best_length := INF
	for toilet in game.get_toilets():
		if has_flushed_toilet(toilet.toilet_id):
			continue
		for index in 8:
			var angle := TAU * float(index) / 8.0
			var approach: Vector3 = toilet.global_position + Vector3(sin(angle), 0.0, cos(angle)) * 1.15
			approach.y = 0.05
			if not _can_stand_at(approach) or not _toilet_visible_from(toilet, approach):
				continue
			var path: PackedVector3Array = game.find_apartment_path(global_position, approach)
			if path.is_empty() or path[path.size() - 1].distance_to(approach) > 0.4:
				continue
			var length := 0.0
			var last := global_position
			for point in path:
				length += last.distance_to(point)
				last = point
			if length < best_length:
				best_length = length
				toilet_target = toilet
				destination = approach
	if is_instance_valid(toilet_target):
		behavior = "toilet"
		path_refresh = 0.0
		toilet_trip_time = 35.0


func _can_stand_at(location: Vector3) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.5
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, location + Vector3.UP * 0.75)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query).is_empty()


func _toilet_visible_from(toilet: Node3D, location: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(location + Vector3.UP * 1.15, toilet.global_position + Vector3.UP * 0.6, 5, [self])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == toilet


func _can_flush_toilet(toilet: Node3D) -> bool:
	return global_position.distance_to(toilet.global_position) <= 1.65 and _toilet_visible_from(toilet, global_position)


func has_flushed_toilet(toilet_id: int) -> bool:
	return flushed_toilets.has(toilet_id)


func register_toilet_flush(toilet_id: int) -> void:
	if not is_alive or has_flushed_toilet(toilet_id):
		return
	flushed_toilets[toilet_id] = true
	if flushed_toilets.size() >= 3:
		equip_weapon("rainbow_rifle")
	else:
		var choices := WEAPONS.duplicate()
		choices.erase(current_weapon)
		equip_weapon(choices.pick_random())
	if game:
		game.emit_world_sound("powerup" if flushed_toilets.size() >= 3 else "equip", global_position + Vector3.UP)


func equip_weapon(weapon_name: String) -> void:
	current_weapon = weapon_name if weapon_name in WEAPONS or weapon_name == "rainbow_rifle" else "pistol"
	weapon_material.emission_enabled = current_weapon == "rainbow_rifle"
	weapon_material.emission_energy_multiplier = 0.6
	var mesh := BoxMesh.new()
	match current_weapon:
		"shotgun":
			damage = 12
			mesh.size = Vector3(0.18, 0.14, 0.76)
			weapon_material.albedo_color = Color("8a5132")
		"rifle", "rainbow_rifle":
			damage = 40 if current_weapon == "rainbow_rifle" else 20
			mesh.size = Vector3(0.16, 0.22, 0.82)
			weapon_material.albedo_color = Color("ff3fcf") if current_weapon == "rainbow_rifle" else Color("314a68")
		"bazooka":
			damage = 90
			var tube := CylinderMesh.new()
			tube.top_radius = 0.15
			tube.bottom_radius = 0.15
			tube.height = 0.85
			gun.mesh = tube
			gun.rotation.x = PI * 0.5
			weapon_material.albedo_color = Color("5b7d43")
			return
		_:
			damage = DAMAGE
			mesh.size = Vector3(0.13, 0.13, 0.43)
			weapon_material.albedo_color = Color("242830")
	gun.rotation = Vector3.ZERO
	gun.mesh = mesh


func apply_damage(amount: int, _attacker: Node = null) -> void:
	if not is_alive or amount <= 0 or spawn_protection_remaining > 0.0:
		return
	regeneration.reset()
	health = maxi(health - amount, 0)
	if game:
		game.report_combat_hit(self,_attacker,health == 0)
	if _attacker is Node3D:
		toilet_target = null
		destination = _attacker.global_position
		memory_time = 5.0
		behavior = "investigate"
	body_material.albedo_color = body_material.albedo_color.lerp(Color.WHITE, 0.25)
	create_tween().tween_property(body_material,"albedo_color",base_body_color,0.2)
	if health <= 0:
		is_alive = false
		spawn_ring.visible = false
		collision_layer = 0
		collision_mask = 0
		velocity = Vector3.ZERO
		death_tween = create_tween()
		death_tween.tween_property(self,"rotation:z",deg_to_rad(82.0),0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		died.emit(self)


func respawn_at(spawn_position: Vector3, yaw: float) -> void:
	if death_tween and death_tween.is_valid():
		death_tween.kill()
	behavior = "patrol"
	current_path.clear()
	memory_time = 0.0
	cover_time = 0.0
	toilet_target = null
	toilet_check_time = randf_range(8.0, 15.0)
	spawn_protection_remaining = SPAWN_GRACE
	spawn_ring.visible = true
	reaction_time = reaction_delay()
	health = MAX_HEALTH
	regeneration.reset()
	is_alive = true
	collision_layer = 2
	collision_mask = 1
	velocity = Vector3.ZERO
	global_position = spawn_position
	rotation = Vector3(0.0, yaw, 0.0)
	body_material.albedo_color = base_body_color
	target = null
	retarget_time = 0.0
	path_refresh = 0.0
	fire_time = randf_range(0.65, 1.1)


func combatant_name() -> String:
	return "Roommate %d" % bot_number
