extends Label3D

const RISE_SPEED = 2.0
const LIFETIME = 1.5
const INITIAL_SCALE = 2.0
const FINAL_SCALE = 3.0

var time: float = 0.0

func _ready():
	scale = Vector3.ONE * INITIAL_SCALE

func _process(delta):
	time += delta
	position.y += RISE_SPEED * delta
	
	modulate.a = 1.0 - (time / LIFETIME)
	
	# Scale up over lifetime
	var scale_factor = lerp(INITIAL_SCALE, FINAL_SCALE, time / LIFETIME)
	scale = Vector3.ONE * scale_factor
	
	if time >= LIFETIME:
		queue_free()
