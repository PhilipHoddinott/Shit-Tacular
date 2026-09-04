extends SceneTree

# Converts the supplied source (which arrived as WebP data) into a real PNG and
# crops a texture aligned to the pixel coordinates used by the level builder.
func _initialize() -> void:
	var source_path := ProjectSettings.globalize_path("res://apt_floorplan.webp")
	var source := Image.load_from_file(source_path)
	if source == null or source.is_empty():
		push_error("Could not load the apartment floor plan")
		quit(1)
		return

	var assets_path := ProjectSettings.globalize_path("res://assets")
	DirAccess.make_dir_recursive_absolute(assets_path)
	var png_error := source.save_png(ProjectSettings.globalize_path("res://apt_floorplan.png"))
	if png_error != OK:
		push_error("Could not write apt_floorplan.png")
		quit(1)
		return

	# A 12-pixel border keeps the outside edges visible. At PLAN_SCALE=0.02,
	# this crop maps to x=-0.24..10.14 and z=-0.24..11.54 in the 3D level.
	var floor_texture := source.get_region(Rect2i(236, 2, 519, 589))
	var crop_error := floor_texture.save_png(ProjectSettings.globalize_path("res://assets/floorplan_floor.png"))
	if crop_error != OK:
		push_error("Could not write the cropped floor texture")
		quit(1)
		return

	print("FLOORPLAN_READY png=930x680 crop=519x589")
	quit()
