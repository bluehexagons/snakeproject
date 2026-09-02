extends Node
class_name SpatialGrid

const CELL_SIZE = 2.0
const GRID_LAYERS = 4

var grid: Dictionary = {}
var object_cells: Dictionary = {}

func get_cell_coords(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / CELL_SIZE), floori(pos.z / CELL_SIZE))

func _cell_key(coords: Vector2i, layer: int) -> Vector3i:
	return Vector3i(coords.x, coords.y, layer)

func insert(obj: Node3D, layer: int = 0) -> void:
	if object_cells.has(obj):
		remove(obj)

	var coords = get_cell_coords(obj.global_position)
	var key = _cell_key(coords, layer)
	
	if not grid.has(key):
		grid[key] = []
	grid[key].append(obj)
	object_cells[obj] = {"coords": coords, "layer": layer}

func remove(obj: Node3D, _layer: int = -1) -> void:
	var record: Dictionary = object_cells.get(obj, {})
	if record.is_empty():
		return

	var key = _cell_key(record.coords, record.layer)
	if grid.has(key):
		grid[key].erase(obj)
		if grid[key].is_empty():
			grid.erase(key)
	object_cells.erase(obj)

func update_position(obj: Node3D, layer: int = 0) -> void:
	var new_coords = get_cell_coords(obj.global_position)
	var old_record: Dictionary = object_cells.get(obj, {})
	
	if old_record.is_empty() or old_record.coords != new_coords or old_record.layer != layer:
		remove(obj)
		insert(obj, layer)

func get_nearby(pos: Vector3, radius: float = CELL_SIZE, layer: int = -1) -> Array[Node3D]:
	if not pos.is_finite() or is_nan(radius) or is_inf(radius) or radius < 0.0:
		return []

	var cells_to_check = ceili(maxf(radius, 0.0) / CELL_SIZE)
	var pos_coords = get_cell_coords(pos)
	var nearby: Array[Node3D] = []
	var layers = range(GRID_LAYERS) if layer < 0 else [layer]
	
	for x in range(pos_coords.x - cells_to_check, pos_coords.x + cells_to_check + 1):
		for y in range(pos_coords.y - cells_to_check, pos_coords.y + cells_to_check + 1):
			for current_layer in layers:
				var key = _cell_key(Vector2i(x, y), current_layer)
				if grid.has(key):
					for obj in grid[key]:
						if is_instance_valid(obj) and obj.global_position.distance_to(pos) <= radius:
							nearby.append(obj)

	return nearby

func clear() -> void:
	grid.clear()
	object_cells.clear()
