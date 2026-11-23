extends Control

const VIEWPORT_MARGIN = 16.0

@onready var panel: Panel = $Panel
@onready var continue_button: Button = $Panel/VBoxContainer/ContinueButton
@onready var best_score_label: Label = $Panel/VBoxContainer/BestScoreLabel

func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	call_deferred("_fit_panel_to_viewport")
	_refresh_continue_button()
	best_score_label.text = "BEST SCORE  %d" % GameState.get_best_score()
	continue_button.pressed.connect(_on_continue_button_pressed)
	$Panel/VBoxContainer/NewGameButton.pressed.connect(on_new_game_pressed)
	$Panel/VBoxContainer/QuitButton.pressed.connect(on_quit_pressed)
	# Web storage commits asynchronously. Refresh once after the scene enters
	# the tree so a save made immediately before returning here is discoverable.
	call_deferred("_refresh_continue_button")
	call_deferred("_focus_default_button")

func _focus_default_button() -> void:
	if continue_button.visible:
		continue_button.grab_focus()
	else:
		$Panel/VBoxContainer/NewGameButton.grab_focus()

func _on_viewport_size_changed() -> void:
	_fit_panel_to_viewport()

func _fit_panel_to_viewport() -> void:
	if not is_instance_valid(panel) or panel.size.x <= 0.0 or panel.size.y <= 0.0:
		return
	panel.pivot_offset = panel.size * 0.5
	var available_size = get_viewport_rect().size - Vector2.ONE * VIEWPORT_MARGIN * 2.0
	var scale_factor = minf(1.0, minf(available_size.x / panel.size.x, available_size.y / panel.size.y))
	panel.scale = Vector2.ONE * maxf(scale_factor, 0.01)

func _refresh_continue_button() -> void:
	if is_instance_valid(continue_button):
		continue_button.visible = GameState.has_saved_game()

func on_new_game_pressed() -> void:
	if not GameState.delete_save_game():
		push_warning("Unable to clear the saved game")
		return
	SoundFx.play(SoundFx.Cue.UI, 0.53, 1.27)
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func on_quit_pressed() -> void:
	get_tree().quit()

func _on_continue_button_pressed() -> void:
	if GameState.has_saved_game():
		SoundFx.play(SoundFx.Cue.UI, 0.53, 1.12)
		get_tree().change_scene_to_file("res://scenes/main.tscn")
			
