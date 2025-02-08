extends Node

const MINIMUM_SEPARATION = 0.8
const SEPARATION_FORCE = 80.0
const COLLISION_BOUNCE = 0.3
const PLAYER_MASS = 0.5
const SEGMENT_MASS = 3.0
const FRICTION_COEFFICIENT = 0.1  # How much to reduce tangential velocity

func handle_collision(body_a: CharacterBody3D, body_b: CharacterBody3D, collision_normal: Vector3, delta: float) -> void:
	var mass_a = PLAYER_MASS if body_a.is_in_group("player") else SEGMENT_MASS
	var mass_b = PLAYER_MASS if body_b.is_in_group("player") else SEGMENT_MASS
	
	# Calculate mass ratios for momentum conservation
	var total_mass = mass_a + mass_b
	var mass_ratio_a = mass_a / total_mass
	var mass_ratio_b = mass_b / total_mass
	
	# Calculate relative velocity
	var relative_velocity = body_b.velocity - body_a.velocity
	
	# Split velocity into normal and tangential components
	var normal_velocity = relative_velocity.dot(collision_normal) * collision_normal
	var tangent_velocity = relative_velocity - normal_velocity
	
	# Only apply collision response if objects are moving toward each other
	if normal_velocity.dot(collision_normal) > 0:
		return
	
	# Calculate impulse for normal component
	var normal_impulse = -normal_velocity * (1.0 + COLLISION_BOUNCE)
	
	# Apply friction to tangential component
	var friction_impulse = -tangent_velocity * FRICTION_COEFFICIENT
	
	# Combine impulses
	var total_impulse = normal_impulse + friction_impulse
	
	# Apply velocities based on mass ratios
	var velocity_change_a = total_impulse * mass_ratio_b
	var velocity_change_b = -total_impulse * mass_ratio_a
	
	body_a.velocity += velocity_change_a
	body_b.velocity += velocity_change_b
	
	# Apply separation force along normal only
	var separation_force = collision_normal * SEPARATION_FORCE * delta
	body_a.velocity -= separation_force
	body_b.velocity += separation_force

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
