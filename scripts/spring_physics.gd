extends Node
class_name SpringPhysics

const MIN_STIFFNESS = 0.2  # Much softer connection
const CHAIN_LENGTH_SCALING = 0.9  # Less aggressive scaling
const CHAIN_POSITION_FACTOR = 0.05  # Much less positional correction
const MIN_VELOCITY_MATCH = 0.05  # Almost no velocity matching

static func calculate_chain_factors(chain_index: int, chain_length: int) -> Dictionary:
	var chain_factor = chain_index / float(max(chain_length, 1))
	var position_scale = lerp(1.0, MIN_STIFFNESS, chain_factor * chain_factor)  # Quadratic falloff
	var length_factor = pow(CHAIN_LENGTH_SCALING, chain_index)
	
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
	
	var direction = to_target / current_distance
	var stretch = current_distance - target_distance
	
	# Simple spring force with reduced stiffness
	return direction * stretch * stiffness * force_scale * 0.5  # Halved base force

static func calculate_damping_force(
		velocity: Vector3,
		target_velocity: Vector3,
		damping: float,
		force_scale: float
	) -> Vector3:
	return (target_velocity - velocity) * damping * force_scale

static func calculate_velocity_matching(
		_current_pos: Vector3,
		_target_pos: Vector3,
		velocity: Vector3,
		target_velocity: Vector3,
		_target_distance: float,
		mass: float,
		matching_factor: float
	) -> Vector3:
	# Minimal velocity matching to maintain chain stability
	return (target_velocity - velocity) * matching_factor * mass * MIN_VELOCITY_MATCH

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
