extends Area3D
class_name Food

const LEVITATION: float = 0.5
const HOVER_HEIGHT: float = 0.1
const HOVER_SPEED: float = 2.0
const ROTATION_SPEED: float = 2.0
const MIN_SCALE: float = 0.8
const MAX_SCALE: float = 1.2
const SCALE_SPEED: float = 1.3
const CONSUME_DURATION: float = 0.3
const CONSUME_SCALE_END: float = 0.1

var start_y: float
var time: float = 0.0
var is_consumed: bool = false
var consuming_target: Node3D = null
var consume_timer: float = 0.0

@onready var mesh: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	start_y = position.y

func _process(delta: float) -> void:
	if is_consumed:
		consume_timer += delta
		var progress = consume_timer / CONSUME_DURATION
		if progress >= 1.0:
			queue_free()
			return
			
		if is_instance_valid(consuming_target):
			var t = ease(progress, 0.7)
			global_position = global_position.lerp(consuming_target.global_position, t)
			mesh.scale = Vector3.ONE * lerp(1.0, CONSUME_SCALE_END, t)
			mesh.rotate_y(ROTATION_SPEED * (1.0 + progress * 2.0) * delta)
		else:
			queue_free()
		return
		
	time += delta
	position.y = start_y + LEVITATION + sin(time * HOVER_SPEED) * HOVER_HEIGHT
	rotate_y(ROTATION_SPEED * delta)
	var scale_factor = lerp(MIN_SCALE, MAX_SCALE, (sin(time * SCALE_SPEED) + 1.0) * 0.5)
	mesh.scale = Vector3.ONE * scale_factor

func eat(target: Node3D) -> float:
	if is_consumed:
		return 0.0
	is_consumed = true
	consume_timer = 0.0
	consuming_target = target
	return 10.0

func dead_eat() -> float:
	if is_consumed:
		return 0.0
	queue_free()
	return 20.0

func is_available() -> bool:
	return not is_consumed
