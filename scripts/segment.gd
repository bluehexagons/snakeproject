extends PhysicsObject

class_name Segment

const SPRING_STIFFNESS = 140.0      # Reduced for less aggressive spring force
const SPRING_DAMPING_BASE = 15.0    # Reduced damping
const SPRING_DAMPING_GROWTH = 2.5   # Less aggressive damping growth
const TARGET_DISTANCE = 1.0
const GROWTH_DURATION = 0.33  # Faster growth
const INITIAL_SCALE = 0.4  # Slightly larger initial scale
const INITIAL_SPRING_REDUCTION = 0.5  # More force reduction when small
const SAFE_COLOR = Color(0.3, 0.8, 1.0, 0.9)
const DANGER_COLOR = Color(0.9, 0.2, 0.2, 0.9)
const DANGER_EMISSION = Color(0.8, 0.1, 0.1, 1.0)
const COLOR_CHANGE_SPEED = 5.0
const PULL_START_DISTANCE = 1.0  # Distance at which pull force starts
const PULL_MAX_DISTANCE = 2.2    # Distance at which pull force peaks
const PULL_FORCE = 400.0        # Reduced from 800.0 to allow more external influence
const RECOVERY_DURATION = 1.0         # Slightly faster recovery
const CLUSTER_FORCE_REDUCTION = 0.85  # Increased force reduction in clusters
const MAX_NEARBY_SEGMENTS = 5  # Threshold for considering an area "crowded"
const POP_FORCE = 1.0
const POP_FORCE_OPPOSITE = 10.0
const MAX_STRETCH = 1.4  # Maximum stretch multiplier before constraint kicks in
const HARD_MAX_STRETCH = 2.2  # Absolute maximum stretch before breaking
const STRETCH_STIFFNESS_SCALE = 10.4  # How much to increase stiffness when stretching
const SNAP_THRESHOLD = 0.1  # How close to max stretch before increasing stiffness
const BREAK_THRESHOLD = 0.99  # How close to HARD_MAX_STRETCH before breaking
const GROWTH_CURVE = 0.5  # Less aggressive easing
const SPAWN_DURATION = 0.5  # Duration of spawn state
const SPAWN_COLLISION_MASK = 0b111  # Actually collide with everything, but...
const NORMAL_COLLISION_MASK = 0b111  # Normal collision mask (all layers)
const CHAIN_POSITION_FACTOR = 0.12  # Increased from 0.08 for stronger position effect
const CHAIN_LENGTH_SCALING = 0.85   # More aggressive length scaling
const MIN_STIFFNESS = 0.4          # Increased minimum stiffness
const MAX_CHAIN_LENGTH = 20        # Length after which to apply extra scaling
const CHAIN_PULL_DECAY = 0.8       # Slower pull force decay through chain
const MIN_PULL_FORCE = 100.0    # Minimum pull force at chain end
const RECOVERY_COOLDOWN = 0.5   # Time before segment can break again
const SPRING_FORCE_DELAY = 0.1  # Time to wait after collision before full spring force
const COLLISION_RECOVERY_RATE = 2.0  # How fast spring forces recover after collision
const VELOCITY_MATCHING_FACTOR = 0.2 # Reduced to prevent over-matching
const VELOCITY_INHERITANCE = 0.7  # How much of target's velocity direction to inherit
const VELOCITY_INHERITANCE_SPEED = 5.0  # How fast to inherit velocity direction
const MIN_VELOCITY_MATCH = 0.2  # Minimum velocity matching even at rest
const COLLISION_FORCE_SCALE = 0.9   # Less reduction in collision response
const MIN_COLLISION_SPEED = 4.0  # Increased threshold for extra dampening
const BROKEN_VELOCITY_INHERIT = 0.7  # How much velocity to keep when breaking
const BROKEN_ANGULAR_IMPULSE = 5.0  # Add some spin when breaking
const CONNECTED_FRICTION_MULTIPLIER = 2.5  # Higher friction when connected
const CONNECTED_ROLLING_MULTIPLIER = 3.0   # Much harder to roll when connected
const COLLISION_BOUNCE_DAMPING = 0.1        # Drastically reduced bounce
const COLLISION_TANGENT_RETAIN = 0.95       # Keep almost all sliding motion
const COLLISION_SEPARATION_FORCE = 0.15     # Very gentle separation
const ROCK_COLLISION_EXTRA_DAMPING = 0.4    # Allow more sliding on rocks
const SEGMENT_COLLISION_RESTITUTION = 0.1   # Minimal bounce between segments
const SEGMENT_REPULSION_FORCE = 120.0       # Gentler separation force
const SEGMENT_PROXIMITY_RADIUS = 1.2      # Distance to check for segment interaction
const COLLISION_VELOCITY_MATCH = 0.25       # Increased to prevent bouncing

# Add proximity handling constants
const PROXIMITY_FORCE = 80.0                # Reduced repulsion for smoother grouping
const PROXIMITY_FALLOFF = 0.8               # Gentler force falloff
const PROXIMITY_VELOCITY_MATCH = 0.2  # How much to match velocities when close

const PULL_FORCE_TRANSFER = 1.5  # How much of pull force transfers to pushing obstacles
const PUSH_BOOST_THRESHOLD = 0.5  # Speed threshold to identify when being pulled strongly
const PUSH_FORCE_MULTIPLIER = 2.0  # Extra force when pushing due to chain pull

const PUSH_FORCE_RAMP_RATE = 1.5  # How quickly to build up pushing force
const MAX_PUSH_MULTIPLIER = 2.5  # Maximum force multiplier when pushing
const RESISTANCE_DECAY = 0.8  # How quickly push force decays

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
var last_pull_direction: Vector3 = Vector3.ZERO
var current_pull_force: float = 0.0
var push_force_multiplier: float = 1.0
var last_collision_time: float = 0.0

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
	# Near the start, update friction based on connection state
	if is_instance_valid(target):
		# Check if we're ultimately connected to the player through the chain
		var is_player_connected = false
		var current_target = target
		var depth = 0  # Prevent infinite loops
		while current_target and depth < 100:
			if current_target is Player:
				is_player_connected = true
				break
			if current_target is Segment:
				current_target = current_target.target
			else:
				break
			depth += 1
		
		# Adjust friction based on connection
		if is_player_connected:
			static_friction = PhysicsConstants.SEGMENT_STATIC_FRICTION * CONNECTED_FRICTION_MULTIPLIER
			rolling_friction = PhysicsConstants.SEGMENT_ROLLING_FRICTION * CONNECTED_ROLLING_MULTIPLIER
		else:
			static_friction = PhysicsConstants.SEGMENT_STATIC_FRICTION
			rolling_friction = PhysicsConstants.SEGMENT_ROLLING_FRICTION
	else:
		# Reset to default friction when disconnected
		static_friction = PhysicsConstants.SEGMENT_STATIC_FRICTION
		rolling_friction = PhysicsConstants.SEGMENT_ROLLING_FRICTION
	
	# Add early exit for extreme velocities
	if velocity.length() > PhysicsConstants.SEGMENT_MAX_SPEED * 2.0:
		velocity = velocity.normalized() * PhysicsConstants.SEGMENT_MAX_SPEED
	
	# Early out if recovering
	if is_recovering:
		recovery_timer = min(recovery_timer + delta, RECOVERY_DURATION)
		if recovery_timer >= RECOVERY_DURATION:
			is_recovering = false

	if is_growing:
		growth_timer += delta
		var t = growth_timer / GROWTH_DURATION
		if t <= 1.0:
			var growth = ease(t, GROWTH_CURVE)
			 # Rename to avoid shadowing
			var growth_scale = lerp(INITIAL_SCALE, 1.0, growth)
			apply_physics_scale(growth_scale)
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
	
	# Calculate base spring force with spawn reduction
	var base_stiffness = SPRING_STIFFNESS * lerp(INITIAL_SPRING_REDUCTION, 1.0, 1.0 - (spawn_timer / SPAWN_DURATION))
	
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
					
					# Make both segments dangerous
					become_dangerous()
					if target is Segment:
						target.become_dangerous()
					
					# Apply break forces with more physical behavior
					# Remove unused break_velocity variable
					# We can't apply torque to CharacterBody3D, so we'll use linear forces instead
					var random_dir = Vector3(
						randf_range(-1, 1),
						randf_range(-1, 1),
						randf_range(-1, 1)
					).normalized()
					
					apply_impulse(-target_direction * POP_FORCE_OPPOSITE * mass)
					apply_impulse(Vector3.UP * POP_FORCE * mass)
					apply_impulse(random_dir * BROKEN_ANGULAR_IMPULSE * mass)
					
					if target is PhysicsObject:
						target.apply_impulse(target_direction * POP_FORCE_OPPOSITE * target.mass)
						target.apply_impulse(Vector3.UP * POP_FORCE * target.mass)
						target.apply_impulse(-random_dir * BROKEN_ANGULAR_IMPULSE * target.mass)
						velocity = velocity.lerp(target.velocity, 0.3)  # Inherit some velocity
					
					target = null  # Clear target reference first
				
				is_recovering = true
			
			if not is_recovering and target:
				var target_velocity = target.velocity if target is PhysicsObject else Vector3.ZERO
				
				# Get chain scaling factors from SpringPhysics
				var factors = SpringPhysics.calculate_chain_factors(chain_index, chain_length)
				
				# Calculate spring scale
				var spring_scale = lerp(0.3, 1.0, min(collision_recovery_timer / SPRING_FORCE_DELAY, 1.0))
				collision_recovery_timer += delta * COLLISION_RECOVERY_RATE
				
				# Apply stretch-based stiffness increase
				var stretch_factor = current_distance / adjusted_distance
				var stretch_progress = clamp((stretch_factor - 1.0) / (MAX_STRETCH - 1.0), 0.0, 1.0)
				var current_stiffness = base_stiffness * (1.0 + stretch_progress * (STRETCH_STIFFNESS_SCALE * 0.7))
				
				# Calculate final force scale
				var force_scale = factors.position_scale * factors.length_factor * spring_stiffness_multiplier * spring_scale
				
				# Apply distance constraint if needed
				if current_distance > max_distance:
					_apply_distance_constraint(target, max_distance, delta)
				
				# Calculate spring force using SpringPhysics
				var spring_force = SpringPhysics.calculate_spring_force(
					global_position,
					target.global_position,
					adjusted_distance,
					current_stiffness,
					force_scale
				) * 0.8  # Reduce spring force importance
				
				# Calculate damping using SpringPhysics
				var damping = SPRING_DAMPING_BASE + (SPRING_DAMPING_GROWTH * pow(factors.chain_factor, 0.8))
				var damping_force = SpringPhysics.calculate_damping_force(
					velocity,
					target_velocity,
					damping,
					force_scale
				)
				
				# Calculate velocity matching using SpringPhysics
				var matching_force = SpringPhysics.calculate_velocity_matching(
					global_position,
					target.global_position,
					velocity,
					target_velocity,
					adjusted_distance,
					mass,
					VELOCITY_MATCHING_FACTOR
				)
				
				# Calculate velocity inheritance using SpringPhysics
				var inherit_force = SpringPhysics.apply_velocity_inheritance(
					velocity,
					target_velocity,
					delta,
					VELOCITY_INHERITANCE_SPEED,
					VELOCITY_INHERITANCE,
					mass
				)
				
				# Apply all forces
				apply_force(spring_force)
				apply_force(damping_force)
				apply_force(matching_force)
				apply_force(inherit_force)
				
				# Handle pull forces
				_apply_pull_forces(target, current_distance, target_direction)
				
				last_force = spring_force.length()

	var collision = move_and_collide(velocity * delta)
	if collision:
		var collider = collision.get_collider()
		if not collider is PhysicsObject:
			return
			
		var normal = collision.get_normal()
		var relative_velocity = velocity - collider.velocity
		var normal_vel = normal * relative_velocity.dot(normal)
		var tangent_vel = relative_velocity - normal_vel
		
		 # Remove unused mass ratio variables since we're not using them in the collision response
		var restitution = COLLISION_BOUNCE_DAMPING
		var tangent_retain = COLLISION_TANGENT_RETAIN
		
		# Adjust response based on collider type
		if collider is Segment:
			restitution = SEGMENT_COLLISION_RESTITUTION
			tangent_retain = 0.9
			
			# Apply separation impulse
			var separation = normal * SEGMENT_REPULSION_FORCE * delta
			apply_impulse(separation)
			collider.apply_impulse(-separation)
			
			# Match velocities to prevent ping-ponging
			velocity = velocity.lerp(collider.velocity, COLLISION_VELOCITY_MATCH)
		elif collider.material_type == PhysicsConstants.MATERIAL_ROCK:
			restitution *= ROCK_COLLISION_EXTRA_DAMPING
		
		# Apply collision response
		velocity = (tangent_vel * tangent_retain - normal_vel * restitution) * COLLISION_FORCE_SCALE
		
		# Apply gentle separation impulse
		apply_impulse(normal * COLLISION_SEPARATION_FORCE * mass)
		
		# Handle impact effects
		handle_impact(relative_velocity.length() * collision_force_multiplier)
		
		has_collision = true
		last_collision_normal = normal
		collision_recovery_timer = 0.0
	
	# Handle proximity
	if has_collision:  # We still check only after collisions for performance
		var nearby_bodies = get_node("/root/CollisionHandler").get_nearby_bodies(global_position, SEGMENT_PROXIMITY_RADIUS)
		for other in nearby_bodies:
			if other == self or not other is PhysicsObject:
				continue
			
			var to_other = other.global_position - global_position
			var distance = to_other.length()
			if distance > 0 and distance < SEGMENT_PROXIMITY_RADIUS:
				handle_proximity(other, distance, to_other / distance)
	
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
			velocity = velocity.lerp(velocity + correction_vel * mass_ratio_b, 0.5)
			target_body.velocity = target_body.velocity.lerp(
				target_body.velocity - correction_vel * mass_ratio_a, 0.5)

# Rename parameter to avoid shadowing
func _apply_pull_forces(target_body: Node3D, current_distance: float, direction: Vector3) -> void:
	if current_distance > PULL_START_DISTANCE:
		var pull_factor = clamp(
			(current_distance - PULL_START_DISTANCE) / (PULL_MAX_DISTANCE - PULL_START_DISTANCE),
			0.0, 1.0
		)
		
		# Calculate chain-based pull force that increases with resistance
		var chain_pull = PULL_FORCE * pow(CHAIN_PULL_DECAY, chain_index * 0.7)
		chain_pull = max(chain_pull * (1.0 + velocity.length() * 0.1), MIN_PULL_FORCE)
		var pull_force = direction * chain_pull * pull_factor
		
		# Apply forces with better distribution
		apply_force(pull_force)
		if target_body is PhysicsObject:
			var resistance_scale = clamp(velocity.length() / 5.0, 0.5, 2.0)
			target_body.apply_force(-pull_force * resistance_scale)
			
			# Store pull direction for collision handling
			last_pull_direction = direction
			current_pull_force = chain_pull * pull_factor

func handle_proximity(other: PhysicsObject, distance: float, direction: Vector3) -> void:
	if distance <= 0:
		return
		
	var force_scale = (1.0 - distance / SEGMENT_PROXIMITY_RADIUS)
	var repulsion = -direction * PROXIMITY_FORCE * pow(force_scale, PROXIMITY_FALLOFF)
	
	# Add velocity matching to prevent oscillation
	var relative_velocity = other.velocity - velocity
	var velocity_correction = relative_velocity * PROXIMITY_VELOCITY_MATCH
	
	apply_force(repulsion - velocity_correction)
	if other is PhysicsObject:
		other.apply_force(-repulsion + velocity_correction)

func handle_collision(other: PhysicsObject, normal: Vector3, relative_velocity: Vector3) -> void:
	# Only handle if moving towards each other
	var normal_velocity = relative_velocity.dot(normal)
	if normal_velocity >= 0:
		return
	
	var time_since_collision = Time.get_ticks_msec() / 1000.0 - last_collision_time
	last_collision_time = Time.get_ticks_msec() / 1000.0
	
	# Build up push force if colliding repeatedly
	if time_since_collision < 0.2:  # Recent collision
		push_force_multiplier = min(
			push_force_multiplier + PUSH_FORCE_RAMP_RATE * time_since_collision,
			MAX_PUSH_MULTIPLIER
		)
	else:
		push_force_multiplier = max(push_force_multiplier * RESISTANCE_DECAY, 1.0)
	
	# Calculate collision response with ramping force
	var restitution = 0.3
	var impact_force = -(1.0 + restitution) * normal_velocity
	
	# Add extra force when being pulled against obstacle
	var extra_force = 0.0
	if is_instance_valid(target) and target is PhysicsObject:
		var to_target = (target.global_position - global_position).normalized()
		var push_alignment = -normal.dot(to_target)
		
		if push_alignment > 0.3 and velocity.length() > PUSH_BOOST_THRESHOLD:
			extra_force = push_alignment * PUSH_FORCE_MULTIPLIER * current_pull_force
	
	# Apply ramping force multiplier
	impact_force *= (1.0 + extra_force) * push_force_multiplier
	
	# Apply forces with improved mass ratios
	var mass_sum = mass + other.mass
	var my_ratio = mass / mass_sum
	var other_ratio = other.mass / mass_sum
	var scaled_force = impact_force * (mass * other.mass) / mass_sum
	
	# Apply impulses
	apply_impulse(normal * scaled_force * other_ratio)
	other.apply_impulse(-normal * scaled_force * my_ratio)
	
	# Handle impact effects
	handle_impact(scaled_force * collision_force_multiplier)

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
