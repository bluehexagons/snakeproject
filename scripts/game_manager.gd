extends Node3D

const PLAYER_SCENE = preload("res://scenes/player.tscn")
const FOOD_SCENE = preload("res://scenes/food.tscn")
const SPAWN_AREA_SIZE = Vector2(8, 8)  # Keep within camera view
const BASE_CAMERA_SIZE = 15.0  # This is our reference size for 1:1 aspect ratio
const SAVE_FILE = "user://save_game.dat"
const CAMERA_HEIGHT = 10.0
const CAMERA_FOLLOW_SPEED = 5.0
const CAMERA_TILT_ANGLE = 15.0  # Maximum tilt in degrees

const INITIAL_CAMERA_HEIGHT = 20.0  # Starting height
const FINAL_CAMERA_HEIGHT = 10.0    # Height to zoom to
const INITIAL_CAMERA_SIZE = 30.0    # Starting orthographic size
const FINAL_CAMERA_SIZE = 15.0      # Size to zoom to
const ZOOM_DURATION = 1.5           # How long the zoom takes
const ZOOM_DELAY = 0.5              # Wait before starting zoom

const CAMERA_HORIZONTAL_SMOOTHING = 3.0  # Lower = smoother horizontal movement
const CAMERA_VERTICAL_SMOOTHING = 2.0    # Separate smoothing for height changes
const CAMERA_PREDICTION_STRENGTH = 0.3   # How much to look ahead based on velocity

var score: int = 0
var is_paused: bool = false
var target_camera_pos: Vector3
var target_camera_rot: Vector3
var zoom_timer: float = 0.0
var is_zooming: bool = false
var camera_height: float = INITIAL_CAMERA_HEIGHT
var camera_size: float = INITIAL_CAMERA_SIZE
var camera_velocity: Vector3 = Vector3.ZERO

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
	target_camera_pos = camera.position
	target_camera_rot = camera.rotation_degrees
	
	camera.position.y = INITIAL_CAMERA_HEIGHT
	camera.size = INITIAL_CAMERA_SIZE
	target_camera_pos = camera.position
	target_camera_rot = camera.rotation_degrees
	
	await get_tree().create_timer(ZOOM_DELAY).timeout
	is_zooming = true

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):  # ESC key
		toggle_pause()

func _process(delta):
	if is_zooming:
		zoom_timer = min(zoom_timer + delta, ZOOM_DURATION)
		var t = ease(zoom_timer / ZOOM_DURATION, 0.5)  # Smooth easing
		
		camera_height = lerp(INITIAL_CAMERA_HEIGHT, FINAL_CAMERA_HEIGHT, t)
		camera_size = lerp(INITIAL_CAMERA_SIZE, FINAL_CAMERA_SIZE, t)
		
		if zoom_timer >= ZOOM_DURATION:
			is_zooming = false
	
	var player = get_node_or_null("Player")
	if player:
			# Calculate predicted position based on player velocity
		var prediction = Vector3.ZERO
		if player.velocity.length() > 0.1:
			prediction = player.velocity.normalized() * CAMERA_PREDICTION_STRENGTH
		
		# Update target position to follow player with prediction
		var target_x = player.position.x + prediction.x
		var target_z = player.position.z + prediction.z
		var target_y = camera_height  # Height changes are handled separately
		
		target_camera_pos = Vector3(target_x, target_y, target_z)
		
		# Separate axis smoothing
		var new_pos = camera.position
		new_pos.x = lerp(new_pos.x, target_camera_pos.x, delta * CAMERA_HORIZONTAL_SMOOTHING)
		new_pos.z = lerp(new_pos.z, target_camera_pos.z, delta * CAMERA_HORIZONTAL_SMOOTHING)
		new_pos.y = lerp(new_pos.y, target_camera_pos.y, delta * CAMERA_VERTICAL_SMOOTHING)
		
		camera.position = new_pos
		camera.size = camera_size

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
		camera.size = camera_size
	# If window is taller than wide, maintain horizontal size
	else:
		camera.size = camera_size / aspect_ratio

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
		},
		"segments": player.get_segment_positions()
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
	
	# First set the player's position and state
	player.restore_from_save(save_data)
	
	# Then restore segments with their growth states in reverse order
	if save_data.has("segments"):
		# Process segments in reverse order for proper chain formation
		var segments = save_data["segments"] as Array
		for i in range(segments.size() - 1, -1, -1):
			var segment_data = segments[i]
			# Create position vector from position dictionary
			var pos = Vector3(
				float(segment_data["position"]["x"]),
				float(segment_data["position"]["y"]),
				float(segment_data["position"]["z"])
			)
			# Create and position segment
			var segment = player.add_segment(0.0, pos)  # Initial growth of 0
			# Initialize segment data after it's properly in the scene tree
			await get_tree().process_frame
			segment.init_from_save_data(segment_data)
	
	# Spawn and setup food
	var food = FOOD_SCENE.instantiate()
	add_child(food)
	food.position = Vector3(
		float(save_data["food_position"]["x"]),
		float(save_data["food_position"]["y"]),
		float(save_data["food_position"]["z"])
	)
	
	score = save_data["score"]
	update_score(0)
	return true

func has_saved_game():
	return FileAccess.file_exists(SAVE_FILE)

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game_state()
		get_tree().quit()
