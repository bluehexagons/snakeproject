extends PhysicsObject
class_name Player

const SEGMENT_SCENE = preload("res://scenes/segment.tscn")
const SCORE_POPUP = preload("res://scenes/score_popup.tscn")

const EXPECTED_MAX_SPEED = 400.0
const ACCELERATION = 100.0  # Increased since we're using forces now
const CONTROL_DRAG = 0.9
const DEAD_CONTROL_DRAG = 1.0
const ROTATION_SPEED = 15.0
const LUNGE_FORCE = 10.0
const SEGMENT_PUSHBACK = 3.0
const VELOCITY_SMOOTHING = 0.15
const SPEED_BOOST_BASE = 1.0  # Rename IDLE_SPEED to SPEED_BOOST_BASE
const IDLE_TIMEOUT = 3.0  # Time in seconds before game over when idle
const COLOR_CHANGE_SPEED = 5.0  # Speed of color transition
const SPEED_SCORE_MULTIPLIER = 1.5  # Points per multiple of speed
const MAX_BONUS_SPEED_MULTIPLIER = 3.0 # Max score multiplier for speed
const BONUS_SPEED_PER_FEED = 0.2  # Speed increase per food eaten
const MAX_SPEED_BOOST = 15.0  # Cap on how fast the minimum speed can get
const SEGMENT_SPAWN_OFFSET = 0.5  # Reduced from 1.2 to spawn closer
const SEGMENT_SPAWN_VELOCITY = 0.95  # Increased from 0.8 for better matching
const STUCK_TIMEOUT = 3.0  # Time in seconds before game over when stuck

const IDLE_WARNING_START = 1.0  # When to start showing gray
const IDLE_DANGER_START = 2.0   # When to start showing red
const IDLE_EMISSION_START = 2.9  # When to start glowing

const BASE_COLOR = Color(0.2, 0.4, 1.0)      # Blue
const IDLE_COLOR = Color(0.5, 0.5, 0.5)      # Gray
const DANGER_COLOR = Color(0.8, 0.2, 0.2)    # Dark Red
const FLASH_COLOR = Color(1.0, 0.2, 0.2)     # Bright Red
const DEATH_COLOR = Color(0.3, 0.1, 0.1)     # Medium Red

const BASE_EMISSION = Color(0.2, 0.4, 1.0)    # Subtle blue glow
const DANGER_EMISSION = Color(1.0, 0.2, 0.2)  # Red warning glow
const DEAD_EMISSION = Color(0.2, 0, 0)  # Red warning glow

const BASE_EMISSION_ENERGY = 0.6
const WARNING_EMISSION_ENERGY = 1.0
const DANGER_EMISSION_ENERGY = 2.0
const DEAD_EMISSION_ENERGY = 0.1

const DIGESTION_DURATION = 0.16  # Time to digest food
const DIGESTION_FLASH_INTENSITY = 0.3  # Max intensity of digestion flash
const SEGMENT_SPAWN_PUSH = 20.0  # Force to push back existing segments
const DIGESTION_PULSE_SCALE = 1.2  # How much to pulse when digesting

var facing_direction: Vector3 = Vector3.FORWARD
var segments: Array[Segment] = []
var target_velocity: Vector3 = Vector3.ZERO
var smoothed_velocity: Vector3 = Vector3.ZERO
var has_started_moving: bool = false
var food_eaten: int = 0
var filler_eaten: int = 0
var current_speed_boost: float = SPEED_BOOST_BASE
var is_dead: bool = false
var has_lost: bool = false
var stuck_detector: RefCounted
var dead_time: float = 0.0
var is_digesting: bool = false
var digestion_timer: float = 0.0
var digestion_flash_material: StandardMaterial3D
var unkillable: bool = true

var physics_basis: Basis
var visual_basis: Basis

func _ready():
	super()
	material_type = PhysicsConstants.MATERIAL_PLAYER
	base_mass = PhysicsConstants.PLAYER_MASS
	mass = base_mass
	pull_reduction = 0.85
	target_distance = 1.1
	collision_force_multiplier = 0.8  # Player takes less collision damage
	spring_stiffness_multiplier = 1.2  # Player has stronger spring forces
	
	drag_coefficient = PhysicsConstants.PLAYER_DRAG
	max_speed = PhysicsConstants.PLAYER_MAX_SPEED
	mass = 0.5
	drag_coefficient = PhysicsConstants.PLAYER_DRAG
	static_friction = 0.01
	dynamic_friction = 0.005
	rolling_friction = 0.002
	base_emission = BASE_EMISSION
	base_emission_energy = BASE_EMISSION_ENERGY
	state_color = BASE_COLOR
	current_color = BASE_COLOR
	physics_basis = mesh_instance.basis
	visual_basis = mesh_instance.basis
	drag_coefficient = PhysicsConstants.PLAYER_DRAG
	mass = 0.5
	
	# Store initial emission color
	if current_material is StandardMaterial3D:
		base_emission = current_material.emission
	
	stuck_detector = preload("res://scripts/stuck_detector.gd").new()
	
	# Set initial emission state
	apply_color(BASE_COLOR, BASE_EMISSION, BASE_EMISSION_ENERGY)
	
	# Setup digestion flash material
	digestion_flash_material = current_material.duplicate()
	digestion_flash_material.emission_enabled = true

	base_scale = 1.0
	current_scale = 1.0
	target_scale = 1.0

func _physics_process(delta):
	# Handle color updates before any potential impacts
	var target_base_color = BASE_COLOR
	var target_emission = BASE_EMISSION
	var target_emission_energy = BASE_EMISSION_ENERGY

	var stuck_time = 0.0

	var score_change = 0.0

	# Handle digestion first
	if is_digesting:
		digestion_timer += delta
		var digest_progress = digestion_timer / DIGESTION_DURATION
		var flash_intensity = sin(digest_progress * PI) * DIGESTION_FLASH_INTENSITY
		
		# Update flash material
		digestion_flash_material.emission = BASE_EMISSION + Color(0.3, 0.3, 0.3) * flash_intensity
		digestion_flash_material.emission_energy_multiplier = 1.0 + flash_intensity * 2.0
		
		# Pulse scale
		var scale_pulse = 1.0 + sin(digest_progress * PI) * (DIGESTION_PULSE_SCALE - 1.0)
		apply_physics_scale(scale_pulse)
		
		if digestion_timer >= DIGESTION_DURATION:
			finish_digestion()

	# Update stuck detection
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
			var progress = (stuck_time - IDLE_EMISSION_START) / (STUCK_TIMEOUT - IDLE_EMISSION_START)
			target_emission_energy = lerp(WARNING_EMISSION_ENERGY, DANGER_EMISSION_ENERGY, progress)
		elif stuck_time >= IDLE_DANGER_START:
			var warning_ratio = (stuck_time - IDLE_DANGER_START) / (IDLE_EMISSION_START - IDLE_DANGER_START)
			target_base_color = IDLE_COLOR.lerp(DANGER_COLOR, warning_ratio)
			target_emission = BASE_EMISSION.lerp(DANGER_EMISSION, warning_ratio)
			target_emission_energy = lerp(WARNING_EMISSION_ENERGY, DANGER_EMISSION_ENERGY, warning_ratio)
		elif stuck_time >= IDLE_WARNING_START:
			var gray_ratio = (stuck_time - IDLE_WARNING_START) / (IDLE_DANGER_START - IDLE_WARNING_START)
			target_base_color = BASE_COLOR.lerp(IDLE_COLOR, gray_ratio)
			target_emission = BASE_EMISSION
			target_emission_energy = lerp(BASE_EMISSION_ENERGY, WARNING_EMISSION_ENERGY, gray_ratio)
	
	if is_dead:
		target_base_color = DEATH_COLOR
		target_emission = DEAD_EMISSION
	
	state_color = target_base_color
	state_emission = target_emission
	state_emission_energy = target_emission_energy
	
	current_color = current_color.lerp(state_color, delta * COLOR_CHANGE_SPEED)
	apply_color(current_color, state_emission, state_emission_energy)
	
	var input_dir = Vector3.ZERO
	var raw_input = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	
	# Get camera basis for input transformation
	var camera = get_viewport().get_camera_3d()
	if camera and raw_input != Vector2.ZERO:
		# Get camera's forward and right vectors projected onto XZ plane
		var cam_forward = -camera.global_transform.basis.z
		var cam_right = camera.global_transform.basis.x
		
		# Project vectors to ground plane
		cam_forward.y = 0
		cam_right.y = 0
		
		# Normalize after projection
		if cam_forward.length_squared() > 0.001:
			cam_forward = cam_forward.normalized()
		else:
			cam_forward = Vector3.FORWARD
		
		if cam_right.length_squared() > 0.001:
			cam_right = cam_right.normalized()
		else:
			cam_right = Vector3.RIGHT
		
		# Combine movement relative to camera orientation
		input_dir = (cam_right * raw_input.x + cam_forward * -raw_input.y)
		
		# Ensure normalized movement
		if input_dir.length_squared() > 1.0:
			input_dir = input_dir.normalized()
	
	if is_dead:
		dead_time += delta
	
	if not has_lost and input_dir != Vector3.ZERO:
		has_started_moving = true
		var drag = DEAD_CONTROL_DRAG if is_dead else CONTROL_DRAG
		velocity += (input_dir * (current_speed_boost / max(pow(dead_time * 0.5, 1.5), 1.0) if is_dead else ACCELERATION + (current_speed_boost * 10.0)) * delta)
		velocity *= drag
	if velocity != Vector3.ZERO:
		facing_direction = velocity.normalized()
	
	var collision = move_and_collide(velocity * delta)
	var collision_handler = get_node("/root/CollisionHandler")
	if collision:
		var collider = collision.get_collider()
		if collider.is_in_group("dangerous"):
			die()  # Die immediately on contact with any dangerous object
		
		if is_dead:
			if collider.has_method("dead_eat"):
				score_change += collider.dead_eat()
		elif collider.has_method("eat"):
			score_change += collider.eat()
				
		collision_handler.handle_collision(self, collider, collision.get_normal(), delta)
	
	# Handle proximity with segments
	var nearby_segments = get_tree().get_nodes_in_group("segment")
	collision_handler.handle_proximity(self, nearby_segments, delta)

	var current_speed = min(max(velocity.length(), current_speed_boost) / current_speed_boost, MAX_BONUS_SPEED_MULTIPLIER)

	# Food collection
	# Get list of food items and sort by distance
	var food_nodes = get_tree().get_nodes_in_group("food")
	food_nodes.sort_custom(func(a, b): 
		return a.global_position.distance_to(global_position) < b.global_position.distance_to(global_position)
	)
	
	# Check closest food first
	for food_node in food_nodes:
		if food_node.global_position.distance_to(global_position) < 0.75:
			if is_dead:
				score_change += food_node.dead_eat()
			else:
				if not is_digesting:  # Only collect if not currently digesting
					score_change += food_node.eat()
					start_digestion()
					food_eaten += 1
					
					# Update minimum speed requirement
					current_speed_boost = min(
						SPEED_BOOST_BASE + (food_eaten * BONUS_SPEED_PER_FEED),
						MAX_SPEED_BOOST
					)
					
					# Add extra momentum when collecting food
					apply_impulse(facing_direction * LUNGE_FORCE)

					# Find game manager and notify it
					var game_manager = get_tree().get_first_node_in_group("game_manager")
					if game_manager:
						game_manager.on_food_collected()
			break  # Only eat one food item per frame

	if not has_lost and score_change > 0.0:
		# Calculate score based on speed
		score_change = int(current_speed * score_change * SPEED_SCORE_MULTIPLIER)
		score_change = max(int(score_change), 1)
		var game_manager = get_tree().get_first_node_in_group("game_manager")
		if game_manager:
			game_manager.add_score(score_change)
			# Spawn score popup
			var popup = SCORE_POPUP.instantiate()
			popup.position = global_position + Vector3(0, 1.5, 0)  # Raise the spawn point
			popup.text = "+" + str(score_change)
			get_parent().add_child(popup)

	# Store physics state with normalized basis
	super._physics_process(delta)
	physics_basis = mesh_instance.basis.orthonormalized()

func _process(_delta):
	# Interpolate visual position between physics updates
	var fraction = Engine.get_physics_interpolation_fraction()
	visual_pos = physics_pos.lerp(global_position, fraction)
	
	# Ensure both bases are normalized before interpolating
	var current_basis = mesh_instance.basis.orthonormalized()
	visual_basis = physics_basis.slerp(current_basis, fraction).orthonormalized()
	
	# Update visual representation
	mesh_instance.global_position = visual_pos
	mesh_instance.basis = visual_basis

func add_segment(growth_state: float = 0.0, saved_pos: Vector3 = Vector3.ZERO) -> CharacterBody3D:
	if is_dead:
		return
	
	var segment = SEGMENT_SCENE.instantiate()
	segment.set_script(load("res://scripts/segment.gd"))
	get_parent().add_child(segment)
	
	# Calculate spawn position with closer offset
	var spawn_pos: Vector3
	if saved_pos != Vector3.ZERO:
		spawn_pos = saved_pos
	else:
		# Use a smaller offset and add a slight random variation to prevent perfect overlap
		var random_offset = Vector3(
			randf_range(-0.1, 0.1),
			0,
			randf_range(-0.1, 0.1)
		)
		var spawn_offset = -facing_direction * (SEGMENT_SPAWN_OFFSET + segment.INITIAL_SCALE)
		spawn_pos = global_position + spawn_offset + random_offset
		# Give segment better initial velocity
		segment.velocity = velocity * SEGMENT_SPAWN_VELOCITY
	
	# Initialize segment with proper scale first
	segment.init_with_growth(growth_state)
	
	# Then set position and chain properties
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
	return segment

func get_segment_positions() -> Array:
	var positions = []
	for segment in segments:
		positions.append(segment.get_save_data())
	return positions

func get_save_data() -> Dictionary:
	var base_data = super.get_save_data()
	# Add player-specific data
	base_data["target_velocity"] = {
		"x": target_velocity.x,
		"y": target_velocity.y,
		"z": target_velocity.z
	}
	base_data["smoothed_velocity"] = {
		"x": smoothed_velocity.x,
		"y": smoothed_velocity.y,
		"z": smoothed_velocity.z
	}
	base_data["facing_direction"] = {
		"x": facing_direction.x,
		"y": facing_direction.y,
		"z": facing_direction.z
	}
	base_data["food_eaten"] = food_eaten
	base_data["current_speed_boost"] = current_speed_boost
	base_data["segments"] = get_segment_positions()
	return base_data

func restore_from_save(data: Dictionary):
	var state = data.player_state  # Get complete player state
	if state:
		position = Vector3(
			float(state.position.x),
			float(state.position.y),
			float(state.position.z)
		)
		physics_pos = Vector3(
			float(state.physics_pos.x),
			float(state.physics_pos.y),
			float(state.physics_pos.z)
		)
		visual_pos = Vector3(
			float(state.visual_pos.x),
			float(state.visual_pos.y),
			float(state.visual_pos.z)
		)
		velocity = Vector3(
			float(state.velocity.x),
			float(state.velocity.y),
			float(state.velocity.z)
		)
		target_velocity = Vector3(
			float(state.target_velocity.x),
			float(state.target_velocity.y),
			float(state.target_velocity.z)
		)
		smoothed_velocity = Vector3(
			float(state.smoothed_velocity.x),
			float(state.smoothed_velocity.y),
			float(state.smoothed_velocity.z)
		)
		facing_direction = Vector3(
			float(state.facing_direction.x),
			float(state.facing_direction.y),
			float(state.facing_direction.z)
		)
		food_eaten = state.get("food_eaten", 0)
		current_speed_boost = state.get("current_speed_boost", SPEED_BOOST_BASE)

func lose():
	if has_lost:
		return

	has_lost = true

	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager:
		game_manager.game_over()

func die():
	if is_dead or unkillable:
		return
	
	is_dead = true

	for segment in segments:
		segment.target = null

func start_digestion():
	is_digesting = true
	digestion_timer = 0.0
	mesh_instance.material_override = digestion_flash_material

func finish_digestion():
	is_digesting = false
	digestion_timer = 0.0
	mesh_instance.material_override = null
	apply_physics_scale(1.0)
	
	# Push back first segment if it exists
	if not is_dead and not segments.is_empty():
		segments[0].velocity -= facing_direction * SEGMENT_SPAWN_PUSH
	
	# Spawn new segment
	add_segment()
