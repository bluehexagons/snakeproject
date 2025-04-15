extends Label3D

const FADE_IN_TIME = 0.05
const COLOR_SHIFT_TIME = 0.3
const FADE_OUT_TIME = 2.0
const INITIAL_COLOR = Color(0.3, 1.0, 0.3, 0.0)
const PEAK_COLOR = Color(1.0, 1.0, 0.6, 1.0)
const FINAL_COLOR = Color(0.7, 0.7, 0.7, 0.0)
const RISE_SPEED = 1.0

var time: float = 0.0

func _ready():
	modulate = INITIAL_COLOR
	outline_modulate = Color(0, 0, 0, 0)

func _process(delta):
	time += delta
	position.y += RISE_SPEED * delta
	
	if time < FADE_IN_TIME:
		var t = time / FADE_IN_TIME
		modulate = INITIAL_COLOR.lerp(PEAK_COLOR, t)
		outline_modulate = Color(0, 0, 0, t)
	elif time < COLOR_SHIFT_TIME:
		modulate = PEAK_COLOR
		outline_modulate = Color.BLACK
	else:
		var t = (time - COLOR_SHIFT_TIME) / FADE_OUT_TIME
		modulate = PEAK_COLOR.lerp(FINAL_COLOR, t)
		outline_modulate = Color(0, 0, 0, 1.0 - t)
		
	if time >= COLOR_SHIFT_TIME + FADE_OUT_TIME:
		queue_free()
