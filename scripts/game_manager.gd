extends Node3D

const PLAYER_SCENE = preload("res://scenes/player.tscn")
const FOOD_SCENE = preload("res://scenes/food.tscn")
const SPAWN_AREA_SIZE = Vector2(8, 8)  # Keep within camera view
const BASE_CAMERA_SIZE = 15.0  # This is our reference size for 1:1 aspect ratio
const SAVE_FILE = "user://save_game.dat"

var score: int = 0
var is_paused: bool = false
@onready var camera = $Camera3D
@onready var ui = $UI

func _ready():
	if GameState.has_saved_game():
		load_game_state()
	else:
		spawn_player()
		spawn_food()
	
	get_tree().root.size_changed.connect(_on_window_resize)
	_on_window_resize()
	update_score(0)

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):  # ESC key
		toggle_pause()

func toggle_pause():
	is_paused = !is_paused
	get_tree().paused = is_paused
	ui.toggle_pause_menu(is_paused)

func spawn_player():
	var player = PLAYER_SCENE.instantiate()
	add_child(player)
	
	# Random position within spawn area
	var random_x = randf_range(-SPAWN_AREA_SIZE.x, SPAWN_AREA_SIZE.x)
	var random_z = randf_range(-SPAWN_AREA_SIZE.y, SPAWN_AREA_SIZE.y)
	player.position = Vector3(random_x, 0, random_z)

func spawn_food():
	var food = FOOD_SCENE.instantiate()
	add_child(food)
	
	# Random position within spawn area
	var random_x = randf_range(-SPAWN_AREA_SIZE.x, SPAWN_AREA_SIZE.x)
	var random_z = randf_range(-SPAWN_AREA_SIZE.y, SPAWN_AREA_SIZE.y)
	food.position = Vector3(random_x, 0, random_z)

func on_food_collected():
	update_score(10)
	spawn_food()

func _on_window_resize():
	var window_size = DisplayServer.window_get_size()
	var aspect_ratio = float(window_size.x) / float(window_size.y)
	
	# If window is wider than tall, maintain vertical size
	if aspect_ratio > 1.0:
		camera.size = BASE_CAMERA_SIZE
	# If window is taller than wide, maintain horizontal size
	else:
		camera.size = BASE_CAMERA_SIZE / aspect_ratio

func update_score(points: int):
	score += points
	if ui:
		ui.update_score(score)

func game_over():
	is_paused = true
	get_tree().paused = true
	ui.show_game_over(score)

func return_to_main_menu():
	save_game_state()
	get_tree().paused = false
	# Remove pause state before changing scene
	is_paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func save_and_quit():
	save_game_state()
	get_tree().paused = false
	# Remove pause state before changing scene
	is_paused = false
	get_tree().quit()

func save_game_state():
	var player = get_node_or_null("Player")
	var food = get_tree().get_first_node_in_group("food")
	
	if not player or not food:
		print("Warning: Could not find player or food when saving")
		return
	
	var save_data = {
		"score": score,
		"player_position": {
			"x": player.position.x,
			"y": player.position.y,
			"z": player.position.z
		},
		"food_position": {
			"x": food.position.x,
			"y": food.position.y,
			"z": food.position.z
		}
	}
	GameState.save_game_state(save_data)

func load_game_state():
	var save_data = GameState.load_game_state()
	if save_data.is_empty():
		spawn_player()
		spawn_food()
		return false
		
	# Clear existing entities
	if has_node("Player"):
		$Player.queue_free()
	if has_node("Food"):
		$Food.queue_free()
	
	# Spawn and setup player
	var player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.position = Vector3(
		float(save_data.player_position.x),
		float(save_data.player_position.y),
		float(save_data.player_position.z)
	)
	
	# Spawn and setup food
	var food = FOOD_SCENE.instantiate()
	add_child(food)
	food.position = Vector3(
		float(save_data.food_position.x),
		float(save_data.food_position.y),
		float(save_data.food_position.z)
	)
	
	score = save_data.score
	update_score(0)
	return true

func has_saved_game():
	return FileAccess.file_exists(SAVE_FILE)

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game_state()
		get_tree().quit()
