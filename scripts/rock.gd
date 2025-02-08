extends CharacterBody3D

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

var physics_pos: Vector3
var visual_pos: Vector3
var is_dangerous: bool = false
var is_initialized: bool = false

var spawn_timer: float = 0.0
var is_spawning: bool = true
var spawn_start_pos: Vector3

@onready var mesh_instance = $MeshInstance3D
@onready var material = mesh_instance.mesh.surface_get_material(0)

func _ready():
	material = material.duplicate()
	mesh_instance.mesh.surface_set_material(0, material)

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
	
	# Only process physics after spawning is complete
	# Apply gravity
	if position.y > PhysicsConstants.GROUND_LEVEL:
		velocity.y -= PhysicsConstants.GRAVITY * delta
	elif position.y < PhysicsConstants.GROUND_LEVEL:
		position.y = PhysicsConstants.GROUND_LEVEL
		if velocity.y < 0:
			velocity.y = -velocity.y * PhysicsConstants.BOUNCE_DAMPENING
			if abs(velocity.y) < 0.1:
				velocity.y = 0
	
	# More controlled drag for moving rocks
	if velocity.length_squared() > MIN_VELOCITY * MIN_VELOCITY:
		velocity = velocity.lerp(Vector3.ZERO, DRAG_COEFFICIENT * delta)
	elif velocity.length_squared() > 0:
		velocity = Vector3.ZERO
	
	var collision = move_and_collide(velocity * delta)
	var collision_handler = get_node("/root/CollisionHandler")
	
	if collision:
		var collider = collision.get_collider()
		if collider:  # Make sure there's actually a collider
			collision_handler.handle_collision(self, collider, collision.get_normal(), delta)
			
			# Add direct impulse response for better feel
			var impact_normal = collision.get_normal()
			var impact_speed = velocity.length()
			var reflection = velocity.bounce(impact_normal)
			velocity = reflection * 0.8  # Reduce bounce by 20%
	
	physics_pos = global_position

func _process(delta):
	if !is_initialized:
		return
		
	if is_spawning:
		# During spawn animation, position is directly set
		mesh_instance.global_position = position
		return
		
	# After spawn, use normal interpolation
	var fraction = Engine.get_physics_interpolation_fraction()
	visual_pos = physics_pos.lerp(global_position, fraction)
	$MeshInstance3D.global_position = visual_pos

func get_save_data() -> Dictionary:
	var data = {
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
		"is_dangerous": is_dangerous
	}
	return data

func handle_impact(force: float) -> void:
	var material = $MeshInstance3D.mesh.surface_get_material(0)
	if material:
		ImpactFlash.flash_material(material, force)

func make_dangerous():
	is_dangerous = true
	add_to_group("dangerous")
	material.albedo_color = DANGER_COLOR
	material.emission = DANGER_EMISSION
	material.emission_enabled = true
	# Update collision layers to match other dangerous objects
	# Layer 4: dangerous objects
	# Layer 2: normal physics objects
	# Mask 7: collide with everything (players, segments, other rocks)
	collision_layer = 4 | 2  # Both dangerous AND physical
	collision_mask = 7  # Collide with everything
