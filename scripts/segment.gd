extends PhysicsObject

class_name Segment

const SPRING_STIFFNESS = 730.0
const SPRING_DAMPING = 40.0
const PLAYER_TARGET_DISTANCE = 0.9
const TARGET_DISTANCE = 0.8
const GROWTH_DURATION = 0.33
const INITIAL_SCALE = 0.2
const FOLLOW_STRENGTH = 0.8  # How strongly to match target's velocity
const MIN_FOLLOW_DISTANCE = 0.1  # Distance at which to start matching velocity
const INITIAL_SPRING_REDUCTION = 0.3  # Reduce spring force when first spawned
const SAFE_COLOR = Color(0.3, 0.8, 1.0, 0.9)
const DANGER_COLOR = Color(0.9, 0.2, 0.2, 0.9)
const DANGER_EMISSION = Color(0.8, 0.1, 0.1, 1.0)
const COLOR_CHANGE_SPEED = 5.0
const PULL_START_DISTANCE = 1.1  # Distance at which pull force starts
const PULL_MAX_DISTANCE = 3.0    # Distance at which pull force peaks
const PULL_FORCE = 300.0        # Reduced base pull force
const PULL_VELOCITY_MATCH = 0.9  # How strongly to match target's velocity when pulling
const COLLISION_BREAK_FORCE = 1500.0  # Force required during collision to break
const RECOVERY_DURATION = 1.0         # Slightly faster recovery
const RECOVERY_EASE_POWER = 1.5       # How quickly targeting recovers (higher = more sudden)
const PLAYER_PULL_REDUCTION = 0.25  # Reduce pull force when targeting player
const CLUSTER_FORCE_REDUCTION = 0.7  # Reduce forces when in tight clusters
const MAX_NEARBY_SEGMENTS = 5  # Threshold for considering an area "crowded"

var target: Node3D
var smoothed_velocity: Vector3
var growth_timer: float = 0.0
var is_growing: bool = true
var current_scale: float = INITIAL_SCALE
var spawn_timer: float = 0.5  # Time to use reduced spring force
var is_dangerous: bool = false
var recovery_timer: float = 0.0
var is_recovering: bool = false
var last_force: float = 0.0
var last_collision_normal: Vector3 = Vector3.ZERO
var has_collision: bool = false

func _ready():
	super()
	mass = 1.0
	drag_coefficient = PhysicsConstants.SEGMENT_DRAG
	max_speed = PhysicsConstants.SEGMENT_MAX_SPEED
	static_friction = PhysicsConstants.SEGMENT_STATIC_FRICTION
	dynamic_friction = PhysicsConstants.SEGMENT_DYNAMIC_FRICTION
	rolling_friction = PhysicsConstants.SEGMENT_ROLLING_FRICTION
	# Set initial scale and positions
	current_scale = INITIAL_SCALE
	update_scale(current_scale)
	
	# Set initial colors
	current_color = SAFE_COLOR
	target_color = SAFE_COLOR
	base_emission = Color(0.2, 0.6, 0.3, 1.0)
	apply_color(current_color, Color(0.2, 0.6, 0.3, 1.0))

func update_scale(new_scale: float):
	mesh_instance.scale = Vector3.ONE * new_scale

func init_with_growth(initial_growth: float):
	growth_timer = GROWTH_DURATION * initial_growth
	current_scale = lerp(INITIAL_SCALE, 1.0, ease(initial_growth, 0.7))
	is_growing = initial_growth < 1.0
	update_scale(current_scale)

func get_save_data() -> Dictionary:
	var base_data = super.get_save_data()
	# Add segment-specific data
	base_data["smoothed_velocity"] = {
			"x": smoothed_velocity.x,
			"y": smoothed_velocity.y,
			"z": smoothed_velocity.z
	}
	base_data["growth"] = min(growth_timer / GROWTH_DURATION, 1.0)
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
		velocity = Vector3(data.velocity.x, data.velocity.y, data.velocity.z)
	if data.has("smoothed_velocity"):
		smoothed_velocity = Vector3(data.smoothed_velocity.x, data.smoothed_velocity.y, data.smoothed_velocity.z)
	
	# Initialize scale and growth first
	current_scale = data.get("current_scale", 1.0)  # Default to full size if not specified
	update_scale(current_scale)

	growth_timer = GROWTH_DURATION * data.get("growth")
	
	# Then handle danger state to prevent scale reset
	if data.has("is_dangerous") and data.is_dangerous:
		is_dangerous = true  # Set flag first
		add_to_group("dangerous")
		current_color = DANGER_COLOR
		current_material.albedo_color = DANGER_COLOR
		current_material.emission = DANGER_EMISSION
		current_material.emission_enabled = true
	elif data.has("current_color"):
		current_color = Color(
			data.current_color.r,
			data.current_color.g,
			data.current_color.b,
			data.current_color.a
		)
		current_material.albedo_color = current_color
	
	growth_timer = GROWTH_DURATION  # Mark growth as complete

func _physics_process(delta):
	# Add early exit for extreme velocities
	if velocity.length() > PhysicsConstants.SEGMENT_MAX_SPEED * 2.0:
		velocity = velocity.normalized() * PhysicsConstants.SEGMENT_MAX_SPEED

	if is_growing:
		growth_timer += delta
		var t = growth_timer / GROWTH_DURATION
		if t <= 1.0:
			var growth = ease(t, 0.7)
			current_scale = lerp(INITIAL_SCALE, 1.0, growth)
			update_scale(current_scale)
		else:
			is_growing = false
			current_scale = 1.0
			update_scale(current_scale)
	
	# Update spawn timer
	spawn_timer = max(0.0, spawn_timer - delta)
	
	if is_recovering:
		recovery_timer = min(recovery_timer + delta, RECOVERY_DURATION)
		if recovery_timer >= RECOVERY_DURATION:
			is_recovering = false
	
	# Calculate spring force with spawn reduction
	var spring_multiplier = lerp(INITIAL_SPRING_REDUCTION, 1.0, 1.0 - (spawn_timer / 0.5))
	var current_stiffness = SPRING_STIFFNESS * spring_multiplier
	var spring_force = Vector3.ZERO
	var damping_force = Vector3.ZERO
	var collision_handler = get_node("/root/CollisionHandler")

	if is_instance_valid(target):
		# Calculate target distance based on current scales
		var target_distance = TARGET_DISTANCE if target is Segment else PLAYER_TARGET_DISTANCE
		var adjusted_distance = target_distance * (current_scale + (target.get("current_scale") if target.has_method("get_scale") else 1.0)) * 0.5
		
		var to_target = target.global_position - global_position
		var current_distance = to_target.length()
		
		if current_distance > 0:
			# Calculate forces but only apply if not in recovery or gradually during recovery
			var target_direction = to_target.normalized()
			var desired_pos = target.global_position - target_direction * adjusted_distance
			var to_desired = desired_pos - global_position
			
			# Store the magnitude of force for break detection
			last_force = (to_desired * current_stiffness).length()
			
			 # Only break if we're colliding AND force is high enough
			if has_collision and last_force > COLLISION_BREAK_FORCE:
				if not is_recovering:
					recovery_timer = 0.0
					# Add velocity along collision normal instead of toward target
					velocity += last_collision_normal * 50.0
				is_recovering = true

				# Add some velocity opposite the direction we were being pulled
			else:
				# Calculate normal spring forces
				var force_multiplier = 1.0
				if is_recovering:
					# Gradually restore targeting force
					force_multiplier = ease(recovery_timer / RECOVERY_DURATION, RECOVERY_EASE_POWER)
				
				spring_force = to_desired * current_stiffness * force_multiplier * delta
				damping_force = -velocity * SPRING_DAMPING * delta
				
				 # Get nearby bodies for cluster detection
				var nearby = collision_handler.get_nearby_bodies(global_position)
				var nearby_count = nearby.size()
				
				# Calculate cluster factor
				var cluster_factor = clamp(float(nearby_count) / MAX_NEARBY_SEGMENTS, 0.0, 1.0)
				
				# Reduce spring forces in crowded areas
				spring_force *= (1.0 - cluster_factor * CLUSTER_FORCE_REDUCTION)
				damping_force *= (1.0 - cluster_factor * CLUSTER_FORCE_REDUCTION * 0.5)
				
				# Apply forces
				velocity += spring_force + damping_force
				
				# Only apply pull forces if not recovering
				if !is_recovering and current_distance > PULL_START_DISTANCE:
					var pull_factor = clamp(
						(current_distance - PULL_START_DISTANCE) / (PULL_MAX_DISTANCE - PULL_START_DISTANCE),
						0.0, 1.0
					)
					var pull_strength = PULL_FORCE * pull_factor * delta
					
					 # Reduce pull force when targeting player
					if target.is_in_group("player"):
						pull_strength *= PLAYER_PULL_REDUCTION
					
					# Apply opposite forces to both objects
					var pull_force = target_direction * pull_strength
					velocity += pull_force  # Pull this segment toward target
					if target is PhysicsObject:  # Only apply force if target can receive it
						target.velocity -= pull_force * (1.0 if not target.is_in_group("player") else PLAYER_PULL_REDUCTION) / pow(current_distance, 2.0)
						
						# Match velocities to reduce oscillation
						var match_strength = PULL_VELOCITY_MATCH * pull_factor * delta
						if target.is_in_group("player"):
							# When targeting player, match player's velocity more strongly
							velocity = velocity.lerp(target.velocity, match_strength * 1.5)
						else:
							var avg_velocity = (velocity + target.velocity) * 0.5
							velocity = velocity.lerp(avg_velocity, match_strength)
							target.velocity = target.velocity.lerp(avg_velocity, match_strength)
	
	has_collision = false  # Reset collision flag
	var collision = move_and_collide(velocity * delta)
	if collision:
		has_collision = true
		last_collision_normal = collision.get_normal()
		var collider = collision.get_collider()
		collision_handler.handle_collision(self, collider, last_collision_normal, delta)
	
	# Handle proximity with other segments
	var nearby_segments = get_tree().get_nodes_in_group("segment")
	collision_handler.handle_proximity(self, nearby_segments, delta)
	
	# Store physics state
	physics_pos = global_position

	# Update color
	if current_material:
		if is_dangerous:
			# When dangerous, maintain red color and emission
			current_color = DANGER_COLOR
			apply_color(current_color, DANGER_EMISSION)
		else:
			# Normal color lerping for safe segments
			current_color = current_color.lerp(target_color, delta * COLOR_CHANGE_SPEED)
			apply_color(current_color, Color(0.2, 0.6, 0.3, 1.0))
	
	if is_dangerous:
		target_color = DANGER_COLOR
		base_emission = DANGER_EMISSION
	else:
		target_color = SAFE_COLOR
		base_emission = Color(0.2, 0.6, 0.3, 1.0)

	super._physics_process(delta)

func _process(_delta):
	# Interpolate visual position between physics updates
	var fraction = Engine.get_physics_interpolation_fraction()
	visual_pos = physics_pos.lerp(global_position, fraction)
	
	# Update visual representation
	mesh_instance.global_position = visual_pos

func become_dangerous():
	if not is_dangerous:  # Only change state if not already dangerous
		is_dangerous = true
		target_color = DANGER_COLOR
		current_color = DANGER_COLOR  # Set current color too for immediate effect
		
		if current_material:
			current_material.albedo_color = DANGER_COLOR
			current_material.emission = DANGER_EMISSION
			current_material.emission_enabled = true
		
		add_to_group("dangerous")
		# Ensure material color updates immediately
		current_material.albedo_color = DANGER_COLOR
		
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
