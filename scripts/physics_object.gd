extends RigidBody3D
class_name PhysicsObject

var physics_pos: Vector3
var visual_pos: Vector3

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var current_material: StandardMaterial3D = mesh_instance.mesh.surface_get_material(0).duplicate() if mesh_instance else null

const IMPACT_FLASH_DURATION = 0.15
const IMPACT_MIN_FORCE = 0.3
const IMPACT_MAX_FORCE = 35.0

var current_emission: Color = Color.BLACK
var current_emission_energy: float = 1.0
var target_color: Color
var base_emission: Color
var base_emission_energy: float = 0.3
var color_change_speed: float = 5.0

var drag_coefficient: float = PhysicsConstants.BASE_DRAG_COEFFICIENT
var max_speed: float = PhysicsConstants.MAX_SPEED

var base_color: Color = Color.WHITE
var state_color: Color = Color.WHITE
var current_color: Color = Color.WHITE
var state_emission: Color = Color.BLACK
var state_emission_energy: float = 0.0

var static_friction: float = PhysicsConstants.BASE_STATIC_FRICTION
var dynamic_friction: float = PhysicsConstants.BASE_DYNAMIC_FRICTION
var rolling_friction: float = PhysicsConstants.BASE_ROLLING_FRICTION
var is_static: bool = false

var material_type: String = "default"

var minimum_speed: float
var pull_reduction: float = 1.0
var target_distance: float = 1.0
var collision_force_multiplier: float = 1.0
var spring_stiffness_multiplier: float = 1.0

@export var base_mass: float = 1.0:
	set(value):
		base_mass = value
		if is_inside_tree():
			mass = value * current_scale * current_scale
	get:
		return base_mass
@export var base_scale: float = 1.0

var cached_velocity: Vector3:
	get: return linear_velocity
	set(v): 
		if is_valid_vector(v):
			linear_velocity = v
		else:
			push_warning("Invalid velocity value attempted")

func apply_central_velocity(vel: Vector3) -> void:
	cached_velocity = vel

var accumulated_force: Vector3 = Vector3.ZERO
var accumulated_impulse: Vector3 = Vector3.ZERO

var current_scale: float = 1.0
var target_scale: float = 1.0
var scale_velocity: float = 0.0
const SCALE_SPRING_STIFFNESS = 80.0
const SCALE_DAMPING = 12.0
const MIN_SCALE = 0.1
const MAX_SCALE = 2.0

var is_grounded: bool = false
var ground_contact_timer: float = 0.0
const GROUND_CONTACT_TIME: float = 0.1
const GROUND_LIFT_RESISTANCE: float = 3.5
const GROUND_CHECK_DISTANCE: float = 0.1

static var COLLISION_RESPONSE_FACTOR = 0.2
static var RESTITUTION = 0.01
static var FRICTION_TRANSFER = 0.5
static var VELOCITY_BLEND = 0.1
static var COLLISION_DAMPING = 0.96
static var MIN_SEPARATION = 1.1
static var SEPARATION_FORCE = 5.0
static var MIN_COLLISION_SPEED = 0.1

const MAX_CONTACTS = 4
const CONTACT_MONITOR_ENABLED = true

func _ready():
	physics_pos = global_position
	visual_pos = global_position
	if mesh_instance and current_material:
		mesh_instance.mesh.surface_set_material(0, current_material)
		base_emission = current_material.emission
		current_emission = base_emission
		current_emission_energy = base_emission_energy
		mesh_instance.global_position = global_position

	mass = base_mass
	gravity_scale = 1.0
	continuous_cd = true
	contact_monitor = CONTACT_MONITOR_ENABLED
	max_contacts_reported = MAX_CONTACTS
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	
	linear_damp = 0.1
	angular_damp = 2.0
	
	var physics_material = PhysicsMaterial.new()
	physics_material.friction = dynamic_friction
	physics_material.bounce = RESTITUTION
	physics_material.rough = true
	physics_material_override = physics_material

func update_physical_properties() -> void:
	set_effective_mass(base_mass * current_scale * current_scale)
	if mesh_instance:
		mesh_instance.scale = Vector3.ONE * current_scale

func apply_physics_scale(new_scale: float, immediate: bool = false) -> void:
	target_scale = clamp(new_scale, MIN_SCALE, MAX_SCALE)
	if immediate:
		current_scale = target_scale
		scale_velocity = 0.0
		update_physical_properties()

func is_valid_vector(v: Vector3) -> bool:
	return v.is_finite() and v.length_squared() < 10000000.0

func _integrate_forces(state: PhysicsDirectBodyState3D):
	var is_on_ground = false
	for i in state.get_contact_count():
		var contact_normal = state.get_contact_local_normal(i)
		if contact_normal.dot(Vector3.UP) > 0.7:
			is_on_ground = true
			var friction_coeffs = PhysicsConstants.get_ground_friction_coefficients(material_type)
			var friction = friction_coeffs[1]
			if state.linear_velocity.length() < PhysicsConstants.ROLLING_THRESHOLD:
				friction = friction_coeffs[0]
			state.apply_central_force(-state.linear_velocity * friction * get_effective_mass() * PhysicsConstants.GRAVITY)
	
	is_grounded = is_on_ground
	if is_grounded:
		ground_contact_timer = GROUND_CONTACT_TIME
	
	if accumulated_force != Vector3.ZERO:
		apply_force(accumulated_force, Vector3.ZERO)
		accumulated_force = Vector3.ZERO
	
	if accumulated_impulse != Vector3.ZERO:
		apply_impulse(accumulated_impulse, Vector3.ZERO)
		accumulated_impulse = Vector3.ZERO
	
	if state.linear_velocity.length_squared() > max_speed * max_speed:
		state.linear_velocity = state.linear_velocity.normalized() * max_speed
	
	physics_pos = global_position

func _physics_process(delta: float):
	var scale_error = target_scale - current_scale
	var spring_force = scale_error * SCALE_SPRING_STIFFNESS
	var damping_force = -scale_velocity * SCALE_DAMPING
	var scale_acceleration = spring_force + damping_force
	
	scale_velocity += scale_acceleration * delta
	current_scale += scale_velocity * delta
	
	if abs(scale_error) > 0.001 or abs(scale_velocity) > 0.001:
		update_physical_properties()

	if not is_valid_vector(accumulated_force):
		push_warning("Invalid accumulated force detected, resetting")
		accumulated_force = Vector3.ZERO
	
	if not is_valid_vector(accumulated_impulse):
		push_warning("Invalid accumulated impulse detected, resetting")
		accumulated_impulse = Vector3.ZERO
	
	if get_effective_mass() > 0:
		var force_delta = accumulated_force * (delta / get_effective_mass())
		if is_valid_vector(force_delta):
			apply_central_force(force_delta)
		
		var impulse_delta = accumulated_impulse / get_effective_mass()
		if is_valid_vector(impulse_delta):
			apply_central_impulse(impulse_delta)
	
	if not is_valid_vector(cached_velocity):
		push_warning("Invalid velocity detected, resetting")
		cached_velocity = Vector3.ZERO
	
	accumulated_force = Vector3.ZERO
	accumulated_impulse = Vector3.ZERO
	
	apply_gravity(delta)
	apply_drag(delta)
	limit_speed()
	physics_pos = global_position

	if current_material:
		current_color = current_color.lerp(state_color, delta * color_change_speed)
		apply_color(current_color, state_emission, state_emission_energy)

	for body in get_colliding_bodies():
		if body is PhysicsObject:
			var collision_info = get_contact_info(body)
			if collision_info:
				handle_collision(body, collision_info.normal, collision_info.relative_velocity)

func _process(_delta):
	if mesh_instance:
		var fraction = Engine.get_physics_interpolation_fraction()
		visual_pos = physics_pos.lerp(global_position, fraction)
		mesh_instance.global_position = visual_pos

func get_save_data() -> Dictionary:
	var base_data = {
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
			"x": cached_velocity.x,
			"y": cached_velocity.y,
			"z": cached_velocity.z
		}
	}
	base_data["is_grounded"] = is_grounded
	base_data["ground_contact_timer"] = ground_contact_timer
	return base_data

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
		cached_velocity = Vector3(
			float(data.velocity.x),
			float(data.velocity.y),
			float(data.velocity.z)
		)
	is_grounded = data.get("is_grounded", false)
	ground_contact_timer = data.get("ground_contact_timer", 0.0)

func apply_gravity(delta: float) -> void:
	var collision_radius = 0.4
	if position.y <= PhysicsConstants.GROUND_LEVEL + collision_radius:
		ground_contact_timer = GROUND_CONTACT_TIME
		is_grounded = true
	else:
		ground_contact_timer = max(0.0, ground_contact_timer - delta)
		is_grounded = ground_contact_timer > 0.0
	
	var gravity_multiplier = GROUND_LIFT_RESISTANCE if is_grounded else 1.0
	
	if position.y > PhysicsConstants.GROUND_LEVEL + collision_radius:
		apply_force(Vector3.DOWN * get_effective_mass() * PhysicsConstants.GRAVITY * gravity_multiplier)
	elif position.y < PhysicsConstants.GROUND_LEVEL + collision_radius:
		position.y = PhysicsConstants.GROUND_LEVEL + collision_radius
		if cached_velocity.y < 0:
			var impulse = Vector3.UP * (-cached_velocity.y * get_effective_mass() * (1.0 + PhysicsConstants.BOUNCE_DAMPENING))
			apply_impulse(impulse)
			if abs(cached_velocity.y) < 0.1:
				cached_velocity.y = 0

func apply_drag(_delta: float) -> void:
	var speed_squared = cached_velocity.length_squared()
	
	if speed_squared < minimum_speed * minimum_speed:
		if speed_squared < PhysicsConstants.STATIC_BREAKAWAY_THRESHOLD:
			cached_velocity = Vector3.ZERO
			is_static = true
			return
	
	var drag_force = -cached_velocity.normalized() * speed_squared * drag_coefficient
	apply_force(drag_force)
	
	if is_grounded:
		var friction_coeffs = PhysicsConstants.get_ground_friction_coefficients(material_type)
		var friction_coeff = friction_coeffs[1]
		if speed_squared < PhysicsConstants.ROLLING_THRESHOLD:
			friction_coeff = friction_coeffs[0]
		
		var normal_force = get_effective_mass() * PhysicsConstants.GRAVITY
		var friction_force = -cached_velocity.normalized() * friction_coeff * normal_force
		apply_force(friction_force)
	
	is_static = false

func limit_speed() -> void:
	if cached_velocity.length_squared() > max_speed * max_speed:
		cached_velocity = cached_velocity.normalized() * max_speed

func handle_impact(force: float) -> void:
	if !current_material or !mesh_instance:
		return
			
	var flash_intensity = clampf((force - IMPACT_MIN_FORCE) / (IMPACT_MAX_FORCE - IMPACT_MIN_FORCE), 0.0, 1.0)
	if flash_intensity <= 0.0:
		return
	
	flash_intensity = 1.0 - (1.0 - flash_intensity) * 0.95 + flash_intensity
	
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

func handle_collision(other: PhysicsObject, normal: Vector3, relative_velocity: Vector3) -> void:
	var normal_velocity = relative_velocity.dot(normal)
	if normal_velocity >= 0 or normal_velocity > -MIN_COLLISION_SPEED:
		return
	
	var contact_mass = get_effective_mass() * other.get_effective_mass() / (get_effective_mass() + other.get_effective_mass())
	var impulse = normal * -normal_velocity * contact_mass * COLLISION_RESPONSE_FACTOR
	
	apply_central_impulse(-impulse)
	other.apply_central_impulse(impulse)
	
	handle_impact(impulse.length() * collision_force_multiplier)

func _calculate_separation(other: PhysicsObject) -> Vector3:
	var separation_vector = global_position - other.global_position
	var distance = separation_vector.length()
	if distance > 0 and distance < MIN_SEPARATION:
		var delta = get_physics_process_delta_time()
		return separation_vector.normalized() * SEPARATION_FORCE * (1.0 - distance / MIN_SEPARATION) * delta
	return Vector3.ZERO

func apply_color(color: Color, emission: Color = Color.BLACK, emission_energy: float = -1.0) -> void:
	if current_material:
		current_material.albedo_color = color
		current_material.emission = emission if emission != Color.BLACK else base_emission
		current_material.emission_enabled = true
		current_material.emission_energy_multiplier = emission_energy if emission_energy >= 0 else base_emission_energy
		current_color = color
		state_emission = emission
		state_emission_energy = emission_energy if emission_energy >= 0 else base_emission_energy

func add_physics_force(force: Vector3) -> void:
	if not is_valid_vector(force):
		push_warning("Invalid force vector detected: ", force)
		return
	accumulated_force += force

func add_physics_impulse(impulse: Vector3) -> void:
	if not is_valid_vector(impulse):
		push_warning("Invalid impulse vector detected: ", impulse)
		return
	accumulated_impulse += impulse

func calculate_friction_force(other: PhysicsObject, normal_force: float, relative_velocity: Vector3, collision_normal: Vector3) -> Vector3:
	if not is_valid_vector(relative_velocity) or not is_finite(normal_force) or not is_valid_vector(collision_normal):
		return Vector3.ZERO

	var friction_coeffs = PhysicsConstants.get_friction_coefficients(material_type, other.material_type)
	var object_static_coeff = friction_coeffs[0]
	var object_dynamic_coeff = friction_coeffs[1]
	
	var tangential_velocity = relative_velocity - collision_normal * relative_velocity.dot(collision_normal)
	var tangential_speed = tangential_velocity.length()
	
	if tangential_speed < 0.0001:
		return Vector3.ZERO
	
	var friction_direction = -tangential_velocity.normalized()
	
	if tangential_speed < minimum_speed:
		var max_static_force = object_static_coeff * normal_force
		var stopping_force = get_effective_mass() * tangential_speed / get_physics_process_delta_time()
		return friction_direction * min(max_static_force, stopping_force)
	
	var friction_scale = clamp(tangential_speed / (minimum_speed * 2.0), 0.0, 1.0)
	return friction_direction * object_dynamic_coeff * normal_force * friction_scale

func get_contact_info(other: PhysicsObject) -> Dictionary:
	var contacts = get_colliding_bodies()
	var space_state = get_world_3d().direct_space_state
	
	if other in contacts:
		var query = PhysicsRayQueryParameters3D.create(
			global_position,
			other.global_position,
			collision_mask,
			[self]  # Exclude self from ray test
		)
		var result = space_state.intersect_ray(query)
		
		if result:
			return {
				"normal": result.normal,
				"relative_velocity": linear_velocity - other.linear_velocity,
				"position": result.position
			}
	
	return {}

func get_effective_mass() -> float:
	return mass

func set_effective_mass(value: float) -> void:
	mass = value
