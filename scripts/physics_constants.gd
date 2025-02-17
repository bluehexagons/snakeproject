extends Node

const GRAVITY = 25.0  # Increased from 20.0 to make objects feel more grounded
const GROUND_LEVEL = 0.0
const BOUNCE_DAMPENING = 0.3  # Reduced from 0.5 for less bouncy impacts

# Mass constants (in kg)
const PLAYER_MASS = 1.0          # Keep player mass
const ROCK_MASS = 3.0           # Further reduced for better pushing
const SEGMENT_MASS = 2.5        # Slightly lighter for more responsive following

# Drag coefficients (adjusted for mass-based system)
const BASE_DRAG_COEFFICIENT = 0.3
const PLAYER_DRAG = 0.4
const ROCK_DRAG = 0.1
const SEGMENT_DRAG = 0.3        # Less drag for smoother movement

# Speed limits (now in m/s)
const PLAYER_MAX_SPEED = 30.0
const ROCK_MAX_SPEED = 15.0
const SEGMENT_MAX_SPEED = 22.0  # Increased to allow better following
const MAX_SPEED = 30.0

# Friction constants
const BASE_STATIC_FRICTION = 0.02
const BASE_DYNAMIC_FRICTION = 0.01
const BASE_ROLLING_FRICTION = 0.005

const ROCK_STATIC_FRICTION = 0.4
const ROCK_DYNAMIC_FRICTION = 0.15
const ROCK_ROLLING_FRICTION = 0.1

const SEGMENT_STATIC_FRICTION = 0.05   # Base static friction reduced
const SEGMENT_DYNAMIC_FRICTION = 0.04  # Keep dynamic friction the same
const SEGMENT_ROLLING_FRICTION = 0.01  # Base rolling friction reduced

const PLAYER_STATIC_FRICTION = 0.01
const PLAYER_DYNAMIC_FRICTION = 0.005
const PLAYER_ROLLING_FRICTION = 0.002
const PLAYER_PULL_REDUCTION = 0.75  # Reduce pull force when targeting player
const PLAYER_TARGET_DISTANCE = 1.1

# Friction breakaway thresholds
const STATIC_BREAKAWAY_THRESHOLD = 0.1
const ROLLING_THRESHOLD = 0.5

# Minimum speed thresholds (calculated based on mass and friction)
const BASE_MIN_SPEED_THRESHOLD = 0.1

# Further adjusted segment friction coefficients
const FRICTION_COEFFICIENTS = {
	"segment_segment": [0.001, 0.0005],  # Very low friction between segments
	"segment_player": [0.005, 0.002],         # Keep player-segment smooth
	"segment_rock": [0.03, 0.02],    # More grip for pushing rocks
	"player_rock": [0.2, 0.1],         # Increased player-rock friction for better control
	"rock_rock": [0.3, 0.15],                # Keep rock-rock friction
	"default": [0.02, 0.01]                  # Keep default friction
}

# Ground friction coefficients adjusted for connection-based system
const GROUND_FRICTION_COEFFICIENTS = {
	"segment": [0.002, 0.001],  # Even lower ground friction
	"player": [0.02, 0.01],   # Player values unchanged
	"rock": [0.2, 0.1],        # Reduced to make rocks easier to move
	"default": [0.1, 0.05]    # Default values unchanged
}

# Material type identifiers
const MATERIAL_SEGMENT = "segment"
const MATERIAL_PLAYER = "player"
const MATERIAL_ROCK = "rock"

# Helper functions
func get_friction_coefficients(material1: String, material2: String) -> Array:
	# Sort materials to ensure consistent lookup regardless of order
	var key = [material1, material2]
	key.sort()
	var lookup_key = key[0] + "_" + key[1]
	
	return FRICTION_COEFFICIENTS.get(lookup_key, FRICTION_COEFFICIENTS.default)

func get_ground_friction_coefficients(material_type: String) -> Array:
	return GROUND_FRICTION_COEFFICIENTS.get(material_type, GROUND_FRICTION_COEFFICIENTS.default)
