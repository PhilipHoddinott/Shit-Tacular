extends Node3D
## A small separate render pass keeps the hands clear of apartment walls.
const MODEL = preload("res://assets/models/pistol_viewmodel.glb")
var player: FpsPlayer
var viewport: SubViewport
var overlay: CanvasLayer
var view_camera: Camera3D
var pivot: Node3D
var slide: Node3D
var slide_rest := Vector3.ZERO
var equip_time := 0.22
var flash: OmniLight3D

func _ready() -> void:
	viewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	view_camera = Camera3D.new()
	view_camera.near = 0.01
	view_camera.far = 5.0
	view_camera.current = true
	viewport.add_child(view_camera)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c4d9ee")
	env.ambient_light_energy = 0.65
	environment.environment = env
	viewport.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -35, 0)
	key.light_color = Color("fff0d9")
	key.light_energy = 1.0
	viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(10, 145, 0)
	fill.light_color = Color("b8d8f4")
	fill.light_energy = 0.5
	viewport.add_child(fill)
	pivot = Node3D.new()
	viewport.add_child(pivot)
	var model := MODEL.instantiate() as Node3D
	pivot.add_child(model)
	slide = model.find_child("Slide", true, false) as Node3D
	if slide:
		slide_rest = slide.position
	flash = OmniLight3D.new()
	flash.position = Vector3(0, 0.035, -0.627)
	flash.light_color = Color("ffc365")
	flash.omni_range = 1.0
	pivot.add_child(flash)
	overlay = CanvasLayer.new()
	overlay.layer = 5
	add_child(overlay)
	var display := TextureRect.new()
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.texture = viewport.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.add_child(display)
	_update_pose(0)

func _process(delta: float) -> void:
	_update_pose(delta)

func _update_pose(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var showing := is_visible_in_tree() and player.camera.current and player.is_alive and player.current_weapon == FpsPlayer.WEAPON_PISTOL
	overlay.visible = showing
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if showing else SubViewport.UPDATE_DISABLED
	if not showing:
		return
	var resolution := Vector2i(get_viewport().get_visible_rect().size)
	if viewport.size != resolution:
		viewport.size = resolution
	view_camera.fov = player.camera.fov
	pivot.transform = player.weapon_root.transform
	equip_time = maxf(0.0, equip_time - delta)
	pivot.position.y -= 0.16 * pow(equip_time / 0.22, 2)
	pivot.rotation.z += 0.15 * equip_time / 0.22
	if slide:
		# Convert a Godot-space slide motion into its imported parent space.
		var motion := pivot.global_basis * Vector3(0, 0, player.recoil * 0.48)
		slide.position = slide_rest + slide.get_parent().global_basis.inverse() * motion
	flash.light_energy = player.muzzle_flash.light_energy * 0.65
