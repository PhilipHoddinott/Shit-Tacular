extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const NetworkPlayerScript = preload("res://scripts/network_player.gd")
const BotScript = preload("res://scripts/bot.gd")
const ToiletScript = preload("res://scripts/toilet.gd")
const ChairScript = preload("res://scripts/chair.gd")

const APARTMENT_SCALE := 2.0
const PLAN_SCALE := 0.02 * APARTMENT_SCALE
const PLAN_ORIGIN := Vector2(248.0, 14.0)
const WALL_HEIGHT := 2.72
const WALL_THICKNESS := 0.13
const DEFAULT_NETWORK_PORT := 7000
const MIN_NETWORK_PLAYERS := 2
const MAX_NETWORK_PLAYERS := 8

var rng := RandomNumberGenerator.new()
var player: FpsPlayer
var combatants: Array[Node] = []
var spawn_positions: Array[Vector3] = []
var nav_graph := AStar3D.new()
var ui_health: Label
var ui_toilets: Label
var ui_lives: Label
var ui_prompt: Label
var ui_banner: Label
var ui_status: Label
var replay_button: Button
var lives_selector: OptionButton
var hud_root: Control
var menu_root: Control
var multiplayer_menu_root: Control
var player_name_edit: LineEdit
var player_count_selector: OptionButton
var host_port_edit: LineEdit
var join_ip_edit: LineEdit
var join_port_edit: LineEdit
var network_status: Label
var lobby_roster: Label
var host_start_button: Button
var copy_address_button: Button
var copy_public_address_button: Button
var upnp_checkbox: CheckBox
var crash_logs_button: Button
var banner_time := 0.0
var round_over := false
var selected_lives := 1
var selected_player_count := 4
var network_port := DEFAULT_NETWORK_PORT
var is_network_host := false
var network_match_started := false
var network_state_time := 0.0
var lobby_players: Dictionary = {}
var network_players: Dictionary = {}
var upnp_thread: Thread
var active_upnp: UPNP
var upnp_mapping_active := false
var upnp_public_address := ""
var upnp_status_message := ""
var upnp_mapped_port := 0
var wall_material: StandardMaterial3D
var floor_material: StandardMaterial3D
var wood_material: StandardMaterial3D
var white_material: StandardMaterial3D
var dark_material: StandardMaterial3D
var primary_wall_material: StandardMaterial3D
var living_wall_material: StandardMaterial3D
var hall_wall_material: StandardMaterial3D
var kitchen_wall_material: StandardMaterial3D
var bedroom_wall_material: StandardMaterial3D
var bathroom_wall_material: StandardMaterial3D
var foyer_wall_material: StandardMaterial3D


func _ready() -> void:
	rng.randomize()
	multiplayer.peer_connected.connect(_on_network_peer_connected)
	multiplayer.peer_disconnected.connect(_on_network_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_network_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_setup_materials()
	_setup_world()
	_build_apartment()
	_build_windows_and_entry()
	_build_furniture()
	_build_toilets()
	_build_navigation_graph()
	_create_ui()
	Diagnostics.log_event("game_scene_ready", {"qa_mode": not OS.get_cmdline_user_args().is_empty()})
	if "--qa-capture" in OS.get_cmdline_user_args():
		_start_round()
		_capture_qa_frame.call_deferred()
	elif "--qa-smoke" in OS.get_cmdline_user_args():
		selected_lives = 2
		_start_round()
		_run_qa_smoke.call_deferred()
	elif "--qa-menu-capture" in OS.get_cmdline_user_args():
		_capture_menu_qa_frame.call_deferred()
	elif "--qa-floorplan-capture" in OS.get_cmdline_user_args():
		_capture_floorplan_qa_frame.call_deferred()
	elif "--qa-roundover-capture" in OS.get_cmdline_user_args():
		_start_round()
		_capture_roundover_qa_frame.call_deferred()
	elif "--qa-entry-capture" in OS.get_cmdline_user_args():
		_start_round()
		_capture_entry_qa_frame.call_deferred()
	elif "--qa-bathroom-capture" in OS.get_cmdline_user_args():
		_start_round()
		_capture_bathroom_qa_frame.call_deferred()
	elif "--qa-weapons-capture" in OS.get_cmdline_user_args():
		_start_round()
		_capture_weapons_qa_frames.call_deferred()
	elif "--qa-multiplayer-menu-capture" in OS.get_cmdline_user_args():
		_capture_multiplayer_menu_qa_frame.call_deferred()
	elif "--qa-host-lobby-capture" in OS.get_cmdline_user_args():
		_capture_host_lobby_qa_frame.call_deferred()
	elif "--qa-network-host" in OS.get_cmdline_user_args():
		_start_qa_network_host.call_deferred()
	elif "--qa-network-client" in OS.get_cmdline_user_args():
		_start_qa_network_client.call_deferred()
	else:
		_show_main_menu()


func _process(delta: float) -> void:
	_poll_upnp_setup()
	if player and is_instance_valid(player):
		ui_prompt.text = player.get_interaction_prompt()
	if banner_time > 0.0:
		banner_time -= delta
		ui_banner.modulate.a = minf(1.0, banner_time * 1.8)
	else:
		ui_banner.text = ""
	if round_over and Input.is_action_just_pressed("restart"):
		if network_match_started and is_network_host:
			_start_network_match()
		elif not network_match_started:
			_start_round()


func _exit_tree() -> void:
	_close_upnp_mapping()


func _physics_process(delta: float) -> void:
	if not network_match_started or not multiplayer.is_server():
		return
	network_state_time -= delta
	if network_state_time <= 0.0:
		network_state_time = 0.05
		_broadcast_network_state()


func _capture_qa_frame() -> void:
	# Optional automated visual check: `godot --path . -- --qa-capture`.
	# It never runs during normal play and its output is ignored by Git.
	player.input_enabled = false
	player.position = _expanded(Vector3(6.8, 0.05, 5.55))
	player.rotation.y = 0.0
	player.register_toilet_flush(1)
	player.register_toilet_flush(2)
	player.register_toilet_flush(3)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path("res://artifacts/qa_first_person.png"))
	print("QA_CAPTURE:", error)
	get_tree().quit()


func _capture_menu_qa_frame() -> void:
	_show_main_menu()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path("res://artifacts/qa_main_menu.png"))
	print("QA_MENU_CAPTURE:", error)
	get_tree().quit()


func _capture_floorplan_qa_frame() -> void:
	menu_root.visible = false
	hud_root.visible = false
	var ceiling := get_node_or_null("Ceiling") as Node3D
	if ceiling:
		ceiling.visible = false
	var audit_camera := Camera3D.new()
	audit_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	audit_camera.size = 12.7 * APARTMENT_SCALE
	audit_camera.position = _expanded(Vector3(4.95, 14.0, 5.65))
	audit_camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	audit_camera.current = true
	add_child(audit_camera)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path("res://artifacts/qa_floorplan_alignment.png"))
	print("QA_FLOORPLAN_CAPTURE:", error)
	get_tree().quit()


func _capture_roundover_qa_frame() -> void:
	player.input_enabled = false
	player.position = _expanded(Vector3(6.8, 0.05, 5.55))
	player.rotation.y = 0.0
	for index in range(1, combatants.size()):
		combatants[index].apply_damage(999, player)
	await get_tree().create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path("res://artifacts/qa_round_over.png"))
	print("QA_ROUNDOVER_CAPTURE:", error)
	get_tree().quit()


func _capture_entry_qa_frame() -> void:
	player.input_enabled = false
	player.position = _expanded(Vector3(7.95, 0.05, 6.35))
	player.rotation.y = deg_to_rad(-150.0)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path("res://artifacts/qa_fake_entry.png"))
	print("QA_ENTRY_CAPTURE:", error)
	get_tree().quit()


func _capture_bathroom_qa_frame() -> void:
	player.input_enabled = false
	player.position = _expanded(Vector3(3.85, 0.05, 3.72))
	player.rotation.y = 0.0
	ui_banner.text = ""
	banner_time = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path("res://artifacts/qa_bathroom_mirror.png"))
	print("QA_BATHROOM_CAPTURE:", error)
	get_tree().quit()


func _capture_weapons_qa_frames() -> void:
	player.input_enabled = false
	player.position = _expanded(Vector3(6.8, 0.05, 5.55))
	player.rotation.y = 0.0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	for weapon_name in [FpsPlayer.WEAPON_PISTOL, FpsPlayer.WEAPON_SHOTGUN, FpsPlayer.WEAPON_RIFLE, FpsPlayer.WEAPON_BAZOOKA, FpsPlayer.WEAPON_RAINBOW_RIFLE]:
		player.equip_weapon(weapon_name)
		ui_toilets.text = "%s    DAMAGE  %s" % [player.weapon_display_name(), player.weapon_damage_text()]
		ui_banner.text = player.weapon_display_name()
		banner_time = 10.0
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var file_name := "res://artifacts/qa_weapon_%s.png" % weapon_name
		var error := image.save_png(ProjectSettings.globalize_path(file_name))
		print("QA_WEAPON_CAPTURE %s: %s" % [weapon_name, error])
	get_tree().quit()


func _capture_multiplayer_menu_qa_frame() -> void:
	_show_multiplayer_menu()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path("res://artifacts/qa_multiplayer_menu.png"))
	print("QA_MULTIPLAYER_MENU_CAPTURE:", error)
	get_tree().quit()


func _capture_host_lobby_qa_frame() -> void:
	_show_multiplayer_menu()
	upnp_checkbox.button_pressed = false
	selected_player_count = 2
	player_count_selector.select(0)
	_host_lobby()
	upnp_mapping_active = true
	upnp_public_address = "203.0.113.42"
	upnp_status_message = "Internet address ready."
	copy_public_address_button.visible = true
	_refresh_host_network_status()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path("res://artifacts/qa_host_lobby.png"))
	print("QA_HOST_LOBBY_CAPTURE:", error)
	get_tree().quit()


func _start_qa_network_host() -> void:
	player_name_edit.text = "QA Host"
	selected_player_count = 2
	player_count_selector.select(0)
	host_port_edit.text = "7019"
	upnp_checkbox.button_pressed = false
	_host_lobby()


func _start_qa_network_client() -> void:
	player_name_edit.text = "QA Client"
	join_ip_edit.text = "127.0.0.1:7019"
	join_port_edit.text = str(DEFAULT_NETWORK_PORT)
	_join_lobby()


func _finish_qa_network_test() -> void:
	assert(network_match_started, "Network match must start on every peer")
	assert(network_players.size() == 2, "Network match must contain two human players")
	assert(player != null, "Each peer must own a local first-person player")
	var starting_position := player.global_position
	if multiplayer.is_server():
		await get_tree().create_timer(0.4).timeout
		for id in network_players:
			if int(id) != 1:
				var client_player := network_players[id] as NetworkFpsPlayer
				client_player.register_toilet_flush(1)
				client_player.register_toilet_flush(2)
				client_player.register_toilet_flush(3)
				client_player.apply_damage(24, player)
		await get_tree().create_timer(0.5).timeout
	else:
		Input.action_press("move_right")
		await get_tree().create_timer(0.35).timeout
		Input.action_release("move_right")
		await get_tree().create_timer(0.55).timeout
		assert(player.global_position.distance_to(starting_position) > 0.05, "Client input must move its server-authoritative player")
		assert(player.health == 76, "Server damage must synchronize to the client")
		assert(player.current_weapon == FpsPlayer.WEAPON_RAINBOW_RIFLE and player.damage == 40 and player.flushed_toilets.size() == 3, "The toilet weapon reward must synchronize to the client")
	print("QA_NETWORK_OK peer=%d players=%d host=%s" % [multiplayer.get_unique_id(), network_players.size(), multiplayer.is_server()])
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()


func _run_qa_smoke() -> void:
	await get_tree().physics_frame
	for combatant in combatants:
		combatant.set_physics_process(false)
	player.input_enabled = false
	_assert_hallway_clearance()
	assert(APARTMENT_SCALE == 2.0 and _network_spawn_positions()[7].x > 17.0, "Apartment geometry and spawns must use the doubled footprint")
	assert(player.health == 100, "Player must spawn with 100 health")
	assert(player.damage == 24, "Pistol must start at 24 damage")
	for weapon_test in [
		[FpsPlayer.WEAPON_SHOTGUN, 12, "12 x 8"],
		[FpsPlayer.WEAPON_RIFLE, 20, "20"],
		[FpsPlayer.WEAPON_BAZOOKA, 90, "90"],
		[FpsPlayer.WEAPON_PISTOL, 24, "24"]
	]:
		player.equip_weapon(weapon_test[0])
		assert(player.current_weapon == weapon_test[0] and player.damage == weapon_test[1] and player.weapon_damage_text() == weapon_test[2], "Every standard weapon must equip with its own damage profile")
	var blast_target := combatants[1] as ApartmentBot
	spawn_explosion(blast_target.global_position, player, 2.6, 90)
	assert(blast_target.health == 10, "A direct bazooka blast must deal 90 damage")
	blast_target.health = 100
	assert(selected_lives == 2 and lives_selector.item_count == 4, "The menu must offer the configured lives choices")
	assert(lives_selector.get_item_metadata(0) == 1 and lives_selector.get_item_metadata(3) == 5, "Lives choices must range from one to five")
	assert(upnp_checkbox.button_pressed, "Automatic UDP port mapping must be enabled by default")
	assert(_upnp_error_message(UPNP.UPNP_RESULT_NO_GATEWAY) == "no compatible router was found", "UPnP failures must have a useful fallback message")
	assert(player.lives_remaining == 2, "The player must receive the menu's selected lives")
	assert(get_tree().get_nodes_in_group("sittable_chairs").size() == 4, "All four dining chairs must be sittable")
	var test_chair := get_tree().get_first_node_in_group("sittable_chairs") as SittableChair
	assert(test_chair != null, "At least one chair must be sittable")
	player.sit_on(test_chair)
	assert(player.sitting and test_chair.occupant == player, "Player must be able to sit")
	player.stand_up()
	assert(not player.sitting and test_chair.occupant == null, "Player must be able to stand")
	player.register_toilet_flush(1)
	var first_random_weapon := player.current_weapon
	assert(first_random_weapon in [FpsPlayer.WEAPON_SHOTGUN, FpsPlayer.WEAPON_RIFLE, FpsPlayer.WEAPON_BAZOOKA], "The first flush must award a new random weapon")
	player.register_toilet_flush(1)
	assert(player.flushed_toilets.size() == 1, "The same toilet cannot count twice")
	assert(player.current_weapon == first_random_weapon, "The same toilet cannot reroll the weapon twice")
	player.register_toilet_flush(2)
	player.register_toilet_flush(3)
	assert(player.current_weapon == FpsPlayer.WEAPON_RAINBOW_RIFLE and player.damage == 40, "Three toilets must grant the 40-damage rainbow rifle")
	assert(player.weapon_material.emission_enabled, "The rainbow rifle must use its animated glowing material")
	var rainbow_before := player.weapon_material.albedo_color
	player._animate_weapon(0.5)
	assert(player.weapon_material.albedo_color != rainbow_before, "The rainbow rifle must slowly cycle its color")
	assert(ui_banner.text == "TRIPLE-SHIT!", "Power-up banner must use the requested wording")
	player.apply_damage(999)
	assert(not player.is_alive and player.lives_remaining == 1, "A defeated player must spend one life")
	await get_tree().create_timer(1.2).timeout
	assert(player.is_alive and player.health == 100, "A player with lives remaining must respawn at full health")
	assert(player.current_weapon == FpsPlayer.WEAPON_RAINBOW_RIFLE and player.damage == 40 and player.flushed_toilets.size() == 3, "The rainbow rifle must survive a respawn")
	var test_bot := combatants[1] as ApartmentBot
	test_bot.apply_damage(40, player)
	test_bot.apply_damage(40, player)
	assert(test_bot.health == 20 and test_bot.is_alive, "Two rainbow-rifle bullets must leave 20 of 100 health")
	test_bot.apply_damage(40, player)
	assert(not test_bot.is_alive and test_bot.lives_remaining == 1, "A third rainbow-rifle bullet must spend one bot life")
	await get_tree().create_timer(1.2).timeout
	assert(test_bot.is_alive and test_bot.health == 100, "A bot with lives remaining must respawn at full health")
	for index in range(1, combatants.size()):
		var bot := combatants[index] as ApartmentBot
		if bot.is_alive:
			bot.apply_damage(999, player)
		if bot.lives_remaining > 0:
			await get_tree().create_timer(1.2).timeout
			assert(bot.is_alive and bot.health == 100, "Every bot must respawn while it has another life")
			bot.apply_damage(999, player)
	await get_tree().create_timer(0.25).timeout
	assert(round_over and replay_button.visible, "Round end must offer a replay button")
	replay_button.pressed.emit()
	await get_tree().process_frame
	assert(not round_over and not replay_button.visible and combatants.size() == 4, "Replay button must start a fresh round")
	for combatant in combatants:
		assert(combatant.lives_remaining == 2, "Replay must preserve the selected lives setting")
	print("QA_SMOKE_OK apartment_scale=2 weapons=4 rainbow_rifle_damage=40 toilets=3 chairs=sittable lives=respawn replay=visible")
	get_tree().quit()


func _assert_hallway_clearance() -> void:
	var player_shape := CapsuleShape3D.new()
	player_shape.radius = 0.25
	player_shape.height = 1.5
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = player_shape
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var doorway_centers := {
		"primary bedroom": _plan(Vector2(419, 232.5)),
		"upper bathroom": _plan(Vector2(464, 260)),
		"center bedroom": _plan(Vector2(411.5, 319)),
		"private bathroom hall": _plan(Vector2(312.5, 382)),
		"bottom bathroom": _plan(Vector2(412.5, 489)),
		"living room from hall": _plan(Vector2(507, 289.5)),
		"open kitchen": _plan(Vector2(580, 319))
	}
	for doorway_name: String in doorway_centers:
		query.transform = Transform3D(Basis.IDENTITY, doorway_centers[doorway_name] + Vector3.UP * 0.78)
		var collisions := get_world_3d().direct_space_state.intersect_shape(query, 8)
		var collider_names: Array[String] = []
		for collision in collisions:
			collider_names.append(str(collision.collider.get_path()))
		assert(collisions.is_empty(), "%s doorway must fit the player capsule; hit %s" % [doorway_name, ", ".join(collider_names)])
	print("QA_HALLWAYS_OK doorways=7 capsule_width=0.50m")


func _setup_materials() -> void:
	wall_material = _material(Color("e8e0d5"), 0.86)
	primary_wall_material = _material(Color("82b7e8"), 0.9)
	living_wall_material = _material(Color("f29b7f"), 0.9)
	hall_wall_material = _material(Color("a8d59b"), 0.9)
	kitchen_wall_material = _material(Color("f2cf66"), 0.9)
	bedroom_wall_material = _material(Color("c49ce2"), 0.9)
	bathroom_wall_material = _material(Color("76d4c7"), 0.86)
	foyer_wall_material = _material(Color("ef9fc8"), 0.9)
	floor_material = _material(Color("8a6849"), 0.72)
	wood_material = _material(Color("70452f"), 0.77)
	white_material = _material(Color("eeeef0"), 0.64)
	dark_material = _material(Color("252832"), 0.48)


func _setup_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("15131c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d8d4ef")
	env.ambient_light_energy = 0.38
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62.0, -28.0, 0.0)
	sun.light_color = Color("fff2d4")
	sun.light_energy = 0.52
	sun.shadow_enabled = true
	add_child(sun)

	for light_data in [
		[Vector3(2.0, 2.45, 2.9), Color("ffd8a6")],
		[Vector3(7.3, 2.45, 3.8), Color("fff0d2")],
		[Vector3(4.1, 2.45, 5.6), Color("f2e3ff")],
		[Vector3(3.0, 2.45, 8.2), Color("ffe9cf")],
		[Vector3(6.6, 2.45, 7.4), Color("ffe8c2")]
	]:
		var light := OmniLight3D.new()
		light.position = _expanded(light_data[0])
		light.light_color = light_data[1]
		light.light_energy = 0.62
		light.omni_range = 7.2
		light.shadow_enabled = true
		add_child(light)


func _build_apartment() -> void:
	_create_box("Floor", _expanded(Vector3(4.95, -0.08, 5.65)), _expanded_size(Vector3(10.15, 0.16, 11.55)), floor_material, true)
	_create_floorplan_overlay()
	_create_box("Ceiling", _expanded(Vector3(4.95, WALL_HEIGHT + 0.06, 5.65)), _expanded_size(Vector3(10.15, 0.12, 11.55)), _material(Color("d5d1d8"), 0.95), false)

	var outer_segments := [
		[Vector2(248, 90), Vector2(273, 90)], [Vector2(273, 90), Vector2(273, 67)],
		[Vector2(273, 67), Vector2(302, 14)], [Vector2(302, 14), Vector2(369, 14)],
		[Vector2(369, 14), Vector2(399, 68)], [Vector2(399, 68), Vector2(399, 90)],
		[Vector2(399, 90), Vector2(419, 90)], [Vector2(419, 90), Vector2(419, 77)],
		[Vector2(419, 77), Vector2(530, 77)], [Vector2(530, 77), Vector2(554, 26)],
		[Vector2(554, 26), Vector2(625, 26)], [Vector2(625, 26), Vector2(651, 90)],
		[Vector2(651, 90), Vector2(743, 90)], [Vector2(743, 90), Vector2(743, 449)],
		[Vector2(743, 449), Vector2(490, 449)], [Vector2(490, 449), Vector2(490, 579)],
		[Vector2(490, 579), Vector2(248, 579)], [Vector2(248, 579), Vector2(248, 322)],
		[Vector2(248, 322), Vector2(272, 322)], [Vector2(272, 322), Vector2(272, 258)],
		[Vector2(272, 258), Vector2(248, 258)], [Vector2(248, 258), Vector2(248, 90)]
	]
	for segment in outer_segments:
		_create_wall(_plan(segment[0]), _plan(segment[1]), WALL_THICKNESS, WALL_HEIGHT, 0.0, _wall_material_for_segment(segment[0], segment[1]))

	var interior_segments := [
		# Primary bedroom / upper bathroom / hall.
		[Vector2(419, 90), Vector2(419, 214)], [Vector2(419, 251), Vector2(419, 260)],
		[Vector2(419, 137), Vector2(507, 137)], [Vector2(507, 137), Vector2(507, 260)],
		[Vector2(419, 260), Vector2(443, 260)], [Vector2(485, 260), Vector2(507, 260)],
		# Hall boundary and entrance to living room.
		[Vector2(331, 260), Vector2(419, 260)],
		[Vector2(331, 319), Vector2(390, 319)], [Vector2(433, 319), Vector2(507, 319)],
		# Left bathroom and center bedroom.
		[Vector2(331, 319), Vector2(331, 579)],
		[Vector2(248, 382), Vector2(294, 382)],
		[Vector2(490, 319), Vector2(490, 449)],
		# Center bedroom / bottom bathroom.
		[Vector2(331, 489), Vector2(389, 489)], [Vector2(436, 489), Vector2(490, 489)],
		# Kitchen is fully open to the living room; the foyer-side wall is solid.
		[Vector2(507, 449), Vector2(645, 449)], [Vector2(645, 337), Vector2(645, 449)]
	]
	for segment in interior_segments:
		_create_wall(_plan(segment[0]), _plan(segment[1]), WALL_THICKNESS, WALL_HEIGHT, 0.0, _wall_material_for_segment(segment[0], segment[1]))

	# Door headers make openings read as doors while remaining walkable.
	for door in [
		[Vector2(419, 214), Vector2(419, 251)], [Vector2(443, 260), Vector2(485, 260)],
		[Vector2(390, 319), Vector2(433, 319)], [Vector2(294, 382), Vector2(331, 382)],
		[Vector2(389, 489), Vector2(436, 489)]
	]:
		_create_wall(_plan(door[0]), _plan(door[1]), 0.13, 0.55, 2.17, wood_material)


func _create_floorplan_overlay() -> void:
	var texture := load("res://assets/floorplan_floor.png") as Texture2D
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = 0.94
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(10.38, 11.78) * APARTMENT_SCALE
	var overlay := MeshInstance3D.new()
	overlay.name = "FloorplanOverlay"
	overlay.mesh = plane_mesh
	overlay.material_override = material
	overlay.position = _expanded(Vector3(4.95, 0.012, 5.65))
	add_child(overlay)


func _wall_material_for_segment(a: Vector2, b: Vector2) -> StandardMaterial3D:
	var midpoint := (a + b) * 0.5
	if midpoint.x < 419.0 and midpoint.y < 260.0:
		return primary_wall_material
	if midpoint.x < 331.0 and midpoint.y >= 382.0:
		return bathroom_wall_material
	if midpoint.x < 490.0 and midpoint.y >= 489.0:
		return bathroom_wall_material
	if midpoint.x < 490.0 and midpoint.y >= 319.0:
		return bedroom_wall_material
	if midpoint.x >= 507.0 and midpoint.y >= 319.0 and midpoint.x < 645.0:
		return kitchen_wall_material
	if midpoint.x >= 645.0 and midpoint.y >= 319.0:
		return foyer_wall_material
	if midpoint.x >= 507.0 or midpoint.y < 137.0:
		return living_wall_material
	if midpoint.x >= 419.0 and midpoint.y < 260.0:
		return bathroom_wall_material
	return hall_wall_material


func _build_windows_and_entry() -> void:
	_create_window(_expanded(Vector3(1.72, 1.48, 0.08)), 0.0, 1.0, Vector3(0.0, 0.0, 1.0))
	_create_window(_expanded(Vector3(6.75, 1.48, 0.32)), 0.0, 0.92, Vector3(0.0, 0.0, 1.0))
	_create_window(_expanded(Vector3(9.05, 1.48, 1.45)), 0.0, 0.72, Vector3(0.0, 0.0, 1.0))
	_create_fake_foyer_door()


func _create_window(position: Vector3, rotation_y: float, width: float, inward: Vector3) -> void:
	var window := Node3D.new()
	window.name = "CartoonWindow"
	window.position = position
	window.rotation.y = rotation_y
	add_child(window)

	var glass := _material(Color("82d9ff"), 0.15, true)
	_create_child_box(window, Vector3.ZERO, Vector3(width, 0.92, 0.045), glass, false)
	_create_child_box(window, Vector3(0.0, 0.49, 0.0), Vector3(width + 0.14, 0.08, 0.085), white_material, false)
	_create_child_box(window, Vector3(0.0, -0.49, 0.0), Vector3(width + 0.14, 0.08, 0.085), white_material, false)
	_create_child_box(window, Vector3(-width * 0.5, 0.0, 0.0), Vector3(0.08, 1.02, 0.085), white_material, false)
	_create_child_box(window, Vector3(width * 0.5, 0.0, 0.0), Vector3(0.08, 1.02, 0.085), white_material, false)
	_create_child_box(window, Vector3(0.0, 0.0, -0.01), Vector3(0.055, 0.94, 0.065), white_material, false)

	var spot := SpotLight3D.new()
	spot.name = "FakeWindowLight"
	spot.position = position + inward * 0.08 + Vector3.UP * 0.48
	spot.light_color = Color("ffd77b")
	spot.light_energy = 2.25
	spot.spot_range = 8.5
	spot.spot_angle = 38.0
	spot.shadow_enabled = false
	add_child(spot)
	spot.look_at(position + inward * 3.0 + Vector3.DOWN * 1.45, Vector3.UP)

	var beam_material := StandardMaterial3D.new()
	beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.albedo_color = Color(1.0, 0.76, 0.26, 0.16)
	var beam := _create_box("Sunbeam", position + inward * 1.45 * APARTMENT_SCALE + Vector3(0.0, -1.445, 0.0), Vector3(width * 0.9, 0.018, 2.9 * APARTMENT_SCALE), beam_material, false)
	beam.rotation.y = rotation_y


func _create_fake_foyer_door() -> void:
	var door := Node3D.new()
	door.name = "FakeOutsideDoor"
	door.position = _expanded(Vector3(9.18, 0.0, 8.61))
	add_child(door)
	var door_material := _material(Color("8b67d3"), 0.72)
	_create_child_box(door, Vector3(0.0, 1.08, 0.0), Vector3(1.08, 2.16, 0.09), door_material, false)
	_create_child_box(door, Vector3(0.0, 2.2, -0.01), Vector3(1.22, 0.11, 0.14), dark_material, false)
	_create_child_box(door, Vector3(-0.59, 1.08, -0.01), Vector3(0.11, 2.27, 0.14), dark_material, false)
	_create_child_box(door, Vector3(0.59, 1.08, -0.01), Vector3(0.11, 2.27, 0.14), dark_material, false)
	for panel_y in [0.64, 1.48]:
		_create_child_box(door, Vector3(0.0, panel_y, -0.055), Vector3(0.72, 0.52, 0.035), _material(Color("a986eb"), 0.76), false)

	var knob := MeshInstance3D.new()
	var knob_mesh := SphereMesh.new()
	knob_mesh.radius = 0.075
	knob_mesh.height = 0.15
	knob.mesh = knob_mesh
	knob.position = Vector3(0.39, 1.05, -0.095)
	knob.material_override = _material(Color("ffd34f"), 0.25, true)
	door.add_child(knob)

	var sign := Label3D.new()
	sign.text = "OUTSIDE\n(SOON™)"
	sign.font_size = 48
	sign.pixel_size = 0.0032
	sign.outline_size = 12
	sign.modulate = Color("fff176")
	sign.position = Vector3(0.0, 1.82, -0.105)
	sign.rotation.y = PI
	door.add_child(sign)


func _build_furniture() -> void:
	# Primary bedroom.
	_create_bed(Vector3(1.65, 0.0, 2.45), 0.0, Color("4d6b93"))
	_create_box("Dresser", _expanded(Vector3(0.45, 0.45, 3.95)), Vector3(0.55, 0.9, 1.45), wood_material, true)

	# Center bedroom.
	_create_bed(Vector3(3.15, 0.0, 7.85), PI * 0.5, Color("8c586e"))
	_create_box("Nightstand", _expanded(Vector3(3.8, 0.36, 7.55)), Vector3(0.55, 0.72, 0.55), wood_material, true)

	# Living room sofa, coffee table, and television.
	_create_sofa(Vector3(8.2, 0.0, 3.65), PI * 0.5, Color("43a88d"))
	var coffee_table := _create_box("CoffeeTable", _expanded(Vector3(6.85, 0.31, 3.65)), Vector3(1.35, 0.12, 0.72), wood_material, true)
	coffee_table.rotation.y = PI * 0.5
	_create_tv(Vector3(5.28, 1.48, 3.65), PI)

	# Dining area.
	_create_box("DiningTable", _expanded(Vector3(6.75, 0.77, 1.35)), Vector3(1.7, 0.12, 0.9), wood_material, true)
	for chair_data in [
		[Vector3(6.175, 0.0, 1.35), -PI * 0.5, Color("f07892")],
		[Vector3(7.325, 0.0, 1.35), PI * 0.5, Color("62b8e8")],
		[Vector3(6.75, 0.0, 0.9), PI, Color("f1c75b")],
		[Vector3(6.75, 0.0, 1.8), 0.0, Color("9d79dc")]
	]:
		_create_chair(chair_data[0], chair_data[1], chair_data[2])

	# Kitchen counters and island.
	_create_box("KitchenCounter", _expanded(Vector3(6.34, 0.48, 7.97)), Vector3(2.15, 0.96, 0.58), white_material, true)
	_create_box("KitchenCounter", _expanded(Vector3(5.872, 0.48, 7.55)), Vector3(0.55, 0.96, 1.25), white_material, true)
	_create_box("KitchenIsland", _expanded(Vector3(6.4, 0.48, 7.01)), Vector3(1.55, 0.96, 0.68), _material(Color("d8d1c2"), 0.45), true)
	_create_box("CartoonFridge", _expanded(Vector3(7.09, 0.95, 7.55)), Vector3(0.62, 1.9, 0.72), _material(Color("8ed8ef"), 0.38), true)

	# Bathroom sinks and tubs to make all three rooms recognizable.
	_create_box("Vanity", _expanded(Vector3(3.85, 0.46, 2.76)), Vector3(0.72, 0.92, 0.42), white_material, true)
	_create_box("Vanity", _expanded(Vector3(0.55, 0.46, 8.25)), Vector3(0.65, 0.92, 1.15), white_material, true)
	_create_box("Tub", _expanded(Vector3(2.35, 0.35, 10.45)), Vector3(1.2, 0.7, 0.68), white_material, true)
	_create_box("Vanity", _expanded(Vector3(3.35, 0.46, 11.03)), Vector3(0.7, 0.92, 0.36), white_material, true)

	# Small, route-safe cartoon decor.
	_create_rug(Vector3(7.25, 0.0, 3.65), Vector2(3.25, 2.8), Color("e86bb7"))
	_create_rug(Vector3(1.75, 0.0, 2.65), Vector2(1.55, 2.2), Color("65bfe8"))
	_create_box("LivingSideTable", _expanded(Vector3(8.375, 0.34, 4.4)), Vector3(0.56, 0.68, 0.56), _material(Color("ef9d55"), 0.72), true)
	_create_floor_lamp(Vector3(8.66, 0.0, 4.495), Color("ffd55f"))
	_create_plant(Vector3(8.78, 0.0, 1.92), Color("44bd73"))
	_create_plant(Vector3(2.55, 0.0, 0.75), Color("62c96b"))
	_create_wall_art(Vector3(9.79, 1.55, 5.55), PI * 0.5, Color("58cde0"), Color("ff6b9b"))
	_create_wall_art(Vector3(0.08, 1.5, 2.8), -PI * 0.5, Color("ffd45c"), Color("795ad9"))
	_create_wall_mirror(Vector3(3.85, 1.52, 2.52), 0.0, Vector2(0.72, 0.78))


func _build_toilets() -> void:
	_create_toilet(1, Vector3(4.58, 0.0, 4.25), PI)
	_create_toilet(2, Vector3(0.72, 0.0, 9.52), -PI * 0.5)
	_create_toilet(3, Vector3(4.32, 0.0, 10.42), PI * 0.5)


func _create_toilet(id: int, position: Vector3, rotation_y: float) -> void:
	var toilet := ToiletScript.new() as FlushableToilet
	toilet.setup(id, white_material)
	toilet.position = _expanded(position)
	toilet.rotation.y = rotation_y
	add_child(toilet)


func _start_round() -> void:
	Diagnostics.log_event("single_player_round_started", {"lives": selected_lives, "bots": 3})
	for old_combatant in combatants:
		if is_instance_valid(old_combatant):
			old_combatant.queue_free()
	combatants.clear()
	player = null
	round_over = false
	ui_status.visible = false
	replay_button.visible = false
	hud_root.visible = true
	menu_root.visible = false

	spawn_positions = _network_spawn_positions()
	var available_spawns := spawn_positions.duplicate()
	available_spawns.shuffle()

	player = PlayerScript.new() as FpsPlayer
	player.name = "Player"
	player.game = self
	player.lives_remaining = selected_lives
	player.position = available_spawns.pop_back()
	player.health_changed.connect(_on_player_health_changed)
	player.toilet_progress.connect(_on_toilet_progress)
	player.powerup_activated.connect(_on_powerup_activated)
	player.died.connect(_on_combatant_died)
	add_child(player)
	combatants.append(player)

	var colors := [Color("e05a4f"), Color("4f83dc"), Color("d4a83f")]
	for index in 3:
		var bot := BotScript.new() as ApartmentBot
		bot.setup(index + 1, colors[index])
		bot.game = self
		bot.lives_remaining = selected_lives
		bot.position = available_spawns.pop_back()
		bot.died.connect(_on_combatant_died)
		add_child(bot)
		combatants.append(bot)

	ui_health.text = "HEALTH  100"
	ui_toilets.text = "TOILETS  0 / 3    PISTOL  24"
	ui_lives.text = "LIVES  %d" % selected_lives
	ui_toilets.modulate = Color.WHITE
	_show_banner("LAST ONE STANDING", 2.4)


func get_closest_opponent(requester: Node3D) -> Node3D:
	var closest: Node3D
	var closest_distance := INF
	for combatant in combatants:
		if combatant == requester or not is_instance_valid(combatant) or not combatant.get("is_alive"):
			continue
		var distance := requester.global_position.distance_squared_to(combatant.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest = combatant
	return closest


func _on_combatant_died(combatant: Node) -> void:
	combatant.lives_remaining = maxi(combatant.lives_remaining - 1, 0)
	Diagnostics.log_event("combatant_died", {
		"name": combatant.combatant_name(),
		"lives_remaining": combatant.lives_remaining,
		"networked": network_match_started
	})
	if combatant == player:
		ui_lives.text = "LIVES  %d" % combatant.lives_remaining

	var contenders := _get_remaining_contenders()
	if contenders.size() <= 1:
		await get_tree().create_timer(0.15).timeout
		_finish_round(contenders)
		return

	if combatant.lives_remaining > 0:
		if combatant == player:
			_show_banner("OOPS!\nRESPAWNING...", 1.1)
		await get_tree().create_timer(1.1).timeout
		if not round_over and is_instance_valid(combatant):
			combatant.respawn_at(_choose_respawn_position(combatant), rng.randf_range(-PI, PI))
			Diagnostics.log_event("combatant_respawned", {"name": combatant.combatant_name(), "lives_remaining": combatant.lives_remaining, "networked": network_match_started})
			if combatant == player:
				ui_lives.text = "LIVES  %d" % combatant.lives_remaining
	else:
		if combatant == player:
			_show_banner("OUT OF LIVES!", 1.5)


func _get_remaining_contenders() -> Array[Node]:
	var contenders: Array[Node] = []
	for combatant in combatants:
		if is_instance_valid(combatant) and combatant.lives_remaining > 0:
			contenders.append(combatant)
	return contenders


func _choose_respawn_position(respawning: Node3D) -> Vector3:
	var candidates := spawn_positions.duplicate()
	candidates.shuffle()
	for candidate: Vector3 in candidates:
		var clear := true
		for combatant in combatants:
			if combatant == respawning or not is_instance_valid(combatant) or not combatant.is_alive:
				continue
			if candidate.distance_squared_to(combatant.global_position) < 9.0:
				clear = false
				break
		if clear:
			return candidate
	return candidates[0]


func _finish_round(contenders: Array[Node]) -> void:
	if round_over:
		return
	round_over = true
	var winner := "Nobody"
	if contenders.size() == 1:
		winner = contenders[0].combatant_name()
	Diagnostics.log_event("round_finished", {"winner": winner, "networked": network_match_started})
	ui_status.text = "%s WINS!" % winner.to_upper()
	ui_status.visible = true
	replay_button.visible = not network_match_started or is_network_host
	_show_banner("ROUND OVER", 3.5)
	if player:
		player.input_enabled = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if network_match_started and multiplayer.is_server():
		_network_round_finished.rpc(winner)


@rpc("authority", "call_remote", "reliable")
func _network_round_finished(winner: String) -> void:
	round_over = true
	ui_status.text = "%s WINS!" % winner.to_upper()
	ui_status.visible = true
	replay_button.visible = false
	_show_banner("ROUND OVER", 3.5)
	if player:
		player.input_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_player_health_changed(current: int, _maximum: int) -> void:
	ui_health.text = "HEALTH  %d" % current
	ui_health.modulate = Color("ff6565") if current <= 30 else Color.WHITE


func _on_toilet_progress(current: int, total: int) -> void:
	var weapon_name := player.weapon_display_name() if player else "PISTOL"
	var damage_text := player.weapon_damage_text() if player else "24"
	ui_toilets.text = "TOILETS  %d / %d    %s  %s" % [current, total, weapon_name, damage_text]
	_show_banner("TOILET FLUSHED  %d / %d\n%s!" % [current, total, weapon_name], 1.4)


func _on_powerup_activated() -> void:
	Diagnostics.log_event("triple_shit_activated", {"player": player.combatant_name() if player else "unknown", "networked": network_match_started})
	ui_toilets.modulate = Color("ff53e4")
	_show_banner("TRIPLE-SHIT!", 1.0)
	ui_banner.scale = Vector2(0.35, 0.35)
	ui_banner.rotation = -0.08
	var pop := create_tween()
	pop.set_trans(Tween.TRANS_BACK)
	pop.set_ease(Tween.EASE_OUT)
	pop.tween_property(ui_banner, "scale", Vector2(1.18, 1.18), 0.18)
	pop.tween_property(ui_banner, "scale", Vector2.ONE, 0.12)
	pop.parallel().tween_property(ui_banner, "rotation", 0.04, 0.22)


func _create_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)

	hud_root = Control.new()
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(hud_root)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade_material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){ vec2 p=UV*2.0-1.0; float v=1.0-smoothstep(0.45,1.35,length(p)); COLOR=vec4(0.05,0.0,0.08,(1.0-v)*0.42); }"
	shade_material.shader = shader
	shade.material = shade_material
	hud_root.add_child(shade)

	ui_health = _ui_label(24, Vector2(28, 22), 22)
	hud_root.add_child(ui_health)
	ui_toilets = _ui_label(24, Vector2(28, 54), 18)
	hud_root.add_child(ui_toilets)
	ui_lives = _ui_label(24, Vector2(28, 82), 18)
	hud_root.add_child(ui_lives)

	var controls := _ui_label(24, Vector2(28, 650), 15)
	controls.text = "WASD MOVE    SHIFT SPRINT    SPACE JUMP    LMB FIRE    E USE / STAND    ESC MOUSE"
	controls.modulate = Color(1, 1, 1, 0.62)
	hud_root.add_child(controls)

	ui_prompt = _ui_label(540, Vector2(370, 570), 22)
	ui_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_prompt.add_theme_color_override("font_color", Color("fff0a8"))
	hud_root.add_child(ui_prompt)

	ui_banner = _ui_label(700, Vector2(290, 88), 42)
	ui_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_banner.add_theme_color_override("font_color", Color("ff47dd"))
	ui_banner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	ui_banner.add_theme_constant_override("shadow_offset_x", 3)
	ui_banner.add_theme_constant_override("shadow_offset_y", 3)
	hud_root.add_child(ui_banner)

	ui_status = _ui_label(700, Vector2(290, 270), 38)
	ui_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_status.visible = false
	hud_root.add_child(ui_status)

	replay_button = _menu_button("PLAY AGAIN")
	replay_button.position = Vector2(500, 390)
	replay_button.size = Vector2(280, 64)
	replay_button.visible = false
	replay_button.pressed.connect(_start_round)
	hud_root.add_child(replay_button)

	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.add_theme_font_size_override("font_size", 24)
	crosshair.add_theme_color_override("font_color", Color(1, 1, 1, 0.82))
	crosshair.position = Vector2(633, 343)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(crosshair)

	_create_main_menu(canvas)
	_create_multiplayer_menu(canvas)
	hud_root.visible = false


func _create_main_menu(canvas: CanvasLayer) -> void:
	menu_root = Control.new()
	menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(menu_root)

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("17121f")
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_root.add_child(background)

	var glow := ColorRect.new()
	glow.position = Vector2(0, 0)
	glow.size = Vector2(1280, 720)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow_material := ShaderMaterial.new()
	var glow_shader := Shader.new()
	glow_shader.code = "shader_type canvas_item; void fragment(){ vec2 p=UV-vec2(0.5); float a=max(0.0,1.0-length(p)*1.65); COLOR=vec4(0.55,0.03,0.5,a*a*0.34); }"
	glow_material.shader = glow_shader
	glow.material = glow_material
	menu_root.add_child(glow)

	var panel := PanelContainer.new()
	panel.position = Vector2(365, 70)
	panel.size = Vector2(550, 580)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.045, 0.035, 0.065, 0.96)
	panel_style.border_color = Color("c52cae")
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 14
	panel_style.corner_radius_top_right = 14
	panel_style.corner_radius_bottom_left = 14
	panel_style.corner_radius_bottom_right = 14
	panel.add_theme_stylebox_override("panel", panel_style)
	menu_root.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 52
	content.offset_top = 38
	content.offset_right = -52
	content.offset_bottom = -34
	panel.add_child(content)

	var title := Label.new()
	title.text = "SHIT-TACULAR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color("ff45dc"))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "THREE TOILETS. ONE SURVIVOR."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", Color(1, 1, 1, 0.66))
	content.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 12
	content.add_child(spacer)

	var lives_row := HBoxContainer.new()
	lives_row.add_theme_constant_override("separation", 20)
	var lives_label := Label.new()
	lives_label.text = "LIVES PER PLAYER"
	lives_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lives_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lives_label.add_theme_font_size_override("font_size", 18)
	lives_label.add_theme_color_override("font_color", Color("f7d7f3"))
	lives_row.add_child(lives_label)
	lives_selector = OptionButton.new()
	lives_selector.custom_minimum_size = Vector2(150, 50)
	lives_selector.add_theme_font_size_override("font_size", 19)
	for life_count in [1, 2, 3, 5]:
		lives_selector.add_item("%d %s" % [life_count, "LIFE" if life_count == 1 else "LIVES"])
		lives_selector.set_item_metadata(lives_selector.item_count - 1, life_count)
	lives_selector.select(0)
	lives_selector.item_selected.connect(_on_lives_selected)
	lives_row.add_child(lives_selector)
	content.add_child(lives_row)

	var single_player := _menu_button("SINGLE PLAYER")
	single_player.pressed.connect(_on_single_player_pressed)
	content.add_child(single_player)

	var multiplayer := _menu_button("MULTIPLAYER")
	multiplayer.pressed.connect(_show_multiplayer_menu)
	content.add_child(multiplayer)

	crash_logs_button = _menu_button("OPEN CRASH LOGS")
	crash_logs_button.custom_minimum_size.y = 48
	crash_logs_button.add_theme_font_size_override("font_size", 17)
	crash_logs_button.tooltip_text = Diagnostics.get_log_directory()
	crash_logs_button.pressed.connect(_on_open_crash_logs_pressed)
	content.add_child(crash_logs_button)

	var note := Label.new()
	note.text = "A previous crash log was found. Open the logs and send the newest file." if Diagnostics.previous_crash_detected else "Flush all three toilets to unlock triple damage."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color("c8bdd0"))
	content.add_child(note)


func _create_multiplayer_menu(canvas: CanvasLayer) -> void:
	multiplayer_menu_root = Control.new()
	multiplayer_menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	multiplayer_menu_root.visible = false
	canvas.add_child(multiplayer_menu_root)

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("17121f")
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	multiplayer_menu_root.add_child(background)

	var panel := PanelContainer.new()
	panel.position = Vector2(270, 35)
	panel.size = Vector2(740, 650)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.045, 0.035, 0.065, 0.98)
	panel_style.border_color = Color("c52cae")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", panel_style)
	multiplayer_menu_root.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 42
	content.offset_top = 24
	content.offset_right = -42
	content.offset_bottom = -24
	panel.add_child(content)

	var title := Label.new()
	title.text = "MULTIPLAYER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color("ff45dc"))
	content.add_child(title)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 14)
	name_row.add_child(_network_field_label("YOUR NAME"))
	player_name_edit = LineEdit.new()
	player_name_edit.text = "Player"
	player_name_edit.max_length = 16
	player_name_edit.custom_minimum_size = Vector2(390, 42)
	player_name_edit.add_theme_font_size_override("font_size", 18)
	name_row.add_child(player_name_edit)
	content.add_child(name_row)

	var host_heading := _network_heading("HOST A GAME")
	content.add_child(host_heading)
	var host_row := HBoxContainer.new()
	host_row.add_theme_constant_override("separation", 10)
	player_count_selector = OptionButton.new()
	player_count_selector.custom_minimum_size = Vector2(170, 46)
	for count in range(MIN_NETWORK_PLAYERS, MAX_NETWORK_PLAYERS + 1):
		player_count_selector.add_item("%d PLAYERS" % count)
		player_count_selector.set_item_metadata(player_count_selector.item_count - 1, count)
	player_count_selector.select(selected_player_count - MIN_NETWORK_PLAYERS)
	player_count_selector.item_selected.connect(_on_player_count_selected)
	host_row.add_child(player_count_selector)
	host_port_edit = _network_line_edit(str(DEFAULT_NETWORK_PORT), "UDP PORT", 130)
	host_port_edit.max_length = 5
	host_row.add_child(host_port_edit)
	var host_button := _menu_button("CREATE LOBBY")
	host_button.custom_minimum_size = Vector2(260, 46)
	host_button.add_theme_font_size_override("font_size", 18)
	host_button.pressed.connect(_host_lobby)
	host_row.add_child(host_button)
	content.add_child(host_row)
	upnp_checkbox = CheckBox.new()
	upnp_checkbox.text = "Automatically open the UDP port for internet players (UPnP)"
	upnp_checkbox.button_pressed = true
	upnp_checkbox.tooltip_text = "If the router supports UPnP, the game will open the selected UDP port and show a public address."
	upnp_checkbox.add_theme_font_size_override("font_size", 15)
	upnp_checkbox.add_theme_color_override("font_color", Color("d7cadc"))
	content.add_child(upnp_checkbox)

	var join_heading := _network_heading("JOIN A GAME")
	content.add_child(join_heading)
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 10)
	join_ip_edit = _network_line_edit("", "HOST IP", 255)
	join_ip_edit.placeholder_text = "192.168.1.42:7000"
	join_ip_edit.tooltip_text = "Paste the host's copied IP:port here."
	join_row.add_child(join_ip_edit)
	join_port_edit = _network_line_edit(str(DEFAULT_NETWORK_PORT), "PORT", 110)
	join_port_edit.max_length = 5
	join_row.add_child(join_port_edit)
	var join_button := _menu_button("JOIN")
	join_button.custom_minimum_size = Vector2(240, 46)
	join_button.add_theme_font_size_override("font_size", 18)
	join_button.pressed.connect(_join_lobby)
	join_row.add_child(join_button)
	content.add_child(join_row)

	network_status = Label.new()
	network_status.text = "Same Wi-Fi: share the host's LAN address. Internet: forward the UDP port first."
	network_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	network_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	network_status.custom_minimum_size.y = 62
	network_status.add_theme_font_size_override("font_size", 15)
	network_status.add_theme_color_override("font_color", Color("c8bdd0"))
	content.add_child(network_status)

	lobby_roster = Label.new()
	lobby_roster.text = ""
	lobby_roster.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_roster.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lobby_roster.custom_minimum_size.y = 100
	lobby_roster.add_theme_font_size_override("font_size", 17)
	lobby_roster.add_theme_color_override("font_color", Color("f7d7f3"))
	content.add_child(lobby_roster)

	var lobby_actions := HBoxContainer.new()
	lobby_actions.add_theme_constant_override("separation", 10)
	copy_address_button = _menu_button("COPY LAN")
	copy_address_button.custom_minimum_size = Vector2(135, 50)
	copy_address_button.add_theme_font_size_override("font_size", 15)
	copy_address_button.visible = false
	copy_address_button.pressed.connect(_copy_host_address)
	lobby_actions.add_child(copy_address_button)
	copy_public_address_button = _menu_button("COPY INTERNET")
	copy_public_address_button.custom_minimum_size = Vector2(175, 50)
	copy_public_address_button.add_theme_font_size_override("font_size", 14)
	copy_public_address_button.visible = false
	copy_public_address_button.pressed.connect(_copy_public_host_address)
	lobby_actions.add_child(copy_public_address_button)
	host_start_button = _menu_button("START MATCH")
	host_start_button.custom_minimum_size = Vector2(200, 50)
	host_start_button.add_theme_font_size_override("font_size", 15)
	host_start_button.visible = false
	host_start_button.disabled = true
	host_start_button.pressed.connect(_start_network_match)
	lobby_actions.add_child(host_start_button)
	var back_button := _menu_button("BACK")
	back_button.custom_minimum_size = Vector2(110, 50)
	back_button.add_theme_font_size_override("font_size", 15)
	back_button.pressed.connect(_leave_multiplayer_menu)
	lobby_actions.add_child(back_button)
	content.add_child(lobby_actions)


func _network_heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color("ff8aea"))
	return label


func _network_field_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(180, 42)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	return label


func _network_line_edit(value: String, placeholder: String, width: float) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = value
	edit.placeholder_text = placeholder
	edit.custom_minimum_size = Vector2(width, 46)
	edit.add_theme_font_size_override("font_size", 18)
	return edit


func _menu_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 64)
	button.add_theme_font_size_override("font_size", 23)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("292035")
	normal.border_color = Color("71507a")
	normal.set_border_width_all(1)
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("5b205b")
	hover.border_color = Color("ff45dc")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("8b267d")
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("1c1822")
	disabled.border_color = Color("443849")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.32))
	return button


func _show_main_menu() -> void:
	menu_root.visible = true
	multiplayer_menu_root.visible = false
	hud_root.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_single_player_pressed() -> void:
	_close_network_connection()
	_start_round()


func _on_open_crash_logs_pressed() -> void:
	var open_error := Diagnostics.open_log_folder()
	crash_logs_button.text = "LOG FOLDER OPENED" if open_error == OK else "LOG PATH COPIED"


func _on_lives_selected(index: int) -> void:
	selected_lives = int(lives_selector.get_item_metadata(index))


func _show_multiplayer_menu() -> void:
	menu_root.visible = false
	multiplayer_menu_root.visible = true
	hud_root.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _leave_multiplayer_menu() -> void:
	_close_network_connection()
	lobby_players.clear()
	lobby_roster.text = ""
	network_status.text = "Same Wi-Fi: share the host's LAN address. Internet: forward the UDP port first."
	copy_address_button.visible = false
	copy_public_address_button.visible = false
	host_start_button.visible = false
	_show_main_menu()


func _on_player_count_selected(index: int) -> void:
	selected_player_count = int(player_count_selector.get_item_metadata(index))


func _host_lobby() -> void:
	_close_network_connection()
	network_port = _validated_port(host_port_edit.text)
	host_port_edit.text = str(network_port)
	Diagnostics.log_event("host_lobby_requested", {
		"players": selected_player_count,
		"lives": selected_lives,
		"port": network_port,
		"upnp": upnp_checkbox.button_pressed
	})
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(network_port, selected_player_count - 1)
	if error != OK:
		Diagnostics.log_error("host_lobby_failed", {"error": error_string(error), "port": network_port})
		network_status.text = "Could not host on UDP %d: %s" % [network_port, error_string(error)]
		return
	multiplayer.multiplayer_peer = peer
	is_network_host = true
	network_match_started = false
	lobby_players = {1: _clean_player_name(player_name_edit.text, 1)}
	copy_address_button.visible = true
	copy_public_address_button.visible = false
	host_start_button.visible = true
	if upnp_checkbox.button_pressed:
		_start_upnp_setup(network_port)
	Diagnostics.log_event("host_lobby_created", {"lan_address": _get_lan_address(), "port": network_port})
	_broadcast_lobby_state()


func _join_lobby() -> void:
	var address := join_ip_edit.text.strip_edges()
	if address.is_empty():
		network_status.text = "Enter the host's IP address first."
		return
	_close_network_connection()
	if address.count(":") == 1:
		var address_parts := address.split(":")
		if address_parts.size() == 2 and str(address_parts[1]).is_valid_int():
			address = str(address_parts[0]).strip_edges()
			network_port = _validated_port(str(address_parts[1]))
		else:
			network_port = _validated_port(join_port_edit.text)
	else:
		network_port = _validated_port(join_port_edit.text)
	join_port_edit.text = str(network_port)
	Diagnostics.log_event("join_lobby_requested", {"address": address, "port": network_port})
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, network_port)
	if error != OK:
		Diagnostics.log_error("join_lobby_failed", {"error": error_string(error), "address": address, "port": network_port})
		network_status.text = "Could not start connection: %s" % error_string(error)
		return
	multiplayer.multiplayer_peer = peer
	is_network_host = false
	network_match_started = false
	lobby_players.clear()
	copy_address_button.visible = false
	copy_public_address_button.visible = false
	host_start_button.visible = false
	network_status.text = "Connecting to %s:%d..." % [address, network_port]
	lobby_roster.text = ""


func _on_connected_to_server() -> void:
	Diagnostics.log_event("connected_to_host", {"peer_id": multiplayer.get_unique_id()})
	network_status.text = "Connected. Joining lobby..."
	_register_lobby_player.rpc_id(1, _clean_player_name(player_name_edit.text, multiplayer.get_unique_id()))


func _on_network_connection_failed() -> void:
	Diagnostics.log_error("connection_to_host_failed")
	network_status.text = "Connection failed. Check the IP, UDP port, firewall, and port forwarding."
	_close_network_connection()


func _on_server_disconnected() -> void:
	Diagnostics.log_warning("host_disconnected", {"match_started": network_match_started})
	network_match_started = false
	round_over = false
	_clear_combatants()
	_show_multiplayer_menu()
	network_status.text = "The host disconnected."
	lobby_roster.text = ""
	_close_network_connection()


func _on_network_peer_connected(peer_id: int) -> void:
	Diagnostics.log_event("network_peer_connected", {"peer_id": peer_id, "host": is_network_host})
	if is_network_host and not network_match_started:
		network_status.text = "A player connected. Waiting for their name..."


func _on_network_peer_disconnected(disconnected_peer_id: int) -> void:
	Diagnostics.log_warning("network_peer_disconnected", {"peer_id": disconnected_peer_id, "host": is_network_host, "match_started": network_match_started})
	if not is_network_host:
		return
	lobby_players.erase(disconnected_peer_id)
	if network_match_started:
		_remove_disconnected_network_player(disconnected_peer_id)
	else:
		_broadcast_lobby_state()


@rpc("any_peer", "call_remote", "reliable")
func _register_lobby_player(requested_name: String) -> void:
	if not multiplayer.is_server() or network_match_started:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 1 or lobby_players.size() >= selected_player_count:
		return
	lobby_players[sender_id] = _clean_player_name(requested_name, sender_id)
	Diagnostics.log_event("lobby_player_registered", {"peer_id": sender_id, "name": lobby_players[sender_id], "count": lobby_players.size()})
	_broadcast_lobby_state()


func _broadcast_lobby_state() -> void:
	if not multiplayer.is_server():
		return
	_receive_lobby_state.rpc(lobby_players, selected_player_count, selected_lives, network_port, _get_lan_address())


@rpc("authority", "call_local", "reliable")
func _receive_lobby_state(players: Dictionary, player_limit: int, lives: int, port: int, lan_address: String) -> void:
	lobby_players = players.duplicate()
	selected_player_count = player_limit
	selected_lives = lives
	network_port = port
	var ids := lobby_players.keys()
	ids.sort()
	var names: Array[String] = []
	for id in ids:
		names.append(str(lobby_players[id]))
	lobby_roster.text = "LOBBY  %d / %d\n%s" % [lobby_players.size(), selected_player_count, "  •  ".join(names)]
	if is_network_host:
		_refresh_host_network_status(lan_address)
		host_start_button.disabled = lobby_players.size() != selected_player_count
		if "--qa-network-host" in OS.get_cmdline_user_args() and lobby_players.size() == selected_player_count:
			_start_network_match.call_deferred()
	else:
		network_status.text = "Connected. Waiting for the host to start.  •  %d lives" % selected_lives


func _start_network_match() -> void:
	if not is_network_host or not multiplayer.is_server():
		return
	if lobby_players.size() != selected_player_count:
		network_status.text = "Waiting for %d more player(s)." % (selected_player_count - lobby_players.size())
		return
	var peer_ids := lobby_players.keys()
	peer_ids.sort()
	Diagnostics.log_event("network_match_starting", {"players": peer_ids.size(), "lives": selected_lives})
	var available_spawns := _network_spawn_positions()
	available_spawns.shuffle()
	var chosen_spawns: Array[Vector3] = []
	for index in peer_ids.size():
		chosen_spawns.append(available_spawns[index])
	_begin_network_match.rpc(peer_ids, lobby_players, selected_lives, chosen_spawns)


@rpc("authority", "call_local", "reliable")
func _begin_network_match(peer_ids: Array, player_names: Dictionary, lives: int, chosen_spawns: Array) -> void:
	_clear_combatants()
	network_match_started = true
	round_over = false
	selected_lives = lives
	Diagnostics.log_event("network_match_started", {"local_peer_id": multiplayer.get_unique_id(), "players": peer_ids.size(), "lives": lives, "host": multiplayer.is_server()})
	network_state_time = 0.0
	ui_status.visible = false
	replay_button.visible = false
	replay_button.text = "PLAY AGAIN" if is_network_host else "WAITING FOR HOST"
	replay_button.disabled = not is_network_host
	hud_root.visible = true
	menu_root.visible = false
	multiplayer_menu_root.visible = false

	spawn_positions = _network_spawn_positions()
	for index in peer_ids.size():
		var id := int(peer_ids[index])
		var network_player := NetworkPlayerScript.new() as NetworkFpsPlayer
		network_player.setup_network(id, str(player_names[id]), self, chosen_spawns[index])
		network_player.game = self
		network_player.lives_remaining = selected_lives
		add_child(network_player)
		combatants.append(network_player)
		network_players[id] = network_player
		if multiplayer.is_server():
			network_player.died.connect(_on_combatant_died)

	var local_id := multiplayer.get_unique_id()
	player = network_players.get(local_id) as FpsPlayer
	if player:
		player.camera.current = true
		player.health_changed.connect(_on_player_health_changed)
		player.toilet_progress.connect(_on_toilet_progress)
		player.powerup_activated.connect(_on_powerup_activated)
	ui_health.text = "HEALTH  100"
	ui_toilets.text = "TOILETS  0 / 3    PISTOL  24"
	ui_toilets.modulate = Color.WHITE
	ui_lives.text = "LIVES  %d" % selected_lives
	_show_banner("LAST ONE STANDING", 2.4)
	if "--qa-network-host" in OS.get_cmdline_user_args() or "--qa-network-client" in OS.get_cmdline_user_args():
		_finish_qa_network_test.call_deferred()


func _network_spawn_positions() -> Array[Vector3]:
	return [
		_expanded(Vector3(1.35, 0.05, 3.55)), _expanded(Vector3(2.5, 0.05, 1.7)),
		_expanded(Vector3(7.4, 0.05, 2.55)), _expanded(Vector3(8.6, 0.05, 4.8)),
		_expanded(Vector3(3.55, 0.05, 7.3)), _expanded(Vector3(2.85, 0.05, 8.8)),
		_expanded(Vector3(6.3, 0.05, 7.55)), _expanded(Vector3(8.7, 0.05, 7.4))
	]


func send_local_network_input(move_input: Vector2, sprinting: bool, firing: bool, yaw: float, pitch: float) -> void:
	if network_match_started and not multiplayer.is_server():
		_server_receive_input.rpc_id(1, move_input, sprinting, firing, yaw, pitch)


func send_local_network_action(action: String) -> void:
	if network_match_started and not multiplayer.is_server():
		_server_receive_action.rpc_id(1, action)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _server_receive_input(move_input: Vector2, sprinting: bool, firing: bool, yaw: float, pitch: float) -> void:
	if not multiplayer.is_server() or not network_match_started:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var sender_player := network_players.get(sender_id) as NetworkFpsPlayer
	if sender_player:
		sender_player.set_server_input(move_input, sprinting, firing, yaw, pitch)


@rpc("any_peer", "call_remote", "reliable", 2)
func _server_receive_action(action: String) -> void:
	if not multiplayer.is_server() or not network_match_started:
		return
	if action != "jump" and action != "interact":
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var sender_player := network_players.get(sender_id) as NetworkFpsPlayer
	if sender_player:
		sender_player.queue_network_action(action)


func _broadcast_network_state() -> void:
	var state: Dictionary = {}
	for id in network_players:
		var network_player := network_players[id] as NetworkFpsPlayer
		if not is_instance_valid(network_player):
			continue
		state[id] = {
			"position": network_player.global_position,
			"yaw": network_player.rotation.y,
			"pitch": network_player.neck.rotation.x,
			"health": network_player.health,
			"lives": network_player.lives_remaining,
			"alive": network_player.is_alive,
			"damage": network_player.damage,
			"weapon": network_player.current_weapon,
			"toilets": network_player.flushed_toilets.keys()
		}
	_receive_network_state.rpc(state)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _receive_network_state(state: Dictionary) -> void:
	for id in state:
		var network_player := network_players.get(id) as NetworkFpsPlayer
		if network_player:
			network_player.apply_network_state(state[id])


func _remove_disconnected_network_player(disconnected_peer_id: int) -> void:
	var disconnected_player := network_players.get(disconnected_peer_id) as NetworkFpsPlayer
	if disconnected_player:
		combatants.erase(disconnected_player)
		disconnected_player.queue_free()
		network_players.erase(disconnected_peer_id)
		_remove_network_player.rpc(disconnected_peer_id)
	var contenders := _get_remaining_contenders()
	if contenders.size() <= 1:
		_finish_round(contenders)


@rpc("authority", "call_remote", "reliable")
func _remove_network_player(disconnected_peer_id: int) -> void:
	var disconnected_player := network_players.get(disconnected_peer_id) as NetworkFpsPlayer
	if disconnected_player:
		combatants.erase(disconnected_player)
		disconnected_player.queue_free()
		network_players.erase(disconnected_peer_id)


func _clear_combatants() -> void:
	for old_combatant in combatants:
		if is_instance_valid(old_combatant):
			old_combatant.queue_free()
	combatants.clear()
	network_players.clear()
	player = null


func _close_network_connection() -> void:
	_close_upnp_mapping()
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	is_network_host = false
	network_match_started = false


func _copy_host_address() -> void:
	var address := "%s:%d" % [_get_lan_address(), network_port]
	DisplayServer.clipboard_set(address)
	network_status.text = "Copied LAN address %s — use this on the same network." % address


func _copy_public_host_address() -> void:
	if upnp_public_address.is_empty():
		return
	var address := "%s:%d" % [upnp_public_address, network_port]
	DisplayServer.clipboard_set(address)
	network_status.text = "Copied internet address %s — send this to remote players." % address


func _start_upnp_setup(port: int) -> void:
	upnp_status_message = "Opening UDP %d on the router..." % port
	Diagnostics.log_event("upnp_setup_started", {"port": port})
	upnp_thread = Thread.new()
	var thread_error := upnp_thread.start(_upnp_setup_worker.bind(port))
	if thread_error != OK:
		upnp_thread = null
		upnp_status_message = "UPnP could not start (%s)." % error_string(thread_error)
		Diagnostics.log_warning("upnp_thread_failed", {"error": error_string(thread_error)})


func _upnp_setup_worker(port: int) -> Dictionary:
	var router_upnp := UPNP.new()
	var discovery_result := router_upnp.discover(2000, 2, "InternetGatewayDevice")
	var result := {
		"upnp": router_upnp,
		"port": port,
		"discovery_result": discovery_result,
		"mapping_result": -1,
		"external_address": ""
	}
	if discovery_result != UPNP.UPNP_RESULT_SUCCESS:
		return result
	var gateway := router_upnp.get_gateway()
	if gateway == null or not gateway.is_valid_gateway():
		result["mapping_result"] = UPNP.UPNP_RESULT_NO_GATEWAY
		return result
	# Prefer a one-day lease so a crashed game does not leave the port open forever.
	# Some routers only accept permanent mappings, so retain that compatibility fallback.
	result["mapping_result"] = router_upnp.add_port_mapping(port, port, "Shit-Tacular", "UDP", 86400)
	if int(result["mapping_result"]) == UPNP.UPNP_RESULT_ONLY_PERMANENT_LEASE_SUPPORTED or int(result["mapping_result"]) == UPNP.UPNP_RESULT_INVALID_DURATION:
		result["mapping_result"] = router_upnp.add_port_mapping(port, port, "Shit-Tacular", "UDP", 0)
	if int(result["mapping_result"]) == UPNP.UPNP_RESULT_SUCCESS:
		result["external_address"] = router_upnp.query_external_address()
	return result


func _poll_upnp_setup() -> void:
	if upnp_thread == null or upnp_thread.is_alive():
		return
	var worker_result = upnp_thread.wait_to_finish()
	upnp_thread = null
	if typeof(worker_result) != TYPE_DICTIONARY:
		upnp_status_message = "UPnP returned an invalid response."
		Diagnostics.log_warning("upnp_invalid_response")
		_refresh_host_network_status()
		return
	var result := worker_result as Dictionary
	var completed_upnp: UPNP = result.get("upnp")
	var completed_port := int(result.get("port", 0))
	var discovery_result := int(result.get("discovery_result", -1))
	var mapping_result := int(result.get("mapping_result", -1))
	if not is_network_host or completed_port != network_port:
		if completed_upnp and mapping_result == UPNP.UPNP_RESULT_SUCCESS:
			completed_upnp.delete_port_mapping(completed_port, "UDP")
		return
	if discovery_result != UPNP.UPNP_RESULT_SUCCESS:
		upnp_status_message = "UPnP unavailable: %s" % _upnp_error_message(discovery_result)
		Diagnostics.log_warning("upnp_discovery_failed", {"result": discovery_result, "message": _upnp_error_message(discovery_result)})
		_refresh_host_network_status()
		return
	if mapping_result != UPNP.UPNP_RESULT_SUCCESS:
		upnp_status_message = "UPnP could not open UDP %d: %s" % [network_port, _upnp_error_message(mapping_result)]
		Diagnostics.log_warning("upnp_mapping_failed", {"port": network_port, "result": mapping_result, "message": _upnp_error_message(mapping_result)})
		_refresh_host_network_status()
		return
	active_upnp = completed_upnp
	upnp_mapping_active = true
	upnp_mapped_port = completed_port
	upnp_public_address = str(result.get("external_address", ""))
	copy_public_address_button.visible = not upnp_public_address.is_empty()
	if upnp_public_address.is_empty():
		upnp_status_message = "UDP %d is open, but the router did not report its public IP." % network_port
	elif _is_private_or_cgnat_address(upnp_public_address):
		upnp_status_message = "UDP is open, but %s looks private; double NAT or CGNAT may block guests." % upnp_public_address
	else:
		upnp_status_message = "Internet address ready."
	Diagnostics.log_event("upnp_mapping_created", {"port": network_port, "external_address": upnp_public_address, "private_or_cgnat": _is_private_or_cgnat_address(upnp_public_address)})
	_refresh_host_network_status()


func _close_upnp_mapping() -> void:
	if upnp_thread != null:
		var worker_result = upnp_thread.wait_to_finish()
		upnp_thread = null
		if typeof(worker_result) == TYPE_DICTIONARY:
			var pending_result := worker_result as Dictionary
			var pending_upnp: UPNP = pending_result.get("upnp")
			if pending_upnp and int(pending_result.get("mapping_result", -1)) == UPNP.UPNP_RESULT_SUCCESS:
				pending_upnp.delete_port_mapping(int(pending_result.get("port", 0)), "UDP")
	if upnp_mapping_active and active_upnp:
		var delete_result := active_upnp.delete_port_mapping(upnp_mapped_port, "UDP")
		Diagnostics.log_event("upnp_mapping_removed", {"port": upnp_mapped_port, "result": delete_result})
	active_upnp = null
	upnp_mapping_active = false
	upnp_public_address = ""
	upnp_status_message = ""
	upnp_mapped_port = 0
	if copy_public_address_button:
		copy_public_address_button.visible = false


func _refresh_host_network_status(lan_address: String = "") -> void:
	if not is_network_host or network_status == null:
		return
	var lan := lan_address if not lan_address.is_empty() else _get_lan_address()
	var lan_text := "LAN %s:%d" % [lan, network_port]
	if upnp_thread != null:
		network_status.text = "%s  •  %s" % [lan_text, upnp_status_message]
	elif upnp_mapping_active and not upnp_public_address.is_empty():
		network_status.text = "%s  •  Internet %s:%d\n%s" % [lan_text, upnp_public_address, network_port, upnp_status_message]
	elif not upnp_status_message.is_empty():
		network_status.text = "%s\n%s Manual UDP forwarding still works." % [lan_text, upnp_status_message]
	else:
		network_status.text = "Share %s  (same Wi-Fi), or manually forward UDP %d." % [lan_text, network_port]


func _upnp_error_message(result: int) -> String:
	match result:
		UPNP.UPNP_RESULT_NOT_AUTHORIZED:
			return "the router has UPnP disabled"
		UPNP.UPNP_RESULT_NO_GATEWAY, UPNP.UPNP_RESULT_NO_DEVICES:
			return "no compatible router was found"
		UPNP.UPNP_RESULT_CONFLICT_WITH_OTHER_MAPPING, UPNP.UPNP_RESULT_CONFLICT_WITH_OTHER_MECHANISM:
			return "that port is already mapped"
		UPNP.UPNP_RESULT_SOCKET_ERROR:
			return "the router could not be reached"
		_:
			return "router error %d" % result


func _is_private_or_cgnat_address(address: String) -> bool:
	var pieces := address.split(".")
	if pieces.size() != 4:
		return false
	var first := int(pieces[0])
	var second := int(pieces[1])
	return first == 10 or first == 127 or (first == 172 and second >= 16 and second <= 31) or (first == 192 and second == 168) or (first == 100 and second >= 64 and second <= 127)


func _get_lan_address() -> String:
	var fallback := "127.0.0.1"
	for address in IP.get_local_addresses():
		if ":" in address or address.begins_with("127.") or address.begins_with("169.254."):
			continue
		if address.begins_with("192.168.") or address.begins_with("10."):
			return address
		if address.begins_with("172."):
			var pieces := address.split(".")
			if pieces.size() == 4 and int(pieces[1]) >= 16 and int(pieces[1]) <= 31:
				return address
		fallback = address
	return fallback


func _validated_port(value: String) -> int:
	var parsed := int(value)
	return clampi(parsed if parsed > 0 else DEFAULT_NETWORK_PORT, 1024, 65535)


func _clean_player_name(requested_name: String, id: int) -> String:
	var cleaned := requested_name.replace("\n", " ").replace("\r", " ").strip_edges().substr(0, 16)
	return cleaned if not cleaned.is_empty() else "Player %d" % id


func update_local_lives(lives: int) -> void:
	ui_lives.text = "LIVES  %d" % lives


func update_local_powerup(current_damage: int, weapon_name: String = "") -> void:
	if weapon_name == FpsPlayer.WEAPON_RAINBOW_RIFLE or current_damage == 40:
		ui_toilets.modulate = Color("ff53e4")
		_show_banner("TRIPLE-SHIT!", 1.0)


func update_local_toilets(count: int, current_damage: int, weapon_name: String = "") -> void:
	var display_name := player.weapon_display_name() if player and player.has_method("weapon_display_name") else weapon_name.replace("_", " ").to_upper()
	var damage_text := player.weapon_damage_text() if player and player.has_method("weapon_damage_text") else str(current_damage)
	ui_toilets.text = "TOILETS  %d / 3    %s  %s" % [count, display_name, damage_text]
	if count == 3 and weapon_name == FpsPlayer.WEAPON_RAINBOW_RIFLE:
		update_local_powerup(current_damage, weapon_name)


func _ui_label(width: float, position: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = position
	label.size = Vector2(width, 110)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f5f2ff"))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _show_banner(text: String, duration: float) -> void:
	ui_banner.text = text
	ui_banner.modulate.a = 1.0
	ui_banner.scale = Vector2.ONE
	ui_banner.rotation = 0.0
	ui_banner.pivot_offset = ui_banner.size * 0.5
	banner_time = duration


func spawn_impact(position: Vector3, normal: Vector3, powered_up: bool) -> void:
	_create_impact(position, normal, powered_up)
	if network_match_started and multiplayer.is_server():
		_spawn_network_impact.rpc(position, normal, powered_up)


func spawn_explosion(position: Vector3, attacker: Node, radius: float, max_damage: int) -> void:
	if network_match_started and not multiplayer.is_server():
		return
	for combatant in combatants:
		if combatant == attacker or not is_instance_valid(combatant) or not combatant.get("is_alive"):
			continue
		var distance: float = combatant.global_position.distance_to(position)
		if distance <= radius:
			var falloff := clampf(1.0 - distance / radius, 0.28, 1.0)
			combatant.apply_damage(roundi(max_damage * falloff), attacker)
	_create_explosion(position, radius)
	if network_match_started and multiplayer.is_server():
		_spawn_network_explosion.rpc(position, radius)


@rpc("authority", "call_remote", "reliable")
func _spawn_network_explosion(position: Vector3, radius: float) -> void:
	_create_explosion(position, radius)


func _create_explosion(position: Vector3, radius: float) -> void:
	var blast := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.36
	blast.mesh = mesh
	blast.position = position
	var blast_material := _material(Color("ff7b24"), 0.18, true)
	blast.material_override = blast_material
	add_child(blast)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(blast, "scale", Vector3.ONE * (radius / 0.18), 0.2)
	tween.tween_property(blast, "scale", Vector3.ZERO, 0.16)
	tween.tween_callback(blast.queue_free)


@rpc("authority", "call_remote", "unreliable")
func _spawn_network_impact(position: Vector3, normal: Vector3, powered_up: bool) -> void:
	_create_impact(position, normal, powered_up)


func _create_impact(position: Vector3, normal: Vector3, powered_up: bool) -> void:
	var impact := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.035 if not powered_up else 0.065
	mesh.height = mesh.radius * 2.0
	impact.mesh = mesh
	impact.position = position + normal * 0.025
	impact.material_override = _material(Color("ff35e1") if powered_up else Color("ffb35a"), 0.2, true)
	add_child(impact)
	var tween := create_tween()
	tween.tween_property(impact, "scale", Vector3.ZERO, 0.3)
	tween.tween_callback(impact.queue_free)


func _build_navigation_graph() -> void:
	var points := [
		Vector3(1.8, 0.05, 3.2), Vector3(3.55, 0.05, 4.45), Vector3(4.05, 0.05, 5.45),
		Vector3(4.45, 0.05, 4.35), Vector3(5.35, 0.05, 5.45), Vector3(7.25, 0.05, 5.35),
		Vector3(6.6, 0.05, 1.35), Vector3(6.35, 0.05, 7.35), Vector3(8.65, 0.05, 7.4),
		Vector3(4.1, 0.05, 6.45), Vector3(3.2, 0.05, 7.8), Vector3(1.05, 0.05, 5.35),
		Vector3(1.05, 0.05, 6.9), Vector3(1.05, 0.05, 8.3), Vector3(4.15, 0.05, 9.75),
		Vector3(3.65, 0.05, 10.55)
	]
	for index in points.size():
		nav_graph.add_point(index, _expanded(points[index]))
	for edge in [[0,1],[1,2],[2,3],[2,4],[4,5],[5,6],[5,7],[5,8],[2,9],[9,10],[0,11],[11,12],[12,13],[10,14],[14,15]]:
		nav_graph.connect_points(edge[0], edge[1])


func find_apartment_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var start_id := nav_graph.get_closest_point(from)
	var end_id := nav_graph.get_closest_point(to)
	var path := nav_graph.get_point_path(start_id, end_id)
	path.append(to)
	return path


func _plan(point: Vector2) -> Vector3:
	return Vector3((point.x - PLAN_ORIGIN.x) * PLAN_SCALE, 0.0, (point.y - PLAN_ORIGIN.y) * PLAN_SCALE)


func _expanded(position: Vector3) -> Vector3:
	return Vector3(position.x * APARTMENT_SCALE, position.y, position.z * APARTMENT_SCALE)


func _expanded_size(size: Vector3) -> Vector3:
	return Vector3(size.x * APARTMENT_SCALE, size.y, size.z * APARTMENT_SCALE)


func _create_wall(a: Vector3, b: Vector3, thickness: float = WALL_THICKNESS, height: float = WALL_HEIGHT, base_y: float = 0.0, material: StandardMaterial3D = null) -> void:
	var direction := b - a
	var length := Vector2(direction.x, direction.z).length()
	var center := (a + b) * 0.5 + Vector3.UP * (base_y + height * 0.5)
	var body := _create_box("Wall", center, Vector3(length + thickness, height, thickness), material if material else wall_material, true)
	body.rotation.y = -atan2(direction.z, direction.x)


func _create_box(object_name: String, position: Vector3, size: Vector3, material: StandardMaterial3D, collision: bool) -> Node3D:
	var root: Node3D
	if collision:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		root = body
	else:
		root = Node3D.new()
	root.name = object_name
	root.position = position
	add_child(root)

	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material
	root.add_child(visual)
	if collision:
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		root.add_child(collider)
	return root


func _create_bed(position: Vector3, rotation_y: float, blanket_color: Color) -> void:
	var bed := Node3D.new()
	bed.position = _expanded(position)
	bed.rotation.y = rotation_y
	add_child(bed)
	_create_child_box(bed, Vector3(0, 0.26, 0), Vector3(1.45, 0.3, 2.05), wood_material)
	_create_child_box(bed, Vector3(0, 0.47, -0.08), Vector3(1.34, 0.24, 1.72), _material(blanket_color, 0.9))
	_create_child_box(bed, Vector3(0, 0.73, -0.76), Vector3(1.18, 0.16, 0.42), white_material)


func _create_sofa(position: Vector3, rotation_y: float, color: Color) -> void:
	var sofa := Node3D.new()
	sofa.position = _expanded(position)
	sofa.rotation.y = rotation_y
	add_child(sofa)
	var material := _material(color, 0.95)
	_create_child_box(sofa, Vector3(0, 0.34, 0), Vector3(2.25, 0.48, 0.82), material)
	_create_child_box(sofa, Vector3(0, 0.83, 0.33), Vector3(2.25, 0.64, 0.22), material)
	_create_child_box(sofa, Vector3(-1.03, 0.63, 0), Vector3(0.2, 0.55, 0.82), material)
	_create_child_box(sofa, Vector3(1.03, 0.63, 0), Vector3(0.2, 0.55, 0.82), material)
	_create_child_box(sofa, Vector3(-0.48, 0.69, -0.28), Vector3(0.48, 0.16, 0.42), _material(Color("ffd45c"), 0.9), false)
	_create_child_box(sofa, Vector3(0.48, 0.69, -0.28), Vector3(0.48, 0.16, 0.42), _material(Color("f47cb7"), 0.9), false)


func _create_rug(position: Vector3, size: Vector2, color: Color) -> void:
	position = _expanded(position)
	_create_box("RugBorder", Vector3(position.x, 0.023, position.z), Vector3(size.x + 0.12, 0.02, size.y + 0.12), _material(color.darkened(0.34), 0.96), false)
	_create_box("CartoonRug", Vector3(position.x, 0.039, position.z), Vector3(size.x, 0.025, size.y), _material(color, 0.94), false)


func _create_floor_lamp(position: Vector3, shade_color: Color) -> void:
	var lamp := Node3D.new()
	lamp.name = "CartoonFloorLamp"
	lamp.position = _expanded(position)
	add_child(lamp)

	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.2
	base_mesh.bottom_radius = 0.24
	base_mesh.height = 0.08
	base.mesh = base_mesh
	base.position.y = 0.04
	base.material_override = dark_material
	lamp.add_child(base)

	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.025
	pole_mesh.bottom_radius = 0.025
	pole_mesh.height = 1.42
	pole.mesh = pole_mesh
	pole.position.y = 0.75
	pole.material_override = dark_material
	lamp.add_child(pole)

	var shade := MeshInstance3D.new()
	var shade_mesh := CylinderMesh.new()
	shade_mesh.top_radius = 0.17
	shade_mesh.bottom_radius = 0.34
	shade_mesh.height = 0.42
	shade.mesh = shade_mesh
	shade.position.y = 1.55
	shade.material_override = _material(shade_color, 0.82, true)
	lamp.add_child(shade)

	var light := OmniLight3D.new()
	light.position.y = 1.48
	light.light_color = Color("ffd99b")
	light.light_energy = 0.34
	light.omni_range = 2.1
	lamp.add_child(light)


func _create_plant(position: Vector3, leaf_color: Color) -> void:
	var plant := Node3D.new()
	plant.name = "CartoonPlant"
	plant.position = _expanded(position)
	add_child(plant)

	var pot := MeshInstance3D.new()
	var pot_mesh := CylinderMesh.new()
	pot_mesh.top_radius = 0.21
	pot_mesh.bottom_radius = 0.15
	pot_mesh.height = 0.34
	pot.mesh = pot_mesh
	pot.position.y = 0.17
	pot.material_override = _material(Color("dc7048"), 0.82)
	plant.add_child(pot)

	var stem := MeshInstance3D.new()
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.025
	stem_mesh.bottom_radius = 0.035
	stem_mesh.height = 0.55
	stem.mesh = stem_mesh
	stem.position.y = 0.62
	stem.material_override = _material(leaf_color.darkened(0.28), 0.9)
	plant.add_child(stem)

	for leaf_data in [
		[Vector3(-0.13, 0.65, 0.0), Vector3(0.16, 0.29, 0.11), -0.45],
		[Vector3(0.14, 0.75, 0.02), Vector3(0.17, 0.32, 0.11), 0.5],
		[Vector3(-0.04, 0.91, 0.0), Vector3(0.18, 0.34, 0.12), -0.14]
	]:
		var leaf := MeshInstance3D.new()
		var leaf_mesh := SphereMesh.new()
		leaf_mesh.radius = 0.5
		leaf_mesh.height = 1.0
		leaf.mesh = leaf_mesh
		leaf.position = leaf_data[0]
		leaf.scale = leaf_data[1]
		leaf.rotation.z = leaf_data[2]
		leaf.material_override = _material(leaf_color, 0.86)
		plant.add_child(leaf)


func _create_wall_art(position: Vector3, rotation_y: float, color_a: Color, color_b: Color) -> void:
	var artwork := Node3D.new()
	artwork.name = "CartoonWallArt"
	artwork.position = _expanded(position)
	artwork.rotation.y = rotation_y
	add_child(artwork)
	_create_child_box(artwork, Vector3.ZERO, Vector3(1.02, 0.78, 0.055), dark_material, false)
	_create_child_box(artwork, Vector3(0.0, 0.0, 0.034), Vector3(0.88, 0.64, 0.025), _material(Color("fff1d2"), 0.9), false)
	_create_child_box(artwork, Vector3(-0.2, 0.08, 0.052), Vector3(0.34, 0.38, 0.018), _material(color_a, 0.86), false)
	_create_child_box(artwork, Vector3(0.22, -0.1, 0.054), Vector3(0.32, 0.29, 0.02), _material(color_b, 0.86), false)


func _create_wall_mirror(position: Vector3, rotation_y: float, size: Vector2) -> void:
	var mirror := Node3D.new()
	mirror.name = "BathroomWallMirror"
	mirror.position = _expanded(position)
	mirror.rotation.y = rotation_y
	add_child(mirror)
	_create_child_box(mirror, Vector3.ZERO, Vector3(size.x + 0.13, size.y + 0.13, 0.06), _material(Color("ffd45c"), 0.55), false)
	var mirror_material := _material(Color("bcecff"), 0.16)
	mirror_material.metallic = 0.38
	mirror_material.emission_enabled = true
	mirror_material.emission = Color("4d8fa8")
	mirror_material.emission_energy_multiplier = 0.24
	_create_child_box(mirror, Vector3(0.0, 0.0, 0.038), Vector3(size.x, size.y, 0.025), mirror_material, false)

	var shine := MeshInstance3D.new()
	var shine_mesh := BoxMesh.new()
	shine_mesh.size = Vector3(0.055, size.y * 0.78, 0.012)
	shine.mesh = shine_mesh
	shine.position = Vector3(-size.x * 0.23, size.y * 0.02, 0.058)
	shine.rotation.z = -0.18
	shine.material_override = _material(Color(1.0, 1.0, 1.0, 0.72), 0.08, true)
	mirror.add_child(shine)

	var caption := Label3D.new()
	caption.text = "LOOKIN' FLUSHED!"
	caption.font_size = 30
	caption.pixel_size = 0.0023
	caption.outline_size = 9
	caption.modulate = Color("fff176")
	caption.position = Vector3(0.0, size.y * 0.7, 0.07)
	mirror.add_child(caption)


func _create_chair(position: Vector3, rotation_y: float, color: Color) -> void:
	var chair := ChairScript.new() as SittableChair
	chair.setup(_material(color, 0.78))
	chair.position = _expanded(position)
	chair.rotation.y = rotation_y
	add_child(chair)


func _create_tv(position: Vector3, rotation_y: float) -> void:
	var tv := Node3D.new()
	tv.position = _expanded(position)
	tv.rotation.y = rotation_y
	add_child(tv)
	_create_child_box(tv, Vector3.ZERO, Vector3(0.08, 1.05, 1.75), dark_material)
	var screen_material := _material(Color("321c4d"), 0.18, true)
	_create_child_box(tv, Vector3(-0.045, 0.0, 0.0), Vector3(0.012, 0.91, 1.58), screen_material, false)


func _create_child_box(parent: Node3D, position: Vector3, size: Vector3, material: StandardMaterial3D, collision: bool = true) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	if collision:
		var static_body := StaticBody3D.new()
		static_body.collision_layer = 1
		static_body.collision_mask = 0
		static_body.position = position
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		static_body.add_child(collider)
		parent.add_child(static_body)


func _material(color: Color, roughness: float, emissive: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.7
	return material
