extends Node3D

const SPEED := 17.0
const MAX_DISTANCE := 40.0
const BLAST_RADIUS := 2.6
const EFFECT_GROUP := "singleplayer_round_effects"

var game: Node3D
var attacker: Node
var damage := 90
var shot_id := -1
var direction := Vector3.FORWARD
var distance_travelled := 0.0
var smoke_time := 0.0
var sweep: ShapeCast3D
var detonated := false


func setup(game_node: Node3D, shooter: Node, origin: Vector3, forward: Vector3, max_damage: int) -> void:
	game = game_node
	attacker = shooter
	damage = max_damage
	if shooter.get("active_shot_id") != null:
		shot_id = int(shooter.get("active_shot_id"))
	direction = forward.normalized()
	game.add_child(self)
	global_position = origin
	look_at(origin + direction, Vector3.RIGHT if absf(direction.dot(Vector3.UP)) > 0.99 else Vector3.UP)
	add_to_group(EFFECT_GROUP)
	_build_model()
	sweep = ShapeCast3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.085
	sweep.shape = shape
	sweep.collision_mask = 3
	sweep.max_results = 4
	sweep.enabled = false
	if shooter is CollisionObject3D:
		sweep.add_exception(shooter)
	add_child(sweep)


func _physics_process(delta: float) -> void:
	if detonated:
		return
	if not is_instance_valid(game) or game.round_over or not is_instance_valid(attacker):
		queue_free()
		return
	var travel := minf(SPEED * delta, MAX_DISTANCE - distance_travelled)
	# Sweep the entire movement segment: even thin walls block a fast rocket.
	sweep.target_position = Vector3(0.0, 0.0, -travel)
	sweep.force_shapecast_update()
	if sweep.is_colliding():
		var collider := sweep.get_collider(0)
		var point := sweep.get_collision_point(0)
		var normal := sweep.get_collision_normal(0)
		_detonate(point, collider if collider is Node else null, normal)
		return
	global_position += direction * travel
	distance_travelled += travel
	smoke_time -= delta
	if smoke_time <= 0.0:
		smoke_time = 0.045
		_spawn_smoke()
	if distance_travelled >= MAX_DISTANCE:
		_detonate(global_position, null, -direction)


func _detonate(point: Vector3, direct_hit: Node, normal: Vector3) -> void:
	if detonated:
		return
	detonated = true
	game.spawn_explosion(point, attacker, BLAST_RADIUS, damage, direct_hit, normal, shot_id)
	queue_free()


func _build_model() -> void:
	var body := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.075
	cylinder.bottom_radius = 0.075
	cylinder.height = 0.34
	cylinder.radial_segments = 8
	body.mesh = cylinder
	body.rotation.x = PI / 2.0
	body.material_override = _material(Color("f8d940"))
	add_child(body)
	var nose := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.08
	cone.height = 0.16
	cone.radial_segments = 8
	nose.mesh = cone
	nose.rotation.x = -PI / 2.0
	nose.position.z = -0.22
	nose.material_override = _material(Color("ea4b50"))
	add_child(nose)
	for index in 4:
		var fin := MeshInstance3D.new()
		var fin_mesh := BoxMesh.new()
		fin_mesh.size = Vector3(0.22, 0.025, 0.13)
		fin.mesh = fin_mesh
		fin.position.z = 0.13
		fin.rotation.z = float(index) * PI / 2.0
		fin.material_override = _material(Color("5d405f"))
		add_child(fin)
	var flame := MeshInstance3D.new()
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.075
	flame_mesh.height = 0.15
	flame.mesh = flame_mesh
	flame.position.z = 0.26
	flame.scale.z = 2.2
	var fire := _material(Color("ffad32"))
	fire.emission_enabled = true
	fire.emission = Color("ff841f")
	fire.emission_energy_multiplier = 2.0
	flame.material_override = fire
	add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color("ffb353")
	light.light_energy = 1.3
	light.omni_range = 2.0
	add_child(light)


func _spawn_smoke() -> void:
	var puff := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.07
	mesh.height = 0.14
	mesh.radial_segments = 8
	mesh.rings = 4
	puff.mesh = mesh
	var material := _material(Color(0.76, 0.73, 0.82, 0.65))
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff.material_override = material
	game.add_child(puff)
	puff.global_position = global_position - direction * 0.25
	puff.add_to_group(EFFECT_GROUP)
	var tween := puff.create_tween().set_parallel(true)
	tween.tween_property(puff, "scale", Vector3.ONE * 3.2, 0.5)
	tween.tween_property(puff, "position:y", puff.position.y + 0.3, 0.5)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.5)
	tween.chain().tween_callback(puff.queue_free)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	return material
