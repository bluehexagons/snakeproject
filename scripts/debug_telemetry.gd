extends Node

const MAX_SAMPLES := 120
const MAX_BODIES := 24
const SAMPLE_INTERVAL := 0.1

var enabled := false
var samples: Array[Dictionary] = []
var run: Dictionary = {}
var _contact_windows: Dictionary = {}
var _invalid_fields: Array[String] = []

func can_capture() -> bool:
	return OS.is_debug_build() and OS.has_feature("web")

func start_capture(run_id: String, metadata: Dictionary) -> void:
	if not can_capture():
		return

	samples.clear()
	_contact_windows.clear()
	_invalid_fields.clear()
	run = {"id": run_id, "metadata": metadata.duplicate(true)}
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

func record_sample(sample: Dictionary) -> void:
	if not enabled or samples.size() >= MAX_SAMPLES:
		return

	var captured = sample.duplicate(true)
	captured["contacts"] = _contact_windows.duplicate(true)
	_contact_windows.clear()
	samples.append(captured)
	if samples.size() >= MAX_SAMPLES:
		publish_trace()

func encode_number(value: float, field_path: String) -> Variant:
	if is_finite(value):
		return value
	_invalid_fields.append(field_path)
	return null

func encode_vector(value: Vector3, field_path: String) -> Array:
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
