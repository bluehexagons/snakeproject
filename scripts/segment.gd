extends PhysicsObject

class_name Segment

const SPRING_STIFFNESS = 200.0  # Significantly reduced from 400.0
const SPRING_DAMPING = 35.0     # Slightly reduced from 45.0
const TARGET_DISTANCE = 1.0
const GROWTH_DURATION = 0.33  # Faster growth
const INITIAL_SCALE = 0.4  # Slightly larger initial scale
const INITIAL_SPRING_REDUCTION = 0.5  # More force reduction when small
const SAFE_COLOR = Color(0.3, 0.8, 1.0, 0.9)
const DANGER_COLOR = Color(0.9, 0.2, 0.2, 0.9)
const DANGER_EMISSION = Color(0.8, 0.1, 0.1, 1.0)
const COLOR_CHANGE_SPEED = 5.0
const PULL_START_DISTANCE = 1.3  # Distance at which pull force starts
const PULL_MAX_DISTANCE = 2.0    # Distance at which pull force peaks
const PULL_FORCE = 400.0        # Reduced from 800.0 to allow more external influence
const RECOVERY_DURATION = 1.0         # Slightly faster recovery
const CLUSTER_FORCE_REDUCTION = 0.85  # Increased force reduction in clusters
const MAX_NEARBY_SEGMENTS = 5  # Threshold for considering an area "crowded"
const POP_FORCE = 1.0
const POP_FORCE_OPPOSITE = 10.0
const MAX_STRETCH = 1.4  # Maximum stretch multiplier before constraint kicks in
const HARD_MAX_STRETCH = 2.6  # Absolute maximum stretch before breaking
const STRETCH_STIFFNESS_SCALE = 10.0  # How much to increase stiffness when stretching
const SNAP_THRESHOLD = 0.1  # How close to max stretch before increasing stiffness
const BREAK_THRESHOLD = 0.999  # How close to HARD_MAX_STRETCH before breaking
const GROWTH_CURVE = 0.5  # Less aggressive easing
const SPAWN_DURATION = 0.5  # Duration of spawn state
const SPAWN_COLLISION_MASK = 0b111  # Actually collide with everything, but...
const NORMAL_COLLISION_MASK = 0b111  # Normal collision mask (all layers)
const CHAIN_POSITION_FACTOR = 0.08  # Reduced for more gradual change
const CHAIN_LENGTH_SCALING = 0.92   # Less aggressive length scaling
const MIN_STIFFNESS = 0.3          # Minimum spring stiffness multiplier
const MAX_CHAIN_LENGTH = 20        # Length after which to apply extra scaling
const CHAIN_PULL_DECAY = 0.7    # How much pull force carries through chain
const MIN_PULL_FORCE = 100.0    # Minimum pull force at chain end
const RECOVERY_COOLDOWN = 0.5   # Time before segment can break again
const SPRING_FORCE_DELAY = 0.1  # Time to wait after collision before full spring force

var target: Node3D
var smoothed_velocity: Vector3
var growth_timer: float = 0.0
var is_growing: bool = true
var spawn_timer: float = SPAWN_DURATION  # Changed from 0.5 to match SPAWN_DURATION
var is_dangerous: bool = false
var recovery_timer: float = 0.0
var is_recovering: bool = false
var last_force: float = 0.0
var last_collision_normal: Vector3 = Vector3.ZERO
var has_collision: bool = false
var chain_index: int = 0  # Position in the chain, set during add_segment
var chain_length: int = 1 # Total chain length, updated by player
var collision_recovery_timer: float = 0.0  # Track time since last collision

func _ready():
	super()
	material_type = PhysicsConstants.MATERIAL_SEGMENT
	base_mass = PhysicsConstants.SEGMENT_MASS
	mass = base_mass
	pull_reduction = 1.2  # Slightly easier to pull
	target_distance = TARGET_DISTANCE  # Use existing constant
	collision_force_multiplier = 1.2  # Take more impact from collisions
	spring_stiffness_multiplier = 0.8  # Reduced spring forces
	
	drag_coefficient = PhysicsConstants.SEGMENT_DRAG
	max_speed = PhysicsConstants.SEGMENT_MAX_SPEED
	static_friction = PhysicsConstants.SEGMENT_STATIC_FRICTION
	dynamic_friction = PhysicsConstants.SEGMENT_DYNAMIC_FRICTION
	rolling_friction = PhysicsConstants.SEGMENT_ROLLING_FRICTION
	# Set initial scale and positions
	base_scale = 1.0
	
	# Set initial colors
	current_color = SAFE_COLOR
	target_color = SAFE_COLOR
	base_emission = Color(0.2, 0.6, 0.3, 1.0)
	apply_color(current_color, Color(0.2, 0.6, 0.3, 1.0))
	apply_physics_scale(INITIAL_SCALE, true)
	
	# Initially set up collisions - we'll just ignore them in the collision handler
	collision_mask = SPAWN_COLLISION_MASK
	collision_layer = 2  # Always be on physics layer

func init_with_growth(initial_growth: float):
	growth_timer = GROWTH_DURATION * initial_growth
	var growth = ease(initial_growth, GROWTH_CURVE)
	apply_physics_scale(lerp(INITIAL_SCALE, 1.0, growth), true)
	is_growing = initial_growth < 1.0
	# Reset spawn timer to avoid collision issues
	spawn_timer = SPAWN_DURATION if is_growing else 0.0
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
	var growth = data.get("growth", 1.0)
	growth_timer = GROWTH_DURATION * growth
	is_growing = growth < 1.0
	
	# Apply scale immediately
	apply_physics_scale(current_scale, true)
	
	# Set spawn timer based on growth
	spawn_timer = SPAWN_DURATION if is_growing else 0.0
	
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
			var growth = ease(t, GROWTH_CURVE)
			# Smoother scale transition
			var target = lerp(INITIAL_SCALE, 1.0, growth)
			apply_physics_scale(target)
			# Scale spring forces with size
			spring_stiffness_multiplier = lerp(INITIAL_SPRING_REDUCTION, 1.0, growth)
		else:
			is_growing = false
			apply_physics_scale(1.0)
			spring_stiffness_multiplier = 1.0
	
	# Update spawn timer and collision masks
	if spawn_timer > 0:
		spawn_timer = max(0.0, spawn_timer - delta)
		if spawn_timer <= 0:
			# Enable full collisions when spawn is complete
			collision_mask = NORMAL_COLLISION_MASK
			collision_layer = 2  # Physical objects layer
	
	# Update spawn timer
	spawn_timer = max(0.0, spawn_timer - delta)
	
	if is_recovering:
		recovery_timer = min(recovery_timer + delta, RECOVERY_DURATION)
		if recovery_timer >= RECOVERY_DURATION:
			is_recovering = false
	
	# Calculate base spring force with spawn reduction
	var base_stiffness = SPRING_STIFFNESS * lerp(INITIAL_SPRING_REDUCTION, 1.0, 1.0 - (spawn_timer / 0.5))
	
	var collision_handler = get_node("/root/CollisionHandler")

	if is_instance_valid(target):
		# Calculate target distance based on current scales
		var adjusted_distance = target_distance * (current_scale + (target.get("current_scale") if target.has_method("get_scale") else 1.0)) * 0.5
		var max_distance = adjusted_distance * MAX_STRETCH
		var hard_max_distance = adjusted_distance * HARD_MAX_STRETCH
		
		var to_target = target.global_position - global_position
		var current_distance = to_target.length()
		
		if current_distance > 0:
			var target_direction = to_target.normalized()
			
			# Check for breaking condition first
			if current_distance > hard_max_distance * BREAK_THRESHOLD:
				if not is_recovering:
					recovery_timer = 0.0
					# Apply break impulse away from excessive stretch
					apply_impulse(-target_direction * POP_FORCE_OPPOSITE * mass * randf_range(0, 1))
					apply_impulse(Vector3.UP * POP_FORCE * mass * randf_range(0, 1))
				is_recovering = true
				return  # Skip normal spring forces
			
			# Calculate stretch factor
			var stretch_factor = current_distance / adjusted_distance
			
			# Apply hard distance constraint
			if current_distance > max_distance:
				# Calculate positions for constraint
				var constraint_center = (global_position + target.global_position) * 0.5
				var to_center = global_position - constraint_center
				var constraint_distance = max_distance * 0.5
				
				# Apply constraint through velocity adjustment
				if target is PhysicsObject:
					var total_mass = mass + target.mass
					var mass_ratio_a = mass / total_mass
					var mass_ratio_b = target.mass / total_mass
					
					var new_pos_a = constraint_center + to_center.normalized() * constraint_distance
					var new_pos_b = constraint_center - to_center.normalized() * constraint_distance
					
					var correction_a = (new_pos_a - global_position) / delta
					var correction_b = (new_pos_b - target.global_position) / delta
					
					velocity += correction_a * mass_ratio_b
					target.velocity += correction_b * mass_ratio_a
			
			# Calculate spring force with progressive stiffness
			var desired_pos = target.global_position - target_direction * adjusted_distance
			var to_desired = desired_pos - global_position
			
			# Increase stiffness as we approach max stretch, but with less intensity
			var stretch_progress = clamp((stretch_factor - 1.0) / (MAX_STRETCH - 1.0), 0.0, 1.0)
			var current_stiffness = base_stiffness * (1.0 + stretch_progress * (STRETCH_STIFFNESS_SCALE * 0.7))
			
			# Store the magnitude of force for debugging
			last_force = (to_desired * current_stiffness).length()
			
			# Apply chain-based scaling factors with smoother progression
			var position_scale = pow(1.0 - (chain_index * CHAIN_POSITION_FACTOR), 0.7)
			position_scale = clamp(position_scale, MIN_STIFFNESS, 1.0)
			
			var length_factor = 1.0
			if chain_length > MAX_CHAIN_LENGTH:
				length_factor = pow(CHAIN_LENGTH_SCALING, chain_length - MAX_CHAIN_LENGTH)
			
			# Progressive damping that increases more toward the tail
			var damping_scale = lerp(1.0, 3.0, pow(float(chain_index) / chain_length, 0.6))
			
			# Calculate base forces with new scaling
			var force_scale = position_scale * length_factor * spring_stiffness_multiplier
			var spring_force = to_desired * current_stiffness * force_scale
			var damping_force = -velocity * (SPRING_DAMPING * damping_scale) * force_scale
			
			# Calculate pull force that propagates through the chain
			if current_distance > PULL_START_DISTANCE:
				var pull_factor = clamp(
					(current_distance - PULL_START_DISTANCE) / (PULL_MAX_DISTANCE - PULL_START_DISTANCE),
					0.0, 1.0
				)
				
				# Calculate chain-aware pull force
				var chain_pull = PULL_FORCE * pow(CHAIN_PULL_DECAY, chain_index)
				chain_pull = max(chain_pull, MIN_PULL_FORCE)
				var pull_force = target_direction * chain_pull * pull_factor
				
				# Apply pull force both to self and target
				apply_force(pull_force)
				if target is PhysicsObject:
					var target_mass_ratio = target.mass / (mass + target.mass)
					var opposite_force = -pull_force * target_mass_ratio * target.pull_reduction
					target.apply_force(opposite_force)
			
			# Get nearby bodies for cluster detection
			var nearby = collision_handler.get_nearby_bodies(global_position)
			var cluster_factor = clamp(float(nearby.size()) / MAX_NEARBY_SEGMENTS, 0.0, 1.0)
			
			# Apply cluster-based force reduction
			spring_force *= (1.0 - cluster_factor * CLUSTER_FORCE_REDUCTION)
			damping_force *= (1.0 - cluster_factor * CLUSTER_FORCE_REDUCTION)
			
			apply_force(spring_force)
			apply_force(damping_force)

	var collision = move_and_collide(velocity * delta)
	if collision:
		has_collision = true
		last_collision_normal = collision.get_normal()
		collision_recovery_timer = SPRING_FORCE_DELAY  # Reset recovery timer on collision
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
