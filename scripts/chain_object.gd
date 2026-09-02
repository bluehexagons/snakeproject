extends "res://scripts/physics_object.gd"
class_name ChainObject

var chain_index: int = 0
var chain_length: int = 1
var chain_tension: float = 0.0
var target: Node3D
var collision_recovery_timer: float = 0.0

func _physics_process(delta: float) -> void:
	_handle_chain_physics(delta)
	_update_base_physics(delta)

func _handle_chain_physics(delta: float) -> bool:
	if not is_instance_valid(target):
		return false

	var target_offset = target.global_position - global_position
	var distance = target_offset.length()
	var desired_distance = SegmentConstants.TARGET_DISTANCE

	if distance > desired_distance:
		chain_tension = move_toward(chain_tension, 1.0, ChainPhysics.TENSION_BUILD_RATE * delta)
	else:
		chain_tension *= ChainPhysics.TENSION_DAMPING

	collision_recovery_timer = min(collision_recovery_timer + delta, ChainPhysics.COLLISION_RECOVERY_DELAY)
	return true

func get_chain_data() -> Dictionary:
	if not is_instance_valid(target):
		return {
			"follow_distance": 0.0,
			"follow_direction": Vector3.ZERO,
			"tension": chain_tension
		}

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
	chain_index = max(int(data.get("chain_index", 0)), 0)
	chain_length = max(int(data.get("chain_length", 1)), 1)
	chain_tension = clampf(float(data.get("chain_tension", 0.0)), 0.0, 1.0)
