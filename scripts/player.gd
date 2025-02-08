extends CharacterBody3D

const MAX_SPEED = 100000.0
const ACCELERATION = 40.0
const DRAG_COEFFICIENT = 0.05
const MIN_SPEED_THRESHOLD = 0.1
const ROTATION_SPEED = 15.0
const SEGMENT_SCENE = preload("res://scenes/segment.tscn")
const LUNGE_FORCE = 0.2
const SEGMENT_PUSHBACK = 0.1
const VELOCITY_SMOOTHING = 0.15
const IDLE_SPEED_BASE = 3.0  # Rename IDLE_SPEED to IDLE_SPEED_BASE
const IDLE_TIMEOUT = 3.0  # Time in seconds before game over when idle
const NORMAL_COLOR = Color(0.2, 0.4, 1.0)    # Blue
const WARNING_COLOR = Color(0.5, 0.5, 0.5)    # Gray
const DANGER_COLOR = Color(1.0, 0.9, 0.2)     # Yellow
const DYING_COLOR = Color(1.0, 0.2, 0.2)      # Red
const WARNING_SPEED_THRESHOLD = 1.1            # When to start showing warning color (multiplier of idle speed)
const COLOR_CHANGE_SPEED = 5.0  # Speed of color transition
const SPEED_SCORE_MULTIPLIER = 5.0  # Points per multiple of speed
const MAX_SPEED_IDLE_MULTIPLIER = 3.0 # Max score multiplier for speed
const IDLE_SPEED_INCREASE = 5.0  # Speed increase per food eaten
const MAX_IDLE_SPEED = 5.0  # Cap on how fast the minimum speed can get
const FLASH_COLOR = Color(1.0, 0.0, 0.0)      # Bright Red for final flash
const DEATH_COLORS = [                         # Colors to cycle through when dead
	Color(1.0, 0.0, 0.0),  # Red
	Color(0.0, 0.0, 0.0),  # Black
	Color(0.3, 0.3, 0.3),  # Gray
]
const FLASH_TIME = 0.2                        # How long before death to flash
const DEATH_COLOR_SPEED = 3.0                 # Speed of color cycling when dead
const SCORE_POPUP = preload("res://scenes/score_popup.tscn")
const STUN_CONTROL_REDUCTION = 0.5  # Amount by which to reduce control while stunned

var facing_direction: Vector3 = Vector3.FORWARD
var segments: Array[CharacterBody3D] = []
var target_velocity: Vector3 = Vector3.ZERO
var smoothed_velocity: Vector3 = Vector3.ZERO
var current_scale: float = 1.0  # Add this for consistent scaling behavior
var idle_timer: float = 0.0
var has_started_moving: bool = false
var current_color: Color = NORMAL_COLOR
var food_eaten: int = 0
var current_idle_speed: float = IDLE_SPEED_BASE
var is_dead: bool = false
var death_color_time: float = 0.0
var stun_timer: float = 0.0

var physics_pos: Vector3
var physics_basis: Basis
var visual_pos: Vector3
var visual_basis: Basis

@onready var head_mesh = $MeshInstance3D
@onready var head_material = head_mesh.mesh.surface_get_material(0)

func _ready():
	physics_pos = global_position
	visual_pos = global_position
	physics_basis = head_mesh.basis
	visual_basis = head_mesh.basis
	# Clone the material so we don't affect other instances
	head_material = head_material.duplicate()
	head_mesh.mesh.surface_set_material(0, head_material)

func _physics_process(delta):
	if is_dead:
		# Cycle through death colors
		death_color_time += delta * DEATH_COLOR_SPEED
		var color_index = int(death_color_time) % DEATH_COLORS.size()
		var next_index = (color_index + 1) % DEATH_COLORS.size()
		var color_fraction = fmod(death_color_time, 1.0)
		current_color = DEATH_COLORS[color_index].lerp(DEATH_COLORS[next_index], color_fraction)
		head_material.albedo_color = current_color
		return

	if stun_timer > 0:
		stun_timer -= delta

	var input_multiplier = 1.0 if stun_timer <= 0 else STUN_CONTROL_REDUCTION

	var input_dir = Vector3.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.z = Input.get_axis("move_up", "move_down")
	
	if input_dir != Vector3.ZERO:
		has_started_moving = true
		idle_timer = 0.0  # Reset timer when there's input
		input_dir = input_dir.normalized()
		 # Calculate target velocity
		target_velocity += input_dir * ACCELERATION * delta * input_multiplier
		target_velocity = target_velocity.limit_length(MAX_SPEED)
	
	# Handle idle timeout
	if has_started_moving and velocity.length() < current_idle_speed:
		idle_timer += delta
		if idle_timer >= IDLE_TIMEOUT:
			var game_manager = get_tree().get_first_node_in_group("game_manager")
			if game_manager:
				game_manager.game_over()
				return
	
	# Apply drag to target velocity
	var speed = target_velocity.length()
	if speed > 0:
		var drag_force = -target_velocity.normalized() * speed * speed * DRAG_COEFFICIENT * delta
		target_velocity += drag_force
		
		if target_velocity.length() < MIN_SPEED_THRESHOLD:
			target_velocity = Vector3.ZERO
	
	# Smooth velocity transition
	smoothed_velocity = smoothed_velocity.lerp(target_velocity, VELOCITY_SMOOTHING)
	velocity = smoothed_velocity
	
	if velocity != Vector3.ZERO:
		facing_direction = velocity.normalized()
	
	var collision = move_and_collide(velocity * delta)
	var collision_handler = get_node("/root/CollisionHandler")
	if collision:
		var collider = collision.get_collider()
		if collider.is_in_group("barrier"):
			var game_manager = get_tree().get_first_node_in_group("game_manager")
			if game_manager:
				game_manager.game_over()
				return
				
		# Let the collision handler manage the collision
		collision_handler.handle_collision(self, collider, collision.get_normal(), delta)
	
	# Handle proximity with segments
	var nearby_segments = get_tree().get_nodes_in_group("segment")
	collision_handler.handle_proximity(self, nearby_segments, delta)
	
	# Update head rotation
	if velocity != Vector3.ZERO:
		var speed_factor = clamp(velocity.length() / MAX_SPEED, 0.0, 1.0)
		var forward = velocity.normalized()
		var right = forward.cross(Vector3.UP).normalized()  # Normalize the right vector
		var up = right.cross(forward).normalized()  # Normalize the up vector
		
		# Create and normalize the basis
		var target_basis = Basis(right, up, -forward).orthonormalized()
		var tilt = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-15 * speed_factor), 0, 0)))
		target_basis = (target_basis * tilt.basis).orthonormalized()
		
		# Apply the rotation with normalized basis
		head_mesh.basis = head_mesh.basis.slerp(target_basis, delta * ROTATION_SPEED).orthonormalized()
	
	# Update color based on speed and idle timer
	var speed_ratio = velocity.length() / current_idle_speed
	var target_color
	
	if velocity.length() < current_idle_speed:
		 # Flash red right before death
		if IDLE_TIMEOUT - idle_timer <= FLASH_TIME:
			target_color = FLASH_COLOR
		else:
			# Interpolate between yellow and red based on remaining time
			var time_ratio = idle_timer / (IDLE_TIMEOUT - FLASH_TIME)  # Adjust ratio to account for flash time
			target_color = DANGER_COLOR.lerp(DYING_COLOR, time_ratio)
	elif speed_ratio < WARNING_SPEED_THRESHOLD:
		# Interpolate between yellow and blue based on how close to warning threshold
		var warning_ratio = (speed_ratio - 1.0) / (WARNING_SPEED_THRESHOLD - 1.0)
		target_color = WARNING_COLOR.lerp(NORMAL_COLOR, warning_ratio)
	else:
		target_color = NORMAL_COLOR
	
	current_color = current_color.lerp(target_color, delta * COLOR_CHANGE_SPEED)
	head_material.albedo_color = current_color
	
	# Store physics state
	physics_pos = global_position
	physics_basis = head_mesh.basis
	
	# Food collection
	for area in get_tree().get_nodes_in_group("food"):
		if area.global_position.distance_to(global_position) < 0.75:
			area.queue_free()
			add_segment()
			food_eaten += 1
			# Update minimum speed requirement
			current_idle_speed = min(
				IDLE_SPEED_BASE + (food_eaten * IDLE_SPEED_INCREASE),
				MAX_IDLE_SPEED
			)
			 # Calculate score based on speed
			var current_speed = min(max(velocity.length(), current_idle_speed) / current_idle_speed, MAX_SPEED_IDLE_MULTIPLIER)
			var speed_points = int(current_speed * SPEED_SCORE_MULTIPLIER)
			# Find game manager and notify it
			var game_manager = get_tree().get_first_node_in_group("game_manager")
			if game_manager:
				game_manager.on_food_collected(speed_points)
			# Add extra momentum when collecting food
			velocity += facing_direction * LUNGE_FORCE
			
			# Spawn score popup
			var popup = SCORE_POPUP.instantiate()
			popup.position = global_position + Vector3(0, 1.5, 0)  # Raise the spawn point
			popup.text = "+" + str(speed_points)
			get_parent().add_child(popup)

func _process(delta):
	# Interpolate visual position between physics updates
	var fraction = Engine.get_physics_interpolation_fraction()
	visual_pos = physics_pos.lerp(global_position, fraction)
	visual_basis = physics_basis.slerp(head_mesh.basis, fraction)
	
	# Update visual representation
	head_mesh.global_position = visual_pos
	head_mesh.basis = visual_basis

func add_segment(growth_state: float = 0.0, saved_pos: Vector3 = Vector3.ZERO) -> CharacterBody3D:
	var segment = SEGMENT_SCENE.instantiate()
	segment.set_script(load("res://scripts/segment.gd"))
	
	# First add to scene tree so transforms work properly
	get_parent().add_child(segment)  # This was correct, but ensure food has group
	
	# Now set position after it's in the tree
	var spawn_pos: Vector3
	if saved_pos != Vector3.ZERO:
		spawn_pos = saved_pos
	else:
		if segments.is_empty():
			spawn_pos = global_position - facing_direction * (1.0 + segment.INITIAL_SCALE)
		else:
			spawn_pos = global_position - facing_direction * segment.INITIAL_SCALE * 2.0
	
	segment.global_position = spawn_pos
	segment.physics_pos = spawn_pos
	segment.visual_pos = spawn_pos
	
	segment.init_with_growth(growth_state)
	
	# Update targeting
	if segments.is_empty():
		segment.target = self
	else:
		segment.target = self
		segments[0].target = segment
	
	segments.push_front(segment)
	return segment  # Return the segment for further initialization

func get_segment_positions() -> Array:
	var positions = []
	for segment in segments:
		positions.append(segment.get_save_data())
	return positions

func get_save_data() -> Dictionary:
	return {
		"position": {
			"x": global_position.x,
			"y": global_position.y,
			"z": global_position.z
		},
			"physics_pos": {
			"x": physics_pos.x,
			"y": physics_pos.y,
			"z": physics_pos.z
		},
		"visual_pos": {
			"x": visual_pos.x,
			"y": visual_pos.y,
			"z": visual_pos.z
		},
		"velocity": {
			"x": velocity.x,
			"y": velocity.y,
			"z": velocity.z
		},
		"target_velocity": {
			"x": target_velocity.x,
			"y": target_velocity.y,
			"z": target_velocity.z
		},
		"smoothed_velocity": {
			"x": smoothed_velocity.x,
			"y": smoothed_velocity.y,
			"z": smoothed_velocity.z
		},
		"facing_direction": {
			"x": facing_direction.x,
			"y": facing_direction.y,
			"z": facing_direction.z
		},
		"food_eaten": food_eaten,
		"current_idle_speed": current_idle_speed,
		"segments": get_segment_positions()
	}

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
		current_idle_speed = state.get("current_idle_speed", IDLE_SPEED_BASE)

func die():
	is_dead = true
	death_color_time = 0.0
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager:
		game_manager.game_over()
