extends Node

const GRAVITY = 25.0
const BASE_DRAG_COEFFICIENT = 0.3
const PLAYER_DRAG = 0.4

const PLAYER_MAX_SPEED = 30.0
const ROCK_MAX_SPEED = 15.0
const SEGMENT_MAX_SPEED = 22.0
const MAX_SPEED = 30.0

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

const LAYER_DEFAULT = 0b001  # Ground and static objects
const LAYER_PHYSICAL = 0b010  # Movable objects (rocks, segments)
const LAYER_PLAYER = 0b100   # Player and anything that should collide with everything

const MASK_PHYSICAL = 0b111

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

func get_ground_friction_coefficients(material_type: String) -> Array:
	return GROUND_FRICTION_COEFFICIENTS.get(material_type, GROUND_FRICTION_COEFFICIENTS.default)
