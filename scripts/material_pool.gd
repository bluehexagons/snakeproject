extends Node

const POOL_SIZE = 20  # Maximum number of flash materials to keep in pool
var available_materials: Array[StandardMaterial3D] = []
var in_use_materials: Dictionary = {}  # MeshInstance3D -> Material

func _ready():
	# Pre-create some materials
	for i in range(POOL_SIZE):
		var material = StandardMaterial3D.new()
		material.emission_enabled = true
		available_materials.push_back(material)

func get_flash_material(base_material: StandardMaterial3D) -> StandardMaterial3D:
	var flash_material: StandardMaterial3D
	
	if available_materials.is_empty():
		# Create new material if pool is empty
		flash_material = StandardMaterial3D.new()
		flash_material.emission_enabled = true
	else:
		# Reuse material from pool
		flash_material = available_materials.pop_back()
	
	# Copy relevant properties from base material
	flash_material.albedo_color = base_material.albedo_color
	flash_material.metallic = base_material.metallic
	flash_material.roughness = base_material.roughness
	flash_material.emission = base_material.emission
	flash_material.transparency = base_material.transparency
	
	return flash_material

func return_material(material: StandardMaterial3D) -> void:
	if available_materials.size() < POOL_SIZE:
		available_materials.push_back(material)
