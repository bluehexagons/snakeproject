extends Label
class_name ScorePopup

const LIFETIME := 0.8

var camera: Camera3D
var world_position: Vector3
var points := 0
var elapsed := 0.0

func can_combine(world_point: Vector3) -> bool:
	return elapsed < 0.45 and world_position.distance_squared_to(world_point) < 2.56

func add_points(amount: int) -> void:
	points += amount
	text = "+%d" % points
	reset_size()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= LIFETIME:
		queue_free()
		return

	var lift := lerpf(24.0, 50.0, ease(elapsed / LIFETIME, 0.5))
	var screen_position := camera.unproject_position(world_position) - Vector2(0.0, lift)
	position = (screen_position - size * 0.5).round()
	modulate.a = smoothstep(0.0, 0.08, elapsed) * (1.0 - smoothstep(0.45, LIFETIME, elapsed))
