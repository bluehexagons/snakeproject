extends Node

const MINIMUM_SEPARATION = 0.1
const SEPARATION_FORCE = 0.1
const COLLISION_BOUNCE = 0.4
const PERSISTENT_COLLISION_DAMPING = 0.8
const MAX_COLLISION_SPEED = 20.0
const REST_THRESHOLD = 0.1
const VELOCITY_LOSS_ON_COLLISION = 0.7  # How much velocity to maintain after collision
const BARRIER_BOUNCE_MULTIPLIER = 1.0  # Extra bounce for barrier collisions
const BARRIER_PUSH_FORCE = 0.25  # Additional force away from barrier
const MIN_BARRIER_BOUNCE_SPEED = 2.0  # Minimum speed after barrier bounce
const DEFAULT_MASS = 1.0

# New constants for optimization
const MAX_IMPULSE = 1000.0  # Cap maximum collision response
const FORCE_DISSIPATION_FACTOR = 0.7  # Reduce force in tight clusters
const PROXIMITY_GRID_SIZE = 2.0  # Size of spatial grid cells
const MAX_BODIES_PER_CELL = 8  # Limit checks in dense areas
const CLUSTER_CHECK_RADIUS = 3.0  # Radius to check for clustered objects

# Spatial partitioning for broad phase
var proximity_grid = {}
var frame_index: int = 0

func _physics_process(_delta):
	# Clear grid each physics frame
	proximity_grid.clear()
	frame_index += 1

func get_grid_cell(pos: Vector3) -> Vector2i:
	return Vector2i(
		floor(pos.x / PROXIMITY_GRID_SIZE),
		floor(pos.z / PROXIMITY_GRID_SIZE)
	)

func add_to_grid(body: Node3D, cell: Vector2i):
	var key = str(cell)
	if !proximity_grid.has(key):
		proximity_grid[key] = []
	if proximity_grid[key].size() < MAX_BODIES_PER_CELL:
		proximity_grid[key].append(body)

func get_nearby_bodies(pos: Vector3) -> Array:
	var cell = get_grid_cell(pos)
	var nearby = []
	
	# Check 3x3 grid of cells
	for x in range(-1, 2):
		for z in range(-1, 2):
			var check_cell = cell + Vector2i(x, z)
			var key = str(check_cell)
			if proximity_grid.has(key):
				nearby.append_array(proximity_grid[key])
	
	return nearby

func is_valid_vector(v: Vector3) -> bool:
	return v.is_finite() and v.length_squared() < 1000000.0

func handle_collision(body_a: CharacterBody3D, body_b: Node, collision_normal: Vector3, delta: float) -> void:
	if not is_valid_vector(collision_normal):
		push_warning("Invalid collision normal detected")
		return

	# Add bodies to spatial grid
	var cell_a = get_grid_cell(body_a.global_position)
	add_to_grid(body_a, cell_a)
	
	if body_b is CharacterBody3D:
		var cell_b = get_grid_cell(body_b.global_position)
		add_to_grid(body_b, cell_b)
	
	# Check for clustered collisions
	var nearby_count = get_nearby_bodies(body_a.global_position).size()
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
		
	var mass_a = get_body_mass(body_a)
	var mass_b = get_body_mass(body_b)
	
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
	
	# Calculate collision response with safety checks
	var restitution = COLLISION_BOUNCE * (1.0 - cluster_factor * 0.5)  # Reduce bounce in clusters
	var denominator = (1.0 / mass_a) + (1.0 / mass_b)
	if denominator <= 0.0 or not is_finite(denominator):
		push_warning("Invalid mass calculation detected")
		return
		
	var impulse = -(1.0 + restitution) * normal_speed / denominator
	
	# Cap maximum impulse
	impulse = clamp(impulse, -MAX_IMPULSE, MAX_IMPULSE)
	
	# Apply impulse with safety checks
	var force_scale = 1.0 - (cluster_factor * FORCE_DISSIPATION_FACTOR)
	var impulse_a = collision_normal * (impulse / mass_a) * force_scale
	var impulse_b = collision_normal * (impulse / mass_b) * force_scale
	
	if is_valid_vector(impulse_a):
		body_a.velocity -= impulse_a
	if body_b is CharacterBody3D and is_valid_vector(impulse_b):
		body_b.velocity += impulse_b
	
	# Apply separation to prevent sticking
	var separation = collision_normal * SEPARATION_FORCE * delta
	body_a.velocity -= separation
	if body_b is CharacterBody3D:
		body_b.velocity += separation

	# Handle friction between physics objects
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
func handle_proximity(body: CharacterBody3D, nearby_bodies: Array, delta: float) -> void:
	# Skip proximity checks for dangerous segments
		
	# Only check segments that are close to this one in the chain
	for other in nearby_bodies:
		if other == body:
			continue
			
		var direction = body.global_position - other.global_position
		var distance_squared = direction.length_squared()  # Optimization: avoid square root
		
		if distance_squared < MINIMUM_SEPARATION * MINIMUM_SEPARATION:
			var distance = sqrt(distance_squared)  # Only calculate when needed
			var separation = direction.normalized() * (MINIMUM_SEPARATION - distance) * SEPARATION_FORCE * delta
			body.velocity -= separation

func get_body_mass(body: Node) -> float:
	if body is PhysicsObject:
		return body.mass
	else:
		return DEFAULT_MASS
