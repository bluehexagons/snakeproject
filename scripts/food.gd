extends Area3D

const LEVITATION = 0.1
const HOVER_HEIGHT = 0.1
const HOVER_SPEED = 2.0
const ROTATION_SPEED = 2.0
const MIN_SCALE = 0.8  # Prevent complete shrinking
const MAX_SCALE = 1.2  # Allow slight growth
const SCALE_SPEED = 1.3  # How fast the scaling happens

var start_y: float
var time: float = 0.0

@onready var mesh = $MeshInstance3D

func _ready():
	start_y = position.y

func _process(delta):
	time += delta
	
	# Smooth hovering motion
	position.y = start_y + LEVITATION + sin(time * HOVER_SPEED) * HOVER_HEIGHT
	
	# Gentle rotation
	rotate_y(ROTATION_SPEED * delta)
	
	# Pulsing scale that never goes to zero
	var scale_factor = lerp(MIN_SCALE, MAX_SCALE, (sin(time * SCALE_SPEED) + 1.0) * 0.5)
	mesh.scale = Vector3.ONE * scale_factor

func eat() -> float:
	queue_free()
	return 10.0

func dead_eat() -> float:
	queue_free()
	return 20.0
