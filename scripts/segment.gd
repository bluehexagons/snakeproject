extends ChainObject
class_name Segment

# Remove @onready var and use direct singleton reference
@onready var segment_config = SegmentConstants   # Segment config singleton

var smoothed_velocity: Vector3
var growth_timer: float = 0.0
var is_growing: bool = true
var spawn_timer: float = 0.5  # Use hard-coded initial value first
var is_dangerous: bool = false
var recovery_timer: float = 0.0
var is_recovering: bool = false
var last_collision_normal: Vector3 = Vector3.ZERO
var has_collision: bool = false
var current_pull_force: float = 0.0
var current_pull_multiplier: float = 0.0

func _ready():
	super()
	material_type = PhysicsConstants.MATERIAL_SEGMENT
	spawn_timer = segment_config.SPAWN_DURATION
	
	# Configure RigidBody3D properties
	var settings = PhysicsConstants.RIGID_BODY_SETTINGS.segment
	linear_damp = settings.linear_damp
	angular_damp = settings.angular_damp
	collision_layer = PhysicsConstants.LAYER_PHYSICAL
	collision_mask = PhysicsConstants.LAYER_DEFAULT | PhysicsConstants.LAYER_PHYSICAL | PhysicsConstants.LAYER_PLAYER
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = true
	
	# Set up physics material
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = settings.friction
	physics_material_override.bounce = settings.bounce
	physics_material_override.rough = true
	
	# Initialize scale and colors
	apply_physics_scale(segment_config.INITIAL_SCALE, true)
	apply_color(segment_config.SAFE_COLOR, Color(0.2, 0.6, 0.3, 1.0))

func init_with_growth(initial_growth: float):
	growth_timer = segment_config.GROWTH_DURATION * initial_growth
	var growth = ease(initial_growth, segment_config.GROWTH_CURVE)
	apply_physics_scale(lerp(segment_config.INITIAL_SCALE, 1.0, growth), true)
	is_growing = initial_growth < 1.0
	# Reset spawn timer to avoid collision issues
	spawn_timer = segment_config.GROWTH_DURATION if is_growing else 0.0
	# Initialize chain properties
	chain_index = 0
	chain_length = 1

func get_save_data() -> Dictionary:
	var base_data = super.get_save_data()
	# Add segment-specific data
	base_data["smoothed_velocity"] = {
			"x": smoothed_velocity.x,
			"y": smoothed_velocity.y,
			"z": smoothed_velocity.z
	}
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

func init_from_save_data(data: Dictionary):
	if data.has("velocity"):
		cached_velocity = Vector3(data.velocity.x, data.velocity.y, data.velocity.z)
	if data.has("smoothed_velocity"):
		smoothed_velocity = Vector3(data.smoothed_velocity.x, data.smoothed_velocity.y, data.smoothed_velocity.z)
	
	# Initialize scale and growth first
	current_scale = data.get("current_scale", 1.0)  # Default to full size if not specified
	var growth = data.get("growth", 1.0)
	growth_timer = segment_config.GROWTH_DURATION * growth
	is_growing = growth < 1.0
	
	# Apply scale immediately
	apply_physics_scale(current_scale, true)
	
	# Set spawn timer based on growth
	spawn_timer = segment_config.GROWTH_DURATION if is_growing else 0.0
	
	# Then handle danger state to prevent scale reset
	if data.has("is_dangerous") and data.is_dangerous:
		is_dangerous = true  # Set flag first
		add_to_group("dangerous")
		current_color = segment_config.DANGER_COLOR
		current_material.albedo_color = segment_config.DANGER_COLOR
		current_material.emission = segment_config.DANGER_EMISSION
		current_material.emission_enabled = true
	elif data.has("current_color"):
		current_color = Color(
			data.current_color.r,
			data.current_color.g,
			data.current_color.b,
			data.current_color.a
		)
		current_material.albedo_color = current_color
	
	growth_timer = segment_config.GROWTH_DURATION  # Mark growth as complete

# Clean up physics process to be more focused
func _physics_process(delta):
	if not _handle_base_physics(delta) or not is_instance_valid(target):
		return
	
	var chain_data = _calculate_chain_data(delta)
	if chain_data.follow_distance > 0:
		if _should_break_chain(chain_data.follow_distance, chain_data.adjusted_distance):
			break_chain()
			return
		
		if not is_recovering:
			_apply_chain_forces(chain_data, delta)
	
	_handle_collisions(delta)
	_update_visuals(delta)

# New helper to consolidate chain calculations
func _calculate_chain_data(delta: float) -> Dictionary:
	var target_offset = target.global_position - global_position
	var follow_distance = target_offset.length()
	var follow_direction = target_offset / follow_distance if follow_distance > 0 else Vector3.ZERO
	
	chain_tension = move_toward(chain_tension, 1.0, chain_physics.TENSION_BUILD_RATE * delta)
	
	var chain_forces = chain_physics.calculate_chain_forces(
		global_position,
		target.global_position,
		chain_index,
		chain_length,
		segment_config.TARGET_DISTANCE,
		chain_tension,
		min(collision_recovery_timer / segment_config.SPRING_FORCE_DELAY, 1.0)
	)
	
	# Check for break condition from chain forces
	if chain_forces.should_break:
		break_chain()
	
	return {
		"follow_distance": follow_distance,
		"follow_direction": follow_direction,
		"chain_data": chain_forces,
		"adjusted_distance": _calculate_adjusted_distance()
	}

# Consolidated spring force calculation
func _calculate_spring_force(target_pos: Vector3, distance: float, factors: Dictionary) -> Vector3:
	var spring_scale = lerp(0.3, 1.0, min(collision_recovery_timer / segment_config.SPRING_FORCE_DELAY, 1.0))
	
	# Calculate scaled stiffness based on stretch
	var stiffness = segment_config.SPRING_STIFFNESS
	if distance > segment_config.TARGET_DISTANCE:
		var stretch = (distance - segment_config.TARGET_DISTANCE) / segment_config.TARGET_DISTANCE
		if stretch > segment_config.SNAP_THRESHOLD:
			stiffness *= 1.0 + (stretch * segment_config.STRETCH_STIFFNESS_SCALE)
	
	# Apply chain-based scaling
	var chain_scale = factors.force_scale * spring_scale * spring_stiffness_multiplier
	
	return ChainPhysicsManager.calculate_spring_force(
		global_position,
		target_pos,
		distance,
		stiffness,
		chain_scale,
		chain_tension
	) * 0.8

# Combined implementation of chain forces
func _apply_chain_forces(chain_data: Dictionary, delta: float) -> void:
	var target_velocity = _get_target_velocity()
	
	# Calculate all forces
	var walk_force = ChainPhysics.calculate_walk_force(
		global_position,
		target.global_position,
		cached_velocity,
		target_velocity,
		chain_data.chain_data.chain_factor,
		segment_config.FOLLOW_ACCELERATION
	)
	
	var follow_force = _calculate_follow_force(
		chain_data.follow_distance,
		chain_data.follow_direction,
		chain_data.chain_data.chain_factor
	)
	
	# Apply all forces once
	add_physics_force(chain_data.chain_data.spring_force)
	if follow_force.length_squared() > segment_config.MIN_FORCE_THRESHOLD:
		add_physics_force(follow_force)
	add_physics_force(walk_force)
	
	_handle_proximity_and_obstacles(delta)
	_apply_drag()

# Consolidate following force calculation
func _calculate_follow_force(follow_distance: float, follow_direction: Vector3, chain_factor: float) -> Vector3:
	if not target:
		return Vector3.ZERO
	
	var needs_movement = follow_distance > segment_config.IDEAL_FOLLOW_DISTANCE * 1.1 or follow_distance < segment_config.TOO_CLOSE_DISTANCE
	if not needs_movement:
		return -cached_velocity * (segment_config.PASSIVE_DAMPING - 1.0) * get_effective_mass()
	
	var follow_force = Vector3.ZERO
	if follow_distance < segment_config.TOO_CLOSE_DISTANCE:
		follow_force = -follow_direction * segment_config.BACKING_FORCE_SCALE * chain_factor
	else:
		var target_speed = (target.global_position - last_target_pos).length() / get_physics_process_delta_time()
		var force_scale = 0.5 if target_speed > segment_config.MOVEMENT_THRESHOLD else 0.2
		follow_force = follow_direction * segment_config.FOLLOW_ACCELERATION * force_scale * chain_factor
	
	if target is Player:
		follow_force *= segment_config.PLAYER_FOLLOW_MULTIPLIER
		if cached_velocity.length() < target.cached_velocity.length():
			follow_force *= 1.5
	
	return follow_force * get_effective_mass()

func break_chain() -> void:
	if not is_recovering and target:
		become_dangerous()
		if target is Segment:
			target.become_dangerous()
		
		# Calculate break direction and forces
		var break_dir = (target.global_position - global_position).normalized()
		var random_spin = Vector3(
			randf_range(-1, 1),
			randf_range(-1, 1),
			randf_range(-1, 1)
		).normalized() * segment_config.BROKEN_ANGULAR_IMPULSE
		
		# Apply break forces
		apply_impulse(-break_dir * segment_config.POP_FORCE_OPPOSITE * mass)
		apply_impulse(random_spin * mass)
		
		if target is PhysicsObject:
			target.apply_impulse(break_dir * segment_config.POP_FORCE_OPPOSITE * target.mass)
			target.apply_impulse(-random_spin * target.mass)
			
			# Inherit some velocity
			cached_velocity = cached_velocity.lerp(target.cached_velocity, segment_config.BROKEN_VELOCITY_INHERIT)
		
		target = null
		is_recovering = true
		recovery_timer = 0.0

# Split out helper functions
func _update_friction():
	var is_player_connected = _check_player_connection()
	static_friction = PhysicsConstants.SEGMENT_STATIC_FRICTION * (segment_config.CONNECTED_FRICTION_MULTIPLIER if is_player_connected else 1.0)
	rolling_friction = PhysicsConstants.SEGMENT_ROLLING_FRICTION * (segment_config.CONNECTED_ROLLING_MULTIPLIER if is_player_connected else 1.0)

func _check_velocity_limits():
	if cached_velocity.length() > PhysicsConstants.SEGMENT_MAX_SPEED * 2.0:
		cached_velocity = cached_velocity.normalized() * PhysicsConstants.SEGMENT_MAX_SPEED

func _handle_recovery(delta: float) -> bool:
	if is_recovering:
		recovery_timer = min(recovery_timer + delta, segment_config.RECOVERY_DURATION)
		is_recovering = recovery_timer < segment_config.RECOVERY_DURATION
		return true
	return false

func _handle_growth(delta: float) -> bool:
	growth_timer += delta
	var t = growth_timer / segment_config.GROWTH_DURATION
	if t <= 1.0:
		var growth = ease(t, segment_config.GROWTH_CURVE)
		var growth_scale = lerp(segment_config.INITIAL_SCALE, 1.0, growth)
		apply_physics_scale(growth_scale)
		spring_stiffness_multiplier = lerp(segment_config.INITIAL_SPRING_REDUCTION, 1.0, growth)
		return true
	
	is_growing = false
	apply_physics_scale(1.0)
	spring_stiffness_multiplier = 1.0
	return false

func _calculate_adjusted_distance() -> float:
	if not is_instance_valid(target):
		return 0.0

	return target_distance * (current_scale + (target.get("current_scale") if target.has_method("get_scale") else 1.0)) * 0.5

func _should_break_chain(current_distance: float, adjusted_distance: float) -> bool:
	var hard_max_distance = adjusted_distance * segment_config.HARD_MAX_STRETCH
	return current_distance > hard_max_distance * segment_config.BREAK_THRESHOLD

func _get_target_velocity() -> Vector3:
	if target is RigidBody3D:
		return target.linear_velocity
	elif target.has_method("get_velocity"):
		return target.get_velocity()
	return Vector3.ZERO

func _apply_distance_constraint(target_body: Node3D, max_distance: float, delta: float) -> void:
	var to_target = target_body.global_position - global_position
	var current_distance = to_target.length()
	
	if current_distance > 0:
		var correction = (current_distance - max_distance) * 0.3  # Even softer correction
		var correction_dir = to_target / current_distance
		
		if target_body is PhysicsObject:
			var total_mass = mass + target_body.mass
			var mass_ratio_a = mass / total_mass
			var mass_ratio_b = target_body.mass / total_mass
			
			 # Smoother velocity-based correction
			var correction_vel = correction_dir * correction / delta
			cached_velocity = cached_velocity.lerp(cached_velocity + correction_vel * mass_ratio_b, 0.5)
			target_body.cached_velocity = target_body.cached_velocity.lerp(
				target_body.cached_velocity - correction_vel * mass_ratio_a, 0.5)

# Rename parameter to avoid shadowing
func _apply_pull_forces(target_body: Node3D, current_distance: float, direction: Vector3) -> void:
	if current_distance > segment_config.PULL_START_DISTANCE:
		var pull_factor = clamp(
			(current_distance - segment_config.PULL_START_DISTANCE) / (segment_config.PULL_MAX_DISTANCE - segment_config.PULL_START_DISTANCE),
			0.0, 1.0
		)
		
		 # Build up pull force gradually
		current_pull_multiplier = move_toward(
			current_pull_multiplier,
			1.0,
			segment_config.PULL_ACCELERATION_RATE * get_physics_process_delta_time()
		)
		
		# Calculate chain-based pull force
		var chain_pull = segment_config.PULL_FORCE * pow(segment_config.CHAIN_PULL_DECAY, chain_index * 0.7)
		chain_pull = max(chain_pull * (1.0 + cached_velocity.length() * 0.1), segment_config.MIN_PULL_FORCE)
		
		# Only pull if beyond ideal distance
		if current_distance > segment_config.IDEAL_FOLLOW_DISTANCE:
			var pull_force = direction * chain_pull * pull_factor * current_pull_multiplier
			
			# Reduce pull force significantly when target is player
			if target_body is Player:
				pull_force *= segment_config.PULL_FORCE_PLAYER_REDUCTION
			
			# Limit pull velocity
			var current_speed = cached_velocity.length()
			if current_speed > segment_config.MAX_PULL_VELOCITY:
				cached_velocity = cached_velocity.normalized() * segment_config.MAX_PULL_VELOCITY
				pull_force *= segment_config.PULL_VELOCITY_REDUCTION
			
			apply_force(pull_force)
			
			if target_body is PhysicsObject:
				# Apply reduced force to target and store for collision handling
				var resistance_scale = clamp(cached_velocity.length() / 5.0, 0.3, 1.0)  # Reduced maximum resistance
				target_body.apply_force(-pull_force * resistance_scale)
				current_pull_force = chain_pull * pull_factor
		else:
			current_pull_multiplier = 0.0  # Reset pull force when in good position

func handle_proximity(other: PhysicsObject, distance: float, direction: Vector3) -> void:
	if distance <= 0:
		return
		
	var force_scale = (1.0 - distance / segment_config.SEGMENT_PROXIMITY_RADIUS)
	var repulsion = -direction * segment_config.PROXIMITY_FORCE * pow(force_scale, segment_config.PROXIMITY_FALLOFF)
	
	# Fix velocity reference
	var relative_velocity = other.linear_velocity - cached_velocity
	var velocity_correction = relative_velocity * segment_config.PROXIMITY_VELOCITY_MATCH
	
	apply_force(repulsion - velocity_correction)
	if other is PhysicsObject:
		other.apply_force(-repulsion + velocity_correction)

func handle_collision(other: PhysicsObject, normal: Vector3, relative_velocity: Vector3) -> void:
	if other.material_type == PhysicsConstants.MATERIAL_ROCK:
		var chain_factor = 1.0 - (float(chain_index) / max(chain_length, 1))
		
		# Calculate push force with better scaling
		var push_force = segment_config.ROCK_PUSH_SCALE
		if current_pull_force > 0:
			push_force += chain_factor * segment_config.CHAIN_FORCE_SCALE
			
			# Build up force over time
			collision_force_multiplier = lerp(
				collision_force_multiplier,
				push_force,
				segment_config.PUSH_FORCE_BUILDUP
			)
			
			# Transfer momentum more gradually
			var transfer_velocity = -normal * current_pull_force * 0.3
			other.cached_velocity = other.cached_velocity.lerp(transfer_velocity, chain_factor * 0.2)
	
	super.handle_collision(other, normal, relative_velocity)
	collision_force_multiplier = move_toward(collision_force_multiplier, 1.0, 0.1)

func _process(_delta):
	# Interpolate visual position between physics updates
	var fraction = Engine.get_physics_interpolation_fraction()
	visual_pos = physics_pos.lerp(global_position, fraction)
	
	# Update visual representation
	mesh_instance.global_position = visual_pos

func become_dangerous():
	if not is_dangerous:  # Only change state if not already dangerous
		is_dangerous = true
		target_color = segment_config.DANGER_COLOR
		current_color = segment_config.DANGER_COLOR  # Set current color too for immediate effect
		
		if current_material:
			current_material.albedo_color = segment_config.DANGER_COLOR
			current_material.emission = segment_config.DANGER_EMISSION
			current_material.emission_enabled = true
		
		add_to_group("dangerous")
		# Ensure material color updates immediately
		current_material.albedo_color = segment_config.DANGER_COLOR
		
		 # Reduced visual feedback
		var tween = create_tween()
		tween.tween_property(mesh_instance, "scale", mesh_instance.scale * 1.2, 0.15)  # Reduced scale pop
		tween.tween_property(mesh_instance, "scale", mesh_instance.scale, 0.25)
		
		# Softer emission pulse
		var flash_material = current_material.duplicate()
		mesh_instance.material_override = flash_material
		flash_material.emission_energy_multiplier = 2.0  # Reduced from 4.0
		
		tween.parallel().tween_property(flash_material, "emission_energy_multiplier", 1.0, 0.4)  # Longer fade
		tween.tween_callback(func(): mesh_instance.material_override = null)

func dead_eat() -> float:
	queue_free()
	return 5.0

func _integrate_forces(state: PhysicsDirectBodyState3D):
	if is_recovering or not target:
		return
		
	if is_growing:
		growth_timer += get_physics_process_delta_time()
		var t = growth_timer / segment_config.GROWTH_DURATION
		if t <= 1.0:
			var growth = ease(t, segment_config.GROWTH_CURVE)
			apply_physics_scale(lerp(segment_config.INITIAL_SCALE, 1.0, growth))
			spring_stiffness_multiplier = lerp(segment_config.INITIAL_SPRING_REDUCTION, 1.0, growth)
		else:
			is_growing = false
			apply_physics_scale(1.0)
			spring_stiffness_multiplier = 1.0
	
	# Just update cached velocity
	cached_velocity = state.linear_velocity

func _check_player_connection() -> bool:
	var current_target = target
	var depth = 0  # Prevent infinite loops
	while current_target and depth < 100:
		if current_target is Player:
			return true
		if current_target is Segment:
			current_target = current_target.target
		else:
			break
		depth += 1
	return false

func _update_spawn_timer(delta: float) -> void:
	if spawn_timer > 0:
		spawn_timer = max(0.0, spawn_timer - delta)
		if spawn_timer <= 0:
			collision_mask = segment_config.NORMAL_COLLISION_MASK
			collision_layer = PhysicsConstants.LAYER_PHYSICAL

func _apply_drag() -> void:
	add_physics_force(-cached_velocity * (1.0 - segment_config.FOLLOW_DRAG) * get_effective_mass())

func _handle_collisions(delta: float) -> void:
	var collision = move_and_collide(cached_velocity * delta)
	if not collision:
		return
		
	var collider = collision.get_collider()
	if not collider is PhysicsObject:
		return
		
	var normal = collision.get_normal()
	var relative_velocity = cached_velocity - collider.cached_velocity
	var normal_vel = normal * relative_velocity.dot(normal)
	var tangent_vel = relative_velocity - normal_vel
	
	var restitution = segment_config.COLLISION_BOUNCE_DAMPING
	var tangent_retain = segment_config.COLLISION_TANGENT_RETAIN
	
	if collider is Segment:
		restitution = segment_config.SEGMENT_COLLISION_RESTITUTION
		tangent_retain = 0.9
		
		var separation = normal * segment_config.SEGMENT_REPULSION_FORCE * delta
		apply_impulse(separation)
		collider.apply_impulse(-separation)
		
		cached_velocity = cached_velocity.lerp(collider.cached_velocity, segment_config.COLLISION_VELOCITY_MATCH)
	elif collider.material_type == PhysicsConstants.MATERIAL_ROCK:
		restitution *= segment_config.ROCK_COLLISION_EXTRA_DAMPING
	
	cached_velocity = (tangent_vel * tangent_retain - normal_vel * restitution) * segment_config.COLLISION_FORCE_SCALE
	apply_impulse(normal * segment_config.COLLISION_SEPARATION_FORCE * mass)
	
	handle_impact(relative_velocity.length() * collision_force_multiplier)
	
	has_collision = true
	last_collision_normal = normal
	collision_recovery_timer = 0.0

func _update_visuals(delta: float) -> void:
	# Store physics state
	physics_pos = global_position

	# Update color
	if current_material:
		if is_dangerous:
			current_color = segment_config.DANGER_COLOR
			apply_color(current_color, segment_config.DANGER_EMISSION)
		else:
			current_color = current_color.lerp(target_color, delta * segment_config.COLOR_CHANGE_SPEED)
			apply_color(current_color, Color(0.2, 0.6, 0.3, 1.0))
	
	if is_dangerous:
		target_color = segment_config.DANGER_COLOR
		base_emission = segment_config.DANGER_EMISSION
	else:
		target_color = segment_config.SAFE_COLOR
		base_emission = Color(0.2, 0.6, 0.3, 1.0)

func _handle_proximity_and_obstacles(_delta: float) -> void:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position,
		target.global_position,
		collision_mask
	)
	var result = space_state.intersect_ray(query)
	
	if result and result.collider is PhysicsObject:
		var obstacle = result.collider as PhysicsObject
		if obstacle.is_in_group("rock"):
			var push_dir = (target.global_position - global_position).normalized()
			var push_force = push_dir * segment_config.ROCK_PUSH_FORCE * chain_tension
			
			obstacle.apply_force(push_force)
			apply_force(-push_force * 0.3)

func init_with_scale_and_velocity(initial_scale: float, initial_velocity: Vector3) -> void:
	# Initialize scale
	apply_physics_scale(initial_scale, true)
	spring_stiffness_multiplier = lerp(segment_config.INITIAL_SPRING_REDUCTION, 1.0, initial_scale)
	growth_timer = segment_config.GROWTH_DURATION * ((initial_scale - segment_config.INITIAL_SCALE) / (1.0 - segment_config.INITIAL_SCALE))
	is_growing = initial_scale < 1.0
	
	# Initialize physics
	cached_velocity = initial_velocity
	smoothed_velocity = initial_velocity
	spawn_timer = segment_config.GROWTH_DURATION if is_growing else 0.0
	
	# Set initial chain properties
	chain_tension = 0.0
	current_pull_multiplier = 0.0
	
	# Set initial collision state
	collision_recovery_timer = 0.0
	has_collision = false
	is_recovering = false

# Add the missing function
func _handle_base_physics(delta: float) -> bool:
	_update_friction()
	_check_velocity_limits()
	
	# Handle early-out conditions
	if _handle_recovery(delta):
		return false
	
	if is_growing:
		if _handle_growth(delta):
			return false
	
	_update_spawn_timer(delta)
	return true

func _handle_chain_physics(delta: float) -> bool:
	if not _handle_base_physics(delta):
		return false
		
	return super._handle_chain_physics(delta)
