extends "res://scripts/chain_object.gd"
class_name Segment

@onready var segment_config = SegmentConstants

var growth_timer: float = 0.0
var is_growing: bool = true
var spawn_timer: float = 0.5
var is_dangerous: bool = false
var _chain_data_cache: Dictionary = {}

func _ready():
	super()
	material_type = PhysicsConstants.MATERIAL_SEGMENT
	spawn_timer = segment_config.SPAWN_DURATION
	
	var settings = PhysicsConstants.RIGID_BODY_SETTINGS.segment
	linear_damp = settings.linear_damp
	angular_damp = settings.angular_damp
	collision_layer = PhysicsConstants.LAYER_PHYSICAL
	collision_mask = PhysicsConstants.LAYER_DEFAULT | PhysicsConstants.LAYER_PHYSICAL | PhysicsConstants.LAYER_PLAYER
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = false
	
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = settings.friction
	physics_material_override.bounce = settings.bounce
	physics_material_override.rough = true
	
	apply_physics_scale(segment_config.INITIAL_SCALE, true)
	target_color = segment_config.SAFE_COLOR
	state_color = segment_config.SAFE_COLOR
	apply_color(segment_config.SAFE_COLOR, segment_config.SAFE_COLOR)
	# Growing segments should not affect the chain until they are fully spawned.
	collision_mask = 0
	collision_layer = 0

func init_with_growth(initial_growth: float) -> void:
	initial_growth = clampf(initial_growth, 0.0, 1.0)
	growth_timer = segment_config.GROWTH_DURATION * initial_growth
	var growth = ease(initial_growth, segment_config.GROWTH_CURVE)
	apply_physics_scale(lerp(segment_config.INITIAL_SCALE, 1.0, growth), true)
	is_growing = initial_growth < 1.0
	spawn_timer = segment_config.GROWTH_DURATION if is_growing else 0.0
	_enable_spawn_collisions_if_ready()

func get_save_data() -> Dictionary:
	var base_data = super.get_save_data()
	base_data["growth"] = min(growth_timer / segment_config.GROWTH_DURATION, 1.0)
	base_data["current_scale"] = current_scale
	base_data["is_dangerous"] = is_dangerous
	base_data["current_color"] = {
			"r": current_color.r,
			"g": current_color.g,
			"b": current_color.b,
			"a": current_color.a
	}
	return base_data

func init_from_save_data(data: Dictionary) -> void:
	restore_from_save_data(data)
	load_chain_data(data)
	
	current_scale = float(data.get("current_scale", 1.0))
	var growth = clampf(float(data.get("growth", 1.0)), 0.0, 1.0)
	growth_timer = segment_config.GROWTH_DURATION * growth
	is_growing = growth < 1.0
	
	apply_physics_scale(current_scale, true)
	
	spawn_timer = segment_config.GROWTH_DURATION if is_growing else 0.0
	_enable_spawn_collisions_if_ready()
	
	if data.get("is_dangerous", false):
		is_dangerous = true
		add_to_group("dangerous")
		current_color = segment_config.DANGER_COLOR
		current_material.albedo_color = segment_config.DANGER_COLOR
		current_material.emission = segment_config.DANGER_EMISSION
		current_material.emission_enabled = true
	elif data.get("current_color") is Dictionary:
		var saved_color: Dictionary = data.current_color
		current_color = Color(
			float(saved_color.get("r", current_color.r)),
			float(saved_color.get("g", current_color.g)),
			float(saved_color.get("b", current_color.b)),
			float(saved_color.get("a", current_color.a))
		)
		current_material.albedo_color = current_color
	

func _physics_process(delta):
	if not _handle_chain_physics(delta):
		_update_base_physics(delta)
		return

	_chain_data_cache = _calculate_chain_data(delta)
	_apply_neighbor_separation()

	_update_visuals(delta)
	_update_base_physics(delta)

func _calculate_chain_data(_delta: float) -> Dictionary:
	var target_offset = target.global_position - global_position
	var follow_distance = target_offset.length()
	var follow_direction = target_offset / follow_distance if follow_distance > 0 else Vector3.ZERO
	var target_velocity = _get_target_velocity()
	
	var chain_forces = ChainPhysics.calculate_chain_forces(
		global_position,
		target.global_position,
		chain_index,
		chain_length,
		segment_config.TARGET_DISTANCE,
		chain_tension,
		min(collision_recovery_timer / ChainPhysics.SPRING_FORCE_DELAY, 1.0),
		cached_velocity,
		target_velocity
	)
	
	return {
		"follow_distance": follow_distance,
		"follow_direction": follow_direction,
		"chain_data": chain_forces
	}

func _get_target_velocity() -> Vector3:
	if target is RigidBody3D:
		return target.linear_velocity
	elif target.has_method("get_velocity"):
		return target.get_velocity()
	return Vector3.ZERO

func handle_proximity(other: PhysicsObject, distance: float, direction: Vector3) -> void:
	if distance <= 0:
		return

	var relative_velocity = other.linear_velocity - cached_velocity
	var separation_force = calculate_proximity_force(
		direction,
		distance,
		segment_config.SEGMENT_PROXIMITY_RADIUS,
		segment_config.PROXIMITY_FORCE,
		segment_config.PROXIMITY_FALLOFF,
		relative_velocity,
		segment_config.PROXIMITY_VELOCITY_DAMPING
	)

	apply_force(separation_force)
	if other is PhysicsObject:
		other.apply_force(-separation_force)

func _apply_neighbor_separation() -> void:
	for nearby_body in CollisionHandler.get_nearby_bodies(global_position, segment_config.SEGMENT_PROXIMITY_RADIUS):
		if not nearby_body is Segment or nearby_body == self:
			continue
		# Apply each pair once because handle_proximity applies equal and
		# opposite forces to both segments.
		if get_instance_id() > nearby_body.get_instance_id():
			continue

		var offset = nearby_body.global_position - global_position
		var distance = offset.length()
		if distance > 0.0 and distance < segment_config.SEGMENT_PROXIMITY_RADIUS:
			handle_proximity(nearby_body, distance, offset / distance)

func _process(_delta):
	var fraction = Engine.get_physics_interpolation_fraction()
	visual_pos = physics_pos.lerp(global_position, fraction)
	
	mesh_instance.global_position = visual_pos

func become_dangerous():
	if not is_dangerous:
		is_dangerous = true
		target_color = segment_config.DANGER_COLOR
		current_color = segment_config.DANGER_COLOR
		
		if current_material:
			current_material.albedo_color = segment_config.DANGER_COLOR
			current_material.emission = segment_config.DANGER_EMISSION
			current_material.emission_enabled = true
		
		add_to_group("dangerous")
		current_material.albedo_color = segment_config.DANGER_COLOR
		
		var tween = create_tween()
		tween.tween_property(mesh_instance, "scale", mesh_instance.scale * 1.2, 0.15)
		tween.tween_property(mesh_instance, "scale", mesh_instance.scale, 0.25)
		
		var flash_material = current_material.duplicate()
		mesh_instance.material_override = flash_material
		flash_material.emission_energy_multiplier = 2.0
		
		tween.parallel().tween_property(flash_material, "emission_energy_multiplier", 1.0, 0.4)
		tween.tween_callback(func(): mesh_instance.material_override = null)

func dead_eat() -> float:
	queue_free()
	return 5.0

func _integrate_forces(state: PhysicsDirectBodyState3D):
	if not target:
		super._integrate_forces(state)
		return

	if _chain_data_cache:
		var chain_data = _chain_data_cache
		add_physics_force(chain_data.chain_data.spring_force)
		var target_velocity = _get_target_velocity()
		var walk_force = ChainPhysics.calculate_walk_force(
			global_position,
			target.global_position,
			cached_velocity,
			target_velocity,
			chain_data.chain_data.chain_factor,
			segment_config.FOLLOW_ACCELERATION,
			segment_config.TARGET_DISTANCE
		)
		if walk_force.length_squared() > segment_config.MIN_FORCE_THRESHOLD:
			add_physics_force(walk_force.limit_length(chain_data.chain_data.spring_force.length() * 0.5))

	if is_growing:
		growth_timer += state.step
		var t = growth_timer / segment_config.GROWTH_DURATION
		if t <= 1.0:
			var growth = ease(t, segment_config.GROWTH_CURVE)
			apply_physics_scale(lerp(segment_config.INITIAL_SCALE, 1.0, growth))
		else:
			is_growing = false
			apply_physics_scale(1.0)

	super._integrate_forces(state)

func _update_spawn_timer(delta: float) -> void:
	if spawn_timer > 0:
		spawn_timer = max(0.0, spawn_timer - delta)
		if spawn_timer <= 0:
			_enable_spawn_collisions_if_ready()

func _enable_spawn_collisions_if_ready() -> void:
	if spawn_timer <= 0:
		collision_mask = PhysicsConstants.MASK_PHYSICAL
		collision_layer = PhysicsConstants.LAYER_PHYSICAL

func _update_visuals(delta: float) -> void:
	physics_pos = global_position
	target_color = segment_config.DANGER_COLOR if is_dangerous else segment_config.SAFE_COLOR
	state_color = target_color
	state_emission = segment_config.DANGER_EMISSION if is_dangerous else segment_config.SAFE_COLOR
	state_emission_energy = base_emission_energy

	if current_material:
		if is_dangerous:
			current_color = segment_config.DANGER_COLOR
			apply_color(current_color, state_emission, state_emission_energy)
		else:
			current_color = current_color.lerp(target_color, delta * segment_config.COLOR_CHANGE_SPEED)
			apply_color(current_color, state_emission, state_emission_energy)

func init_with_scale_and_velocity(initial_scale: float, initial_velocity: Vector3) -> void:
	apply_physics_scale(initial_scale, true)
	growth_timer = segment_config.GROWTH_DURATION * ((initial_scale - segment_config.INITIAL_SCALE) / (1.0 - segment_config.INITIAL_SCALE))
	is_growing = initial_scale < 1.0
	
	cached_velocity = initial_velocity
	spawn_timer = segment_config.GROWTH_DURATION if is_growing else 0.0
	_enable_spawn_collisions_if_ready()
	
	chain_tension = 0.0
	collision_recovery_timer = 0.0

func _handle_base_physics(delta: float) -> bool:
	_update_spawn_timer(delta)
	return true

func _handle_chain_physics(delta: float) -> bool:
	if not _handle_base_physics(delta):
		return false
		
	return super._handle_chain_physics(delta)
