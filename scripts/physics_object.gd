extends CharacterBody3D
class_name PhysicsObject

var physics_pos: Vector3
var visual_pos: Vector3

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var current_material: StandardMaterial3D = mesh_instance.mesh.surface_get_material(0).duplicate() if mesh_instance else null

const IMPACT_FLASH_DURATION = 0.15  # Slightly longer but softer flash
const IMPACT_MIN_FORCE = 0.3       # Increased minimum threshold
const IMPACT_MAX_FORCE = 35.0      # Increased range for better scaling

var current_emission: Color = Color.BLACK
var current_emission_energy: float = 1.0
var target_color: Color
var base_emission: Color
var base_emission_energy: float = 0.3
var color_change_speed: float = 5.0

var drag_coefficient: float = PhysicsConstants.BASE_DRAG_COEFFICIENT
var max_speed: float = PhysicsConstants.MAX_SPEED
var mass: float = 1.0

var base_color: Color = Color.WHITE
var state_color: Color = Color.WHITE
var current_color: Color = Color.WHITE
var state_emission: Color = Color.BLACK
var state_emission_energy: float = 0.0

var static_friction: float = PhysicsConstants.BASE_STATIC_FRICTION
var dynamic_friction: float = PhysicsConstants.BASE_DYNAMIC_FRICTION
var rolling_friction: float = PhysicsConstants.BASE_ROLLING_FRICTION
var is_static: bool = false

# Add property for minimum speed
var min_speed_threshold: float = PhysicsConstants.BASE_MIN_SPEED_THRESHOLD

# Physics state
var accumulated_force: Vector3 = Vector3.ZERO
var accumulated_impulse: Vector3 = Vector3.ZERO

func _ready():
	if mesh_instance and current_material:
		mesh_instance.mesh.surface_set_material(0, current_material)
		base_emission = current_material.emission
		current_emission = base_emission
		current_emission_energy = base_emission_energy
	physics_pos = global_position
	visual_pos = global_position
	if mesh_instance:
		mesh_instance.global_position = global_position

	# Set appropriate minimum speed threshold based on object type
	if self is Player:
		min_speed_threshold = PhysicsConstants.PLAYER_MIN_SPEED
	elif self is Rock:
		min_speed_threshold = PhysicsConstants.ROCK_MIN_SPEED
	elif self is Segment:
		min_speed_threshold = PhysicsConstants.SEGMENT_MIN_SPEED
	else:
		# Calculate default based on mass
		min_speed_threshold = PhysicsConstants.BASE_MIN_SPEED_THRESHOLD * sqrt(mass) * dynamic_friction

func _physics_process(delta):
	# Apply accumulated forces
	if mass > 0:
		velocity += accumulated_force * (delta / mass)
	
	# Apply accumulated impulses
	if mass > 0:
		velocity += accumulated_impulse / mass
	
	# Reset accumulators
	accumulated_force = Vector3.ZERO
	accumulated_impulse = Vector3.ZERO
	
	apply_gravity(delta)
	apply_drag(delta)
	limit_speed()
	physics_pos = global_position

	# Update color
	if current_material:
		current_color = current_color.lerp(state_color, delta * color_change_speed)
		apply_color(current_color, state_emission, state_emission_energy)

func _process(_delta):
	if mesh_instance:
		var fraction = Engine.get_physics_interpolation_fraction()
		visual_pos = physics_pos.lerp(global_position, fraction)
		mesh_instance.global_position = visual_pos

func get_save_data() -> Dictionary:
	return {
		"position": {
			"x": global_position.x,
			"y": global_position.y,
			"z": global_position.z
		},
		"physics_pos": {
			"x": physics_pos.x,
			"y": physics_pos.y,
			"z": physics_pos.z
		},
		"visual_pos": {
			"x": visual_pos.x,
			"y": visual_pos.y,
			"z": visual_pos.z
		},
		"velocity": {
			"x": velocity.x,
			"y": velocity.y,
			"z": velocity.z
		}
	}

func restore_from_save_data(data: Dictionary) -> void:
	if data.has("position"):
		position = Vector3(
			float(data.position.x),
			float(data.position.y),
			float(data.position.z)
		)
	if data.has("physics_pos"):
		physics_pos = Vector3(
			float(data.physics_pos.x),
			float(data.physics_pos.y),
			float(data.physics_pos.z)
		)
	if data.has("visual_pos"):
		visual_pos = Vector3(
			float(data.visual_pos.x),
			float(data.visual_pos.y),
			float(data.visual_pos.z)
		)
	if data.has("velocity"):
		velocity = Vector3(
			float(data.velocity.x),
			float(data.velocity.y),
			float(data.velocity.z)
		)

func apply_gravity(delta: float) -> void:
	if position.y > PhysicsConstants.GROUND_LEVEL:
		# Gravity is a force, but we can optimize by applying it directly as acceleration
		velocity.y -= PhysicsConstants.GRAVITY * delta
	elif position.y < PhysicsConstants.GROUND_LEVEL:
		position.y = PhysicsConstants.GROUND_LEVEL
		if velocity.y < 0:
			# Convert impact to an impulse
			var impulse = Vector3.UP * (-velocity.y * mass * (1.0 + PhysicsConstants.BOUNCE_DAMPENING))
			apply_impulse(impulse)
			if abs(velocity.y) < 0.1:
				velocity.y = 0

func apply_drag(_delta: float) -> void:
	var speed_squared = velocity.length_squared()
	
	if speed_squared < min_speed_threshold * min_speed_threshold:
		if speed_squared < PhysicsConstants.STATIC_BREAKAWAY_THRESHOLD:
			velocity = Vector3.ZERO
			is_static = true
			return
	
	# Calculate drag force based on velocity squared
	var drag_force = -velocity.normalized() * speed_squared * drag_coefficient
	apply_force(drag_force)
	
	# Apply friction as a force proportional to normal force
	var friction_coefficient = dynamic_friction
	if speed_squared < PhysicsConstants.ROLLING_THRESHOLD:
		friction_coefficient = rolling_friction
	
	var normal_force = mass * PhysicsConstants.GRAVITY
	var friction_force = -velocity.normalized() * friction_coefficient * normal_force
	apply_force(friction_force)
	
	is_static = false

func limit_speed() -> void:
	if velocity.length_squared() > max_speed * max_speed:
		velocity = velocity.normalized() * max_speed

func handle_impact(force: float) -> void:
	if !current_material or !mesh_instance:
		return
			
	var flash_intensity = clampf((force - IMPACT_MIN_FORCE) / (IMPACT_MAX_FORCE - IMPACT_MIN_FORCE), 0.0, 1.0)
	if flash_intensity <= 0.0:
		return
	
	flash_intensity = 1.0 - (1.0 - flash_intensity) * 0.95 + flash_intensity
	
	# Create flash material that respects current state colors
	var flash_material = current_material.duplicate()
	var flash_emission = state_emission if state_emission != Color.BLACK else current_material.emission
	flash_material.albedo_color = current_color
	flash_material.emission = flash_emission + Color(0.5, 0.5, 0.5, 1.0) * flash_intensity
	flash_material.emission_energy_multiplier = state_emission_energy + flash_intensity * 2.0
	
	mesh_instance.material_override = flash_material
	
	var tween = create_tween()
	tween.tween_property(flash_material, "emission", flash_emission, IMPACT_FLASH_DURATION).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(flash_material, "emission_energy_multiplier", 
		state_emission_energy, IMPACT_FLASH_DURATION).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		if is_instance_valid(mesh_instance):
			mesh_instance.material_override = null
	)

func handle_collision(force: float) -> void:
	is_static = false  # Break static friction on impact
	handle_impact(force)

func apply_color(color: Color, emission: Color = Color.BLACK, emission_energy: float = -1.0) -> void:
	if current_material:
		current_material.albedo_color = color
		current_material.emission = emission if emission != Color.BLACK else base_emission
		current_material.emission_enabled = true
		current_material.emission_energy_multiplier = emission_energy if emission_energy >= 0 else base_emission_energy
		# Store current state
		current_color = color
		state_emission = emission
		state_emission_energy = emission_energy if emission_energy >= 0 else base_emission_energy

func apply_force(force: Vector3) -> void:
	accumulated_force += force

func apply_impulse(impulse: Vector3) -> void:
	accumulated_impulse += impulse
