extends Node

const GRAVITY = 20.0  # Remains the same as it's an acceleration
const GROUND_LEVEL = 0.0
const BOUNCE_DAMPENING = 0.5

# Mass constants (in kg)
const PLAYER_MASS = 0.5
const ROCK_MASS = 8.0
const SEGMENT_MASS = 1.0

# Drag coefficients (adjusted for mass-based system)
const BASE_DRAG_COEFFICIENT = 0.3
const PLAYER_DRAG = 0.4
const ROCK_DRAG = 0.1
const SEGMENT_DRAG = 0.2

# Speed limits (now in m/s)
const PLAYER_MAX_SPEED = 30.0
const ROCK_MAX_SPEED = 15.0
const SEGMENT_MAX_SPEED = 20.0
const MAX_SPEED = 30.0

# Friction constants
const BASE_STATIC_FRICTION = 0.02
const BASE_DYNAMIC_FRICTION = 0.01
const BASE_ROLLING_FRICTION = 0.005

const ROCK_STATIC_FRICTION = 0.4
const ROCK_DYNAMIC_FRICTION = 0.15
const ROCK_ROLLING_FRICTION = 0.1

const SEGMENT_STATIC_FRICTION = 0.05
const SEGMENT_DYNAMIC_FRICTION = 0.02
const SEGMENT_ROLLING_FRICTION = 0.01

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

# Friction coefficients between different materials
# Format: [static_friction, dynamic_friction]
const FRICTION_COEFFICIENTS = {
    "segment_segment": [0.001, 0.05],  # Segments slide easily against each other
    "segment_player": [0.15, 0.08],  # Player has slightly more grip
    "segment_rock": [0.4, 0.2],      # Rocks are rougher
    "player_rock": [0.4, 0.2],
    "rock_rock": [0.5, 0.25],
    "default": [0.3, 0.15]           # Default values for unspecified pairs
}

# Material type identifiers
const MATERIAL_SEGMENT = "segment"
const MATERIAL_PLAYER = "player"
const MATERIAL_ROCK = "rock"

# Helper functions
static func get_friction_coefficients(material1: String, material2: String) -> Array:
    # Sort materials to ensure consistent lookup regardless of order
    var key = [material1, material2]
    key.sort()
    var lookup_key = key[0] + "_" + key[1]
    
    return FRICTION_COEFFICIENTS.get(lookup_key, FRICTION_COEFFICIENTS.default)
