extends Node3D

const PLAYER_SCENE = preload("res://scenes/player.tscn")
const SPAWN_AREA_SIZE = Vector2(8, 8)  # Keep within camera view
const BASE_CAMERA_SIZE = 15.0  # This is our reference size for 1:1 aspect ratio

@onready var camera = $Camera3D

func _ready():
	spawn_player()
	get_tree().root.size_changed.connect(_on_window_resize)
	_on_window_resize()

func spawn_player():
	var player = PLAYER_SCENE.instantiate()
	add_child(player)
	
	# Random position within spawn area
	var random_x = randf_range(-SPAWN_AREA_SIZE.x, SPAWN_AREA_SIZE.x)
	var random_z = randf_range(-SPAWN_AREA_SIZE.y, SPAWN_AREA_SIZE.y)
	player.position = Vector3(random_x, 0, random_z)

func _on_window_resize():
	var window_size = DisplayServer.window_get_size()
	var aspect_ratio = float(window_size.x) / float(window_size.y)
	
	# If window is wider than tall, maintain vertical size
	if aspect_ratio > 1.0:
		camera.size = BASE_CAMERA_SIZE
	# If window is taller than wide, maintain horizontal size
	else:
		camera.size = BASE_CAMERA_SIZE / aspect_ratio
