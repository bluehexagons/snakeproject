extends CharacterBody3D

const SPEED = 5.0
const SEGMENT_SCENE = preload("res://scenes/segment.tscn")
const LUNGE_FORCE = 0.8  # How far to push player forward
const SEGMENT_PUSHBACK = 0.5  # How far to push first segment back

var facing_direction: Vector3 = Vector3.FORWARD
var segments: Array[CharacterBody3D] = []

@onready var head_mesh = $MeshInstance3D

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
	
	# Update head rotation
	if velocity != Vector3.ZERO:
		# Get direction to first segment or use velocity if no segments
		var look_direction = -facing_direction
		if not segments.is_empty():
			look_direction = (segments[0].global_position - global_position).normalized()
		
		# Calculate rotation to face movement direction, but tilt based on segment position
		var forward = velocity.normalized()
		var right = forward.cross(Vector3.UP)
		var up = right.cross(forward)  # Corrected up vector
		
		# Create basis from our vectors
		var target_basis = Basis(right, up, -forward)  # Note: forward is negated to face movement
		
		# Add tilt based on look_direction
		var tilt_angle = look_direction.y * 0.5  # Adjust tilt strength
		var tilt = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-15 + tilt_angle), 0, 0)))
		target_basis = target_basis * tilt.basis
		
		# Smoothly interpolate rotation
		head_mesh.basis = head_mesh.basis.slerp(target_basis, delta * 15.0)  # Increased interpolation speed
	
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
	
	# Push player forward
	global_position += facing_direction * LUNGE_FORCE
	
	if segments.is_empty():
		# If this is the first segment, place it behind player
		segment.global_position = global_position - facing_direction * 2.0
		segment.target = self
	else:
		# Push first existing segment back
		var first_segment = segments[0]
		var push_dir = (first_segment.global_position - global_position).normalized()
		first_segment.global_position += push_dir * SEGMENT_PUSHBACK
		
		# Place new segment between player and pushed-back segment
		segment.global_position = global_position + (first_segment.global_position - global_position) * 0.5
		
		# Update targeting
		segment.target = self
		first_segment.target = segment
	
	segments.push_front(segment)

func get_segment_positions() -> Array:
	var positions = []
	for segment in segments:
		positions.append({
			"x": segment.global_position.x,
			"y": segment.global_position.y,
			"z": segment.global_position.z
		})
	return positions
