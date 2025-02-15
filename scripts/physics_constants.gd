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

# Friction breakaway thresholds
const STATIC_BREAKAWAY_THRESHOLD = 0.1
const ROLLING_THRESHOLD = 0.5

# Minimum speed thresholds (calculated based on mass and friction)
const BASE_MIN_SPEED_THRESHOLD = 0.1
const PLAYER_MIN_SPEED = BASE_MIN_SPEED_THRESHOLD * sqrt(PLAYER_MASS) * PLAYER_DYNAMIC_FRICTION
const ROCK_MIN_SPEED = BASE_MIN_SPEED_THRESHOLD * sqrt(ROCK_MASS) * ROCK_DYNAMIC_FRICTION
const SEGMENT_MIN_SPEED = BASE_MIN_SPEED_THRESHOLD * sqrt(SEGMENT_MASS) * SEGMENT_DYNAMIC_FRICTION
