extends RefCounted

const Rocket := preload("res://scripts/rocket.gd")
const EFFECT_GROUP := "singleplayer_round_effects"


static func spawn_rocket(game: Node3D, origin: Vector3, direction: Vector3, attacker: Node, max_damage: int) -> Node3D:
	var rocket := Rocket.new()
	rocket.setup(game, attacker, origin, direction, max_damage)
	return rocket


static func explode(game: Node3D, position: Vector3, attacker: Node, radius: float, max_damage: int, direct_hit: Node = null, normal: Vector3 = Vector3.ZERO, shot_id: int = -1) -> void:
	if game.round_over or radius <= 0.0:
		return
	_cartoon_explosion(game, position + normal.normalized() * 0.08, radius)
	# Move the visibility ray just away from the struck surface, never through it.
	var visible_origin := position + normal.normalized() * 0.025
	var recipients: Array = game.combatants.duplicate()
	for combatant in recipients:
		if game.round_over:
			break
		if not is_instance_valid(combatant) or combatant.is_queued_for_deletion() or combatant == attacker or not combatant.get("is_alive"):
			continue
		var center: Vector3 = combatant.global_position + Vector3.UP * 0.75
		var distance := center.distance_to(position)
		var amount := 0
		if combatant == direct_hit:
			amount = max_damage
		elif distance <= radius:
			var query := PhysicsRayQueryParameters3D.create(visible_origin, center, 1)
			query.hit_from_inside = true
			if game.get_world_3d().direct_space_state.intersect_ray(query):
				continue
			amount = roundi(max_damage * clampf(1.0 - distance / radius, 0.28, 1.0))
		if amount > 0:
			_apply_projectile_damage(game, combatant, attacker, amount, shot_id)


static func _apply_projectile_damage(game: Node3D, target: Node, attacker: Node, amount: int, shot_id: int) -> void:
	var old_health := int(target.get("health"))
	var prior_projectile_meta: Variant = game.get_meta("projectile_damage") if game.has_meta("projectile_damage") else null
	game.set_meta("projectile_damage", true)
	target.apply_damage(amount, attacker)
	if prior_projectile_meta == null:
		game.remove_meta("projectile_damage")
	else:
		game.set_meta("projectile_damage", prior_projectile_meta)
	if is_instance_valid(target) and int(target.get("health")) < old_health and game.has_method("record_projectile_hit"):
		game.record_projectile_hit(attacker, shot_id)


static func _cartoon_explosion(game: Node3D, position: Vector3, radius: float) -> void:
	game.emit_world_sound("explosion", position)
	var effect := Node3D.new()
	game.add_child(effect)
	effect.global_position = position
	effect.add_to_group(EFFECT_GROUP)
	for index in 3:
		var blast := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.2
		mesh.height = 0.4
		mesh.radial_segments = 12
		mesh.rings = 6
		blast.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = [Color("f25b39"), Color("ffb82e"), Color("fff199")][index]
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		blast.material_override = material
		blast.position = Vector3(0.14 * float(index - 1), float(index) * 0.09, 0.0)
		effect.add_child(blast)
		var tween := blast.create_tween()
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(blast, "scale", Vector3.ONE * radius * (3.0 - float(index) * 0.6), 0.14)
		tween.tween_property(blast, "scale", Vector3.ZERO, 0.22)
	var caption := Label3D.new()
	caption.text = "KA-POOP!"
	caption.font_size = 82
	caption.outline_size = 18
	caption.modulate = Color("ffe25b")
	caption.outline_modulate = Color("492349")
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	caption.no_depth_test = false
	caption.pixel_size = 0.003
	caption.position.y = 0.3
	effect.add_child(caption)
	var text_tween := caption.create_tween().set_parallel(true)
	text_tween.tween_property(caption, "position:y", 1.0, 0.65)
	text_tween.tween_property(caption, "scale", Vector3.ONE * 1.25, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	text_tween.tween_property(caption, "modulate:a", 0.0, 0.25).set_delay(0.4)
	var cleanup := effect.create_tween()
	cleanup.tween_interval(0.7)
	cleanup.tween_callback(effect.queue_free)
