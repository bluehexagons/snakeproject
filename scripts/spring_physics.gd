extends Node
class_name SpringPhysics

const MIN_STIFFNESS = 0.6          # Increased for better chain stability
const MAX_CHAIN_LENGTH = 20
const CHAIN_LENGTH_SCALING = 0.95   # Less aggressive scaling
const CHAIN_POSITION_FACTOR = 0.12
const MIN_VELOCITY_MATCH = 0.25     # Reduced for smoother following

static func calculate_chain_factors(chain_index: int, chain_length: int) -> Dictionary:
	var chain_factor = chain_index / float(max(chain_length, 1))
	var position_scale = lerp(1.0, MIN_STIFFNESS, pow(chain_factor, 0.6))
	
	var length_factor = 1.0
	if chain_length > MAX_CHAIN_LENGTH:
		var excess = chain_length - MAX_CHAIN_LENGTH
		length_factor = pow(CHAIN_LENGTH_SCALING, excess)
	
	return {
		"chain_factor": chain_factor,
		"position_scale": position_scale,
		"length_factor": length_factor
	}

static func calculate_spring_force(
		current_pos: Vector3,
		target_pos: Vector3, 
		target_distance: float,
		stiffness: float,
		force_scale: float
	) -> Vector3:
	var to_target = target_pos - current_pos
	var current_distance = to_target.length()
	
	if current_distance <= 0:
		return Vector3.ZERO
	
	# Smoother spring force calculation
	var target_direction = to_target / current_distance
	var displacement = current_distance - target_distance
	var spring_force = displacement * target_direction * stiffness
	
	# Add soft limit to prevent excessive force
	var max_force = stiffness * target_distance * 2.0
	if spring_force.length_squared() > max_force * max_force:
		spring_force = spring_force.normalized() * max_force
	
	return spring_force * force_scale

static func calculate_damping_force(
		velocity: Vector3,
		target_velocity: Vector3,
		damping: float,
		force_scale: float
	) -> Vector3:
	# Simplified damping calculation
	return (target_velocity - velocity) * damping * force_scale

static func calculate_velocity_matching(
		current_pos: Vector3,
		target_pos: Vector3,
		velocity: Vector3,
		target_velocity: Vector3,
		target_distance: float,
		mass: float,
		matching_factor: float
	) -> Vector3:
	var current_distance = (target_pos - current_pos).length()
	var distance_factor = clamp(1.0 - (current_distance / (target_distance * 2.0)), MIN_VELOCITY_MATCH, 1.0)
	return (target_velocity - velocity) * matching_factor * mass * distance_factor

static func apply_velocity_inheritance(
		velocity: Vector3,
		target_velocity: Vector3,
		delta: float,
		inheritance_speed: float,
		inheritance_factor: float,
		mass: float
	) -> Vector3:
	var target_speed = target_velocity.length()
	if target_speed > 0.1:
		var desired_direction = target_velocity.normalized()
		var current_direction = velocity.normalized()
		
		var blend_factor = min(delta * inheritance_speed, 1.0)
		var new_direction = current_direction.lerp(desired_direction, blend_factor)
		
		return (new_direction * target_speed * inheritance_factor - velocity) * mass
	
	return Vector3.ZERO
