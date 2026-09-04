class_name SittableChair
extends StaticBody3D

var occupant: Node


func setup(chair_material: StandardMaterial3D) -> void:
	add_to_group("sittable_chairs")
	collision_layer = 5
	collision_mask = 0

	var seat := MeshInstance3D.new()
	var seat_mesh := BoxMesh.new()
	seat_mesh.size = Vector3(0.5, 0.12, 0.5)
	seat.mesh = seat_mesh
	seat.position.y = 0.47
	seat.material_override = chair_material
	add_child(seat)

	var back := MeshInstance3D.new()
	var back_mesh := BoxMesh.new()
	back_mesh.size = Vector3(0.5, 0.66, 0.11)
	back.mesh = back_mesh
	back.position = Vector3(0.0, 0.78, 0.2)
	back.material_override = chair_material
	add_child(back)

	for leg_position in [
		Vector3(-0.19, 0.22, -0.19), Vector3(0.19, 0.22, -0.19),
		Vector3(-0.19, 0.22, 0.19), Vector3(0.19, 0.22, 0.19)
	]:
		var leg := MeshInstance3D.new()
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.07, 0.44, 0.07)
		leg.mesh = leg_mesh
		leg.position = leg_position
		leg.material_override = chair_material
		add_child(leg)

	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.52, 1.08, 0.52)
	collider.shape = shape
	collider.position.y = 0.54
	add_child(collider)


func interact(player: Node) -> void:
	if occupant and not is_instance_valid(occupant):
		occupant = null
	if occupant and occupant != player:
		return
	if player.has_method("sit_on"):
		player.sit_on(self)


func interaction_text(player: Node) -> String:
	if occupant and not is_instance_valid(occupant):
		occupant = null
	if occupant and occupant != player:
		return "Seat occupied"
	return "Press E to sit"


func get_sit_position() -> Vector3:
	return to_global(Vector3(0.0, 0.05, 0.0))


func get_stand_position() -> Vector3:
	return to_global(Vector3(0.0, 0.05, -0.88))


func release(player: Node) -> void:
	if occupant == player:
		occupant = null
