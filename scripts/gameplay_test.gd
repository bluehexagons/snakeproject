extends Node

const MAIN = preload("res://scenes/main.tscn")
const FOOD = preload("res://scenes/food.tscn")
const ROCK = preload("res://scenes/rock.tscn")
var failed = false

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	if GameState.save_file_path.begins_with("user://"):
		push_error("Run tests using scripts/verify_project.py to isolate player saves")
		get_tree().quit(1)
		return
	GameState.delete_save_game()
	var main = MAIN.instantiate()
	add_child(main)
	var player: Player = main.player
	# A controlled empty arena retains real ground, walls, input and physics.
	for group in ["rock", "food"]:
		for node in get_tree().get_nodes_in_group(group):
			node.queue_free()
	player.freeze = true
	player.position = Vector3(0, 0.5, 0)
	await get_tree().physics_frame
	player.freeze = false
	player.rebuild_trail()
	for frame in 30:
		await get_tree().physics_frame
	# Several pickups inside one digestion period must each grow exactly once.
	for index in 6:
		var food = FOOD.instantiate()
		food.position = Vector3(player.position.x, 0, player.position.z)
		main.gameplay_container.add_child(food)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(player.food_eaten == 6 and player.segments.size() == 6, "Rapid pickups lost or duplicated growth")
	check(main.score == 60, "Pickup scoring was not exactly once per food")
	check(is_equal_approx(player.mass, 1.0) and player.collision_shape.scale.is_equal_approx(Vector3.ONE), "Eating changed head collision or mass")
	await get_tree().physics_frame
	check(player.linear_velocity.dot(Vector3.FORWARD) > 1.0, "Pickup did not apply a forward impulse")
	check(player.linear_velocity.length() <= player.max_speed + Player.MAX_PICKUP_BOOST + 0.1, "Rapid pickups exceeded the lunge speed cap")
	# Remove random replenishment so this route tests only the intended hazards.
	await get_tree().process_frame
	for group in ["rock", "food"]:
		for node in get_tree().get_nodes_in_group(group):
			node.queue_free()
	var max_link = 0.0
	var max_step = 0.0
	for action in ["move_right", "move_down", "move_left", "move_up", "move_right", "move_down"]:
		Input.action_press(action)
		for frame in 36:
			var previous = player.segments.back().global_position
			await get_tree().physics_frame
			max_step = maxf(max_step, previous.distance_to(player.segments.back().global_position))
			for segment in player.segments:
				check(segment.global_position.is_finite() and absf(segment.global_position.y - 0.35) < 0.01, "Body left the playable ground plane")
				max_link = maxf(max_link, segment.global_position.distance_to(segment.target.global_position))
		Input.action_release(action)
	check(not player.has_lost, "Normal steering unexpectedly killed the player")
	# Contact can temporarily stretch a link while a new piece rounds a corner.
	check(max_link < 1.25, "Body stretched too far during a turn: %f" % max_link)
	check(max_step < 0.3, "Tail teleported during movement: %f" % max_step)
	for frame in 15:
		await get_tree().physics_frame
	check(player.linear_velocity.length() < 0.2, "Player did not brake promptly after releasing input")
	for frame in 45:
		await get_tree().physics_frame
	for segment in player.segments:
		check(segment.collision_layer == PhysicsConstants.LAYER_SEGMENT, "A grown segment never became solid after moving clear")
		check(segment.global_position.distance_to(segment.target.global_position) < 1.0, "Body did not close up after braking")
	main.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(main.is_paused and GameState.has_saved_game(), "Focus loss did not pause and save the run")
	check(main.ui.get_node("PauseMenu/VBoxContainer/ResumeButton").has_focus(), "Pause menu has no keyboard focus")
	main.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(main.is_paused, "Repeated focus loss resumed gameplay")
	main.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	check(main.is_paused, "Returning to the window resumed gameplay without consent")
	main.toggle_pause()
	main.toggle_gameplay_pause()
	check(GameState.delete_save_game(), "Failed to clear focus-loss fixture")
	main.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(main.is_gameplay_paused and not main.is_paused, "Focus loss changed an existing Space pause")
	check(GameState.has_saved_game(), "Focus loss while already paused did not save")
	var repeated_pause = InputEventKey.new()
	repeated_pause.keycode = KEY_ESCAPE
	repeated_pause.pressed = true
	repeated_pause.echo = true
	main._unhandled_input(repeated_pause)
	check(main.is_gameplay_paused and not main.is_paused, "Key repeat changed the pause state")
	var paused_position = player.global_position
	var paused_growth = player.segments[0].growth_timer
	for frame in 30:
		await get_tree().physics_frame
	check(player.global_position.is_equal_approx(paused_position), "Pause did not freeze physics")
	check(is_equal_approx(player.segments[0].growth_timer, paused_growth), "Pause did not freeze growth")
	main.toggle_gameplay_pause()
	main.save_game_state()
	var saved_positions = player.get_segment_positions()
	# Legacy recovery must repair the recorded path as well as each piece.
	var fallen_save = GameState.load_game_state()
	for segment_data in fallen_save.player_state.segments:
		segment_data.position.y = -3.0
	for point in fallen_save.player_state.trail:
		point.y = -3.0
	check(GameState.save_game_state(fallen_save), "Failed to write fallen-body fixture")
	main.free()
	main = MAIN.instantiate()
	add_child(main)
	player = main.player
	check(main.score == 60 and player.segments.size() == 6, "Save/resume lost score or body length")
	for index in player.segments.size():
		var saved = saved_positions[index].position
		check(player.segments[index].position.distance_to(Vector3(saved.x, saved.y, saved.z)) < 0.01, "Save/resume reversed the body order")
	var stayed_grounded = true
	for frame in 70:
		await get_tree().physics_frame
		for segment in player.segments:
			stayed_grounded = stayed_grounded and absf(segment.position.y - 0.35) < 0.01
	check(stayed_grounded, "Saved trail pulled a recovered body off the ground")
	check(not player.has_lost, "A brief stop after resuming killed the player")
	for segment in player.segments:
		check(segment.position.y > 0.3 and is_equal_approx(segment.current_scale, 1.0), "Resumed body disappeared or failed to finish growth")
		check(segment.collision_layer == PhysicsConstants.LAYER_SEGMENT, "Resumed body stayed intangible")
	# Real wall contact must still end the session once, and prevent more food.
	Input.action_press("move_right")
	for frame in 240:
		await get_tree().physics_frame
		if main.is_game_over:
			break
	Input.action_release("move_right")
	check(main.is_game_over and player.has_lost, "Wall collision failed to end the run")
	check(not GameState.has_saved_game() and not FileAccess.file_exists(GameState.save_file_path + ".bak"), "Game over retained a resumable dead session")
	await get_tree().process_frame
	for segment in player.segments:
		check(segment.is_detached and segment.target == null and not segment.axis_lock_linear_y, "The body remained tethered after death")
	main.free()
	Engine.time_scale = 1.0
	await _check_body_contacts()
	await _check_stuck_loss()
	await _check_speed_scoring()
	await _check_handling()
	await _check_rock_impacts()
	await _check_pickup_clearance()
	await _check_arena_fall()
	_check_empty_food_resume()
	_check_crowded_food_refill()
	_check_body_spawn_clearance()
	print("Gameplay regression: max link %.3f, max tail step %.3f" % [max_link, max_step])
	if not failed:
		print("Gameplay regression passed")
	get_tree().quit(1 if failed else 0)

func _check_body_contacts() -> void:
	var fixture = {
		"score": 10,
		"player_state": {
			"position": {"x": 0, "y": 0.4, "z": 0},
			"segments": [{"position": {"x": -0.8, "y": 0.35, "z": 0}, "growth": 1.0}],
		},
		"food_positions": [{"x": 6, "y": 0, "z": 6}],
	}
	check(GameState.save_game_state(fixture), "Failed to write body collision fixture")
	var main = MAIN.instantiate()
	add_child(main)
	var player: Player = main.player
	var segment: Segment = player.segments[0]
	for frame in 10:
		await get_tree().physics_frame
	check(segment.collision_layer == PhysicsConstants.LAYER_SEGMENT, "A mature segment never became solid")

	# A rock approaches the body from the side, outside the head's reach.
	var rock: Rock = ROCK.instantiate()
	main.gameplay_container.add_child(rock)
	rock.restore_from_save_data({"position": {"x": -0.8, "y": 0.5, "z": -1.1}})
	rock.linear_velocity = Vector3.BACK * 5.0
	var rock_touched_body = false
	var body_deflection = 0.0
	for frame in 25:
		await get_tree().physics_frame
		rock_touched_body = rock_touched_body or rock.get_colliding_bodies().has(segment)
		body_deflection = maxf(body_deflection, segment.position.z)
	check(rock_touched_body and body_deflection > 0.02, "A moving rock passed through the body without deflecting it")
	rock.queue_free()

	# Reversing into a blue piece should produce contact without ending the run.
	var touched_own_body = false
	Input.action_press("move_left")
	for frame in 18:
		await get_tree().physics_frame
		touched_own_body = touched_own_body or player.get_colliding_bodies().has(segment)
	Input.action_release("move_left")
	check(touched_own_body and not player.has_lost, "Reversing into a blue piece failed to produce a safe collision")
	check(player.position.x > segment.position.x, "The head crossed through the solid body piece")
	Input.action_press("move_down")
	var turn_start = player.position
	for frame in 16:
		await get_tree().physics_frame
	Input.action_release("move_down")
	check(player.position.z - turn_start.z > 0.6, "Steering could not pull the head away from its body after contact")

	# A body piece pushed into a wall becomes a visible, persistent hazard.
	var wall_piece: Segment = Player.SEGMENT_SCENE.instantiate()
	wall_piece.position = Vector3(10, 0.35, -3)
	main.gameplay_container.add_child(wall_piece)
	wall_piece.init_with_growth(1.0)
	for frame in 3:
		await get_tree().physics_frame
	wall_piece.set_path_target(Vector3(11, 0.35, -3), 1.0)
	for frame in 30:
		await get_tree().physics_frame
	check(wall_piece.is_dangerous and wall_piece.is_in_group("dangerous"), "Wall contact did not turn a body piece dangerous")
	fixture.player_state.segments[0].is_dangerous = wall_piece.get_save_data().is_dangerous
	main.free()

	check(GameState.save_game_state(fixture), "Failed to write dangerous segment fixture")
	main = MAIN.instantiate()
	add_child(main)
	player = main.player
	check(player.segments[0].is_dangerous, "A dangerous segment lost its state on resume")
	for frame in 10:
		await get_tree().physics_frame
	Input.action_press("move_left")
	for frame in 18:
		await get_tree().physics_frame
		if main.is_game_over:
			break
	Input.action_release("move_left")
	check(main.is_game_over, "Head contact with a red body piece did not end the run")
	main.free()
	Engine.time_scale = 1.0
	check(GameState.delete_save_game(), "Failed to clear body collision fixture")

func _check_stuck_loss() -> void:
	var fixture = {
		"score": 0,
		"player_state": {"position": {"x": 0, "y": 0.4, "z": 0}},
		"food_positions": [{"x": -6, "y": 0, "z": -6}],
	}
	check(GameState.save_game_state(fixture), "Failed to write inactivity fixture")
	var main = MAIN.instantiate()
	add_child(main)
	var player: Player = main.player
	for frame in 190:
		await get_tree().physics_frame
	check(not main.is_game_over and player.stuck_elapsed == 0.0, "Inactivity killed the player before their first move")

	Input.action_press("move_right")
	for frame in 24:
		await get_tree().physics_frame
	Input.action_release("move_right")
	for frame in 110:
		await get_tree().physics_frame
	check(player.stuck_elapsed >= Player.STUCK_WARNING_START and not main.is_game_over, "Stopping did not give the player time to recover")
	await get_tree().process_frame
	check(main.ui.hint_label.visible and main.ui.hint_label.text.begins_with("KEEP MOVING"), "Stuck warning was missing from the HUD")

	var before_pause = player.stuck_elapsed
	main.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	for frame in 125:
		await get_tree().physics_frame
	check(is_equal_approx(player.stuck_elapsed, before_pause) and not main.is_game_over, "Inactivity advanced while the run was paused")
	main.free()
	main = MAIN.instantiate()
	add_child(main)
	player = main.player
	check(player.has_started_moving and is_equal_approx(player.stuck_elapsed, before_pause), "Resume lost the active inactivity countdown")

	Input.action_press("move_down")
	for frame in 24:
		await get_tree().physics_frame
	Input.action_release("move_down")
	check(is_zero_approx(player.stuck_elapsed) and not main.is_game_over, "Moving before the deadline did not clear the warning")

	for frame in 130:
		await get_tree().physics_frame
	check(not main.is_game_over, "A stop ended the run before the three-second timeout")
	for frame in 105:
		await get_tree().physics_frame
		if main.is_game_over:
			break
	check(main.is_game_over and not GameState.has_saved_game(), "Staying stopped did not end the live run and clear its save")
	main.free()

	check(GameState.save_game_state(fixture), "Failed to write blocked-motion fixture")
	main = MAIN.instantiate()
	add_child(main)
	player = main.player
	var blocker = StaticBody3D.new()
	var collider = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(0.5, 2.0, 4.0)
	collider.shape = box
	blocker.add_child(collider)
	blocker.position = Vector3(1.0, 0.9, 0.0)
	main.gameplay_container.add_child(blocker)
	await get_tree().physics_frame
	Input.action_press("move_right")
	for frame in 225:
		await get_tree().physics_frame
		if main.is_game_over:
			break
	Input.action_release("move_right")
	check(main.is_game_over and player.position.x < 0.5, "Holding movement against a blocker bypassed the stuck timeout")
	main.free()
	Engine.time_scale = 1.0

func _check_speed_scoring() -> void:
	var fixture = {
		"score": 0,
		"player_state": {"position": {"x": 0, "y": 0.4, "z": 0}},
		"food_positions": [{"x": 3.5, "y": 0, "z": 0}],
	}
	check(GameState.save_game_state(fixture), "Failed to write speed scoring fixture")
	var main = MAIN.instantiate()
	add_child(main)
	Input.action_press("move_right")
	for frame in 60:
		await get_tree().physics_frame
		if main.player.food_eaten > 0:
			break
	Input.action_release("move_right")
	check(main.player.food_eaten == 1 and main.player.segments.size() == 1, "A cruising pickup failed to grow the body")
	check(main.score == 20, "A cruising pickup did not award double the stationary score")
	main.free()
	check(GameState.delete_save_game(), "Failed to clear speed scoring fixture")

func _check_handling() -> void:
	var fixture = {
		"score": 0,
		"player_state": {"position": {"x": 0, "y": 0.5, "z": -3}},
		"food_positions": [{"x": -7, "y": 0, "z": -7}],
	}
	check(GameState.save_game_state(fixture), "Failed to write handling fixture")
	var main = MAIN.instantiate()
	add_child(main)
	var player: Player = main.player
	Input.action_press("move_right")
	for frame in 30:
		await get_tree().physics_frame
	Input.action_release("move_right")
	var cruise_speed = player.linear_velocity.x
	check(cruise_speed > Player.BASE_MAX_SPEED * 0.95, "The head was slow to reach cruising speed")

	var turn_start = player.position
	var min_turn_speed = cruise_speed
	Input.action_press("move_down")
	for frame in 14:
		await get_tree().physics_frame
		var velocity = Vector2(player.linear_velocity.x, player.linear_velocity.z)
		min_turn_speed = minf(min_turn_speed, velocity.length())
	Input.action_release("move_down")
	var turn_drift = player.position.x - turn_start.x
	check(min_turn_speed >= cruise_speed * 0.9, "A right-angle turn shed too much momentum")
	check(player.linear_velocity.z >= cruise_speed * 0.9 and turn_drift < 1.15, "The head took too long to steer through a right angle")

	var reverse_start = player.position
	Input.action_press("move_up")
	for frame in 14:
		await get_tree().physics_frame
	Input.action_release("move_up")
	check(player.linear_velocity.z < -2.0 and absf(player.position.x - reverse_start.x) < 0.1, "A direct reversal was slow or pulled the head sideways")

	main.camera.toggle_view()
	Input.action_press("move_left")
	Input.action_press("move_up")
	for frame in 22:
		await get_tree().physics_frame
	Input.action_release("move_left")
	Input.action_release("move_up")
	var diagonal = Vector2(player.linear_velocity.x, player.linear_velocity.z)
	check(diagonal.normalized().dot(Vector2(-1, -1).normalized()) > 0.99, "Diagonal steering changed with the camera angle")
	check(absf(diagonal.length() - cruise_speed) < 0.3, "Diagonal input changed cruising speed")

	var coast_start = player.position
	for frame in 15:
		await get_tree().physics_frame
	var coast_distance = player.position.distance_to(coast_start)
	check(player.linear_velocity.length() < 0.2 and coast_distance < 0.95, "The head coasted too far after release")
	check(not main.is_game_over and player.food_eaten == 0, "The handling fixture hit a wall or picked up food")
	print("Handling regression: cruise %.2f, turn minimum %.2f, turn drift %.2f, coast %.2f" %
		[cruise_speed, min_turn_speed, turn_drift, coast_distance])
	main.free()
	check(GameState.delete_save_game(), "Failed to clear handling fixture")

func _check_rock_impacts() -> void:
	# Use the real input and pickup path so the break is reachable in play.
	for impact_case in ["cruise", "boosted", "dangerous"]:
		var boosted = impact_case != "cruise"
		var dangerous = impact_case == "dangerous"
		var fixture = {
			"score": 0,
			"player_state": {"position": {"x": -4, "y": 0.5, "z": 0}},
			"rocks": [{"position": {"x": 0, "y": 0.5, "z": 0}, "is_dangerous": dangerous}],
			"food_positions": [{"x": -1.25 if boosted else 6, "y": 0, "z": 0}],
		}
		check(GameState.save_game_state(fixture), "Failed to write rock impact fixture")
		var main = MAIN.instantiate()
		add_child(main)
		var rock: Rock = get_tree().get_first_node_in_group("rock")
		var saw_flash = false
		Input.action_press("move_right")
		for frame in 58:
			await get_tree().physics_frame
			if is_instance_valid(rock):
				saw_flash = saw_flash or rock.mesh.material_override != null
			if main.is_game_over:
				break
		Input.action_release("move_right")
		match impact_case:
			"cruise":
				check(is_instance_valid(rock) and rock.position.x > 0.3, "A cruising hit did not push an intact gray rock")
				check(saw_flash, "The rock did not flash on impact")
			"boosted":
				check(main.player.food_eaten == 1 and not main.is_game_over, "The boosted collision did not follow a live pickup")
				check(get_tree().get_nodes_in_group("rock").is_empty(), "A hard boosted hit did not break the gray rock")
				main.save_game_state()
				check(GameState.load_game_state().rocks.is_empty(), "A broken rock reappeared in the save")
			"dangerous":
				check(main.is_game_over and is_instance_valid(rock), "A boosted hit broke a red rock instead of ending the run")
		main.free()
		Engine.time_scale = 1.0
		check(GameState.delete_save_game(), "Failed to clear rock impact fixture")

func _check_pickup_clearance() -> void:
	var fixture = {
		"score": 0,
		"player_state": {"position": {"x": 0, "y": 0.5, "z": 0}},
		"food_positions": [{"x": 0.65, "y": 0, "z": 0}],
	}
	check(GameState.save_game_state(fixture), "Failed to write obstructed pickup fixture")
	var main = MAIN.instantiate()
	add_child(main)
	var blocker = StaticBody3D.new()
	blocker.collision_layer = PhysicsConstants.LAYER_BARRIER
	blocker.position = Vector3(0.48, 0.6, 0)
	var collider = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(0.1, 1.2, 2.0)
	collider.shape = box
	blocker.add_child(collider)
	main.gameplay_container.add_child(blocker)
	for frame in 8:
		await get_tree().physics_frame
	check(main.player.food_eaten == 0, "The head collected food through a solid obstacle")
	blocker.queue_free()
	for frame in 4:
		await get_tree().physics_frame
	check(main.player.food_eaten == 1, "Removing the obstacle did not make the food collectible")
	main.free()

	fixture.player_state.position.y = 2.6
	fixture.food_positions[0].x = 0.2
	check(GameState.save_game_state(fixture), "Failed to write airborne pickup fixture")
	main = MAIN.instantiate()
	add_child(main)
	for frame in 10:
		await get_tree().physics_frame
	check(main.player.food_eaten == 0, "The head collected food from far above it")
	for frame in 25:
		await get_tree().physics_frame
		if main.player.food_eaten > 0:
			break
	check(main.player.food_eaten == 1 and main.player.position.y > 1.3, "The head failed to collect food within the generous vertical reach")
	main.free()
	check(GameState.delete_save_game(), "Failed to clear pickup clearance fixture")

func _check_arena_fall() -> void:
	var fixture = {
		"score": 0,
		"player_state": {"position": {"x": 12, "y": 0.5, "z": 0}},
		"rocks": [{"position": {"x": 12, "y": 0.5, "z": 3}}],
		"food_positions": [{"x": 6, "y": 0, "z": 0}],
	}
	check(GameState.save_game_state(fixture), "Failed to write arena fall fixture")
	var main = MAIN.instantiate()
	add_child(main)
	for frame in 85:
		await get_tree().physics_frame
		if main.is_game_over and get_tree().get_nodes_in_group("rock").is_empty():
			break
	check(main.is_game_over and not GameState.has_saved_game(), "Falling out of the arena left a live or resumable run")
	check(get_tree().get_nodes_in_group("rock").is_empty(), "A fallen rock remained in the game")
	main.free()
	Engine.time_scale = 1.0

func _check_body_spawn_clearance() -> void:
	var fixture = {
		"score": 0,
		"player_state": {"position": {"x": 0, "y": 0.5, "z": 0}, "segments": []},
	}
	check(GameState.save_game_state(fixture), "Failed to write spawn clearance fixture")
	seed(42)
	var main = MAIN.instantiate()
	add_child(main)
	for food in get_tree().get_nodes_in_group("food"):
		fixture.player_state.segments.append({"position": {"x": food.position.x, "y": 0.35, "z": food.position.z}})
	seed(88)
	check(main.spawn_rock(true), "Could not place the reference rock")
	var rock: Rock = get_tree().get_first_node_in_group("rock")
	if rock:
		fixture.player_state.segments.append({"position": {"x": rock.position.x, "y": 0.35, "z": rock.position.z}})
	main.free()

	check(GameState.save_game_state(fixture), "Failed to write body-occupied spawn fixture")
	seed(42)
	main = MAIN.instantiate()
	add_child(main)
	seed(88)
	check(main.spawn_rock(true), "Body clearance prevented all rock placement")
	check(get_tree().get_nodes_in_group("food").size() == main.MIN_FOOD_COUNT, "Body clearance prevented food refill")
	for group in ["rock", "food"]:
		for item in get_tree().get_nodes_in_group(group):
			for segment in main.player.segments:
				check(main._horizontal_distance(item.position, segment.position) >= main.MIN_BODY_SPAWN_DISTANCE, "A %s spawned over the body" % group)
	main.free()
	check(GameState.delete_save_game(), "Failed to clear spawn clearance fixture")

func _check_empty_food_resume() -> void:
	var fixture = {
		"score": 0,
		"player_state": {"position": {"x": 0, "y": 0.5, "z": 0}},
		"food_positions": [],
		"rocks": [],
	}
	check(GameState.save_game_state(fixture), "Failed to write empty-food save fixture")
	seed(42)
	var main = MAIN.instantiate()
	add_child(main)
	# Place saved hazards at the exact locations the same random sequence
	# chooses in an empty arena. Food generation must see the restored rocks.
	for food in get_tree().get_nodes_in_group("food"):
		if food.is_queued_for_deletion():
			continue
		fixture.rocks.append({
			"position": {"x": food.position.x, "y": 0.5, "z": food.position.z},
			"is_dangerous": true,
		})
	check(fixture.rocks.size() >= main.MIN_FOOD_COUNT, "Empty-food fixture failed to generate food")
	main.free()
	check(GameState.save_game_state(fixture), "Failed to write saved-hazard fixture")
	seed(42)
	main = MAIN.instantiate()
	add_child(main)
	var food_count = 0
	for food in get_tree().get_nodes_in_group("food"):
		if food.is_queued_for_deletion():
			continue
		food_count += 1
		for rock in get_tree().get_nodes_in_group("rock"):
			check(main._horizontal_distance(food.position, rock.position) >= 1.0, "Replacement food overlapped a restored hazard")
	check(food_count >= main.MIN_FOOD_COUNT, "Resume did not replenish an empty food list")
	main.free()
	check(GameState.delete_save_game(), "Failed to clear saved-hazard fixture")

func _check_crowded_food_refill() -> void:
	var main = MAIN.instantiate()
	add_child(main)
	for group in ["rock", "food"]:
		for node in get_tree().get_nodes_in_group(group):
			node.queue_free()
	# Cover the spawn area with hazard markers, then clear it without a pickup.
	var hazards = Node3D.new()
	main.gameplay_container.add_child(hazards)
	for x in range(-8, 9):
		for z in range(-8, 9):
			var hazard = Node3D.new()
			hazard.position = Vector3(x, 0, z)
			hazard.add_to_group("dangerous")
			hazards.add_child(hazard)
	main._refill_food()
	var food = get_tree().get_nodes_in_group("food").filter(func(item): return not item.is_queued_for_deletion())
	check(food.is_empty(), "Crowded arena spawned food on a hazard")
	hazards.free()
	main._process(main.AUTOSAVE_INTERVAL)
	food = get_tree().get_nodes_in_group("food").filter(func(item): return not item.is_queued_for_deletion())
	check(food.size() == main.MIN_FOOD_COUNT, "Active game did not refill food after the spawn area opened up")
	main.free()
	check(GameState.delete_save_game(), "Failed to clear food refill fixture")
