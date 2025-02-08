extends Node

const FLASH_DURATION = 0.15
const FLASH_COLOR = Color(1.0, 1.0, 1.0, 1.0)
const MIN_IMPACT_FORCE = 2.0
const MAX_IMPACT_FORCE = 20.0

@onready var material_pool = $MaterialPool

func _ready():
	material_pool = Node.new()
	material_pool.set_script(load("res://scripts/material_pool.gd"))
	add_child(material_pool)
	material_pool._ready()

static func flash_material(material: Material, impact_force: float) -> void:
	if not material or not material is StandardMaterial3D:
		return
		
	var std_material = material as StandardMaterial3D
	var mesh_instance = find_mesh_instance_for_material(std_material)
	if not mesh_instance:
		return
		
	var flash_intensity = clampf((impact_force - MIN_IMPACT_FORCE) / (MAX_IMPACT_FORCE - MIN_IMPACT_FORCE), 0.0, 1.0)
	if flash_intensity <= 0.0:
		return
		
	# Get material from pool
	var impact_flash = Engine.get_main_loop().current_scene.get_node_or_null("/root/ImpactFlash")
	if not impact_flash:
		return
		
	var temp_material = impact_flash.material_pool.get_flash_material(std_material)
	var base_emission = std_material.emission if std_material.emission_enabled else Color.BLACK
	var flash_color = base_emission + FLASH_COLOR * flash_intensity
	
	# Apply flash material
	mesh_instance.material_override = temp_material
	
	# Create and configure tween
	var scene_tree = Engine.get_main_loop() as SceneTree
	if scene_tree:
		var tween = scene_tree.create_tween()
		tween.tween_property(temp_material, "emission", flash_color, 0.05)
		tween.tween_property(temp_material, "emission", base_emission, FLASH_DURATION)
		tween.tween_callback(func():
			if is_instance_valid(mesh_instance):
				mesh_instance.material_override = null
			impact_flash.material_pool.return_material(temp_material)
		)

static func find_mesh_instance_for_material(material: StandardMaterial3D) -> MeshInstance3D:
	# Try to find the MeshInstance3D that uses this material
	var scene_tree = Engine.get_main_loop() as SceneTree
	if not scene_tree:
		return null
		
	var root = scene_tree.current_scene
	if not root:
		return null
		
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh as MeshInstance3D
		if not mesh_instance:
			continue
			
		if mesh_instance.mesh and mesh_instance.mesh.surface_get_material(0) == material:
			return mesh_instance
			
	return null
