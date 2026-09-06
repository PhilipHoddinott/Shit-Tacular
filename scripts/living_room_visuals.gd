extends RefCounted
## Imported furniture is visual-only: the original apartment colliders stay put.

const SOFA_SCENE: PackedScene = preload("res://assets/models/living_sofa.glb")
const TABLE_SCENE: PackedScene = preload("res://assets/models/living_coffee_table.glb")


static func replace_sofa(sofa: Node3D) -> void:
	if sofa.has_node("BlenderSofaVisual"):
		return
	_hide_meshes(sofa)
	var visual := SOFA_SCENE.instantiate() as Node3D
	visual.name = "BlenderSofaVisual"
	sofa.add_child(visual)
	_contact_shadow(sofa, Vector2(2.25, 0.85), 0.015)


static func replace_coffee_table(table: Node3D, original_size: Vector3) -> void:
	# Call after original legs are built, before adding books/remote on the top.
	if table.has_node("BlenderCoffeeTableVisual"):
		return
	_hide_meshes(table)
	var visual := TABLE_SCENE.instantiate() as Node3D
	visual.name = "BlenderCoffeeTableVisual"
	visual.scale = Vector3(original_size.x / 1.35, 1.0, original_size.z / 0.72)
	table.add_child(visual)
	_contact_shadow(table, Vector2(original_size.x, original_size.z), -table.position.y + 0.015)


static func _hide_meshes(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			child.visible = false
		_hide_meshes(child)


static func _contact_shadow(parent: Node3D, size: Vector2, height: float) -> void:
	var shadow := MeshInstance3D.new()
	shadow.name = "SoftContactShadow"
	var plane := PlaneMesh.new()
	plane.size = size
	shadow.mesh = plane
	shadow.position.y = height
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded, cull_disabled, depth_draw_never; void fragment(){float d=length((UV-vec2(0.5))*2.0); ALBEDO=vec3(0.08,0.055,0.07); ALPHA=0.18*(1.0-smoothstep(0.35,1.0,d));}"
	var material := ShaderMaterial.new()
	material.shader = shader
	shadow.material_override = material
	parent.add_child(shadow)
