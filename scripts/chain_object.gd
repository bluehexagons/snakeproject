extends PhysicsObject
class_name ChainObject

@onready var chain_physics = ChainPhysicsManager
var chain_index: int = 0
var chain_length: int = 1
var chain_tension: float = 0.0
var target: Node3D
var last_target_pos: Vector3
var collision_recovery_timer: float = 0.0

func _physics_process(delta: float) -> void:
	if not _handle_chain_physics(delta):
		return

func _handle_chain_physics(delta: float) -> bool:
	if not is_instance_valid(target):
		return false

	var target_offset = target.global_position - global_position
	var distance = target_offset.length()
	var desired_distance = 1.4

	if distance > desired_distance:
		chain_tension = move_toward(chain_tension, 1.0, chain_physics.TENSION_BUILD_RATE * delta)
	else:
		chain_tension *= chain_physics.TENSION_DAMPING

	collision_recovery_timer = min(collision_recovery_timer + delta, chain_physics.COLLISION_RECOVERY_DELAY)
	return true

func _custom_physics_process(_delta: float) -> void:
	pass

func get_chain_data() -> Dictionary:
	var target_offset = target.global_position - global_position
	var distance = target_offset.length()
	
	return {
		"follow_distance": distance,
		"follow_direction": target_offset / distance if distance > 0 else Vector3.ZERO,
		"tension": chain_tension
	}

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
