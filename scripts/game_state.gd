extends Node

const SAVE_FILE = "user://save_game.dat"

func save_game_state(data: Dictionary):
	var file = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	var json_string = JSON.stringify(data)
	file.store_string(json_string)

func load_game_state() -> Dictionary:
	if not FileAccess.file_exists(SAVE_FILE):
		return {}
		
	var file = FileAccess.open(SAVE_FILE, FileAccess.READ)
	var json_string = file.get_as_text()
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		print("JSON Parse Error: ", json.get_error_message())
		return {}
		
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		print("Invalid save data format")
		return {}
		
	return data

func has_saved_game() -> bool:
	return FileAccess.file_exists(SAVE_FILE)

func delete_save_game():
	if FileAccess.file_exists(SAVE_FILE):
		DirAccess.remove_absolute(SAVE_FILE)
