extends SceneTree

# Produces GitHub's recommended 1280x640 social-preview size while preserving
# the full-resolution generated PNG beside it as the editable source.
func _initialize() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path("res://assets/github/social-preview-source.png"))
	if source == null or source.is_empty():
		push_error("Could not load the generated social-preview source")
		quit(1)
		return
	source.resize(1280, 640, Image.INTERPOLATE_LANCZOS)
	var error := source.save_jpg(ProjectSettings.globalize_path("res://assets/github/social-preview.jpg"), 0.88)
	if error != OK:
		push_error("Could not write the optimized GitHub image")
		quit(1)
		return
	print("GITHUB_ART_READY size=1280x640")
	quit()
