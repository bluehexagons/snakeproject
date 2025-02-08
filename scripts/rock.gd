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

var spawn_timer: float = 0.0
var is_spawning: bool = true
var spawn_start_pos: Vector3

@onready var mesh_instance = $MeshInstance3D
@onready var material = mesh_instance.mesh.surface_get_material(0)

func _ready():
	if physics_pos == Vector3.ZERO:  # If not set during spawn
		physics_pos = global_position
	if visual_pos == Vector3.ZERO:  # If not set during spawn
		visual_pos = global_position
	
	material = material.duplicate()
	mesh_instance.mesh.surface_set_material(0, material)
	
	# Setup spawn animation
	spawn_start_pos = global_position
	position.y -= 0.5  # Start slightly below ground
	mesh_instance.scale = Vector3.ONE * INITIAL_SCALE
	mesh_instance.global_position = visual_pos

func _physics_process(delta):
	if is_spawning:
		spawn_timer = min(spawn_timer + delta, SPAWN_DURATION)
		var t = spawn_timer / SPAWN_DURATION
		var smooth_t = ease(t, 0.7)  # Smooth easing for natural motion
		
		# Rise and scale effect
		var height_offset = lerp(-0.5, 0.0, smooth_t)
		position.y = spawn_start_pos.y + height_offset
		mesh_instance.scale = Vector3.ONE * lerp(INITIAL_SCALE, 1.0, smooth_t)
		
		if spawn_timer >= SPAWN_DURATION:
			is_spawning = false
			position.y = spawn_start_pos.y  # Ensure final position is correct
			return
	
	# Only process physics after spawning is complete
	if !is_spawning:
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
			collision_handler.handle_collision(self, collider, collision.get_normal(), delta)
		
		physics_pos = global_position

func _process(delta):
	if is_spawning:
		mesh_instance.global_position = position
		return
		
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
	collision_layer = 4  # Layer for dangerous objects
	collision_mask = 3   # Collide with player and segments
