extends CharacterBody3D
class_name PhysicsObject

var physics_pos: Vector3
var visual_pos: Vector3

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var current_material: StandardMaterial3D = mesh_instance.mesh.surface_get_material(0).duplicate() if mesh_instance else null

const IMPACT_FLASH_DURATION = 0.15
const IMPACT_MIN_FORCE = 2.0
const IMPACT_MAX_FORCE = 20.0

var current_emission: Color = Color.BLACK
var current_emission_energy: float = 1.0
var target_color: Color
var current_color: Color
var base_emission: Color
var base_emission_energy: float = 0.3
var color_change_speed: float = 5.0

var drag_coefficient: float = PhysicsConstants.BASE_DRAG_COEFFICIENT
var max_speed: float = PhysicsConstants.MAX_SPEED

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

func _physics_process(delta):
    apply_gravity(delta)
    apply_drag(delta)
    limit_speed()
    physics_pos = global_position

    # Update color
    if current_material:
        current_color = current_color.lerp(target_color, delta * color_change_speed)
        apply_color(current_color)

func _process(delta):
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
        velocity.y -= PhysicsConstants.GRAVITY * delta
    elif position.y < PhysicsConstants.GROUND_LEVEL:
        position.y = PhysicsConstants.GROUND_LEVEL
        if velocity.y < 0:
            velocity.y = -velocity.y * PhysicsConstants.BOUNCE_DAMPENING
            if abs(velocity.y) < 0.1:
                velocity.y = 0

func apply_drag(delta: float) -> void:
    if velocity.length_squared() > PhysicsConstants.MIN_SPEED_THRESHOLD * PhysicsConstants.MIN_SPEED_THRESHOLD:
        velocity = velocity.lerp(Vector3.ZERO, drag_coefficient * delta)
    elif velocity.length_squared() > 0:
        velocity = Vector3.ZERO

func limit_speed() -> void:
    if velocity.length_squared() > max_speed * max_speed:
        velocity = velocity.normalized() * max_speed

func handle_impact(force: float) -> void:
    if !current_material or !mesh_instance:
        return
            
    var flash_intensity = clampf((force - IMPACT_MIN_FORCE) / (IMPACT_MAX_FORCE - IMPACT_MIN_FORCE), 0.0, 1.0)
    if flash_intensity <= 0.0:
        return
    
    # Create flash material based on current state
    var flash_material = current_material.duplicate()
    flash_material.emission = current_material.emission + Color(1, 1, 1, 1) * flash_intensity
    flash_material.emission_energy_multiplier = current_material.emission_energy_multiplier + flash_intensity
    
    mesh_instance.material_override = flash_material
    
    var tween = create_tween()
    tween.tween_property(flash_material, "emission", current_material.emission, IMPACT_FLASH_DURATION)
    tween.parallel().tween_property(flash_material, "emission_energy_multiplier", 
        current_material.emission_energy_multiplier, IMPACT_FLASH_DURATION)
    tween.tween_callback(func():
        if is_instance_valid(mesh_instance):
            mesh_instance.material_override = null
    )

func apply_color(color: Color, emission: Color = Color.BLACK, emission_energy: float = -1.0) -> void:
    if current_material:
        current_material.albedo_color = color
        current_material.emission = emission if emission != Color.BLACK else base_emission
        current_material.emission_enabled = emission != Color.BLACK || base_emission != Color.BLACK
        current_material.emission_energy_multiplier = emission_energy if emission_energy >= 0 else base_emission_energy
        # Store current emission state for impact flashes
        current_emission = current_material.emission
        current_emission_energy = current_material.emission_energy_multiplier
