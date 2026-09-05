extends Node
## Original synthesized effects, cached once; no downloaded audio assets.
const SAMPLE_RATE := 22050
const MAX_VOICES := 24
var streams: Dictionary = {}

func stop_all() -> void:
	for voice in get_children():
		voice.stop()
		voice.queue_free()

func _exit_tree() -> void:
	for voice in get_children():
		voice.stop()

func _ready() -> void:
	for effect in ["pistol", "shotgun", "rifle", "rainbow_rifle", "bazooka", "impact", "explosion", "flush", "equip", "powerup", "hurt"]:
		streams[effect] = _synthesize(effect)

func play_effect(effect: String, location: Vector3) -> void:
	if not streams.has(effect) or get_child_count() >= MAX_VOICES:
		return
	var voice := AudioStreamPlayer3D.new()
	voice.stream = streams[effect]
	voice.volume_db = -12.0 if effect == "impact" else -6.0
	voice.unit_size = 4.0
	voice.max_distance = 35.0
	add_child(voice)
	voice.global_position = location
	voice.finished.connect(voice.queue_free)
	voice.play()

func _synthesize(effect: String) -> AudioStreamWAV:
	var duration := 0.24
	match effect:
		"shotgun": duration = 0.48
		"rifle", "rainbow_rifle": duration = 0.15
		"bazooka": duration = 0.65
		"explosion": duration = 1.0
		"flush": duration = 1.8
		"powerup": duration = 0.8
		"impact", "equip", "hurt": duration = 0.12
	var samples := int(duration * SAMPLE_RATE)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	var noise_rng := RandomNumberGenerator.new()
	noise_rng.seed = 8128
	var low_noise := 0.0
	var phase := 0.0
	for index in range(samples):
		var t := float(index) / SAMPLE_RATE
		var progress := t / duration
		var noise := noise_rng.randf_range(-1.0, 1.0)
		low_noise = lerpf(low_noise, noise, 0.14)
		var value := 0.0
		var envelope := exp(-progress * 7.0) * minf(t * 1200.0, 1.0) * minf((duration - t) * 100.0, 1.0)
		match effect:
			"flush":
				value = (low_noise * 1.5 + sin(TAU * (95.0 * t - 15.0 * t * t)) * 0.10) * sin(PI * progress) * (0.8 + 0.2 * sin(t * 28.0))
			"powerup":
				var note := mini(3, int(progress * 4.0))
				phase += TAU * [440.0, 554.37, 659.25, 880.0][note] / SAMPLE_RATE
				value = sin(phase) * 0.35 * sin(PI * fmod(progress * 4.0, 1.0))
			"equip": value = (noise * 0.35 + sin(t * TAU * 1300.0) * 0.2) * envelope
			"hurt": value = (sin(t * TAU * 120.0) * 0.4 + low_noise) * envelope
			"impact": value = noise * envelope * 0.5
			"explosion", "bazooka": value = (low_noise * 2.0 + sin(t * TAU * 52.0) * 0.3) * envelope
			_:
				var frequency := 100.0 if effect == "shotgun" else 180.0
				value = (noise * 0.5 + sin(TAU * frequency * t) * 0.3 + low_noise * 0.5) * envelope
		var pcm := int(clampf(value, -0.95, 0.95) * 32767.0)
		bytes.encode_s16(index * 2, pcm)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = bytes
	return stream
