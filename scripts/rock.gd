extends PhysicsObject
class_name Rock

const SAFE_COLOR = Color(0.7, 0.7, 0.7, 1.0)
const DANGER_COLOR = Color(0.8, 0.2, 0.2, 1.0)
const DANGER_EMISSION = Color(0.6, 0.1, 0.1, 1.0)

const SPAWN_DURATION = 0.5
const SPAWN_HEIGHT = 1.5  # How high to rise from ground
const INITIAL_SCALE = 0.2  # Start very small
const BREAK_FORCE_THRESHOLD = 100.0  # Force required to break the rock

var is_dangerous: bool = false
var is_initialized: bool = false
var spawn_timer: float = 0.0
var is_spawning: bool = true
var spawn_start_pos: Vector3

# @onready var material = mesh_instance.mesh.surface_get_material(0)

func _ready():
	super()
	mass = 8.0
	drag_coefficient = PhysicsConstants.ROCK_DRAG
	max_speed = PhysicsConstants.ROCK_MAX_SPEED
	static_friction = PhysicsConstants.ROCK_STATIC_FRICTION
	dynamic_friction = PhysicsConstants.ROCK_DYNAMIC_FRICTION
	rolling_friction = PhysicsConstants.ROCK_ROLLING_FRICTION
	target_color = SAFE_COLOR
	current_color = SAFE_COLOR
	base_emission = Color(0.2, 0.2, 0.2, 1.0) 
	base_emission_energy = 0.2  # Low base emission energy

func finish_spawn():
	is_spawning = false
	spawn_timer = SPAWN_DURATION
	position.y = spawn_start_pos.y
	physics_pos = position
	visual_pos = position
	mesh_instance.scale = Vector3.ONE

func initialize(spawn_position: Vector3):
	is_initialized = true
	spawn_start_pos = spawn_position
	position = spawn_position
	position.y -= 0.5  # Start slightly below ground
	
	physics_pos = position
	visual_pos = position
	mesh_instance.global_position = position
	mesh_instance.scale = Vector3.ONE * INITIAL_SCALE

func _physics_process(delta):
	if !is_initialized:
		return
		
	if is_spawning:
		spawn_timer = min(spawn_timer + delta, SPAWN_DURATION)
		var t = spawn_timer / SPAWN_DURATION
		var smooth_t = ease(t, 0.7) 
		
		# Rise and scale effect
		var height_offset = lerp(-0.5, 0.0, smooth_t)
		position.y = spawn_start_pos.y - height_offset
		physics_pos = position  # Update physics position during spawn
		visual_pos = position  # Update visual position during spawn
		mesh_instance.scale = Vector3.ONE * lerp(INITIAL_SCALE, 1.0, smooth_t)
		mesh_instance.global_position = position  # Direct position during spawn
		
		if spawn_timer >= SPAWN_DURATION:
			finish_spawn()
	
	var collision = move_and_collide(velocity * delta)
	var collision_handler = get_node("/root/CollisionHandler")
	
	if collision and collision.get_collider():
		var force = collision.get_remainder().length() * mass
		if force > BREAK_FORCE_THRESHOLD:
			break_rock()
		else:
			collision_handler.handle_collision(self, collision.get_collider(), collision.get_normal(), delta)
	
	super._physics_process(delta)

func _process(delta):
	if !is_initialized or is_spawning:
		mesh_instance.global_position = position
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
