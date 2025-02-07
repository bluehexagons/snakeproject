extends CharacterBody3D

const SPRING_STIFFNESS = 600.0
const SPRING_DAMPING = 2.0
const TARGET_DISTANCE = 0.6

var target: Node3D
var velocity_smoothing: Vector3

func _physics_process(delta):
	if not target:
		return
		
	var direction = target.global_position - global_position
	var target_pos = target.global_position - direction.normalized() * TARGET_DISTANCE
	
	# Spring force calculation
	var displacement = target_pos - global_position
	var spring_force = displacement * SPRING_STIFFNESS
	
	# Damping force to prevent oscillation
	var damping_force = -velocity * SPRING_DAMPING
	
	# Apply forces
	var acceleration = spring_force + damping_force
	velocity = velocity.lerp(acceleration * delta, 0.5)
	
	# Move segment
	move_and_slide()
