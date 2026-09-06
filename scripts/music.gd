extends AudioStreamPlayer
## Persistent background soundtrack; M toggles music without muting game effects.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bus = "Music"
	var track := preload("res://assets/music/flush_funk.wav").duplicate() as AudioStreamWAV
	track.loop_mode = AudioStreamWAV.LOOP_FORWARD
	track.loop_begin = 0
	track.loop_end = int(track.get_length() * track.mix_rate)
	stream = track
	volume_db = -20.0
	play()
	Settings.changed.connect(_apply_settings)
	_apply_settings()


func _apply_settings() -> void:
	stream_paused = not Settings.music_enabled


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		Settings.set_music_enabled(not Settings.music_enabled)
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	stop()
	stream = null
