extends CharacterBody3D

const SPEED = 5.0

var facing_direction: Vector3 = Vector3.FORWARD

func _physics_process(delta):
	var input_dir = Vector3.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.z = Input.get_axis("move_up", "move_down")
	
	if input_dir != Vector3.ZERO:
		input_dir = input_dir.normalized()  # Normalize before storing facing direction
		facing_direction = input_dir
		velocity = input_dir * SPEED
	else:
		velocity = Vector3.ZERO
		
	move_and_slide()
	
	# Check for food collection
	for area in get_tree().get_nodes_in_group("food"):
		if area.global_position.distance_to(global_position) < 0.75:
			area.queue_free()
			get_parent().on_food_collected()
