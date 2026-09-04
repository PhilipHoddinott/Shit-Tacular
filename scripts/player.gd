class_name FpsPlayer
extends CharacterBody3D

signal health_changed(current: int, maximum: int)
signal toilet_progress(current: int, total: int)
signal powerup_activated
signal died(combatant: Node)

const WALK_SPEED := 4.6
const SPRINT_SPEED := 6.6
const JUMP_VELOCITY := 4.8
const MOUSE_SENSITIVITY := 0.0021
const BASE_DAMAGE := 24
const MAX_HEALTH := 100
const INTERACT_DISTANCE := 2.4
const FIRE_DISTANCE := 40.0
const STANDING_CAMERA_HEIGHT := 1.34
const SITTING_CAMERA_HEIGHT := 0.94
const WEAPON_PISTOL := "pistol"
const WEAPON_SHOTGUN := "shotgun"
const WEAPON_RIFLE := "rifle"
const WEAPON_BAZOOKA := "bazooka"
const WEAPON_RAINBOW_RIFLE := "rainbow_rifle"

var health := MAX_HEALTH
var damage := BASE_DAMAGE
var current_weapon := WEAPON_PISTOL
var lives_remaining := 1
var is_alive := true
var input_enabled := true
var flushed_toilets: Dictionary = {}
var game: Node
var camera: Camera3D
var neck: Node3D
var weapon_root: Node3D
var weapon_material: StandardMaterial3D
var muzzle_flash: OmniLight3D
var fire_cooldown := 0.0
var recoil := 0.0
var rainbow_time := 0.0
var sitting := false
var sitting_chair: Node
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.25

	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.5
	collider.shape = capsule
	collider.position.y = 0.75
	add_child(collider)

	neck = Node3D.new()
	neck.name = "Neck"
	neck.position.y = STANDING_CAMERA_HEIGHT
	add_child(neck)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.current = true
	camera.fov = 78.0
	neck.add_child(camera)

	_create_weapon()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _create_weapon() -> void:
	weapon_root = Node3D.new()
	camera.add_child(weapon_root)

	weapon_material = StandardMaterial3D.new()
	_equip_weapon(WEAPON_PISTOL)


func equip_weapon(weapon_name: String) -> void:
	_equip_weapon(weapon_name)


func _equip_weapon(weapon_name: String) -> void:
	if weapon_name not in [WEAPON_PISTOL, WEAPON_SHOTGUN, WEAPON_RIFLE, WEAPON_BAZOOKA, WEAPON_RAINBOW_RIFLE]:
		weapon_name = WEAPON_PISTOL
	current_weapon = weapon_name
	weapon_material.emission_enabled = false
	weapon_material.metallic = 0.58
	weapon_material.roughness = 0.34
	match current_weapon:
		WEAPON_SHOTGUN:
			damage = 12
			weapon_material.albedo_color = Color("8a5132")
		WEAPON_RIFLE:
			damage = 20
			weapon_material.albedo_color = Color("314a68")
		WEAPON_BAZOOKA:
			damage = 90
			weapon_material.albedo_color = Color("5b7d43")
		WEAPON_RAINBOW_RIFLE:
			damage = 40
			weapon_material.albedo_color = Color("ff3fcf")
			weapon_material.emission_enabled = true
			weapon_material.emission = Color("ff3fcf")
			weapon_material.emission_energy_multiplier = 1.45
		_:
			damage = BASE_DAMAGE
			weapon_material.albedo_color = Color("30343b")
	_rebuild_weapon_visual()


func weapon_display_name() -> String:
	match current_weapon:
		WEAPON_SHOTGUN:
			return "SHOTGUN"
		WEAPON_RIFLE:
			return "RIFLE"
		WEAPON_BAZOOKA:
			return "BAZOOKA"
		WEAPON_RAINBOW_RIFLE:
			return "RAINBOW RIFLE"
		_:
			return "PISTOL"


func weapon_damage_text() -> String:
	return "%d x 8" % damage if current_weapon == WEAPON_SHOTGUN else str(damage)


func _rebuild_weapon_visual() -> void:
	for child in weapon_root.get_children():
		child.visible = false
		child.queue_free()
	weapon_root.name = weapon_display_name().to_pascal_case()
	var accent := StandardMaterial3D.new()
	accent.albedo_color = Color("242832")
	accent.metallic = 0.68
	accent.roughness = 0.3
	var muzzle_z := -0.68

	match current_weapon:
		WEAPON_SHOTGUN:
			weapon_root.position = Vector3(0.34, -0.25, -0.7)
			weapon_root.scale = Vector3.ONE * 0.86
			_add_weapon_box(Vector3(0.0, -0.02, -0.18), Vector3(0.21, 0.18, 0.52), accent)
			_add_weapon_box(Vector3(0.0, -0.08, 0.16), Vector3(0.18, 0.24, 0.32), weapon_material, Vector3(-0.18, 0.0, 0.0))
			_add_weapon_cylinder(Vector3(0.0, 0.02, -0.68), 0.064, 0.76, accent)
			_add_weapon_box(Vector3(0.0, -0.12, -0.55), Vector3(0.24, 0.16, 0.32), weapon_material)
			muzzle_z = -1.08
		WEAPON_RIFLE, WEAPON_RAINBOW_RIFLE:
			weapon_root.position = Vector3(0.34, -0.25, -0.72)
			weapon_root.scale = Vector3.ONE * 0.84
			_add_weapon_box(Vector3(0.0, -0.01, -0.22), Vector3(0.2, 0.2, 0.56), weapon_material)
			_add_weapon_box(Vector3(0.0, -0.08, 0.18), Vector3(0.17, 0.23, 0.34), accent, Vector3(-0.16, 0.0, 0.0))
			_add_weapon_box(Vector3(0.0, -0.2, -0.24), Vector3(0.14, 0.28, 0.19), accent, Vector3(0.18, 0.0, 0.0))
			_add_weapon_cylinder(Vector3(0.0, 0.01, -0.73), 0.038, 0.64, accent)
			_add_weapon_cylinder(Vector3(0.0, 0.15, -0.2), 0.045, 0.32, accent, Vector3(0.0, 0.0, PI * 0.5))
			muzzle_z = -1.08
		WEAPON_BAZOOKA:
			weapon_root.position = Vector3(0.3, -0.27, -0.64)
			weapon_root.scale = Vector3.ONE * 0.9
			_add_weapon_cylinder(Vector3(0.0, 0.0, -0.45), 0.12, 1.08, weapon_material)
			_add_weapon_cylinder(Vector3(0.0, 0.0, -0.96), 0.16, 0.1, accent)
			_add_weapon_cylinder(Vector3(0.0, 0.0, 0.05), 0.15, 0.12, accent)
			_add_weapon_box(Vector3(0.0, -0.2, -0.35), Vector3(0.14, 0.32, 0.16), accent, Vector3(0.16, 0.0, 0.0))
			muzzle_z = -1.08
		_:
			weapon_root.position = Vector3(0.31, -0.28, -0.58)
			weapon_root.scale = Vector3.ONE * 0.82
			_add_weapon_box(Vector3(0.0, 0.02, -0.12), Vector3(0.16, 0.15, 0.48), weapon_material)
			_add_weapon_box(Vector3(0.0, -0.19, 0.01), Vector3(0.14, 0.32, 0.15), weapon_material, Vector3(-0.16, 0.0, 0.0))
			_add_weapon_cylinder(Vector3(0.0, 0.035, -0.47), 0.045, 0.31, accent)

	muzzle_flash = OmniLight3D.new()
	muzzle_flash.light_color = Color("ffc36a")
	muzzle_flash.light_energy = 0.0
	muzzle_flash.omni_range = 2.6 if current_weapon == WEAPON_BAZOOKA else 2.2
	muzzle_flash.position = Vector3(0.0, 0.03, muzzle_z)
	weapon_root.add_child(muzzle_flash)


func _add_weapon_box(position: Vector3, size: Vector3, material: StandardMaterial3D, rotation: Vector3 = Vector3.ZERO) -> void:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = position
	part.rotation = rotation
	part.material_override = material
	weapon_root.add_child(part)


func _add_weapon_cylinder(position: Vector3, radius: float, length: float, material: StandardMaterial3D, rotation: Vector3 = Vector3(PI * 0.5, 0.0, 0.0)) -> void:
	var part := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	part.mesh = mesh
	part.position = position
	part.rotation = rotation
	part.material_override = material
	weapon_root.add_child(part)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and input_enabled:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		neck.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		neck.rotation.x = clampf(neck.rotation.x, deg_to_rad(-88.0), deg_to_rad(88.0))
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	fire_cooldown = maxf(fire_cooldown - delta, 0.0)
	muzzle_flash.light_energy = move_toward(muzzle_flash.light_energy, 0.0, delta * 30.0)
	recoil = move_toward(recoil, 0.0, delta * 5.5)
	weapon_root.rotation.x = recoil
	_animate_weapon(delta)
	if sitting:
		velocity = Vector3.ZERO
		if input_enabled and Input.is_action_just_pressed("interact"):
			stand_up()
		if input_enabled and Input.is_action_pressed("fire") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_fire()
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	if input_enabled and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_vector := Vector2.ZERO
	if input_enabled:
		input_vector = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
	var target_speed := SPRINT_SPEED if Input.is_key_pressed(KEY_SHIFT) else WALK_SPEED
	if direction:
		velocity.x = move_toward(velocity.x, direction.x * target_speed, delta * 25.0)
		velocity.z = move_toward(velocity.z, direction.z * target_speed, delta * 25.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, delta * 22.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 22.0)
	move_and_slide()

	if input_enabled and Input.is_action_pressed("fire") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_fire()
	if input_enabled and Input.is_action_just_pressed("interact"):
		_interact()


func _animate_weapon(delta: float) -> void:
	if current_weapon == WEAPON_RAINBOW_RIFLE:
		rainbow_time = fmod(rainbow_time + delta * 0.12, 1.0)
		var rainbow_color := Color.from_hsv(rainbow_time, 0.78, 1.0)
		weapon_material.albedo_color = rainbow_color
		weapon_material.emission = rainbow_color


func _fire() -> void:
	if fire_cooldown > 0.0:
		return
	match current_weapon:
		WEAPON_SHOTGUN:
			fire_cooldown = 0.82
			recoil = 0.2
		WEAPON_RIFLE, WEAPON_RAINBOW_RIFLE:
			fire_cooldown = 0.12
			recoil = 0.075
		WEAPON_BAZOOKA:
			fire_cooldown = 1.25
			recoil = 0.26
		_:
			fire_cooldown = 0.28
			recoil = 0.11
	muzzle_flash.light_energy = 5.5 if current_weapon == WEAPON_BAZOOKA else 3.0
	var origin := camera.global_position
	var forward := -camera.global_basis.z
	if current_weapon == WEAPON_BAZOOKA:
		_fire_bazooka(origin, forward)
		return
	var pellet_count := 8 if current_weapon == WEAPON_SHOTGUN else 1
	var spread := 0.075 if current_weapon == WEAPON_SHOTGUN else (0.012 if current_weapon == WEAPON_PISTOL else 0.006)
	for _pellet in pellet_count:
		var direction := (forward + camera.global_basis.x * randf_range(-spread, spread) + camera.global_basis.y * randf_range(-spread, spread)).normalized()
		_fire_hitscan(origin, direction)


func _fire_hitscan(origin: Vector3, direction: Vector3) -> void:
	var end := origin + direction * FIRE_DISTANCE
	var query := PhysicsRayQueryParameters3D.create(origin, end, 3, [self])
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result:
		var collider: Object = result.collider
		if collider.has_method("apply_damage"):
			collider.apply_damage(damage, self)
		if game and game.has_method("spawn_impact"):
			game.spawn_impact(result.position, result.normal, current_weapon == WEAPON_RAINBOW_RIFLE)


func _fire_bazooka(origin: Vector3, direction: Vector3) -> void:
	var end := origin + direction * FIRE_DISTANCE
	var query := PhysicsRayQueryParameters3D.create(origin, end, 3, [self])
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	var impact_position: Vector3 = result.position if result else end
	if game and game.has_method("spawn_explosion"):
		game.spawn_explosion(impact_position, self, 2.6, damage)


func _interact() -> void:
	var origin := camera.global_position
	var end := origin + -camera.global_basis.z * INTERACT_DISTANCE
	var query := PhysicsRayQueryParameters3D.create(origin, end, 4, [self])
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result and result.collider.has_method("interact"):
		result.collider.interact(self)


func get_interaction_prompt() -> String:
	if not camera or not is_alive:
		return ""
	if sitting:
		return "Press E to stand"
	var origin := camera.global_position
	var end := origin + -camera.global_basis.z * INTERACT_DISTANCE
	var query := PhysicsRayQueryParameters3D.create(origin, end, 4, [self])
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result and result.collider.has_method("interaction_text"):
		return result.collider.interaction_text(self)
	return ""


func register_toilet_flush(toilet_id: int) -> void:
	if flushed_toilets.has(toilet_id):
		return
	flushed_toilets[toilet_id] = true
	if flushed_toilets.size() == 3:
		_equip_weapon(WEAPON_RAINBOW_RIFLE)
	else:
		var choices := [WEAPON_PISTOL, WEAPON_SHOTGUN, WEAPON_RIFLE, WEAPON_BAZOOKA]
		choices.erase(current_weapon)
		_equip_weapon(choices.pick_random())
	toilet_progress.emit(flushed_toilets.size(), 3)
	if flushed_toilets.size() == 3:
		powerup_activated.emit()


func has_flushed_toilet(toilet_id: int) -> bool:
	return flushed_toilets.has(toilet_id)


func sit_on(chair: Node) -> void:
	if sitting or not is_alive:
		return
	sitting = true
	sitting_chair = chair
	chair.occupant = self
	velocity = Vector3.ZERO
	collision_mask = 0
	global_position = chair.get_sit_position()
	rotation.y = chair.global_rotation.y
	neck.position.y = SITTING_CAMERA_HEIGHT


func stand_up() -> void:
	if not sitting or not is_instance_valid(sitting_chair):
		return
	var chair := sitting_chair
	sitting = false
	sitting_chair = null
	global_position = chair.get_stand_position()
	neck.position.y = STANDING_CAMERA_HEIGHT
	collision_mask = 1
	chair.release(self)


func apply_damage(amount: int, _attacker: Node = null) -> void:
	if not is_alive:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, MAX_HEALTH)
	if health <= 0:
		if sitting and is_instance_valid(sitting_chair):
			sitting_chair.release(self)
		sitting = false
		sitting_chair = null
		is_alive = false
		input_enabled = false
		collision_layer = 0
		collision_mask = 0
		velocity = Vector3.ZERO
		neck.rotation.z = deg_to_rad(72.0)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		died.emit(self)


func respawn_at(spawn_position: Vector3, yaw: float) -> void:
	if sitting and is_instance_valid(sitting_chair):
		sitting_chair.release(self)
	sitting = false
	sitting_chair = null
	health = MAX_HEALTH
	is_alive = true
	input_enabled = true
	collision_layer = 2
	collision_mask = 1
	velocity = Vector3.ZERO
	global_position = spawn_position
	rotation = Vector3(0.0, yaw, 0.0)
	neck.rotation = Vector3.ZERO
	neck.position.y = STANDING_CAMERA_HEIGHT
	camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	health_changed.emit(health, MAX_HEALTH)


func combatant_name() -> String:
	return "You"
