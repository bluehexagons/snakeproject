extends Node

const LOAD_TARGETS = [
	"res://scripts/collision_handler.gd",
	"res://scripts/game_camera.gd",
	"res://scripts/game_manager.gd",
	"res://scripts/game_state.gd",
	"res://scripts/food.gd",
	"res://scripts/physics_object.gd",
	"res://scripts/physics_constants.gd",
	"res://scripts/segment_constants.gd",
	"res://scripts/chain_physics.gd",
	"res://scripts/player.gd",
	"res://scripts/segment.gd",
	"res://scripts/rock.gd",
	"res://scenes/player.tscn",
	"res://scenes/segment.tscn",
	"res://scenes/rock.tscn",
	"res://scenes/main.tscn",
	"res://scenes/main_menu.tscn",
]

const SPATIAL_GRID = preload("res://scripts/spatial_grid.gd")
const STUCK_DETECTOR = preload("res://scripts/stuck_detector.gd")
const CHAIN_PHYSICS = preload("res://scripts/chain_physics.gd")
const ROCK_SCENE = preload("res://scenes/rock.tscn")

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var failed := false
	if not GameState.is_supported_save_version(1) or not GameState.is_supported_save_version(1.0):
		push_error("Save version validation rejected a supported numeric version")
		failed = true
	if GameState.is_supported_save_version(0.5) or GameState.is_supported_save_version("1"):
		push_error("Save version validation accepted an invalid version")
		failed = true
	if not GameState.is_valid_saved_score(0) or not GameState.is_valid_saved_score(1.0):
		push_error("Save score validation rejected a supported numeric score")
		failed = true
	if GameState.is_valid_saved_score(-1) or GameState.is_valid_saved_score(1.5) or GameState.is_valid_saved_score("1"):
		push_error("Save score validation accepted an invalid score")
		failed = true
	if not GameState.is_valid_saved_vector({"x": 1, "y": 2.0, "z": -3}):
		push_error("Save vector validation rejected a supported vector")
		failed = true
	if GameState.is_valid_saved_vector({"x": 1001, "y": 0, "z": 0}) or GameState.is_valid_saved_vector({"x": "1", "y": 0, "z": 0}):
		push_error("Save vector validation accepted an invalid vector")
		failed = true

	for path in LOAD_TARGETS:
		var resource := load(path)
		if resource == null:
			push_error("Failed to load %s" % path)
			failed = true

	var grid = SPATIAL_GRID.new()
	var segment := Node3D.new()
	segment.position = Vector3.ZERO
	var rock := Node3D.new()
	rock.position = Vector3.ZERO
	add_child(segment)
	add_child(rock)
	grid.insert(segment, 1)
	grid.insert(rock, 2)
	if grid.get_nearby(Vector3.ZERO, 1.0).size() != 2:
		push_error("Spatial grid did not query all layers")
		failed = true
	if grid.get_nearby(Vector3.ZERO, 1.0, 1).size() != 1:
		push_error("Spatial grid did not filter by layer")
		failed = true
	segment.position = Vector3(1.5, 0, 0)
	grid.update_position(segment, 1)
	if not grid.get_nearby(Vector3.ZERO, 1.0, 1).is_empty():
		push_error("Spatial grid returned an object outside the requested radius")
		failed = true
	segment.position = Vector3(4, 0, 0)
	grid.update_position(segment, 1)
	if grid.get_nearby(Vector3.ZERO, 1.0, 1).size() != 0:
		push_error("Spatial grid left an object in its old cell")
		failed = true
	segment.free()
	rock.free()
	grid.free()

	var queued_body := Node3D.new()
	add_child(queued_body)
	CollisionHandler.spatial_grid.insert(queued_body)
	queued_body.queue_free()
	if CollisionHandler.get_nearby_bodies(Vector3.ZERO, 1.0).has(queued_body):
		push_error("Collision handler returned a body queued for deletion")
		failed = true
	await get_tree().process_frame

	var detector = STUCK_DETECTOR.new()
	for _frame in range(40):
		detector.update(Vector3.ZERO, 1.0 / 60.0)
	if not detector.is_stuck or detector.get_stuck_duration() <= 0.0:
		push_error("Stuck detector did not identify a stationary object")
		failed = true
	for frame in range(30):
		detector.update(Vector3(frame * 0.2, 0, 0), 1.0 / 60.0)
	if detector.is_stuck:
		push_error("Stuck detector did not recover after movement")
		failed = true

	var chain_data = CHAIN_PHYSICS.calculate_chain_forces(
		Vector3.ZERO,
		Vector3(3, 0, 0),
		0,
		2,
		1.4,
		1.0
	)
	if chain_data.spring_force.length() <= 0.0:
		push_error("Chain physics did not produce a spring force for a stretched link")
		failed = true

	var test_rock = ROCK_SCENE.instantiate()
	add_child(test_rock)
	test_rock.setup_rock(Vector3(2, 0, 3))
	var saved_rock_data = test_rock.get_save_data()
	test_rock.position = Vector3.ZERO
	test_rock.restore_from_save_data(saved_rock_data)
	if test_rock.global_position.distance_to(Vector3(2, 15, 3)) > 0.001:
		push_error("Rock restore did not preserve the saved transform")
		failed = true
	test_rock.queue_free()
	await get_tree().process_frame

	var main_scene := load("res://scenes/main.tscn")
	if main_scene and main_scene is PackedScene:
		var main: Node = main_scene.instantiate()
		add_child(main)
		for i in 5:
			await get_tree().physics_frame
		main.queue_free()
		await get_tree().process_frame

	if failed:
		get_tree().quit(1)
		return

	print("Smoke test passed")
	get_tree().quit(0)
