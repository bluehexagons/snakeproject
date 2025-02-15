extends Node3D

const PLAYER_SCENE = preload("res://scenes/player.tscn")
const FOOD_SCENE = preload("res://scenes/food.tscn")
const ROCK_SCENE = preload("res://scenes/rock.tscn")
const SPAWN_AREA_SIZE = Vector2(8, 8)  # Reduced from previous size to account for barriers

const INITIAL_ROCKS = 10  # Number of rocks to spawn at start
const ROCKS_SPAWN_INTERVAL = 2  # Spawn a new rock every X food collections
const DANGER_START_SCORE = 50  # Score at which rocks start becoming dangerous
const DANGER_MAX_SCORE = 300   # Score at which danger probability peaks
const MAX_DANGER_PROBABILITY = 0.8  # Maximum probability of a rock being dangerous

const SAFE_SPAWN_DISTANCE = 4.0  # Minimum distance from player for dangerous rocks
const SAFE_FORWARD_ANGLE = 60.0  # Angle in degrees to check in front of player

const MIN_FOOD_COUNT = 1  # Minimum number of food items in the world
const MAX_FOOD_COUNT = 5  # Maximum number of food items in the world
const MIN_FOOD_DISTANCE = 3.0  # Minimum distance between food items

var is_isometric: bool = false

var target_camera_pos: Vector3
var target_camera_rot: Vector3

# Camera state
var zoom_timer: float = 0.0
var is_zooming: bool = false

var previous_player_direction: Vector3 = Vector3.FORWARD
var camera_transition: float = 0.0  # 0 = top-down, 1 = third-person

var look_target_pos: Vector3  # Keep track of where we're looking
var predicted_direction: Vector3 = Vector3.FORWARD  # Smoothed prediction vector

# UI state
var is_paused: bool = false # In this state, all game-related features are paused
var is_gameplay_paused: bool = false # In this state, the physics and game logic are paused
var is_game_over: bool = false

# Game state
var score: int = 0

@onready var camera = $GameplayContainer/Camera3D
@onready var ui = $UI
@onready var gameplay_container = $GameplayContainer

# Add toggle state tracking
var was_toggle_pressed: bool = false

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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_camera_angle"):
		camera.toggle_view()
	if event.is_action_pressed("ui_cancel"):  # ESC key
		toggle_pause()
	elif event.is_action_pressed("gameplay_pause"):
		if !is_paused:  # Only toggle gameplay pause when menu isn't open
			toggle_gameplay_pause()

func _process(_delta: float) -> void:
	pass

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
	var current_food_count = get_tree().get_nodes_in_group("food").size() - 1
	
	# Don't spawn if we're at or above minimum food count
	if current_food_count >= MIN_FOOD_COUNT:
		return
		
	# Only spawn enough to reach minimum
	var to_spawn = MIN_FOOD_COUNT - current_food_count
	var max_attempts = 10
	
	for i in range(to_spawn):
		# Don't exceed maximum food count
		if get_tree().get_nodes_in_group("food").size() >= MAX_FOOD_COUNT:
			break
			
		var attempts = 0
		var food = FOOD_SCENE.instantiate()
		gameplay_container.add_child(food)
		
		while attempts < max_attempts:
			var random_x = randf_range(-SPAWN_AREA_SIZE.x, SPAWN_AREA_SIZE.x)
			var random_z = randf_range(-SPAWN_AREA_SIZE.y, SPAWN_AREA_SIZE.y)
			var pos = Vector3(random_x, 0, random_z)
			food.position = pos
			
			# Check distance from dangerous segments, rocks, and other food
			var too_close = false
			
			# Check distance from dangerous objects
			for node in get_tree().get_nodes_in_group("dangerous"):
				if node.global_position.distance_to(pos) < 2.0:
					too_close = true
					break
			
			# Check distance from rocks
			for rock in get_tree().get_nodes_in_group("rock"):
				if rock.global_position.distance_to(pos) < 1.5:
					too_close = true
					break
			
			# Check distance from other food
			for other_food in get_tree().get_nodes_in_group("food"):
				if other_food != food and other_food.global_position.distance_to(pos) < MIN_FOOD_DISTANCE:
					too_close = true
					break
					
			if !too_close:
				break
				
			attempts += 1
		
		if attempts >= max_attempts:
			food.queue_free()  # Remove food if we couldn't find a good spot

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

func add_score(points: int):
	if is_game_over:
		return

	update_score(points)

func on_food_collected():
	if is_game_over:
		return

	var player = gameplay_container.get_node_or_null("Player")
	
	# Only spawn new rock every ROCKS_SPAWN_INTERVAL food collections
	if player.food_eaten % ROCKS_SPAWN_INTERVAL == 0:
		spawn_rock()
	
	# Check if removing this food would put us below minimum
	var current_food_count = get_tree().get_nodes_in_group("food").size()
	if current_food_count <= MIN_FOOD_COUNT:
		# Try to spawn more food to maintain minimum
		spawn_food()

func _on_window_resize():
	pass

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
	if player.is_dead:
		return
		
	var foods = get_tree().get_nodes_in_group("food")
	var rocks = get_tree().get_nodes_in_group("rock")
	
	if not player or foods.is_empty():
		print("Warning: Could not find valid player or food when saving")
		return
	
	var food_positions = []
	for food in foods:
		food_positions.append({
			"x": food.position.x,
			"y": food.position.y,
			"z": food.position.z
		})
	
	var rock_data = []
	for rock in rocks:
		if rock.has_method("get_save_data"):
			rock_data.append(rock.get_save_data())
	
	var save_data = {
		"score": score,
		"player_state": player.get_save_data(),
		"food_positions": food_positions,
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
	if save_data.has("food_positions"):
		for food_pos in save_data.food_positions:
			var food = FOOD_SCENE.instantiate()
			gameplay_container.add_child(food)
			food.position = Vector3(
				float(food_pos.x),
				float(food_pos.y),
				float(food_pos.z)
			)
	else:
		# Backward compatibility for old save files with single food
		if save_data.has("food_position"):
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
