extends Node3D

const PLAYER_SCENE = preload("res://scenes/player.tscn")
const FOOD_SCENE = preload("res://scenes/food.tscn")
const SPAWN_AREA_SIZE = Vector2(8, 8)  # Keep within camera view
const BASE_CAMERA_SIZE = 15.0  # This is our reference size for 1:1 aspect ratio

var score: int = 0
@onready var camera = $Camera3D
@onready var ui = $UI

func _ready():
	spawn_player()
	spawn_food()
	get_tree().root.size_changed.connect(_on_window_resize)
	_on_window_resize()
	update_score(0)

func spawn_player():
	var player = PLAYER_SCENE.instantiate()
	add_child(player)
	
	# Random position within spawn area
	var random_x = randf_range(-SPAWN_AREA_SIZE.x, SPAWN_AREA_SIZE.x)
	var random_z = randf_range(-SPAWN_AREA_SIZE.y, SPAWN_AREA_SIZE.y)
	player.position = Vector3(random_x, 0, random_z)

func spawn_food():
	var food = FOOD_SCENE.instantiate()
	add_child(food)
	
	# Random position within spawn area
	var random_x = randf_range(-SPAWN_AREA_SIZE.x, SPAWN_AREA_SIZE.x)
	var random_z = randf_range(-SPAWN_AREA_SIZE.y, SPAWN_AREA_SIZE.y)
	food.position = Vector3(random_x, 0, random_z)

func on_food_collected():
	update_score(10)
	spawn_food()

func _on_window_resize():
	var window_size = DisplayServer.window_get_size()
	var aspect_ratio = float(window_size.x) / float(window_size.y)
	
	# If window is wider than tall, maintain vertical size
	if aspect_ratio > 1.0:
		camera.size = BASE_CAMERA_SIZE
	# If window is taller than wide, maintain horizontal size
	else:
		camera.size = BASE_CAMERA_SIZE / aspect_ratio

func update_score(points: int):
	score += points
	if ui:
		ui.update_score(score)
