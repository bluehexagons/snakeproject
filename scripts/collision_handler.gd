extends Node

const PROXIMITY_RADIUS = 1.0
const SPATIAL_GRID_SCRIPT = preload("res://scripts/spatial_grid.gd")

var spatial_grid

func _ready() -> void:
	# Preloading keeps this autoload independent from the editor's global class
	# cache, which may not exist on a clean headless run.
	spatial_grid = SPATIAL_GRID_SCRIPT.new()
	add_child(spatial_grid)
	# Refresh before gameplay nodes query the index so they see the positions
	# produced by the previous physics tick.
	process_priority = -1

func _physics_process(_delta: float) -> void:
	spatial_grid.clear()
	for obj in get_tree().get_nodes_in_group("physics_object"):
		if obj.is_inside_tree() and not obj.is_queued_for_deletion():
			spatial_grid.insert(obj, get_object_layer(obj))

func get_nearby_bodies(pos: Vector3, radius: float = PROXIMITY_RADIUS) -> Array:
	var nearby = spatial_grid.get_nearby(pos, radius, -1)
	return nearby.filter(func(obj): return is_instance_valid(obj) and obj.is_inside_tree() and not obj.is_queued_for_deletion())

func get_object_layer(obj: Node3D) -> int:
	if obj.is_in_group("segment"):
		return 1
	elif obj.is_in_group("rock"):
		return 2
	return 0
