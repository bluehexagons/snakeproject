extends Node3D

const PLAYER_SCENE = preload("res://scenes/player.tscn")
const FOOD_SCENE = preload("res://scenes/food.tscn")
const ROCK_SCENE = preload("res://scenes/rock.tscn")
const SPAWN_AREA_SIZE = Vector2(8, 8)  # Reduced from previous size to account for barriers
const BASE_CAMERA_SIZE = 15.0  # This is our reference size for 1:1 aspect ratio
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
const INITIAL_ROCKS = 10  # Number of rocks to spawn at start
const ROCKS_SPAWN_INTERVAL = 2  # Spawn a new rock every X food collections
const DANGER_START_SCORE = 50  # Score at which rocks start becoming dangerous
const DANGER_MAX_SCORE = 300   # Score at which danger probability peaks
const MAX_DANGER_PROBABILITY = 0.8  # Maximum probability of a rock being dangerous

const SAFE_SPAWN_DISTANCE = 4.0  # Minimum distance from player for dangerous rocks
const SAFE_FORWARD_ANGLE = 60.0  # Angle in degrees to check in front of player

const CAMERA_OFFSET = Vector3(0, 0, 0)  # Offset from target to maintain perspective

var target_camera_pos: Vector3
var target_camera_rot: Vector3

# Camera state
var zoom_timer: float = 0.0
var is_zooming: bool = false
var camera_height: float = INITIAL_CAMERA_HEIGHT
var camera_size: float = INITIAL_CAMERA_SIZE
var camera_velocity: Vector3 = Vector3.ZERO

# UI state
var is_paused: bool = false # In this state, all game-related features are paused
var is_gameplay_paused: bool = false # In this state, the physics and game logic are paused
var is_game_over: bool = false

# Game state
var score: int = 0

@onready var camera = $GameplayContainer/Camera3D
@onready var ui = $UI
@onready var gameplay_container = $GameplayContainer

func _ready():
	if GameState.has_saved_game():
		load_game_state()
	else:
		spawn_player()
		spawn_food()
		spawn_initial_rocks()
	
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
	elif event.is_action_pressed("gameplay_pause"):
		if !is_paused:  # Only toggle gameplay pause when menu isn't open
			toggle_gameplay_pause()

func _process(delta):
	if is_zooming:
		zoom_timer = min(zoom_timer + delta, ZOOM_DURATION)
		var t = ease(zoom_timer / ZOOM_DURATION, 0.5)  # Smooth easing
		
		camera_height = lerp(INITIAL_CAMERA_HEIGHT, FINAL_CAMERA_HEIGHT, t)
		camera_size = lerp(INITIAL_CAMERA_SIZE, FINAL_CAMERA_SIZE, t)
		
		if zoom_timer >= ZOOM_DURATION:
			is_zooming = false
	
	var player = gameplay_container.get_node_or_null("Player")
	if player:
		# Calculate predicted position based on player velocity
		var prediction = Vector3.ZERO
		if player.velocity.length() > 0.1:
			prediction = player.velocity.normalized() * CAMERA_PREDICTION_STRENGTH
		
		# Update target position to follow player with prediction and offset
		var target_pos = player.position + prediction
		target_camera_pos = Vector3(
			target_pos.x + CAMERA_OFFSET.x,
			camera_height,
			target_pos.z + CAMERA_OFFSET.z
		)
		
		# Update camera position with smoothing
		var new_pos = camera.position
		new_pos.x = lerp(new_pos.x, target_camera_pos.x, delta * CAMERA_HORIZONTAL_SMOOTHING)
		new_pos.z = lerp(new_pos.z, target_camera_pos.z, delta * CAMERA_HORIZONTAL_SMOOTHING)
		new_pos.y = lerp(new_pos.y, target_camera_pos.y, delta * CAMERA_VERTICAL_SMOOTHING)
		
		camera.position = new_pos
		camera.size = camera_size

func toggle_gameplay_pause():
	if is_game_over:
		return

	is_gameplay_paused = !is_gameplay_paused
	update_pause_state()
	if ui:
		ui.set_gameplay_paused(is_gameplay_paused)

func toggle_pause():
	if is_game_over:
		return

	is_paused = !is_paused
	update_pause_state()
	ui.toggle_pause_menu(is_paused)

func update_pause_state():
	# Only pause the gameplay container
	gameplay_container.process_mode = Node.PROCESS_MODE_DISABLED if (is_paused || is_gameplay_paused) else Node.PROCESS_MODE_INHERIT

func spawn_player():
	var player = PLAYER_SCENE.instantiate()
	gameplay_container.add_child(player)
	
	# Random position within spawn area
	var random_x = randf_range(-SPAWN_AREA_SIZE.x, SPAWN_AREA_SIZE.x)
	var random_z = randf_range(-SPAWN_AREA_SIZE.y, SPAWN_AREA_SIZE.y)
	player.position = Vector3(random_x, 0, random_z)

func spawn_food():
	var max_attempts = 10
	var attempts = 0
	var food = FOOD_SCENE.instantiate()
	gameplay_container.add_child(food)
	
	while attempts < max_attempts:
		var random_x = randf_range(-SPAWN_AREA_SIZE.x, SPAWN_AREA_SIZE.x)
		var random_z = randf_range(-SPAWN_AREA_SIZE.y, SPAWN_AREA_SIZE.y)
		var pos = Vector3(random_x, 0, random_z)
		food.position = pos
		
		# Check distance from dangerous segments and rocks
		var too_close = false
		for node in get_tree().get_nodes_in_group("dangerous"):
			if node.global_position.distance_to(pos) < 2.0:
				too_close = true
				break
		
		for rock in get_tree().get_nodes_in_group("rock"):
			if rock.global_position.distance_to(pos) < 1.5:
				too_close = true
				break
				
		if !too_close:
			return
			
		attempts += 1
	
	# If we couldn't find a good spot, just leave it where it is
	food.position = Vector3.ZERO

func spawn_initial_rocks():
	for i in range(INITIAL_ROCKS):
		spawn_rock(true)  # Force initial rocks to be safe

func spawn_rock(force_safe: bool = false):
	var rock = ROCK_SCENE.instantiate()
	gameplay_container.add_child(rock)
	
	# Random position within spawn area
	var random_x = randf_range(-SPAWN_AREA_SIZE.x, SPAWN_AREA_SIZE.x)
	var random_z = randf_range(-SPAWN_AREA_SIZE.y, SPAWN_AREA_SIZE.y)
	var spawn_pos = Vector3(random_x, 0, random_z)
	
	# Initialize the rock
	rock.initialize(spawn_pos)
	
	# Get player reference
	var player = gameplay_container.get_node_or_null("Player")
	var should_be_dangerous = false
	
	# Calculate danger probability based on score
	if !force_safe && score >= DANGER_START_SCORE:
		var score_factor = clamp(float(score - DANGER_START_SCORE) / (DANGER_MAX_SCORE - DANGER_START_SCORE), 0.0, 1.0)
		var danger_probability = score_factor * MAX_DANGER_PROBABILITY
		
		if randf() < danger_probability:
			# Check if position is safe for a dangerous rock
			var is_safe_position = true
			if player:
				# Check distance from player
				var dist_to_player = player.global_position.distance_to(spawn_pos)
				if dist_to_player < SAFE_SPAWN_DISTANCE:
					is_safe_position = false
				else:
					# Check if rock is in front of player
					var to_rock = (spawn_pos - player.global_position).normalized()
					var angle = rad_to_deg(acos(to_rock.dot(player.facing_direction)))
					if angle < SAFE_FORWARD_ANGLE:
						is_safe_position = false
			
			should_be_dangerous = is_safe_position
	
	# Make the rock dangerous only if position is safe
	if should_be_dangerous:
		rock.make_dangerous()
	
	# Ensure rocks don't spawn too close to each other
	for other_rock in get_tree().get_nodes_in_group("rock"):
		if other_rock != rock and other_rock.position.distance_to(rock.position) < 2.0:
			rock.queue_free()
			spawn_rock(force_safe)  # Try again
			return

func on_food_collected(points: int):
	if is_game_over:
		return

	var player = gameplay_container.get_node_or_null("Player")
	update_score(points)
	spawn_food()
	
	# Spawn new rock every ROCKS_SPAWN_INTERVAL food collections
	if player.food_eaten % ROCKS_SPAWN_INTERVAL == 0:
		spawn_rock()

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
	if is_game_over:
		return

	is_game_over = true
	Engine.time_scale = 0.5  # Slow the game to half speed instead of pausing
	is_gameplay_paused = false  # Ensure gameplay pause is cleared
	update_pause_state()
	ui.show_game_over(score)

func return_to_main_menu():
	save_game_state()
	Engine.time_scale = 1.0  # Restore normal time scale
	get_tree().paused = false
	is_paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func save_and_quit():
	save_game_state()
	Engine.time_scale = 1.0  # Restore normal time scale
	get_tree().paused = false
	is_paused = false
	get_tree().quit()

func save_game_state():
	if is_game_over:
		return

	var player = gameplay_container.get_node_or_null("Player")
	var food = get_tree().get_first_node_in_group("food")
	var rocks = get_tree().get_nodes_in_group("rock")
	
	if not player or not food:
		print("Warning: Could not find valid player or food when saving")
		return
	
	var rock_data = []
	for rock in rocks:
		if rock.has_method("get_save_data"):
			rock_data.append(rock.get_save_data())
	
	var save_data = {
		"score": score,
		"player_state": player.get_save_data(),
		"food_position": {
			"x": food.position.x,
			"y": food.position.y,
			"z": food.position.z
		},
		"rocks": rock_data
	}
	GameState.save_game_state(save_data)

func load_game_state():
	var save_data = GameState.load_game_state()
	if save_data.is_empty():
		spawn_player()
		spawn_food()
		spawn_initial_rocks()
		return false
		
	# Spawn and setup player
	var player = PLAYER_SCENE.instantiate()
	gameplay_container.add_child(player)
	
	# First set the player's position and state
	player.restore_from_save(save_data)
	
	# Then restore segments with their growth states in reverse order
	if save_data["player_state"].has("segments"):
		# Process segments in reverse order for proper chain formation
		var segments = save_data["player_state"]["segments"] as Array
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
			segment.init_from_save_data(segment_data)
	
	# Spawn and setup food
	var food = FOOD_SCENE.instantiate()
	gameplay_container.add_child(food)
	food.position = Vector3(
		float(save_data["food_position"]["x"]),
		float(save_data["food_position"]["y"]),
		float(save_data["food_position"]["z"])
	)
	
	# Load rocks
	if save_data.has("rocks"):
		for rock_data in save_data.rocks:
			var rock = ROCK_SCENE.instantiate()
			gameplay_container.add_child(rock)
			
			var pos = Vector3(
				float(rock_data.position.x),
				float(rock_data.position.y),
				float(rock_data.position.z)
			)
			
			# Initialize the rock properly first
			rock.initialize(pos)
			
			# Then set any saved properties
			if rock_data.has("velocity"):
				rock.velocity = Vector3(
					float(rock_data.velocity.x),
					float(rock_data.velocity.y),
					float(rock_data.velocity.z)
				)
			if rock_data.get("is_dangerous", false):
				rock.make_dangerous()
			
			# Skip spawn animation for loaded rocks
			rock.finish_spawn()
	
	score = save_data["score"]
	update_score(0)
	return true

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game_state()
		get_tree().quit()
