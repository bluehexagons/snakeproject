
extends CharacterBody3D

const SPEED = 5.0

func _physics_process(delta):
	var input_dir = Vector3.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.z = Input.get_axis("move_up", "move_down")
	input_dir = input_dir.normalized()
	
	velocity = input_dir * SPEED
	move_and_slide()
