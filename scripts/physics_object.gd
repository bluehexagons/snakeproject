extends CharacterBody3D
class_name PhysicsObject

var physics_pos: Vector3
var visual_pos: Vector3

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var material: StandardMaterial3D = mesh_instance.mesh.surface_get_material(0) if mesh_instance else null

func _ready():
    if material:
        material = material.duplicate()
        mesh_instance.mesh.surface_set_material(0, material)
    physics_pos = global_position
    visual_pos = global_position
    if mesh_instance:
        mesh_instance.global_position = global_position

func _physics_process(delta):
    physics_pos = global_position

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

func handle_impact(force: float) -> void:
    if material:
        ImpactFlash.flash_material(material, force)

func apply_color(color: Color, emission: Color = Color.BLACK) -> void:
    if material:
        material.albedo_color = color
        material.emission = emission
        material.emission_enabled = emission != Color.BLACK
