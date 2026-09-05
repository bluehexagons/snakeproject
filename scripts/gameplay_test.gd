extends Node

const MAIN = preload("res://scenes/main.tscn")
const FOOD = preload("res://scenes/food.tscn")
var failed = false

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
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
	check(max_link < 1.0, "Body detached during a turn: %f" % max_link)
	check(max_step < 0.3, "Tail teleported during movement: %f" % max_step)
	for frame in 60:
		await get_tree().physics_frame
	check(player.linear_velocity.length() < 0.2, "Player did not stop after releasing input")
	main.toggle_gameplay_pause()
	var paused_position = player.global_position
	var paused_growth = player.segments[0].growth_timer
	for frame in 30:
		await get_tree().physics_frame
	check(player.global_position.is_equal_approx(paused_position), "Pause did not freeze physics")
	check(is_equal_approx(player.segments[0].growth_timer, paused_growth), "Pause did not freeze growth")
	main.toggle_gameplay_pause()
	main.save_game_state()
	var saved_positions = player.get_segment_positions()
	main.free()
	main = MAIN.instantiate()
	add_child(main)
	player = main.player
	check(main.score == 60 and player.segments.size() == 6, "Save/resume lost score or body length")
	for index in player.segments.size():
		var saved = saved_positions[index].position
		check(player.segments[index].position.distance_to(Vector3(saved.x, saved.y, saved.z)) < 0.01, "Save/resume reversed the body order")
	for frame in 240:
		await get_tree().physics_frame
	check(not player.has_lost, "Intentional inactivity killed the player")
	for segment in player.segments:
		check(segment.position.y > 0.3 and is_equal_approx(segment.current_scale, 1.0), "Resumed body disappeared or failed to finish growth")
	# Real wall contact must still end the session once, and prevent more food.
	Input.action_press("move_right")
	for frame in 240:
		await get_tree().physics_frame
		if main.is_game_over:
			break
	Input.action_release("move_right")
	check(main.is_game_over and player.has_lost, "Wall collision failed to end the run")
	check(not FileAccess.file_exists(GameState.SAVE_FILE), "Game over retained a resumable dead session")
	main.free()
	Engine.time_scale = 1.0
	print("Gameplay regression: max link %.3f, max tail step %.3f" % [max_link, max_step])
	if not failed:
		print("Gameplay regression passed")
	get_tree().quit(1 if failed else 0)
