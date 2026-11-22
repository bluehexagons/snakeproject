extends RefCounted
class_name PhysicsConstants

const GRAVITY = 25.0
const BASE_DRAG_COEFFICIENT = 0.3
const PLAYER_DRAG = 0.4

const PLAYER_MAX_SPEED = 12.0
const ROCK_MAX_SPEED = 15.0
const MAX_SPEED = 30.0
const FALL_LIMIT_Y = -3.0

const BASE_DYNAMIC_FRICTION = 0.01

const ROCK_DYNAMIC_FRICTION = 0.15

const SEGMENT_DYNAMIC_FRICTION = 0.04

const PLAYER_DYNAMIC_FRICTION = 0.005
const ROLLING_THRESHOLD = 0.5

const GROUND_FRICTION_COEFFICIENTS = {
	"segment": [0.1, 0.05],
	"player": [0.02, 0.01],
	"rock": [0.08, 0.04],
	"default": [0.1, 0.05]
}

const MATERIAL_SEGMENT = "segment"
const MATERIAL_PLAYER = "player"
const MATERIAL_ROCK = "rock"

const LAYER_DEFAULT = 0b0001  # Ground
const LAYER_PHYSICAL = 0b0010  # Rocks
const LAYER_PLAYER = 0b0100
const LAYER_SEGMENT = 0b1000
const LAYER_BARRIER = 0b10000
const LAYER_ARENA = LAYER_DEFAULT | LAYER_BARRIER

const ROCK_MAX_CONTACTS = 4

const RIGID_BODY_SETTINGS = {
	"rock": {
		"linear_damp": 0.2,
		"angular_damp": 3.0,
		"friction": ROCK_DYNAMIC_FRICTION,
		"bounce": 0.01,
		"max_contacts": 4
	},
	"segment": {
		"linear_damp": 0.08,
		"angular_damp": 2.5,
		"friction": SEGMENT_DYNAMIC_FRICTION,
		"bounce": 0.02
	},
	"player": {
		"linear_damp": 0.05,
		"angular_damp": 1.0,
		"friction": PLAYER_DYNAMIC_FRICTION,
		"bounce": 0.01
	}
}

static func get_ground_friction_coefficients(material_type: String) -> Array:
	return GROUND_FRICTION_COEFFICIENTS.get(material_type, GROUND_FRICTION_COEFFICIENTS.default)
