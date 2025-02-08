extends RefCounted

const HISTORY_SIZE = 60  # Number of positions to track (60 frames = 1 second at 60fps)
const MIN_MOVEMENT_THRESHOLD = 4.0  # Minimum distance required to not be considered stuck
const CLUSTER_RADIUS = 200.0  # How close positions need to be to be considered clustered
const REQUIRED_CLUSTER_RATIO = 0.8  # What portion of points need to be in cluster to be stuck

var position_history: Array[Vector3] = []
var is_stuck: bool = false
var stuck_duration: float = 0.0
var stuck_position: Vector3

func update(current_pos: Vector3, delta: float) -> bool:
	# Add new position
	position_history.push_back(current_pos)
	if position_history.size() > HISTORY_SIZE:
		position_history.pop_front()
	
	if position_history.size() < HISTORY_SIZE:
		return false
	
	# Calculate the centroid of recent positions
	var centroid = Vector3.ZERO
	for pos in position_history:
		centroid += pos
	centroid /= position_history.size()
	
	# Count points within cluster radius of centroid
	var points_in_cluster = 0
	for pos in position_history:
		if pos.distance_to(centroid) <= CLUSTER_RADIUS:
			points_in_cluster += 1
	
	# Calculate cluster ratio
	var cluster_ratio = float(points_in_cluster) / position_history.size()
	
	# Check if movement is below threshold
	var total_movement = position_history[0].distance_to(position_history[-1])
	var is_currently_stuck = cluster_ratio >= REQUIRED_CLUSTER_RATIO and total_movement < MIN_MOVEMENT_THRESHOLD
	
	if is_currently_stuck:
		if !is_stuck:
			# Just became stuck
			is_stuck = true
			stuck_position = centroid
		stuck_duration += delta
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
