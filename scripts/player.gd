extends CharacterBody3D

const SPEED = 5.0
const SEGMENT_SCENE = preload("res://scenes/segment.tscn")

var facing_direction: Vector3 = Vector3.FORWARD
var segments: Array[CharacterBody3D] = []

func _physics_process(delta):
	var input_dir = Vector3.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.z = Input.get_axis("move_up", "move_down")
	
	if input_dir != Vector3.ZERO:
		input_dir = input_dir.normalized()
		facing_direction = input_dir
		velocity = input_dir * SPEED
	else:
		velocity = Vector3.ZERO
		
	move_and_slide()
	
	# Check for food collection
	for area in get_tree().get_nodes_in_group("food"):
		if area.global_position.distance_to(global_position) < 0.75:
			area.queue_free()
			add_segment()
			get_parent().on_food_collected()

func add_segment():
	var segment = SEGMENT_SCENE.instantiate()
	segment.set_script(load("res://scripts/segment.gd"))
	get_parent().add_child(segment)
	
	# Set the segment's target
	if segments.is_empty():
		segment.target = self
	else:
		segment.target = segments[-1]
	
	# Place segment behind its target
	var spawn_pos: Vector3
	if segments.is_empty():
		spawn_pos = global_position - facing_direction
	else:
		var last_segment = segments[-1]
		spawn_pos = last_segment.global_position - facing_direction
	
	segment.global_position = spawn_pos
	segments.append(segment)

func get_segment_positions() -> Array:
	var positions = []
	for segment in segments:
		positions.append({
			"x": segment.global_position.x,
			"y": segment.global_position.y,
			"z": segment.global_position.z
		})
	return positions
