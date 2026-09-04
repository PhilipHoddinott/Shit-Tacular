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

var health := MAX_HEALTH
var damage := BASE_DAMAGE
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
var sitting := false
var sitting_chair: Node
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	name = "Player"
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
	weapon_root.name = "Pistol"
	weapon_root.position = Vector3(0.31, -0.28, -0.58)
	weapon_root.scale = Vector3.ONE * 0.82
	camera.add_child(weapon_root)

	weapon_material = StandardMaterial3D.new()
	weapon_material.albedo_color = Color("30343b")
	weapon_material.metallic = 0.72
	weapon_material.roughness = 0.28

	var slide := MeshInstance3D.new()
	var slide_mesh := BoxMesh.new()
	slide_mesh.size = Vector3(0.16, 0.15, 0.48)
	slide.mesh = slide_mesh
	slide.position = Vector3(0.0, 0.02, -0.12)
	slide.material_override = weapon_material
	weapon_root.add_child(slide)

	var grip := MeshInstance3D.new()
	var grip_mesh := BoxMesh.new()
	grip_mesh.size = Vector3(0.14, 0.32, 0.15)
	grip.mesh = grip_mesh
	grip.position = Vector3(0.0, -0.19, 0.01)
	grip.rotation.x = -0.16
	grip.material_override = weapon_material
	weapon_root.add_child(grip)

	var barrel := MeshInstance3D.new()
	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius = 0.045
	barrel_mesh.bottom_radius = 0.045
	barrel_mesh.height = 0.31
	barrel.mesh = barrel_mesh
	barrel.position = Vector3(0.0, 0.035, -0.47)
	barrel.rotation.x = PI * 0.5
	barrel.material_override = weapon_material
	weapon_root.add_child(barrel)

	muzzle_flash = OmniLight3D.new()
	muzzle_flash.light_color = Color("ffc36a")
	muzzle_flash.light_energy = 0.0
	muzzle_flash.omni_range = 2.2
	muzzle_flash.position = Vector3(0.0, 0.03, -0.68)
	weapon_root.add_child(muzzle_flash)


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


func _fire() -> void:
	if fire_cooldown > 0.0:
		return
	fire_cooldown = 0.28
	recoil = 0.11
	muzzle_flash.light_energy = 3.0
	var origin := camera.global_position
	var end := origin + -camera.global_basis.z * FIRE_DISTANCE
	var query := PhysicsRayQueryParameters3D.create(origin, end, 3, [self])
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result:
		var collider: Object = result.collider
		if collider.has_method("apply_damage"):
			collider.apply_damage(damage, self)
		if game and game.has_method("spawn_impact"):
			game.spawn_impact(result.position, result.normal, damage > BASE_DAMAGE)


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
	toilet_progress.emit(flushed_toilets.size(), 3)
	if flushed_toilets.size() == 3:
		damage = BASE_DAMAGE * 3
		weapon_material.albedo_color = Color("ff2bd6")
		weapon_material.emission_enabled = true
		weapon_material.emission = Color("a000ff")
		weapon_material.emission_energy_multiplier = 2.2
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
		velocity = Vector3.ZERO
		neck.rotation.z = deg_to_rad(72.0)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		died.emit(self)


func combatant_name() -> String:
	return "You"
