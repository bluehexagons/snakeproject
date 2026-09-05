extends "res://scripts/physics_object.gd"
class_name Segment

# Body pieces are path followers. They never participate in the rigid-body
# solver, so growth cannot fall through the floor or kick the head around.
var target: Node3D
var chain_index: int = 0
var chain_length: int = 1
var growth_timer: float = 0.0
var is_growing: bool = true
var is_dangerous: bool = false

func _ready() -> void:
	super()
	freeze = true
	gravity_scale = 0.0
	collision_layer = 0
	collision_mask = 0
	contact_monitor = false
	apply_color(SegmentConstants.SAFE_COLOR, SegmentConstants.SAFE_COLOR, 0.4)
	init_with_growth(0.0)

func init_with_growth(growth: float) -> void:
	growth_timer = clampf(growth, 0.0, 1.0) * SegmentConstants.GROWTH_DURATION
	is_growing = growth_timer < SegmentConstants.GROWTH_DURATION
	_update_growth()

func _physics_process(delta: float) -> void:
	growth_timer = minf(growth_timer + delta, SegmentConstants.GROWTH_DURATION)
	is_growing = growth_timer < SegmentConstants.GROWTH_DURATION
	_update_growth()

func _update_growth() -> void:
	current_scale = lerpf(SegmentConstants.INITIAL_SCALE, 1.0, growth_timer / SegmentConstants.GROWTH_DURATION)
	mesh_instance.scale = Vector3.ONE * current_scale

func follow_path(destination: Vector3) -> void:
	global_position = destination
	physics_pos = destination
	visual_pos = destination

func _integrate_forces(_state: PhysicsDirectBodyState3D) -> void:
	pass

func get_save_data() -> Dictionary:
	var data = super.get_save_data()
	data["growth"] = growth_timer / SegmentConstants.GROWTH_DURATION
	return data

func init_from_save_data(data: Dictionary) -> void:
	global_position = _vector_from_data(data.get("position"), global_position)
	global_position.y = 0.35
	init_with_growth(float(data.get("growth", 1.0)))
	reset_physics_interpolation()
