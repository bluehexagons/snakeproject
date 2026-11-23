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
const MIN_FOOD_DISTANCE = 3.0
const PREFERRED_PLAYER_DISTANCE = 8.0
const MIN_PLAYER_DISTANCE = 2.0
const MIN_FOOD_DANGER_DISTANCE = 1.5
const MIN_FOOD_ROCK_DISTANCE = 1.0
const MIN_ROCK_PLAYER_DISTANCE = 2.5
const MIN_BODY_SPAWN_DISTANCE = 1.0
const MAX_FOOD_SPAWN_ATTEMPTS = 30
const FALLBACK_FOOD_SPAWN_LIMIT = 9 # The barriers sit at +/-11.
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
var previous_auto_accept_quit: bool
var autosave_elapsed: float = 0.0
var debug_trace_elapsed: float = 0.0
var debug_trace_time: float = 0.0
var player: Player

@onready var camera: GameCamera = $GameplayContainer/Camera3D
@onready var ui: GameUI = $UI
@onready var gameplay_container: Node3D = $GameplayContainer
@onready var world_environment: WorldEnvironment = $WorldEnvironment

func _enter_tree() -> void:
	previous_auto_accept_quit = get_tree().auto_accept_quit
	get_tree().auto_accept_quit = false

func _exit_tree() -> void:
	get_tree().auto_accept_quit = previous_auto_accept_quit

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
	# Rocks can open or cover pickup locations even when the snake hasn't eaten.
	_refill_food(true)
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
	if event.is_echo():
		return
	if event.is_action_pressed("toggle_camera_angle"):
		camera.toggle_view()
		SoundFx.play(SoundFx.Cue.UI, 0.39, 1.20)
	if event.is_action_pressed("ui_cancel"):
		toggle_pause(true)
	elif event.is_action_pressed("gameplay_pause"):
		if !is_paused:
			toggle_gameplay_pause()
func toggle_gameplay_pause() -> void:
	if is_game_over:
		return

	is_gameplay_paused = not is_gameplay_paused
	_play_pause_cue(is_gameplay_paused)
	update_pause_state()
	if ui:
		ui.set_gameplay_paused(is_gameplay_paused)
	if is_gameplay_paused:
		DebugTelemetry.publish_trace()
	else:
		_start_debug_trace()

func toggle_pause(play_cue: bool = false) -> void:
	if is_game_over:
		return

	is_paused = !is_paused
	if play_cue:
		_play_pause_cue(is_paused)
	if is_paused and is_gameplay_paused:
		is_gameplay_paused = false
		ui.set_gameplay_paused(false)
	update_pause_state()
	ui.toggle_pause_menu(is_paused)

func _play_pause_cue(paused: bool) -> void:
	SoundFx.play(SoundFx.Cue.UI, 0.48, 0.81 if paused else 1.12)

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
		"max_contacts_reported": Player.HEAD_MAX_CONTACTS,
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
			"inactivity": player.stuck_elapsed if is_instance_valid(player) else 0.0,
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

func _refill_food(check_covered: bool = false) -> void:
	var foods = get_tree().get_nodes_in_group("food").filter(
		func(food): return not food.is_queued_for_deletion() and food.is_available()
	)
	if not check_covered and foods.size() >= MIN_FOOD_COUNT:
		return

	var hazards = get_tree().get_nodes_in_group("dangerous").filter(
		func(node): return not node.is_queued_for_deletion()
	)
	var rocks = get_tree().get_nodes_in_group("rock").filter(
		func(rock): return not rock.is_queued_for_deletion()
	)
	if check_covered:
		for index in foods.size():
			var food: Food = foods[index]
			var cover_id = _covering_rock_id(food.get_pickup_position(), rocks)
			# Give moving rocks a chance to clear the pickup on their own.
			if cover_id != 0 and cover_id == food.covering_rock_id:
				var replacement: Variant = _find_food_spawn_position(foods, hazards, rocks)
				if replacement != null:
					foods[index] = _spawn_food_at(replacement)
					food.queue_free()
			food.covering_rock_id = cover_id

	while foods.size() < MIN_FOOD_COUNT:
		var spawn_position: Variant = _find_food_spawn_position(foods, hazards, rocks)
		if spawn_position == null:
			break
		foods.append(_spawn_food_at(spawn_position))

func _spawn_food_at(spawn_position: Vector3) -> Food:
	var food: Food = FOOD_SCENE.instantiate()
	food.position = spawn_position
	gameplay_container.add_child(food)
	return food

func _covering_rock_id(point: Vector3, rocks: Array) -> int:
	for rock: Rock in rocks:
		if rock.covers_pickup(point):
			return rock.get_instance_id()
	return 0

func _find_food_spawn_position(foods: Array, hazards: Array, rocks: Array) -> Variant:
	var best_position: Variant = null
	var best_score = 0.0
	var area = SPAWN_AREA_SIZE * 0.9
	for attempt in MAX_FOOD_SPAWN_ATTEMPTS:
		var candidate = Vector3(randf_range(-area.x, area.x), 0, randf_range(-area.y, area.y))
		var candidate_score = _food_spawn_score(candidate, foods, hazards, rocks, MIN_FOOD_DISTANCE)
		if candidate_score > best_score:
			best_score = candidate_score
			best_position = candidate
	if best_position != null:
		return best_position

	# Cover the wider arena if the random sample finds nothing. Only the
	# spacing between food pickups can relax.
	for x in range(-FALLBACK_FOOD_SPAWN_LIMIT, FALLBACK_FOOD_SPAWN_LIMIT + 1):
		for z in range(-FALLBACK_FOOD_SPAWN_LIMIT, FALLBACK_FOOD_SPAWN_LIMIT + 1):
			var candidate = Vector3(x, 0, z)
			var candidate_score = _food_spawn_score(candidate, foods, hazards, rocks, MIN_FOOD_DISTANCE * 0.5)
			if candidate_score > best_score:
				best_score = candidate_score
				best_position = candidate
	return best_position

func _food_spawn_score(candidate: Vector3, foods: Array, hazards: Array, rocks: Array, food_spacing: float) -> float:
	var player_distance = _horizontal_distance(player.global_position, candidate)
	if player_distance < MIN_PLAYER_DISTANCE or _nearest_horizontal_distance(candidate, player.segments) < MIN_BODY_SPAWN_DISTANCE:
		return 0.0
	var hazard_distance = _nearest_horizontal_distance(candidate, hazards)
	if hazard_distance <= MIN_FOOD_DANGER_DISTANCE:
		return 0.0
	var rock_distance = _nearest_horizontal_distance(candidate, rocks)
	if rock_distance <= MIN_FOOD_ROCK_DISTANCE:
		return 0.0
	var food_distance = _nearest_horizontal_distance(candidate, foods)
	if food_distance <= food_spacing:
		return 0.0

	var spacing = minf(hazard_distance, minf(rock_distance, food_distance))
	var distance_factor = maxf(1.0 - absf(player_distance - PREFERRED_PLAYER_DISTANCE) / PREFERRED_PLAYER_DISTANCE, 0.0)
	return (1.0 if is_inf(spacing) else spacing) * (1.0 + distance_factor)

func _nearest_horizontal_distance(position: Vector3, nodes: Array) -> float:
	var nearest = INF
	for node in nodes:
		nearest = minf(nearest, _horizontal_distance(node.global_position, position))
	return nearest

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
		if current_player and _nearest_horizontal_distance(spawn_pos, current_player.segments) < MIN_BODY_SPAWN_DISTANCE:
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
			if not food.is_queued_for_deletion() and food.is_available() and _horizontal_distance(food.position, spawn_pos) < MIN_FOOD_ROCK_DISTANCE:
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

	SoundFx.pickup(total_food_eaten)
	if total_food_eaten % ROCKS_SPAWN_INTERVAL == 0:
		spawn_rock()
	
	_refill_food()

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
	toggle_pause(true)

func _on_retry_requested() -> void:
	if not GameState.delete_save_game():
		push_warning("Unable to clear the saved game for retry")
		return
	SoundFx.play(SoundFx.Cue.UI, 0.53, 1.27)
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
	SoundFx.play(SoundFx.Cue.LOSS)
	GameState.delete_save_game()
	if not GameState.save_best_score(score):
		push_warning("Unable to save the best score")
	Engine.time_scale = 0.5
	is_gameplay_paused = false
	update_pause_state()
	ui.show_game_over(score, GameState.get_best_score(), is_new_best)

func return_to_main_menu() -> void:
	if not _save_before_leaving():
		return
	SoundFx.play(SoundFx.Cue.UI, 0.49, 0.89)
	Engine.time_scale = 1.0
	get_tree().paused = false
	is_paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func save_and_quit() -> void:
	if is_quitting or not _save_before_leaving():
		return
	is_quitting = true
	Engine.time_scale = 1.0
	get_tree().paused = false
	is_paused = false
	get_tree().quit()

func _save_before_leaving() -> bool:
	if save_game_state():
		return true
	if not is_paused:
		toggle_pause()
	ui.show_save_error()
	return false

func save_game_state() -> bool:
	if is_game_over or not is_instance_valid(player) or player.is_dead:
		return true
		
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
		if rock.is_queued_for_deletion() or rock.is_shattering:
			continue
		if rock.has_method("get_save_data"):
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
		_refill_food()
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
			restored_point.y = SegmentConstants.CENTER_HEIGHT
			player.trail.append(restored_point)

	var saved_rocks: Variant = save_data.get("rocks", [])
	if saved_rocks is Array:
		for rock_data in saved_rocks:
			if not rock_data is Dictionary:
				continue
			var rock = ROCK_SCENE.instantiate()
			gameplay_container.add_child(rock)
			rock.restore_from_save_data(rock_data)

	# Replacement food must account for every restored hazard and rock.
	var saved_food_positions: Variant = save_data.get("food_positions", [])
	if saved_food_positions is Array and not saved_food_positions.is_empty():
		for food_pos in saved_food_positions:
			if not food_pos is Dictionary:
				continue
			var food_position = _vector_from_data(food_pos)
			food_position.y = 0.0
			_spawn_food_at(food_position)
	_refill_food()
	

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

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# Alt-Tab and minimizing must not leave a live snake in danger. Resume
		# remains an explicit choice when the player returns to the window.
		if is_node_ready() and not is_game_over:
			if not is_paused and not is_gameplay_paused:
				toggle_pause()
			if not save_game_state() and is_paused:
				ui.show_save_error()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready():
		save_and_quit()
