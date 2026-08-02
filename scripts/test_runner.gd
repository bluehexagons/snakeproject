extends Node

const LOAD_TARGETS = [
	"res://scripts/physics_object.gd",
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

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var failed := false
	for path in LOAD_TARGETS:
		var resource := load(path)
		if resource == null:
			push_error("Failed to load %s" % path)
			failed = true

	var grid = SPATIAL_GRID.new()
	var segment = Node3D.new()
	segment.position = Vector3.ZERO
	var rock = Node3D.new()
	rock.position = Vector3.ZERO
	add_child(segment)
	add_child(rock)
	grid.insert(segment, 1)
	grid.insert(rock, 2)
	if grid.get_nearby(Vector3.ZERO, 1.0).size() != 2:
		push_error("Spatial grid did not query all layers")
		failed = true
	segment.free()
	rock.free()
	grid.free()

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
