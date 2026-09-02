extends Node

const SAVE_FILE = "user://save_game.dat"
const BEST_SCORE_FILE = "user://best_score.dat"
const SAVE_VERSION = 1
const MAX_SAVED_SCORE = 2147483647

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
	var version = data.get("version", SAVE_VERSION)
	var valid = is_supported_save_version(version) and data.has("score") and typeof(data.get("score")) in [TYPE_INT, TYPE_FLOAT] and data.get("player_state") is Dictionary and data.player_state.has("position")
	return valid

func delete_save_game() -> bool:
	if not FileAccess.file_exists(SAVE_FILE):
		return false
	
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
	return max(value, 0)

func save_best_score(score: int) -> bool:
	if score <= get_best_score():
		return true

	return _write_text_atomically(BEST_SCORE_FILE, str(score))
