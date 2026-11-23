extends Control
class_name GameplaySteering

signal hint_changed(text: String)

const TOUCH_DEADZONE = 12.0
const TOUCH_RADIUS = 58.0
const MOUSE_DEADZONE = 0.5
const DESKTOP_HINT = "WASD / arrows or hold left mouse"
const TOUCH_HINT = "Touch and drag to steer"
const GAMEPAD_HINT = "Left stick / D-pad · Start to pause"

@export var action_bar: Control

var hint: String = DESKTOP_HINT
var steering_enabled: bool = false
var wait_for_neutral: bool = false
var mouse_held: bool = false
var mouse_position: Vector2
var touch_index: int = -1
var touch_origin: Vector2
var touch_offset: Vector2

func _ready() -> void:
	if DisplayServer.is_touchscreen_available():
		hint = TOUCH_HINT
	get_viewport().size_changed.connect(_clear_pointer)

func set_steering_enabled(enabled: bool) -> void:
	steering_enabled = enabled
	_clear_pointer()
	wait_for_neutral = enabled and not movement_actions().is_zero_approx()

static func movement_actions() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func movement() -> Vector2:
	var direction = movement_actions()
	if wait_for_neutral:
		wait_for_neutral = not direction.is_zero_approx()
		return Vector2.ZERO
	return direction

func pointer_direction(head: Vector3, camera: Camera3D) -> Vector3:
	if not steering_enabled:
		return Vector3.ZERO
	if touch_index >= 0:
		if touch_offset.length_squared() < TOUCH_DEADZONE * TOUCH_DEADZONE:
			return Vector3.ZERO
		var direction = touch_offset.normalized()
		return Vector3(direction.x, 0.0, direction.y)
	if mouse_held and camera:
		var target = Plane(Vector3.UP, head.y).intersects_ray(
			camera.project_ray_origin(mouse_position), camera.project_ray_normal(mouse_position))
		if target is Vector3:
			var offset: Vector3 = target - head
			offset.y = 0.0
			if offset.length_squared() > MOUSE_DEADZONE * MOUSE_DEADZONE:
				return offset.normalized()
	return Vector3.ZERO

func _set_hint(text: String) -> void:
	if hint != text:
		hint = text
		hint_changed.emit(text)

func _clear_pointer() -> void:
	mouse_held = false
	touch_index = -1
	touch_offset = Vector2.ZERO
	queue_redraw()

func _input(event: InputEvent) -> void:
	# Releases can happen over HUD buttons, so handle them before GUI dispatch.
	if event is InputEventScreenTouch:
		_set_hint(TOUCH_HINT)
		if event.index == touch_index and (event.canceled or not event.pressed):
			_clear_pointer()
	elif event is InputEventScreenDrag and event.index == touch_index:
		touch_offset = (event.position - touch_origin).limit_length(TOUCH_RADIUS)
		touch_origin = event.position - touch_offset
		queue_redraw()
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.pressed:
			_set_hint(DESKTOP_HINT)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			mouse_held = false
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		mouse_position = event.position
	elif event is InputEventKey and event.pressed:
		_set_hint(DESKTOP_HINT)
	elif event is InputEventJoypadButton and event.pressed:
		_set_hint(GAMEPAD_HINT)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		_set_hint(GAMEPAD_HINT)

func _unhandled_input(event: InputEvent) -> void:
	if not steering_enabled or touch_index >= 0:
		return
	if event is InputEventScreenTouch and event.pressed and not event.canceled:
		if not action_bar.get_global_rect().has_point(event.position):
			mouse_held = false
			touch_index = event.index
			touch_origin = event.position
			touch_offset = Vector2.ZERO
			queue_redraw()
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			mouse_held = true
			mouse_position = event.position

func _draw() -> void:
	if touch_index >= 0:
		draw_circle(touch_origin, TOUCH_RADIUS, Color(0.02, 0.10, 0.15, 0.35), true, -1.0, true)
		draw_arc(touch_origin, TOUCH_RADIUS, 0.0, TAU, 48, Color(0.46, 0.90, 0.95, 0.65), 2.0, true)
		draw_circle(touch_origin + touch_offset, 15.0, Color(0.46, 0.90, 0.95, 0.75), true, -1.0, true)
