extends CharacterBody3D

const MASS = 5.0  # Heavier than segments

var physics_pos: Vector3
var visual_pos: Vector3

func _ready():
	physics_pos = global_position
	visual_pos = global_position

func _physics_process(delta):
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
		}
	}
