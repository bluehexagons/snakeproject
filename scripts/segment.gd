extends CharacterBody3D

const SPRING_STIFFNESS = 850.0  # Significantly reduced from 2500.0
const SPRING_DAMPING = 20.0  # Increased damping
const TARGET_DISTANCE = 0.8  # Increased spacing
const VELOCITY_SMOOTHING = 0.2
const GROWTH_DURATION = 0.33
const INITIAL_SCALE = 0.2
const MAX_SEGMENT_SPEED = 40.0  # Reduced max speed
const FOLLOW_STRENGTH = 0.8  # How strongly to match target's velocity
const MIN_FOLLOW_DISTANCE = 0.1  # Distance at which to start matching velocity
const INITIAL_SPRING_REDUCTION = 0.3  # Reduce spring force when first spawned
const SAFE_COLOR = Color(0.3, 0.8, 0.4, 0.9)
const DANGER_COLOR = Color(0.9, 0.2, 0.2, 0.9)
const DANGER_EMISSION = Color(0.8, 0.1, 0.1, 1.0)
const COLOR_CHANGE_SPEED = 5.0

var target: Node3D
var smoothed_velocity: Vector3
var growth_timer: float = 0.0
var is_growing: bool = true
var current_scale: float = INITIAL_SCALE
var spawn_timer: float = 0.5  # Time to use reduced spring force
var is_dangerous: bool = false
var target_color: Color = SAFE_COLOR
var current_color: Color = SAFE_COLOR

var physics_pos: Vector3
var visual_pos: Vector3

@onready var mesh = $MeshInstance3D
@onready var collision = $CollisionShape3D
@onready var material = mesh.mesh.surface_get_material(0)

func _ready():
	# Set initial scale and positions
	current_scale = INITIAL_SCALE
	update_scale(current_scale)
	# Initialize both positions to spawn position to prevent interpolation from origin
	physics_pos = global_position
	visual_pos = global_position
	# Ensure mesh starts at the correct position
	mesh.global_position = global_position
	
	# Important: Get original material and create a unique instance
	var original_material = mesh.mesh.surface_get_material(0)
	material = original_material.duplicate()
	mesh.mesh.surface_set_material(0, material)
	
	# Set initial colors
	current_color = SAFE_COLOR
	target_color = SAFE_COLOR
	material.albedo_color = current_color
	material.emission = Color(0.2, 0.6, 0.3, 1.0)
	material.emission_enabled = true

func update_scale(new_scale: float):
	mesh.scale = Vector3.ONE * new_scale
	collision.scale = Vector3.ONE * new_scale

func init_with_growth(initial_growth: float):
	growth_timer = GROWTH_DURATION * initial_growth
	current_scale = lerp(INITIAL_SCALE, 1.0, ease(initial_growth, 0.7))
	is_growing = initial_growth < 1.0
	update_scale(current_scale)

func get_save_data() -> Dictionary:
	return {
		"position": {
			"x": global_position.x,
			"y": global_position.y,
			"z": global_position.z
		},
		"velocity": {
			"x": velocity.x,
			"y": velocity.y,
			"z": velocity.z
		},
		"smoothed_velocity": {
			"x": smoothed_velocity.x,
			"y": smoothed_velocity.y,
			"z": smoothed_velocity.z
		},
		"growth": min(growth_timer / GROWTH_DURATION, 1.0),
		"current_scale": current_scale,
		"is_dangerous": is_dangerous,
		"current_color": {
			"r": current_color.r,
			"g": current_color.g,
			"b": current_color.b,
			"a": current_color.a
		}
	}

func init_from_save_data(data: Dictionary):
	if data.has("velocity"):
		velocity = Vector3(data.velocity.x, data.velocity.y, data.velocity.z)
	if data.has("smoothed_velocity"):
		smoothed_velocity = Vector3(data.smoothed_velocity.x, data.smoothed_velocity.y, data.smoothed_velocity.z)
	
	# Initialize transforms after velocity
	physics_pos = global_position
	visual_pos = global_position
	
	# Initialize danger state
	if data.has("is_dangerous") and data.is_dangerous:
		become_dangerous()
	elif data.has("current_color"):
		current_color = Color(
			data.current_color.r,
			data.current_color.g,
			data.current_color.b,
			data.current_color.a
		)
		material.albedo_color = current_color
	
	# Initialize growth last
	init_with_growth(data.growth)

func _physics_process(delta):
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
	
	if not target:
		return
		
	# Update spawn timer
	spawn_timer = max(0.0, spawn_timer - delta)
	
	# Calculate spring force with spawn reduction
	var spring_multiplier = lerp(INITIAL_SPRING_REDUCTION, 1.0, 1.0 - (spawn_timer / 0.5))
	var current_stiffness = SPRING_STIFFNESS * spring_multiplier
	
	# Calculate target distance based on current scales
	var adjusted_distance = TARGET_DISTANCE * (current_scale + (target.get("current_scale") if target.has_method("get_scale") else 1.0)) * 0.5
	
	var to_target = target.global_position - global_position
	var current_distance = to_target.length()
	
	if current_distance > 0:
		var target_direction = to_target.normalized()
		
		# Calculate desired position
		var desired_pos = target.global_position - target_direction * adjusted_distance
		var to_desired = desired_pos - global_position
		
		# Calculate forces with spawn adjustment
		var spring_force = to_desired * current_stiffness * delta
		var damping_force = -velocity * SPRING_DAMPING * delta
		
		# Apply forces only to self
		velocity += spring_force + damping_force
		
		# Match target's velocity when close enough
		if current_distance < adjusted_distance + MIN_FOLLOW_DISTANCE:
			velocity = velocity.lerp(target.velocity, FOLLOW_STRENGTH * delta)
	
	# Limit maximum speed
	velocity = velocity.limit_length(MAX_SEGMENT_SPEED)
	
	var movement_collision = move_and_collide(velocity * delta)
	var collision_handler = get_node("/root/CollisionHandler")
	if movement_collision:
		var collider = movement_collision.get_collider()
		if collider and collider.is_in_group("barrier"):
			become_dangerous()
		else:
			collision_handler.handle_collision(self, collider, movement_collision.get_normal(), delta)
	
	# Handle proximity with other segments
	var nearby_segments = get_tree().get_nodes_in_group("segment")
	collision_handler.handle_proximity(self, nearby_segments, delta)
	
	# Store physics state
	physics_pos = global_position

	# Update color
	if material:
		current_color = current_color.lerp(target_color, delta * COLOR_CHANGE_SPEED)
		material.albedo_color = current_color
		if is_dangerous:
			material.emission = DANGER_EMISSION
		else:
			material.emission = Color(0.2, 0.6, 0.3, 1.0)

func _process(delta):
	# Interpolate visual position between physics updates
	var fraction = Engine.get_physics_interpolation_fraction()
	visual_pos = physics_pos.lerp(global_position, fraction)
	
	# Update visual representation
	mesh.global_position = visual_pos
	
	# Keep collision shape at physics position
	collision.global_position = global_position

func handle_impact(force: float) -> void:
	var material = mesh.mesh.surface_get_material(0)
	if material:
		ImpactFlash.flash_material(material, force)

func become_dangerous():
	if not is_dangerous:  # Only change state if not already dangerous
		is_dangerous = true
		target_color = DANGER_COLOR
		current_color = DANGER_COLOR  # Set current color too for immediate effect
		
		if material:
			material.albedo_color = DANGER_COLOR
			material.emission = DANGER_EMISSION
			material.emission_enabled = true
		
		add_to_group("dangerous")
		remove_from_group("segment")
		# Ensure material color updates immediately
		material.albedo_color = DANGER_COLOR
		
		# Visual feedback
		var tween = create_tween()
		tween.tween_property(mesh, "scale", mesh.scale * 1.3, 0.1)
		tween.tween_property(mesh, "scale", mesh.scale, 0.2)
		
		# Emission pulse
		var flash_material = material.duplicate()
		mesh.material_override = flash_material
		flash_material.emission_energy_multiplier = 4.0
		
		tween.parallel().tween_property(flash_material, "emission_energy_multiplier", 1.0, 0.3)
		tween.tween_callback(func(): mesh.material_override = null)
