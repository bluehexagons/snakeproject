extends CharacterBody3D

const SPRING_STIFFNESS = 2500.0
const SPRING_DAMPING = 4.01
const TARGET_DISTANCE = 0.666
const VELOCITY_SMOOTHING = 0.35
const GROWTH_DURATION = 0.33
const INITIAL_SCALE = 0.2  # Increased from 0.01 to avoid disappearing

var target: Node3D
var smoothed_velocity: Vector3
var growth_timer: float = 0.0
var is_growing: bool = true
var current_scale: float = INITIAL_SCALE

@onready var mesh = $MeshInstance3D
@onready var collision = $CollisionShape3D

func _ready():
	# Set initial scale
	current_scale = INITIAL_SCALE
	update_scale(current_scale)

func update_scale(new_scale: float):
	mesh.scale = Vector3.ONE * new_scale
	collision.scale = Vector3.ONE * new_scale

func _physics_process(delta):
	if is_growing:
		growth_timer += delta
		var t = growth_timer / GROWTH_DURATION
		if t <= 1.0:
			var growth = ease(t, 0.7)
			current_scale = lerp(INITIAL_SCALE, 1.0, growth)
			update_scale(current_scale)
		else:
			is_growing = false
			current_scale = 1.0
			update_scale(current_scale)
	
	if not target:
		return
		
	# Calculate target distance based on current scales
	var adjusted_distance = TARGET_DISTANCE * (current_scale + (target.get("current_scale") if target.has_method("get_scale") else 1.0)) * 0.5
	
	var direction = target.global_position - global_position
	var target_pos = target.global_position - direction.normalized() * adjusted_distance
	
	# Spring force calculation
	var displacement = target_pos - global_position
	var spring_force = displacement * SPRING_STIFFNESS * delta
	
	# Damping force to prevent oscillation
	var damping_force = -velocity * SPRING_DAMPING * delta
	
	# Calculate target velocity
	var target_velocity = spring_force + damping_force
	
	# Smooth velocity transition
	smoothed_velocity = smoothed_velocity.lerp(target_velocity, VELOCITY_SMOOTHING)
	velocity = smoothed_velocity
	
	move_and_slide()
