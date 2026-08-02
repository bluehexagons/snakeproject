extends Control

@onready var continue_button: Button = $Panel/VBoxContainer/ContinueButton
@onready var best_score_label: Label = $Panel/VBoxContainer/BestScoreLabel

func _ready() -> void:
	continue_button.visible = GameState.has_saved_game()
	best_score_label.text = "BEST SCORE  %d" % GameState.get_best_score()
	continue_button.pressed.connect(_on_continue_button_pressed)
	$Panel/VBoxContainer/NewGameButton.pressed.connect(on_new_game_pressed)
	$Panel/VBoxContainer/QuitButton.pressed.connect(on_quit_pressed)

func on_new_game_pressed() -> void:
	GameState.delete_save_game()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func on_quit_pressed() -> void:
	get_tree().quit()

func _on_continue_button_pressed() -> void:
	if GameState.has_saved_game():
		get_tree().change_scene_to_file("res://scenes/main.tscn")
			
