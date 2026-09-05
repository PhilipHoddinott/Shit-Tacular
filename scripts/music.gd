extends AudioStreamPlayer
## Persistent background soundtrack; M toggles music without muting game effects.

func _ready() -> void:
	var track := preload("res://assets/music/flush_funk.wav").duplicate() as AudioStreamWAV
	track.loop_mode = AudioStreamWAV.LOOP_FORWARD
	track.loop_begin = 0
	track.loop_end = int(track.get_length() * track.mix_rate)
	stream = track
	volume_db = -20.0
	play()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		stream_paused = not stream_paused
