extends Control

@onready var score_label = $ScoreLabel
@onready var pause_menu = $PauseMenu
@onready var game_over_menu = $GameOverMenu
@onready var gameplay_pause_label = $GameplayPauseLabel

func _ready():
	gameplay_pause_label.visible = false
	$PauseMenu/VBoxContainer/ResumeButton.pressed.connect(on_resume_pressed)
	$PauseMenu/VBoxContainer/MainMenuButton.pressed.connect(on_main_menu_pressed)
	$PauseMenu/VBoxContainer/QuitButton.pressed.connect(on_quit_pressed)
	$GameOverMenu/VBoxContainer/RetryButton.pressed.connect(on_retry_pressed)
	$GameOverMenu/VBoxContainer/MainMenuButton.pressed.connect(on_main_menu_pressed)

func update_score(new_score: int):
	score_label.text = "Score: %d" % new_score

func set_gameplay_paused(is_paused: bool):
	gameplay_pause_label.visible = is_paused

func toggle_pause_menu(is_paused: bool):
	pause_menu.visible = is_paused

func show_game_over(final_score: int):
	game_over_menu.visible = true
	$GameOverMenu/VBoxContainer/ScoreLabel.text = "Final Score: %d" % final_score

func on_resume_pressed():
	Engine.time_scale = 1.0
	get_parent().toggle_pause()

func on_quit_pressed():
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_parent().save_and_quit()

func on_retry_pressed():
	GameState.delete_save_game()
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()

func on_main_menu_pressed():
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_parent().return_to_main_menu()
