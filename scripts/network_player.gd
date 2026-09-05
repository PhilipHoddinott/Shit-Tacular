class_name NetworkFpsPlayer
extends FpsPlayer

var peer_id := 1
var display_name := "Player"
var network_game: Node
var is_local_player := false

var server_move_input := Vector2.ZERO
var server_sprinting := false
var server_firing := false
var server_input_age := 0.0
var queued_jump := false

var target_position := Vector3.ZERO
var target_yaw := 0.0
var target_pitch := 0.0
var has_network_state := false
var avatar_root: Node3D


func setup_network(id: int, player_name: String, game_node: Node, spawn_position: Vector3) -> void:
	peer_id = id
	display_name = player_name
	network_game = game_node
	name = "NetPlayer_%d" % peer_id
	position = spawn_position
	target_position = spawn_position


func _ready() -> void:
	super()
	is_local_player = multiplayer.get_unique_id() == peer_id
	camera.current = is_local_player
	weapon_root.visible = is_local_player
	_create_network_avatar()
	avatar_root.visible = not is_local_player
	if not is_local_player:
		input_enabled = false
	if is_local_player:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _create_network_avatar() -> void:
	avatar_root = Node3D.new()
	avatar_root.name = "Avatar"
	add_child(avatar_root)

	var palette := [Color("ff625f"), Color("54a2ff"), Color("f5c451"), Color("62d391"), Color("ba77f5"), Color("ff8fc8"), Color("56d6d2"), Color("f28b47")]
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = palette[absi(peer_id) % palette.size()]
	body_material.roughness = 0.72

	var torso := MeshInstance3D.new()
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.27
	torso_mesh.height = 1.02
	torso.mesh = torso_mesh
	torso.position.y = 0.72
	torso.material_override = body_material
	avatar_root.add_child(torso)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.2
	head_mesh.height = 0.4
	head.mesh = head_mesh
	head.position.y = 1.4
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color("dca17b")
	head.material_override = skin
	avatar_root.add_child(head)

	var gun := MeshInstance3D.new()
	var gun_mesh := BoxMesh.new()
	gun_mesh.size = Vector3(0.13, 0.13, 0.43)
	gun.mesh = gun_mesh
	gun.position = Vector3(0.23, 1.02, -0.28)
	gun.material_override = weapon_material
	avatar_root.add_child(gun)

	var name_tag := Label3D.new()
	name_tag.text = display_name
	name_tag.font_size = 38
	name_tag.pixel_size = 0.005
	name_tag.outline_size = 8
	name_tag.position.y = 1.82
	name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	avatar_root.add_child(name_tag)


func _unhandled_input(event: InputEvent) -> void:
	if is_local_player:
		super(event)


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		if is_local_player:
			super(delta)
		else:
			_server_simulate(delta)
		return

	_animate_weapon(delta)
	_client_tick(delta)


func _server_simulate(delta: float) -> void:
	if not is_alive:
		return
	_tick_regeneration(delta)
	server_input_age += delta
	if server_input_age > 0.25:
		server_move_input = Vector2.ZERO
		server_sprinting = false
		server_firing = false
	fire_cooldown = maxf(fire_cooldown - delta, 0.0)
	muzzle_flash.light_energy = move_toward(muzzle_flash.light_energy, 0.0, delta * 30.0)
	recoil = move_toward(recoil, 0.0, delta * 5.5)
	weapon_root.rotation.x = recoil

	if sitting:
		velocity = Vector3.ZERO
		if server_firing:
			_fire()
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	if queued_jump and is_on_floor():
		velocity.y = JUMP_VELOCITY
	queued_jump = false

	var direction := (transform.basis * Vector3(server_move_input.x, 0.0, server_move_input.y)).normalized()
	var target_speed := SPRINT_SPEED if server_sprinting else WALK_SPEED
	if direction:
		velocity.x = move_toward(velocity.x, direction.x * target_speed, delta * 25.0)
		velocity.z = move_toward(velocity.z, direction.z * target_speed, delta * 25.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, delta * 22.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 22.0)
	move_and_slide()
	if server_firing:
		_fire()


func _client_tick(delta: float) -> void:
	if is_local_player and is_alive and input_enabled:
		var move_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		network_game.send_local_network_input(
			move_input,
			Input.is_key_pressed(KEY_SHIFT),
			Input.is_action_pressed("fire"),
			rotation.y,
			neck.rotation.x
		)
		if Input.is_action_just_pressed("jump"):
			network_game.send_local_network_action("jump")
		if Input.is_action_just_pressed("interact"):
			network_game.send_local_network_action("interact")

	if has_network_state:
		global_position = global_position.lerp(target_position, minf(delta * 14.0, 1.0))
		if not is_local_player:
			rotation.y = lerp_angle(rotation.y, target_yaw, minf(delta * 16.0, 1.0))
			neck.rotation.x = lerp_angle(neck.rotation.x, target_pitch, minf(delta * 16.0, 1.0))


func set_server_input(move_input: Vector2, sprinting: bool, firing: bool, yaw: float, pitch: float) -> void:
	server_move_input = move_input.limit_length(1.0)
	server_sprinting = sprinting
	server_firing = firing
	server_input_age = 0.0
	rotation.y = wrapf(yaw, -PI, PI)
	neck.rotation.x = clampf(pitch, deg_to_rad(-88.0), deg_to_rad(88.0))


func queue_network_action(action: String) -> void:
	if action == "jump":
		queued_jump = true
	elif action == "interact" and is_alive:
		_interact()


func apply_network_state(state: Dictionary) -> void:
	target_position = state.get("position", global_position)
	target_yaw = float(state.get("yaw", rotation.y))
	target_pitch = float(state.get("pitch", neck.rotation.x))
	has_network_state = true

	var next_health := int(state.get("health", health))
	var next_lives := int(state.get("lives", lives_remaining))
	var next_alive := bool(state.get("alive", is_alive))
	var next_damage := int(state.get("damage", damage))
	var next_weapon := str(state.get("weapon", current_weapon))
	var toilet_ids: Array = state.get("toilets", [])
	if next_health != health:
		health = next_health
		if is_local_player:
			health_changed.emit(health, MAX_HEALTH)
	if next_lives != lives_remaining:
		lives_remaining = next_lives
		if is_local_player and network_game.has_method("update_local_lives"):
			network_game.update_local_lives(lives_remaining)
	if next_weapon != current_weapon:
		equip_weapon(next_weapon)
	if next_damage != damage:
		damage = next_damage
	if toilet_ids.size() != flushed_toilets.size():
		flushed_toilets.clear()
		for toilet_id in toilet_ids:
			flushed_toilets[int(toilet_id)] = true
		if is_local_player and network_game.has_method("update_local_toilets"):
			network_game.update_local_toilets(flushed_toilets.size(), next_damage, next_weapon)
	if next_alive != is_alive:
		is_alive = next_alive
		collision_layer = 2 if is_alive else 0
		collision_mask = 1 if is_alive else 0
		if is_local_player:
			input_enabled = is_alive
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if is_alive else Input.MOUSE_MODE_VISIBLE
		avatar_root.rotation.z = 0.0 if is_alive else deg_to_rad(82.0)


func apply_damage(amount: int, _attacker: Node = null) -> void:
	if not multiplayer.is_server() or not is_alive or amount <= 0:
		return
	regeneration.reset()
	health = maxi(health - amount, 0)
	if game:
		game.report_combat_hit(self,_attacker,health == 0)
	if is_local_player:
		health_changed.emit(health, MAX_HEALTH)
	if health > 0:
		return
	if sitting and is_instance_valid(sitting_chair):
		sitting_chair.release(self)
	sitting = false
	sitting_chair = null
	is_alive = false
	input_enabled = false
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	if is_local_player:
		neck.rotation.z = deg_to_rad(72.0)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		avatar_root.rotation.z = deg_to_rad(82.0)
	died.emit(self)


func respawn_at(spawn_position: Vector3, yaw: float) -> void:
	if sitting and is_instance_valid(sitting_chair):
		sitting_chair.release(self)
	sitting = false
	sitting_chair = null
	health = MAX_HEALTH
	regeneration.reset()
	is_alive = true
	input_enabled = is_local_player
	collision_layer = 2
	collision_mask = 1
	velocity = Vector3.ZERO
	global_position = spawn_position
	rotation = Vector3(0.0, yaw, 0.0)
	neck.rotation = Vector3.ZERO
	neck.position.y = STANDING_CAMERA_HEIGHT
	avatar_root.rotation = Vector3.ZERO
	camera.current = is_local_player
	if is_local_player:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		health_changed.emit(health, MAX_HEALTH)


func combatant_name() -> String:
	return display_name
