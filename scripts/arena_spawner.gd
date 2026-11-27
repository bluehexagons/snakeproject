extends RefCounted
class_name ArenaSpawner

const FOOD_SCENE = preload("res://scenes/food.tscn")
const ROCK_SCENE = preload("res://scenes/rock.tscn")
const SPAWN_AREA_SIZE = Vector2(8, 8)
const PLAYER_SPAWN_HEIGHT = 0.5
const MIN_ROCK_SPACING = 2.0
const DANGER_START_SCORE = 50
const DANGER_MAX_SCORE = 300
const MAX_DANGER_PROBABILITY = 0.8

const SAFE_SPAWN_DISTANCE = 4.0
const SAFE_FORWARD_ANGLE = 60.0

const MIN_FOOD_COUNT = 3
const MIN_FOOD_DISTANCE = 3.0
const PREFERRED_PLAYER_DISTANCE = 8.0
const MIN_PLAYER_DISTANCE = 2.0
const MIN_FOOD_DANGER_DISTANCE = 1.5
const MIN_FOOD_ROCK_DISTANCE = 1.0
const MIN_ROCK_PLAYER_DISTANCE = 2.5
const MIN_BODY_SPAWN_DISTANCE = 1.0
const MAX_FOOD_SPAWN_ATTEMPTS = 30
const FALLBACK_FOOD_SPAWN_LIMIT = 9 # The barriers sit at +/-11.
const MAX_ROCK_SPAWN_ATTEMPTS = 30

var _arena: Node3D

func _init(arena: Node3D) -> void:
	_arena = arena

func initial_player_position() -> Vector3:
	# Start the sphere above the floor to avoid an initial solver overlap.
	return _random_position(SPAWN_AREA_SIZE) + Vector3.UP * PLAYER_SPAWN_HEIGHT

func refill_food(player: Player, check_covered: bool = false) -> void:
	var foods = _arena.get_tree().get_nodes_in_group("food").filter(
		func(food: Food): return food.is_available()
	)
	if not check_covered and foods.size() >= MIN_FOOD_COUNT:
		return

	var hazards = _arena.get_tree().get_nodes_in_group("dangerous").filter(
		func(node): return not node.is_queued_for_deletion()
	)
	var rocks = _arena.get_tree().get_nodes_in_group("rock").filter(
		func(rock): return not rock.is_queued_for_deletion()
	)
	if check_covered:
		for index in foods.size():
			var food: Food = foods[index]
			var cover_id = _covering_rock_id(food.get_pickup_position(), rocks)
			# Give moving rocks a chance to clear the pickup on their own.
			if cover_id != 0 and cover_id == food.covering_rock_id:
				var replacement: Variant = _find_food_spawn_position(player, foods, hazards, rocks)
				if replacement != null:
					foods[index] = spawn_food_at(replacement)
					food.queue_free()
			food.covering_rock_id = cover_id

	while foods.size() < MIN_FOOD_COUNT:
		var spawn_position: Variant = _find_food_spawn_position(player, foods, hazards, rocks)
		if spawn_position == null:
			break
		foods.append(spawn_food_at(spawn_position))

func spawn_food_at(spawn_position: Vector3) -> Food:
	var food: Food = FOOD_SCENE.instantiate()
	food.position = spawn_position
	_arena.add_child(food)
	return food

func _covering_rock_id(point: Vector3, rocks: Array) -> int:
	for rock: Rock in rocks:
		if rock.covers_pickup(point):
			return rock.get_instance_id()
	return 0

func _find_food_spawn_position(player: Player, foods: Array, hazards: Array, rocks: Array) -> Variant:
	var best_position: Variant = null
	var best_score = 0.0
	var area = SPAWN_AREA_SIZE * 0.9
	for _attempt in MAX_FOOD_SPAWN_ATTEMPTS:
		var candidate = _random_position(area)
		var candidate_score = _food_spawn_score(player, candidate, foods, hazards, rocks, MIN_FOOD_DISTANCE)
		if candidate_score > best_score:
			best_score = candidate_score
			best_position = candidate
	if best_position != null:
		return best_position

	# Cover the wider arena if the random sample finds nothing. Only the
	# spacing between food pickups can relax.
	for x in range(-FALLBACK_FOOD_SPAWN_LIMIT, FALLBACK_FOOD_SPAWN_LIMIT + 1):
		for z in range(-FALLBACK_FOOD_SPAWN_LIMIT, FALLBACK_FOOD_SPAWN_LIMIT + 1):
			var candidate = Vector3(x, 0, z)
			var candidate_score = _food_spawn_score(player, candidate, foods, hazards, rocks, MIN_FOOD_DISTANCE * 0.5)
			if candidate_score > best_score:
				best_score = candidate_score
				best_position = candidate
	return best_position

func _food_spawn_score(player: Player, candidate: Vector3, foods: Array, hazards: Array, rocks: Array, food_spacing: float) -> float:
	var player_distance = _horizontal_distance(_arena_position(player), candidate)
	if player_distance < MIN_PLAYER_DISTANCE or _has_nearby_node(candidate, player.segments, MIN_BODY_SPAWN_DISTANCE):
		return 0.0
	var hazard_distance = _nearest_horizontal_distance(candidate, hazards)
	if hazard_distance <= MIN_FOOD_DANGER_DISTANCE:
		return 0.0
	var rock_distance = _nearest_horizontal_distance(candidate, rocks)
	if rock_distance <= MIN_FOOD_ROCK_DISTANCE:
		return 0.0
	var food_distance = _nearest_horizontal_distance(candidate, foods)
	if food_distance <= food_spacing:
		return 0.0

	var spacing = minf(hazard_distance, minf(rock_distance, food_distance))
	var distance_factor = maxf(1.0 - absf(player_distance - PREFERRED_PLAYER_DISTANCE) / PREFERRED_PLAYER_DISTANCE, 0.0)
	return (1.0 if is_inf(spacing) else spacing) * (1.0 + distance_factor)

func _nearest_horizontal_distance(position: Vector3, nodes: Array) -> float:
	var nearest = INF
	for node in nodes:
		nearest = minf(nearest, _horizontal_distance(_arena_position(node), position))
	return nearest

func _has_nearby_node(position: Vector3, nodes: Array, clearance: float) -> bool:
	for node: Node3D in nodes:
		if _horizontal_distance(_arena_position(node), position) < clearance:
			return true
	return false

func spawn_rock(player: Player, score: int, force_safe: bool = false) -> bool:
	var player_position = _arena_position(player)
	var rocks = _arena.get_tree().get_nodes_in_group("rock").filter(
		func(rock: Rock): return not rock.is_queued_for_deletion()
	)
	var foods = _arena.get_tree().get_nodes_in_group("food").filter(
		func(food: Food): return food.is_available()
	)
	for _attempt in MAX_ROCK_SPAWN_ATTEMPTS:
		var candidate = _random_position(SPAWN_AREA_SIZE)
		if _horizontal_distance(player_position, candidate) < MIN_ROCK_PLAYER_DISTANCE:
			continue
		if _has_nearby_node(candidate, player.segments, MIN_BODY_SPAWN_DISTANCE):
			continue
		if _has_nearby_node(candidate, rocks, MIN_ROCK_SPACING):
			continue
		if _has_nearby_node(candidate, foods, MIN_FOOD_ROCK_DISTANCE):
			continue

		var rock: Rock = ROCK_SCENE.instantiate()
		_arena.add_child(rock)
		rock.setup_rock(candidate)
		var arena_facing := _arena.global_basis.inverse() * player.facing_direction
		if not force_safe and _should_spawn_dangerous_rock(candidate - player_position, arena_facing, score):
			rock.make_dangerous()
		return true

	push_warning("Failed to spawn a rock after %d attempts" % MAX_ROCK_SPAWN_ATTEMPTS)
	return false

func restore_rock(data: Dictionary) -> void:
	var rock: Rock = ROCK_SCENE.instantiate()
	_arena.add_child(rock)
	rock.restore_from_save_data(data)

func _should_spawn_dangerous_rock(offset: Vector3, facing: Vector3, score: int) -> bool:
	if score < DANGER_START_SCORE:
		return false
	var score_factor = clampf(float(score - DANGER_START_SCORE) / (DANGER_MAX_SCORE - DANGER_START_SCORE), 0.0, 1.0)
	if randf() >= score_factor * MAX_DANGER_PROBABILITY:
		return false
	offset.y = 0.0
	if offset.length() < SAFE_SPAWN_DISTANCE:
		return false
	facing.y = 0.0
	facing = facing.normalized() if facing.length_squared() > 0.001 else Vector3.FORWARD
	var angle = rad_to_deg(acos(clampf(offset.normalized().dot(facing), -1.0, 1.0)))
	return angle >= SAFE_FORWARD_ANGLE

func _random_position(half_size: Vector2) -> Vector3:
	return Vector3(randf_range(-half_size.x, half_size.x), 0.0, randf_range(-half_size.y, half_size.y))

func _arena_position(node: Node3D) -> Vector3:
	return node.position if node.get_parent() == _arena else _arena.to_local(node.global_position)

func _horizontal_distance(first: Vector3, second: Vector3) -> float:
	return Vector2(first.x, first.z).distance_to(Vector2(second.x, second.z))
