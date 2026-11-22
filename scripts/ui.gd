extends Control
class_name GameUI

const VIEWPORT_MARGIN = 16.0

signal resume_requested
signal quit_requested
signal retry_requested
signal main_menu_requested

@onready var score_label: Label = $ScoreLabel
@onready var stats_label: Label = $StatsLabel
@onready var pause_menu: Control = $PauseMenu
@onready var game_over_menu: Control = $GameOverMenu
@onready var gameplay_pause_label: Label = $GameplayPauseLabel
@onready var hint_label: Label = $HintLabel
@onready var save_error_label: Label = $PauseMenu/VBoxContainer/SaveErrorLabel

var hint_elapsed: float = 0.0
var player: Player

func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	gameplay_pause_label.visible = false
	hint_label.visible = true
	$PauseMenu/VBoxContainer/ResumeButton.pressed.connect(on_resume_pressed)
	$PauseMenu/VBoxContainer/MainMenuButton.pressed.connect(on_main_menu_pressed)
	$PauseMenu/VBoxContainer/QuitButton.pressed.connect(on_quit_pressed)
	$GameOverMenu/VBoxContainer/RetryButton.pressed.connect(on_retry_pressed)
	$GameOverMenu/VBoxContainer/MainMenuButton.pressed.connect(on_main_menu_pressed)
	call_deferred("_fit_overlay_to_viewport")

func _on_viewport_size_changed() -> void:
	_fit_overlay_to_viewport()

func _fit_overlay_to_viewport() -> void:
	_fit_panel_to_viewport(pause_menu)
	_fit_panel_to_viewport(game_over_menu)
	_fit_label_to_viewport(hint_label)
	_fit_label_to_viewport($ControlHintLabel, 520.0)

func _fit_panel_to_viewport(panel: Control) -> void:
	if not is_instance_valid(panel) or panel.size.x <= 0.0 or panel.size.y <= 0.0:
		return
	panel.pivot_offset = panel.size * 0.5
	var available_size = get_viewport_rect().size - Vector2.ONE * VIEWPORT_MARGIN * 2.0
	var scale_factor = minf(1.0, minf(available_size.x / panel.size.x, available_size.y / panel.size.y))
	panel.scale = Vector2.ONE * maxf(scale_factor, 0.01)

func _fit_label_to_viewport(label: Control, base_width: float = 360.0) -> void:
	if not is_instance_valid(label):
		return
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2.ONE * minf(1.0, get_viewport_rect().size.x / base_width)

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return

	var length = player.segments.size() + 1
	stats_label.text = "LENGTH %02d   SPEED %.1fx" % [length, player.current_speed_boost]
	if pause_menu.visible or gameplay_pause_label.visible or game_over_menu.visible:
		hint_label.hide()
		return
	if player.has_started_moving:
		hint_label.visible = player.stuck_elapsed >= Player.STUCK_WARNING_START
		if hint_label.visible:
			hint_label.text = "KEEP MOVING  ·  %.1fs" % maxf(Player.STUCK_TIMEOUT - player.stuck_elapsed, 0.0)
	else:
		hint_elapsed += delta
		hint_label.visible = hint_elapsed < 8.0

func update_score(new_score: int) -> void:
	score_label.text = "Score: %d" % new_score

func set_player(new_player: Player) -> void:
	player = new_player

func set_gameplay_paused(is_paused: bool) -> void:
	gameplay_pause_label.visible = is_paused

func toggle_pause_menu(is_paused: bool) -> void:
	pause_menu.visible = is_paused
	if is_paused:
		$PauseMenu/VBoxContainer/ResumeButton.grab_focus()
	else:
		save_error_label.hide()

func show_save_error() -> void:
	save_error_label.show()

func show_game_over(final_score: int, best_score: int, is_new_best: bool) -> void:
	game_over_menu.visible = true
	$GameOverMenu/VBoxContainer/RetryButton.grab_focus()
	$GameOverMenu/VBoxContainer/ScoreLabel.text = "Final Score: %d" % final_score
	$GameOverMenu/VBoxContainer/SummaryLabel.text = "NEW BEST SCORE!" if is_new_best else "Best Score: %d" % best_score

func on_resume_pressed() -> void:
	resume_requested.emit()

func on_quit_pressed() -> void:
	quit_requested.emit()

func on_retry_pressed() -> void:
	retry_requested.emit()

func on_main_menu_pressed() -> void:
	main_menu_requested.emit()
