extends Node

const LOG_DIRECTORY := "user://logs"
const CURRENT_LOG_NAME := "shit-tacular.log"
const CRASH_MARKERS := [
	"Program crashed",
	"Dumping the backtrace",
	"CrashHandlerException",
	"Unhandled exception"
]

var session_id := ""
var previous_crash_detected := false
var previous_crash_log_path := ""


func _ready() -> void:
	var generator := RandomNumberGenerator.new()
	generator.randomize()
	session_id = "%08x" % generator.randi()
	_find_previous_crash_log()
	log_event("session_started", {
		"app": str(ProjectSettings.get_setting("application/config/name", "Shit-Tacular")),
		"app_version": str(ProjectSettings.get_setting("application/config/version", "unknown")),
		"debug_build": OS.is_debug_build(),
		"godot": str(Engine.get_version_info().get("string", "unknown")),
		"os": OS.get_name(),
		"os_version": OS.get_version(),
		"cpu": OS.get_processor_name(),
		"cpu_threads": OS.get_processor_count(),
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown")),
		"gpu": RenderingServer.get_video_adapter_name(),
		"display_server": DisplayServer.get_name(),
		"window_size": "%dx%d" % [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"user_args": OS.get_cmdline_user_args()
	})
	if previous_crash_detected:
		log_warning("previous_crash_detected", {"log": previous_crash_log_path})


func log_event(event_name: String, details: Dictionary = {}) -> void:
	print(_format_line("INFO", event_name, details))


func log_warning(event_name: String, details: Dictionary = {}) -> void:
	printerr(_format_line("WARN", event_name, details))


func log_error(event_name: String, details: Dictionary = {}) -> void:
	push_error(_format_line("ERROR", event_name, details))


func get_log_directory() -> String:
	return ProjectSettings.globalize_path(LOG_DIRECTORY)


func get_current_log_path() -> String:
	return ProjectSettings.globalize_path(LOG_DIRECTORY.path_join(CURRENT_LOG_NAME))


func open_log_folder() -> Error:
	var directory := get_log_directory()
	var make_error := DirAccess.make_dir_recursive_absolute(directory)
	if make_error != OK and make_error != ERR_ALREADY_EXISTS:
		log_error("log_directory_create_failed", {"error": error_string(make_error), "path": directory})
		return make_error
	var open_error := OS.shell_open(directory)
	if open_error != OK:
		DisplayServer.clipboard_set(directory)
		log_error("log_directory_open_failed", {"error": error_string(open_error), "path": directory})
		return open_error
	log_event("log_directory_opened", {"path": directory})
	return OK


func _format_line(level: String, event_name: String, details: Dictionary) -> String:
	var timestamp := Time.get_datetime_string_from_system(false, true)
	var suffix := "" if details.is_empty() else " " + JSON.stringify(details)
	return "[SHIT-TACULAR][%s][%s][%s] %s%s" % [level, session_id, timestamp, event_name, suffix]


func _find_previous_crash_log() -> void:
	var files := DirAccess.get_files_at(LOG_DIRECTORY)
	if files.is_empty():
		return
	var rotated_logs: Array[String] = []
	for file_name in files:
		if file_name != CURRENT_LOG_NAME and file_name.begins_with(CURRENT_LOG_NAME.get_basename()) and file_name.ends_with(".log"):
			rotated_logs.append(file_name)
	if rotated_logs.is_empty():
		return
	rotated_logs.sort()
	var file_path := LOG_DIRECTORY.path_join(rotated_logs[-1])
	var contents := FileAccess.get_file_as_string(file_path)
	for marker in CRASH_MARKERS:
		if contents.contains(marker):
			previous_crash_detected = true
			previous_crash_log_path = ProjectSettings.globalize_path(file_path)
			return
