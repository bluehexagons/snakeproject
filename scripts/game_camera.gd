extends Camera3D

const TOP_DOWN_HEIGHT = 20.0  # Increased to maintain good view
const THIRD_PERSON_HEIGHT = 15.0
const THIRD_PERSON_DISTANCE = 15.0
const LOOK_AHEAD_DISTANCE = 8.0
const MIN_LOOK_AHEAD = 2.0
const INITIAL_SIZE = 30.0
const FINAL_SIZE = 15.0
const ZOOM_DURATION = 1.5
const ZOOM_DELAY = 0.25

const TRANSITION_SPEED = 2.0
const SMOOTHING = 5.0
const ROTATION_SMOOTHING = 3.0
const LAG_SPEED = 2.5
const PREDICTION_STRENGTH = 0.3

var is_third_person: bool = false
var camera_transition: float = 0.0
var predicted_direction: Vector3 = Vector3.FORWARD
var look_target_pos: Vector3
var current_size: float = INITIAL_SIZE
var zoom_timer: float = 0.0
var is_zooming: bool = false

func _ready() -> void:
	rotation_degrees.x = -90
	position.y = TOP_DOWN_HEIGHT  # Start at TOP_DOWN_HEIGHT instead of a separate INITIAL_HEIGHT
	look_target_pos = Vector3.ZERO
	size = INITIAL_SIZE
	
	await get_tree().create_timer(ZOOM_DELAY).timeout
	is_zooming = true

func _process(delta: float) -> void:
	if is_zooming:
		zoom_timer = min(zoom_timer + delta, ZOOM_DURATION)
		var t = ease(zoom_timer / ZOOM_DURATION, 0.5)
		current_size = lerp(INITIAL_SIZE, FINAL_SIZE, t)
		if zoom_timer >= ZOOM_DURATION:
			is_zooming = false
	
	# Handle window resize
	var window_size = DisplayServer.window_get_size()
	var aspect_ratio = float(window_size.x) / float(window_size.y)
	size = current_size if aspect_ratio > 1.0 else current_size / aspect_ratio
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	# Smooth camera mode transition
	var target_transition = float(is_third_person)
	camera_transition = lerp(camera_transition, target_transition, delta * TRANSITION_SPEED)
	
	# Update predicted direction
	if player.velocity.length() > 0.1:
		predicted_direction = predicted_direction.slerp(player.velocity.normalized(), delta * LAG_SPEED)
	
	var target_pos = player.position
	
	# Calculate camera position
	if camera_transition < 0.01:
		# Top-down view
		var target_camera_pos = Vector3(
			target_pos.x,
			TOP_DOWN_HEIGHT,
			target_pos.z
		)
		position = position.lerp(target_camera_pos, delta * SMOOTHING)
		
		# Maintain top-down rotation
		var current_angle = Vector3(deg_to_rad(-90), 0, 0)
		rotation = rotation.slerp(current_angle, delta * ROTATION_SMOOTHING)
	else:
		# Third-person view
		var height = lerp(TOP_DOWN_HEIGHT, THIRD_PERSON_HEIGHT, camera_transition)
		var behind = -predicted_direction * THIRD_PERSON_DISTANCE
		
		var target_camera_pos = Vector3(
			target_pos.x + behind.x,
			height,
			target_pos.z + behind.z
		)
		
		position = position.lerp(target_camera_pos, delta * SMOOTHING)
		
		# Look at point ahead of player
		var look_target = target_pos + predicted_direction * LOOK_AHEAD_DISTANCE
		look_target.y += 1.0  # Look slightly above ground
		
		# Use looking_at for more stable rotation
		var desired_transform = Transform3D().looking_at(look_target - position, Vector3.UP)
		global_transform = global_transform.interpolate_with(desired_transform, delta * ROTATION_SMOOTHING)

func toggle_view() -> void:
	is_third_person = !is_third_person
