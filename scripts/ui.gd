extends Control
class_name GameUI

const VIEWPORT_MARGIN = 16.0
const HUD_MARGIN = 12.0
const HUD_CARD_WIDTH = 230.0
const ACTION_BAR_WIDTH = 208.0

signal play_area_changed(area: Rect2)
signal pause_requested
signal camera_requested
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
@onready var control_hint: Label = $ControlHintLabel
@onready var action_bar: HBoxContainer = $ActionBar
@onready var pause_button: Button = $ActionBar/PauseButton
@onready var steering: GameplaySteering = $Steering
@onready var save_error_label: Label = $PauseMenu/VBoxContainer/SaveErrorLabel
@onready var menu_shade: ColorRect = $MenuShade

var hint_elapsed: float = 0.0
var player: Player
var compact_hud: bool = false
var current_score: int = 0

func _ready() -> void:
	get_viewport().size_changed.connect(_layout_hud)
	pause_button.pressed.connect(func(): pause_requested.emit())
	$ActionBar/CameraButton.pressed.connect(func(): camera_requested.emit())
	control_hint.text = steering.hint
	steering.hint_changed.connect(func(text: String): control_hint.text = text)
	$PauseMenu/VBoxContainer/ResumeButton.pressed.connect(on_resume_pressed)
	$PauseMenu/VBoxContainer/MainMenuButton.pressed.connect(on_main_menu_pressed)
	$PauseMenu/VBoxContainer/QuitButton.pressed.connect(on_quit_pressed)
	$PauseMenu/VBoxContainer/QuitButton.visible = not OS.has_feature("web")
	$GameOverMenu/VBoxContainer/RetryButton.pressed.connect(on_retry_pressed)
	$GameOverMenu/VBoxContainer/MainMenuButton.pressed.connect(on_main_menu_pressed)
	_layout_hud()

func _actions_at_top(viewport_size: Vector2) -> bool:
	return viewport_size.x >= 520.0 and viewport_size.x >= viewport_size.y * 1.55

func get_play_area() -> Rect2:
	var viewport_rect = get_viewport_rect()
	var bottom = 69.0 if _actions_at_top(viewport_rect.size) else 121.0
	return viewport_rect.grow_individual(-HUD_MARGIN, -66.0, -HUD_MARGIN, -bottom)

func _layout_hud() -> void:
	var viewport_size = get_viewport_rect().size
	var top = _actions_at_top(viewport_size)
	var center_gap = ACTION_BAR_WIDTH + HUD_MARGIN if top else HUD_MARGIN
	var card_width = minf(HUD_CARD_WIDTH, (viewport_size.x - 2.0 * HUD_MARGIN - center_gap) * 0.5)
	compact_hud = card_width < 195.0
	score_label.add_theme_font_size_override("font_size", 17 if compact_hud else 22)
	update_score(current_score)
	_refresh_stats_text()
	stats_label.offset_right = HUD_MARGIN + card_width
	score_label.offset_left = -HUD_MARGIN - card_width

	action_bar.anchor_top = 0.0 if top else 1.0
	action_bar.anchor_bottom = action_bar.anchor_top
	action_bar.offset_top = 12.0 if top else -56.0
	action_bar.offset_bottom = action_bar.offset_top + 48.0
	var footer_shift = 0.0 if top else 52.0
	control_hint.offset_top = -35.0 - footer_shift
	control_hint.offset_bottom = -9.0 - footer_shift
	hint_label.offset_top = -65.0 - footer_shift
	hint_label.offset_bottom = -37.0 - footer_shift

	_fit_panel_to_viewport(pause_menu)
	_fit_panel_to_viewport(game_over_menu)
	play_area_changed.emit(get_play_area())

func _fit_panel_to_viewport(panel: Control) -> void:
	if not is_instance_valid(panel) or panel.size.x <= 0.0 or panel.size.y <= 0.0:
		return
	panel.pivot_offset = panel.size * 0.5
	var available_size = get_viewport_rect().size - Vector2.ONE * VIEWPORT_MARGIN * 2.0
	var scale_factor = minf(1.0, minf(available_size.x / panel.size.x, available_size.y / panel.size.y))
	panel.scale = Vector2.ONE * maxf(scale_factor, 0.01)

func _refresh_stats_text() -> void:
	if is_instance_valid(player):
		var stats_format = "LENGTH %02d\nSPEED %.1fx" if compact_hud else "LENGTH %02d   SPEED %.1fx"
		stats_label.text = stats_format % [player.segments.size() + 1, player.current_speed_boost]

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return

	_refresh_stats_text()
	if pause_menu.visible or gameplay_pause_label.visible or game_over_menu.visible:
		hint_label.hide()
		return
	if player.has_started_moving:
		hint_label.visible = player.stuck_elapsed >= Player.STUCK_WARNING_START
		if hint_label.visible:
			if not hint_label.text.begins_with("KEEP MOVING"):
				hint_label.add_theme_color_override("font_color", Color(1.0, 0.68, 0.38))
			hint_label.text = "KEEP MOVING  ·  %.1fs" % maxf(Player.STUCK_TIMEOUT - player.stuck_elapsed, 0.0)
	else:
		hint_elapsed += delta
		hint_label.visible = hint_elapsed < 8.0

func update_score(new_score: int) -> void:
	current_score = new_score
	var score_format = "SCORE\n%d" if compact_hud else "SCORE  %d"
	score_label.text = score_format % current_score

func set_player(new_player: Player) -> void:
	player = new_player

func set_gameplay_paused(is_paused: bool) -> void:
	gameplay_pause_label.visible = is_paused
	pause_button.text = "Resume" if is_paused else "Pause"
	pause_button.tooltip_text = "Resume (Space)" if is_paused else "Pause (Esc)"

func toggle_pause_menu(is_paused: bool) -> void:
	pause_menu.visible = is_paused
	menu_shade.visible = is_paused
	action_bar.visible = not is_paused
	control_hint.visible = not is_paused
	if is_paused:
		$PauseMenu/VBoxContainer/ResumeButton.grab_focus()
	else:
		save_error_label.hide()

func show_save_error() -> void:
	save_error_label.show()

func show_game_over(final_score: int, best_score: int, is_new_best: bool) -> void:
	game_over_menu.visible = true
	action_bar.hide()
	control_hint.hide()
	gameplay_pause_label.hide()
	menu_shade.show()
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
