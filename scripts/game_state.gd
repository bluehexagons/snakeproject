extends Node

const SAVE_FILE = "user://save_game.dat"

func save_game_state(data: Dictionary) -> bool:
	var file = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if not file:
		push_error("Failed to open save file for writing: ", FileAccess.get_open_error())
		return false
	var json_string = JSON.stringify(data)
	file.store_string(json_string)
	file.close()
	return true

func load_game_state() -> Dictionary:
	if not FileAccess.file_exists(SAVE_FILE):
		return {}
		
	var file = FileAccess.open(SAVE_FILE, FileAccess.READ)
	if not file:
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
	return FileAccess.file_exists(SAVE_FILE)

func delete_save_game() -> bool:
	if not FileAccess.file_exists(SAVE_FILE):
		return false
	
	var dir = DirAccess.open("user://")
	if not dir:
		push_error("Failed to open user directory: ", DirAccess.get_open_error())
		return false
	
	var result = dir.remove(SAVE_FILE)
	if result != OK:
		push_error("Failed to delete save file: ", result)
		return false
	return true
