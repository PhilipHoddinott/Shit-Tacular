extends Control
## Uses the rendered floor's texture and bounds for exact marker alignment.
var game: Node3D
var refresh_time := 0.0
var map_rect := Rect2()
var world_bounds := Rect2()
var floor_texture: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = 24
	offset_right = 284
	offset_top = -324
	offset_bottom = -92

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	refresh_time -= delta
	if refresh_time <= 0.0:
		refresh_time = 0.05
		refresh_map()
		queue_redraw()

func refresh_map() -> void:
	var overlay := game.get_node_or_null("FloorplanOverlay") as MeshInstance3D
	if not overlay:
		floor_texture = null
		return
	var plane := overlay.mesh as PlaneMesh
	var material := overlay.material_override as StandardMaterial3D
	if not plane or not material:
		return
	floor_texture = material.albedo_texture
	world_bounds = Rect2(Vector2(overlay.position.x,overlay.position.z)-plane.size*.5,plane.size)
	var available := Vector2(size.x-24,size.y-82)
	var scale_factor := minf(available.x/plane.size.x,available.y/plane.size.y)
	var extent := plane.size*scale_factor
	map_rect = Rect2(Vector2((size.x-extent.x)*.5,34+(available.y-extent.y)*.5),extent)

func map_position(position: Vector3) -> Vector2:
	return map_rect.position+(Vector2(position.x,position.z)-world_bounds.position)/world_bounds.size*map_rect.size

func visible_combatants() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for combatant in game.combatants:
		if is_instance_valid(combatant) and combatant.is_alive:
			result.append(combatant)
	return result

func _draw() -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.055,0.04,0.075,0.94)
	panel.border_color = Color("936083")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(10)
	draw_style_box(panel,Rect2(Vector2.ZERO,size))
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(12,23),"MAP · "+game.selected_floor_plan,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("f5def0"))
	if not floor_texture:
		return
	draw_texture_rect(floor_texture,map_rect,false,Color(.8,.8,.85))
	if not game.network_match_started:
		for toilet in game.get_toilets():
			var p := map_position(toilet.global_position)
			var visited: bool = is_instance_valid(game.player) and game.player.has_flushed_toilet(toilet.toilet_id)
			var color := Color("80efa5") if visited else Color("ffdb76")
			draw_style_box(_toilet_marker(color), Rect2(p - Vector2(7, 9), Vector2(14, 18)))
			draw_string(font, p + Vector2(-4, 5), str(toilet.toilet_id), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("17121f"))
	var actors := visible_combatants()
	for actor in actors:
		if actor == game.player:
			continue
		var p := map_position(actor.global_position)
		if map_rect.has_point(p):
			draw_circle(p,6,Color("17121f"))
			draw_circle(p,4,Color("ff657e"))
	if is_instance_valid(game.player) and game.player.is_alive:
		var actor: Node3D = game.player
		var p := map_position(actor.global_position)
		var forward := -actor.global_basis.z
		var direction := Vector2(forward.x,forward.z).normalized()
		var side := Vector2(-direction.y,direction.x)
		var triangle := PackedVector2Array([p+direction*9,p-direction*5+side*5,p-direction*5-side*5])
		draw_circle(p,8,Color("17121f"))
		draw_colored_polygon(triangle,Color("68eeff"))
	draw_circle(Vector2(16,size.y-16),4,Color("68eeff"))
	draw_string(font,Vector2(27,size.y-11),"You",HORIZONTAL_ALIGNMENT_LEFT,-1,13)
	draw_circle(Vector2(87,size.y-16),4,Color("ff657e"))
	draw_string(font,Vector2(98,size.y-11),"Others · %d" % maxi(0,actors.size()-1),HORIZONTAL_ALIGNMENT_LEFT,-1,13)
	if not game.network_match_started:
		draw_string(font, Vector2(12, size.y-33), "Toilets: gold = loot · green = flushed", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f7e1b9"))


func _toilet_marker(color: Color) -> StyleBoxFlat:
	var marker := StyleBoxFlat.new()
	marker.bg_color = color
	marker.border_color = Color("17121f")
	marker.set_border_width_all(2)
	marker.set_corner_radius_all(4)
	return marker
