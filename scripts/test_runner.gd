extends Node

const LOAD_TARGETS = [
	"res://scripts/debug_telemetry.gd",
	"res://scripts/game_camera.gd",
	"res://scripts/game_manager.gd",
	"res://scripts/game_state.gd",
	"res://scripts/food.gd",
	"res://scripts/physics_object.gd",
	"res://scripts/physics_constants.gd",
	"res://scripts/segment_constants.gd",
	"res://scripts/player.gd",
	"res://scripts/segment.gd",
	"res://scripts/rock.gd",
	"res://scenes/player.tscn",
	"res://scenes/segment.tscn",
	"res://scenes/rock.tscn",
	"res://scenes/main.tscn",
	"res://scenes/main_menu.tscn",
]

const ROCK_SCENE = preload("res://scenes/rock.tscn")
const PLAYER_SCENE = preload("res://scenes/player.tscn")
const SEGMENT_SCENE = preload("res://scenes/segment.tscn")

class FailingSave:
	extends "res://scripts/game_state.gd"
	var fail_promotion = false
	func _promote_save(directory: DirAccess, source: String, destination: String) -> Error:
		if fail_promotion:
			return ERR_CANT_CREATE
		return super(directory, source, destination)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	if GameState.save_file_path.begins_with("user://"):
		push_error("Run tests using scripts/verify_project.py to isolate player saves")
		get_tree().quit(1)
		return
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

	if not _check_save_validation():
		failed = true
	if not _check_interrupted_save():
		failed = true

	for path in LOAD_TARGETS:
		var resource := load(path)
		if resource == null:
			push_error("Failed to load %s" % path)
			failed = true

	if not is_equal_approx(Player.calculate_max_speed(1.0), Player.BASE_MAX_SPEED):
		push_error("Player base speed limit did not use the unboosted cap")
		failed = true
	if not is_equal_approx(Player.calculate_max_speed(2.0), PhysicsConstants.PLAYER_MAX_SPEED):
		push_error("Player boosted speed limit did not respect the absolute cap")
		failed = true

	var rotated_ground_basis = Basis(Vector3.FORWARD, PI * 0.5)
	var local_ground_normal = rotated_ground_basis.inverse() * Vector3.UP
	if not PhysicsObject.is_ground_contact(local_ground_normal, rotated_ground_basis):
		push_error("Ground contact detection did not transform a rotating body's local normal")
		failed = true
	var stationary_separation = PhysicsObject.calculate_proximity_force(
		Vector3.RIGHT, 0.6, 1.2, 110.0, 2.0, Vector3.ZERO, 6.0
	)
	var approaching_separation = PhysicsObject.calculate_proximity_force(
		Vector3.RIGHT, 0.6, 1.2, 110.0, 2.0, Vector3.LEFT, 6.0
	)
	var departing_separation = PhysicsObject.calculate_proximity_force(
		Vector3.RIGHT, 0.6, 1.2, 110.0, 2.0, Vector3.RIGHT, 6.0
	)
	if approaching_separation.x >= stationary_separation.x or departing_separation.x <= stationary_separation.x or departing_separation.x > 0.0:
		push_error("Proximity damping did not resist closing motion and release separating bodies")
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
		if not is_instance_valid(main.player) or main.player.global_position.y < 0.2:
			push_error("Fresh player spawn intersected or fell through the ground")
			failed = true
		main.queue_free()
		await get_tree().process_frame

	if failed:
		get_tree().quit(1)
		return

	print("Smoke test passed")
	get_tree().quit(0)


func _check_save_validation() -> bool:
	var valid = {
		"score": 10,
		"player_state": {"position": {"x": 0, "y": 0.5, "z": 0}},
	}
	if not GameState.is_valid_save_data(valid):
		push_error("Minimal legacy save was rejected")
		return false
	var cases: Array[Dictionary] = []
	for field in ["food_eaten", "current_speed_boost", "current_scale", "ground_contact_timer", "is_grounded"]:
		var malformed = valid.duplicate(true)
		malformed.player_state[field] = {}
		cases.append(malformed)
	for count in [-1, 1.5, 2147483648]:
		var malformed = valid.duplicate(true)
		malformed.player_state.food_eaten = count
		cases.append(malformed)
	for value in [NAN, INF]:
		var malformed = valid.duplicate(true)
		malformed.player_state.current_speed_boost = value
		if GameState.is_valid_save_data(malformed):
			push_error("Non-finite speed boost was accepted")
			return false
	for entry in [
		{"segments": [{"position": {"x": 0, "y": 0.35, "z": 0}, "growth": []}]},
		{"trail": [{"x": "bad", "y": 0, "z": 0}]},
	]:
		var malformed = valid.duplicate(true)
		malformed.player_state.merge(entry)
		cases.append(malformed)
	for entry in [
		{"rocks": [{"position": {"x": 0, "y": 1, "z": 0}, "current_scale": {}}]},
		{"rocks": [{"position": {"x": 0, "y": 1, "z": 0}, "is_dangerous": "false"}]},
		{"food_positions": [null]},
	]:
		var malformed = valid.duplicate(true)
		malformed.merge(entry)
		cases.append(malformed)
	for malformed in cases:
		if not GameState.save_game_state(malformed):
			push_error("Failed to write malformed-save fixture")
			return false
		if GameState.is_valid_save_data(malformed) or GameState.has_saved_game():
			push_error("Malformed save was accepted by validation or Continue")
			return false
	if not GameState.save_game_state(valid) or not GameState.has_saved_game():
		push_error("Continue rejected a valid legacy save")
		return false
	return GameState.delete_save_game()

func _check_interrupted_save() -> bool:
	var storage = FailingSave.new()
	storage.save_file_path = GameState.save_file_path.get_base_dir().path_join("failure-save.dat")
	storage.best_score_file_path = GameState.save_file_path.get_base_dir().path_join("failure-best.dat")
	var original = {"score": 10, "player_state": {"position": {"x": 0, "y": 0.5, "z": 0}}}
	var passed = storage.save_game_state(original) and storage.save_best_score(10)
	storage.fail_promotion = true
	passed = not storage.save_game_state({"score": 20}) and passed
	passed = not storage.save_best_score(20) and passed
	# A missing primary after failed promotion must be recoverable by both
	# Continue and the gameplay loader, including after restarting the process.
	var recovered = load("res://scripts/game_state.gd").new()
	recovered.save_file_path = storage.save_file_path
	recovered.best_score_file_path = storage.best_score_file_path
	passed = recovered.has_saved_game() and recovered.load_game_state().get("score") == 10 and recovered.get_best_score() == 10 and passed
	passed = recovered.delete_save_game() and not recovered.has_saved_game() and passed
	passed = not FileAccess.file_exists(storage.save_file_path + ".tmp") and not FileAccess.file_exists(storage.save_file_path + ".bak") and passed
	storage.fail_promotion = false
	passed = storage.save_game_state(original) and storage.save_best_score(30) and passed
	passed = storage.get_best_score() == 30 and storage.delete_save_game() and passed
	storage.free()
	recovered.free()
	if not passed:
		push_error("Interrupted save recovery, cleanup, or subsequent write failed")
	return passed
