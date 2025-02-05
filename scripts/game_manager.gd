extends Node3D

const PLAYER_SCENE = preload("res://scenes/player.tscn")
const SPAWN_AREA_SIZE = Vector2(8, 8)  # Keep within camera view

func _ready():
	spawn_player()

func spawn_player():
	var player = PLAYER_SCENE.instantiate()
	add_child(player)
	
	# Random position within spawn area
	var random_x = randf_range(-SPAWN_AREA_SIZE.x, SPAWN_AREA_SIZE.x)
	var random_z = randf_range(-SPAWN_AREA_SIZE.y, SPAWN_AREA_SIZE.y)
	player.position = Vector3(random_x, 0, random_z)
