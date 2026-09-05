class_name ApartmentBot
extends CharacterBody3D

signal died(combatant: Node)

const MAX_HEALTH := 100
const DAMAGE := 24
const MOVE_SPEED := 2.8

var health := MAX_HEALTH
var regeneration := preload("res://scripts/health_regeneration.gd").new()
var lives_remaining := 1
var is_alive := true
var game: Node
var bot_number := 1
var target: Node3D
var retarget_time := 0.0
var fire_time := 0.7
var path_refresh := 0.0
var current_path: PackedVector3Array = []
var path_index := 0
var body_material: StandardMaterial3D
var weapon_material: StandardMaterial3D
var base_body_color := Color.WHITE
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

	var gun := MeshInstance3D.new()
	var gun_mesh := BoxMesh.new()
	gun_mesh.size = Vector3(0.13, 0.13, 0.43)
	gun.mesh = gun_mesh
	gun.position = Vector3(0.23, 1.02, -0.28)
	gun.material_override = weapon_material
	add_child(gun)


func _physics_process(delta: float) -> void:
	if not is_alive or not game:
		return
	if not game.round_over:
		health = regeneration.tick(delta, health, is_alive)
	if not is_on_floor():
		velocity.y -= gravity * delta

	retarget_time -= delta
	path_refresh -= delta
	fire_time -= delta
	if retarget_time <= 0.0 or not is_instance_valid(target) or not target.get("is_alive"):
		target = game.get_closest_opponent(self)
		retarget_time = 0.55
	if not target:
		velocity.x = move_toward(velocity.x, 0.0, delta * 12.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 12.0)
		move_and_slide()
		return

	var aim_position := target.global_position + Vector3.UP * 1.05
	var can_see := _has_line_of_sight(aim_position)
	var flat_distance := Vector2(global_position.x - target.global_position.x, global_position.z - target.global_position.z).length()
	if can_see:
		look_at(Vector3(target.global_position.x, global_position.y, target.global_position.z), Vector3.UP)
		if flat_distance > 4.5:
			_move_toward(target.global_position, delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, delta * 15.0)
			velocity.z = move_toward(velocity.z, 0.0, delta * 15.0)
		if fire_time <= 0.0 and flat_distance < 16.0:
			_shoot(aim_position)
	else:
		if path_refresh <= 0.0:
			current_path = game.find_apartment_path(global_position, target.global_position)
			path_index = 0
			path_refresh = 0.75
		_follow_path(delta)
	move_and_slide()


func _move_toward(destination: Vector3, delta: float) -> void:
	var flat := destination - global_position
	flat.y = 0.0
	if flat.length() < 0.1:
		return
	flat = flat.normalized()
	velocity.x = move_toward(velocity.x, flat.x * MOVE_SPEED, delta * 12.0)
	velocity.z = move_toward(velocity.z, flat.z * MOVE_SPEED, delta * 12.0)


func _follow_path(delta: float) -> void:
	if current_path.is_empty():
		_move_toward(target.global_position, delta)
		return
	while path_index < current_path.size() and global_position.distance_to(current_path[path_index]) < 0.65:
		path_index += 1
	if path_index < current_path.size():
		_move_toward(current_path[path_index], delta)


func _has_line_of_sight(aim_position: Vector3) -> bool:
	var origin := global_position + Vector3.UP * 1.3
	var query := PhysicsRayQueryParameters3D.create(origin, aim_position, 3, [self])
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return result and result.collider == target


func _shoot(aim_position: Vector3) -> void:
	game.emit_world_sound("pistol", global_position + Vector3.UP)
	fire_time = randf_range(0.72, 1.2)
	var origin := global_position + Vector3.UP * 1.28
	var inaccuracy := Vector3(randf_range(-0.16, 0.16), randf_range(-0.12, 0.12), randf_range(-0.16, 0.16))
	var end := aim_position + inaccuracy
	var query := PhysicsRayQueryParameters3D.create(origin, end, 3, [self])
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result and result.collider.has_method("apply_damage"):
		result.collider.apply_damage(DAMAGE, self)
	if result:
		game.spawn_impact(result.position, result.normal, false)


func apply_damage(amount: int, _attacker: Node = null) -> void:
	if not is_alive or amount <= 0:
		return
	regeneration.reset()
	health = maxi(health - amount, 0)
	body_material.albedo_color = body_material.albedo_color.lerp(Color.WHITE, 0.25)
	if health <= 0:
		is_alive = false
		collision_layer = 0
		collision_mask = 0
		velocity = Vector3.ZERO
		rotation.z = deg_to_rad(82.0)
		died.emit(self)


func respawn_at(spawn_position: Vector3, yaw: float) -> void:
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
