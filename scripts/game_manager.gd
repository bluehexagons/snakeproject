extends Node3D

const PLAYER_SCENE = preload("res://scenes/player.tscn")
const FOOD_SCENE = preload("res://scenes/food.tscn")
const ROCK_SCENE = preload("res://scenes/rock.tscn")
const SPAWN_AREA_SIZE = Vector2(8, 8)

const INITIAL_ROCKS = 10
const ROCKS_SPAWN_INTERVAL = 2
const DANGER_START_SCORE = 50
const DANGER_MAX_SCORE = 300
const MAX_DANGER_PROBABILITY = 0.8

const SAFE_SPAWN_DISTANCE = 4.0
const SAFE_FORWARD_ANGLE = 60.0

const MIN_FOOD_COUNT = 1
const MAX_FOOD_COUNT = 5
const MIN_FOOD_DISTANCE = 3.0
const PREFERRED_PLAYER_DISTANCE = 8.0
const MIN_PLAYER_DISTANCE = 2.0
const MIN_FOOD_DANGER_DISTANCE = 1.5
const MIN_FOOD_ROCK_DISTANCE = 0.25
const MAX_FOOD_SPAWN_ATTEMPTS = 30
const MAX_RELAXED_FOOD_SPAWN_ATTEMPTS = 10
const MAX_ROCK_SPAWN_ATTEMPTS = 30

var is_paused: bool = false
var is_gameplay_paused: bool = false
var is_game_over: bool = false

var score: int = 0
var is_new_best: bool = false

@onready var camera: Camera3D = $GameplayContainer/Camera3D
@onready var ui: Control = $UI
@onready var gameplay_container: Node3D = $GameplayContainer

func _ready() -> void:
	load_game_state()
	update_score(0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_camera_angle"):
		camera.toggle_view()
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()
	elif event.is_action_pressed("gameplay_pause"):
		if !is_paused:
			toggle_gameplay_pause()
func toggle_gameplay_pause() -> void:
	if is_game_over:
		return

	is_gameplay_paused = not is_gameplay_paused
	update_pause_state()
	if ui:
		ui.set_gameplay_paused(is_gameplay_paused)

func toggle_pause() -> void:
	if is_game_over:
		return

	is_paused = !is_paused
	update_pause_state()
	ui.toggle_pause_menu(is_paused)

func update_pause_state() -> void:
	gameplay_container.process_mode = Node.PROCESS_MODE_DISABLED if (is_paused or is_gameplay_paused) else Node.PROCESS_MODE_INHERIT

func spawn_player() -> void:
	var player = PLAYER_SCENE.instantiate()
	gameplay_container.add_child(player)
	
	var random_x = randf_range(-SPAWN_AREA_SIZE.x, SPAWN_AREA_SIZE.x)
	var random_z = randf_range(-SPAWN_AREA_SIZE.y, SPAWN_AREA_SIZE.y)
	player.position = Vector3(random_x, 0, random_z)

func spawn_food(force_spawn: bool = false) -> bool:
	var available_food = get_tree().get_nodes_in_group("food").filter(func(f): return f.is_available())
	var current_count = available_food.size()
	
	if current_count >= MAX_FOOD_COUNT:
		return false
	
	if !force_spawn and current_count >= MIN_FOOD_COUNT:
		return false
	
	var food = FOOD_SCENE.instantiate()
	gameplay_container.add_child(food)
	
	var valid_position = false
	var best_distance = 0.0
	var best_position = Vector3.ZERO
	var player = gameplay_container.get_node_or_null("Player")
	
	for _attempt in range(MAX_FOOD_SPAWN_ATTEMPTS):
		var random_x = randf_range(-SPAWN_AREA_SIZE.x * 0.9, SPAWN_AREA_SIZE.x * 0.9)
		var random_z = randf_range(-SPAWN_AREA_SIZE.y * 0.9, SPAWN_AREA_SIZE.y * 0.9)
		var pos = Vector3(random_x, 0, random_z)
		
		var min_distance_to_danger = INF
		var min_distance_to_rock = INF
		var min_distance_to_food = INF
		var distance_to_player = INF if not player else player.global_position.distance_to(pos)
		
		if player and distance_to_player < MIN_PLAYER_DISTANCE:
			continue
		
		for node in get_tree().get_nodes_in_group("dangerous"):
			min_distance_to_danger = min(min_distance_to_danger, node.global_position.distance_to(pos))
		
		for rock in get_tree().get_nodes_in_group("rock"):
			min_distance_to_rock = min(min_distance_to_rock, rock.global_position.distance_to(pos))
		
		for other_food in available_food:
			if other_food != food:
				min_distance_to_food = min(min_distance_to_food, other_food.global_position.distance_to(pos))
		
		if min_distance_to_danger > MIN_FOOD_DANGER_DISTANCE and min_distance_to_rock > MIN_FOOD_ROCK_DISTANCE and min_distance_to_food > MIN_FOOD_DISTANCE:
			var base_spacing = min(min_distance_to_danger, min(min_distance_to_rock, min_distance_to_food))
			
			var position_score = base_spacing
			if player:
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
	
	print("Failed to spawn food after %d attempts" % MAX_FOOD_SPAWN_ATTEMPTS)
	food.queue_free()
	
	if force_spawn:
		push_warning("Retrying force spawn with relaxed constraints")
		return spawn_food_relaxed()
	
	return false

func spawn_food_relaxed() -> bool:
	var food = FOOD_SCENE.instantiate()
	gameplay_container.add_child(food)
	
	for _attempt in range(MAX_RELAXED_FOOD_SPAWN_ATTEMPTS):
		var random_x = randf_range(-SPAWN_AREA_SIZE.x * 0.8, SPAWN_AREA_SIZE.x * 0.8)
		var random_z = randf_range(-SPAWN_AREA_SIZE.y * 0.8, SPAWN_AREA_SIZE.y * 0.8)
		var pos = Vector3(random_x, 0, random_z)
		
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

func spawn_initial_rocks() -> void:
	for i in range(INITIAL_ROCKS):
		spawn_rock(true)

func spawn_rock(force_safe: bool = false) -> bool:
	var player = gameplay_container.get_node_or_null("Player")
	for _attempt in range(MAX_ROCK_SPAWN_ATTEMPTS):
		var rock = ROCK_SCENE.instantiate()
		gameplay_container.add_child(rock)

		var random_x = randf_range(-SPAWN_AREA_SIZE.x, SPAWN_AREA_SIZE.x)
		var random_z = randf_range(-SPAWN_AREA_SIZE.y, SPAWN_AREA_SIZE.y)
		var spawn_pos = Vector3(random_x, 0, random_z)
		rock.setup_rock(spawn_pos)

		var should_be_dangerous = false
		if !force_safe && score >= DANGER_START_SCORE:
			var score_factor = clamp(float(score - DANGER_START_SCORE) / (DANGER_MAX_SCORE - DANGER_START_SCORE), 0.0, 1.0)
			if randf() < score_factor * MAX_DANGER_PROBABILITY:
				var is_safe_position = true
				if player:
					var dist_to_player = player.global_position.distance_to(spawn_pos)
					if dist_to_player < SAFE_SPAWN_DISTANCE:
						is_safe_position = false
					else:
						var to_rock = (spawn_pos - player.global_position).normalized()
						var angle = rad_to_deg(acos(clampf(to_rock.dot(player.facing_direction), -1.0, 1.0)))
						if angle < SAFE_FORWARD_ANGLE:
							is_safe_position = false
				should_be_dangerous = is_safe_position

		if should_be_dangerous:
			rock.make_dangerous()

		var overlaps_rock = false
		for other_rock in get_tree().get_nodes_in_group("rock"):
			if other_rock != rock and not other_rock.is_queued_for_deletion() and other_rock.position.distance_to(rock.position) < 2.0:
				overlaps_rock = true
				break
		if not overlaps_rock:
			return true
		rock.queue_free()

	push_warning("Failed to spawn a rock after %d attempts" % MAX_ROCK_SPAWN_ATTEMPTS)
	return false

func add_score(points: int):
	if is_game_over:
		return
	
	update_score(points)

func on_food_collected():
	if is_game_over:
		return

	var player = gameplay_container.get_node_or_null("Player")
	
	if player.food_eaten % ROCKS_SPAWN_INTERVAL == 0:
		spawn_rock()
	
	var available_food = get_tree().get_nodes_in_group("food").filter(func(f): return f.is_available())
	var current_food_count = available_food.size()
	
	if current_food_count < MIN_FOOD_COUNT:
		spawn_food()

func update_score(points: int) -> void:
	var previous_best = GameState.get_best_score()
	score += points
	if score > previous_best:
		is_new_best = true
		GameState.save_best_score(score)
	if ui:
		ui.update_score(score)

func game_over():
	if is_game_over:
		return

	is_game_over = true
	GameState.save_best_score(score)
	Engine.time_scale = 0.5
	is_gameplay_paused = false
	update_pause_state()
	ui.show_game_over(score, GameState.get_best_score(), is_new_best)

func return_to_main_menu():
	save_game_state()
	Engine.time_scale = 1.0
	get_tree().paused = false
	is_paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func save_and_quit():
	save_game_state()
	Engine.time_scale = 1.0
	get_tree().paused = false
	is_paused = false
	get_tree().quit()

func save_game_state() -> void:
	if is_game_over:
		return

	var player = gameplay_container.get_node_or_null("Player")
	if not player or not player.is_in_group("player") or player.get("is_dead"):
		return
		
	var foods = get_tree().get_nodes_in_group("food")
	var rocks = get_tree().get_nodes_in_group("rock")
	
	var food_positions: Array[Dictionary] = []
	for food in foods:
		if not food.is_available():
			continue
		food_positions.append({
			"x": food.position.x,
			"y": food.position.y,
			"z": food.position.z
		})
	
	var rock_data: Array[Dictionary] = []
	for rock in rocks:
		if rock.is_queued_for_deletion():
			continue
		if rock.has_method("get_save_data"):
			rock_data.append(rock.get_save_data())
	
	var save_data = {
		"score": score,
		"player_state": player.get_save_data(),
		"food_positions": food_positions,
		"rocks": rock_data
	}
	GameState.save_game_state(save_data)

func load_game_state() -> bool:
	for food in get_tree().get_nodes_in_group("food"):
		food.queue_free()
	
	var save_data = GameState.load_game_state()
	if save_data.is_empty() or not _is_valid_save_data(save_data):
		if not save_data.is_empty():
			push_warning("Ignoring invalid save data and starting a new game")
		spawn_player()
		spawn_initial_food()
		spawn_initial_rocks()
		return false
		
	var player = PLAYER_SCENE.instantiate()
	gameplay_container.add_child(player)
	player.restore_from_save(save_data)
	
	var player_state: Dictionary = save_data["player_state"]
	if player_state.has("segments") and player_state["segments"] is Array:
		var segments: Array = player_state["segments"]
		for i in range(segments.size() - 1, -1, -1):
			var segment_data: Dictionary = segments[i] if segments[i] is Dictionary else {}
			var segment = player.add_segment(0.0, _vector_from_data(segment_data.get("position")), true)
			if not segment:
				continue
			segment.init_from_save_data(segment_data)
	
	var saved_food_positions: Variant = save_data.get("food_positions", [])
	if saved_food_positions is Array and not saved_food_positions.is_empty():
		for food_pos in saved_food_positions:
			if not food_pos is Dictionary:
				continue
			var food = FOOD_SCENE.instantiate()
			gameplay_container.add_child(food)
			food.position = _vector_from_data(food_pos)
	else:
		spawn_initial_food()
	
	var saved_rocks: Variant = save_data.get("rocks", [])
	if saved_rocks is Array:
		for rock_data in saved_rocks:
			if not rock_data is Dictionary:
				continue
			var rock = ROCK_SCENE.instantiate()
			gameplay_container.add_child(rock)

			rock.setup_rock(_vector_from_data(rock_data.get("position")))
			
			if rock_data.has("velocity"):
				rock.cached_velocity = _vector_from_data(rock_data.velocity)
			if rock_data.get("is_dangerous", false):
				rock.make_dangerous()
			
			rock.finish_spawn()
	
	score = max(int(save_data.get("score", 0)), 0)
	update_score(0)
	return true

func _is_valid_save_data(data: Dictionary) -> bool:
	var score_type := typeof(data.get("score"))
	return data.get("player_state") is Dictionary and score_type in [TYPE_INT, TYPE_FLOAT]

func _vector_from_data(data: Variant) -> Vector3:
	if not data is Dictionary:
		return Vector3.ZERO
	return Vector3(
		float(data.get("x", 0.0)),
		float(data.get("y", 0.0)),
		float(data.get("z", 0.0))
	)

func spawn_initial_food() -> void:
	for food in get_tree().get_nodes_in_group("food"):
		food.queue_free()
	
	var success_count = 0
	for i in range(MIN_FOOD_COUNT):
		if spawn_food(true):
			success_count += 1
	
	if success_count < MIN_FOOD_COUNT:
		push_warning("Only spawned " + str(success_count) + " out of " + str(MIN_FOOD_COUNT) + " initial food items")
	
	if success_count == 0:
		var food = FOOD_SCENE.instantiate()
		gameplay_container.add_child(food)
		food.position = Vector3(SPAWN_AREA_SIZE.x * 0.5, 0, SPAWN_AREA_SIZE.y * 0.5)
		print("Emergency food spawn at fixed position")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game_state()
		get_tree().quit()
