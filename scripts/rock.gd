extends "res://scripts/physics_object.gd"
class_name Rock

const DANGER_COLOR = Color(0.8, 0.2, 0.2, 1.0)
const DANGER_EMISSION = Color(0.6, 0.1, 0.1, 1.0)

const SPAWN_HEIGHT = 15.0
const SPAWN_DURATION = 0.7
const INITIAL_SCALE = 0.1
const GROWTH_START = 0.1
const GROWTH_PEAK = 0.6
const GROWTH_CURVE = 0.4
const SCALE_OVERSHOOT = 1.3
const INITIAL_SPIN = 12.0
const BREAK_IMPULSE = 4.5
const FRAGMENT_COUNT = 5
const SHATTER_DURATION = 0.24

var is_dangerous: bool = false
var is_initialized: bool = false
var spawn_timer: float = 0.0
var is_spawning: bool = true
var spawn_progress: float = 0.0
var is_shattering: bool = false

@onready var mesh: MeshInstance3D = $MeshInstance3D

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

func finish_spawn() -> void:
	is_spawning = false
	gravity_scale = 1.0
	apply_physics_scale(1.0, true)
	axis_lock_angular_x = false
	axis_lock_angular_z = false

func setup_rock(spawn_position: Vector3) -> void:
	is_initialized = true
	position = spawn_position + Vector3.UP * SPAWN_HEIGHT
	physics_pos = position
	visual_pos = position
	
	rotation = Vector3(randf_range(-PI, PI), randf_range(-PI, PI), randf_range(-PI, PI))
	angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * INITIAL_SPIN
	
	apply_physics_scale(INITIAL_SCALE, true)
	mesh.scale = Vector3.ONE * INITIAL_SCALE
	cached_velocity = Vector3.ZERO
	gravity_scale = 0.0
	spawn_timer = 0.0
	
	axis_lock_angular_x = true
	axis_lock_angular_z = true

func _physics_process(delta: float) -> void:
	if not is_initialized or is_shattering:
		return
		
	if is_spawning:
		spawn_timer = min(spawn_timer + delta, SPAWN_DURATION)
		spawn_progress = spawn_timer / SPAWN_DURATION
		
		var scale_progress = clampf((spawn_progress - GROWTH_START) / (GROWTH_PEAK - GROWTH_START), 0.0, 1.0)
		var target_scale = INITIAL_SCALE
		
		if scale_progress > 0.0:
			var growth = ease(scale_progress, GROWTH_CURVE)
			target_scale = lerp(INITIAL_SCALE, SCALE_OVERSHOOT, growth)
			
			if spawn_progress > GROWTH_PEAK:
				var settle = ease((spawn_progress - GROWTH_PEAK) / (1.0 - GROWTH_PEAK), 0.6)
				target_scale = lerp(SCALE_OVERSHOOT, 1.0, settle)
		
		apply_physics_scale(target_scale, true)
		gravity_scale = spawn_progress * spawn_progress
		
		if spawn_timer >= SPAWN_DURATION:
			finish_spawn()
	
	_update_base_physics(delta)

func _integrate_forces(state: PhysicsDirectBodyState3D):
	if is_spawning or is_shattering:
		return
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
	# Legacy saves have no entrance state and retain their full-sized restore.
	is_spawning = bool(data.get("is_spawning", false))
	spawn_timer = clampf(float(data.get("spawn_timer", SPAWN_DURATION)), 0.0, SPAWN_DURATION)
	spawn_progress = spawn_timer / SPAWN_DURATION
	if is_spawning and spawn_timer < SPAWN_DURATION:
		gravity_scale = spawn_progress * spawn_progress
		axis_lock_angular_x = true
		axis_lock_angular_z = true
	else:
		spawn_timer = SPAWN_DURATION
		spawn_progress = 1.0
		finish_spawn()
	reset_physics_interpolation()
	if data.get("is_dangerous", false):
		make_dangerous()

func make_dangerous() -> void:
	is_dangerous = true
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
	remove_from_group("rock")
	freeze = true
	collision_layer = 0
	collision_mask = 0
	mesh.hide()
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
	tween.chain().tween_callback(queue_free)
