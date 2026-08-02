extends Control

@onready var score_label: Label = $ScoreLabel
@onready var stats_label: Label = $StatsLabel
@onready var pause_menu: Control = $PauseMenu
@onready var game_over_menu: Control = $GameOverMenu
@onready var gameplay_pause_label: Label = $GameplayPauseLabel
@onready var hint_label: Label = $HintLabel

var hint_elapsed: float = 0.0

func _ready() -> void:
	gameplay_pause_label.visible = false
	hint_label.visible = true
	$PauseMenu/VBoxContainer/ResumeButton.pressed.connect(on_resume_pressed)
	$PauseMenu/VBoxContainer/MainMenuButton.pressed.connect(on_main_menu_pressed)
	$PauseMenu/VBoxContainer/QuitButton.pressed.connect(on_quit_pressed)
	$GameOverMenu/VBoxContainer/RetryButton.pressed.connect(on_retry_pressed)
	$GameOverMenu/VBoxContainer/MainMenuButton.pressed.connect(on_main_menu_pressed)

func _process(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var length = player.segments.size() + 1
	stats_label.text = "LENGTH %02d   SPEED %.1fx" % [length, player.current_speed_boost]
	if player.has_started_moving:
		hint_label.visible = false
	else:
		hint_elapsed += delta
		hint_label.visible = hint_elapsed < 8.0

func update_score(new_score: int) -> void:
	score_label.text = "Score: %d" % new_score

func set_gameplay_paused(is_paused: bool) -> void:
	gameplay_pause_label.visible = is_paused

func toggle_pause_menu(is_paused: bool) -> void:
	pause_menu.visible = is_paused

func show_game_over(final_score: int, best_score: int, is_new_best: bool) -> void:
	game_over_menu.visible = true
	$GameOverMenu/VBoxContainer/ScoreLabel.text = "Final Score: %d" % final_score
	$GameOverMenu/VBoxContainer/SummaryLabel.text = "NEW BEST SCORE!" if is_new_best else "Best Score: %d" % best_score

func on_resume_pressed() -> void:
	Engine.time_scale = 1.0
	get_parent().toggle_pause()

func on_quit_pressed() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_parent().save_and_quit()

func on_retry_pressed() -> void:
	GameState.delete_save_game()
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()

func on_main_menu_pressed() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_parent().return_to_main_menu()
