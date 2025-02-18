extends Node

const GRAVITY = 25.0  # Increased from 20.0 to make objects feel more grounded
const GROUND_LEVEL = 0.0
const BOUNCE_DAMPENING = 0.3  # Reduced from 0.5 for less bouncy impacts

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
const ROCK_ROLLING_FRICTION = 0.05  # Lower rolling friction

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
	"segment_segment": [0.001, 0.0005],
	"segment_player": [0.005, 0.002],
	"segment_rock": [0.15, 0.08],   # Lower friction for smoother interaction
	"player_rock": [0.2, 0.1],
	"rock_rock": [0.1, 0.05],       # Even lower friction between rocks
	"default": [0.02, 0.01]
}

# Ground friction coefficients adjusted for connection-based system
const GROUND_FRICTION_COEFFICIENTS = {
	"segment": [0.1, 0.05],     # More ground grip for pushing
	"player": [0.02, 0.01],   # Player values unchanged
	"rock": [0.08, 0.04],        # Lower ground friction for smoother movement
	"default": [0.1, 0.05]    # Default values unchanged
}

# Material type identifiers
const MATERIAL_SEGMENT = "segment"
const MATERIAL_PLAYER = "player"
const MATERIAL_ROCK = "rock"

# Physics layers (updated for clarity)
const LAYER_DEFAULT = 0b001  # Ground and static objects
const LAYER_PHYSICAL = 0b010  # Movable objects (rocks, segments)
const LAYER_PLAYER = 0b100   # Player and anything that should collide with everything

# Combined masks for common use
const MASK_DEFAULT = 0b111  # Collide with everything
const MASK_PHYSICAL = 0b111  # Physical objects collide with everything
const MASK_PLAYER = 0b111   # Player collides with everything

# Ground physics properties
const GROUND_COLLISION_LAYER = LAYER_DEFAULT
const GROUND_COLLISION_MASK = MASK_DEFAULT
const GROUND_FRICTION = 1.0
const GROUND_BOUNCE = 0.0

# Contact reporting thresholds
const CONTACT_FORCE_THRESHOLD = 0.5
const CONTACT_MAX_POINTS = 4
const CONTACT_PROCESS_MODE = 1  # Process during physics

# Rock-specific physics constants
const ROCK_COLLISION_IMPULSE_SCALE = 1.2  # Stronger collision response for rocks
const ROCK_CONTACT_PROCESSING = true      # Enable contact monitoring
const ROCK_MAX_CONTACTS = 4               # Maximum contact points to process
const ROCK_FREEZE_VELOCITY = 0.1          # Velocity threshold for sleeping
const ROCK_FREEZE_ANGULAR = 0.1           # Angular velocity threshold for sleeping

# Add RigidBody-specific constants
const RIGID_BODY_DEFAULTS = {
	"continuous_cd": true,
	"contact_monitor": true,
	"can_sleep": true,
	"custom_integrator": false,
	"freeze_mode": RigidBody3D.FREEZE_MODE_KINEMATIC
}

# Update settings to include more RigidBody properties
const RIGID_BODY_SETTINGS = {
	"rock": {
		"linear_damp": 0.2,
		"angular_damp": 3.0,
		"mass": 1.3,
		"friction": ROCK_DYNAMIC_FRICTION,
		"bounce": 0.01,
		"max_contacts": 4,
		"continuous_cd": true
	},
	"segment": {
		"linear_damp": 0.08,        # Less damping for smoother chain
		"angular_damp": 2.5,
		"mass": 1.5,
		"friction": SEGMENT_DYNAMIC_FRICTION,
		"bounce": 0.02              # Slight bounce for better physics
	},
	"player": {
		"linear_damp": 0.05,
		"angular_damp": 1.0,
		"mass": 1.0,
		"friction": PLAYER_DYNAMIC_FRICTION,
		"bounce": 0.01
	}
}

# Remove constant references to ChainPhysics and use runtime vars instead
var chain_drag: float
var chain_min_speed: float
var chain_tension_damping: float

func _ready():
	# Initialize after autoloads
	chain_drag = BASE_DRAG_COEFFICIENT * ChainPhysicsManager.CHAIN_DRAG_REDUCTION
	chain_min_speed = ChainPhysicsManager.CHAIN_MIN_SPEED
	chain_tension_damping = ChainPhysicsManager.TENSION_DAMPING  # Use the correct constant

# Helper functions
func get_friction_coefficients(material1: String, material2: String) -> Array:
	# Sort materials to ensure consistent lookup regardless of order
	var key = [material1, material2]
	key.sort()
	var lookup_key = key[0] + "_" + key[1]
	
	return FRICTION_COEFFICIENTS.get(lookup_key, FRICTION_COEFFICIENTS.default)

func get_ground_friction_coefficients(material_type: String) -> Array:
	return GROUND_FRICTION_COEFFICIENTS.get(material_type, GROUND_FRICTION_COEFFICIENTS.default)
