extends Control
## Single-player-only pause overlay; menus keep processing while the world freezes.

var game: Node
var panel: PanelContainer
var title_label: Label
var subtitle_label: Label
var resume_button: Button
var restart_button: Button
var menu_button: Button
var match_buttons: HBoxContainer
var music_checkbox: CheckBox
var floor_checkbox: CheckBox
var sliders: Dictionary = {}
var value_labels: Dictionary = {}
var _owns_pause := false
var _from_match := false
var _previous_focus: Control
var _previous_input_enabled := true


func _ready() -> void:
	name = "PauseSettings"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_create_panel()
	Settings.changed.connect(_sync_values)
	resized.connect(_fit_panel)
	_fit_panel()
	_sync_values()
	hide()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		if visible:
			get_viewport().set_input_as_handled()
			resume()
		elif _can_pause():
			get_viewport().set_input_as_handled()
			open_pause()


func _can_pause() -> bool:
	return is_instance_valid(game) and not game.network_match_started and not game.round_over \
		and not game.death_menu_pending and is_instance_valid(game.player) \
		and game.player.is_alive and game.hud_root.visible


func is_open() -> bool:
	return visible


func open_pause() -> bool:
	if visible or not _can_pause():
		return false
	_from_match = true
	_owns_pause = true
	_previous_input_enabled = game.player.input_enabled
	game.player.input_enabled = false
	get_tree().paused = true
	_open()
	return true


func open_settings() -> void:
	if visible:
		return
	# This entry is for the main menu. Never pause a connected host or client.
	if is_instance_valid(game) and game.network_match_started:
		return
	if _can_pause():
		open_pause()
		return
	_from_match = false
	_open()


func _open() -> void:
	_previous_focus = get_viewport().gui_get_focus_owner()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	title_label.text = "POTTY BREAK" if _from_match else "SETTINGS"
	subtitle_label.text = "Apartment paused. Even the plumbing can wait." if _from_match else "Make yourself at home. Changes save automatically."
	resume_button.text = "RESUME GAME" if _from_match else "BACK"
	match_buttons.visible = _from_match
	_sync_values()
	show()
	resume_button.grab_focus()


func resume() -> void:
	if not visible:
		return
	var restore_game := _from_match and _can_resume()
	# Buttons activate on release. Clear mapped actions as an extra guard against
	# the resume click, held aiming, or a key repeat leaking into the next frame.
	for action in ["fire", "aim", "interact", "jump", "restart"]:
		Input.action_release(action)
	close_for_transition()
	if restore_game:
		game.player.input_enabled = _previous_input_enabled
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()


func _can_resume() -> bool:
	return is_instance_valid(game) and is_instance_valid(game.player) \
		and game.player.is_alive and not game.round_over and not game.network_match_started


func close_for_transition() -> void:
	hide()
	if _owns_pause:
		get_tree().paused = false
	_owns_pause = false
	_from_match = false


func _restart() -> void:
	close_for_transition()
	if is_instance_valid(game):
		game._start_round.call_deferred()


func _main_menu() -> void:
	close_for_transition()
	if is_instance_valid(game):
		game._show_main_menu.call_deferred()


func _exit_tree() -> void:
	if _owns_pause:
		get_tree().paused = false


func _create_panel() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.035, 0.02, 0.055, 0.86)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("211827")
	style.border_color = Color("ee5ed3")
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	panel.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", Color("ff78df"))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title_label)
	subtitle_label = Label.new()
	subtitle_label.add_theme_font_size_override("font_size", 14)
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_color_override("font_color", Color("d5c6dc"))
	content.add_child(subtitle_label)
	_add_slider(content, "sensitivity", "Mouse sensitivity", 0.25, 3.0, 0.05, Settings.set_sensitivity)
	_add_slider(content, "fov", "Field of view", 60.0, 110.0, 1.0, Settings.set_fov)
	_add_slider(content, "music_volume", "Music volume", 0.0, 1.0, 0.05, Settings.set_music_volume)
	_add_slider(content, "sfx_volume", "Sound effects volume", 0.0, 1.0, 0.05, Settings.set_sfx_volume)
	music_checkbox = CheckBox.new()
	music_checkbox.text = "Music enabled (M to toggle)"
	music_checkbox.toggled.connect(Settings.set_music_enabled)
	content.add_child(music_checkbox)
	floor_checkbox = CheckBox.new()
	floor_checkbox.text = "Floor-plan drawing on floor"
	floor_checkbox.toggled.connect(Settings.set_floorplan_floor)
	content.add_child(floor_checkbox)
	var reset_button := _button("RESET DEFAULTS", Color("5f526d"))
	reset_button.pressed.connect(Settings.reset_defaults)
	content.add_child(reset_button)
	resume_button = _button("RESUME GAME", Color("773667"))
	resume_button.pressed.connect(resume)
	content.add_child(resume_button)
	match_buttons = HBoxContainer.new()
	match_buttons.add_theme_constant_override("separation", 10)
	content.add_child(match_buttons)
	restart_button = _button("RESTART", Color("504061"))
	restart_button.pressed.connect(_restart)
	match_buttons.add_child(restart_button)
	menu_button = _button("MAIN MENU", Color("504061"))
	menu_button.pressed.connect(_main_menu)
	match_buttons.add_child(menu_button)
	var help := Label.new()
	help.text = "ESC BACK  /  TAB SELECT  /  ARROWS ADJUST"
	help.add_theme_font_size_override("font_size", 12)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_color_override("font_color", Color("b6a7c2"))
	content.add_child(help)


func _add_slider(content: VBoxContainer, key: String, label_text: String, minimum: float, maximum: float, step: float, setter: Callable) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 2)
	content.add_child(section)
	var row := HBoxContainer.new()
	section.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var value_label := Label.new()
	value_label.add_theme_color_override("font_color", Color("ffe58b"))
	row.add_child(value_label)
	value_labels[key] = value_label
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.custom_minimum_size.y = 24
	slider.tooltip_text = label_text + " — Left/Right arrows to adjust"
	slider.value_changed.connect(setter)
	section.add_child(slider)
	sliders[key] = slider


func _button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 17)
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.set_corner_radius_all(8)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.15)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = color.darkened(0.12)
	button.add_theme_stylebox_override("pressed", pressed)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("ffe58b")
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(8)
	button.add_theme_stylebox_override("focus", focus)
	return button


func _sync_values() -> void:
	for key in sliders:
		var value: float = Settings.get(key)
		sliders[key].set_value_no_signal(value)
		if key == "sensitivity":
			value_labels[key].text = "%.2fx" % value
		elif key == "fov":
			value_labels[key].text = "%d°" % roundi(value)
		else:
			value_labels[key].text = "%d%%" % roundi(value * 100.0)
	music_checkbox.set_pressed_no_signal(Settings.music_enabled)
	floor_checkbox.set_pressed_no_signal(Settings.floorplan_floor)


func _fit_panel() -> void:
	if not is_instance_valid(panel):
		return
	panel.size = Vector2(minf(580.0, maxf(250.0, size.x - 32.0)), minf(650.0, maxf(250.0, size.y - 32.0)))
	panel.position = (size - panel.size) * 0.5
