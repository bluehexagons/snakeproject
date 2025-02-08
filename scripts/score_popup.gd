extends Label3D

const FADE_IN_TIME = 0.05
const COLOR_SHIFT_TIME = 0.3
const FADE_OUT_TIME = 2.0
const INITIAL_COLOR = Color(0.3, 1.0, 0.3, 0.0)  # Green, starting transparent
const PEAK_COLOR = Color(1.0, 1.0, 0.6, 1.0)     # Green, fully opaque
const FINAL_COLOR = Color(0.7, 0.7, 0.7, 0.0)    # Desaturated, fade to transparent
const RISE_SPEED = 1.0

var time: float = 0.0

func _ready():
	modulate = INITIAL_COLOR
	outline_modulate = Color(0, 0, 0, 0)  # Start with transparent outline

func _process(delta):
	time += delta
	position.y += RISE_SPEED * delta
	
	if time < FADE_IN_TIME:
		# Fade in phase
		var t = time / FADE_IN_TIME
		modulate = INITIAL_COLOR.lerp(PEAK_COLOR, t)
		outline_modulate = Color(0, 0, 0, t)
	elif time < COLOR_SHIFT_TIME:
		# Hold peak color briefly
		modulate = PEAK_COLOR
		outline_modulate = Color.BLACK
	else:
		# Fade out phase
		var t = (time - COLOR_SHIFT_TIME) / FADE_OUT_TIME
		modulate = PEAK_COLOR.lerp(FINAL_COLOR, t)
		outline_modulate = Color(0, 0, 0, 1.0 - t)
		
	if time >= COLOR_SHIFT_TIME + FADE_OUT_TIME:
		queue_free()
