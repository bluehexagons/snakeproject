extends Node

# Growth and Timing
const GROWTH_DURATION = 0.33
const SPAWN_DURATION = 0.5
const RECOVERY_DURATION = 1.0

# Chain configuration
const INITIAL_SCALE = 0.4
const INITIAL_SPRING_REDUCTION = 0.5
const GROWTH_CURVE = 0.5
const TARGET_DISTANCE = 1.4
const IDEAL_FOLLOW_DISTANCE = 1.2
const TOO_CLOSE_DISTANCE = 1.0

# Movement and Following
const FOLLOW_ACCELERATION = 140.0
const FOLLOW_DRAG = 0.95
const PLAYER_FOLLOW_MULTIPLIER = 1.5
const BACKING_FORCE_SCALE = 2.0
const MIN_FORCE_THRESHOLD = 0.1
const COLLISION_SEPARATION_FORCE = 0.5
const MOVEMENT_THRESHOLD = 0.5

# General Physics
const PASSIVE_DAMPING = 0.98

# Visual
const SAFE_COLOR = Color(0.3, 0.8, 1.0, 0.9)
const DANGER_COLOR = Color(0.9, 0.2, 0.2, 0.9)
const DANGER_EMISSION = Color(0.8, 0.1, 0.1, 1.0)
const COLOR_CHANGE_SPEED = 5.0

# Break Effects
const POP_FORCE_OPPOSITE = 10.0
const BROKEN_VELOCITY_INHERIT = 0.7
const BROKEN_ANGULAR_IMPULSE = 5.0

# Collisions
const COLLISION_FORCE_SCALE = 0.7
const COLLISION_BOUNCE_DAMPING = 0.1
const COLLISION_TANGENT_RETAIN = 0.95
const COLLISION_VELOCITY_MATCH = 0.25

# Object interaction
const ROCK_PUSH_FORCE = 600.0
const ROCK_PUSH_SCALE = 1.5
const PUSH_FORCE_BUILDUP = 0.2

# Friction
const CONNECTED_FRICTION_MULTIPLIER = 2.5
const CONNECTED_ROLLING_MULTIPLIER = 3.0

# Add singleton indicator
static var singleton: Node

func _init():
	singleton = self

func _ready():
	process_mode = Node.PROCESS_MODE_DISABLED  # This is a data-only node
