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
]

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var failed := false
	for path in LOAD_TARGETS:
		var resource := load(path)
		if resource == null:
			push_error("Failed to load %s" % path)
			failed = true

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
