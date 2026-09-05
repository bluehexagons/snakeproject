extends RigidBody3D
class_name PhysicsObject

var physics_pos: Vector3
var visual_pos: Vector3

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var current_material: StandardMaterial3D = _duplicate_mesh_material()

const IMPACT_FLASH_DURATION = 0.15
const IMPACT_MIN_FORCE = 0.3
const IMPACT_MAX_FORCE = 35.0

var target_color: Color
var base_emission: Color
var base_emission_energy: float = 0.3
var color_change_speed: float = 5.0

var drag_coefficient: float = PhysicsConstants.BASE_DRAG_COEFFICIENT
var max_speed: float = PhysicsConstants.MAX_SPEED

var state_color: Color = Color.WHITE
var current_color: Color = Color.WHITE
var state_emission: Color = Color.BLACK
var state_emission_energy: float = 0.0

var dynamic_friction: float = PhysicsConstants.BASE_DYNAMIC_FRICTION

var material_type: String = "default"

@export_category("Physics Properties")
@export var base_mass: float = 1.0:
	set(value):
		base_mass = value
		if is_inside_tree():
			mass = value * current_scale * current_scale
	get:
		return base_mass

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

const RESTITUTION: float = 0.01

const MAX_CONTACTS = 4
const CONTACT_MONITOR_ENABLED = true

func _duplicate_mesh_material() -> StandardMaterial3D:
	if not mesh_instance or not mesh_instance.mesh:
		return null
	var material = mesh_instance.mesh.surface_get_material(0)
	return material.duplicate() as StandardMaterial3D if material is StandardMaterial3D else null

func _ready():
	physics_pos = global_position
	visual_pos = global_position
	# Each instance owns its mesh resource so changing a material on one rock,
	# segment, or player cannot change every other instance in the scene.
	if mesh_instance and mesh_instance.mesh:
		mesh_instance.mesh = mesh_instance.mesh.duplicate()
	if mesh_instance and current_material:
		mesh_instance.mesh.surface_set_material(0, current_material)
		base_emission = current_material.emission
		mesh_instance.global_position = global_position

	mass = base_mass
	gravity_scale = 1.0
	continuous_cd = false
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
	if collision_shape:
		collision_shape.scale = Vector3.ONE * current_scale

func apply_physics_scale(new_scale: float, immediate: bool = false) -> void:
	target_scale = clamp(new_scale, MIN_SCALE, MAX_SCALE)
	if immediate:
		current_scale = target_scale
		scale_velocity = 0.0
		update_physical_properties()

func is_valid_vector(v: Vector3) -> bool:
	return v.is_finite() and v.length_squared() < 10000000.0

static func is_ground_contact(local_normal: Vector3, body_basis: Basis) -> bool:
	var world_normal = (body_basis * local_normal).normalized()
	return world_normal.dot(Vector3.UP) > 0.7

static func calculate_proximity_force(
		direction_to_other: Vector3,
		distance: float,
		radius: float,
		strength: float,
		falloff: float,
		relative_velocity: Vector3,
		velocity_damping: float
	) -> Vector3:
	if distance <= 0.0 or distance >= radius or radius <= 0.0:
		return Vector3.ZERO

	var direction = direction_to_other.normalized()
	var force_scale = 1.0 - distance / radius
	var repulsion = -direction * strength * pow(force_scale, falloff)
	# Matching relative velocity damps closing motion and releases bodies that
	# are already separating instead of making close contacts oscillate.
	var damped_force = repulsion + relative_velocity * velocity_damping
	var radial_force = minf(damped_force.dot(direction), 0.0)
	var tangential_force = damped_force - direction * damped_force.dot(direction)
	return direction * radial_force + tangential_force

func _integrate_forces(state: PhysicsDirectBodyState3D):
	if DebugTelemetry.enabled:
		DebugTelemetry.record_contacts(self, state)

	var is_on_ground = false
	for i in range(state.get_contact_count()):
		var contact_normal = state.get_contact_local_normal(i)
		if is_ground_contact(contact_normal, state.transform.basis):
			is_on_ground = true

	is_grounded = is_on_ground
	if is_grounded:
		ground_contact_timer = GROUND_CONTACT_TIME
	else:
		ground_contact_timer = max(0.0, ground_contact_timer - state.step)

	var velocity = state.linear_velocity
	var horizontal_velocity = Vector3(velocity.x, 0.0, velocity.z)
	if horizontal_velocity.length_squared() > 0.0001:
		var drag_force = -horizontal_velocity.normalized() * horizontal_velocity.length_squared() * drag_coefficient
		state.apply_central_force(drag_force)

		if ground_contact_timer > 0.0:
			var friction_coeffs = PhysicsConstants.get_ground_friction_coefficients(material_type)
			var friction = friction_coeffs[1]
			if horizontal_velocity.length() < PhysicsConstants.ROLLING_THRESHOLD:
				friction = friction_coeffs[0]
			state.apply_central_force(-horizontal_velocity.normalized() * friction * get_effective_mass() * PhysicsConstants.GRAVITY)

	if accumulated_force != Vector3.ZERO:
		state.apply_central_force(accumulated_force)
		accumulated_force = Vector3.ZERO

	if accumulated_impulse != Vector3.ZERO:
		state.apply_central_impulse(accumulated_impulse)
		accumulated_impulse = Vector3.ZERO

	if state.linear_velocity.length_squared() > max_speed * max_speed:
		state.linear_velocity = state.linear_velocity.normalized() * max_speed

	cached_velocity = state.linear_velocity
	physics_pos = state.transform.origin

func _physics_process(delta: float):
	_update_base_physics(delta)

func _update_base_physics(delta: float) -> void:
	var scale_error = target_scale - current_scale
	var spring_force = scale_error * SCALE_SPRING_STIFFNESS
	var damping_force = -scale_velocity * SCALE_DAMPING
	var scale_acceleration = spring_force + damping_force
	
	scale_velocity += scale_acceleration * delta
	current_scale = clampf(current_scale + scale_velocity * delta, MIN_SCALE, MAX_SCALE)
	
	if abs(scale_error) > 0.001 or abs(scale_velocity) > 0.001:
		update_physical_properties()

	if not is_valid_vector(accumulated_force):
		push_warning("Invalid accumulated force detected, resetting")
		accumulated_force = Vector3.ZERO
	
	if not is_valid_vector(accumulated_impulse):
		push_warning("Invalid accumulated impulse detected, resetting")
		accumulated_impulse = Vector3.ZERO
	
	if not is_valid_vector(cached_velocity):
		push_warning("Invalid velocity detected, resetting")
		cached_velocity = Vector3.ZERO

	physics_pos = global_position

	if current_material:
		current_color = current_color.lerp(state_color, delta * color_change_speed)
		apply_color(current_color, state_emission, state_emission_energy)

func _process(_delta):
	pass

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
		},
		"current_scale": current_scale
	}
	base_data["is_grounded"] = is_grounded
	base_data["ground_contact_timer"] = ground_contact_timer
	return base_data

func restore_from_save_data(data: Dictionary) -> void:
	global_position = _vector_from_data(data.get("position"), global_position)
	physics_pos = _vector_from_data(data.get("physics_pos"), physics_pos)
	visual_pos = _vector_from_data(data.get("visual_pos"), visual_pos)
	cached_velocity = _vector_from_data(data.get("velocity"), cached_velocity)
	if data.has("current_scale"):
		apply_physics_scale(float(data.get("current_scale", current_scale)), true)
	is_grounded = bool(data.get("is_grounded", false))
	ground_contact_timer = maxf(float(data.get("ground_contact_timer", 0.0)), 0.0)

func _vector_from_data(data: Variant, fallback: Vector3) -> Vector3:
	if not data is Dictionary:
		return fallback
	var value = Vector3(
		float(data.get("x", fallback.x)),
		float(data.get("y", fallback.y)),
		float(data.get("z", fallback.z))
	)
	return value if value.is_finite() and value.length() <= 1000.0 else fallback

func handle_impact(force: float) -> void:
	if !current_material or !mesh_instance:
		return
			
	var flash_intensity = clampf((force - IMPACT_MIN_FORCE) / (IMPACT_MAX_FORCE - IMPACT_MIN_FORCE), 0.0, 1.0)
	if flash_intensity <= 0.0:
		return
	
	flash_intensity = 1.0 - (1.0 - flash_intensity) * 0.95
	
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

func get_effective_mass() -> float:
	return mass

func set_effective_mass(value: float) -> void:
	mass = value
