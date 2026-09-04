extends RefCounted
class_name ChainPhysics

# Timing constants
const SPRING_FORCE_DELAY = 0.1
const COLLISION_RECOVERY_DELAY = 0.1
# Chain behavior
const TENSION_BUILD_RATE = 4.0
const MIN_TENSION = 0.2
const TENSION_RELEASE_RATE = 6.0

# Movement constants and thresholds
const SPRING_STIFFNESS = 34.0
const STRETCH_STIFFNESS_SCALE = 1.75
const MAX_STRETCH_RATIO = 1.5
const SPRING_DAMPING = 9.0
const MAX_SPRING_FORCE = 180.0
const SPRING_SLACK_RATIO = 0.03

# Force scaling
const MIN_STIFFNESS = 0.15
const CHAIN_LENGTH_SCALING = 0.95
const FORCE_FALLOFF_RATE = 1.2

# Movement and behavior
const MAX_WALK_SPEED = 10.0

static func calculate_chain_forces(
		current_pos: Vector3,
		target_pos: Vector3,
		chain_index: int,
		chain_length: int,
		target_distance: float,
		current_tension: float,
		collision_recovery: float = 1.0,
		current_velocity: Vector3 = Vector3.ZERO,
		target_velocity: Vector3 = Vector3.ZERO
	) -> Dictionary:
	
	var chain_factor = chain_index / float(max(chain_length, 1))
	var position_scale = lerp(1.0, MIN_STIFFNESS, chain_factor * chain_factor)
	var length_factor = pow(CHAIN_LENGTH_SCALING, chain_index)
	
	var force_scale = max(MIN_TENSION, 1.0 - (chain_factor * FORCE_FALLOFF_RATE))
	
	var to_target = target_pos - current_pos
	var current_distance = to_target.length()
	
	if current_distance <= 0 or target_distance <= 0:
		return {
			"spring_force": Vector3.ZERO,
			"chain_factor": chain_factor,
		}
	
	var direction = to_target / current_distance
	var extension = current_distance - target_distance
	var slack_distance = target_distance * SPRING_SLACK_RATIO
	if extension <= slack_distance:
		return {
			"spring_force": Vector3.ZERO,
			"chain_factor": chain_factor,
		}

	var stretch_ratio = minf(extension / target_distance, MAX_STRETCH_RATIO)
	var stiffness = SPRING_STIFFNESS * (1.0 + stretch_ratio * STRETCH_STIFFNESS_SCALE)
	var separation_speed = (target_velocity - current_velocity).dot(direction)
	var spring_strength = extension * stiffness + separation_speed * SPRING_DAMPING
	spring_strength = clampf(spring_strength, 0.0, MAX_SPRING_FORCE)
	var spring_force = direction * spring_strength
	
	spring_force *= force_scale * position_scale * length_factor * current_tension * collision_recovery
	
	return {
		"spring_force": spring_force,
		"chain_factor": chain_factor,
	}

static func calculate_walk_force(
		current_pos: Vector3,
		target_pos: Vector3,
		current_vel: Vector3,
		target_vel: Vector3,
		chain_factor: float,
		base_acceleration: float,
		target_distance: float
	) -> Vector3:
	
	var to_target = target_pos - current_pos
	var distance = to_target.length()
	
	if distance <= target_distance or target_distance <= 0.0:
		return Vector3.ZERO
	
	var walk_direction = to_target / distance
	var distance_engagement = clampf((distance - target_distance) / target_distance, 0.0, 1.0)
	var follow_strength = lerpf(1.0, 0.35, clampf(chain_factor, 0.0, 1.0))
	var force = walk_direction * base_acceleration * follow_strength * distance_engagement
	
	var closing_speed = (current_vel - target_vel).dot(walk_direction)
	if closing_speed > 0:
		force *= (1.0 - clamp(closing_speed / MAX_WALK_SPEED, 0.0, 1.0))
	
	return force
