extends Node3D

func _ready() -> void:
	# Each contour runs clockwise from the north edge. Joining them builds one
	# rail with mitered corners and beveled edges around the square colliders.
	$Rail.mesh = _build_mesh([
		_contour(10.50, 0.035, 0.0),
		_contour(10.50, 0.035, 0.36),
		_contour(10.62, 0.12, 0.48),
		_contour(11.38, 0.43, 0.48),
		_contour(11.50, 0.52, 0.36),
		_contour(11.50, 0.52, 0.0),
	])
	$Frame.mesh = _build_base(11.40, 0.5, -0.03, -0.99)
	$Trim.mesh = _build_base(11.57, 0.54, -0.695, -0.785)

func _build_base(extent: float, chamfer: float, top: float, bottom: float) -> ArrayMesh:
	return _build_mesh([
		_contour(10.4, 0.06, top),
		_contour(extent, chamfer, top),
		_contour(extent, chamfer, bottom),
	])

func _build_mesh(contours: Array[PackedVector3Array]) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for band in contours.size() - 1:
		var inner: PackedVector3Array = contours[band]
		var outer: PackedVector3Array = contours[band + 1]
		for index in inner.size():
			var next := (index + 1) % inner.size()
			surface.add_triangle_fan(PackedVector3Array([inner[index], outer[index], outer[next], inner[next]]))
	surface.generate_normals()
	return surface.commit()

func _contour(extent: float, chamfer: float, height: float) -> PackedVector3Array:
	var inset := extent - chamfer
	return PackedVector3Array([
		Vector3(-inset, height, -extent), Vector3(inset, height, -extent),
		Vector3(extent, height, -inset), Vector3(extent, height, inset),
		Vector3(inset, height, extent), Vector3(-inset, height, extent),
		Vector3(-extent, height, inset), Vector3(-extent, height, -inset),
	])
