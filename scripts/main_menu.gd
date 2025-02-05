extends Control

func _ready():
	$Panel/VBoxContainer/NewGameButton.pressed.connect(on_new_game_pressed)
	$Panel/VBoxContainer/QuitButton.pressed.connect(on_quit_pressed)

func on_new_game_pressed():
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func on_quit_pressed():
	get_tree().quit()
