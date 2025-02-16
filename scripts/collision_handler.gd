extends Node

const MINIMUM_SEPARATION = 0.2  # Increased from 0.1
const SEPARATION_FORCE = 0.3    # Increased from 0.1
const COLLISION_BOUNCE = 0.5  # Increased from 0.4 for more lively collisions
const PERSISTENT_COLLISION_DAMPING = 0.85  # Slightly reduced damping
const MAX_COLLISION_SPEED = 20.0
const REST_THRESHOLD = 0.1
const VELOCITY_LOSS_ON_COLLISION = 0.7  # How much velocity to maintain after collision
const BARRIER_BOUNCE_MULTIPLIER = 1.0  # Extra bounce for barrier collisions
const BARRIER_PUSH_FORCE = 0.25  # Additional force away from barrier
const MIN_BARRIER_BOUNCE_SPEED = 2.0  # Minimum speed after barrier bounce
const DEFAULT_MASS = 1.0

# New constants for optimization
const MAX_IMPULSE = 1000.0  # Cap maximum collision response
const FORCE_DISSIPATION_FACTOR = 0.6  # Reduced from 0.7 for more force transfer
const PROXIMITY_GRID_SIZE = 2.0  # Size of spatial grid cells
const MAX_BODIES_PER_CELL = 8  # Limit checks in dense areas
const CLUSTER_CHECK_RADIUS = 3.0  # Radius to check for clustered objects

const SEGMENT_COLLISION_BOUNCE = 0.6   # Increased from 0.4 for more responsive collisions
const SEGMENT_SEPARATION_FORCE = 0.4   # Increased from 0.2
const SEGMENT_TANGENT_FORCE = 0.15   # Force to help segments slide past each other
const SEGMENT_REPULSION_RADIUS = 0.6  # Radius for repulsion between segments
const SEGMENT_REPULSION_FORCE = 0.8   # Strength of repulsion
const SEGMENT_MASS_SCALE = 0.4        # Reduced from 1.5 to make segments more responsive to hits
const ROCK_COLLISION_SCALE = 1.2      # Changed from 0.6 to increase rock impact
const ROCK_SEGMENT_IMPULSE_BOOST = 2.0 # Additional scaling for rock->segment impacts

const PROXIMITY_RADIUS = 1.0
const MAX_OBJECTS_PER_CHECK = 8  # Limit number of objects checked per frame
const OPTIMIZATION_DISTANCE = 3.0  # Distance at which to start optimizing checks

@onready var spatial_grid = preload("res://scripts/spatial_grid.gd").new()

# Spatial partitioning for broad phase
# Remove old proximity grid and associated variables

func _ready():
	process_priority = 1  # Ensure this runs before physics objects

func _physics_process(_delta):
	# Clear grid each physics frame
	spatial_grid.clear()
	
	# Register all physics objects
	for obj in get_tree().get_nodes_in_group("physics_object"):
		if obj.is_inside_tree() and not obj.is_queued_for_deletion():
			spatial_grid.insert(obj, get_object_layer(obj))

# Remove unused functions

func get_nearby_bodies(pos: Vector3, radius: float = PROXIMITY_RADIUS) -> Array:
	var nearby = spatial_grid.get_nearby(pos, radius)
	# Filter out invalid objects early
	return nearby.filter(func(obj): return is_instance_valid(obj) and obj.is_inside_tree())

func is_valid_vector(v: Vector3) -> bool:
	return v.is_finite() and v.length_squared() < 1000000.0

func handle_detailed_collision(body_a: CharacterBody3D, body_b: Node, collision_normal: Vector3, delta: float) -> void:
	if not is_valid_vector(collision_normal):
		push_warning("Invalid collision normal detected")
		return

	# Check for clustered collisions using spatial grid directly
	var nearby_count = spatial_grid.get_nearby(body_a.global_position, CLUSTER_CHECK_RADIUS).size()
	var cluster_factor = clamp(float(nearby_count) / MAX_BODIES_PER_CELL, 0.0, 1.0)
	
	# Handle barrier collisions first
	if body_b.is_in_group("barrier"):
		handle_barrier_collision(body_a, collision_normal, delta)
		return
	
	# Early return for static bodies (barriers)
	if body_b is StaticBody3D:
		handle_static_collision(body_a, collision_normal, delta)
		return
	
	# Only proceed with CharacterBody3D collisions
	if not body_b is CharacterBody3D:
		return

	# Skip collision processing if either body is a spawning segment
	if (body_a.is_in_group("segment") and body_a.spawn_timer > 0) or \
	   (body_b is CharacterBody3D and body_b.is_in_group("segment") and body_b.spawn_timer > 0):
		return

	# Special handling for spawning segments
	var spawn_ignores_collision = false
	if (body_a.is_in_group("segment") and body_a.spawn_timer > 0):
		# Only ignore collisions with other segments and player during spawn
		spawn_ignores_collision = body_b.is_in_group("segment") or body_b.is_in_group("player")
	elif (body_b is CharacterBody3D and body_b.is_in_group("segment") and body_b.spawn_timer > 0):
		# Only ignore collisions with other segments and player during spawn
		spawn_ignores_collision = body_a.is_in_group("segment") or body_a.is_in_group("player")
	
	if spawn_ignores_collision:
		return
		
	var mass_a = get_body_mass(body_a)
	var mass_b = get_body_mass(body_b)
	
	# Scale masses for collision response early
	var effective_mass_a = mass_a
	var effective_mass_b = mass_b
	
	# Adjust mass scaling for specific collision types
	if body_a.is_in_group("segment"):
		effective_mass_a *= SEGMENT_MASS_SCALE
		if body_b.is_in_group("rock"):
			effective_mass_a *= SEGMENT_MASS_SCALE
	
	if body_b.is_in_group("segment"):
		effective_mass_b *= SEGMENT_MASS_SCALE
		if body_a.is_in_group("rock"):
			effective_mass_b *= SEGMENT_MASS_SCALE
	
	# Special boost for rock impacts
	var rock_impact_boost = 1.0
	if (body_a.is_in_group("rock") and body_b.is_in_group("segment")) or \
	   (body_b.is_in_group("rock") and body_a.is_in_group("segment")):
		rock_impact_boost = ROCK_SEGMENT_IMPULSE_BOOST
	
	# Calculate velocities and impact characteristics
	var relative_velocity = body_b.velocity - body_a.velocity
	if not is_valid_vector(relative_velocity):
		push_warning("Invalid relative velocity detected")
		return
		
	var normal_speed = relative_velocity.dot(collision_normal)
	if not is_finite(normal_speed):
		push_warning("Invalid normal speed detected")
		return
	
	# Skip tiny collisions
	if abs(normal_speed) < REST_THRESHOLD:
		return
		
	var impact_force = min(abs(normal_speed), MAX_COLLISION_SPEED)
	
	# Apply cluster-based force reduction
	impact_force *= (1.0 - cluster_factor * FORCE_DISSIPATION_FACTOR)
	
	# Trigger impact flashes with calculated force
	if body_a.has_method("handle_impact"):
		body_a.handle_impact(impact_force)
	if body_b is CharacterBody3D and body_b.has_method("handle_impact"):
		body_b.handle_impact(impact_force)
	
	# Calculate collision response with adjusted masses
	var restitution = COLLISION_BOUNCE * (1.0 - cluster_factor * 0.5)
	if body_a.is_in_group("segment") and body_b is CharacterBody3D and body_b.is_in_group("segment"):
		restitution = SEGMENT_COLLISION_BOUNCE
	
	var denominator = (1.0 / effective_mass_a) + (1.0 / effective_mass_b)
	var impulse = -(1.0 + restitution) * normal_speed / denominator
	impulse = clamp(impulse, -MAX_IMPULSE, MAX_IMPULSE)
	
	# Calculate final impulse scale
	var impulse_scale = (1.0 - (cluster_factor * FORCE_DISSIPATION_FACTOR)) * rock_impact_boost
	if body_a.is_in_group("segment") or (body_b is CharacterBody3D and body_b.is_in_group("segment")):
		impulse_scale *= 1.25  # Additional scale for segment collisions
	
	# Apply impulses with all scaling factors
	var impulse_a = collision_normal * (impulse / effective_mass_a) * impulse_scale
	var impulse_b = collision_normal * (impulse / effective_mass_b) * impulse_scale
	
	if is_valid_vector(impulse_a):
		body_a.velocity -= impulse_a
	if body_b is CharacterBody3D and is_valid_vector(impulse_b):
		body_b.velocity += impulse_b
	
	# Calculate separation with rock impact consideration
	var separation_scale = 2.0 if rock_impact_boost > 1.0 else 1.0
	var separation = collision_normal * (
		SEGMENT_SEPARATION_FORCE if body_a.is_in_group("segment") and body_b.is_in_group("segment") else SEPARATION_FORCE
	) * delta * separation_scale
	
	# Apply separation
	body_a.velocity -= separation
	if body_b is CharacterBody3D:
		body_b.velocity += separation
	
	# Handle friction and tangential forces
	if body_a is PhysicsObject and body_b is PhysicsObject:
		# Calculate true normal force based on collision normal and masses
		var normal_force = abs(relative_velocity.dot(collision_normal)) * (mass_a + mass_b) / delta
		normal_force += (mass_a + mass_b) * PhysicsConstants.GRAVITY  # Add weight component
		
		# Calculate friction forces for both bodies using collision normal
		var friction_force_a = body_a.calculate_friction_force(body_b, normal_force, relative_velocity, collision_normal)
		var friction_force_b = body_b.calculate_friction_force(body_a, normal_force, -relative_velocity, -collision_normal)
		
		# Apply friction forces scaled by cluster factor
		var friction_scale = 1.0 - (cluster_factor * 0.7)  # Reduce friction in clusters
		body_a.apply_force(friction_force_a * friction_scale)
		body_b.apply_force(friction_force_b * friction_scale)
		
		# Remove direct velocity reduction and let forces handle it
		# This prevents the abrupt jumps we were seeing
	
	# Handle rock breaking
	if body_b is Rock:
		var force = body_a.velocity.length() * mass_a
		if force > body_b.BREAK_FORCE_THRESHOLD:
			body_b.break_rock()
		else:
			# Handle normal collision
			return

	# Special handling for segment collisions
	if body_a.is_in_group("segment") and body_b is CharacterBody3D and body_b.is_in_group("segment"):
		# Calculate tangent direction for sliding
		var tangent = (body_b.velocity - body_a.velocity).normalized()
		tangent = (tangent - collision_normal * tangent.dot(collision_normal)).normalized()
		
		# Apply tangential force to help segments slide past each other
		var tangent_force = tangent * SEGMENT_TANGENT_FORCE * (effective_mass_a + effective_mass_b)
		if is_valid_vector(tangent_force):
			body_a.apply_force(-tangent_force)
			if body_b is PhysicsObject:
				body_b.apply_force(tangent_force)

func handle_static_collision(body: CharacterBody3D, collision_normal: Vector3, _delta: float) -> void:
	var impact_speed = body.velocity.dot(collision_normal)  # Used in calculation
	var reflection = body.velocity.bounce(collision_normal) * COLLISION_BOUNCE
	body.velocity = reflection * VELOCITY_LOSS_ON_COLLISION
	
	# Add slight upward bounce to prevent sticking to ground
	if collision_normal.y > 0.5:  # If hitting ground-like surface
		body.velocity.y += abs(impact_speed) * 0.1

func handle_barrier_collision(body: CharacterBody3D, collision_normal: Vector3, _delta: float) -> void:
	var impact_force = body.velocity.length()
	
	# Handle impact flash for all physics objects
	if body.has_method("handle_impact"):
		body.handle_impact(impact_force * 1.5)  # Increased flash for barrier impacts
	
	# Make segments dangerous if they aren't already
	if body.is_in_group("segment") and not body.is_in_group("dangerous"):
		body.become_dangerous()
	
	# Calculate bounce with extra force
	var reflection = body.velocity.bounce(collision_normal)
	var push_force = collision_normal * BARRIER_PUSH_FORCE
	body.velocity = (reflection * BARRIER_BOUNCE_MULTIPLIER) + push_force
	
	# Ensure minimum bounce speed
	if body.velocity.length() < MIN_BARRIER_BOUNCE_SPEED:
		body.velocity = body.velocity.normalized() * MIN_BARRIER_BOUNCE_SPEED

# Check for nearby segments and apply separation forces
func handle_physics_proximity(body: CharacterBody3D, nearby_bodies: Array, delta: float) -> void:
	# Skip proximity checks for dangerous or queued for deletion objects
	if body.is_in_group("dangerous") or body.is_queued_for_deletion():
		return
	
	# Get nearby objects directly from spatial grid
	var nearby = spatial_grid.get_nearby(body.global_position, PROXIMITY_RADIUS)
	
	# Early out if not enough nearby objects
	if nearby.size() < 2:
		return
	
	# Limit checks per frame and filter out invalid objects
	var check_count = min(nearby.size(), MAX_OBJECTS_PER_CHECK)
	for i in range(check_count):
		var other = nearby[i]
		if not is_instance_valid(other) or other.is_queued_for_deletion():
			continue
			
		if other == body or not other is CharacterBody3D:
			continue
		
		# Skip checks between connected segments
		if body.is_in_group("segment") and other.is_in_group("segment"):
			if body.get("target") == other or other.get("target") == body:
				continue
		
		var direction = body.global_position - other.global_position
		var distance_squared = direction.length_squared()
		
		# Apply repulsion force between segments
		if body.is_in_group("segment") and other.is_in_group("segment"):
			if distance_squared < SEGMENT_REPULSION_RADIUS * SEGMENT_REPULSION_RADIUS:
				var distance = sqrt(distance_squared)
				var repulsion = direction.normalized() * (
					SEGMENT_REPULSION_FORCE * 
					(1.0 - distance / SEGMENT_REPULSION_RADIUS)
				) * delta
				
				# Scale repulsion based on relative velocity
				var rel_vel = body.velocity - other.velocity
				var approach_speed = -rel_vel.dot(direction.normalized())
				if approach_speed > 0:
					repulsion *= (1.0 + approach_speed)
				
				body.apply_force(repulsion * body.mass)
				other.apply_force(-repulsion * other.mass)
		
		if distance_squared < MINIMUM_SEPARATION * MINIMUM_SEPARATION:
			var distance = sqrt(distance_squared)
			var separation = direction.normalized() * (
				MINIMUM_SEPARATION - distance
			) * SEPARATION_FORCE * delta
			
			# Add velocity-based separation
			var rel_vel = body.velocity - (other.velocity if other is CharacterBody3D else Vector3.ZERO)
			var approach_speed = -rel_vel.dot(direction.normalized())
			if approach_speed > 0:
				separation *= (1.0 + approach_speed)
			
			body.velocity += separation * 2.0  # Increased separation effect
			if other is CharacterBody3D:
				other.velocity -= separation * 2.0

func get_body_mass(body: Node) -> float:
	if body is PhysicsObject:
		return body.mass
	else:
		return DEFAULT_MASS

func get_object_layer(obj: Node) -> int:
	if obj.is_in_group("segment"):
		return 1
	elif obj.is_in_group("rock"):
		return 2
	return 0
