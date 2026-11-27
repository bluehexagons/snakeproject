extends RefCounted
class_name SaveVector

const MAX_LENGTH = 1000.0

static func encode(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}

static func decode(data: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	var value = _parse(data)
	return value if value != null else fallback

static func is_valid(data: Variant) -> bool:
	return _parse(data) != null

static func _parse(data: Variant) -> Variant:
	if not data is Dictionary:
		return null
	var x = data.get("x")
	var y = data.get("y")
	var z = data.get("z")
	if (not (x is int or x is float)
			or not (y is int or y is float)
			or not (z is int or z is float)):
		return null
	var value = Vector3(x, y, z)
	return value if value.is_finite() and value.length() <= MAX_LENGTH else null
