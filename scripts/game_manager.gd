extends Node3D

enum SessionMode { PLAYING, QUICK_PAUSED, MENU_PAUSED, GAME_OVER }

const PLAYER_SCENE = preload("res://scenes/player.tscn")
const SCORE_POPUP = preload("res://scenes/score_popup.tscn")

const INITIAL_ROCKS = 10
const ROCKS_SPAWN_INTERVAL = 2
const AUTOSAVE_INTERVAL = 5.0

var session_mode := SessionMode.PLAYING

var score: int = 0
var is_new_best: bool = false
var is_quitting: bool = false
var previous_auto_accept_quit: bool
var autosave_elapsed: float = 0.0
var player: Player
var score_popup: ScorePopup

@onready var camera: GameCamera = $GameplayContainer/Camera3D
@onready var ui: GameUI = $UI
@onready var score_popups: Control = $UI/ScorePopups
@onready var gameplay_container: Node3D = $GameplayContainer
@onready var spawner := ArenaSpawner.new(gameplay_container)
@onready var world_environment: WorldEnvironment = $WorldEnvironment

func _enter_tree() -> void:
	previous_auto_accept_quit = get_tree().auto_accept_quit
	get_tree().auto_accept_quit = false

func _exit_tree() -> void:
	get_tree().auto_accept_quit = previous_auto_accept_quit

func _ready() -> void:
	Engine.time_scale = 1.0
	var capture_available := DebugTelemetry.can_capture()
	set_physics_process(capture_available)
	if capture_available:
		seed(DebugTelemetry.RANDOM_SEED)
	_configure_renderer_features()
	_connect_ui()
	load_game_state()
	_apply_session_mode()
	update_score(0)
	DebugTelemetry.start_capture()

func _configure_renderer_features() -> void:
	if world_environment and world_environment.environment:
		world_environment.environment.volumetric_fog_enabled = RenderingServer.get_current_rendering_method() == "forward_plus"

func _connect_ui() -> void:
	ui.play_area_changed.connect(camera.fit_arena)
	camera.fit_arena(ui.get_play_area())
	ui.pause_requested.connect(_on_pause_requested)
	ui.camera_requested.connect(_toggle_camera)
	ui.resume_requested.connect(_on_resume_requested)
	ui.quit_requested.connect(save_and_quit)
	ui.retry_requested.connect(_on_retry_requested)
	ui.main_menu_requested.connect(return_to_main_menu)

func _process(delta: float) -> void:
	if session_mode != SessionMode.PLAYING or not is_instance_valid(player):
		return

	autosave_elapsed += maxf(delta, 0.0)
	if autosave_elapsed < AUTOSAVE_INTERVAL:
		return

	autosave_elapsed = fmod(autosave_elapsed, AUTOSAVE_INTERVAL)
	# Rocks can open or cover pickup locations even when the snake hasn't eaten.
	spawner.refill_food(player, true)
	# Browser tabs can be refreshed or closed without sending a reliable close
	# notification, so keep the resumable session reasonably current.
	save_game_state()

func _physics_process(delta: float) -> void:
	if session_mode == SessionMode.PLAYING:
		DebugTelemetry.sample_gameplay(delta, player, score)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or session_mode == SessionMode.GAME_OVER:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("gameplay_menu"):
		toggle_pause(true)
	elif event.is_action_pressed("gameplay_pause") and session_mode != SessionMode.MENU_PAUSED:
		toggle_gameplay_pause()
	elif event.is_action_pressed("toggle_camera_angle") and session_mode != SessionMode.MENU_PAUSED:
		_toggle_camera()

func _on_pause_requested() -> void:
	if session_mode == SessionMode.QUICK_PAUSED:
		toggle_gameplay_pause()
	else:
		toggle_pause(true)

func _toggle_camera() -> void:
	camera.toggle_view()
	SoundFx.play(SoundFx.Cue.UI, 0.39, 1.20)

func toggle_gameplay_pause() -> void:
	if session_mode not in [SessionMode.PLAYING, SessionMode.QUICK_PAUSED]:
		return

	var next := SessionMode.PLAYING if session_mode == SessionMode.QUICK_PAUSED else SessionMode.QUICK_PAUSED
	_play_pause_cue(next == SessionMode.QUICK_PAUSED)
	_set_session_mode(next)

func toggle_pause(play_cue: bool = false) -> void:
	if session_mode == SessionMode.GAME_OVER:
		return

	var next := SessionMode.PLAYING if session_mode == SessionMode.MENU_PAUSED else SessionMode.MENU_PAUSED
	if play_cue:
		_play_pause_cue(next == SessionMode.MENU_PAUSED)
	_set_session_mode(next)

func _play_pause_cue(paused: bool) -> void:
	SoundFx.play(SoundFx.Cue.UI, 0.48, 0.81 if paused else 1.12)

func _set_session_mode(next: SessionMode) -> void:
	if next == session_mode:
		return

	var previous := session_mode
	session_mode = next
	_apply_session_mode()
	if next == SessionMode.QUICK_PAUSED:
		DebugTelemetry.publish_trace()
	elif next == SessionMode.PLAYING and previous == SessionMode.QUICK_PAUSED:
		DebugTelemetry.start_capture()

func _apply_session_mode() -> void:
	var quick_paused := session_mode == SessionMode.QUICK_PAUSED
	var menu_paused := session_mode == SessionMode.MENU_PAUSED
	# The snake and debris still simulate in slow motion after a loss.
	gameplay_container.process_mode = Node.PROCESS_MODE_DISABLED if quick_paused or menu_paused else Node.PROCESS_MODE_INHERIT
	ui.steering.set_steering_enabled(session_mode == SessionMode.PLAYING)
	ui.set_gameplay_paused(quick_paused)
	ui.toggle_pause_menu(menu_paused)

func spawn_player() -> Player:
	player = PLAYER_SCENE.instantiate()
	gameplay_container.add_child(player)
	_bind_player(player)
	
	player.position = spawner.initial_player_position()
	player.rebuild_trail()
	return player

func _bind_player(new_player: Player) -> void:
	player = new_player
	player.steering = ui.steering
	player.food_collected.connect(_on_player_food_collected, CONNECT_DEFERRED)
	player.score_earned.connect(_on_player_score_earned)
	player.player_lost.connect(_on_player_lost)
	ui.set_player(player)

func _on_player_food_collected(total_food_eaten: int) -> void:
	if session_mode == SessionMode.GAME_OVER:
		return

	SoundFx.pickup(total_food_eaten)
	if total_food_eaten % ROCKS_SPAWN_INTERVAL == 0:
		spawner.spawn_rock(player, score)
	
	spawner.refill_food(player)

func _on_player_score_earned(points: int, popup_position: Vector3) -> void:
	if session_mode == SessionMode.GAME_OVER:
		return
	update_score(points)
	if not is_instance_valid(score_popup) or not score_popup.can_combine(popup_position):
		score_popup = SCORE_POPUP.instantiate()
		score_popup.camera = camera
		score_popup.world_position = popup_position
		score_popups.add_child(score_popup)
	score_popup.add_points(points)

func _on_player_lost() -> void:
	game_over()

func _on_resume_requested() -> void:
	if session_mode == SessionMode.MENU_PAUSED:
		Engine.time_scale = 1.0
		toggle_pause(true)

func _on_retry_requested() -> void:
	ArenaLoading.open_arena(false)

func update_score(points: int) -> void:
	var previous_best = GameState.get_best_score()
	score = clampi(score + points, 0, GameState.MAX_SAVED_SCORE)
	if score > previous_best:
		is_new_best = true
		if not GameState.save_best_score(score):
			push_warning("Unable to save the best score")
	if ui:
		ui.update_score(score)

func game_over() -> void:
	if session_mode == SessionMode.GAME_OVER:
		return

	_set_session_mode(SessionMode.GAME_OVER)
	SoundFx.play(SoundFx.Cue.LOSS)
	GameState.delete_save_game()
	if not GameState.save_best_score(score):
		push_warning("Unable to save the best score")
	Engine.time_scale = 0.5
	ui.show_game_over(score, GameState.get_best_score(), is_new_best)

func return_to_main_menu() -> void:
	if not _save_before_leaving():
		return
	SoundFx.play(SoundFx.Cue.UI, 0.49, 0.89)
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func save_and_quit() -> void:
	if is_quitting or not _save_before_leaving():
		return
	is_quitting = true
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().quit()

func _save_before_leaving() -> bool:
	if save_game_state():
		return true
	_set_session_mode(SessionMode.MENU_PAUSED)
	ui.show_save_error()
	return false

func save_game_state() -> bool:
	if session_mode == SessionMode.GAME_OVER or not is_instance_valid(player) or player.is_dead:
		return true
		
	var foods = get_tree().get_nodes_in_group("food")
	var rocks = get_tree().get_nodes_in_group("rock")
	
	var food_positions: Array[Dictionary] = []
	for food: Food in foods:
		if not food.is_available():
			continue
		food_positions.append(SaveVector.encode(Vector3(food.position.x, 0.0, food.position.z)))
	
	var rock_data: Array[Dictionary] = []
	for rock: Rock in rocks:
		if rock.is_queued_for_deletion() or rock.is_shattering:
			continue
		rock_data.append(rock.get_save_data())
	
	var save_data = {
		"score": score,
		"player_state": player.get_save_data(),
		"food_positions": food_positions,
		"rocks": rock_data
	}
	if GameState.save_game_state(save_data):
		return true
	push_warning("Unable to save the current game state")
	return false

func load_game_state() -> bool:
	for food in get_tree().get_nodes_in_group("food"):
		food.queue_free()
	
	var save_data = GameState.load_game_state()
	if save_data.is_empty():
		spawn_player()
		spawner.refill_food(player)
		for _index in INITIAL_ROCKS:
			spawner.spawn_rock(player, score, true)
		return false
		
	player = PLAYER_SCENE.instantiate()
	gameplay_container.add_child(player)
	player.restore_from_save_data(save_data.player_state)
	_bind_player(player)

	for rock_data: Dictionary in save_data.get("rocks", []):
		spawner.restore_rock(rock_data)

	# Replacement food must account for every restored hazard and rock.
	for food_pos: Dictionary in save_data.get("food_positions", []):
		var food_position := SaveVector.decode(food_pos)
		food_position.y = 0.0
		spawner.spawn_food_at(food_position)
	spawner.refill_food(player)

	score = int(save_data.score)
	return true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# Alt-Tab and minimizing must not leave a live snake in danger. Resume
		# remains an explicit choice when the player returns to the window.
		if is_node_ready() and session_mode != SessionMode.GAME_OVER:
			if session_mode == SessionMode.PLAYING:
				_set_session_mode(SessionMode.MENU_PAUSED)
			if not save_game_state() and session_mode == SessionMode.MENU_PAUSED:
				ui.show_save_error()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready():
		save_and_quit()
