extends Node
# Remove duplicate chain constants
const MIN_FORCE_THRESHOLD = 0.1     # Common physics threshold
const MAX_SPEED = 30.0             # Maximum physics speed

const MIN_STIFFNESS = 0.15          # Even softer to allow more stretch
const CHAIN_LENGTH_SCALING = 0.95    # Less aggressive scaling
const MIN_VELOCITY_MATCH = 0.02     # Minimal velocity matching
const MAX_FORCE_SCALE = 2.0         # Limit maximum force
const FORCE_FALLOFF_RATE = 1.2      # How quickly force reduces through chain
const SAFE_FORCE_THRESHOLD = 0.1    # Don't apply tiny forces
const MAX_WALK_SPEED = 10.0         # Speed limit for walking movement
const WALK_ACCELERATION = 40.0      # How quickly to accelerate when walking
const WALK_FORCE_SCALE = 0.8        # Scale down walking forces
const PULL_FORCE_SCALE = 1.2        # Scale up pulling forces
const TENSION_BUILD_RATE = 0.8      # How quickly chain tension builds
const MIN_TENSION = 0.2             # Minimum tension to maintain chain shape

# Calculate how forces should scale based on position in chain
static func calculate_chain_factors(chain_index: int, chain_length: int) -> Dictionary:
	var chain_factor = chain_index / float(max(chain_length, 1))
	var position_scale = lerp(1.0, MIN_STIFFNESS, chain_factor * chain_factor)
	var length_factor = pow(CHAIN_LENGTH_SCALING, chain_index)
	
	return {
		"chain_factor": chain_factor,
		"position_scale": position_scale,
		"length_factor": length_factor,
		"force_scale": max(MIN_TENSION, 1.0 - (chain_factor * FORCE_FALLOFF_RATE))
	}

# Calculate forces for maintaining chain linkage
static func calculate_spring_force(
		current_pos: Vector3,
		target_pos: Vector3, 
		target_distance: float,
		stiffness: float,
		chain_factor: float,
		tension: float
	) -> Vector3:
	var to_target = target_pos - current_pos
	var current_distance = to_target.length()
	
	if current_distance <= 0:
		return Vector3.ZERO
	
	var direction = to_target / current_distance
	var stretch = current_distance - target_distance
	
	# Scale force based on stretch and chain position
	var force_magnitude = stretch * stiffness * chain_factor * tension
	force_magnitude = clamp(force_magnitude, -MAX_FORCE_SCALE, MAX_FORCE_SCALE)
	
	if abs(force_magnitude) < SAFE_FORCE_THRESHOLD:
		return Vector3.ZERO
	
	return direction * force_magnitude

# Calculate walking forces for intelligent segment movement
static func calculate_walk_force(
		current_pos: Vector3,
		target_pos: Vector3,
		current_velocity: Vector3,
		target_velocity: Vector3,
		chain_factor: float,
		target_distance: float
	) -> Vector3:
	var to_target = target_pos - current_pos
	var distance = to_target.length()
	
	if distance <= target_distance or distance <= 0.001:
		return Vector3.ZERO
	
	# Only walk if we're too far behind
	if distance < target_distance * 1.5:
		return Vector3.ZERO
	
	var walk_direction = to_target / distance
	var current_speed = current_velocity.length()
	
	# Don't walk if moving too fast or if target is moving away quickly
	if current_speed > MAX_WALK_SPEED:
		return Vector3.ZERO
	
	var target_speed = target_velocity.length()
	if target_speed > MAX_WALK_SPEED:
		return Vector3.ZERO
	
	# Calculate walk force that scales with distance and chain position
	var force = walk_direction * WALK_ACCELERATION * chain_factor * WALK_FORCE_SCALE
	
	# Reduce force if target is moving toward us
	var relative_velocity = target_velocity - current_velocity
	var approaching_speed = -relative_velocity.dot(walk_direction)
	if approaching_speed > 0:
		force *= (1.0 - clamp(approaching_speed / MAX_WALK_SPEED, 0.0, 1.0))
	
	return force

# Calculate damping forces to prevent oscillation
static func calculate_damping_force(
		velocity: Vector3,
		target_velocity: Vector3,
		damping: float,
		force_scale: float
	) -> Vector3:
	var relative_velocity = velocity - target_velocity
	return -relative_velocity * damping * force_scale
