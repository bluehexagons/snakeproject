extends Node

const FLASH_DURATION = 0.15
const FLASH_COLOR = Color(1.0, 1.0, 1.0, 1.0)
const MIN_IMPACT_FORCE = 2.0
const MAX_IMPACT_FORCE = 20.0

static func flash_material(material: Material, impact_force: float) -> void:
	if not material or not material is StandardMaterial3D:
		return
		
	var std_material = material as StandardMaterial3D
	
	# Scale flash intensity with impact force
	var flash_intensity = clampf((impact_force - MIN_IMPACT_FORCE) / (MAX_IMPACT_FORCE - MIN_IMPACT_FORCE), 0.0, 1.0)
	if flash_intensity > 0.0:
		var scene_tree = Engine.get_main_loop()
		if scene_tree:
			var base_emission = std_material.emission
			var tween = scene_tree.create_tween()
			var flash_color = base_emission + FLASH_COLOR * flash_intensity
			
			# Quick bright flash
			tween.tween_property(std_material, "emission", flash_color, 0.05)
			# Slower fade back to normal
			tween.tween_property(std_material, "emission", base_emission, FLASH_DURATION)
