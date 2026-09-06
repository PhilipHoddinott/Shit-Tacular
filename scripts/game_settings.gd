extends Node
## User preferences live outside the project and apply immediately.

signal changed

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULTS := {
	"sensitivity": 1.0,
	"fov": 78.0,
	"music_volume": 1.0,
	"sfx_volume": 1.0,
	"music_enabled": true,
	"floorplan_floor": true,
}

var sensitivity := 1.0
var fov := 78.0
var music_volume := 1.0
var sfx_volume := 1.0
var music_enabled := true
var floorplan_floor := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_audio_bus("Music")
	_ensure_audio_bus("SFX")
	load_settings()


func snapshot() -> Dictionary:
	return {
		"sensitivity": sensitivity,
		"fov": fov,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"music_enabled": music_enabled,
		"floorplan_floor": floorplan_floor,
	}


func apply_values(values: Dictionary, persist: bool = true) -> void:
	sensitivity = _safe_number(values.get("sensitivity", sensitivity), 1.0, 0.25, 3.0)
	fov = _safe_number(values.get("fov", fov), 78.0, 60.0, 110.0)
	music_volume = _safe_number(values.get("music_volume", music_volume), 1.0, 0.0, 1.0)
	sfx_volume = _safe_number(values.get("sfx_volume", sfx_volume), 1.0, 0.0, 1.0)
	if values.get("music_enabled", music_enabled) is bool:
		music_enabled = values.get("music_enabled", music_enabled)
	if values.get("floorplan_floor", floorplan_floor) is bool:
		floorplan_floor = values.get("floorplan_floor", floorplan_floor)
	_apply_audio()
	changed.emit()
	if persist:
		save_settings()


func set_sensitivity(value: float) -> void:
	apply_values({"sensitivity": value})


func set_fov(value: float) -> void:
	apply_values({"fov": value})


func set_music_volume(value: float) -> void:
	apply_values({"music_volume": value})


func set_sfx_volume(value: float) -> void:
	apply_values({"sfx_volume": value})


func set_music_enabled(value: bool) -> void:
	apply_values({"music_enabled": value})


func set_floorplan_floor(value: bool) -> void:
	apply_values({"floorplan_floor": value})


func reset_defaults() -> void:
	apply_values(DEFAULTS)


func load_settings() -> void:
	var config := ConfigFile.new()
	var values := DEFAULTS.duplicate()
	if config.load(SETTINGS_PATH) == OK:
		for key in DEFAULTS:
			values[key] = config.get_value("preferences", key, DEFAULTS[key])
	apply_values(values, false)


func save_settings() -> void:
	var config := ConfigFile.new()
	for key in snapshot():
		config.set_value("preferences", key, get(key))
	var result := config.save(SETTINGS_PATH)
	if result != OK:
		push_warning("Could not save game settings: %s" % error_string(result))


func _safe_number(value: Variant, fallback: float, minimum: float, maximum: float) -> float:
	if not (value is float or value is int) or not is_finite(float(value)):
		return fallback
	return clampf(float(value), minimum, maximum)


func _ensure_audio_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")


func _apply_audio() -> void:
	for bus_name in ["Music", "SFX"]:
		var index := AudioServer.get_bus_index(bus_name)
		if index < 0:
			continue
		var level: float = music_volume if bus_name == "Music" else sfx_volume
		AudioServer.set_bus_mute(index, level <= 0.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, 0.0001)))
