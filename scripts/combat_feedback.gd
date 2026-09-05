extends Control
var hit_time := 0.0
var damage_time := 0.0
var confirmed_kill := false
var damage_direction := Vector2.UP

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_hit(killed: bool) -> void:
	hit_time = 0.35 if killed else 0.18
	confirmed_kill = killed
	queue_redraw()

func show_damage(direction: Vector2) -> void:
	damage_time = 0.65
	damage_direction = direction.normalized() if direction.length() > 0.01 else Vector2.UP
	queue_redraw()

func _process(delta: float) -> void:
	hit_time = maxf(0.0, hit_time - delta)
	damage_time = maxf(0.0, damage_time - delta)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	if hit_time > 0.0:
		var color := Color("ffd36b") if confirmed_kill else Color.WHITE
		color.a = minf(1.0, hit_time * 10.0)
		for direction in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
			draw_line(center+direction*9,center+direction*17,color,2.5,true)
	if damage_time > 0.0:
		var red := Color(0.9,0.07,0.12,damage_time*0.38)
		draw_rect(Rect2(Vector2.ZERO,size),red,false,18.0)
		var tip := center + damage_direction*92.0
		var side := Vector2(-damage_direction.y,damage_direction.x)*10.0
		draw_colored_polygon(PackedVector2Array([tip,tip-damage_direction*19.0+side,tip-damage_direction*19.0-side]),Color(1,0.15,0.15,minf(1.0,damage_time*3)))
