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
	main.set_process(false) # Keep the autosave refill from placing food along the route.
	for group in ["rock", "food"]:
		for node in get_tree().get_nodes_in_group(group):
			node.queue_free()
	player.freeze = true
	player.position = Vector3(0, 0.5, 0)
	await get_tree().physics_frame
	await _check_rock_drop(main.gameplay_container)
	player.freeze = false
	player.rebuild_trail()
	for frame in 30:
		await get_tree().physics_frame
	# A retired pickup can still be in the tree until the frame ends.
	var retired_food: Food = FOOD.instantiate()
	retired_food.position = Vector3(player.position.x, 0, player.position.z)
	main.gameplay_container.add_child(retired_food)
	retired_food.queue_free()
	player._collect_food()
	check(player.food_eaten == 0 and main.score == 0, "A retired pickup still awarded points")
	# Several pickups inside one digestion period must each grow exactly once.
	for index in 6:
		var food = FOOD.instantiate()
		food.position = Vector3(player.position.x, 0, player.position.z)
		main.gameplay_container.add_child(food)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(player.food_eaten == 6 and player.segments.size() == 6, "Rapid pickups lost or duplicated growth")
	check(main.score == 60, "Pickup scoring was not exactly once per food")
	check(main.score_popups.get_child_count() == 1 and main.score_popup.text == "+60",
		"Nearby pickups did not combine into one readable score popup")
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
	# Finish the second lap heading into open space for the coast check.
	for action in ["move_right", "move_down", "move_left", "move_up", "move_right", "move_down", "move_left", "move_up"]:
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
	for frame in 100:
		await get_tree().physics_frame
	check(player.linear_velocity.length() < 0.2, "Player did not settle after coasting")
	for frame in 18:
		await get_tree().physics_frame
	for segment in player.segments:
		check(segment.collision_layer == PhysicsConstants.LAYER_SEGMENT, "A grown segment never became solid after moving clear")
		check(is_instance_valid(segment.target) and segment.global_position.distance_to(segment.target.global_position) < 1.0,
			"Body did not close up after coasting")
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
	var saved_positions := player.get_segment_save_data()
	# Legacy recovery must repair the recorded path as well as each piece.
	var fallen_save = GameState.load_game_state()
	for segment_data in fallen_save.player_state.segments:
		segment_data.position.y = -3.0
		segment_data.erase("is_solid")
		segment_data.erase("path_target")
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
	await _check_resume_momentum()
	await _check_handling()
	await _check_passive_momentum()
	await _check_rock_impacts()
	await _check_pickup_clearance()
	await _check_arena_fall()
	_check_failed_exit_save()
	_check_empty_food_resume()
	_check_crowded_food_refill()
	_check_covered_food_refill()
	_check_body_spawn_clearance()
	await _check_device_controls()
	print("Gameplay regression: max link %.3f, max tail step %.3f" % [max_link, max_step])
	if not failed:
		print("Gameplay regression passed")
	get_tree().quit(1 if failed else 0)

func _send_input(event: InputEvent) -> void:
	Input.parse_input_event(event.duplicate())
	Input.flush_buffered_events()

func _check_device_controls() -> void:
	var main = MAIN.instantiate()
	add_child(main)
	var player: Player = main.player
	player.freeze = true
	player.position = Vector3(0.0, 0.5, 0.0)
	var window = get_window()
	var original_size = window.size
	for resolution in [Vector2i(320, 640), Vector2i(568, 320), Vector2i(640, 480), Vector2i(1440, 540)]:
		window.size = resolution
		await get_tree().process_frame
		var play_area: Rect2 = main.ui.get_play_area()
		for corner in [Vector3(-11, 0, -11), Vector3(11, 0, -11), Vector3(-11, 0, 11), Vector3(11, 0, 11)]:
			check(play_area.has_point(main.camera.unproject_position(corner)),
				"Arena escaped the HUD-safe play area at %s" % resolution)
		check(not main.ui.score_label.get_global_rect().intersects(main.ui.stats_label.get_global_rect()),
			"HUD cards overlap at %s" % resolution)

	var mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = main.camera.unproject_position(Vector3(5.0, 0.5, 0.0))
	mouse.pressed = true
	_send_input(mouse)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(player.input_dir.dot(Vector3.RIGHT) > 0.99, "Holding the mouse did not steer toward the pointed world position")
	mouse.pressed = false
	mouse.position = main.ui.pause_button.get_global_rect().get_center()
	_send_input(mouse)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(player.input_dir.is_zero_approx(), "Releasing the mouse over a HUD button kept steering")

	var touch = InputEventScreenTouch.new()
	touch.index = 0
	touch.position = main.ui.get_play_area().get_center()
	touch.pressed = true
	_send_input(touch)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(player.input_dir.is_zero_approx(), "Touch-down steered before the player dragged")
	var drag = InputEventScreenDrag.new()
	drag.index = touch.index
	drag.position = touch.position + Vector2(0.0, -50.0)
	_send_input(drag)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(player.input_dir.dot(Vector3.FORWARD) > 0.99, "Touch drag did not steer along the screen axes")
	touch.pressed = false
	touch.canceled = true
	_send_input(touch)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(player.input_dir.is_zero_approx(), "Canceling touch did not release steering")

	var axis = InputEventJoypadMotion.new()
	axis.axis = JOY_AXIS_LEFT_X
	axis.axis_value = -0.8
	_send_input(axis)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(player.input_dir.x < -0.4 and player.input_dir.x > -0.9, "Left stick did not provide analog steering")
	axis.axis_value = 0.2
	_send_input(axis)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(player.input_dir.is_zero_approx(), "Stick drift bypassed the movement deadzone")
	axis.axis_value = 0.0
	_send_input(axis)

	var button = InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_START
	button.pressed = true
	_send_input(button)
	check(main.is_paused, "Start did not open the pause menu")
	button.pressed = false
	_send_input(button)
	await get_tree().process_frame
	await get_tree().process_frame
	button.button_index = JOY_BUTTON_DPAD_DOWN
	button.pressed = true
	_send_input(button)
	check(main.ui.get_node("PauseMenu/VBoxContainer/MainMenuButton").has_focus(), "D-pad did not navigate the pause menu")
	button.button_index = JOY_BUTTON_START
	_send_input(button)
	check(not main.is_paused, "Start did not resume gameplay")
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(player.input_dir.is_zero_approx(), "Held menu direction steered immediately after resuming")
	button.pressed = false
	_send_input(button)
	button.button_index = JOY_BUTTON_DPAD_DOWN
	_send_input(button)
	await get_tree().physics_frame
	await get_tree().physics_frame
	button.pressed = true
	_send_input(button)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(player.input_dir.dot(Vector3.BACK) > 0.99, "D-pad did not steer after returning to neutral")
	button.pressed = false
	_send_input(button)
	button.button_index = JOY_BUTTON_Y
	button.pressed = true
	_send_input(button)
	check(main.camera.is_third_person, "Y did not switch to the angled camera")
	await get_tree().create_timer(0.8).timeout
	var angled_area: Rect2 = main.ui.get_play_area()
	check(angled_area.has_point(main.camera.unproject_position(Vector3(11, 0, 11))),
		"Angled camera cropped the arena")
	button.pressed = false
	_send_input(button)
	button.button_index = JOY_BUTTON_B
	button.pressed = true
	_send_input(button)
	check(main.is_paused, "B did not open the pause menu")
	button.pressed = false
	_send_input(button)
	await get_tree().process_frame
	button.button_index = JOY_BUTTON_A
	button.pressed = true
	_send_input(button)
	button.pressed = false
	_send_input(button)
	check(not main.is_paused, "A did not activate the focused Resume button")
	main.free()
	window.size = original_size

func _check_rock_drop(container: Node3D) -> void:
	var rock: Rock = ROCK.instantiate()
	container.add_child(rock)
	rock.setup_rock(Vector3(5, 0, 5))
	check(rock.position.y < 6.0 and rock.linear_velocity.y < -1.0, "A new rock spawned too high or hung in the air")
	check(rock.landing_marker.visible and rock.landing_marker.global_position.distance_to(Vector3(5, 0, 5)) < 0.05,
		"The drop marker did not appear on the floor below the rock")
	var landing_frame := 0
	for frame in 45:
		await get_tree().physics_frame
		check(rock.collision_shape.scale.is_equal_approx(Vector3.ONE) and is_equal_approx(rock.mass, rock.base_mass),
			"The drop animation changed the rock's collider or mass")
		if not rock.is_spawning:
			landing_frame = frame + 1
			break
	check(landing_frame >= 20 and landing_frame <= 38 and rock.position.y < 0.55,
		"Rock did not complete its drop on ground contact within the expected time")
	check(is_equal_approx(rock.gravity_scale, 1.0) and rock.mesh.scale.is_equal_approx(Vector3.ONE),
		"The landed rock retained its drop gravity or visual scale")
	print("Rock drop: first landing after %d physics ticks" % landing_frame)
	for frame in 20:
		await get_tree().physics_frame
	check(not rock.landing_marker.visible, "The landing marker stayed visible after impact")
	var impact_position := rock.global_position
	rock.shatter_from_lunge(Rock.BREAK_IMPULSE)
	for frame in 5:
		await get_tree().physics_frame
	check(rock.shatter_effect.global_position.is_equal_approx(impact_position)
		and rock.break_sparks.global_position.is_equal_approx(impact_position),
		"The shatter effect moved away from the rock's impact position")
	check(rock.shatter_effect.get_child_count() == Rock.FRAGMENT_COUNT + 1,
		"The rock fragments were not attached to the shatter effect")
	rock.free()

func _check_body_contacts() -> void:
	var fixture = {
		"score": 10,
		"player_state": {
			"position": {"x": 0, "y": 0.4, "z": 0},
			"segments": [{"position": {"x": -0.8, "y": 0.35, "z": 0}, "growth": 1.0}],
		},
		"food_positions": [
			{"x": 6, "y": 0, "z": 6}, {"x": 7, "y": 0, "z": -6}, {"x": 0, "y": 0, "z": 7},
		],
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

	# Brake from forward motion and then reverse into the blue piece.
	Input.action_press("move_right")
	for frame in 28:
		await get_tree().physics_frame
	Input.action_release("move_right")
	var forward_speed := player.linear_velocity.x
	check(forward_speed > 6.0, "The snake never reached speed before braking")
	var touched_own_body = false
	var furthest_x := player.position.x
	Input.action_press("move_left")
	for frame in 38:
		await get_tree().physics_frame
		furthest_x = maxf(furthest_x, player.position.x)
		if frame == 4:
			check(player.linear_velocity.x > 0.0 and player.linear_velocity.x < forward_speed - 1.0,
				"Opposite input did not brake forward motion before reversing")
		if player.get_colliding_bodies().has(segment):
			touched_own_body = true
			break
	Input.action_release("move_left")
	check(touched_own_body and furthest_x - player.position.x > 0.08 and not player.has_lost,
		"Reversing into a blue piece failed to produce a safe collision")
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
		"food_positions": [
			{"x": -6, "y": 0, "z": -6}, {"x": -7, "y": 0, "z": 0}, {"x": -6, "y": 0, "z": 6},
		],
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
	for frame in 140:
		await get_tree().physics_frame
	check(player.stuck_elapsed >= Player.STUCK_WARNING_START and not main.is_game_over, "Stopping did not give the player time to recover")
	await get_tree().process_frame
	check(main.ui.hint_label.visible and main.ui.hint_label.text.begins_with("KEEP MOVING"), "Stuck warning was missing from the HUD")

	var before_pause = player.stuck_elapsed
	var partial_sample = player.motion_sample_elapsed
	var sample_start = player.motion_sample_start
	check(partial_sample > 0.0, "The pause did not catch an unfinished motion sample")
	main.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	for frame in 125:
		await get_tree().physics_frame
	check(is_equal_approx(player.stuck_elapsed, before_pause) and not main.is_game_over, "Inactivity advanced while the run was paused")
	check(is_equal_approx(player.motion_sample_elapsed, partial_sample), "The partial motion sample advanced while paused")
	main.free()
	main = MAIN.instantiate()
	add_child(main)
	player = main.player
	check(player.has_started_moving and is_equal_approx(player.stuck_elapsed, before_pause), "Resume lost the active inactivity countdown")
	check(is_equal_approx(player.motion_sample_elapsed, partial_sample) and player.motion_sample_start.is_equal_approx(sample_start), "Resume lost the unfinished motion sample")

	Input.action_press("move_down")
	for frame in 24:
		await get_tree().physics_frame
	Input.action_release("move_down")
	check(is_zero_approx(player.stuck_elapsed) and not main.is_game_over, "Moving before the deadline did not clear the warning")

	for frame in 130:
		await get_tree().physics_frame
	check(not main.is_game_over, "A stop ended the run before the three-second timeout")
	# The inactivity window starts once the longer coast stops making progress.
	for frame in 150:
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

func _check_resume_momentum() -> void:
	var fixture = {
		"score": 0,
		"player_state": {"position": {"x": 0, "y": 0.4, "z": 0}},
		"food_positions": [{"x": 0, "y": 0, "z": 0}, {"x": 6, "y": 0, "z": 6}],
	}
	check(GameState.save_game_state(fixture), "Failed to write pickup resume fixture")
	var main = MAIN.instantiate()
	add_child(main)
	# Save at the pickup boundary before the next force integration.
	main.player.food_collected.connect(func(_total): main.save_game_state(), CONNECT_ONE_SHOT)
	for frame in 3:
		await get_tree().physics_frame
		if main.player.food_eaten == 1:
			break
	check(is_equal_approx(float(GameState.load_game_state().player_state.get("pending_pickup_impulse", 0.0)), Player.PICKUP_IMPULSE), "The pickup save lost the queued lunge")
	main.free()
	main = MAIN.instantiate()
	add_child(main)
	var player: Player = main.player
	check(is_equal_approx(player.position.y, 0.4), "Resume lifted a grounded head")
	check(player.is_digesting and player.segments[0].freeze, "Resume lost the digestion or growth state")
	var resumed_speed = 0.0
	for frame in 4:
		await get_tree().physics_frame
		resumed_speed = maxf(resumed_speed, player.linear_velocity.dot(Vector3.FORWARD))
	check(resumed_speed > 1.0 and player.pending_pickup_impulse == 0.0, "The queued lunge did not apply on resume")
	check(player.food_eaten == 1 and player.segments.size() == 1 and main.score == 10, "Resume duplicated the pickup")
	var active_bonus = player.pickup_speed_bonus
	var digestion = player.digestion_timer
	main.save_game_state()
	main.free()
	main = MAIN.instantiate()
	add_child(main)
	player = main.player
	check(active_bonus > 0.0 and is_equal_approx(player.pickup_speed_bonus, active_bonus) and player.pending_pickup_impulse == 0.0, "Resume reset or replayed an active speed bonus")
	check(digestion > 0.0 and is_equal_approx(player.digestion_timer, digestion), "Resume reset the digestion pulse")
	main.free()

	fixture.food_positions.pop_front()
	fixture.player_state.segments = [{
		"position": {"x": -0.73, "y": 0.35, "z": 0},
		"velocity": {"x": 0, "y": 0, "z": 1.5},
		"path_target": {"x": -0.8, "y": 0.35, "z": 0},
		"growth": 1.0,
		"is_solid": true,
	}]
	check(GameState.save_game_state(fixture), "Failed to write touching-segment fixture")
	main = MAIN.instantiate()
	add_child(main)
	var segment: Segment = main.player.segments[0]
	check(not segment.freeze and segment.collision_layer == PhysicsConstants.LAYER_SEGMENT, "A solid segment temporarily lost collision on resume")
	check(is_equal_approx(segment.linear_velocity.z, 1.5) and is_equal_approx(segment.path_target.x, -0.8), "Resume discarded a moving segment's motion")
	main.free()
	check(GameState.delete_save_game(), "Failed to clear pickup resume fixture")

func _check_handling() -> void:
	var fixture = {
		"score": 0,
		"player_state": {"position": {"x": 0, "y": 0.5, "z": -3}},
		"food_positions": [{"x": -7, "y": 0, "z": -7}, {"x": 0, "y": 0, "z": 7}, {"x": 7, "y": 0, "z": -7}],
	}
	check(GameState.save_game_state(fixture), "Failed to write handling fixture")
	var main = MAIN.instantiate()
	add_child(main)
	var player: Player = main.player
	Input.action_press("move_right")
	for frame in 9:
		await get_tree().physics_frame
	var launch_speed = player.linear_velocity.x
	check(launch_speed > 2.0 and launch_speed < 4.3, "The head accelerated too abruptly or hesitated off the line")
	for frame in 25:
		await get_tree().physics_frame
	Input.action_release("move_right")
	var cruise_speed = player.linear_velocity.x
	check(cruise_speed > Player.BASE_MAX_SPEED * 0.95, "The head was slow to reach cruising speed")

	var turn_start = player.position
	var min_turn_speed = cruise_speed
	Input.action_press("move_down")
	for frame in 20:
		await get_tree().physics_frame
		var velocity = Vector2(player.linear_velocity.x, player.linear_velocity.z)
		if frame == 5:
			check(velocity.x > 5.5 and velocity.y > 2.0, "A right-angle turn did not change heading gradually")
		min_turn_speed = minf(min_turn_speed, velocity.length())
	Input.action_release("move_down")
	var turn_drift = player.position.x - turn_start.x
	check(min_turn_speed >= cruise_speed * 0.9, "A right-angle turn shed too much momentum")
	check(player.linear_velocity.z >= cruise_speed * 0.95 and turn_drift > 1.0 and turn_drift < 1.55,
		"The head did not track the expected wider cornering arc")

	var reverse_start = player.position
	Input.action_press("move_up")
	for frame in 22:
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
	var coast_speed = player.linear_velocity.length()
	for frame in 25:
		await get_tree().physics_frame
	var mid_coast_speed = Vector2(player.linear_velocity.x, player.linear_velocity.z)
	for frame in 40:
		await get_tree().physics_frame
	var coast_distance = player.position.distance_to(coast_start)
	check(coast_speed > 6.0 and mid_coast_speed.dot(diagonal.normalized()) > 3.0,
		"Releasing the input canceled too much forward momentum")
	check(player.linear_velocity.length() < 0.2 and coast_distance > 4.4 and coast_distance < 5.5,
		"The head did not roll to a gradual stop")
	check(not main.is_game_over and player.food_eaten == 0, "The handling fixture hit a wall or picked up food")
	print("Handling regression: cruise %.2f, turn minimum %.2f, turn drift %.2f, coast speed %.2f, coast distance %.2f" %
		[cruise_speed, min_turn_speed, turn_drift, coast_speed, coast_distance])
	main.free()
	check(GameState.delete_save_game(), "Failed to clear handling fixture")

func _check_passive_momentum() -> void:
	var fixture = {
		"score": 0,
		"player_state": {
			"position": {"x": 0, "y": 0.4, "z": 0},
			"segments": [{"position": {"x": -0.8, "y": 0.35, "z": 0}, "growth": 1.0}],
		},
		"food_positions": [{"x": 6, "y": 0, "z": 6}],
		"rocks": [{"position": {"x": 5, "y": 0.5, "z": -5}}],
	}
	check(GameState.save_game_state(fixture), "Failed to write passive momentum fixture")
	var main = MAIN.instantiate()
	add_child(main)
	var segment: Segment = main.player.segments[0]
	var rock: Rock = get_tree().get_first_node_in_group("rock")
	for frame in 10:
		await get_tree().physics_frame
	check(not segment.freeze, "Momentum fixture body piece never became solid")

	segment.linear_velocity = Vector3.BACK * 5.0
	for frame in 3:
		await get_tree().physics_frame
	var attached_drift = segment.position.z
	for frame in 60:
		await get_tree().physics_frame
	check(absf(segment.position.z) < 0.05, "A deflected body piece did not return to its path")

	segment.release_from_chain()
	segment.linear_velocity = Vector3.BACK * 5.0
	rock.linear_velocity = Vector3.BACK * 5.0
	for frame in 30:
		await get_tree().physics_frame
	var detached_speed = segment.linear_velocity.z
	var rock_speed = rock.linear_velocity.z
	check(attached_drift > 0.13, "The body follower canceled a sideways impulse too quickly")
	check(detached_speed > 3.5, "A detached body piece lost momentum too quickly")
	check(rock_speed > 3.5, "A rolling rock lost momentum too quickly")
	print("Passive momentum: attached drift %.2f, detached speed %.2f, rock speed %.2f" %
		[attached_drift, detached_speed, rock_speed])
	main.free()
	check(GameState.delete_save_game(), "Failed to clear passive momentum fixture")

func _check_rock_impacts() -> void:
	# Use the real input and pickup path so the break is reachable in play.
	for impact_case in ["cruise", "early_boost", "fast_cruise", "oncoming", "expired_boost", "hard_boost", "glancing", "dangerous"]:
		var oncoming = impact_case in ["oncoming", "expired_boost"]
		var fast = oncoming or impact_case in ["fast_cruise", "hard_boost", "glancing", "dangerous"]
		var boosted = impact_case in ["early_boost", "hard_boost", "glancing", "dangerous"]
		var dangerous = impact_case == "dangerous"
		var row = 0.57 if impact_case == "glancing" else 0.0
		var fixture = {
			"score": 0,
			"player_state": {
				"position": {"x": -6.5, "y": 0.5, "z": row},
				"food_eaten": 20 if fast else 0,
				"current_speed_boost": 1.5 if fast else 1.0,
			},
			"rocks": [{"position": {"x": 0, "y": 0.5, "z": 0}, "is_dangerous": dangerous}],
			"food_positions": [
				{"x": -1.24 if boosted else 6, "y": 0, "z": row},
				{"x": 6, "y": 0, "z": 6}, {"x": 7, "y": 0, "z": -6},
			],
		}
		if oncoming:
			fixture.player_state.position.x = -4.0
			fixture.player_state.velocity = {"x": 12, "y": 0, "z": 0}
			fixture.rocks[0].velocity = {"x": -6, "y": 0, "z": 0}
		if impact_case == "expired_boost":
			fixture.player_state.position.x = -9.0
			fixture.player_state.pickup_speed_bonus = 2.5
		check(GameState.save_game_state(fixture), "Failed to write rock impact fixture")
		var main = MAIN.instantiate()
		add_child(main)
		var rock: Rock = get_tree().get_first_node_in_group("rock")
		var saw_flash = false
		Input.action_press("move_right")
		for frame in 65:
			await get_tree().physics_frame
			if impact_case == "cruise" and is_instance_valid(rock):
				saw_flash = saw_flash or rock.mesh.material_override != null
			if main.is_game_over:
				break
		Input.action_release("move_right")
		if boosted:
			check(main.player.food_eaten == (21 if fast else 1), "%s: the snake missed the pickup before impact" % impact_case)
		if oncoming:
			check(main.player.pickup_speed_bonus == 0.0, "The oncoming-rock fixture still had a pickup boost")
		match impact_case:
			"hard_boost":
				check(not main.is_game_over, "Shattering a gray rock ended the run")
				check(get_tree().get_nodes_in_group("rock").is_empty(), "A hard boosted hit did not break the gray rock")
				main.save_game_state()
				check(GameState.load_game_state().rocks.is_empty(), "A broken rock reappeared in the save")
			"dangerous":
				check(main.is_game_over and is_instance_valid(rock), "A boosted hit broke a red rock instead of ending the run")
			_:
				check(is_instance_valid(rock) and not rock.is_shattering and rock.position.x > 0.3,
					"%s: the rock should have rolled away intact" % impact_case)
				if impact_case == "cruise":
					check(saw_flash, "The rock did not flash on impact")
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

func _check_failed_exit_save() -> void:
	var main = MAIN.instantiate()
	var previous_auto_accept_quit = get_tree().auto_accept_quit
	add_child(main)
	check(not get_tree().auto_accept_quit, "Live gameplay did not take over the window close action")
	var original_save_path = GameState.save_file_path
	var blocked_path = original_save_path + ".blocked"
	check(DirAccess.make_dir_absolute(blocked_path) == OK, "Failed to block the save destination")
	GameState.save_file_path = blocked_path

	main.return_to_main_menu()
	check(main.is_paused and main.is_inside_tree(), "Failed menu save discarded the live game")
	check(main.ui.save_error_label.is_visible_in_tree(), "Pause menu hid the failed save")
	main.toggle_pause()
	check(not main.ui.save_error_label.visible, "Resuming left a stale save error")
	main.notification(NOTIFICATION_WM_CLOSE_REQUEST)
	check(main.is_paused and not main.is_quitting, "Failed window-close save discarded the live game")
	check(main.ui.save_error_label.is_visible_in_tree(), "Failed window-close save did not explain the pause")
	main.save_and_quit()
	check(not main.is_quitting, "Failed Quit save exited the game")

	check(DirAccess.remove_absolute(blocked_path) == OK, "Failed to restore the save destination")
	check(main.save_game_state() and GameState.has_saved_game(), "The live game could not be saved after the destination recovered")
	check(GameState.delete_save_game(), "Failed to clear the recovered exit fixture")
	GameState.save_file_path = original_save_path
	main.free()
	check(get_tree().auto_accept_quit == previous_auto_accept_quit, "Gameplay left window closing disabled outside the run")

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
	var edge_hazards = Node3D.new()
	hazards.add_child(edge_hazards)
	for x in range(-8, 9):
		for z in range(-8, 9):
			var hazard = Node3D.new()
			hazard.position = Vector3(x, 0, z)
			hazard.add_to_group("dangerous")
			var parent = edge_hazards if absi(x) == 8 or absi(z) == 8 else hazards
			parent.add_child(hazard)
	main._refill_food()
	var food = get_tree().get_nodes_in_group("food").filter(func(item): return not item.is_queued_for_deletion())
	check(food.is_empty(), "Crowded arena spawned food on a hazard")
	edge_hazards.free()
	main._process(main.AUTOSAVE_INTERVAL)
	food = get_tree().get_nodes_in_group("food").filter(func(item): return not item.is_queued_for_deletion())
	check(food.size() == main.MIN_FOOD_COUNT, "Active game did not refill food in the free space outside a crowded center")
	for item: Food in food:
		check(maxf(absf(item.position.x), absf(item.position.z)) == 9.0, "Fallback food did not stay on the cleared outer ring")
	main.free()
	check(GameState.delete_save_game(), "Failed to clear food refill fixture")

func _check_covered_food_refill() -> void:
	var fixture = {
		"score": 0,
		"player_state": {"position": {"x": 0, "y": 0.5, "z": 0}},
		"food_positions": [{"x": 5, "y": 0, "z": 0}],
		"rocks": [{"position": {"x": 5, "y": 0.5, "z": 0}, "is_dangerous": true}],
	}
	check(GameState.save_game_state(fixture), "Failed to write covered-food fixture")
	var main = MAIN.instantiate()
	add_child(main)
	var original_food: Food = get_tree().get_first_node_in_group("food")
	var rock: Rock = get_tree().get_first_node_in_group("rock")
	check(get_tree().get_node_count_in_group("food") == main.MIN_FOOD_COUNT, "Resume left a partial food supply")

	main._process(main.AUTOSAVE_INTERVAL)
	check(not original_food.is_queued_for_deletion(), "Food moved after a single observation of cover")
	rock.position.y = 2.0
	main._process(main.AUTOSAVE_INTERVAL)
	check(not original_food.is_queued_for_deletion(), "An airborne rock removed food below it")

	rock.position.y = 0.5
	main._process(main.AUTOSAVE_INTERVAL)
	check(not original_food.is_queued_for_deletion(), "Previously cleared cover carried over")
	main._process(main.AUTOSAVE_INTERVAL)
	check(original_food.is_queued_for_deletion(), "Food remained stuck inside a settled rock")
	var food_count = 0
	for food: Food in get_tree().get_nodes_in_group("food"):
		if not food.is_queued_for_deletion():
			check(main._horizontal_distance(food.position, rock.position) > main.MIN_FOOD_ROCK_DISTANCE, "Replacement food collided with the covering rock")
			food_count += 1
	check(food_count == main.MIN_FOOD_COUNT, "Covered food replacement changed the available supply")
	check(GameState.load_game_state().food_positions.size() == main.MIN_FOOD_COUNT, "Covered food replacement did not persist")
	main.free()
	check(GameState.delete_save_game(), "Failed to clear covered-food fixture")
