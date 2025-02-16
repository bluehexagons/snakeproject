extends Node

const CELL_SIZE = 2.0
const GRID_LAYERS = 4

var grid = {}
var object_cells = {}
var cell_coords = Vector2i()  # Reusable vector to avoid allocations

func _init():
	# Initialize empty grid
	grid = {}
	object_cells = {}

func get_cell_coords(pos: Vector3) -> Vector2i:
	cell_coords.x = floori(pos.x / CELL_SIZE)
	cell_coords.y = floori(pos.z / CELL_SIZE)
	return cell_coords

func insert(obj: Node3D, layer: int = 0) -> void:
	var coords = get_cell_coords(obj.global_position)
	var key = str(coords.x) + "," + str(coords.y) + "," + str(layer)
	
	if !grid.has(key):
		grid[key] = []
	grid[key].append(obj)
	object_cells[obj] = coords

func remove(obj: Node3D, layer: int = 0) -> void:
	var coords = object_cells.get(obj)
	if coords:
		var key = str(coords.x) + "," + str(coords.y) + "," + str(layer)
		if grid.has(key):
			grid[key].erase(obj)
			if grid[key].is_empty():
				grid.erase(key)
		object_cells.erase(obj)

func update_position(obj: Node3D, layer: int = 0) -> void:
	var new_coords = get_cell_coords(obj.global_position)
	var old_coords = object_cells.get(obj)
	
	if old_coords != new_coords:
		remove(obj, layer)
		insert(obj, layer)

func get_nearby(pos: Vector3, radius: float = CELL_SIZE, layer: int = 0) -> Array:
	var cells_to_check = ceili(radius / CELL_SIZE)
	var pos_coords = get_cell_coords(pos)
	var nearby = []
	
	# Preallocate capacity for better performance
	nearby.resize(16)
	var nearby_count = 0
	
	for x in range(pos_coords.x - cells_to_check, pos_coords.x + cells_to_check + 1):
		for y in range(pos_coords.y - cells_to_check, pos_coords.y + cells_to_check + 1):
			var key = str(x) + "," + str(y) + "," + str(layer)
			if grid.has(key):
				var cell = grid[key]
				for obj in cell:
					if nearby_count >= nearby.size():
						nearby.resize(nearby.size() * 2)
					nearby[nearby_count] = obj
					nearby_count += 1
	
	# Trim array to actual size
	nearby.resize(nearby_count)
	return nearby

func clear() -> void:
	grid.clear()
	object_cells.clear()
