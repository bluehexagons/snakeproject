extends Node

const MINIMUM_SEPARATION = 0.8
const SEPARATION_FORCE = 80.0
const COLLISION_BOUNCE = 0.6  # Increased for more energetic collisions
const PLAYER_MASS = 0.5
const SEGMENT_MASS = 3.0
const FRICTION_COEFFICIENT = 0.05  # Reduced to allow more sliding
const ENERGY_TRANSFER = 0.8  # How much kinetic energy is preserved in collisions

func handle_collision(body_a: CharacterBody3D, body_b: CharacterBody3D, collision_normal: Vector3, delta: float) -> void:
	var mass_a = PLAYER_MASS if body_a.is_in_group("player") else SEGMENT_MASS
	var mass_b = PLAYER_MASS if body_b.is_in_group("player") else SEGMENT_MASS
	
	# Calculate relative velocity and its components
	var relative_velocity = body_b.velocity - body_a.velocity
	var normal_speed = relative_velocity.dot(collision_normal)
	
	# Only process collision if objects are moving toward each other
	if normal_speed > 0:
		return
	
	# Calculate coefficient of restitution based on relative speed
	var restitution = COLLISION_BOUNCE * ENERGY_TRANSFER
	
	# Calculate impulse magnitude using the elastic collision formula
	var impulse_magnitude = -(1.0 + restitution) * normal_speed
	impulse_magnitude /= (1.0 / mass_a) + (1.0 / mass_b)
	
	# Apply impulse to both bodies
	var impulse = collision_normal * impulse_magnitude
	body_a.velocity -= impulse / mass_a
	body_b.velocity += impulse / mass_b
	
	# Calculate and apply tangential forces (friction)
	var tangent_velocity = relative_velocity - (normal_speed * collision_normal)
	if tangent_velocity.length_squared() > 0.001:
		var tangent = tangent_velocity.normalized()
		var friction_impulse = -tangent * impulse_magnitude * FRICTION_COEFFICIENT
		
		body_a.velocity -= friction_impulse / mass_a
		body_b.velocity += friction_impulse / mass_b
	
	# Apply separation force to prevent sticking
	var separation_vector = (body_b.global_position - body_a.global_position)
	var separation_distance = separation_vector.length()
	if separation_distance < MINIMUM_SEPARATION:
		var separation_force = collision_normal * SEPARATION_FORCE * delta * (MINIMUM_SEPARATION - separation_distance)
		body_a.velocity -= separation_force / mass_a
		body_b.velocity += separation_force / mass_b

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
