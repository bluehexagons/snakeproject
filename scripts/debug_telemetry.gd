extends Node

const MAX_SAMPLES := 120
const MAX_BODIES := 24
const SAMPLE_INTERVAL := 0.1
const RANDOM_SEED := 1337

var enabled := false
var samples: Array[Dictionary] = []
var run: Dictionary = {}
var _sample_elapsed := 0.0
var _capture_time := 0.0
var _contact_windows: Dictionary = {}
var _invalid_fields: Array[String] = []

func can_capture() -> bool:
	return OS.is_debug_build() and OS.has_feature("web")

func start_capture() -> void:
	if not can_capture():
		return

	samples.clear()
	_contact_windows.clear()
	_invalid_fields.clear()
	_sample_elapsed = 0.0
	_capture_time = 0.0
	run = {
		"id": "%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_msec()],
		"metadata": {
			"project_version": ProjectSettings.get_setting("application/config/version", "unversioned"),
			"godot": Engine.get_version_info().get("string", "unknown"),
			"physics_backend": ProjectSettings.get_setting("physics/3d/physics_engine", "unknown"),
			"physics_ticks_per_second": Engine.physics_ticks_per_second,
			"debug_build": OS.is_debug_build(),
			"max_bodies": MAX_BODIES,
			"max_contacts_reported": Player.HEAD_MAX_CONTACTS,
			"random_seed": RANDOM_SEED,
		},
	}
	var browser_window = JavaScriptBridge.get_interface("window")
	browser_window.__godotPhysicsTrace = null
	enabled = true

func record_contacts(body: PhysicsObject, state: PhysicsDirectBodyState3D) -> void:
	if not enabled:
		return

	var body_id = str(body.get_instance_id())
	var contact_window: Dictionary = _contact_windows.get(body_id, {"count": 0, "peak_impulse": 0.0})
	contact_window.count += state.get_contact_count()
	for index in state.get_contact_count():
		var impulse = state.get_contact_impulse(index)
		if not impulse.is_finite():
			_invalid_fields.append("contacts.%s.impulse" % body_id)
			continue
		contact_window.peak_impulse = maxf(contact_window.peak_impulse, impulse.length())
	_contact_windows[body_id] = contact_window

func sample_gameplay(delta: float, player: Player, score: int) -> void:
	if not enabled:
		return

	var step := maxf(delta, 0.0)
	_sample_elapsed += step
	_capture_time += step
	if _sample_elapsed < SAMPLE_INTERVAL:
		return

	_sample_elapsed = fmod(_sample_elapsed, SAMPLE_INTERVAL)
	_record_sample(_build_sample(player, score))

func _build_sample(player: Player, score: int) -> Dictionary:
	var bodies: Array[Dictionary] = []
	var physics_objects = get_tree().get_nodes_in_group("physics_object")
	physics_objects.sort_custom(func(first, second): return first.get_instance_id() < second.get_instance_id())
	for body in physics_objects.slice(0, MAX_BODIES):
		if not body is PhysicsObject or not is_instance_valid(body):
			continue
		bodies.append({
			"id": str(body.get_instance_id()),
			"kind": _body_kind(body),
			"position": _encode_vector(body.global_position, "bodies.%s.position" % body.get_instance_id()),
			"linear_velocity": _encode_vector(body.linear_velocity, "bodies.%s.linear_velocity" % body.get_instance_id()),
			"angular_velocity": _encode_vector(body.angular_velocity, "bodies.%s.angular_velocity" % body.get_instance_id()),
		})

	var links: Array[Dictionary] = []
	if is_instance_valid(player):
		for segment in player.segments:
			if not is_instance_valid(segment) or not is_instance_valid(segment.target):
				continue
			var distance = segment.global_position.distance_to(segment.target.global_position)
			links.append({
				"segment_id": str(segment.get_instance_id()),
				"target_id": str(segment.target.get_instance_id()),
				"distance": _encode_number(distance, "links.%s.distance" % segment.get_instance_id()),
				"rest_length": SegmentConstants.TARGET_DISTANCE,
				"error": _encode_number(distance - SegmentConstants.TARGET_DISTANCE, "links.%s.error" % segment.get_instance_id()),
			})

	var foods: Array[Dictionary] = []
	for food: Food in get_tree().get_nodes_in_group("food"):
		if not food.is_available():
			continue
		foods.append({
			"id": str(food.get_instance_id()),
			"position": _encode_vector(food.global_position, "foods.%s.position" % food.get_instance_id()),
		})

	return {
		"physics_tick": Engine.get_physics_frames(),
		"capture_time": _capture_time,
		"bodies": bodies,
		"links": links,
		"foods": foods,
		"gameplay": {
			"score": score,
			"paused": false,
			"lost": false,
			"active_input": is_instance_valid(player) and not player.input_dir.is_zero_approx(),
			"inactivity": player.stuck_elapsed if is_instance_valid(player) else 0.0,
		},
	}

func _body_kind(body: PhysicsObject) -> String:
	if body.is_in_group("player"):
		return "player"
	if body.is_in_group("segment"):
		return "segment"
	if body.is_in_group("rock"):
		return "rock"
	return "physics_object"

func _record_sample(sample: Dictionary) -> void:
	sample["contacts"] = _contact_windows
	_contact_windows = {}
	samples.append(sample)
	if samples.size() >= MAX_SAMPLES:
		publish_trace()

func _encode_number(value: float, field_path: String) -> Variant:
	if is_finite(value):
		return value
	_invalid_fields.append(field_path)
	return null

func _encode_vector(value: Vector3, field_path: String) -> Array:
	if value.is_finite():
		return [value.x, value.y, value.z]
	_invalid_fields.append(field_path)
	return [null, null, null]

func publish_trace() -> void:
	if not enabled:
		return

	enabled = false
	var payload := JSON.stringify({
		"schema": 1,
		"run": run,
		"invalid_fields": _invalid_fields,
		"samples": samples,
	}, "", true, true)
	var browser_window = JavaScriptBridge.get_interface("window")
	browser_window.__godotPhysicsTrace = payload
