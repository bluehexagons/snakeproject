extends "res://scripts/physics_object.gd"
class_name Rock

const DANGER_COLOR = Color(0.8, 0.2, 0.2, 1.0)
const DANGER_EMISSION = Color(0.6, 0.1, 0.1, 1.0)

const SPAWN_HEIGHT = 5.2
const DROP_GRAVITY_SCALE = 1.3
const INITIAL_DROP_SPEED = 2.25
const GROWTH_DURATION = 0.28
const INITIAL_SCALE = 0.84
const INITIAL_SPIN = 5.0
const LANDING_RIPPLE_DURATION = 0.2
const LANDING_MARKER_Y = 0.018
const BREAK_IMPULSE = 4.5
const FRAGMENT_COUNT = 5
const SHATTER_DURATION = 0.24

var is_dangerous: bool = false
var is_initialized: bool = false
var spawn_timer: float = 0.0
var is_spawning: bool = true
var is_shattering: bool = false
var _drop_contact := false

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var landing_marker: MeshInstance3D = $LandingMarker
@onready var landing_material: ShaderMaterial = landing_marker.material_override
@onready var break_sparks: GPUParticles3D = $BreakSparks

func _ready() -> void:
	super()
	material_type = PhysicsConstants.MATERIAL_ROCK
	add_to_group("physics_object")
	
	var settings = PhysicsConstants.RIGID_BODY_SETTINGS.rock
	linear_damp = settings.linear_damp
	angular_damp = settings.angular_damp
	collision_layer = PhysicsConstants.LAYER_PHYSICAL
	collision_mask = PhysicsConstants.LAYER_ARENA | PhysicsConstants.LAYER_PHYSICAL | PhysicsConstants.LAYER_PLAYER | PhysicsConstants.LAYER_SEGMENT
	contact_monitor = true
	max_contacts_reported = PhysicsConstants.ROCK_MAX_CONTACTS
	continuous_cd = false
	
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = settings.friction
	physics_material_override.bounce = settings.bounce
	physics_material_override.rough = true

func _finish_spawn() -> void:
	is_spawning = false
	gravity_scale = 1.0
	mesh.scale = Vector3.ONE
	_position_landing_marker()
	landing_material.set_shader_parameter("impact", 0.0)
	var ripple := create_tween()
	ripple.tween_property(landing_material, "shader_parameter/impact", 1.0, LANDING_RIPPLE_DURATION)
	ripple.tween_callback(landing_marker.hide)

func covers_pickup(point: Vector3) -> bool:
	if is_spawning or is_shattering or collision_shape.disabled:
		return false
	var sphere := collision_shape.shape as SphereShape3D
	return sphere != null and collision_shape.to_local(point).length_squared() < sphere.radius * sphere.radius

func setup_rock(spawn_position: Vector3) -> void:
	is_initialized = true
	is_spawning = true
	_drop_contact = false
	position = spawn_position + Vector3.UP * SPAWN_HEIGHT
	physics_pos = position
	visual_pos = position
	
	rotation = Vector3(randf_range(-PI, PI), randf_range(-PI, PI), randf_range(-PI, PI))
	angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * INITIAL_SPIN
	
	cached_velocity = Vector3.DOWN * INITIAL_DROP_SPEED
	gravity_scale = DROP_GRAVITY_SCALE
	spawn_timer = 0.0
	_update_drop_visuals()
	landing_marker.reset_physics_interpolation()
	reset_physics_interpolation()

func _position_landing_marker() -> void:
	var rock_position := global_position
	landing_marker.global_position = Vector3(rock_position.x, LANDING_MARKER_Y, rock_position.z)

func _update_drop_visuals() -> void:
	var growth := smoothstep(0.0, GROWTH_DURATION, spawn_timer)
	mesh.scale = Vector3.ONE * lerpf(INITIAL_SCALE, 1.0, growth)
	_position_landing_marker()
	var altitude := inverse_lerp(0.5, SPAWN_HEIGHT, global_position.y)
	landing_material.set_shader_parameter("altitude", clampf(altitude, 0.0, 1.0))
	landing_material.set_shader_parameter("impact", -1.0)
	landing_marker.show()

func _physics_process(delta: float) -> void:
	if not is_initialized or is_shattering:
		return
	if global_position.y < PhysicsConstants.FALL_LIMIT_Y:
		queue_free()
		return
		
	if is_spawning:
		spawn_timer = minf(spawn_timer + delta, GROWTH_DURATION)
		if _drop_contact:
			_finish_spawn()
		else:
			_update_drop_visuals()
	
	_update_base_physics(delta)

func _integrate_forces(state: PhysicsDirectBodyState3D):
	if not is_initialized or is_shattering:
		return
	if is_spawning and state.get_contact_count() == 0:
		super._integrate_forces(state)
		return
	_drop_contact = is_spawning
	if not is_dangerous:
		for index in state.get_contact_count():
			var head = state.get_contact_collider_object(index) as Player
			if head and not head.has_lost and state.get_contact_impulse(index).length() >= BREAK_IMPULSE:
				is_shattering = true
				break_rock.call_deferred()
				return
	var current_speed = state.linear_velocity.length()
	if current_speed > PhysicsConstants.ROCK_MAX_SPEED:
		state.linear_velocity = state.linear_velocity * (PhysicsConstants.ROCK_MAX_SPEED / current_speed)

	super._integrate_forces(state)

func get_save_data() -> Dictionary:
	var base_data = super.get_save_data()
	base_data["is_dangerous"] = is_dangerous
	base_data["is_spawning"] = is_spawning
	base_data["spawn_timer"] = spawn_timer
	base_data["rotation"] = {
		"x": rotation.x,
		"y": rotation.y,
		"z": rotation.z
	}
	base_data["angular_velocity"] = {
		"x": angular_velocity.x,
		"y": angular_velocity.y,
		"z": angular_velocity.z
	}
	return base_data

func restore_from_save_data(data: Dictionary) -> void:
	super.restore_from_save_data(data)
	rotation = _vector_from_data(data.get("rotation"), rotation)
	angular_velocity = _vector_from_data(data.get("angular_velocity"), angular_velocity)
	is_initialized = true
	# Older drops grew their collider as well as the mesh.
	apply_physics_scale(1.0, true)
	is_spawning = bool(data.get("is_spawning", false))
	spawn_timer = clampf(float(data.get("spawn_timer", GROWTH_DURATION)), 0.0, GROWTH_DURATION)
	_drop_contact = false
	gravity_scale = DROP_GRAVITY_SCALE if is_spawning else 1.0
	if is_spawning:
		_update_drop_visuals()
	else:
		landing_marker.hide()
	landing_marker.reset_physics_interpolation()
	reset_physics_interpolation()
	if data.get("is_dangerous", false):
		make_dangerous()

func make_dangerous() -> void:
	is_dangerous = true
	landing_material.set_shader_parameter("marker_color", Color(1.0, 0.35, 0.22, 1.0))
	target_color = DANGER_COLOR
	current_color = DANGER_COLOR
	state_color = DANGER_COLOR
	base_emission = DANGER_EMISSION
	state_emission = DANGER_EMISSION
	base_emission_energy = 1.0
	state_emission_energy = 1.0
	apply_color(DANGER_COLOR, DANGER_EMISSION, 1.0)
	add_to_group("dangerous")

func dead_eat() -> float:
	queue_free()
	return 2.0

func break_rock() -> void:
	SoundFx.play(SoundFx.Cue.SHATTER)
	remove_from_group("rock")
	freeze = true
	collision_layer = 0
	collision_mask = 0
	mesh.hide()
	landing_marker.hide()
	break_sparks.emitting = true
	var tween = create_tween().set_parallel()
	var to_local = global_basis.inverse()
	for index in FRAGMENT_COUNT:
		var angle = TAU * index / FRAGMENT_COUNT
		var direction = to_local * Vector3(cos(angle), 0.4 + 0.15 * (index % 3), sin(angle))
		var fragment = MeshInstance3D.new()
		fragment.mesh = mesh.mesh
		fragment.position = direction * 0.2
		fragment.scale = Vector3.ONE * 0.35
		add_child(fragment)
		tween.tween_property(fragment, "position", direction, SHATTER_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(fragment, "scale", Vector3.ZERO, SHATTER_DURATION)
	tween.chain().tween_callback(queue_free).set_delay(break_sparks.lifetime - SHATTER_DURATION)
