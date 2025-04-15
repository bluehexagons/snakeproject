extends Node
class_name ChainPhysics

func _ready():
	process_mode = Node.PROCESS_MODE_DISABLED  # This is a data-only node

# Timing constants
const SPRING_FORCE_DELAY = 0.1
const COLLISION_RECOVERY_DELAY = 0.1
const FORCE_RESPONSE_RATE = 0.8

# Chain behavior
const TENSION_BUILD_RATE = 0.8
const MIN_TENSION = 0.2
const TENSION_DAMPING = 0.85
const CHAIN_DRAG_REDUCTION = 0.7
const CHAIN_MIN_SPEED = 1.0

# Movement constants and thresholds
const MAX_STRETCH = 2.5
const STRETCH_THRESHOLD = 0.99
const SPRING_STIFFNESS = 40.0
const STIFFNESS_SCALE = 10.4
const SNAP_THRESHOLD = 0.1

# Force scaling
const MIN_STIFFNESS = 0.15
const CHAIN_LENGTH_SCALING = 0.95
const MAX_FORCE_SCALE = 2.0
const FORCE_FALLOFF_RATE = 1.2

# Force calculations
const SAFE_FORCE_THRESHOLD = 0.1

# Movement and behavior
const MAX_WALK_SPEED = 10.0
const WALK_ACCELERATION = 40.0
const WALK_FORCE_SCALE = 0.8

static func calculate_chain_forces(
		current_pos: Vector3,
		target_pos: Vector3,
		chain_index: int,
		chain_length: int,
		target_distance: float,
		current_tension: float,
		collision_recovery: float = 1.0
	) -> Dictionary:
	
	var chain_factor = chain_index / float(max(chain_length, 1))
	var position_scale = lerp(1.0, MIN_STIFFNESS, chain_factor * chain_factor)
	var length_factor = pow(CHAIN_LENGTH_SCALING, chain_index)
	
	var force_scale = max(MIN_TENSION, 1.0 - (chain_factor * FORCE_FALLOFF_RATE))
	
	var to_target = target_pos - current_pos
	var current_distance = to_target.length()
	
	if current_distance <= 0:
		return {
			"spring_force": Vector3.ZERO,
			"chain_factor": chain_factor,
		}
	
	var stiffness = SPRING_STIFFNESS
	if current_distance > target_distance:
		var stretch = (current_distance - target_distance) / target_distance
		if stretch > SNAP_THRESHOLD:
			stiffness *= 1.0 + (stretch * STIFFNESS_SCALE)
	
	var direction = to_target / current_distance
	var spring_force = direction * (current_distance - target_distance) * stiffness
	
	# DEBUG: Print calculated spring force for diagnostics
	# Temporarily boost stiffness and reduce multipliers for testing
	var debug_stiffness = 120.0 # Try a much higher value for visibility
	stiffness = debug_stiffness
	# Remove or reduce multipliers for easier testing
	# spring_force *= force_scale * position_scale * length_factor * current_tension * collision_recovery
	spring_force *= current_tension # Only tension for now
	print("[ChainPhysics] spring_force=", spring_force, " mag=", spring_force.length(), " tension=", current_tension)
	
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
		base_acceleration: float
	) -> Vector3:
	
	var to_target = target_pos - current_pos
	var distance = to_target.length()
	
	if distance <= 0.001:
		return Vector3.ZERO
	
	var walk_direction = to_target / distance
	var force = walk_direction * base_acceleration * chain_factor
	
	var relative_velocity = target_vel - current_vel
	var approaching_speed = relative_velocity.dot(walk_direction)
	if approaching_speed > 0:
		force *= (1.0 - clamp(approaching_speed / MAX_WALK_SPEED, 0.0, 1.0))
	
	return force

static func calculate_spring_force(from_pos: Vector3, to_pos: Vector3, distance: float, stiffness: float, scale: float, tension: float) -> Vector3:
	if distance <= 0:
		return Vector3.ZERO
	var direction = (to_pos - from_pos) / distance
	return direction * distance * stiffness * scale * tension
