extends RefCounted
## Code-native cartoon props. Only the furniture bases affect navigation.

static func build(g: Node3D) -> void:
	for toilet in g.get_toilets():
		var sign := Node3D.new()
		sign.name = "BathroomSign"
		toilet.add_child(sign)
		sign.position = Vector3(0, 1.40, 0.32)
		g._create_child_box(sign, Vector3.ZERO, Vector3(0.94, 0.44, 0.04), g._material(Color("ffc95c"), 0.85), false)
		g._create_child_box(sign, Vector3(0, -0.42, 0.025), Vector3(0.04, 0.42, 0.04), g.dark_material, false)
		var slogans := ["ROYAL FLUSH", "LOOT LOO", "FINAL FRONTIER"]
		label(sign, "%02d  %s\nFLUSH FOR LOOT" % [toilet.toilet_id, slogans[toilet.toilet_id - 1]], Vector3(0, 0, -0.027), PI, 32, Color("30233a"), 0.0025)
		add_wobble(sign)
	# Place compact cabinets inside rooms, away from doors and known spawns.
	var spots: Array[Vector3] = []
	if g.selected_floor_plan == "2nd floor":
		spots = [g.SecondFloor.point(730, 185), g.SecondFloor.point(1140, 690)]
	else:
		spots = [g._expanded(Vector3(2.85, 0, 2.8)), g._expanded(Vector3(7.7, 0, 5.65))]
	for spot in spots:
		var cabinet: Node3D = g._create_box("ComicCabinet", spot + Vector3.UP * 0.56, Vector3(1.0, 1.12, 0.55), g.wood_material, true)
		g._create_child_box(cabinet, Vector3(0, 0, -0.285), Vector3(0.88, 0.94, 0.035), g._material(Color("6aa8af"), 0.8), false)
		g._create_child_box(cabinet, Vector3(0, 0, -0.315), Vector3(0.16, 0.04, 0.04), g.dark_material, false)
		var trophy := Node3D.new()
		cabinet.add_child(trophy)
		trophy.position = Vector3(0, 0.68, 0)
		g._create_child_box(trophy, Vector3.ZERO, Vector3(0.20, 0.22, 0.18), g._material(Color("ffd15c"), 0.32), false)
		label(trophy, "#2", Vector3(0, 0, -0.096), PI, 32, Color("352447"), 0.003)
		add_wobble(trophy)
	# Small posters use the existing framed wall art, without new collision.
	for node in g.get_children():
		if str(node.name).begins_with("CartoonWallArt"):
			label(node, "LIVE. LAUGH.\nFLUSH.", Vector3(0, 0, 0.066), 0, 30, Color("30233a"), 0.003)

static func label(parent: Node3D, text: String, position: Vector3, yaw: float, font_size: int, color: Color, pixel_size: float) -> void:
	var caption := Label3D.new()
	caption.text = text
	caption.font_size = font_size
	caption.pixel_size = pixel_size
	caption.modulate = color
	caption.outline_size = 0
	caption.no_depth_test = false
	caption.position = position
	caption.rotation.y = yaw
	parent.add_child(caption)

static func add_wobble(prop: Node3D) -> void:
	prop.add_to_group("wobble_decor")
	prop.set_meta("rest_rotation", prop.rotation)

static func wobble_near(g: Node3D, position: Vector3, radius: float) -> void:
	for prop in g.get_tree().get_nodes_in_group("wobble_decor"):
		if prop.global_position.distance_to(position) > radius + 2.0:
			continue
		var old: Tween = prop.get_meta("wobble_tween") if prop.has_meta("wobble_tween") else null
		if old and old.is_valid():
			old.kill()
		var rest: Vector3 = prop.get_meta("rest_rotation")
		var tween := prop.create_tween()
		prop.set_meta("wobble_tween", tween)
		tween.tween_property(prop, "rotation", rest + Vector3(0.10, 0, 0.15), 0.09)
		tween.tween_property(prop, "rotation", rest - Vector3(0.05, 0, 0.10), 0.12)
		tween.tween_property(prop, "rotation", rest, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
