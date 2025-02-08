extends Label3D

const RISE_SPEED = 2.0
const LIFETIME = 1.5
const INITIAL_SCALE = 2.0
const FINAL_SCALE = 3.0

var time: float = 0.0

func _ready():
	scale = Vector3.ONE * INITIAL_SCALE
	# Set initial transparency
	modulate = Color(1, 1, 1, 1)

func _process(delta):
	time += delta
	position.y += RISE_SPEED * delta
	
	# Calculate alpha and maintain RGB values
	var alpha = 1.0 - (time / LIFETIME)
	modulate = Color(modulate.r, modulate.g, modulate.b, alpha)
	
	# Scale up over lifetime
	var scale_factor = lerp(INITIAL_SCALE, FINAL_SCALE, time / LIFETIME)
	scale = Vector3.ONE * scale_factor
	
	if time >= LIFETIME:
		queue_free()
