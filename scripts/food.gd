extends Area3D
class_name Food

const LEVITATION = 0.5
const HOVER_HEIGHT = 0.1
const HOVER_SPEED = 2.0
const ROTATION_SPEED = 2.0
const MIN_SCALE = 0.8
const MAX_SCALE = 1.2
const SCALE_SPEED = 1.3
const CONSUME_DURATION = 0.3
const CONSUME_SCALE_END = 0.1

var start_y: float
var time: float = 0.0
var is_consumed: bool = false
var consuming_target: Node3D = null
var consume_timer: float = 0.0
var initial_distance: float = 0.0

@onready var mesh = $MeshInstance3D

func _ready():
	start_y = position.y

func _process(delta):
	if is_consumed:
		consume_timer += delta
		var progress = consume_timer / CONSUME_DURATION
		if progress >= 1.0:
			queue_free()
			return
			
		if consuming_target:
			var t = ease(progress, 0.7)
			global_position = global_position.lerp(consuming_target.global_position, t)
			mesh.scale = Vector3.ONE * lerp(1.0, CONSUME_SCALE_END, t)
			mesh.rotate_y(ROTATION_SPEED * (1.0 + progress * 2.0) * delta)
		return
		
	time += delta
	position.y = start_y + LEVITATION + sin(time * HOVER_SPEED) * HOVER_HEIGHT
	rotate_y(ROTATION_SPEED * delta)
	var scale_factor = lerp(MIN_SCALE, MAX_SCALE, (sin(time * SCALE_SPEED) + 1.0) * 0.5)
	mesh.scale = Vector3.ONE * scale_factor

func eat() -> float:
	if is_consumed:
		return 0.0
	is_consumed = true
	consume_timer = 0.0
	var player = get_tree().get_first_node_in_group("player")
	if player:
		consuming_target = player
		initial_distance = global_position.distance_to(player.global_position)
	return 10.0

func dead_eat() -> float:
	if is_consumed:
		return 0.0
	queue_free()
	return 20.0

func is_available() -> bool:
	return !is_consumed
