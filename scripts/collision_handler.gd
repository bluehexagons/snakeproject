extends Node

const MINIMUM_SEPARATION = 0.8
const SEPARATION_FORCE = 80.0
const COLLISION_BOUNCE = 0.6  # Increased for more energetic collisions
const PLAYER_MASS = 0.5
const SEGMENT_MASS = 3.0
const FRICTION_COEFFICIENT = 0.05  # Reduced to allow more sliding
const ENERGY_TRANSFER = 0.8  # How much kinetic energy is preserved in collisions
const PERSISTENT_COLLISION_DAMPING = 0.95  # Reduce velocity when objects stay in contact
const MAX_COLLISION_SPEED = 20.0  # Cap the maximum collision response
const REST_THRESHOLD = 0.1  # Speed below which objects are considered at rest

func handle_collision(body_a: CharacterBody3D, body_b: CharacterBody3D, collision_normal: Vector3, delta: float) -> void:
	var mass_a = PLAYER_MASS if body_a.is_in_group("player") else SEGMENT_MASS
	var mass_b = PLAYER_MASS if body_b.is_in_group("player") else SEGMENT_MASS
	
	# Calculate relative velocity and its components
	var relative_velocity = body_b.velocity - body_a.velocity
	var normal_speed = relative_velocity.dot(collision_normal)
	
	# Handle persistent collisions (objects staying in contact)
	var penetration = MINIMUM_SEPARATION - body_a.global_position.distance_to(body_b.global_position)
	if penetration > 0:
		# Apply additional damping when objects are in sustained contact
		body_a.velocity *= PERSISTENT_COLLISION_DAMPING
		body_b.velocity *= PERSISTENT_COLLISION_DAMPING
	
	# Only process collision if objects are moving toward each other
	if normal_speed > 0:
		return
	
	# Limit collision speed
	normal_speed = clamp(normal_speed, -MAX_COLLISION_SPEED, MAX_COLLISION_SPEED)
	
	# Calculate coefficient of restitution based on relative speed
	var restitution = COLLISION_BOUNCE * ENERGY_TRANSFER
	
	# Reduce restitution for low-speed collisions to help objects come to rest
	if abs(normal_speed) < REST_THRESHOLD:
		restitution *= normal_speed / REST_THRESHOLD
	
	# Calculate impulse magnitude using the elastic collision formula
	var impulse_magnitude = -(1.0 + restitution) * normal_speed
	impulse_magnitude /= (1.0 / mass_a) + (1.0 / mass_b)
	
	# Apply impulse to both bodies
	var impulse = collision_normal * impulse_magnitude
	var velocity_change_a = -impulse / mass_a
	var velocity_change_b = impulse / mass_b
	
	# Calculate tangential forces (friction)
	var tangent_velocity = relative_velocity - (normal_speed * collision_normal)
	if tangent_velocity.length_squared() > 0.001:
		var tangent = tangent_velocity.normalized()
		var friction_impulse = -tangent * abs(impulse_magnitude) * FRICTION_COEFFICIENT
		
		velocity_change_a -= friction_impulse / mass_a
		velocity_change_b += friction_impulse / mass_b
	
	# Apply final velocity changes
	body_a.velocity += velocity_change_a
	body_b.velocity += velocity_change_b
	
	# Bring very slow-moving objects to a complete stop
	if body_a.velocity.length() < REST_THRESHOLD:
		body_a.velocity = Vector3.ZERO
	if body_b.velocity.length() < REST_THRESHOLD:
		body_b.velocity = Vector3.ZERO
	
	# Apply separation force to prevent sticking
	if penetration > 0:
		var separation_force = collision_normal * SEPARATION_FORCE * delta * penetration
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
