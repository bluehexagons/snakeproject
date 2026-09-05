extends Camera3D
class_name GameCamera

var is_third_person: bool = false

func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	size = 26.0
	position = Vector3(0, 24, 0)
	rotation_degrees = Vector3(-90, 0, 0)

func _process(delta: float) -> void:
	# Keep the arena and all pickups visible; camera motion must not rotate
	# the control axes as the player turns.
	var viewport_size = get_viewport().get_visible_rect().size
	var aspect = viewport_size.x / maxf(viewport_size.y, 1.0)
	size = 26.0 * maxf(1.0 / aspect, 1.0)
	var blend = 1.0 - exp(-6.0 * delta)
	var destination = Vector3(0, 24, 16) if is_third_person else Vector3(0, 24, 0)
	position = position.lerp(destination, blend)
	var angle = -56.3 if is_third_person else -90.0
	rotation.x = lerp_angle(rotation.x, deg_to_rad(angle), blend)

func toggle_view() -> void:
	is_third_person = not is_third_person
