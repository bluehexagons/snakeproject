extends Node

var save_file_path = "user://save_game.dat"
var best_score_file_path = "user://best_score.dat"
const SAVE_VERSION = 1
const MAX_SAVED_SCORE = 2147483647
const MAX_SAVED_POSITION = 1000.0
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
	if not data is Dictionary or not data.has("x") or not data.has("y") or not data.has("z"):
		return false
	if not _is_finite_number(data.x) or not _is_finite_number(data.y) or not _is_finite_number(data.z):
		return false
	var value = Vector3(float(data.x), float(data.y), float(data.z))
	return value.is_finite() and value.length() <= MAX_SAVED_POSITION

func _is_finite_number(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var numeric_value := float(value)
	return not is_nan(numeric_value) and not is_inf(numeric_value)

func _write_text_safely(path: String, contents: String) -> bool:
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
	# Move the old save aside first so a failed promotion or interrupted write
	# leaves a recoverable copy. Readers use it only when the primary is absent.
	if FileAccess.file_exists(path):
		var backup_result = directory.rename(path.get_file(), path.get_file() + ".bak")
		if backup_result != OK:
			push_warning("Failed to back up save file: %s" % backup_result)
			return false
	var rename_result = _promote_save(directory, temporary_path.get_file(), path.get_file())
	if rename_result != OK:
		push_warning("Failed to commit save file; previous save retained: %s" % rename_result)
		return false
	return true

func _promote_save(directory: DirAccess, source: String, destination: String) -> Error:
	return directory.rename(source, destination)

func _open_saved_file(path: String) -> FileAccess:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file and FileAccess.get_open_error() == ERR_FILE_NOT_FOUND:
		return FileAccess.open(path + ".bak", FileAccess.READ)
	return file

func save_game_state(data: Dictionary) -> bool:
	var save_data = data.duplicate(true)
	save_data["version"] = SAVE_VERSION
	return _write_text_safely(save_file_path, JSON.stringify(save_data))

func load_game_state() -> Dictionary:
	var file = _open_saved_file(save_file_path)
	if not file:
		if FileAccess.get_open_error() != ERR_FILE_NOT_FOUND:
			push_error("Failed to open save file for reading: ", FileAccess.get_open_error())
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("JSON Parse Error: ", json.get_error_message())
		return {}
		
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Invalid save data format")
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
		for key in ["physics_pos", "visual_pos", "velocity"]:
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
		if rock_data.has("is_dangerous") and not rock_data.is_dangerous is bool:
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
	var file = _open_saved_file(save_file_path)
	if not file:
		return false
	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_string) != OK:
		return false
	var data = json.get_data()
	if not data is Dictionary:
		return false
	return is_valid_save_data(data)

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
	var file = _open_saved_file(best_score_file_path)
	if not file:
		return 0

	var value = file.get_as_text().to_int()
	file.close()
	return clampi(value, 0, MAX_SAVED_SCORE)

func save_best_score(score: int) -> bool:
	if score < 0 or score > MAX_SAVED_SCORE:
		return false
	if score <= get_best_score():
		return true

	return _write_text_safely(best_score_file_path, str(score))
