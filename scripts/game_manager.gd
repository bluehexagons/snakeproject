extends Node3D

const PLAYER_SCENE = preload("res://scenes/player.tscn")
const FOOD_SCENE = preload("res://scenes/food.tscn")
const ROCK_SCENE = preload("res://scenes/rock.tscn")
const SCORE_POPUP = preload("res://scenes/score_popup.tscn")
const SPAWN_AREA_SIZE = Vector2(8, 8)
const PLAYER_SPAWN_HEIGHT = 0.5

const INITIAL_ROCKS = 10
const ROCKS_SPAWN_INTERVAL = 2
const DANGER_START_SCORE = 50
const DANGER_MAX_SCORE = 300
const MAX_DANGER_PROBABILITY = 0.8

const SAFE_SPAWN_DISTANCE = 4.0
const SAFE_FORWARD_ANGLE = 60.0

const MIN_FOOD_COUNT = 3
const MAX_FOOD_COUNT = 5
const MIN_FOOD_DISTANCE = 3.0
const PREFERRED_PLAYER_DISTANCE = 8.0
const MIN_PLAYER_DISTANCE = 2.0
const MIN_FOOD_DANGER_DISTANCE = 1.5
const MIN_FOOD_ROCK_DISTANCE = 1.0
const MIN_ROCK_PLAYER_DISTANCE = 2.5
const MAX_FOOD_SPAWN_ATTEMPTS = 30
const MAX_RELAXED_FOOD_SPAWN_ATTEMPTS = 10
const MAX_ROCK_SPAWN_ATTEMPTS = 30
const MAX_SCORE = 2147483647
const AUTOSAVE_INTERVAL = 5.0
const DEBUG_TRACE_SAMPLE_INTERVAL = 0.1
const DEBUG_RANDOM_SEED = 1337

var is_paused: bool = false
var is_gameplay_paused: bool = false
var is_game_over: bool = false

var score: int = 0
var is_new_best: bool = false
var is_quitting: bool = false
var autosave_elapsed: float = 0.0
var debug_trace_elapsed: float = 0.0
var debug_trace_time: float = 0.0
var player: Player

@onready var camera: GameCamera = $GameplayContainer/Camera3D
@onready var ui: GameUI = $UI
@onready var gameplay_container: Node3D = $GameplayContainer
@onready var world_environment: WorldEnvironment = $WorldEnvironment

func _ready() -> void:
	Engine.time_scale = 1.0
	if DebugTelemetry.can_capture():
		seed(DEBUG_RANDOM_SEED)
	_configure_renderer_features()
	_connect_ui()
	load_game_state()
	update_score(0)
	_start_debug_trace()

func _configure_renderer_features() -> void:
	if world_environment and world_environment.environment:
		world_environment.environment.volumetric_fog_enabled = RenderingServer.get_current_rendering_method() == "forward_plus"

func _connect_ui() -> void:
	ui.resume_requested.connect(_on_resume_requested)
	ui.quit_requested.connect(save_and_quit)
	ui.retry_requested.connect(_on_retry_requested)
	ui.main_menu_requested.connect(return_to_main_menu)

func _process(delta: float) -> void:
	if is_game_over or is_paused or is_gameplay_paused or not is_instance_valid(player):
		return

	autosave_elapsed += maxf(delta, 0.0)
	if autosave_elapsed < AUTOSAVE_INTERVAL:
		return

	autosave_elapsed = fmod(autosave_elapsed, AUTOSAVE_INTERVAL)
	# Browser tabs can be refreshed or closed without sending a reliable close
	# notification, so keep the resumable session reasonably current.
	save_game_state()

func _physics_process(delta: float) -> void:
	if not DebugTelemetry.enabled or is_paused or is_gameplay_paused or is_game_over:
		return

	debug_trace_elapsed += maxf(delta, 0.0)
	debug_trace_time += maxf(delta, 0.0)
	if debug_trace_elapsed < DEBUG_TRACE_SAMPLE_INTERVAL:
		return

	debug_trace_elapsed = fmod(debug_trace_elapsed, DEBUG_TRACE_SAMPLE_INTERVAL)
	DebugTelemetry.record_sample(_build_debug_trace_sample())

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
	if is_gameplay_paused:
		DebugTelemetry.publish_trace()
	else:
		_start_debug_trace()

func toggle_pause() -> void:
	if is_game_over:
		return

	is_paused = !is_paused
	if is_paused and is_gameplay_paused:
		is_gameplay_paused = false
		ui.set_gameplay_paused(false)
	update_pause_state()
	ui.toggle_pause_menu(is_paused)

func update_pause_state() -> void:
	gameplay_container.process_mode = Node.PROCESS_MODE_DISABLED if (is_paused or is_gameplay_paused) else Node.PROCESS_MODE_INHERIT

func _start_debug_trace() -> void:
	if not DebugTelemetry.can_capture():
		return

	debug_trace_elapsed = 0.0
	debug_trace_time = 0.0
	var run_id = "%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_msec()]
	DebugTelemetry.start_capture(run_id, {
		"project_version": ProjectSettings.get_setting("application/config/version", "unversioned"),
		"godot": Engine.get_version_info().get("string", "unknown"),
		"physics_backend": ProjectSettings.get_setting("physics/3d/physics_engine", "unknown"),
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"debug_build": OS.is_debug_build(),
		"max_bodies": DebugTelemetry.MAX_BODIES,
		"max_contacts_reported": PhysicsObject.MAX_CONTACTS,
		"random_seed": DEBUG_RANDOM_SEED,
	})

func _build_debug_trace_sample() -> Dictionary:
	var bodies: Array[Dictionary] = []
	var physics_objects = get_tree().get_nodes_in_group("physics_object")
	physics_objects.sort_custom(func(first, second): return first.get_instance_id() < second.get_instance_id())
	for body in physics_objects.slice(0, DebugTelemetry.MAX_BODIES):
		if not body is PhysicsObject or not is_instance_valid(body):
			continue
		bodies.append({
			"id": str(body.get_instance_id()),
			"kind": _debug_body_kind(body),
			"position": DebugTelemetry.encode_vector(body.global_position, "bodies.%s.position" % body.get_instance_id()),
			"linear_velocity": DebugTelemetry.encode_vector(body.linear_velocity, "bodies.%s.linear_velocity" % body.get_instance_id()),
			"angular_velocity": DebugTelemetry.encode_vector(body.angular_velocity, "bodies.%s.angular_velocity" % body.get_instance_id()),
		})

	var links: Array[Dictionary] = []
	if is_instance_valid(player):
		for segment in player.segments:
			if not is_instance_valid(segment) or not is_instance_valid(segment.target):
				continue
			var distance = segment.global_position.distance_to(segment.target.global_position)
			links.append({
				"segment_id": str(segment.get_instance_id()),
				"target_id": str(segment.target.get_instance_id()),
				"distance": DebugTelemetry.encode_number(distance, "links.%s.distance" % segment.get_instance_id()),
				"rest_length": SegmentConstants.TARGET_DISTANCE,
				"error": DebugTelemetry.encode_number(distance - SegmentConstants.TARGET_DISTANCE, "links.%s.error" % segment.get_instance_id()),
			})

	var foods: Array[Dictionary] = []
	for food in get_tree().get_nodes_in_group("food"):
		if not is_instance_valid(food) or food.is_queued_for_deletion() or not food.is_available():
			continue
		foods.append({
			"id": str(food.get_instance_id()),
			"position": DebugTelemetry.encode_vector(food.global_position, "foods.%s.position" % food.get_instance_id()),
		})

	return {
		"physics_tick": Engine.get_physics_frames(),
		"capture_time": debug_trace_time,
		"bodies": bodies,
		"links": links,
		"foods": foods,
		"gameplay": {
			"score": score,
			"paused": is_paused or is_gameplay_paused,
			"lost": is_game_over,
			"active_input": Input.get_vector("move_left", "move_right", "move_up", "move_down").length_squared() > 0.0,
			"inactivity": 0.0,
		},
	}

func _debug_body_kind(body: PhysicsObject) -> String:
	if body.is_in_group("player"):
		return "player"
	if body.is_in_group("segment"):
		return "segment"
	if body.is_in_group("rock"):
		return "rock"
	return "physics_object"

func spawn_player() -> Player:
	player = PLAYER_SCENE.instantiate()
	gameplay_container.add_child(player)
	_bind_player(player)
	
	var random_x = randf_range(-SPAWN_AREA_SIZE.x, SPAWN_AREA_SIZE.x)
	var random_z = randf_range(-SPAWN_AREA_SIZE.y, SPAWN_AREA_SIZE.y)
	# Start the sphere clear of the floor instead of half-embedded, which can
	# make the solver resolve the initial overlap through the ground.
	player.position = Vector3(random_x, PLAYER_SPAWN_HEIGHT, random_z)
	player.rebuild_trail()
	return player

func _bind_player(new_player: Player) -> void:
	player = new_player
	player.food_collected.connect(_on_player_food_collected, CONNECT_DEFERRED)
	player.score_earned.connect(_on_player_score_earned)
	player.player_lost.connect(_on_player_lost)
	ui.set_player(player)

func spawn_food(force_spawn: bool = false) -> bool:
	var available_food = get_tree().get_nodes_in_group("food").filter(func(f): return not f.is_queued_for_deletion() and f.is_available())
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
	var current_player: Player = player if is_instance_valid(player) else null
	
	for _attempt in range(MAX_FOOD_SPAWN_ATTEMPTS):
		var random_x = randf_range(-SPAWN_AREA_SIZE.x * 0.9, SPAWN_AREA_SIZE.x * 0.9)
		var random_z = randf_range(-SPAWN_AREA_SIZE.y * 0.9, SPAWN_AREA_SIZE.y * 0.9)
		var pos = Vector3(random_x, 0, random_z)
		
		var min_distance_to_danger = INF
		var min_distance_to_rock = INF
		var min_distance_to_food = INF
		var distance_to_player = INF if not current_player else current_player.global_position.distance_to(pos)
		
		if current_player and distance_to_player < MIN_PLAYER_DISTANCE:
			continue
		
		for node in get_tree().get_nodes_in_group("dangerous"):
			if not node.is_queued_for_deletion():
				min_distance_to_danger = min(min_distance_to_danger, _horizontal_distance(node.global_position, pos))
		
		for rock in get_tree().get_nodes_in_group("rock"):
			if not rock.is_queued_for_deletion():
				min_distance_to_rock = min(min_distance_to_rock, _horizontal_distance(rock.global_position, pos))
		
		for other_food in available_food:
			if other_food != food:
				min_distance_to_food = min(min_distance_to_food, _horizontal_distance(other_food.global_position, pos))
		
		if min_distance_to_danger > MIN_FOOD_DANGER_DISTANCE and min_distance_to_rock > MIN_FOOD_ROCK_DISTANCE and min_distance_to_food > MIN_FOOD_DISTANCE:
			var base_spacing = min(min_distance_to_danger, min(min_distance_to_rock, min_distance_to_food))
			
			var position_score = base_spacing
			if current_player:
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
	var current_player: Player = player if is_instance_valid(player) else null
	var available_food = get_tree().get_nodes_in_group("food").filter(func(f): return f != food and not f.is_queued_for_deletion() and f.is_available())
	
	for _attempt in range(MAX_RELAXED_FOOD_SPAWN_ATTEMPTS):
		var random_x = randf_range(-SPAWN_AREA_SIZE.x * 0.8, SPAWN_AREA_SIZE.x * 0.8)
		var random_z = randf_range(-SPAWN_AREA_SIZE.y * 0.8, SPAWN_AREA_SIZE.y * 0.8)
		var pos = Vector3(random_x, 0, random_z)
		if current_player and _horizontal_distance(current_player.global_position, pos) < MIN_PLAYER_DISTANCE:
			continue
		
		var valid = true
		for node in get_tree().get_nodes_in_group("dangerous"):
			if not node.is_queued_for_deletion() and _horizontal_distance(node.global_position, pos) < 1.0:
				valid = false
				break
		if valid:
			for rock in get_tree().get_nodes_in_group("rock"):
				if not rock.is_queued_for_deletion() and _horizontal_distance(rock.global_position, pos) < MIN_FOOD_ROCK_DISTANCE:
					valid = false
					break
		if valid:
			for other_food in available_food:
				if _horizontal_distance(other_food.global_position, pos) < MIN_FOOD_DISTANCE * 0.5:
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
	var current_player: Player = player if is_instance_valid(player) else null
	for _attempt in range(MAX_ROCK_SPAWN_ATTEMPTS):
		var random_x = randf_range(-SPAWN_AREA_SIZE.x, SPAWN_AREA_SIZE.x)
		var random_z = randf_range(-SPAWN_AREA_SIZE.y, SPAWN_AREA_SIZE.y)
		var spawn_pos = Vector3(random_x, 0, random_z)
		if current_player and _horizontal_distance(current_player.global_position, spawn_pos) < MIN_ROCK_PLAYER_DISTANCE:
			continue

		var overlaps_rock = false
		for other_rock in get_tree().get_nodes_in_group("rock"):
			if not other_rock.is_queued_for_deletion() and _horizontal_distance(other_rock.position, spawn_pos) < 2.0:
				overlaps_rock = true
				break
		if overlaps_rock:
			continue
		var overlaps_food = false
		for food in get_tree().get_nodes_in_group("food"):
			if food.is_available() and _horizontal_distance(food.position, spawn_pos) < MIN_FOOD_ROCK_DISTANCE:
				overlaps_food = true
				break
		if overlaps_food:
			continue

		var rock = ROCK_SCENE.instantiate()
		gameplay_container.add_child(rock)
		rock.setup_rock(spawn_pos)

		var should_be_dangerous = false
		if !force_safe && score >= DANGER_START_SCORE:
			var score_factor = clamp(float(score - DANGER_START_SCORE) / (DANGER_MAX_SCORE - DANGER_START_SCORE), 0.0, 1.0)
			if randf() < score_factor * MAX_DANGER_PROBABILITY:
				var is_safe_position = true
				if current_player:
					var dist_to_player = _horizontal_distance(current_player.global_position, spawn_pos)
					if dist_to_player < SAFE_SPAWN_DISTANCE:
						is_safe_position = false
					else:
						var to_rock = spawn_pos - current_player.global_position
						to_rock.y = 0.0
						to_rock = to_rock.normalized()
						var facing = current_player.facing_direction
						facing.y = 0.0
						facing = facing.normalized() if facing.length_squared() > 0.001 else Vector3.FORWARD
						var angle = rad_to_deg(acos(clampf(to_rock.dot(facing), -1.0, 1.0)))
						if angle < SAFE_FORWARD_ANGLE:
							is_safe_position = false
				should_be_dangerous = is_safe_position

		if should_be_dangerous:
			rock.make_dangerous()

		return true

	push_warning("Failed to spawn a rock after %d attempts" % MAX_ROCK_SPAWN_ATTEMPTS)
	return false

func add_score(points: int):
	if is_game_over:
		return
	
	update_score(points)

func _on_player_food_collected(total_food_eaten: int) -> void:
	if is_game_over:
		return

	if total_food_eaten % ROCKS_SPAWN_INTERVAL == 0:
		spawn_rock()
	
	var available_food = get_tree().get_nodes_in_group("food").filter(func(f): return not f.is_queued_for_deletion() and f.is_available())
	var current_food_count = available_food.size()
	
	while current_food_count < MIN_FOOD_COUNT:
		if not spawn_food(true):
			break
		current_food_count += 1

func _on_player_score_earned(points: int, popup_position: Vector3) -> void:
	if is_game_over:
		return
	add_score(points)
	var popup = SCORE_POPUP.instantiate()
	popup.position = popup_position
	popup.text = "+" + str(points)
	gameplay_container.add_child(popup)

func _on_player_lost() -> void:
	game_over()

func _on_resume_requested() -> void:
	Engine.time_scale = 1.0
	toggle_pause()

func _on_retry_requested() -> void:
	if not GameState.delete_save_game():
		push_warning("Unable to clear the saved game for retry")
		return
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()

func update_score(points: int) -> void:
	var previous_best = GameState.get_best_score()
	score = clampi(score + points, 0, MAX_SCORE)
	if score > previous_best:
		is_new_best = true
		if not GameState.save_best_score(score):
			push_warning("Unable to save the best score")
	if ui:
		ui.update_score(score)

func game_over():
	if is_game_over:
		return

	is_game_over = true
	GameState.delete_save_game()
	if not GameState.save_best_score(score):
		push_warning("Unable to save the best score")
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
	if is_quitting:
		return
	is_quitting = true
	save_game_state()
	Engine.time_scale = 1.0
	get_tree().paused = false
	is_paused = false
	get_tree().quit()

func save_game_state() -> void:
	if is_game_over:
		return

	if not is_instance_valid(player) or player.is_dead:
		return
		
	var foods = get_tree().get_nodes_in_group("food")
	var rocks = get_tree().get_nodes_in_group("rock")
	
	var food_positions: Array[Dictionary] = []
	for food in foods:
		if food.is_queued_for_deletion() or not food.is_available():
			continue
		food_positions.append({
			"x": food.position.x,
			"y": 0.0,
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
	if not GameState.save_game_state(save_data):
		push_warning("Unable to save the current game state")

func load_game_state() -> bool:
	for food in get_tree().get_nodes_in_group("food"):
		food.queue_free()
	
	var save_data = GameState.load_game_state()
	if save_data.is_empty() or not GameState.is_valid_save_data(save_data):
		if not save_data.is_empty():
			push_warning("Ignoring invalid save data and starting a new game")
			GameState.delete_save_game()
		spawn_player()
		spawn_initial_food()
		spawn_initial_rocks()
		return false
		
	player = PLAYER_SCENE.instantiate()
	gameplay_container.add_child(player)
	player.restore_from_save(save_data)
	_bind_player(player)

	var player_state: Dictionary = save_data["player_state"]
	if player_state.has("segments") and player_state["segments"] is Array:
		var segments: Array = player_state["segments"]
		for i in range(segments.size()):
			var segment_data: Dictionary = segments[i] if segments[i] is Dictionary else {}
			var segment = player.add_segment(0.0, _vector_from_data(segment_data.get("position")), true)
			if not segment:
				continue
			segment.init_from_save_data(segment_data)
	
	player.rebuild_trail()
	if player_state.has("trail") and not player_state.trail.is_empty():
		player.trail.clear()
		for point in player_state.trail:
			var restored_point = _vector_from_data(point)
			# Segment restore repairs fallen pieces; repair their path too so
			# the next physics tick cannot send them underground again.
			restored_point.y = 0.35
			player.trail.append(restored_point)
	var saved_food_positions: Variant = save_data.get("food_positions", [])
	if saved_food_positions is Array and not saved_food_positions.is_empty():
		for food_pos in saved_food_positions:
			if not food_pos is Dictionary:
				continue
			var food = FOOD_SCENE.instantiate()
			gameplay_container.add_child(food)
			food.position = _vector_from_data(food_pos)
			food.position.y = 0.0
	else:
		spawn_initial_food()
	
	var saved_rocks: Variant = save_data.get("rocks", [])
	if saved_rocks is Array:
		for rock_data in saved_rocks:
			if not rock_data is Dictionary:
				continue
			var rock = ROCK_SCENE.instantiate()
			gameplay_container.add_child(rock)
			rock.restore_from_save_data(rock_data)
	
	score = max(int(save_data.get("score", 0)), 0)
	update_score(0)
	return true

func _horizontal_distance(first: Vector3, second: Vector3) -> float:
	return Vector2(first.x, first.z).distance_to(Vector2(second.x, second.z))

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
		if is_quitting:
			return
		is_quitting = true
		save_game_state()
		get_tree().quit()
