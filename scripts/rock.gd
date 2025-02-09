extends PhysicsObject

const MASS = 8.0  # Increased to match collision handler
const STATIC_FRICTION = 3.0  # Increased resistance
const DRAG_COEFFICIENT = 0.2  # Reduced from 0.8 to prevent rapid stopping
const MIN_VELOCITY = 0.1  # Only stop completely below this threshold

const SAFE_COLOR = Color(0.7, 0.7, 0.7, 1.0)
const DANGER_COLOR = Color(0.8, 0.2, 0.2, 1.0)
const DANGER_EMISSION = Color(0.6, 0.1, 0.1, 1.0)

const SPAWN_DURATION = 0.5
const SPAWN_HEIGHT = 1.5  # How high to rise from ground
const INITIAL_SCALE = 0.2  # Start very small

const BARRIER_BOUNCE_MULTIPLIER = 1.5  # Bounce more energetically off barriers
const BARRIER_PUSH_FORCE = 3.0  # Additional force away from barrier
const MIN_BOUNCE_SPEED = 2.0  # Ensure rocks always maintain some momentum after barrier hits

var is_dangerous: bool = false
var is_initialized: bool = false
var spawn_timer: float = 0.0
var is_spawning: bool = true
var spawn_start_pos: Vector3

# @onready var material = mesh_instance.mesh.surface_get_material(0)

func _ready():
	super()
	target_color = SAFE_COLOR
	current_color = SAFE_COLOR
	base_emission = Color(0.4, 0.4, 0.4, 1.0)  # Add subtle gray emission for rocks
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
		var smooth_t = ease(t, 0.7)  # Smooth easing for natural motion
		
		# Rise and scale effect
		var height_offset = lerp(-0.5, 0.0, smooth_t)
		position.y = spawn_start_pos.y - height_offset
		physics_pos = position  # Update physics position during spawn
		visual_pos = position  # Update visual position during spawn
		mesh_instance.scale = Vector3.ONE * lerp(INITIAL_SCALE, 1.0, smooth_t)
		mesh_instance.global_position = position  # Direct position during spawn
		
		if spawn_timer >= SPAWN_DURATION:
			finish_spawn()
			return
	
	# Apply gravity and physics from parent class
	super._physics_process(delta)
	
	# More controlled drag for moving rocks
	if velocity.length_squared() > MIN_VELOCITY * MIN_VELOCITY:
		velocity = velocity.lerp(Vector3.ZERO, DRAG_COEFFICIENT * delta)
	elif velocity.length_squared() > 0:
		velocity = Vector3.ZERO
	
	var collision = move_and_collide(velocity * delta)
	var collision_handler = get_node("/root/CollisionHandler")
	
	if collision and collision.get_collider():
		var collider = collision.get_collider()
		var impact_force = velocity.length()  # Calculate impact force for flash effect
		
		if collider.is_in_group("barrier"):
			# Special barrier bounce handling
			var impact_normal = collision.get_normal()
			var reflection = velocity.bounce(impact_normal)
			
			# Add extra force away from barrier
			var push_force = impact_normal * BARRIER_PUSH_FORCE
			velocity = (reflection * BARRIER_BOUNCE_MULTIPLIER) + push_force
			
			# Ensure minimum bounce speed
			if velocity.length() < MIN_BOUNCE_SPEED:
				velocity = velocity.normalized() * MIN_BOUNCE_SPEED
			
			# Handle impact flash with increased intensity for barrier collisions
			handle_impact(impact_force * 1.5)
		else:
			collision_handler.handle_collision(self, collider, collision.get_normal(), delta)
			# Handle impact flash for normal collisions
			handle_impact(impact_force)
	
	physics_pos = global_position
	
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
	base_emission = DANGER_EMISSION
	base_emission_energy = 1.0
	
	add_to_group("dangerous")
	collision_layer = 4 | 2  # Both dangerous AND physical
	collision_mask = 7  # Collide with everything
