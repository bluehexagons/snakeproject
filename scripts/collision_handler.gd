extends Node

const MINIMUM_SEPARATION = 0.8
const SEPARATION_FORCE = 80.0
const COLLISION_BOUNCE = 0.4  # Reduced bounce for more stable collisions
const PLAYER_MASS = 0.5
const SEGMENT_MASS = 3.0
const ROCK_MASS = 5.0
const FRICTION_COEFFICIENT = 0.1
const ENERGY_TRANSFER = 0.95  # Increased energy transfer
const PERSISTENT_COLLISION_DAMPING = 0.8  # Less aggressive damping
const MAX_COLLISION_SPEED = 20.0
const REST_THRESHOLD = 0.1
const STATIC_BREAKAWAY_FORCE = 2.0  # Force needed to start moving a static object

func handle_collision(body_a: CharacterBody3D, body_b: CharacterBody3D, collision_normal: Vector3, delta: float) -> void:
	var mass_a = get_body_mass(body_a)
	var mass_b = get_body_mass(body_b)
	
	# Calculate velocities and energies
	var relative_velocity = body_b.velocity - body_a.velocity
	var normal_speed = relative_velocity.dot(collision_normal)
	
	# Calculate initial kinetic energies
	var energy_a = 0.5 * mass_a * body_a.velocity.length_squared()
	var energy_b = 0.5 * mass_b * body_b.velocity.length_squared()
	var total_energy = energy_a + energy_b
	
	# Handle static friction for rocks
	if body_a.is_in_group("rock") and relative_velocity.length() < STATIC_BREAKAWAY_FORCE:
		mass_a *= 2.0  # Make rocks harder to move when static
	if body_b.is_in_group("rock") and relative_velocity.length() < STATIC_BREAKAWAY_FORCE:
		mass_b *= 2.0
	
	# Calculate impulse for the collision
	var restitution = COLLISION_BOUNCE * ENERGY_TRANSFER
	var impulse_magnitude = -(1.0 + restitution) * normal_speed / ((1.0 / mass_a) + (1.0 / mass_b))
	var impulse = collision_normal * impulse_magnitude
	
	# Apply impulses
	var vel_change_a = -impulse / mass_a
	var vel_change_b = impulse / mass_b
	
	# Calculate and apply friction
	var tangent_velocity = relative_velocity - (normal_speed * collision_normal)
	if tangent_velocity.length_squared() > 0.001:
		var tangent = tangent_velocity.normalized()
		var friction_impulse = -tangent * abs(impulse_magnitude) * FRICTION_COEFFICIENT
		
		vel_change_a -= friction_impulse / mass_a
		vel_change_b += friction_impulse / mass_b
	
	# Apply velocity changes
	body_a.velocity += vel_change_a
	body_b.velocity += vel_change_b
	
	# Ensure energy is conserved (with some intentional loss)
	var new_energy_a = 0.5 * mass_a * body_a.velocity.length_squared()
	var new_energy_b = 0.5 * mass_b * body_b.velocity.length_squared()
	var new_total_energy = new_energy_a + new_energy_b
	
	if new_total_energy > total_energy:
		var scale = sqrt(total_energy / new_total_energy) * ENERGY_TRANSFER
		body_a.velocity *= scale
		body_b.velocity *= scale
	
	# Apply separation
	var separation_vector = (body_b.global_position - body_a.global_position)
	var penetration = MINIMUM_SEPARATION - separation_vector.length()
	if penetration > 0:
		var separation = collision_normal * SEPARATION_FORCE * delta * penetration
		body_a.velocity -= separation / mass_a
		body_b.velocity += separation / mass_b

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
