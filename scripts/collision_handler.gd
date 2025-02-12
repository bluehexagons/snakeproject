extends Node

const MINIMUM_SEPARATION = 0.1
const SEPARATION_FORCE = 0.1
const COLLISION_BOUNCE = 0.4
const PLAYER_MASS = 0.5
const SEGMENT_MASS = 3.0
const ROCK_MASS = 8.0  # Increased rock mass
const FRICTION_COEFFICIENT = 0.15  # Increased friction
const ENERGY_TRANSFER = 0.85  # Reduced to lose more energy in collisions
const PERSISTENT_COLLISION_DAMPING = 0.8
const MAX_COLLISION_SPEED = 20.0
const REST_THRESHOLD = 0.1
const STATIC_BREAKAWAY_FORCE = 2.0  # Increased force needed to move rocks
const VELOCITY_LOSS_ON_COLLISION = 0.7  # How much velocity to maintain after collision
const BARRIER_BOUNCE_MULTIPLIER = 1.5  # Extra bounce for barrier collisions
const BARRIER_PUSH_FORCE = 3.0  # Additional force away from barrier
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

func handle_collision(body_a: CharacterBody3D, body_b: Node, collision_normal: Vector3, delta: float) -> void:
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
	var normal_speed = relative_velocity.dot(collision_normal)
	
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
	
	# Calculate collision response
	var restitution = COLLISION_BOUNCE * (1.0 - cluster_factor * 0.5)  # Reduce bounce in clusters
	var impulse = -(1.0 + restitution) * normal_speed / ((1.0 / mass_a) + (1.0 / mass_b))
	
	# Cap maximum impulse
	impulse = clamp(impulse, -MAX_IMPULSE, MAX_IMPULSE)
	
	# Apply impulse with cluster-based reduction
	var force_scale = 1.0 - (cluster_factor * FORCE_DISSIPATION_FACTOR)
	body_a.velocity -= collision_normal * (impulse / mass_a) * force_scale
	if body_b is CharacterBody3D:
		body_b.velocity += collision_normal * (impulse / mass_b) * force_scale
	
	# Apply separation to prevent sticking
	var separation = collision_normal * SEPARATION_FORCE * delta
	body_a.velocity -= separation
	if body_b is CharacterBody3D:
		body_b.velocity += separation

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
