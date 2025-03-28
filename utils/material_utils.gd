@tool
extends RefCounted
class_name MaterialUtils

static func create_material(mesh_instance: MeshInstance3D, color: Color) -> void:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	mesh_instance.material_override = material
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

static func apply_split_material(mesh_instance: MeshInstance3D, color1: Color, color2: Color) -> void:
	var material = ShaderMaterial.new()
	material.shader = preload("res://ASSETS/SHADERS/SHADERS_split_color_shader.gdshader")
	material.set_shader_parameter("color1", color1)
	material.set_shader_parameter("color2", color2)
	material.set_shader_parameter("split_angle", 90.0)
	mesh_instance.material_override = material
