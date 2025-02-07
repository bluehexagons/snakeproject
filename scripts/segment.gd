extends CharacterBody3D

const SPRING_STIFFNESS = 2500.0
const SPRING_DAMPING = 4.01
const TARGET_DISTANCE = 0.666
const VELOCITY_SMOOTHING = 0.35

var target: Node3D
var smoothed_velocity: Vector3

func _physics_process(delta):
	if not target:
		return
		
	var direction = target.global_position - global_position
	var target_pos = target.global_position - direction.normalized() * TARGET_DISTANCE
	
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
