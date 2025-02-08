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

func handle_collision(body_a: CharacterBody3D, body_b: Node, collision_normal: Vector3, delta: float) -> void:
	# Early return for static bodies (barriers)
	if body_b is StaticBody3D:
		handle_static_collision(body_a, collision_normal, delta)
		return
	
	# Only proceed with CharacterBody3D collisions
	if not body_b is CharacterBody3D:
		return
		
	var mass_a = get_body_mass(body_a)
	var mass_b = get_body_mass(body_b)
	
	# Calculate velocities and energies
	var relative_velocity = body_b.velocity - body_a.velocity
	var normal_speed = relative_velocity.dot(collision_normal)
	
	# Additional velocity loss on collision
	body_a.velocity *= VELOCITY_LOSS_ON_COLLISION
	body_b.velocity *= VELOCITY_LOSS_ON_COLLISION
	
	# Handle static friction for rocks with increased effect
	if body_a.is_in_group("rock"):
		if relative_velocity.length() < STATIC_BREAKAWAY_FORCE:
			mass_a *= 3.0  # Increased mass multiplier for static rocks
	if body_b.is_in_group("rock"):
		if relative_velocity.length() < STATIC_BREAKAWAY_FORCE:
			mass_b *= 3.0
	
	# Calculate impulse with increased mass effect
	var restitution = COLLISION_BOUNCE * ENERGY_TRANSFER
	var impulse_magnitude = -(1.0 + restitution) * normal_speed
	impulse_magnitude /= (1.0 / mass_a) + (1.0 / mass_b)
	
	# Apply impulses with stronger effect
	var impulse = collision_normal * impulse_magnitude
	body_a.velocity -= impulse / mass_a
	body_b.velocity += impulse / mass_b
	
	# Enhanced friction effect
	var tangent_velocity = relative_velocity - (normal_speed * collision_normal)
	if tangent_velocity.length_squared() > 0.001:
		var tangent = tangent_velocity.normalized()
		var friction_impulse = -tangent * abs(impulse_magnitude) * FRICTION_COEFFICIENT
		
		body_a.velocity -= friction_impulse / mass_a
		body_b.velocity += friction_impulse / mass_b
	
	# Apply separation with mass consideration
	var separation_vector = (body_b.global_position - body_a.global_position)
	var penetration = MINIMUM_SEPARATION - separation_vector.length()
	if penetration > 0:
		var separation = collision_normal * SEPARATION_FORCE * delta * penetration
		body_a.velocity -= separation / mass_a
		body_b.velocity += separation / mass_b

func handle_static_collision(body: CharacterBody3D, collision_normal: Vector3, delta: float) -> void:
	var impact_speed = body.velocity.dot(collision_normal)  # Used in calculation
	var reflection = body.velocity.bounce(collision_normal) * COLLISION_BOUNCE
	body.velocity = reflection * VELOCITY_LOSS_ON_COLLISION
	
	# Add slight upward bounce to prevent sticking to ground
	if collision_normal.y > 0.5:  # If hitting ground-like surface
		body.velocity.y += abs(impact_speed) * 0.1

# Check for nearby segments and apply separation forces
func handle_proximity(body: CharacterBody3D, nearby_bodies: Array, delta: float) -> void:
	for other in nearby_bodies:
		if other == body:
			continue
			
		var direction = body.global_position - other.global_position
		var distance = direction.length()
		
		if distance < MINIMUM_SEPARATION:
			var separation = direction.normalized() * (MINIMUM_SEPARATION - distance) * SEPARATION_FORCE * delta
			body.velocity -= separation

func get_body_mass(body: Node) -> float:
	if body.is_in_group("player"):
		return PLAYER_MASS
	elif body.is_in_group("rock"):
		return ROCK_MASS
	else:
		return SEGMENT_MASS
