extends Node
class_name ChainPhysics

static var singleton: Node

func _init():
	singleton = self

func _ready():
	process_mode = Node.PROCESS_MODE_DISABLED  # This is a data-only node

# Chain base properties
const TENSION_BUILD_RATE = 0.8
const MIN_TENSION = 0.2
const IDEAL_FOLLOW_DISTANCE = 1.2
const TOO_CLOSE_DISTANCE = 1.0
const COLLISION_RECOVERY_DELAY = 0.1

# Chain breaking - simplified to use only stretch
const MAX_STRETCH = 2.5  # Maximum stretch ratio before breaking
const STRETCH_THRESHOLD = 0.99  # Break at 99% of max stretch

# Chain physics
const CHAIN_STIFFNESS = 40.0
const STIFFNESS_SCALE = 10.4
const SNAP_THRESHOLD = 0.1

# Force scaling
const MIN_STIFFNESS = 0.15
const CHAIN_LENGTH_SCALING = 0.95
const MAX_FORCE_SCALE = 2.0
const FORCE_FALLOFF_RATE = 1.2
const SAFE_FORCE_THRESHOLD = 0.1

# Movement constants
const MAX_WALK_SPEED = 10.0
const WALK_ACCELERATION = 40.0
const WALK_FORCE_SCALE = 0.8
const PULL_FORCE_SCALE = 1.2

# Chain behavior
const CHAIN_DRAG_REDUCTION = 0.7
const CHAIN_MIN_SPEED = 1.0
const CHAIN_TENSION_DAMPING = 0.85

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
	
	# Calculate force scale based on chain position
	var force_scale = max(MIN_TENSION, 1.0 - (chain_factor * FORCE_FALLOFF_RATE))
	
	# Calculate base spring force
	var to_target = target_pos - current_pos
	var current_distance = to_target.length()
	
	if current_distance <= 0:
		return {
			"spring_force": Vector3.ZERO,
			"chain_factor": chain_factor,
			"should_break": false
		}
	
	# Simplified break check based only on stretch
	var stretch_ratio = current_distance / target_distance
	var should_break = stretch_ratio > MAX_STRETCH * STRETCH_THRESHOLD
	
	# Calculate stiffness based on stretch
	var stiffness = CHAIN_STIFFNESS
	if current_distance > target_distance:
		var stretch = (current_distance - target_distance) / target_distance
		if stretch > SNAP_THRESHOLD:
			stiffness *= 1.0 + (stretch * STIFFNESS_SCALE)
	
	# Calculate final spring force
	var direction = to_target / current_distance
	var spring_force = direction * (current_distance - target_distance) * stiffness
	spring_force *= force_scale * position_scale * length_factor * current_tension * collision_recovery
	
	return {
		"spring_force": spring_force,
		"chain_factor": chain_factor,
		"should_break": should_break,
		"current_distance": current_distance,
		"force_scale": force_scale,
		"length_factor": length_factor
	}

# Walking force calculation for chain movement
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
	
	# Reduce force if already moving toward target
	var relative_velocity = target_vel - current_vel
	var approaching_speed = relative_velocity.dot(walk_direction)
	if approaching_speed > 0:
		force *= (1.0 - clamp(approaching_speed / MAX_WALK_SPEED, 0.0, 1.0))
	
	return force
