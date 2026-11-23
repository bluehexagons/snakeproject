extends Node

# The Web canvas uses device pixels, while touch targets are sized in CSS pixels.
func _ready() -> void:
	if OS.has_feature("web"):
		get_window().size_changed.connect(_update_scale)
		_update_scale()

func _update_scale() -> void:
	var scale_factor = maxf(1.0, DisplayServer.screen_get_scale())
	if not is_equal_approx(get_window().content_scale_factor, scale_factor):
		get_window().content_scale_factor = scale_factor
