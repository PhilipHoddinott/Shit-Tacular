class_name FlushableToilet
extends StaticBody3D

var toilet_id: int = 0
var water_material: StandardMaterial3D
var handle: MeshInstance3D
var _animation_time := 0.0


func setup(id: int, porcelain_material: StandardMaterial3D) -> void:
	toilet_id = id
	name = "Toilet_%d" % id
	collision_layer = 5
	collision_mask = 0

	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(0.48, 0.42, 0.62)
	base.mesh = base_mesh
	base.position = Vector3(0.0, 0.28, 0.02)
	base.material_override = porcelain_material
	add_child(base)

	var tank := MeshInstance3D.new()
	var tank_mesh := BoxMesh.new()
	tank_mesh.size = Vector3(0.5, 0.58, 0.22)
	tank.mesh = tank_mesh
	tank.position = Vector3(0.0, 0.55, 0.32)
	tank.material_override = porcelain_material
	add_child(tank)

	var bowl := MeshInstance3D.new()
	var bowl_mesh := CylinderMesh.new()
	bowl_mesh.top_radius = 0.28
	bowl_mesh.bottom_radius = 0.22
	bowl_mesh.height = 0.22
	bowl.mesh = bowl_mesh
	bowl.position = Vector3(0.0, 0.51, -0.15)
	bowl.scale = Vector3(1.0, 1.0, 1.25)
	bowl.material_override = porcelain_material
	add_child(bowl)

	var water := MeshInstance3D.new()
	var water_mesh := CylinderMesh.new()
	water_mesh.top_radius = 0.19
	water_mesh.bottom_radius = 0.19
	water_mesh.height = 0.015
	water.mesh = water_mesh
	water.position = Vector3(0.0, 0.63, -0.16)
	water.scale = Vector3(1.0, 1.0, 1.25)
	water_material = StandardMaterial3D.new()
	water_material.albedo_color = Color("4aa9d8")
	water_material.metallic = 0.1
	water_material.roughness = 0.18
	water.material_override = water_material
	add_child(water)

	handle = MeshInstance3D.new()
	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.13, 0.05, 0.04)
	handle.mesh = handle_mesh
	handle.position = Vector3(0.2, 0.62, 0.19)
	var handle_material := StandardMaterial3D.new()
	handle_material.albedo_color = Color("b7bcc4")
	handle_material.metallic = 0.85
	handle_material.roughness = 0.2
	handle.material_override = handle_material
	add_child(handle)

	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.55, 0.85, 0.8)
	collider.shape = shape
	collider.position = Vector3(0.0, 0.43, 0.0)
	add_child(collider)


func interact(player: Node) -> void:
	if _animation_time <= 0.0 and player.get("game"):
		player.game.emit_world_sound("flush", global_position)
	if player.has_method("register_toilet_flush"):
		player.register_toilet_flush(toilet_id)
	_animation_time = 0.75
	water_material.albedo_color = Color("d8f7ff")


func interaction_text(player: Node) -> String:
	if player.has_method("has_flushed_toilet") and player.has_flushed_toilet(toilet_id):
		return "Already flushed"
	return "Press E to flush"


func _process(delta: float) -> void:
	if _animation_time <= 0.0:
		return
	_animation_time -= delta
	var phase := (0.75 - _animation_time) * 12.0
	handle.rotation.z = sin(phase) * 0.25
	water_material.albedo_color = Color("d8f7ff").lerp(Color("4aa9d8"), 1.0 - maxf(_animation_time, 0.0) / 0.75)
	if _animation_time <= 0.0:
		handle.rotation.z = 0.0
