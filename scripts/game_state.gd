extends Node

const SAVE_FILE = "user://save_game.dat"
const BEST_SCORE_FILE = "user://best_score.dat"
const SAVE_VERSION = 1
const MAX_SAVED_SCORE = 2147483647
const MAX_SAVED_POSITION = 1000.0
const MAX_SAVED_SEGMENTS = 1000
const MAX_SAVED_FOOD = 100
const MAX_SAVED_ROCKS = 1000

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

func _write_text_atomically(path: String, contents: String) -> bool:
	var temporary_path = path + ".tmp"
	var file = FileAccess.open(temporary_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to open temporary save file for writing: ", FileAccess.get_open_error())
		return false

	file.store_string(contents)
	file.flush()
	file.close()

	var directory = DirAccess.open("user://")
	if not directory:
		push_error("Failed to open user directory: ", DirAccess.get_open_error())
		return false

	var rename_result = directory.rename(temporary_path.get_file(), path.get_file())
	if rename_result == OK:
		return true

	# Some platforms do not replace an existing file during rename. The fully
	# written temporary file is safe to promote after removing the old copy.
	if FileAccess.file_exists(path):
		var remove_result = directory.remove(path.get_file())
		if remove_result != OK:
			push_error("Failed to replace save file: ", remove_result)
			return false
		rename_result = directory.rename(temporary_path.get_file(), path.get_file())

	if rename_result != OK:
		push_error("Failed to commit save file: ", rename_result)
		if FileAccess.file_exists(temporary_path):
			directory.remove(temporary_path.get_file())
		return false
	return true

func save_game_state(data: Dictionary) -> bool:
	var save_data = data.duplicate(true)
	save_data["version"] = SAVE_VERSION
	return _write_text_atomically(SAVE_FILE, JSON.stringify(save_data))

func load_game_state() -> Dictionary:
	var file = FileAccess.open(SAVE_FILE, FileAccess.READ)
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
	var file = FileAccess.open(SAVE_FILE, FileAccess.READ)
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
	# Probe with a direct open instead of FileAccess.file_exists(), whose
	# result can lag behind the Web virtual filesystem state.
	var file = FileAccess.open(SAVE_FILE, FileAccess.READ)
	if not file:
		if FileAccess.get_open_error() == ERR_FILE_NOT_FOUND:
			return true
		push_error("Failed to inspect save file: ", FileAccess.get_open_error())
		return false
	file.close()

	var dir = DirAccess.open("user://")
	if not dir:
		push_error("Failed to open user directory: ", DirAccess.get_open_error())
		return false
	
	var result = dir.remove(SAVE_FILE.get_file())
	if result != OK:
		push_error("Failed to delete save file: ", result)
		return false
	return true

func get_best_score() -> int:
	var file = FileAccess.open(BEST_SCORE_FILE, FileAccess.READ)
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

	return _write_text_atomically(BEST_SCORE_FILE, str(score))
