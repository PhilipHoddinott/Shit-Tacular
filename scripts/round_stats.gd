extends RefCounted
## Accuracy counts trigger pulls that hurt an opponent, not shotgun pellets.
const SAVE_PATH := "user://singleplayer_records.cfg"

var elapsed := 0.0
var shots := 0
var kills := 0
var successful_shots: Dictionary = {}
var active := false
var record_key := ""
var summary := ""

func start(map_name: String, difficulty: String, bot_lives: int) -> void:
	elapsed = 0.0
	shots = 0
	kills = 0
	successful_shots.clear()
	summary = ""
	record_key = "%s_%s_%d" % [map_name, difficulty, bot_lives]
	active = true

func tick(delta: float) -> void:
	if active:
		elapsed += delta

func record_shot() -> int:
	if not active:
		return -1
	shots += 1
	return shots

func record_hit(shot_id: int) -> void:
	if active and shot_id > 0 and shot_id <= shots:
		successful_shots[shot_id] = true

func accuracy() -> int:
	return roundi(100.0 * successful_shots.size() / shots) if shots > 0 else 0

func clock_text() -> String:
	return "%02d:%02d" % [int(elapsed) / 60, int(elapsed) % 60]

func finish(won: bool, toilets: int, save_record: bool = true) -> String:
	if not active:
		return summary
	active = false
	summary = "%d KILLS    %d%% ACCURACY    %s\n%d / 3 TOILETS FLUSHED" % [kills, accuracy(), clock_text(), toilets]
	if won:
		var records := ConfigFile.new()
		records.load(SAVE_PATH)
		var previous := float(records.get_value("fastest_wins", record_key, INF))
		if elapsed < previous:
			summary += "\nNEW PERSONAL BEST!"
			if save_record:
				records.set_value("fastest_wins", record_key, elapsed)
				var error := records.save(SAVE_PATH)
				if error != OK:
					push_warning("Could not save the single-player record: " + error_string(error))
		else:
			summary += "\nBEST WIN: %02d:%02d" % [int(previous) / 60, int(previous) % 60]
	return summary
