extends Camera3D
class_name GameCamera

const ARENA_FRAME_SIZE = 26.0

var is_third_person: bool = false

func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	size = ARENA_FRAME_SIZE
	position = Vector3(0, 24, 0)
	rotation_degrees = Vector3(-90, 0, 0)

func fit_arena(play_area: Rect2) -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	var frame_side = maxf(1.0, minf(play_area.size.x, play_area.size.y))
	var units_per_pixel = ARENA_FRAME_SIZE / frame_side
	size = viewport_size.y * units_per_pixel
	v_offset = (play_area.get_center().y - viewport_size.y * 0.5) * units_per_pixel

func _process(delta: float) -> void:
	# Keep the control axes fixed as the view tilts.
	var blend = 1.0 - exp(-6.0 * delta)
	var destination = Vector3(0, 24, 16) if is_third_person else Vector3(0, 24, 0)
	position = position.lerp(destination, blend)
	var angle = -56.3 if is_third_person else -90.0
	rotation.x = lerp_angle(rotation.x, deg_to_rad(angle), blend)

func toggle_view() -> void:
	is_third_person = not is_third_person
