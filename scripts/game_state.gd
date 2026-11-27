extends Node

var save_file_path = "user://save_game.dat"
var best_score_file_path = "user://best_score.dat"
const SAVE_VERSION = 1
const MAX_SAVED_SCORE = 2147483647
const MAX_SAVED_SEGMENTS = 1000
const MAX_SAVED_FOOD = 100
const MAX_SAVED_ROCKS = 1000

# Verification explicitly redirects both files on every native platform. Release
# builds always use user://, even if the environment contains a test override.
func _init() -> void:
	var test_directory = OS.get_environment("SNAKE3D_TEST_DATA_DIR")
	if OS.is_debug_build() and not test_directory.is_empty():
		save_file_path = test_directory.path_join("save_game.dat")
		best_score_file_path = test_directory.path_join("best_score.dat")
		if not test_directory.is_absolute_path() or not DirAccess.dir_exists_absolute(test_directory):
			push_error("Test data directory must be an existing absolute path")
			Engine.get_main_loop().quit(1)
			return

func is_supported_save_version(version: Variant) -> bool:
	var version_type := typeof(version)
	if version_type not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var numeric_version := float(version)
	return not is_nan(numeric_version) and not is_inf(numeric_version) and numeric_version == floor(numeric_version) and numeric_version >= 1.0 and numeric_version <= SAVE_VERSION

func is_valid_saved_score(score: Variant) -> bool:
	var score_type := typeof(score)
	if score_type not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var numeric_score := float(score)
	return not is_nan(numeric_score) and not is_inf(numeric_score) and numeric_score == floor(numeric_score) and numeric_score >= 0.0 and numeric_score <= MAX_SAVED_SCORE

func is_valid_saved_vector(data: Variant) -> bool:
	return SaveVector.is_valid(data)

func _is_finite_number(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var numeric_value := float(value)
	return not is_nan(numeric_value) and not is_inf(numeric_value)

func _write_text_safely(path: String, contents: String, keep_backup: bool) -> bool:
	var temporary_path = path + ".tmp"
	var file = FileAccess.open(temporary_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to open temporary save file for writing: ", FileAccess.get_open_error())
		return false

	file.store_string(contents)
	file.flush()
	var write_result = file.get_error()
	file.close()
	if write_result != OK:
		push_error("Failed to write save file: ", write_result)
		return false

	var directory = DirAccess.open(path.get_base_dir())
	if not directory:
		push_error("Failed to open user directory: ", DirAccess.get_open_error())
		return false

	# Godot's Windows rename removes an existing destination before moving.
	# Keep the recovery copy if the primary is unreadable or invalid.
	if FileAccess.file_exists(path):
		var filename = path.get_file()
		var prepare_result = directory.remove(filename) if keep_backup else directory.rename(filename, filename + ".bak")
		if prepare_result != OK:
			push_warning("Failed to prepare save file for replacement: %s" % prepare_result)
			return false
	var rename_result = _promote_save(directory, temporary_path.get_file(), path.get_file())
	if rename_result != OK:
		push_warning("Failed to commit save file: %s" % rename_result)
		return false
	return true

func _promote_save(directory: DirAccess, source: String, destination: String) -> Error:
	return directory.rename(source, destination)

func save_game_state(data: Dictionary) -> bool:
	var save_data = data.duplicate()
	save_data["version"] = SAVE_VERSION
	if not is_valid_save_data(save_data):
		return false
	var keep_backup = FileAccess.file_exists(save_file_path + ".bak") and _read_game_save(save_file_path).is_empty()
	return _write_text_safely(save_file_path, JSON.stringify(save_data), keep_backup)

func load_game_state() -> Dictionary:
	var data = _read_game_save(save_file_path)
	return _read_game_save(save_file_path + ".bak") if data.is_empty() else data

func _read_game_save(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	var data = json.get_data()
	if not data is Dictionary or not is_valid_save_data(data):
		return {}
	return data

func is_valid_save_data(data: Dictionary) -> bool:
	var version = data.get("version", SAVE_VERSION)
	if not is_supported_save_version(version):
		return false

	if not is_valid_saved_score(data.get("score")):
		return false

	var player_state: Variant = data.get("player_state")
	if not player_state is Dictionary:
		return false
	if not is_valid_saved_vector(player_state.get("position")):
		return false
	for key in ["physics_pos", "visual_pos", "velocity", "facing_direction"]:
		if player_state.has(key) and not is_valid_saved_vector(player_state.get(key)):
			return false

	if not _has_valid_physics_scalars(player_state):
		return false
	if player_state.has("food_eaten") and not is_valid_saved_score(player_state.food_eaten):
		return false
	if player_state.has("current_speed_boost") and not _is_finite_number(player_state.current_speed_boost):
		return false
	if player_state.has("has_started_moving") and not player_state.has_started_moving is bool:
		return false
	if player_state.has("stuck_elapsed"):
		var elapsed = player_state.stuck_elapsed
		if not _is_finite_number(elapsed) or elapsed < 0.0 or elapsed >= Player.STUCK_TIMEOUT:
			return false
	for key in ["pending_pickup_impulse", "pickup_speed_bonus"]:
		if player_state.has(key):
			var boost = player_state[key]
			if not _is_finite_number(boost) or boost < 0.0 or boost > Player.MAX_PICKUP_BOOST:
				return false
	if player_state.has("digestion_timer"):
		var elapsed = player_state.digestion_timer
		if not _is_finite_number(elapsed) or elapsed < 0.0 or elapsed >= Player.DIGESTION_DURATION:
			return false
	if player_state.has("motion_sample"):
		var sample = player_state.motion_sample
		if not sample is Dictionary or not is_valid_saved_vector(sample.get("start")):
			return false
		var elapsed = sample.get("elapsed")
		if not _is_finite_number(elapsed) or elapsed < 0.0 or elapsed >= Player.STUCK_CHECK_INTERVAL:
			return false

	var segments: Variant = player_state.get("segments", [])
	if not segments is Array or segments.size() > MAX_SAVED_SEGMENTS:
		return false
	for segment_data in segments:
		if not segment_data is Dictionary or not is_valid_saved_vector(segment_data.get("position")):
			return false
		if not _has_valid_physics_scalars(segment_data):
			return false
		if segment_data.has("growth") and not _is_finite_number(segment_data.growth):
			return false
		for key in ["is_dangerous", "is_solid"]:
			if segment_data.has(key) and not segment_data[key] is bool:
				return false
		for key in ["physics_pos", "visual_pos", "velocity", "path_target"]:
			if segment_data.has(key) and not is_valid_saved_vector(segment_data.get(key)):
				return false

	var trail: Variant = player_state.get("trail", [])
	if not trail is Array or trail.size() > 20000:
		return false
	for point in trail:
		if not is_valid_saved_vector(point):
			return false

	var food_positions: Variant = data.get("food_positions", [])
	if not food_positions is Array or food_positions.size() > MAX_SAVED_FOOD:
		return false
	for food_data in food_positions:
		if not food_data is Dictionary or not is_valid_saved_vector(food_data):
			return false

	var rocks: Variant = data.get("rocks", [])
	if not rocks is Array or rocks.size() > MAX_SAVED_ROCKS:
		return false
	for rock_data in rocks:
		if not rock_data is Dictionary or not is_valid_saved_vector(rock_data.get("position")):
			return false
		if not _has_valid_physics_scalars(rock_data):
			return false
		for key in ["is_dangerous", "is_spawning"]:
			if rock_data.has(key) and not rock_data[key] is bool:
				return false
		if rock_data.has("spawn_timer") and not _is_finite_number(rock_data.spawn_timer):
			return false
		for key in ["physics_pos", "visual_pos", "velocity", "rotation", "angular_velocity"]:
			if rock_data.has(key) and not is_valid_saved_vector(rock_data.get(key)):
				return false
	return true

func _has_valid_physics_scalars(data: Dictionary) -> bool:
	for key in ["current_scale", "ground_contact_timer"]:
		if data.has(key) and not _is_finite_number(data[key]):
			return false
	return not data.has("is_grounded") or data.is_grounded is bool

func has_saved_game() -> bool:
	return not load_game_state().is_empty()

func delete_save_game() -> bool:
	var directory = DirAccess.open(save_file_path.get_base_dir())
	if not directory:
		push_error("Failed to open user directory: ", DirAccess.get_open_error())
		return false
	# Remove recovery files before the primary, so New Game or death cannot
	# resurrect an earlier session after a successful deletion.
	for suffix in [".bak", ".tmp", ""]:
		var path = save_file_path + suffix
		var file = FileAccess.open(path, FileAccess.READ)
		if not file:
			if FileAccess.get_open_error() == ERR_FILE_NOT_FOUND:
				continue
			push_error("Failed to inspect save file: ", FileAccess.get_open_error())
			return false
		file.close()
		var result = directory.remove(path.get_file())
		if result != OK:
			push_error("Failed to delete save file: ", result)
			return false
	return true

func get_best_score() -> int:
	var score = _read_best_score(best_score_file_path)
	return maxi(_read_best_score(best_score_file_path + ".bak"), 0) if score < 0 else score

func _read_best_score(path: String) -> int:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return -1
	var score_text = file.get_as_text().strip_edges()
	if not score_text.is_valid_int():
		return -1
	var score = score_text.to_int()
	return score if score >= 0 and score <= MAX_SAVED_SCORE else -1

func save_best_score(score: int) -> bool:
	if score < 0 or score > MAX_SAVED_SCORE:
		return false
	var primary_score = _read_best_score(best_score_file_path)
	var keep_backup = primary_score < 0 and FileAccess.file_exists(best_score_file_path + ".bak")
	var best = maxi(_read_best_score(best_score_file_path + ".bak"), 0) if keep_backup else maxi(primary_score, 0)
	if score <= best:
		return true

	return _write_text_safely(best_score_file_path, str(score), keep_backup)
