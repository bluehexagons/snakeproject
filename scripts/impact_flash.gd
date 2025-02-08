extends Node

const FLASH_DURATION = 0.15
const FLASH_COLOR = Color(1.0, 1.0, 1.0, 1.0)
const MIN_IMPACT_FORCE = 2.0
const MAX_IMPACT_FORCE = 20.0

static func find_owner_mesh(material: StandardMaterial3D) -> MeshInstance3D:
	# Get all mesh instances in the scene
	var scene_tree = Engine.get_main_loop() as SceneTree
	if not scene_tree:
		return null
	
	# Get the current scene root
	var root = scene_tree.current_scene
	if not root:
		return null
	
	# Find all MeshInstance3D nodes in the scene
	var meshes = root.find_children("*", "MeshInstance3D", true, false)
	for mesh in meshes:
		if mesh.get_active_material(0) == material:
			return mesh
	return null

static func flash_material(material: Material, impact_force: float) -> void:
	if not material or not material is StandardMaterial3D:
		return
		
	var std_material = material as StandardMaterial3D
	var mesh_instance = find_owner_mesh(std_material)
	if not mesh_instance:
		print("Could not find mesh instance for material")
		return
	
	# Scale flash intensity with impact force
	var flash_intensity = clampf((impact_force - MIN_IMPACT_FORCE) / (MAX_IMPACT_FORCE - MIN_IMPACT_FORCE), 0.0, 1.0)
	if flash_intensity <= 0.0:
		return
		
	# Create a temporary material for the flash effect
	var flash_material = std_material.duplicate()
	flash_material.emission_enabled = true
	
	# Calculate flash color
	var base_emission = std_material.emission if std_material.emission_enabled else Color.BLACK
	var flash_color = base_emission + FLASH_COLOR * flash_intensity
	
	# Apply flash material
	mesh_instance.material_override = flash_material
	
	# Create and configure tween
	var scene_tree = Engine.get_main_loop() as SceneTree
	if scene_tree:
		var tween = scene_tree.create_tween()
		tween.tween_property(flash_material, "emission", flash_color, 0.05)
		tween.tween_property(flash_material, "emission", base_emission, FLASH_DURATION)
		tween.tween_callback(func():
			mesh_instance.material_override = null
		)
