extends RigidBody3D
class_name PhysicsObject

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var current_material: ShaderMaterial = _duplicate_mesh_material()

const IMPACT_FLASH_DURATION = 0.15
const IMPACT_MIN_IMPULSE = 1.0
const IMPACT_FULL_IMPULSE = 6.0

var impact_tween: Tween

var drag_coefficient: float = PhysicsConstants.BASE_DRAG_COEFFICIENT
var max_speed: float = PhysicsConstants.MAX_SPEED

var current_color: Color = Color.WHITE
var current_glow: Color = Color.BLACK
var current_glow_strength: float = 0.0

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

func _duplicate_mesh_material() -> ShaderMaterial:
	if not mesh_instance or not mesh_instance.mesh:
		return null
	var material := mesh_instance.mesh.surface_get_material(0) as ShaderMaterial
	return material.duplicate() as ShaderMaterial if material else null

func _ready():
	if current_material:
		# Tint and impact feedback are per object. The geometry stays shared.
		mesh_instance.set_surface_override_material(0, current_material)
		current_color = current_material.get_shader_parameter("glass_tint")
		current_glow = current_material.get_shader_parameter("glow_tint")
		current_glow_strength = current_material.get_shader_parameter("glow_strength")
		mesh_instance.global_position = global_position

	mass = base_mass
	gravity_scale = 1.0
	continuous_cd = false
	contact_monitor = CONTACT_MONITOR_ENABLED
	max_contacts_reported = MAX_CONTACTS
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.03
	angular_damp = 0.45
	
	var physics_material = PhysicsMaterial.new()
	physics_material.friction = dynamic_friction
	physics_material.bounce = RESTITUTION
	physics_material.rough = true
	physics_material_override = physics_material

func update_physical_properties() -> void:
	mass = base_mass * current_scale * current_scale
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
	_flash_contacts(state)

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
			state.apply_central_force(-horizontal_velocity.normalized() * friction * mass * PhysicsConstants.GRAVITY)

	if state.linear_velocity.length_squared() > max_speed * max_speed:
		state.linear_velocity = state.linear_velocity.normalized() * max_speed

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

	if not is_valid_vector(linear_velocity):
		push_warning("Invalid velocity detected, resetting")
		linear_velocity = Vector3.ZERO

func get_save_data() -> Dictionary:
	return {
		"position": SaveVector.encode(global_position),
		"velocity": SaveVector.encode(linear_velocity),
		"current_scale": current_scale,
		"is_grounded": is_grounded,
		"ground_contact_timer": ground_contact_timer,
	}

func restore_from_save_data(data: Dictionary) -> void:
	global_position = SaveVector.decode(data.get("position"), global_position)
	linear_velocity = SaveVector.decode(data.get("velocity"), linear_velocity)
	if data.has("current_scale"):
		apply_physics_scale(float(data.get("current_scale", current_scale)), true)
	is_grounded = bool(data.get("is_grounded", false))
	ground_contact_timer = maxf(float(data.get("ground_contact_timer", 0.0)), 0.0)

func _flash_contacts(state: PhysicsDirectBodyState3D) -> void:
	var peak_impulse = 0.0
	var strongest_contact := -1
	for index in state.get_contact_count():
		var impulse := state.get_contact_impulse(index).length()
		if impulse > peak_impulse:
			peak_impulse = impulse
			strongest_contact = index
	if peak_impulse > SoundFx.MIN_IMPACT_IMPULSE:
		var collider := state.get_contact_collider_object(strongest_contact) as Node
		if collider:
			SoundFx.queue_impact(self, collider, peak_impulse)
	if peak_impulse <= IMPACT_MIN_IMPULSE or not current_material:
		return

	var flash_intensity = remap(clampf(peak_impulse, IMPACT_MIN_IMPULSE, IMPACT_FULL_IMPULSE), IMPACT_MIN_IMPULSE, IMPACT_FULL_IMPULSE, 0.0, 1.0)
	if impact_tween:
		impact_tween.kill()
	var flash_material := mesh_instance.material_override as ShaderMaterial
	if not flash_material:
		flash_material = current_material.duplicate()
	flash_material.set_shader_parameter("impact", flash_intensity)
	mesh_instance.material_override = flash_material

	impact_tween = create_tween()
	impact_tween.tween_property(flash_material, "shader_parameter/impact", 0.0,
		IMPACT_FLASH_DURATION).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	impact_tween.tween_callback(func(): mesh_instance.material_override = null)

func apply_color(color: Color, glow: Color, glow_strength: float) -> void:
	if not current_material:
		return
	if (current_color.is_equal_approx(color) and current_glow.is_equal_approx(glow)
			and is_equal_approx(current_glow_strength, glow_strength)):
		return
	current_color = color
	current_glow = glow
	current_glow_strength = glow_strength
	_apply_glass_tint(current_material)
	var flash_material := mesh_instance.material_override as ShaderMaterial
	if flash_material:
		_apply_glass_tint(flash_material)

func _apply_glass_tint(material: ShaderMaterial) -> void:
	material.set_shader_parameter("glass_tint", current_color)
	material.set_shader_parameter("glow_tint", current_glow)
	material.set_shader_parameter("glow_strength", current_glow_strength)
