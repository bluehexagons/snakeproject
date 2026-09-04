extends RefCounted
class_name SegmentConstants

# Growth and Timing
const GROWTH_DURATION = 0.33
const SPAWN_DURATION = 0.5

# Chain configuration
const INITIAL_SCALE = 0.4
const GROWTH_CURVE = 0.5
const TARGET_DISTANCE = 1.4

# Movement and Following
const FOLLOW_ACCELERATION = 110.0
const MIN_FORCE_THRESHOLD = 0.1

# Local separation keeps neighboring body segments from collapsing into one
# another while the spring chain catches up.
const SEGMENT_PROXIMITY_RADIUS = 1.2
const PROXIMITY_FORCE = 110.0
const PROXIMITY_FALLOFF = 2.0
const PROXIMITY_VELOCITY_DAMPING = 6.0

# Visual
const SAFE_COLOR = Color(0.3, 0.8, 1.0, 0.9)
const DANGER_COLOR = Color(0.9, 0.2, 0.2, 0.9)
const DANGER_EMISSION = Color(0.8, 0.1, 0.1, 1.0)
const COLOR_CHANGE_SPEED = 5.0
