extends RefCounted
class_name StuckDetector

const HISTORY_SIZE = 30
const MIN_MOVEMENT_THRESHOLD = 1.5
const STUCK_CHECK_INTERVAL = 0.5

var position_history: Array[Vector3] = []
var is_stuck: bool = false
var stuck_duration: float = 0.0
var check_timer: float = 0.0

func update(current_pos: Vector3, delta: float) -> bool:
	check_timer += delta
	position_history.push_back(current_pos)
	if position_history.size() > HISTORY_SIZE:
		position_history.pop_front()
	
	if check_timer < STUCK_CHECK_INTERVAL:
		return is_stuck
	
	var elapsed_since_check = check_timer
	check_timer = 0.0
	
	if position_history.size() < 2:
		return false
	
	var oldest_pos = position_history[0]
	var total_movement = oldest_pos.distance_to(current_pos)
	var time_span = max((position_history.size() - 1) * delta, delta)
	var current_speed = total_movement / time_span
	
	var is_currently_stuck = current_speed < MIN_MOVEMENT_THRESHOLD
	
	if is_currently_stuck:
		if !is_stuck:
			is_stuck = true
		stuck_duration += elapsed_since_check
	else:
		is_stuck = false
		stuck_duration = 0.0
	
	return is_stuck

func get_stuck_duration() -> float:
	return stuck_duration

func reset() -> void:
	position_history.clear()
	is_stuck = false
	stuck_duration = 0.0
	check_timer = 0.0
