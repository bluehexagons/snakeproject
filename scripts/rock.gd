extends PhysicsObject
class_name Rock

const SAFE_COLOR = Color(0.7, 0.7, 0.7, 1.0)
const DANGER_COLOR = Color(0.8, 0.2, 0.2, 1.0)
const DANGER_EMISSION = Color(0.6, 0.1, 0.1, 1.0)

const SPAWN_DURATION = 0.5
const SPAWN_HEIGHT = 1.5  # How high to rise from ground
const INITIAL_SCALE = 0.2  # Start very small
const BREAK_FORCE_THRESHOLD = 100.0  # Force required to break the rock

# Simplified segment interaction constants
const SEGMENT_FORCE_SCALE = 1.0    # Direct force transfer
const SEGMENT_SLIDE = 0.9          # High sliding retention
const MIN_RESPONSE = 10.0          # Minimum response threshold

# Simplify to just use parent collision handling with even lighter mass
const MASS_SCALING = 0.6  # Even lighter for better pushing

var is_dangerous: bool = false
var is_initialized: bool = false
var spawn_timer: float = 0.0
var is_spawning: bool = true
var spawn_start_pos: Vector3

@onready var mesh: MeshInstance3D = $MeshInstance3D

func _ready():
	super()
	material_type = PhysicsConstants.MATERIAL_ROCK
	
	# Configure RigidBody3D properties
	var settings = PhysicsConstants.RIGID_BODY_SETTINGS.rock
	linear_damp = settings.linear_damp
	angular_damp = settings.angular_damp
	collision_layer = PhysicsConstants.LAYER_PHYSICAL
	collision_mask = PhysicsConstants.LAYER_DEFAULT | PhysicsConstants.LAYER_PHYSICAL | PhysicsConstants.LAYER_PLAYER
	contact_monitor = true
	max_contacts_reported = PhysicsConstants.ROCK_MAX_CONTACTS
	continuous_cd = true
	
	# Set up physics material
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = settings.friction
	physics_material_override.bounce = settings.bounce
	physics_material_override.rough = true

func finish_spawn():
	is_spawning = false
	spawn_timer = SPAWN_DURATION
	position.y = spawn_start_pos.y
	physics_pos = position
	visual_pos = position
	mesh.scale = Vector3.ONE

# Replace initialize with setup_rock
func setup_rock(spawn_position: Vector3) -> void:
	is_initialized = true
	spawn_start_pos = spawn_position
	position = spawn_position
	position.y -= 0.5  # Start slightly below ground
	
	physics_pos = position
	visual_pos = position
	mesh.global_position = position
	mesh.scale = Vector3.ONE * INITIAL_SCALE
	
	# Set initial physics state
	apply_physics_scale(INITIAL_SCALE, true)
	cached_velocity = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if not is_initialized:
		return
		
	if is_spawning:
		spawn_animation(delta)
	else:
		physics_pos = global_position
		visual_pos = physics_pos

func _integrate_forces(state: PhysicsDirectBodyState3D):
	if is_spawning:
		return
	
	# Use PhysicsDirectBodyState3D for contact handling
	for i in state.get_contact_count():
		var contact_normal = state.get_contact_local_normal(i)
		var contact_position = state.get_contact_local_position(i)
		var contact_collider = state.get_contact_collider_object(i)
		
		# Apply ground friction
		if contact_normal.dot(Vector3.UP) > 0.7:
			state.apply_central_force(-state.linear_velocity * PhysicsConstants.ROCK_STATIC_FRICTION * mass)
		
		# Apply anti-sticking force using proper impulse
		if contact_normal.dot(Vector3.UP) > 0.1:  # Only push up if somewhat facing up
			state.apply_central_impulse(contact_normal * 0.1)
	
	# Use built-in velocity limiting
	var current_speed = state.linear_velocity.length()
	if current_speed > PhysicsConstants.ROCK_MAX_SPEED:
		state.linear_velocity = state.linear_velocity * (PhysicsConstants.ROCK_MAX_SPEED / current_speed)

	# Update cached velocity
	cached_velocity = state.linear_velocity

func spawn_animation(delta: float) -> void:
	spawn_timer = min(spawn_timer + delta, SPAWN_DURATION)
	var t = spawn_timer / SPAWN_DURATION
	var smooth_t = ease(t, 0.7)
	
	var height_offset = lerp(-0.5, 0.0, smooth_t)
	position.y = spawn_start_pos.y - height_offset
	mesh.scale = Vector3.ONE * lerp(INITIAL_SCALE, 1.0, smooth_t)
	
	if spawn_timer >= SPAWN_DURATION:
		finish_spawn()

func _process(delta):
	if !is_initialized or is_spawning:
		mesh.global_position = position
		return
	
	super._process(delta)

func get_save_data() -> Dictionary:
	var base_data = super.get_save_data()
	base_data["is_dangerous"] = is_dangerous
	return base_data

func make_dangerous():
	is_dangerous = true
	target_color = DANGER_COLOR
	current_color = DANGER_COLOR  # Immediate color change
	state_color = DANGER_COLOR    # Add this line
	base_emission = DANGER_EMISSION
	state_emission = DANGER_EMISSION  # Add this line
	base_emission_energy = 1.0
	state_emission_energy = 1.0   # Add this line
	apply_color(DANGER_COLOR, DANGER_EMISSION, 1.0)  # Force immediate update
	
	add_to_group("dangerous")
	collision_layer = 4 | 2  # Both dangerous AND physical
	collision_mask = 7  # Collide with everything

func dead_eat() -> float:
	queue_free()
	return 2.0

func break_rock():
	# Add visual and sound effects for breaking the rock
	# For now, just queue_free the rock
	queue_free()
