extends "res://scripts/physics_object.gd"
class_name Player

const SEGMENT_SCENE = preload("res://scenes/segment.tscn")

signal food_collected(total_food_eaten: int)
signal score_earned(points: int, popup_position: Vector3)
signal player_lost

const BASE_COLOR = Color(0.18, 0.49, 1.0)
const BASE_EMISSION = Color(0.12, 0.42, 1.0)
const STUCK_WARNING_COLOR = Color(0.55, 0.55, 0.55)
const STUCK_DANGER_COLOR = Color(1.0, 0.2, 0.2)
const STUCK_MIN_SPEED = 1.5
const STUCK_CHECK_INTERVAL = 0.5
const STUCK_WARNING_START = 1.0
const STUCK_TIMEOUT = 3.0
const BASE_MAX_SPEED = 8.0
const SPEED_BOOST_BASE = 1.0
const BONUS_SPEED_PER_FEED = 0.025
const MAX_SPEED_BOOST = 1.5
const DRIVE_ACCELERATION = 46.0
const DRIVE_RESPONSE = 18.0
const COAST_DECELERATION = 14.0
const OVERSPEED_DECELERATION = 16.0
const REVERSE_BRAKE_ACCELERATION = 68.0
const REVERSE_ALIGNMENT = -0.966
const TURN_RATE = 12.0
const DIGESTION_DURATION = 0.16
const TRAIL_STEP = 0.08
const PICKUP_RADIUS = 0.8
const PICKUP_VERTICAL_RADIUS = 1.1
const PICKUP_SWEEP_SCALE = Vector3(1.0, PICKUP_RADIUS / PICKUP_VERTICAL_RADIUS, 1.0)
const PICKUP_OBSTACLES = PhysicsConstants.LAYER_BARRIER | PhysicsConstants.LAYER_PHYSICAL | PhysicsConstants.LAYER_SEGMENT
const SCORE_SPEED_REFERENCE = 0.5
const MAX_SCORE_MULTIPLIER = 3.0
const PICKUP_IMPULSE = 2.5
const MAX_PICKUP_BOOST = 4.0
const PICKUP_BOOST_DECAY = 10.0
const HEAD_MAX_CONTACTS = 12

var facing_direction: Vector3 = Vector3.FORWARD
var segments: Array[Segment] = []
var trail: Array[Vector3] = []
var has_started_moving: bool = false
var food_eaten: int = 0
var current_speed_boost: float = SPEED_BOOST_BASE
var is_dead: bool = false
var has_lost: bool = false
var unkillable: bool = false
var is_digesting: bool = false
var digestion_timer: float = 0.0
var input_dir: Vector3 = Vector3.ZERO
var pending_pickup_impulse: float = 0.0
var pickup_speed_bonus: float = 0.0
var previous_pickup_position: Vector3
var pickup_position_initialized: bool = false
var stuck_elapsed: float = 0.0
var motion_sample_elapsed: float = 0.0
var motion_sample_start: Vector2

func _ready() -> void:
	super()
	material_type = PhysicsConstants.MATERIAL_PLAYER
	collision_layer = PhysicsConstants.LAYER_PLAYER
	collision_mask = PhysicsConstants.LAYER_ARENA | PhysicsConstants.LAYER_PHYSICAL | PhysicsConstants.LAYER_SEGMENT
	max_contacts_reported = HEAD_MAX_CONTACTS
	continuous_cd = true
	lock_rotation = true
	linear_damp = 0.0
	physics_material_override.friction = 0.0
	physics_material_override.bounce = 0.0
	max_speed = calculate_max_speed(current_speed_boost)
	apply_color(BASE_COLOR, BASE_EMISSION, 0.6)

func _physics_process(delta: float) -> void:
	mesh_instance.rotation.y = atan2(-facing_direction.x, -facing_direction.z)
	input_dir = Vector3.ZERO
	if OS.is_debug_build() and Input.is_action_just_pressed("toggle_unkillable"):
		unkillable = not unkillable
	if not has_lost and global_position.y < PhysicsConstants.FALL_LIMIT_Y:
		lose()
	if not has_lost:
		var raw_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var camera = get_viewport().get_camera_3d()
		var right = Vector3.RIGHT
		var forward = Vector3.FORWARD
		if camera:
			right = camera.global_basis.x
			right.y = 0.0
			right = right.normalized()
			# Cross product remains stable even for a straight-down camera.
			forward = Vector3.UP.cross(right)
		input_dir = right * raw_input.x - forward * raw_input.y
		if not input_dir.is_zero_approx():
			has_started_moving = true
		_update_stuck(delta)
		if not has_lost:
			_collect_food()
			_update_body(delta)
	if is_digesting:
		digestion_timer += delta
		if digestion_timer >= DIGESTION_DURATION:
			finish_digestion()
		else:
			_update_digestion_mesh()

func _update_stuck(delta: float) -> void:
	if not has_started_moving or unkillable:
		stuck_elapsed = 0.0
		motion_sample_elapsed = 0.0
		_update_stuck_color(delta)
		return

	var position_xz = Vector2(global_position.x, global_position.z)
	if motion_sample_elapsed == 0.0:
		motion_sample_start = position_xz
	motion_sample_elapsed += delta
	var distance = motion_sample_start.distance_to(position_xz)
	# Net horizontal movement filters out vertical bounce and contact jitter.
	if distance >= STUCK_MIN_SPEED * maxf(motion_sample_elapsed, STUCK_CHECK_INTERVAL):
		stuck_elapsed = 0.0
	if motion_sample_elapsed + 0.000001 >= STUCK_CHECK_INTERVAL:
		var sample_duration = maxf(motion_sample_elapsed, STUCK_CHECK_INTERVAL)
		if distance < STUCK_MIN_SPEED * sample_duration:
			var was_warned := stuck_elapsed >= STUCK_WARNING_START
			stuck_elapsed += sample_duration
			if not was_warned and stuck_elapsed >= STUCK_WARNING_START:
				SoundFx.play(SoundFx.Cue.WARNING, 0.61)
		motion_sample_elapsed = 0.0
	if stuck_elapsed + 0.000001 >= STUCK_TIMEOUT:
		lose()
	else:
		_update_stuck_color(delta)

func _update_stuck_color(delta: float) -> void:
	var warning = clampf((stuck_elapsed - STUCK_WARNING_START) / (STUCK_TIMEOUT - STUCK_WARNING_START), 0.0, 1.0)
	var color = BASE_COLOR
	if stuck_elapsed >= STUCK_WARNING_START:
		color = STUCK_WARNING_COLOR.lerp(STUCK_DANGER_COLOR, warning)
	var blend = 1.0 - exp(-12.0 * delta)
	apply_color(current_color.lerp(color, blend), BASE_EMISSION.lerp(STUCK_DANGER_COLOR, warning), 0.6 + warning)

func _collect_food() -> void:
	var start = previous_pickup_position if pickup_position_initialized else global_position
	var scaled_start = start * PICKUP_SWEEP_SCALE
	var scaled_end = global_position * PICKUP_SWEEP_SCALE
	var speed = Vector2(linear_velocity.x, linear_velocity.z).length()
	var score_multiplier = clampf(speed / (max_speed * SCORE_SPEED_REFERENCE), 1.0, MAX_SCORE_MULTIPLIER)
	for candidate in get_tree().get_nodes_in_group("food"):
		var food = candidate as Food
		if not food or not food.is_available():
			continue
		# Sweep the head's movement to catch pickups at speed, then check for
		# solid geometry between the approach point and the food.
		var point = food.get_pickup_position()
		var scaled_point = point * PICKUP_SWEEP_SCALE
		var nearest = Geometry3D.get_closest_point_to_segment(scaled_point, scaled_start, scaled_end)
		if scaled_point.distance_squared_to(nearest) > PICKUP_RADIUS * PICKUP_RADIUS:
			continue
		var ray = PhysicsRayQueryParameters3D.create(nearest / PICKUP_SWEEP_SCALE, point, PICKUP_OBSTACLES)
		ray.hit_from_inside = true
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		var points = food.eat(self)
		if points <= 0.0:
			continue
		food_eaten += 1
		current_speed_boost = minf(SPEED_BOOST_BASE + food_eaten * BONUS_SPEED_PER_FEED, MAX_SPEED_BOOST)
		max_speed = calculate_max_speed(current_speed_boost)
		# Growth belongs to the pickup, not the end of a cosmetic animation.
		add_segment()
		pending_pickup_impulse = minf(pending_pickup_impulse + PICKUP_IMPULSE, MAX_PICKUP_BOOST)
		start_digestion()
		score_earned.emit(roundi(points * score_multiplier), global_position + Vector3.UP * 1.5)
		food_collected.emit(food_eaten)
	previous_pickup_position = global_position
	pickup_position_initialized = true

func _update_body(delta: float) -> void:
	var head = Vector3(global_position.x, SegmentConstants.CENTER_HEIGHT, global_position.z)
	if trail.is_empty():
		trail.append(head)
	if head.distance_to(trail[0]) >= TRAIL_STEP:
		trail.push_front(head)
	# Sample the recorded path by distance, not by frame count or spring force.
	var path: Array[Vector3] = [head]
	path.append_array(trail)
	var edge = 0
	var traversed = 0.0
	for index in segments.size():
		var wanted = (index + 1) * SegmentConstants.TARGET_DISTANCE
		while edge + 1 < path.size() and traversed + path[edge].distance_to(path[edge + 1]) < wanted:
			traversed += path[edge].distance_to(path[edge + 1])
			edge += 1
		var destination = path[edge]
		if edge + 1 < path.size():
			var length = path[edge].distance_to(path[edge + 1])
			destination = path[edge].lerp(path[edge + 1], (wanted - traversed) / maxf(length, 0.0001))
		# With no older path, new growth stays at the tail until we move.
		segments[index].set_path_target(destination, delta)
	var keep = maxi(edge + 3, 3)
	if trail.size() > keep:
		trail.resize(keep)

func rebuild_trail() -> void:
	trail.clear()
	trail.append(Vector3(global_position.x, SegmentConstants.CENTER_HEIGHT, global_position.z))
	for segment in segments:
		trail.append(Vector3(segment.global_position.x, SegmentConstants.CENTER_HEIGHT, segment.global_position.z))
	previous_pickup_position = global_position
	pickup_position_initialized = true
	reset_physics_interpolation()

func add_segment(growth_state: float = 0.0, saved_pos: Vector3 = Vector3.ZERO, use_saved_position: bool = false) -> Segment:
	if is_dead:
		return null
	var segment: Segment = SEGMENT_SCENE.instantiate()
	var leader: Node3D = self if segments.is_empty() else segments.back()
	var spawn_pos = saved_pos if use_saved_position else leader.global_position
	spawn_pos.y = SegmentConstants.CENTER_HEIGHT
	segment.position = spawn_pos
	get_parent().add_child(segment)
	segment.target = leader
	segment.init_with_growth(growth_state)
	segments.append(segment)
	segment.reset_physics_interpolation()
	return segment

func get_segment_positions() -> Array:
	var positions = []
	for segment in segments:
		positions.append(segment.get_save_data())
	return positions

func get_save_data() -> Dictionary:
	var base_data = super.get_save_data()
	base_data["facing_direction"] = {
		"x": facing_direction.x,
		"y": facing_direction.y,
		"z": facing_direction.z
	}
	base_data["food_eaten"] = food_eaten
	base_data["current_speed_boost"] = current_speed_boost
	base_data["pending_pickup_impulse"] = pending_pickup_impulse
	base_data["pickup_speed_bonus"] = pickup_speed_bonus
	if is_digesting:
		base_data["digestion_timer"] = digestion_timer
	base_data["has_started_moving"] = has_started_moving
	base_data["stuck_elapsed"] = stuck_elapsed
	if motion_sample_elapsed > 0.0:
		base_data["motion_sample"] = {
			"elapsed": motion_sample_elapsed,
			"start": {"x": motion_sample_start.x, "y": 0.0, "z": motion_sample_start.y},
		}
	base_data["segments"] = get_segment_positions()
	var saved_trail: Array[Dictionary] = []
	for point in trail:
		saved_trail.append({"x": point.x, "y": point.y, "z": point.z})
	base_data["trail"] = saved_trail
	return base_data

func restore_from_save(data: Dictionary) -> void:
	var state: Dictionary = data.get("player_state", {})
	if state.is_empty():
		return

	restore_from_save_data(state)
	# Old digestion saves may contain a pulsing collider or a fallen head.
	apply_physics_scale(1.0, true)
	if global_position.y < 0.3:
		global_position.y = 0.5
		linear_velocity.y = 0.0
	facing_direction.y = 0.0
	var saved_facing_direction: Variant = state.get("facing_direction")
	if saved_facing_direction is Dictionary:
		var restored_direction = _vector_from_save(saved_facing_direction, Vector3.FORWARD)
		if restored_direction.length_squared() > 0.001:
			facing_direction = Vector3(restored_direction.x, 0.0, restored_direction.z).normalized()
			if facing_direction.is_zero_approx():
				facing_direction = Vector3.FORWARD
	food_eaten = max(int(state.get("food_eaten", 0)), 0)
	current_speed_boost = clampf(float(state.get("current_speed_boost", SPEED_BOOST_BASE)), SPEED_BOOST_BASE, MAX_SPEED_BOOST)
	max_speed = calculate_max_speed(current_speed_boost)
	pending_pickup_impulse = float(state.get("pending_pickup_impulse", 0.0))
	pickup_speed_bonus = float(state.get("pickup_speed_bonus", 0.0))
	if state.has("digestion_timer"):
		is_digesting = true
		digestion_timer = float(state.digestion_timer)
		_update_digestion_mesh()
	has_started_moving = state.get("has_started_moving", false)
	stuck_elapsed = float(state.get("stuck_elapsed", 0.0)) if has_started_moving else 0.0
	if has_started_moving and state.has("motion_sample"):
		var sample: Dictionary = state.motion_sample
		motion_sample_elapsed = float(sample.elapsed)
		motion_sample_start = Vector2(sample.start.x, sample.start.z)

func _vector_from_save(data: Variant, fallback: Vector3) -> Vector3:
	if not data is Dictionary:
		return fallback
	return Vector3(
		float(data.get("x", fallback.x)),
		float(data.get("y", fallback.y)),
		float(data.get("z", fallback.z))
	)

func lose() -> void:
	if has_lost or unkillable:
		return
	has_lost = true
	is_dead = true
	apply_color(Color(0.3, 0.1, 0.1), Color(0.2, 0, 0), 0.1)
	for segment in segments:
		segment.release_from_chain.call_deferred()
	player_lost.emit()

func die() -> void:
	lose()

func start_digestion() -> void:
	is_digesting = true
	digestion_timer = 0.0

func _update_digestion_mesh() -> void:
	var progress = clampf(digestion_timer / DIGESTION_DURATION, 0.0, 1.0)
	mesh_instance.scale = Vector3.ONE * (1.0 + sin(progress * PI) * 0.15)

func finish_digestion() -> void:
	is_digesting = false
	digestion_timer = 0.0
	mesh_instance.scale = Vector3.ONE

static func calculate_max_speed(speed_boost: float) -> float:
	return minf(BASE_MAX_SPEED * maxf(speed_boost, SPEED_BOOST_BASE), PhysicsConstants.PLAYER_MAX_SPEED)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if DebugTelemetry.enabled:
		DebugTelemetry.record_contacts(self, state)
	if not has_lost and not unkillable:
		for index in state.get_contact_count():
			var collider = state.get_contact_collider_object(index)
			if collider is Node and collider.is_in_group("dangerous"):
				lose()
				break
	if not has_lost:
		_flash_contacts(state)
	var horizontal = Vector3(state.linear_velocity.x, 0.0, state.linear_velocity.z)
	pickup_speed_bonus = move_toward(pickup_speed_bonus, 0.0, PICKUP_BOOST_DECAY * state.step)
	horizontal = _drive_velocity(horizontal, state.step)
	state.linear_velocity = Vector3(horizontal.x, state.linear_velocity.y, horizontal.z)
	if pending_pickup_impulse > 0.0 and not has_lost:
		var direction = input_dir.normalized() if not input_dir.is_zero_approx() else facing_direction
		if horizontal.length_squared() > 0.01:
			direction = horizontal.normalized()
		state.apply_central_impulse(direction * pending_pickup_impulse * mass)
		pickup_speed_bonus = minf(pickup_speed_bonus + pending_pickup_impulse, MAX_PICKUP_BOOST)
		horizontal = Vector3(state.linear_velocity.x, 0.0, state.linear_velocity.z).limit_length(max_speed + MAX_PICKUP_BOOST)
		state.linear_velocity = Vector3(horizontal.x, state.linear_velocity.y, horizontal.z)
	pending_pickup_impulse = 0.0
	if horizontal.length_squared() > 0.01:
		facing_direction = horizontal.normalized()
	physics_pos = state.transform.origin

func _drive_velocity(velocity: Vector3, step: float) -> Vector3:
	if has_lost or input_dir.is_zero_approx():
		return velocity.move_toward(Vector3.ZERO, COAST_DECELERATION * step)

	var direction = input_dir.normalized()
	var speed = velocity.length()
	var heading = velocity / speed if speed > 0.01 else direction
	# Brake a direct reversal before changing heading. A half-turn would
	# choose a side arbitrarily and could steer the head into a hazard.
	if heading.dot(direction) <= REVERSE_ALIGNMENT:
		return velocity.move_toward(Vector3.ZERO, REVERSE_BRAKE_ACCELERATION * step)

	var turn_limit = TURN_RATE * step
	var angle = heading.signed_angle_to(direction, Vector3.UP)
	heading = heading.rotated(Vector3.UP, clampf(angle, -turn_limit, turn_limit))
	var target_speed = (max_speed + pickup_speed_bonus) * input_dir.length()
	var speed_error = target_speed - speed
	var acceleration = minf(DRIVE_ACCELERATION, speed_error * DRIVE_RESPONSE) if speed_error > 0.0 else OVERSPEED_DECELERATION
	speed = move_toward(speed, target_speed, acceleration * step)
	return heading * minf(speed, max_speed + MAX_PICKUP_BOOST)
