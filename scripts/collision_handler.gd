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
	
	# Don't handle collisions with dangerous segments
	if body_b.is_in_group("dangerous") or body_a.is_in_group("dangerous"):
		return
		
	# Only proceed with CharacterBody3D collisions
	if not body_b is CharacterBody3D:
		return
		
	var mass_a = get_body_mass(body_a)
	var mass_b = get_body_mass(body_b)
	
	# Calculate velocities and impact characteristics
	var relative_velocity = body_b.velocity - body_a.velocity
	var normal_speed = relative_velocity.dot(collision_normal)
	var impact_force = abs(normal_speed)
	
	# Calculate how head-on the collision is (1.0 = head-on, 0.0 = glancing)
	var a_dir = body_a.velocity.normalized()
	var b_dir = body_b.velocity.normalized()
	var collision_alignment = abs(a_dir.dot(collision_normal))
	var velocity_alignment = max(0.0, -a_dir.dot(b_dir))  # How opposed the velocities are
	var impact_factor = (collision_alignment + velocity_alignment) * 0.5
	
	# Trigger impact flashes
	if body_a.has_method("handle_impact"):
		body_a.handle_impact(impact_force)
	if body_b.has_method("handle_impact"):
		body_b.handle_impact(impact_force)
	
	# Scale effects based on impact_factor
	var velocity_loss = lerp(1.0, VELOCITY_LOSS_ON_COLLISION, impact_factor)
	var friction_scale = impact_factor
	var restitution = COLLISION_BOUNCE * ENERGY_TRANSFER * impact_factor
	
	# Apply scaled velocity loss
	body_a.velocity *= velocity_loss
	body_b.velocity *= velocity_loss
	
	# Handle static friction for rocks with scaled effect
	var rock_mass_multiplier = lerp(1.0, 3.0, impact_factor)
	if body_a.is_in_group("rock") and relative_velocity.length() < STATIC_BREAKAWAY_FORCE:
		mass_a *= rock_mass_multiplier
	if body_b.is_in_group("rock") and relative_velocity.length() < STATIC_BREAKAWAY_FORCE:
		mass_b *= rock_mass_multiplier
	
	# Calculate impulse with scaled restitution
	var impulse_magnitude = -(1.0 + restitution) * normal_speed
	impulse_magnitude /= (1.0 / mass_a) + (1.0 / mass_b)
	
	# Apply impulses
	var impulse = collision_normal * impulse_magnitude
	var vel_change_a = -impulse / mass_a
	var vel_change_b = impulse / mass_b
	
	# Apply scaled friction
	var tangent_velocity = relative_velocity - (normal_speed * collision_normal)
	if tangent_velocity.length_squared() > 0.001:
		var tangent = tangent_velocity.normalized()
		var friction_impulse = -tangent * abs(impulse_magnitude) * FRICTION_COEFFICIENT * friction_scale
		
		vel_change_a -= friction_impulse / mass_a
		vel_change_b += friction_impulse / mass_b
	
	# Apply final velocity changes
	body_a.velocity += vel_change_a
	body_b.velocity += vel_change_b
	
	# Apply separation (always needed regardless of collision type)
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
	# Skip proximity checks for dangerous segments
	if body.is_in_group("dangerous"):
		return
		
	# Only check segments that are close to this one in the chain
	for other in nearby_bodies:
		if other == body or other.is_in_group("dangerous"):
			continue
			
		var direction = body.global_position - other.global_position
		var distance_squared = direction.length_squared()  # Optimization: avoid square root
		
		if distance_squared < MINIMUM_SEPARATION * MINIMUM_SEPARATION:
			var distance = sqrt(distance_squared)  # Only calculate when needed
			var separation = direction.normalized() * (MINIMUM_SEPARATION - distance) * SEPARATION_FORCE * delta
			body.velocity -= separation

func get_body_mass(body: Node) -> float:
	if body.is_in_group("player"):
		return PLAYER_MASS
	elif body.is_in_group("rock"):
		return ROCK_MASS
	else:
		return SEGMENT_MASS
