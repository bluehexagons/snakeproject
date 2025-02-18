extends Node

# Growth and Scale
const GROWTH_DURATION = 0.33
const INITIAL_SCALE = 0.4
const INITIAL_SPRING_REDUCTION = 0.5
const GROWTH_CURVE = 0.5
const GROWTH_START = 0.1
const GROWTH_PEAK = 0.6
const SCALE_OVERSHOOT = 1.3

# Following and Movement
const FOLLOW_ACCELERATION = 140.0
const FOLLOW_DRAG = 0.95
const PLAYER_FOLLOW_MULTIPLIER = 1.5
const IDEAL_FOLLOW_DISTANCE = 1.2
const TOO_CLOSE_DISTANCE = 1.0
const BACKING_FORCE_SCALE = 2.0
const MIN_FOLLOW_SPEED = 2.0
const MOVEMENT_THRESHOLD = 1.0
const PASSIVE_DAMPING = 0.98
const MIN_FORCE_THRESHOLD = 0.1

# Chain Physics
const SPRING_STIFFNESS = 40.0
const SPRING_DAMPING_BASE = 3.0
const SPRING_DAMPING_GROWTH = 1.2
const TARGET_DISTANCE = 1.4
const MAX_STRETCH = 1.8
const HARD_MAX_STRETCH = 2.5
const STRETCH_STIFFNESS_SCALE = 10.4
const SNAP_THRESHOLD = 0.1
const BREAK_THRESHOLD = 0.99
const CHAIN_POSITION_FACTOR = 0.12
const CHAIN_LENGTH_SCALING = 0.85
const MIN_STIFFNESS = 0.4
const MAX_CHAIN_LENGTH = 20
const CHAIN_PULL_DECAY = 0.9
const SPRING_FORCE_DELAY = 0.1  # Consider moving to ChainPhysics
const COLLISION_RECOVERY_RATE = 2.0  # Consider moving to ChainPhysics

# Breaking and Recovery
const RECOVERY_DURATION = 1.0
const RECOVERY_COOLDOWN = 0.5
const POP_FORCE = 1.0
const POP_FORCE_OPPOSITE = 10.0
const BROKEN_VELOCITY_INHERIT = 0.7
const BROKEN_ANGULAR_IMPULSE = 5.0

# Collision and Proximity
const COLLISION_FORCE_SCALE = 0.7
const COLLISION_BOUNCE_DAMPING = 0.1
const COLLISION_TANGENT_RETAIN = 0.95
const COLLISION_SEPARATION_FORCE = 0.15
const SEGMENT_COLLISION_RESTITUTION = 0.1
const SEGMENT_REPULSION_FORCE = 120.0
const SEGMENT_PROXIMITY_RADIUS = 1.2
const COLLISION_VELOCITY_MATCH = 0.25
const PROXIMITY_FORCE = 80.0
const PROXIMITY_FALLOFF = 0.8
const PROXIMITY_VELOCITY_MATCH = 0.2

# Visual
const SAFE_COLOR = Color(0.3, 0.8, 1.0, 0.9)
const DANGER_COLOR = Color(0.9, 0.2, 0.2, 0.9)
const DANGER_EMISSION = Color(0.8, 0.1, 0.1, 1.0)
const COLOR_CHANGE_SPEED = 5.0

# Initialization Sequence
const INITIALIZATION_MASS = 1.0
const INITIALIZATION_SCALE = 0.4  # This is now separate from INITIAL_SCALE

const PULL_START_DISTANCE = 1.0  # Distance at which pull force starts
const PULL_MAX_DISTANCE = 2.2    # Distance at which pull force peaks
const PULL_FORCE = 80.0           # Much weaker pull force
const CLUSTER_FORCE_REDUCTION = 0.85  # Increased force reduction in clusters
const MAX_NEARBY_SEGMENTS = 5  # Threshold for considering an area "crowded"
const SPAWN_DURATION = 0.5  # Duration of spawn state
const SPAWN_COLLISION_MASK = 0b111  # Actually collide with everything, but...
const NORMAL_COLLISION_MASK = 0b111  # Normal collision mask (all layers)
const MIN_PULL_FORCE = 30.0       # Lower minimum pull force
const VELOCITY_MATCHING_FACTOR = 0.05  # Almost no velocity matching
const VELOCITY_INHERITANCE = 0.7  # How much of target's velocity direction to inherit
const VELOCITY_INHERITANCE_SPEED = 5.0  # How fast to inherit velocity direction
const MIN_VELOCITY_MATCH = 0.2  # Minimum velocity matching even at rest
const CONNECTED_FRICTION_MULTIPLIER = 2.5  # Higher friction when connected
const CONNECTED_ROLLING_MULTIPLIER = 3.0   # Much harder to roll when connected
const ROCK_COLLISION_EXTRA_DAMPING = 0.4    # Allow more sliding on rocks

const PULL_FORCE_TRANSFER = 1.5  # How much of pull force transfers to pushing obstacles
const PUSH_BOOST_THRESHOLD = 0.5  # Speed threshold to identify when being pulled strongly
const PUSH_FORCE_MULTIPLIER = 2.0  # Extra force when pushing due to chain pull

const PUSH_FORCE_RAMP_RATE = 1.5  # How quickly to build up pushing force
const MAX_PUSH_MULTIPLIER = 2.5  # Maximum force multiplier when pushing
const RESISTANCE_DECAY = 0.8  # How quickly push force decays

const FOLLOW_FORCE_SCALE = 1.2   # How strongly to follow

const VELOCITY_DECAY = 0.97        # Decay velocity when target is stationary
const ROCK_PUSH_BOOST = 2.5        # More reasonable push force

const COLLISION_PUSH_FORCE = 180.0   # Strong base push force for collisions
const COLLISION_PUSH_DECAY = 0.85    # How quickly push force decays
const MIN_SEPARATION_SPEED = 1.0     # Minimum speed to maintain when separating
const SEGMENT_PUSH_MULTIPLIER = 1.5  # Extra force when pushing other segments
const PUSH_DIRECTION_BLEND = 0.3     # How much to blend push direction with movement

const PULL_FORCE_PLAYER_REDUCTION = 0.6  # Less reduction on player (was 0.4)
const PULL_ACCELERATION_RATE = 2.0       # How quickly pull force builds up
const MAX_PULL_VELOCITY = 15.0           # Maximum velocity when being pulled
const PULL_VELOCITY_REDUCTION = 0.7      # Reduce velocity when pulling against resistance

# Simplified rock interaction constants
const ROCK_PUSH_FORCE = 600.0     # More reasonable push force
const ROCK_SLIDE_SPEED = 0.9      # Better sliding motion
const ROCK_REBOUND = 0.4          # How much to bounce off
const ROCK_SEPARATION = 100.0     # Force to prevent sticking

const CHAIN_FORCE_TRANSFER = 2.5   # Stronger chain force transfer
const VELOCITY_TRANSFER = 0.4      # Direct velocity transfer during push

const ROCK_PUSH_SCALE = 1.5       # More conservative push force
const CHAIN_FORCE_SCALE = 0.8     # Gentler chain force
const PUSH_FORCE_BUILDUP = 0.2    # Slower force buildup

# Add singleton indicator
static var singleton: Node

func _init():
	singleton = self

func _ready():
	process_mode = Node.PROCESS_MODE_DISABLED  # This is a data-only node

# Add helper functions for initialization
static func get_initial_settings() -> Dictionary:
	return {
		"scale": INITIALIZATION_SCALE,
		"mass": INITIALIZATION_MASS,
		"growth_duration": GROWTH_DURATION,
		"spawn_duration": SPAWN_DURATION
	}
