extends PhysicsObject
class_name ChainObject  # Keep class_name for base class

# Chain properties
@onready var chain_physics = ChainPhysicsManager
var chain_index: int = 0
var chain_length: int = 1
var chain_tension: float = 0.0
var target: Node3D
var last_target_pos: Vector3
var collision_recovery_timer: float = 0.0

# Remove force-based breaking state
var breaking_timer: float = 0.0  # Keep for animation timing

func _physics_process(delta: float) -> void:
	if not _handle_chain_physics(delta):
		return
	
	# Let derived classes handle their specific physics
	_custom_physics_process(delta)

func _handle_chain_physics(delta: float) -> bool:
	if not is_instance_valid(target):
		return false
	
	# Update chain tension
	chain_tension = move_toward(chain_tension, 1.0, chain_physics.TENSION_BUILD_RATE * delta)
	collision_recovery_timer = min(collision_recovery_timer + delta, chain_physics.COLLISION_RECOVERY_DELAY)
	
	return true

# Virtual method for derived classes
func _custom_physics_process(_delta: float) -> void:
	pass

func get_chain_data() -> Dictionary:
	var target_offset = target.global_position - global_position
	var follow_distance = target_offset.length()
	
	return {
		"target_offset": target_offset,
		"follow_distance": follow_distance,
		"follow_direction": target_offset / follow_distance if follow_distance > 0 else Vector3.ZERO,
		"tension": chain_tension,
		"recovery": min(collision_recovery_timer / chain_physics.COLLISION_RECOVERY_DELAY, 1.0)
	}

func _handle_chain_break() -> void:
	# Virtual method for derived classes
	pass

func get_save_data() -> Dictionary:
	var data = super.get_save_data()
	data["chain_index"] = chain_index
	data["chain_length"] = chain_length
	data["chain_tension"] = chain_tension
	return data

func load_chain_data(data: Dictionary) -> void:
	chain_index = data.get("chain_index", 0)
	chain_length = data.get("chain_length", 1)
	chain_tension = data.get("chain_tension", 0.0)
