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
var current_scale: float = 1.0  # Add this for consistent scaling behavior

var physics_pos: Vector3
var physics_basis: Basis
var visual_pos: Vector3
var visual_basis: Basis

@onready var head_mesh = $MeshInstance3D

func _ready():
	physics_pos = global_position
	visual_pos = global_position
	physics_basis = head_mesh.basis
	visual_basis = head_mesh.basis

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
		var right = forward.cross(Vector3.UP).normalized()  # Normalize the right vector
		var up = right.cross(forward).normalized()  # Normalize the up vector
		
		# Create and normalize the basis
		var target_basis = Basis(right, up, -forward).orthonormalized()
		var tilt = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-15 * speed_factor), 0, 0)))
		target_basis = (target_basis * tilt.basis).orthonormalized()
		
		# Apply the rotation with normalized basis
		head_mesh.basis = head_mesh.basis.slerp(target_basis, delta * ROTATION_SPEED).orthonormalized()
	
	# Store physics state
	physics_pos = global_position
	physics_basis = head_mesh.basis
	
	# Food collection
	for area in get_tree().get_nodes_in_group("food"):
		if area.global_position.distance_to(global_position) < 0.75:
			area.queue_free()
			add_segment()
			get_parent().on_food_collected()
			# Add extra momentum when collecting food
			velocity += facing_direction * LUNGE_FORCE

func _process(delta):
	# Interpolate visual position between physics updates
	var fraction = Engine.get_physics_interpolation_fraction()
	visual_pos = physics_pos.lerp(global_position, fraction)
	visual_basis = physics_basis.slerp(head_mesh.basis, fraction)
	
	# Update visual representation
	head_mesh.global_position = visual_pos
	head_mesh.basis = visual_basis

func add_segment():
	var segment = SEGMENT_SCENE.instantiate()
	segment.set_script(load("res://scripts/segment.gd"))
	
	# Calculate spawn position before adding to scene tree
	var spawn_pos: Vector3
	if segments.is_empty():
		spawn_pos = global_position - facing_direction * (1.0 + segment.INITIAL_SCALE)
	else:
		spawn_pos = global_position - facing_direction * segment.INITIAL_SCALE * 2.0
	
	# Set initial position before adding to scene tree
	segment.global_position = spawn_pos
	segment.physics_pos = spawn_pos
	segment.visual_pos = spawn_pos
	
	get_parent().add_child(segment)
	
	# Update targeting
	if segments.is_empty():
		segment.target = self
	else:
		segment.target = self
		segments[0].target = segment
	
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
