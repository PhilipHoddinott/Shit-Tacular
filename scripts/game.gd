extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const BotScript = preload("res://scripts/bot.gd")
const ToiletScript = preload("res://scripts/toilet.gd")
const ChairScript = preload("res://scripts/chair.gd")

const PLAN_SCALE := 0.02
const PLAN_ORIGIN := Vector2(248.0, 14.0)
const WALL_HEIGHT := 2.72
const WALL_THICKNESS := 0.13

var rng := RandomNumberGenerator.new()
var player: FpsPlayer
var combatants: Array[Node] = []
var spawn_positions: Array[Vector3] = []
var nav_graph := AStar3D.new()
var ui_health: Label
var ui_toilets: Label
var ui_prompt: Label
var ui_banner: Label
var ui_status: Label
var replay_button: Button
var hud_root: Control
var menu_root: Control
var banner_time := 0.0
var round_over := false
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
	_setup_materials()
	_setup_world()
	_build_apartment()
	_build_windows_and_entry()
	_build_furniture()
	_build_toilets()
	_build_navigation_graph()
	_create_ui()
	if "--qa-capture" in OS.get_cmdline_user_args():
		_start_round()
		_capture_qa_frame.call_deferred()
	elif "--qa-smoke" in OS.get_cmdline_user_args():
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
	else:
		_show_main_menu()


func _process(delta: float) -> void:
	if player and is_instance_valid(player):
		ui_prompt.text = player.get_interaction_prompt()
	if banner_time > 0.0:
		banner_time -= delta
		ui_banner.modulate.a = minf(1.0, banner_time * 1.8)
	else:
		ui_banner.text = ""
	if round_over and Input.is_action_just_pressed("restart"):
		_start_round()


func _capture_qa_frame() -> void:
	# Optional automated visual check: `godot --path . -- --qa-capture`.
	# It never runs during normal play and its output is ignored by Git.
	player.input_enabled = false
	player.position = Vector3(6.8, 0.05, 5.55)
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
	audit_camera.size = 12.7
	audit_camera.position = Vector3(4.95, 14.0, 5.65)
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
	player.position = Vector3(6.8, 0.05, 5.55)
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
	player.position = Vector3(7.95, 0.05, 6.35)
	player.rotation.y = deg_to_rad(-150.0)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path("res://artifacts/qa_fake_entry.png"))
	print("QA_ENTRY_CAPTURE:", error)
	get_tree().quit()


func _run_qa_smoke() -> void:
	await get_tree().physics_frame
	_assert_hallway_clearance()
	assert(player.health == 100, "Player must spawn with 100 health")
	assert(player.damage == 24, "Pistol must start at 24 damage")
	assert(get_tree().get_nodes_in_group("sittable_chairs").size() == 4, "All four dining chairs must be sittable")
	var test_chair := get_tree().get_first_node_in_group("sittable_chairs") as SittableChair
	assert(test_chair != null, "At least one chair must be sittable")
	player.sit_on(test_chair)
	assert(player.sitting and test_chair.occupant == player, "Player must be able to sit")
	player.stand_up()
	assert(not player.sitting and test_chair.occupant == null, "Player must be able to stand")
	player.register_toilet_flush(1)
	player.register_toilet_flush(1)
	assert(player.flushed_toilets.size() == 1, "The same toilet cannot count twice")
	player.register_toilet_flush(2)
	player.register_toilet_flush(3)
	assert(player.damage == 72, "Three toilets must grant triple damage")
	assert(ui_banner.text == "TRIPLE-SHIT!", "Power-up banner must use the requested wording")
	var test_bot := combatants[1] as ApartmentBot
	test_bot.apply_damage(72, player)
	assert(test_bot.health == 28 and test_bot.is_alive, "72 damage must leave 28 of 100 health")
	test_bot.apply_damage(72, player)
	assert(not test_bot.is_alive, "A second powered shot must eliminate the opponent")
	for index in range(2, combatants.size()):
		combatants[index].apply_damage(999, player)
	await get_tree().create_timer(0.2).timeout
	assert(round_over and replay_button.visible, "Round end must offer a replay button")
	replay_button.pressed.emit()
	await get_tree().process_frame
	assert(not round_over and not replay_button.visible and combatants.size() == 4, "Replay button must start a fresh round")
	print("QA_SMOKE_OK health=100 base_damage=24 powered_damage=72 toilets=3 chairs=sittable replay=visible")
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
		assert(collisions.is_empty(), "%s doorway must fit the player capsule" % doorway_name)
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
		light.position = light_data[0]
		light.light_color = light_data[1]
		light.light_energy = 0.62
		light.omni_range = 4.2
		light.shadow_enabled = true
		add_child(light)


func _build_apartment() -> void:
	_create_box("Floor", Vector3(4.95, -0.08, 5.65), Vector3(10.15, 0.16, 11.55), floor_material, true)
	_create_floorplan_overlay()
	_create_box("Ceiling", Vector3(4.95, WALL_HEIGHT + 0.06, 5.65), Vector3(10.15, 0.12, 11.55), _material(Color("d5d1d8"), 0.95), false)

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
	plane_mesh.size = Vector2(10.38, 11.78)
	var overlay := MeshInstance3D.new()
	overlay.name = "FloorplanOverlay"
	overlay.mesh = plane_mesh
	overlay.material_override = material
	overlay.position = Vector3(4.95, 0.012, 5.65)
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
	_create_window(Vector3(1.72, 1.48, 0.08), 0.0, 1.0, Vector3(0.0, 0.0, 1.0))
	_create_window(Vector3(6.75, 1.48, 0.32), 0.0, 0.92, Vector3(0.0, 0.0, 1.0))
	_create_window(Vector3(9.05, 1.48, 1.45), 0.0, 0.72, Vector3(0.0, 0.0, 1.0))
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
	spot.spot_range = 5.2
	spot.spot_angle = 38.0
	spot.shadow_enabled = false
	add_child(spot)
	spot.look_at(position + inward * 3.0 + Vector3.DOWN * 1.45, Vector3.UP)

	var beam_material := StandardMaterial3D.new()
	beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.albedo_color = Color(1.0, 0.76, 0.26, 0.16)
	var beam := _create_box("Sunbeam", position + inward * 1.45 + Vector3(0.0, -1.445, 0.0), Vector3(width * 0.9, 0.018, 2.9), beam_material, false)
	beam.rotation.y = rotation_y


func _create_fake_foyer_door() -> void:
	var door := Node3D.new()
	door.name = "FakeOutsideDoor"
	door.position = Vector3(9.18, 0.0, 8.61)
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
	_create_box("Dresser", Vector3(0.45, 0.45, 3.95), Vector3(0.55, 0.9, 1.45), wood_material, true)

	# Center bedroom.
	_create_bed(Vector3(3.15, 0.0, 7.85), PI * 0.5, Color("8c586e"))
	_create_box("Nightstand", Vector3(4.45, 0.36, 7.25), Vector3(0.55, 0.72, 0.55), wood_material, true)

	# Living room sofa, coffee table, and television.
	_create_sofa(Vector3(8.2, 0.0, 3.65), PI * 0.5, Color("43a88d"))
	var coffee_table := _create_box("CoffeeTable", Vector3(6.85, 0.31, 3.65), Vector3(1.35, 0.12, 0.72), wood_material, true)
	coffee_table.rotation.y = PI * 0.5
	_create_tv(Vector3(5.28, 1.48, 3.65), PI)

	# Dining area.
	_create_box("DiningTable", Vector3(6.75, 0.77, 1.35), Vector3(1.7, 0.12, 0.9), wood_material, true)
	for chair_data in [
		[Vector3(5.62, 0.0, 1.35), -PI * 0.5, Color("f07892")],
		[Vector3(7.88, 0.0, 1.35), PI * 0.5, Color("62b8e8")],
		[Vector3(6.75, 0.0, 0.52), PI, Color("f1c75b")],
		[Vector3(6.75, 0.0, 2.18), 0.0, Color("9d79dc")]
	]:
		_create_chair(chair_data[0], chair_data[1], chair_data[2])

	# Kitchen counters and island.
	_create_box("KitchenCounter", Vector3(6.25, 0.48, 8.35), Vector3(2.25, 0.96, 0.58), white_material, true)
	_create_box("KitchenCounter", Vector3(5.35, 0.48, 7.65), Vector3(0.58, 0.96, 1.25), white_material, true)
	_create_box("KitchenIsland", Vector3(6.4, 0.48, 6.75), Vector3(1.55, 0.96, 0.68), _material(Color("d8d1c2"), 0.45), true)

	# Bathroom sinks and tubs to make all three rooms recognizable.
	_create_box("Vanity", Vector3(4.15, 0.46, 4.04), Vector3(0.65, 0.92, 0.42), white_material, true)
	_create_box("Vanity", Vector3(0.55, 0.46, 8.25), Vector3(0.65, 0.92, 1.15), white_material, true)
	_create_box("Tub", Vector3(2.0, 0.35, 10.45), Vector3(1.25, 0.7, 0.68), white_material, true)
	_create_box("Vanity", Vector3(4.35, 0.46, 10.82), Vector3(0.7, 0.92, 0.42), white_material, true)


func _build_toilets() -> void:
	_create_toilet(1, Vector3(4.58, 0.0, 4.25), PI)
	_create_toilet(2, Vector3(0.72, 0.0, 9.52), -PI * 0.5)
	_create_toilet(3, Vector3(4.32, 0.0, 10.42), PI * 0.5)


func _create_toilet(id: int, position: Vector3, rotation_y: float) -> void:
	var toilet := ToiletScript.new() as FlushableToilet
	toilet.setup(id, white_material)
	toilet.position = position
	toilet.rotation.y = rotation_y
	add_child(toilet)


func _start_round() -> void:
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

	spawn_positions = [
		Vector3(1.35, 0.05, 3.55), Vector3(2.5, 0.05, 1.7),
		Vector3(7.4, 0.05, 2.55), Vector3(8.6, 0.05, 4.8),
		Vector3(3.55, 0.05, 7.3), Vector3(2.85, 0.05, 8.8),
		Vector3(6.3, 0.05, 7.55), Vector3(8.7, 0.05, 7.4)
	]
	spawn_positions.shuffle()

	player = PlayerScript.new() as FpsPlayer
	player.game = self
	player.position = spawn_positions.pop_back()
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
		bot.position = spawn_positions.pop_back()
		bot.died.connect(_on_combatant_died)
		add_child(bot)
		combatants.append(bot)

	ui_health.text = "HEALTH  100"
	ui_toilets.text = "TOILETS  0 / 3    DAMAGE  24"
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


func _on_combatant_died(_combatant: Node) -> void:
	await get_tree().create_timer(0.15).timeout
	var alive: Array[Node] = []
	for combatant in combatants:
		if is_instance_valid(combatant) and combatant.get("is_alive"):
			alive.append(combatant)
	if alive.size() <= 1:
		round_over = true
		var winner := "Nobody"
		if alive.size() == 1:
			winner = alive[0].combatant_name()
		ui_status.text = "%s WINS!" % winner.to_upper()
		ui_status.visible = true
		replay_button.visible = true
		_show_banner("ROUND OVER", 3.5)
		if player:
			player.input_enabled = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_player_health_changed(current: int, _maximum: int) -> void:
	ui_health.text = "HEALTH  %d" % current
	ui_health.modulate = Color("ff6565") if current <= 30 else Color.WHITE


func _on_toilet_progress(current: int, total: int) -> void:
	ui_toilets.text = "TOILETS  %d / %d    DAMAGE  %d" % [current, total, 72 if current == total else 24]
	_show_banner("TOILET FLUSHED  %d / %d" % [current, total], 1.4)


func _on_powerup_activated() -> void:
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
	panel.position = Vector2(365, 116)
	panel.size = Vector2(550, 488)
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
	content.add_theme_constant_override("separation", 18)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 52
	content.offset_top = 46
	content.offset_right = -52
	content.offset_bottom = -42
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
	spacer.custom_minimum_size.y = 24
	content.add_child(spacer)

	var single_player := _menu_button("SINGLE PLAYER")
	single_player.pressed.connect(_on_single_player_pressed)
	content.add_child(single_player)

	var multiplayer := _menu_button("MULTIPLAYER  —  COMING NEXT")
	multiplayer.disabled = true
	multiplayer.tooltip_text = "Direct-IP multiplayer will be enabled in the next milestone."
	content.add_child(multiplayer)

	var note := Label.new()
	note.text = "Flush all three toilets to unlock triple damage."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color("c8bdd0"))
	content.add_child(note)


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
	hud_root.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_single_player_pressed() -> void:
	_start_round()


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
		Vector3(4.45, 0.05, 4.35), Vector3(5.35, 0.05, 5.45), Vector3(7.4, 0.05, 4.2),
		Vector3(6.6, 0.05, 1.35), Vector3(6.35, 0.05, 7.35), Vector3(8.65, 0.05, 7.4),
		Vector3(4.1, 0.05, 6.45), Vector3(3.2, 0.05, 7.8), Vector3(1.05, 0.05, 5.35),
		Vector3(1.05, 0.05, 6.9), Vector3(1.05, 0.05, 8.3), Vector3(4.15, 0.05, 9.75),
		Vector3(3.65, 0.05, 10.55)
	]
	for index in points.size():
		nav_graph.add_point(index, points[index])
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
	bed.position = position
	bed.rotation.y = rotation_y
	add_child(bed)
	_create_child_box(bed, Vector3(0, 0.26, 0), Vector3(1.45, 0.3, 2.05), wood_material)
	_create_child_box(bed, Vector3(0, 0.47, -0.08), Vector3(1.34, 0.24, 1.72), _material(blanket_color, 0.9))
	_create_child_box(bed, Vector3(0, 0.73, -0.76), Vector3(1.18, 0.16, 0.42), white_material)


func _create_sofa(position: Vector3, rotation_y: float, color: Color) -> void:
	var sofa := Node3D.new()
	sofa.position = position
	sofa.rotation.y = rotation_y
	add_child(sofa)
	var material := _material(color, 0.95)
	_create_child_box(sofa, Vector3(0, 0.34, 0), Vector3(2.25, 0.48, 0.82), material)
	_create_child_box(sofa, Vector3(0, 0.83, 0.33), Vector3(2.25, 0.64, 0.22), material)
	_create_child_box(sofa, Vector3(-1.03, 0.63, 0), Vector3(0.2, 0.55, 0.82), material)
	_create_child_box(sofa, Vector3(1.03, 0.63, 0), Vector3(0.2, 0.55, 0.82), material)


func _create_chair(position: Vector3, rotation_y: float, color: Color) -> void:
	var chair := ChairScript.new() as SittableChair
	chair.setup(_material(color, 0.78))
	chair.position = position
	chair.rotation.y = rotation_y
	add_child(chair)


func _create_tv(position: Vector3, rotation_y: float) -> void:
	var tv := Node3D.new()
	tv.position = position
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
