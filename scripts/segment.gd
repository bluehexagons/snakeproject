extends "res://scripts/physics_object.gd"
class_name Segment

const FOLLOW_GAIN = 21.0
const FOLLOW_ACCELERATION = 120.0
const MAX_FOLLOW_SPEED = 18.0
const BODY_MASS = 0.6
const SOLID_MASK = PhysicsConstants.LAYER_BARRIER | PhysicsConstants.LAYER_PHYSICAL | PhysicsConstants.LAYER_PLAYER | PhysicsConstants.LAYER_SEGMENT

var target: Node3D
var growth_timer: float = 0.0
var is_dangerous: bool = false
var path_target: Vector3
var path_velocity: Vector3
var is_detached: bool = false

func _ready() -> void:
	super()
	material_type = PhysicsConstants.MATERIAL_SEGMENT
	path_target = global_position
	freeze = true
	gravity_scale = 0.0
	mass = BODY_MASS
	axis_lock_linear_y = true
	lock_rotation = true
	continuous_cd = true
	linear_damp = 0.0
	physics_material_override.friction = 0.0
	physics_material_override.bounce = 0.0
	apply_color(SegmentConstants.SAFE_COLOR, SegmentConstants.SAFE_COLOR, 0.4)
	init_with_growth(0.0)

func init_with_growth(growth: float) -> void:
	growth_timer = clampf(growth, 0.0, 1.0) * SegmentConstants.GROWTH_DURATION
	_update_growth()

func _physics_process(delta: float) -> void:
	growth_timer = minf(growth_timer + delta, SegmentConstants.GROWTH_DURATION)
	_update_growth()
	if freeze:
		global_position = global_position.move_toward(path_target, MAX_FOLLOW_SPEED * delta)
		if growth_timer >= SegmentConstants.GROWTH_DURATION:
			_enable_collisions_if_clear()
	physics_pos = global_position
	visual_pos = global_position

func _update_growth() -> void:
	current_scale = lerpf(SegmentConstants.INITIAL_SCALE, 1.0, growth_timer / SegmentConstants.GROWTH_DURATION)
	mesh_instance.scale = Vector3.ONE * current_scale

func set_path_target(destination: Vector3, delta: float) -> void:
	path_velocity = (destination - path_target) / delta
	path_target = destination

func _enable_collisions_if_clear() -> void:
	# Growth can start inside the tail, even after a stationary segment has
	# finished growing. Wait for room before introducing its full collider.
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = collision_shape.shape
	query.transform = collision_shape.global_transform
	query.collision_mask = SOLID_MASK
	if get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		_enable_collisions(path_velocity)

func _enable_collisions(velocity: Vector3) -> void:
	collision_layer = PhysicsConstants.LAYER_SEGMENT
	collision_mask = SOLID_MASK
	freeze = false
	linear_velocity = Vector3(velocity.x, 0.0, velocity.z).limit_length(MAX_FOLLOW_SPEED)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if is_detached:
		super._integrate_forces(state)
		return

	if DebugTelemetry.enabled:
		DebugTelemetry.record_contacts(self, state)
	_flash_contacts(state)
	var error = path_target - state.transform.origin
	error.y = 0.0
	# Follow the moving path slot without immediately canceling contact impulses.
	var desired = (path_velocity + error * FOLLOW_GAIN).limit_length(MAX_FOLLOW_SPEED)
	state.linear_velocity = state.linear_velocity.move_toward(desired, FOLLOW_ACCELERATION * state.step)
	if is_dangerous:
		return
	for index in state.get_contact_count():
		var collider = state.get_contact_collider_object(index)
		if collider is Node and collider.is_in_group("barrier"):
			make_dangerous()
			SoundFx.play(SoundFx.Cue.WARNING, 0.52, 0.83)
			break

func release_from_chain() -> void:
	is_detached = true
	target = null
	# A piece still sharing space with the chain cannot safely enter the solver.
	if freeze:
		hide()
		set_physics_process(false)
		return

	axis_lock_linear_y = false
	lock_rotation = false
	gravity_scale = 1.0
	collision_mask |= PhysicsConstants.LAYER_DEFAULT
	physics_material_override.friction = PhysicsConstants.SEGMENT_DYNAMIC_FRICTION

func make_dangerous() -> void:
	is_dangerous = true
	add_to_group("dangerous")
	apply_color(SegmentConstants.DANGER_COLOR, SegmentConstants.DANGER_COLOR, 0.6)

func get_save_data() -> Dictionary:
	var data = super.get_save_data()
	data["growth"] = growth_timer / SegmentConstants.GROWTH_DURATION
	data["is_dangerous"] = is_dangerous
	data["is_solid"] = not freeze
	data["path_target"] = SaveVector.encode(path_target)
	return data

func init_from_save_data(data: Dictionary) -> void:
	global_position = SaveVector.decode(data.get("position"), global_position)
	global_position.y = SegmentConstants.CENTER_HEIGHT
	path_target = SaveVector.decode(data.get("path_target"), global_position)
	path_target.y = SegmentConstants.CENTER_HEIGHT
	init_with_growth(float(data.get("growth", 1.0)))
	if data.get("is_solid", false) and growth_timer >= SegmentConstants.GROWTH_DURATION:
		path_velocity = SaveVector.decode(data.get("velocity"))
		path_velocity.y = 0.0
		_enable_collisions(path_velocity)
	if data.get("is_dangerous", false):
		make_dangerous()
	reset_physics_interpolation()
