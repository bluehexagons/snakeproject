extends CharacterBody3D

const SPRING_STIFFNESS = 2500.0
const SPRING_DAMPING = 4.01
const TARGET_DISTANCE = 0.666
const VELOCITY_SMOOTHING = 0.35
const GROWTH_DURATION = 0.33
const INITIAL_SCALE = 0.2  # Increased from 0.01 to avoid disappearing
const SEGMENT_MASS = 3.0  # Reduced from 5.0 to be less dominant
const SEGMENT_BOUNCE = 0.2  # Reduced from 0.3 for less bouncy collisions
const MINIMUM_SEPARATION = 0.8  # Minimum distance to maintain from other segments
const SEPARATION_FORCE = 15.0  # Force to apply when too close
const MAX_SEGMENT_SPEED = 20.0  # Prevent segments from moving too fast

var target: Node3D
var smoothed_velocity: Vector3
var growth_timer: float = 0.0
var is_growing: bool = true
var current_scale: float = INITIAL_SCALE

var physics_pos: Vector3
var visual_pos: Vector3

@onready var mesh = $MeshInstance3D
@onready var collision = $CollisionShape3D

func _ready():
	# Set initial scale and positions
	current_scale = INITIAL_SCALE
	update_scale(current_scale)
	# Initialize both positions to spawn position to prevent interpolation from origin
	physics_pos = global_position
	visual_pos = global_position
	# Ensure mesh starts at the correct position
	mesh.global_position = global_position

func update_scale(new_scale: float):
	mesh.scale = Vector3.ONE * new_scale
	collision.scale = Vector3.ONE * new_scale

func init_with_growth(initial_growth: float):
	growth_timer = GROWTH_DURATION * initial_growth
	current_scale = lerp(INITIAL_SCALE, 1.0, ease(initial_growth, 0.7))
	is_growing = initial_growth < 1.0
	update_scale(current_scale)

func get_save_data() -> Dictionary:
	return {
		"position": {
			"x": global_position.x,
			"y": global_position.y,
			"z": global_position.z
		},
		"velocity": {
			"x": velocity.x,
			"y": velocity.y,
			"z": velocity.z
		},
		"smoothed_velocity": {
			"x": smoothed_velocity.x,
			"y": smoothed_velocity.y,
			"z": smoothed_velocity.z
		},
		"growth": min(growth_timer / GROWTH_DURATION, 1.0),
		"current_scale": current_scale
	}

func init_from_save_data(data: Dictionary):
	if data.has("velocity"):
		velocity = Vector3(data.velocity.x, data.velocity.y, data.velocity.z)
	if data.has("smoothed_velocity"):
		smoothed_velocity = Vector3(data.smoothed_velocity.x, data.smoothed_velocity.y, data.smoothed_velocity.z)
	
	# Initialize transforms after velocity
	physics_pos = global_position
	visual_pos = global_position
	
	# Initialize growth last
	init_with_growth(data.growth)

func _physics_process(delta):
	if is_growing:
		growth_timer += delta
		var t = growth_timer / GROWTH_DURATION
		if t <= 1.0:
			var growth = ease(t, 0.7)
			current_scale = lerp(INITIAL_SCALE, 1.0, growth)
			update_scale(current_scale)
		else:
			is_growing = false
			current_scale = 1.0
			update_scale(current_scale)
	
	if not target:
		return
		
	# Calculate target distance based on current scales
	var adjusted_distance = TARGET_DISTANCE * (current_scale + (target.get("current_scale") if target.has_method("get_scale") else 1.0)) * 0.5
	
	var direction = target.global_position - global_position
	var target_pos = target.global_position - direction.normalized() * adjusted_distance
	
	# Spring force calculation
	var displacement = target_pos - global_position
	var spring_force = displacement * SPRING_STIFFNESS * delta
	
	# Damping force to prevent oscillation
	var damping_force = -velocity * SPRING_DAMPING * delta
	
	# Calculate target velocity
	var target_velocity = spring_force + damping_force
	
	# Smooth velocity transition
	smoothed_velocity = smoothed_velocity.lerp(target_velocity, VELOCITY_SMOOTHING)
	velocity = smoothed_velocity
	
	# Limit segment speed
	velocity = velocity.limit_length(MAX_SEGMENT_SPEED)
	
	var movement_collision = move_and_collide(velocity * delta)
	if movement_collision:
		var collider = movement_collision.get_collider()
		var normal = movement_collision.get_normal()
		
		# Apply bounce effect with reduced bounciness
		velocity = velocity.bounce(normal) * SEGMENT_BOUNCE
		
		# Add separation force
		velocity += normal * SEPARATION_FORCE * delta
		
		# Handle player collision
		if collider and collider.is_in_group("player") and collider.has_method("handle_collision"):
			collider.handle_collision(normal, velocity.length(), SEGMENT_MASS, delta)
		# Handle segment-segment collision
		elif collider and collider.is_in_group("segment"):
			# Add extra separation force between segments
			velocity += normal * SEPARATION_FORCE * 1.5 * delta
	
	# Check for nearby segments and apply separation
	for segment in get_tree().get_nodes_in_group("segment"):
		if segment != self:
			var segment_direction = global_position - segment.global_position
			var distance = segment_direction.length()
			if distance < MINIMUM_SEPARATION:
				var separation = segment_direction.normalized() * (MINIMUM_SEPARATION - distance) * SEPARATION_FORCE * delta
				velocity += separation
	
	# Store physics state
	physics_pos = global_position

func _process(delta):
	# Interpolate visual position between physics updates
	var fraction = Engine.get_physics_interpolation_fraction()
	visual_pos = physics_pos.lerp(global_position, fraction)
	
	# Update visual representation
	mesh.global_position = visual_pos
	
	# Keep collision shape at physics position
	collision.global_position = global_position
