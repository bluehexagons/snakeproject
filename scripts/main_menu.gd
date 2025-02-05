extends Control

@onready var continue_button = $Panel/VBoxContainer/ContinueButton

func _ready():
	continue_button.visible = GameState.has_saved_game()
	continue_button.pressed.connect(_on_continue_button_pressed)
	$Panel/VBoxContainer/NewGameButton.pressed.connect(on_new_game_pressed)
	$Panel/VBoxContainer/QuitButton.pressed.connect(on_quit_pressed)

func on_new_game_pressed():
	if FileAccess.file_exists(GameState.SAVE_FILE):
		DirAccess.remove_absolute(GameState.SAVE_FILE)
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func on_quit_pressed():
	get_tree().quit()

func _on_continue_button_pressed():
	if GameState.has_saved_game():
		await get_tree().create_timer(0.1).timeout
		var game_manager = get_tree().get_first_node_in_group("game_manager")
		if game_manager:
			game_manager.load_game_state()
			
		get_tree().change_scene_to_file("res://scenes/main.tscn")
