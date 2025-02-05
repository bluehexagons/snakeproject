extends Control

@onready var score_label = $ScoreLabel
@onready var pause_menu = $PauseMenu

func _ready():
	$PauseMenu/VBoxContainer/ResumeButton.pressed.connect(_on_resume_pressed)
	$PauseMenu/VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)

func update_score(new_score: int):
	score_label.text = "Score: %d" % new_score

func toggle_pause_menu(is_paused: bool):
	pause_menu.visible = is_paused

func _on_resume_pressed():
	get_parent().toggle_pause()

func _on_quit_pressed():
	get_tree().quit()