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
const PREFERRED_PLAYER_DISTANCE = 8.0  # Quarter of typical 16-unit playfield
const MIN_PLAYER_DISTANCE = 2.0  # Absolute minimum distance from player
const MIN_FOOD_DANGER_DISTANCE = 1.5
const MIN_FOOD_ROCK_DISTANCE = 0.25

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
	load_game_state()
	
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

func spawn_food(force_spawn: bool = false) -> bool:
	# Get only actually available food
	var available_food = get_tree().get_nodes_in_group("food").filter(func(f): return f.is_available())
	var current_count = available_food.size()
	
	# Debug info
	print("Current food count: ", current_count, ", Max: ", MAX_FOOD_COUNT, ", Min: ", MIN_FOOD_COUNT)
	
	# Don't spawn if we're at or above max food count
	if current_count >= MAX_FOOD_COUNT:
		return false
	
	# Only spawn if forcing or below minimum
	if !force_spawn and current_count >= MIN_FOOD_COUNT:
		return false
	
	var food = FOOD_SCENE.instantiate()
	gameplay_container.add_child(food)
	
	var valid_position = false
	var best_distance = 0.0
	var best_position = Vector3.ZERO
	var player = gameplay_container.get_node_or_null("Player")
	
	# Try standard spawning first with preferred distance
	for attempt in range(30):  # Increased attempts
		var random_x = randf_range(-SPAWN_AREA_SIZE.x * 0.9, SPAWN_AREA_SIZE.x * 0.9)
		var random_z = randf_range(-SPAWN_AREA_SIZE.y * 0.9, SPAWN_AREA_SIZE.y * 0.9)
		var pos = Vector3(random_x, 0, random_z)
		
		var min_distance_to_danger = INF
		var min_distance_to_rock = INF
		var min_distance_to_food = INF
		var distance_to_player = INF if not player else player.global_position.distance_to(pos)
		
		# Skip positions too close to player
		if player and distance_to_player < MIN_PLAYER_DISTANCE:
			continue
		
		# Check distances to all relevant objects
		for node in get_tree().get_nodes_in_group("dangerous"):
			min_distance_to_danger = min(min_distance_to_danger, node.global_position.distance_to(pos))
		
		for rock in get_tree().get_nodes_in_group("rock"):
			min_distance_to_rock = min(min_distance_to_rock, rock.global_position.distance_to(pos))
		
		for other_food in available_food:
			if other_food != food:
				min_distance_to_food = min(min_distance_to_food, other_food.global_position.distance_to(pos))
		
		# Position is valid if it meets all minimum distance requirements
		if min_distance_to_danger > MIN_FOOD_DANGER_DISTANCE and min_distance_to_rock > MIN_FOOD_ROCK_DISTANCE and min_distance_to_food > MIN_FOOD_DISTANCE:
				# Calculate score for this position
			var base_spacing = min(min_distance_to_danger, min(min_distance_to_rock, min_distance_to_food))
			
			# Prefer positions farther from player (if player exists)
			var position_score = base_spacing
			if player:
				# Add bonus for being close to preferred distance
				var distance_factor = 1.0 - abs(distance_to_player - PREFERRED_PLAYER_DISTANCE) / PREFERRED_PLAYER_DISTANCE
				position_score *= (1.0 + distance_factor)
			
			if position_score > best_distance:
				best_distance = position_score
				best_position = pos
				valid_position = true
	
	if valid_position:
		food.position = best_position
		print("Food spawned at: ", best_position, " with score: ", best_distance)
		return true
	
	# If we couldn't find a valid position
	print("Failed to spawn food after 30 attempts")
	food.queue_free()
	
	# Retry with relaxed constraints if force spawning
	if force_spawn:
		print("Retrying force spawn with relaxed constraints")
		return spawn_food_relaxed()
	
	return false

func spawn_food_relaxed() -> bool:
	var food = FOOD_SCENE.instantiate()
	gameplay_container.add_child(food)
	
	# Use very relaxed constraints
	for _attempt in range(10):
		var random_x = randf_range(-SPAWN_AREA_SIZE.x * 0.8, SPAWN_AREA_SIZE.x * 0.8)
		var random_z = randf_range(-SPAWN_AREA_SIZE.y * 0.8, SPAWN_AREA_SIZE.y * 0.8)
		var pos = Vector3(random_x, 0, random_z)
		
		# Only check for immediate overlaps
		var valid = true
		for node in get_tree().get_nodes_in_group("dangerous"):
			if node.global_position.distance_to(pos) < 1.0:
				valid = false
				break
		
		if valid:
			food.position = pos
			print("Food force spawned at: ", pos)
			return true
	
	print("Failed to force spawn food even with relaxed constraints")
	food.queue_free()
	return false

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
	
	# Check available food count (excluding those being consumed)
	var available_food = get_tree().get_nodes_in_group("food").filter(func(f): return f.is_available())
	var current_food_count = available_food.size()
	
	# Only spawn new food if we're below minimum
	if current_food_count < MIN_FOOD_COUNT:
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
	# Clear any existing food first
	for food in get_tree().get_nodes_in_group("food"):
		food.queue_free()
	
	var save_data = GameState.load_game_state()
	if save_data.is_empty():
		spawn_player()
		spawn_initial_food()  # Use new function instead of single food spawn
		spawn_initial_rocks()
		return false
		
	# Spawn and setup player
	var player = PLAYER_SCENE.instantiate()
	gameplay_container.add_child(player)
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
	
	# Only spawn food if none were saved
	if save_data.has("food_positions") and !save_data.food_positions.is_empty():
		for food_pos in save_data.food_positions:
			var food = FOOD_SCENE.instantiate()
			gameplay_container.add_child(food)
			food.position = Vector3(
				float(food_pos.x),
				float(food_pos.y),
				float(food_pos.z)
			)
	else:
		# Spawn minimum required food if no saved food exists
		spawn_initial_food()
	
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

func spawn_initial_food():
	# Clear any existing food first
	for food in get_tree().get_nodes_in_group("food"):
		food.queue_free()
	
	# Add error handling for initial spawn
	var success_count = 0
	for i in range(MIN_FOOD_COUNT):
		if spawn_food(true):
			success_count += 1
	
	if success_count < MIN_FOOD_COUNT:
		push_warning("Only spawned " + str(success_count) + " out of " + str(MIN_FOOD_COUNT) + " initial food items")
	
	# Ensure at least one food item exists
	if success_count == 0:
		# Last resort: spawn food at a fixed position
		var food = FOOD_SCENE.instantiate()
		gameplay_container.add_child(food)
		food.position = Vector3(SPAWN_AREA_SIZE.x * 0.5, 0, SPAWN_AREA_SIZE.y * 0.5)
		print("Emergency food spawn at fixed position")

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game_state()
		get_tree().quit()
