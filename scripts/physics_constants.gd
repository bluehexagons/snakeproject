extends Node

const GRAVITY = 25.0
const GROUND_LEVEL = 0.0
const BOUNCE_DAMPENING = 0.3

const BASE_DRAG_COEFFICIENT = 0.3
const PLAYER_DRAG = 0.4
const ROCK_DRAG = 0.1
const SEGMENT_DRAG = 0.3

const PLAYER_MAX_SPEED = 30.0
const ROCK_MAX_SPEED = 15.0
const SEGMENT_MAX_SPEED = 22.0
const MAX_SPEED = 30.0

const BASE_STATIC_FRICTION = 0.02
const BASE_DYNAMIC_FRICTION = 0.01
const BASE_ROLLING_FRICTION = 0.005

const ROCK_STATIC_FRICTION = 0.4
const ROCK_DYNAMIC_FRICTION = 0.15
const ROCK_ROLLING_FRICTION = 0.05

const SEGMENT_STATIC_FRICTION = 0.05
const SEGMENT_DYNAMIC_FRICTION = 0.04
const SEGMENT_ROLLING_FRICTION = 0.01

const PLAYER_STATIC_FRICTION = 0.01
const PLAYER_DYNAMIC_FRICTION = 0.005
const PLAYER_ROLLING_FRICTION = 0.002
const PLAYER_PULL_REDUCTION = 0.75
const PLAYER_TARGET_DISTANCE = 1.1

const STATIC_BREAKAWAY_THRESHOLD = 0.1
const ROLLING_THRESHOLD = 0.5

const BASE_MIN_SPEED_THRESHOLD = 0.1

const FRICTION_COEFFICIENTS = {
	"segment_segment": [0.001, 0.0005],
	"segment_player": [0.005, 0.002],
	"segment_rock": [0.15, 0.08],
	"player_rock": [0.2, 0.1],
	"rock_rock": [0.1, 0.05],
	"default": [0.02, 0.01]
}

const GROUND_FRICTION_COEFFICIENTS = {
	"segment": [0.1, 0.05],
	"player": [0.02, 0.01],
	"rock": [0.08, 0.04],
	"default": [0.1, 0.05]
}

const MATERIAL_SEGMENT = "segment"
const MATERIAL_PLAYER = "player"
const MATERIAL_ROCK = "rock"

const LAYER_DEFAULT = 0b001  # Ground and static objects
const LAYER_PHYSICAL = 0b010  # Movable objects (rocks, segments)
const LAYER_PLAYER = 0b100   # Player and anything that should collide with everything

# Combined masks for common use
const MASK_DEFAULT = 0b111  # Collide with everything
const MASK_PHYSICAL = 0b111
const MASK_PLAYER = 0b111

# Ground physics properties
const GROUND_COLLISION_LAYER = LAYER_DEFAULT
const GROUND_COLLISION_MASK = MASK_DEFAULT
const GROUND_FRICTION = 1.0
const GROUND_BOUNCE = 0.0

# Contact reporting thresholds
const CONTACT_FORCE_THRESHOLD = 0.5
const CONTACT_MAX_POINTS = 4
const CONTACT_PROCESS_MODE = 1  # Process during physics

const ROCK_COLLISION_IMPULSE_SCALE = 1.2
const ROCK_CONTACT_PROCESSING = true
const ROCK_MAX_CONTACTS = 4
const ROCK_FREEZE_VELOCITY = 0.1
const ROCK_FREEZE_ANGULAR = 0.1

const RIGID_BODY_DEFAULTS = {
	"continuous_cd": true,
	"contact_monitor": true,
	"can_sleep": true,
	"custom_integrator": false,
	"freeze_mode": RigidBody3D.FREEZE_MODE_KINEMATIC
}

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
		"linear_damp": 0.08,
		"angular_damp": 2.5,
		"mass": 1.5,
		"friction": SEGMENT_DYNAMIC_FRICTION,
		"bounce": 0.02
	},
	"player": {
		"linear_damp": 0.05,
		"angular_damp": 1.0,
		"mass": 1.0,
		"friction": PLAYER_DYNAMIC_FRICTION,
		"bounce": 0.01
	}
}

var chain_drag: float
var chain_min_speed: float
var chain_tension_damping: float

func _ready():
	chain_drag = BASE_DRAG_COEFFICIENT * ChainPhysicsManager.CHAIN_DRAG_REDUCTION
	chain_min_speed = ChainPhysicsManager.CHAIN_MIN_SPEED
	chain_tension_damping = ChainPhysicsManager.TENSION_DAMPING

func get_friction_coefficients(material1: String, material2: String) -> Array:
	var key = [material1, material2]
	key.sort()
	var lookup_key = key[0] + "_" + key[1]
	
	return FRICTION_COEFFICIENTS.get(lookup_key, FRICTION_COEFFICIENTS.default)

func get_ground_friction_coefficients(material_type: String) -> Array:
	return GROUND_FRICTION_COEFFICIENTS.get(material_type, GROUND_FRICTION_COEFFICIENTS.default)
