extends CharacterBody3D

const MASS = 8.0  # Increased to match collision handler
const STATIC_FRICTION = 3.0  # Increased resistance
const DRAG_COEFFICIENT = 0.2  # Reduced from 0.8 to prevent rapid stopping
const MIN_VELOCITY = 0.1  # Only stop completely below this threshold

const SAFE_COLOR = Color(0.7, 0.7, 0.7, 1.0)
const DANGER_COLOR = Color(0.8, 0.2, 0.2, 1.0)
const DANGER_EMISSION = Color(0.6, 0.1, 0.1, 1.0)

var physics_pos: Vector3
var visual_pos: Vector3
var is_dangerous: bool = false

@onready var mesh_instance = $MeshInstance3D
@onready var material = mesh_instance.mesh.surface_get_material(0)

func _ready():
	physics_pos = global_position
	visual_pos = global_position
	material = material.duplicate()
	mesh_instance.mesh.surface_set_material(0, material)

func _physics_process(delta):
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
