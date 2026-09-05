extends "res://scripts/physics_object.gd"
class_name Player

const SEGMENT_SCENE = preload("res://scenes/segment.tscn")

signal food_collected(total_food_eaten: int)
signal score_earned(points: int, popup_position: Vector3)
signal player_lost

const LUNGE_FORCE = 20.0
const SEGMENT_PUSHBACK = 3.0
const SPEED_BOOST_BASE = 1.0
const COLOR_CHANGE_SPEED = 5.0
const SPEED_SCORE_MULTIPLIER = 1.5
const MAX_BONUS_SPEED_MULTIPLIER = 3.0
const BONUS_SPEED_PER_FEED = 0.05
const MAX_SPEED_BOOST = 15.0
const SEGMENT_SPAWN_OFFSET = 0.2
const SEGMENT_SPAWN_VELOCITY = 0.95
const STUCK_TIMEOUT = 3.0

const IDLE_WARNING_START = 1.0
const IDLE_DANGER_START = 2.0
const IDLE_EMISSION_START = 2.9

const BASE_COLOR = Color(0.2, 0.4, 1.0)
const IDLE_COLOR = Color(0.5, 0.5, 0.5)
const DANGER_COLOR = Color(0.8, 0.2, 0.2)
const FLASH_COLOR = Color(1.0, 0.2, 0.2)
const DEATH_COLOR = Color(0.3, 0.1, 0.1)

const BASE_EMISSION = Color(0.2, 0.4, 1.0)
const DANGER_EMISSION = Color(1.0, 0.2, 0.2)
const DEAD_EMISSION = Color(0.2, 0, 0)

const BASE_EMISSION_ENERGY = 0.6
const WARNING_EMISSION_ENERGY = 1.0
const DANGER_EMISSION_ENERGY = 2.0
const DEAD_EMISSION_ENERGY = 0.1

const DIGESTION_DURATION = 0.16
const DIGESTION_FLASH_INTENSITY = 0.3
const DIGESTION_PULSE_SCALE = 1.2

const UNKILLABLE_COLOR = Color(0.7, 0.9, 1.0)
const UNKILLABLE_EMISSION = Color(0.4, 0.6, 1.0)
const UNKILLABLE_EMISSION_ENERGY = 1.2

const SEGMENT_PROXIMITY_RADIUS = 1.2
const PROXIMITY_FORCE = 110.0
const PROXIMITY_FALLOFF = 2.0
const PROXIMITY_VELOCITY_DAMPING = 6.0

const DIRECT_ACCELERATION = 65.0
const BASE_MAX_SPEED = 18.0
const TURN_RESPONSIVENESS = 10.0
const MOVEMENT_RAMP_TIME = 0.25
const MOVEMENT_DECAY = 0.95
const INPUT_SMOOTHING = 0.25

var facing_direction: Vector3 = Vector3.FORWARD
var segments: Array[Segment] = []
var has_started_moving: bool = false
var food_eaten: int = 0
var current_speed_boost: float = SPEED_BOOST_BASE
var is_dead: bool = false
var has_lost: bool = false
var stuck_detector: StuckDetector
var dead_time: float = 0.0
var is_digesting: bool = false
var digestion_timer: float = 0.0
var digestion_flash_material: StandardMaterial3D
var unkillable: bool = false

var physics_basis: Basis
var visual_basis: Basis
var collected_food: bool = false
var input_dir: Vector3 = Vector3.ZERO
var input_smoothed: Vector3 = Vector3.ZERO
var movement_ramp: float = 0.0

func _ready() -> void:
	super()
	material_type = PhysicsConstants.MATERIAL_PLAYER
	
	var settings = PhysicsConstants.RIGID_BODY_SETTINGS.player
	linear_damp = settings.linear_damp
	angular_damp = settings.angular_damp
	collision_layer = PhysicsConstants.LAYER_PLAYER
	collision_mask = PhysicsConstants.LAYER_DEFAULT | PhysicsConstants.LAYER_PHYSICAL
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = false
	
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = settings.friction
	physics_material_override.bounce = settings.bounce
	physics_material_override.rough = true
	
	add_to_group("player")
	add_to_group("physics_object")
	
	drag_coefficient = PhysicsConstants.PLAYER_DRAG
	max_speed = calculate_max_speed(current_speed_boost)
	dynamic_friction = 0.005
	base_emission = BASE_EMISSION
	base_emission_energy = BASE_EMISSION_ENERGY
	state_color = BASE_COLOR
	current_color = BASE_COLOR
	physics_basis = mesh_instance.basis
	visual_basis = mesh_instance.basis
	
	if current_material is StandardMaterial3D:
		base_emission = current_material.emission
	
	stuck_detector = preload("res://scripts/stuck_detector.gd").new()
	
	apply_color(BASE_COLOR, BASE_EMISSION, BASE_EMISSION_ENERGY)
	
	if current_material:
		digestion_flash_material = current_material.duplicate()
		digestion_flash_material.emission_enabled = true

	current_scale = 1.0
	target_scale = 1.0

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("toggle_unkillable"):
		unkillable = !unkillable
		print("Unkillable toggled: ", unkillable)

	collected_food = false
	
	var target_base_color = BASE_COLOR
	var target_emission = BASE_EMISSION
	var target_emission_energy = BASE_EMISSION_ENERGY
	var stuck_time = 0.0

	if unkillable:
		target_base_color = UNKILLABLE_COLOR
		target_emission = UNKILLABLE_EMISSION
		target_emission_energy = UNKILLABLE_EMISSION_ENERGY

	var score_change = 0.0

	if is_digesting:
		digestion_timer += delta
		var digest_progress = digestion_timer / DIGESTION_DURATION
		var flash_intensity = sin(digest_progress * PI) * DIGESTION_FLASH_INTENSITY
		
		digestion_flash_material.emission = BASE_EMISSION + Color(0.3, 0.3, 0.3) * flash_intensity
		digestion_flash_material.emission_energy_multiplier = 1.0 + flash_intensity * 2.0
		
		var scale_pulse = 1.0 + sin(digest_progress * PI) * (DIGESTION_PULSE_SCALE - 1.0)
		apply_physics_scale(scale_pulse)
		
		if digestion_timer >= DIGESTION_DURATION:
			finish_digestion()

	if has_started_moving:
		var is_stuck = stuck_detector.update(global_position, delta)
		if is_stuck:
			stuck_time = stuck_detector.get_stuck_duration()
			if stuck_time >= STUCK_TIMEOUT:
				die()
				lose()
	
	if has_lost:
		target_base_color = DEATH_COLOR
		target_emission = DEAD_EMISSION
		target_emission_energy = DEAD_EMISSION_ENERGY
	elif has_started_moving and stuck_detector.is_stuck:
		if stuck_time >= STUCK_TIMEOUT:
			target_base_color = FLASH_COLOR
			target_emission = DANGER_EMISSION
			target_emission_energy = DANGER_EMISSION_ENERGY
		elif stuck_time >= IDLE_EMISSION_START:
			target_base_color = DANGER_COLOR
			target_emission = DANGER_EMISSION
			var progress = clampf((stuck_time - IDLE_EMISSION_START) / (STUCK_TIMEOUT - IDLE_EMISSION_START), 0.0, 1.0)
			target_emission_energy = lerpf(WARNING_EMISSION_ENERGY, DANGER_EMISSION_ENERGY, progress)
		elif stuck_time >= IDLE_DANGER_START:
			var warning_ratio = clampf((stuck_time - IDLE_DANGER_START) / (IDLE_EMISSION_START - IDLE_DANGER_START), 0.0, 1.0)
			target_base_color = IDLE_COLOR.lerp(DANGER_COLOR, warning_ratio)
			target_emission = BASE_EMISSION.lerp(DANGER_EMISSION, warning_ratio)
			target_emission_energy = lerpf(WARNING_EMISSION_ENERGY, DANGER_EMISSION_ENERGY, warning_ratio)
		elif stuck_time >= IDLE_WARNING_START:
			var gray_ratio = clampf((stuck_time - IDLE_WARNING_START) / (IDLE_DANGER_START - IDLE_WARNING_START), 0.0, 1.0)
			target_base_color = BASE_COLOR.lerp(IDLE_COLOR, gray_ratio)
			target_emission = BASE_EMISSION
			target_emission_energy = lerpf(BASE_EMISSION_ENERGY, WARNING_EMISSION_ENERGY, gray_ratio)
	
	if is_dead:
		target_base_color = DEATH_COLOR
		target_emission = DEAD_EMISSION
	
	state_color = target_base_color
	state_emission = target_emission
	state_emission_energy = target_emission_energy
	
	current_color = current_color.lerp(state_color, delta * COLOR_CHANGE_SPEED)
	apply_color(current_color, state_emission, state_emission_energy)
	
	input_dir = Vector3.ZERO
	var raw_input = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	
	var camera = get_viewport().get_camera_3d()
	if camera and raw_input != Vector2.ZERO:
		var cam_forward = -camera.global_transform.basis.z
		var cam_right = camera.global_transform.basis.x
		
		cam_forward.y = 0
		cam_right.y = 0
		
		if cam_forward.length_squared() > 0.001:
			cam_forward = cam_forward.normalized()
		else:
			cam_forward = Vector3.FORWARD
		
		if cam_right.length_squared() > 0.001:
			cam_right = cam_right.normalized()
		else:
			cam_right = Vector3.RIGHT
		
		input_dir = (cam_right * raw_input.x + cam_forward * -raw_input.y)
		
		if input_dir.length_squared() > 1.0:
			input_dir = input_dir.normalized()
	
	if is_dead:
		dead_time += delta
	
	if not has_lost and input_dir != Vector3.ZERO:
		has_started_moving = true
		
		input_smoothed = input_smoothed.lerp(input_dir, INPUT_SMOOTHING)
		
		movement_ramp = min(movement_ramp + delta / MOVEMENT_RAMP_TIME, 1.0)
	else:
		movement_ramp = 0.0
		input_smoothed = Vector3.ZERO
	
	if cached_velocity.length_squared() > 0.1:
		facing_direction = cached_velocity.normalized()
	
	var nearby_segments = CollisionHandler.get_nearby_bodies(global_position, SEGMENT_PROXIMITY_RADIUS)
	for segment in nearby_segments:
		if segment == self or not segment is Segment:
			continue
		
		var to_segment = segment.global_position - global_position
		var distance = to_segment.length()
		if distance > 0 and distance < SEGMENT_PROXIMITY_RADIUS:
			handle_proximity(segment, distance, to_segment / distance)

	var current_speed = min(max(cached_velocity.length(), current_speed_boost) / current_speed_boost, MAX_BONUS_SPEED_MULTIPLIER)

	var closest_food: Food
	var closest_food_distance_squared := 0.75 * 0.75
	for food_candidate in get_tree().get_nodes_in_group("food"):
		var food_node := food_candidate as Food
		if not food_node or not food_node.is_available():
			continue
		var distance_squared = global_position.distance_squared_to(food_node.global_position)
		if distance_squared < closest_food_distance_squared:
			closest_food = food_node
			closest_food_distance_squared = distance_squared

	if closest_food and not collected_food:
		if is_dead:
			score_change += closest_food.dead_eat()
			collected_food = true
		elif not is_digesting:
			score_change += closest_food.eat(self)
			start_digestion()
			food_eaten += 1
			collected_food = true

			current_speed_boost = min(
				SPEED_BOOST_BASE + (food_eaten * BONUS_SPEED_PER_FEED),
				MAX_SPEED_BOOST
			)
			max_speed = calculate_max_speed(current_speed_boost)

			apply_impulse(facing_direction * LUNGE_FORCE)
			food_collected.emit(food_eaten)

	if not has_lost and score_change > 0.0:
		score_change = int(current_speed * score_change * SPEED_SCORE_MULTIPLIER)
		score_change = max(int(score_change), 1)
		score_earned.emit(score_change, global_position + Vector3(0, 1.5, 0))

	super._physics_process(delta)
	physics_basis = mesh_instance.basis.orthonormalized()

func _process(_delta: float) -> void:
	var fraction = Engine.get_physics_interpolation_fraction()
	visual_pos = physics_pos.lerp(global_position, fraction)
	
	var current_basis = mesh_instance.basis.orthonormalized()
	visual_basis = physics_basis.slerp(current_basis, fraction).orthonormalized()
	
	mesh_instance.global_position = visual_pos
	mesh_instance.basis = visual_basis

func add_segment(growth_state: float = 0.0, saved_pos: Vector3 = Vector3.ZERO, use_saved_position: bool = false) -> Segment:
	if is_dead:
		return null
	
	var segment: Segment = SEGMENT_SCENE.instantiate()
	get_parent().add_child(segment)
	
	var spawn_pos: Vector3
	if use_saved_position or saved_pos != Vector3.ZERO:
		spawn_pos = saved_pos
	else:
		var random_offset = Vector3(
			randf_range(-0.1, 0.1),
			0,
			randf_range(-0.1, 0.1)
		)
		var spawn_offset = -facing_direction * (SEGMENT_SPAWN_OFFSET + SegmentConstants.INITIAL_SCALE)
		spawn_pos = global_position + spawn_offset + random_offset
		segment.init_with_scale_and_velocity(SegmentConstants.INITIAL_SCALE, cached_velocity * SEGMENT_SPAWN_VELOCITY)
	
	segment.init_with_growth(growth_state)
	
	segment.global_position = spawn_pos
	segment.physics_pos = spawn_pos
	segment.visual_pos = spawn_pos
	
	if segments.is_empty():
		segment.target = self
	else:
		segments[0].apply_impulse(-facing_direction * SEGMENT_PUSHBACK)
		segment.target = self
		segments[0].target = segment
	
	segments.push_front(segment)
	_update_chain_metadata()
	return segment

func _update_chain_metadata() -> void:
	for index in segments.size():
		segments[index].chain_index = index
		segments[index].chain_length = segments.size()

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
	base_data["segments"] = get_segment_positions()
	return base_data

func restore_from_save(data: Dictionary) -> void:
	var state: Dictionary = data.get("player_state", {})
	if state.is_empty():
		return

	restore_from_save_data(state)
	var saved_facing_direction: Variant = state.get("facing_direction")
	if saved_facing_direction is Dictionary:
		var restored_direction = _vector_from_save(saved_facing_direction, Vector3.FORWARD)
		if restored_direction.length_squared() > 0.001:
			facing_direction = restored_direction.normalized()
	food_eaten = max(int(state.get("food_eaten", 0)), 0)
	current_speed_boost = clampf(float(state.get("current_speed_boost", SPEED_BOOST_BASE)), SPEED_BOOST_BASE, MAX_SPEED_BOOST)
	max_speed = calculate_max_speed(current_speed_boost)

func _vector_from_save(data: Variant, fallback: Vector3) -> Vector3:
	if not data is Dictionary:
		return fallback
	return Vector3(
		float(data.get("x", fallback.x)),
		float(data.get("y", fallback.y)),
		float(data.get("z", fallback.z))
	)

func lose():
	if has_lost:
		return

	has_lost = true
	player_lost.emit()

func die():
	if unkillable:
		return
	
	if is_dead:
		return
	
	is_dead = true

	for segment in segments:
		segment.target = null

func start_digestion():
	if is_digesting:
		return
	is_digesting = true
	digestion_timer = 0.0
	mesh_instance.material_override = digestion_flash_material

func finish_digestion():
	if not is_digesting:
		return

	is_digesting = false
	digestion_timer = 0.0
	mesh_instance.material_override = null
	apply_physics_scale(1.0)
	
	add_segment()

func handle_proximity(other: PhysicsObject, distance: float, direction: Vector3) -> void:
	if distance <= 0:
		return

	var relative_velocity = other.cached_velocity - cached_velocity
	var separation_force = calculate_proximity_force(
		direction,
		distance,
		SEGMENT_PROXIMITY_RADIUS,
		PROXIMITY_FORCE,
		PROXIMITY_FALLOFF,
		relative_velocity,
		PROXIMITY_VELOCITY_DAMPING
	)

	apply_force(separation_force)
	if other is PhysicsObject:
		other.apply_force(-separation_force)

static func calculate_steered_velocity(
		current_velocity: Vector3,
		desired_direction: Vector3,
		responsiveness: float,
		delta: float
	) -> Vector3:
	var desired_horizontal = Vector3(desired_direction.x, 0.0, desired_direction.z)
	if desired_horizontal.length_squared() <= 0.0001:
		return current_velocity

	desired_horizontal = desired_horizontal.normalized()
	var horizontal_velocity = Vector3(current_velocity.x, 0.0, current_velocity.z)
	var sideways_velocity = horizontal_velocity - horizontal_velocity.project(desired_horizontal)
	var steering_blend = 1.0 - exp(-maxf(responsiveness, 0.0) * maxf(delta, 0.0))
	var steered_horizontal = horizontal_velocity - sideways_velocity * steering_blend
	return Vector3(steered_horizontal.x, current_velocity.y, steered_horizontal.z)

static func calculate_max_speed(speed_boost: float) -> float:
	return minf(BASE_MAX_SPEED * maxf(speed_boost, SPEED_BOOST_BASE), PhysicsConstants.PLAYER_MAX_SPEED)

func _integrate_forces(state: PhysicsDirectBodyState3D):
	if not is_dead and not unkillable and _has_dangerous_contact(state):
		die()
		lose()

	if is_dead:
		state.linear_velocity *= 0.98
		super._integrate_forces(state)
		return
	
	if not has_lost and input_smoothed != Vector3.ZERO:
		has_started_moving = true
		# Steering is applied here, alongside the physics state, exactly once
		# per tick. Input smoothing and movement_ramp are prepared in _physics_process.
		
		var current_vel = state.linear_velocity
		var movement = input_smoothed * DIRECT_ACCELERATION * movement_ramp
		
		movement *= lerp(1.0, current_speed_boost / SPEED_BOOST_BASE, movement_ramp)
		
		if is_dead:
			movement *= 1.0 / max(pow(dead_time * 0.5, 1.5), 1.0)
		
		state.linear_velocity = calculate_steered_velocity(
			current_vel,
			input_smoothed,
			TURN_RESPONSIVENESS,
			state.step
		)
		
		state.apply_central_force(movement * get_effective_mass())
	else:
		state.linear_velocity *= MOVEMENT_DECAY
		movement_ramp = 0.0
		input_smoothed = Vector3.ZERO
	
	if state.linear_velocity.length_squared() > 0.1:
		facing_direction = state.linear_velocity.normalized()
	
	super._integrate_forces(state)

func _has_dangerous_contact(state: PhysicsDirectBodyState3D) -> bool:
	for index in range(state.get_contact_count()):
		var collider = state.get_contact_collider_object(index)
		if collider is Node and collider.is_in_group("dangerous"):
			return true
	return false
