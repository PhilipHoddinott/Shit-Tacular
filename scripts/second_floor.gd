extends RefCounted
## Traced from otherApartmentFloorPlan.jpg. Pixels remain the source of truth.
const SCALE := 0.025
static func point(x: float, y: float) -> Vector3:
	return Vector3((x - 90.0) * SCALE, 0, (y - 87.0) * SCALE)

static func prop(x: float, y: float, height: float = 0.0) -> Vector3:
	var p := point(x, y) / 2.0
	p.y = height
	return p

static func spawns() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for p in [Vector2(240, 540), Vector2(375, 745), Vector2(620, 310), Vector2(745, 700), Vector2(1180, 310), Vector2(1270, 440), Vector2(1200, 650), Vector2(940, 530)]:
		result.append(point(p.x, p.y) + Vector3.UP * 0.05)
	return result

static func doorways() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for p in [Vector2(170,370), Vector2(493,425), Vector2(493,645), Vector2(853,440), Vector2(983,395), Vector2(1037,450), Vector2(851,540), Vector2(1045,540), Vector2(851,730), Vector2(1050,760)]:
		result.append(point(p.x, p.y))
	return result

static func build(g: Node3D) -> void:
	g._create_box("Floor", point(757.5,451.5) - Vector3.UP * 0.08, Vector3(1515*SCALE,0.16,903*SCALE), g.floor_material, true)
	var overlay := MeshInstance3D.new()
	overlay.name = "FloorplanOverlay"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(1515,903) * SCALE
	overlay.mesh = mesh
	overlay.position = point(757.5,451.5) + Vector3.UP * 0.012
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://otherApartmentFloorPlan.jpg")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.roughness = 0.95
	overlay.material_override = mat
	g.add_child(overlay)
	g._create_box("Ceiling", point(757.5,451.5) + Vector3.UP * 2.78, Vector3(1515*SCALE,0.12,903*SCALE), g.white_material, false)
	var boundary := [Vector2(90,355),Vector2(112,355),Vector2(112,87),Vector2(338,87),Vector2(338,355),Vector2(501,355),Vector2(501,112),Vector2(853,112),Vector2(853,392),Vector2(866,392),Vector2(866,112),Vector2(1433,112),Vector2(1433,491),Vector2(1348,491),Vector2(1348,842),Vector2(90,842),Vector2(90,355)]
	for i in range(boundary.size()-1):
		g._create_wall(point(boundary[i].x,boundary[i].y),point(boundary[i+1].x,boundary[i+1].y),0.24,2.72,0.0,g.living_wall_material)
	for segment in [
		[210,370,501,370], [493,462,493,572], [493,718,493,842],
		[517,486,862,486], [866,395,944,395], [1037,112,1037,422],
		[1037,477,1433,477], [851,580,1045,580], [851,580,851,697],
		[851,697,1045,697], [1045,580,1045,697], [851,770,851,831]
	]:
		g._create_wall(point(segment[0],segment[1]),point(segment[2],segment[3]),0.24,2.72,0.0,g.hall_wall_material)
	# Seal the lightwell and stair footprints so no player can leave the traced plan.
	g._create_box("Lightwell", point(948,638.5)+Vector3.UP*1.36,Vector3(194*SCALE,2.72,117*SCALE),g.wall_material,true)
	for room in [Vector2(275,590),Vector2(680,300),Vector2(690,650),Vector2(1220,300),Vector2(1210,655),Vector2(953,265),Vector2(220,215),Vector2(950,760),Vector2(950,505)]:
		var light := OmniLight3D.new()
		light.position = point(room.x,room.y)+Vector3.UP*2.4
		light.omni_range = 6.0
		light.light_energy = 0.5
		light.light_color = Color("ffe7ca")
		light.shadow_enabled = true
		g.add_child(light)
		g._create_box("CeilingFixture",point(room.x,room.y)+Vector3.UP*2.66,Vector3(.6,.08,.6),g.white_material,false)
	g._create_sofa(prop(250,640),-PI*.5,Color("429d98"))
	g._create_tv(prop(110,600,1.48),PI)
	g._create_box("CoffeeTable",point(195,635)+Vector3.UP*.31,Vector3(1.2,.12,.65),g.wood_material,true)
	g._create_bed(prop(650,200),0,Color("7d96cb"))
	g._create_bed(prop(1280,215),0,Color("ce839a"))
	g._create_box("DiningTable",point(690,650)+Vector3.UP*.77,Vector3(1.7,.12,.9),g.wood_material,true)
	for chair in [[644,650,-PI*.5],[736,650,PI*.5],[690,616,PI],[690,684,0.0]]:
		g._create_chair(prop(chair[0],chair[1]),chair[2],Color("dcad68"))
	g._create_box("KitchenCounter",point(1270,800)+Vector3.UP*.48,Vector3(2.5,.96,.6),g.white_material,true)
	g._create_box("CartoonFridge",point(1300,535)+Vector3.UP*.95,Vector3(.62,1.9,.72),g.white_material,true)
	g._create_toilet(1,prop(910,190),0)
	g._create_toilet(2,prop(165,160),0)
	g._create_toilet(3,prop(965,806),PI)
	g._create_wall_mirror(prop(956,120,1.52),0,Vector2(.72,.78))
	g._create_plant(prop(1320,410),Color("5dba78"))
	g._create_wall_art(prop(1425,290,1.6),-PI*.5,Color("e3ad67"),Color("718ec8"))
	g._create_display_shelf(prop(570,120,1.55),0)
	# Navigation follows openings, including both routes around the lightwell.
	var nodes := [Vector2(270,600),Vector2(440,425),Vector2(560,425),Vector2(700,310),Vector2(800,440),Vector2(945,440),Vector2(980,340),Vector2(980,460),Vector2(1100,450),Vector2(1230,300),Vector2(945,535),Vector2(790,535),Vector2(690,650),Vector2(440,645),Vector2(1100,535),Vector2(1200,670),Vector2(790,740),Vector2(965,760),Vector2(1100,760),Vector2(165,420),Vector2(165,270)]
	for i in range(nodes.size()):
		g.nav_graph.add_point(i,point(nodes[i].x,nodes[i].y)+Vector3.UP*.05)
	for edge in [[0,1],[1,2],[2,3],[2,4],[4,5],[5,7],[7,6],[7,8],[8,9],[7,10],[10,11],[11,12],[12,13],[13,0],[10,14],[14,15],[12,16],[16,17],[17,18],[18,15],[1,19],[19,20]]:
		g.nav_graph.connect_points(edge[0],edge[1])
