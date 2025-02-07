extends CharacterBody3D

const MAX_SPEED = 100000.0
const ACCELERATION = 40.0
const DRAG_COEFFICIENT = 0.05
const MIN_SPEED_THRESHOLD = 0.1
const ROTATION_SPEED = 15.0
const SEGMENT_SCENE = preload("res://scenes/segment.tscn")
const LUNGE_FORCE = 0.2
const SEGMENT_PUSHBACK = 0.1
const VELOCITY_SMOOTHING = 0.15

var facing_direction: Vector3 = Vector3.FORWARD
var segments: Array[CharacterBody3D] = []
var target_velocity: Vector3 = Vector3.ZERO
var smoothed_velocity: Vector3 = Vector3.ZERO

@onready var head_mesh = $MeshInstance3D

func _physics_process(delta):
	var input_dir = Vector3.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.z = Input.get_axis("move_up", "move_down")
	
	if input_dir != Vector3.ZERO:
		input_dir = input_dir.normalized()
		 # Calculate target velocity
		target_velocity += input_dir * ACCELERATION * delta
		target_velocity = target_velocity.limit_length(MAX_SPEED)
	
	# Apply drag to target velocity
	var speed = target_velocity.length()
	if speed > 0:
		var drag_force = -target_velocity.normalized() * speed * speed * DRAG_COEFFICIENT * delta
		target_velocity += drag_force
		
		if target_velocity.length() < MIN_SPEED_THRESHOLD:
			target_velocity = Vector3.ZERO
	
	# Smooth velocity transition
	smoothed_velocity = smoothed_velocity.lerp(target_velocity, VELOCITY_SMOOTHING)
	velocity = smoothed_velocity
	
	if velocity != Vector3.ZERO:
		facing_direction = velocity.normalized()
	
	move_and_slide()
	
	# Update head rotation
	if velocity != Vector3.ZERO:
		var speed_factor = clamp(velocity.length() / MAX_SPEED, 0.0, 1.0)
		var forward = velocity.normalized()
		var right = forward.cross(Vector3.UP)
		var up = right.cross(forward)
		
		var target_basis = Basis(right, up, -forward)
		var tilt = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-15 * speed_factor), 0, 0)))
		target_basis = target_basis * tilt.basis
		
		head_mesh.basis = head_mesh.basis.slerp(target_basis, delta * ROTATION_SPEED)
	
	# Food collection
	for area in get_tree().get_nodes_in_group("food"):
		if area.global_position.distance_to(global_position) < 0.75:
			area.queue_free()
			add_segment()
			get_parent().on_food_collected()
			# Add extra momentum when collecting food
			velocity += facing_direction * LUNGE_FORCE

func add_segment():
	var segment = SEGMENT_SCENE.instantiate()
	segment.set_script(load("res://scripts/segment.gd"))
	get_parent().add_child(segment)
	
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
