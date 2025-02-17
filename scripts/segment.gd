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
const PULL_FORCE = 350.0          # Stronger base pull force
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

const FOLLOW_ACCELERATION = 140.0  # Reduced acceleration
const FOLLOW_DRAG = 0.95         # Less drag to allow better movement
const PLAYER_FOLLOW_MULTIPLIER = 1.5  # Follow player more aggressively
const IDEAL_FOLLOW_DISTANCE = 1.2 # Slightly increased to prevent crowding
const TOO_CLOSE_DISTANCE = 1.0   # Increased to back off sooner
const FOLLOW_FORCE_SCALE = 1.2   # How strongly to follow
const BACKING_FORCE_SCALE = 2.0  # Stronger backing away when too close
const MIN_FOLLOW_SPEED = 2.0     # Minimum speed when following

const MOVEMENT_THRESHOLD = 1.0    # Increased threshold before following
const VELOCITY_DECAY = 0.97        # Decay velocity when target is stationary
const ROCK_PUSH_BOOST = 2.5        # More reasonable push force
const MIN_FORCE_THRESHOLD = 0.1    # Don't apply tiny forces
const PASSIVE_DAMPING = 0.98     # Lighter damping when not moving

const COLLISION_PUSH_FORCE = 180.0   # Strong base push force for collisions
const COLLISION_PUSH_DECAY = 0.85    # How quickly push force decays
const MIN_SEPARATION_SPEED = 1.0     # Minimum speed to maintain when separating
const SEGMENT_PUSH_MULTIPLIER = 1.5  # Extra force when pushing other segments
const PUSH_DIRECTION_BLEND = 0.3     # How much to blend push direction with movement

const PULL_FORCE_PLAYER_REDUCTION = 0.6  # Less reduction on player (was 0.4)
const PULL_ACCELERATION_RATE = 2.0       # How quickly pull force builds up
const MAX_PULL_VELOCITY = 15.0           # Maximum velocity when being pulled
const PULL_VELOCITY_REDUCTION = 0.7      # Reduce velocity when pulling against resistance

# Simplified rock interaction constants
const ROCK_PUSH_FORCE = 800.0     # Much stronger push force
const ROCK_SLIDE_SPEED = 0.8      # How much sliding motion to maintain
const ROCK_REBOUND = 0.4          # How much to bounce off
const ROCK_SEPARATION = 100.0     # Force to prevent sticking

const CHAIN_FORCE_TRANSFER = 2.5   # Stronger chain force transfer
const VELOCITY_TRANSFER = 0.4      # Direct velocity transfer during push

const ROCK_PUSH_SCALE = 1.5       # More conservative push force
const CHAIN_FORCE_SCALE = 0.8     # Gentler chain force
const PUSH_FORCE_BUILDUP = 0.15   # Gradual force buildup

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

var desired_movement: Vector3 = Vector3.ZERO
var last_target_pos: Vector3 = Vector3.ZERO
var target_movement_smoothed: Vector3 = Vector3.ZERO
var current_pull_multiplier: float = 0.0

func _ready():
	super()
	material_type = PhysicsConstants.MATERIAL_SEGMENT
	
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
	apply_physics_scale(INITIAL_SCALE, true)
	apply_color(SAFE_COLOR, Color(0.2, 0.6, 0.3, 1.0))

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
		cached_velocity = Vector3(data.velocity.x, data.velocity.y, data.velocity.z)
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
	
	# Add early exit for extreme velocities now uses cached_velocity
	if cached_velocity.length() > PhysicsConstants.SEGMENT_MAX_SPEED * 2.0:
		cached_velocity = cached_velocity.normalized() * PhysicsConstants.SEGMENT_MAX_SPEED
	
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
		# Calculate following behavior first
		var target_offset = target.global_position - global_position
		var follow_distance = target_offset.length()
		
		if follow_distance > 0:
			var follow_direction = target_offset / follow_distance
			
			# Calculate target's movement
			var target_movement = Vector3.ZERO
			if last_target_pos != Vector3.ZERO:
				target_movement = (target.global_position - last_target_pos) / delta
			last_target_pos = target.global_position
			
			# Only move if we need to
			var needs_movement = follow_distance > IDEAL_FOLLOW_DISTANCE * 1.1 or follow_distance < TOO_CLOSE_DISTANCE
			var target_speed = target_movement.length()
			var follow_force = Vector3.ZERO
			
			if needs_movement:
				# Calculate desired position
				if follow_distance < TOO_CLOSE_DISTANCE:
					# Strong backing away force
					follow_force = -follow_direction * BACKING_FORCE_SCALE
				elif follow_distance > IDEAL_FOLLOW_DISTANCE:
					# Gentle following force, only if target is moving
					var force_scale = 0.5 if target_speed > MOVEMENT_THRESHOLD else 0.2  # Fixed ternary syntax
					follow_force = follow_direction * FOLLOW_ACCELERATION * force_scale
				
				# Modify follow force when target is player
				if target is Player:
					follow_force *= PLAYER_FOLLOW_MULTIPLIER
					if cached_velocity.length() < target.cached_velocity.length():
						# Boost acceleration when falling behind player
						follow_force *= 1.5
				
				# Apply very gentle movement
				if follow_force.length_squared() > MIN_FORCE_THRESHOLD:
					add_physics_force(follow_force * get_effective_mass())
			else:
				# If in good position, just dampen velocity
				add_physics_force(-cached_velocity * (PASSIVE_DAMPING - 1.0) * get_effective_mass())
			
			# Always apply drag
			add_physics_force(-cached_velocity * (1.0 - FOLLOW_DRAG) * get_effective_mass())
		
		# Now handle spring forces and constraints
		var adjusted_distance = target_distance * (current_scale + (target.get("current_scale") if target.has_method("get_scale") else 1.0)) * 0.5
		var max_distance = adjusted_distance * MAX_STRETCH
		var hard_max_distance = adjusted_distance * HARD_MAX_STRETCH
		
		# Reuse the target_offset and follow_distance we calculated earlier
		if follow_distance > hard_max_distance * BREAK_THRESHOLD:
			if not is_recovering:
				recovery_timer = 0.0
				
				# Make both segments dangerous
				become_dangerous()
				if target is Segment:
					target.become_dangerous()
				
				var direction = target_offset.normalized()  # Use normalized target_offset instead of follow_direction
				var random_dir = Vector3(
					randf_range(-1, 1),
					randf_range(-1, 1),
					randf_range(-1, 1)
				).normalized()
				
				apply_impulse(-direction * POP_FORCE_OPPOSITE * mass)
				apply_impulse(Vector3.UP * POP_FORCE * mass)
				apply_impulse(random_dir * BROKEN_ANGULAR_IMPULSE * mass)
				
				if target is PhysicsObject:
					target.apply_impulse(direction * POP_FORCE_OPPOSITE * target.mass)
					target.apply_impulse(Vector3.UP * POP_FORCE * target.mass)
					target.apply_impulse(-random_dir * BROKEN_ANGULAR_IMPULSE * target.mass)
					cached_velocity = cached_velocity.lerp(target.cached_velocity, 0.3)
				
				target = null
			
			is_recovering = true
		
		if not is_recovering and target:
			# Update how we get target velocity
			var target_velocity = Vector3.ZERO
			if target is RigidBody3D:
				target_velocity = target.linear_velocity
			elif target.has_method("get_velocity"):  # Fallback for non-RigidBody3D
				target_velocity = target.get_velocity()
			
			# Get chain scaling factors from SpringPhysics
			var factors = SpringPhysics.calculate_chain_factors(chain_index, chain_length)
			
			# Calculate spring scale
			var spring_scale = lerp(0.3, 1.0, min(collision_recovery_timer / SPRING_FORCE_DELAY, 1.0))
			collision_recovery_timer += delta * COLLISION_RECOVERY_RATE
			
			# Apply stretch-based stiffness increase
			var stretch_factor = follow_distance / adjusted_distance
			var stretch_progress = clamp((stretch_factor - 1.0) / (MAX_STRETCH - 1.0), 0.0, 1.0)
			var current_stiffness = base_stiffness * (1.0 + stretch_progress * (STRETCH_STIFFNESS_SCALE * 0.7))
			
			# Calculate final force scale
			var force_scale = factors.position_scale * factors.length_factor * spring_stiffness_multiplier * spring_scale
			
			# Apply distance constraint if needed
			if follow_distance > max_distance:
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
				cached_velocity,
				target_velocity,
				damping,
				force_scale
			)
			
			# Calculate velocity matching using SpringPhysics
			var matching_force = SpringPhysics.calculate_velocity_matching(
				global_position,
				target.global_position,
				cached_velocity,
				target_velocity,
				adjusted_distance,
				mass,
				VELOCITY_MATCHING_FACTOR
			)
			
			# Calculate velocity inheritance using SpringPhysics
			var inherit_force = SpringPhysics.apply_velocity_inheritance(
				cached_velocity,
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
			_apply_pull_forces(target, follow_distance, target_offset.normalized())
			
			last_force = spring_force.length()

	var collision = move_and_collide(cached_velocity * delta)
	if collision:
		var collider = collision.get_collider()
		if not collider is PhysicsObject:
			return
			
		var normal = collision.get_normal()
		var relative_velocity = cached_velocity - collider.cached_velocity
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
			cached_velocity = cached_velocity.lerp(collider.cached_velocity, COLLISION_VELOCITY_MATCH)
		elif collider.material_type == PhysicsConstants.MATERIAL_ROCK:
			restitution *= ROCK_COLLISION_EXTRA_DAMPING
		
		# Apply collision response
		cached_velocity = (tangent_vel * tangent_retain - normal_vel * restitution) * COLLISION_FORCE_SCALE
		
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
			cached_velocity = cached_velocity.lerp(cached_velocity + correction_vel * mass_ratio_b, 0.5)
			target_body.cached_velocity = target_body.cached_velocity.lerp(
				target_body.cached_velocity - correction_vel * mass_ratio_a, 0.5)

# Rename parameter to avoid shadowing
func _apply_pull_forces(target_body: Node3D, current_distance: float, direction: Vector3) -> void:
	if current_distance > PULL_START_DISTANCE:
		var pull_factor = clamp(
			(current_distance - PULL_START_DISTANCE) / (PULL_MAX_DISTANCE - PULL_START_DISTANCE),
			0.0, 1.0
		)
		
		 # Build up pull force gradually
		current_pull_multiplier = move_toward(
			current_pull_multiplier,
			1.0,
			PULL_ACCELERATION_RATE * get_physics_process_delta_time()
		)
		
		# Calculate chain-based pull force
		var chain_pull = PULL_FORCE * pow(CHAIN_PULL_DECAY, chain_index * 0.7)
		chain_pull = max(chain_pull * (1.0 + cached_velocity.length() * 0.1), MIN_PULL_FORCE)
		
		# Only pull if beyond ideal distance
		if current_distance > IDEAL_FOLLOW_DISTANCE:
			var pull_force = direction * chain_pull * pull_factor * current_pull_multiplier
			
			# Reduce pull force significantly when target is player
			if target_body is Player:
				pull_force *= PULL_FORCE_PLAYER_REDUCTION
			
			# Limit pull velocity
			var current_speed = cached_velocity.length()
			if current_speed > MAX_PULL_VELOCITY:
				cached_velocity = cached_velocity.normalized() * MAX_PULL_VELOCITY
				pull_force *= PULL_VELOCITY_REDUCTION
			
			apply_force(pull_force)
			
			if target_body is PhysicsObject:
				# Apply reduced force to target and store for collision handling
				var resistance_scale = clamp(cached_velocity.length() / 5.0, 0.3, 1.0)  # Reduced maximum resistance
				target_body.apply_force(-pull_force * resistance_scale)
				last_pull_direction = direction
				current_pull_force = chain_pull * pull_factor
		else:
			current_pull_multiplier = 0.0  # Reset pull force when in good position

func handle_proximity(other: PhysicsObject, distance: float, direction: Vector3) -> void:
	if distance <= 0:
		return
		
	var force_scale = (1.0 - distance / SEGMENT_PROXIMITY_RADIUS)
	var repulsion = -direction * PROXIMITY_FORCE * pow(force_scale, PROXIMITY_FALLOFF)
	
	# Fix velocity reference
	var relative_velocity = other.linear_velocity - cached_velocity
	var velocity_correction = relative_velocity * PROXIMITY_VELOCITY_MATCH
	
	apply_force(repulsion - velocity_correction)
	if other is PhysicsObject:
		other.apply_force(-repulsion + velocity_correction)

func handle_collision(other: PhysicsObject, normal: Vector3, relative_velocity: Vector3) -> void:
	if other.material_type == PhysicsConstants.MATERIAL_ROCK:
		var chain_factor = 1.0 - (float(chain_index) / max(chain_length, 1))
		
		# Calculate push force with better scaling
		var push_force = ROCK_PUSH_SCALE
		if current_pull_force > 0:
			push_force += chain_factor * CHAIN_FORCE_SCALE
			
			# Build up force over time
			collision_force_multiplier = lerp(
				collision_force_multiplier,
				push_force,
				PUSH_FORCE_BUILDUP
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

func _integrate_forces(state: PhysicsDirectBodyState3D):
	if is_recovering or not target:
		return
		
	if is_growing:
		growth_timer += get_physics_process_delta_time()
		var t = growth_timer / GROWTH_DURATION
		if t <= 1.0:
			var growth = ease(t, GROWTH_CURVE)
			apply_physics_scale(lerp(INITIAL_SCALE, 1.0, growth))
			spring_stiffness_multiplier = lerp(INITIAL_SPRING_REDUCTION, 1.0, growth)
		else:
			is_growing = false
			apply_physics_scale(1.0)
			spring_stiffness_multiplier = 1.0
	
	# Calculate spring forces
	var to_target = target.global_position - global_position
	var distance = to_target.length()
	
	if distance > 0:
		var direction = to_target / distance
		var target_velocity = target.linear_velocity if target is RigidBody3D else Vector3.ZERO
		
		# Get chain scaling factors
		var factors = SpringPhysics.calculate_chain_factors(chain_index, chain_length)
		
		# Calculate and apply spring forces
		var spring_force = SpringPhysics.calculate_spring_force(
			global_position,
			target.global_position,
			target_distance,
			SPRING_STIFFNESS,
			factors.position_scale * factors.length_factor
		)
		
		var damping = SPRING_DAMPING_BASE + (SPRING_DAMPING_GROWTH * pow(factors.chain_factor, 0.8))
		var damping_force = SpringPhysics.calculate_damping_force(
			state.linear_velocity,
			target_velocity,
			damping,
			factors.position_scale
		)
		
		# Apply forces
		state.apply_central_force(spring_force)
		state.apply_central_force(damping_force)
		
		# Handle distance constraint
		var max_allowed_distance = target_distance * MAX_STRETCH
		if distance > max_allowed_distance:
			var correction = (distance - max_allowed_distance) * 0.3
			var correction_impulse = direction * correction * get_effective_mass()
			state.apply_central_impulse(correction_impulse)
	
	# Update cached velocity at the end
	cached_velocity = state.linear_velocity

# Update any remaining references to velocity to use cached_velocity instead
func init_with_scale_and_velocity(initial_scale: float, initial_velocity: Vector3) -> void:
	apply_physics_scale(initial_scale, true)
	cached_velocity = initial_velocity
