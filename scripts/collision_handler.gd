extends Node

# Spatial partitioning constants
const PROXIMITY_RADIUS = 1.0  # Base radius for proximity checks
const PROXIMITY_GRID_SIZE = 2.0  # Size of spatial grid cells
const MAX_BODIES_PER_CELL = 8  # Limit checks in dense areas

@onready var spatial_grid = preload("res://scripts/spatial_grid.gd").new()

func _ready():
	process_priority = 1

func _physics_process(_delta):
	spatial_grid.clear()
	for obj in get_tree().get_nodes_in_group("physics_object"):
		if obj.is_inside_tree() and not obj.is_queued_for_deletion():
			spatial_grid.insert(obj, get_object_layer(obj))

func get_nearby_bodies(pos: Vector3, radius: float = PROXIMITY_RADIUS) -> Array:
	var nearby = spatial_grid.get_nearby(pos, radius)
	return nearby.filter(func(obj): return is_instance_valid(obj) and obj.is_inside_tree())

func get_object_layer(obj: Node) -> int:
	if obj.is_in_group("segment"):
		return 1
	elif obj.is_in_group("rock"):
		return 2
	return 0
