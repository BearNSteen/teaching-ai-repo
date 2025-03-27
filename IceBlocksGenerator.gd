@tool
extends BiomeVegetationGenerator
class_name IceBlocksGenerator

var ice_crystal_count: int = 0

func _init():
	super()

func CF_configure(veg_factory, grid, terrain, biome, tile_features_dict: Dictionary, buildings_dict = null):
	super.CF_configure(veg_factory, grid, terrain, biome, tile_features_dict, buildings_dict)
	set_density(1, 3)
	return self

func GEN_generate_vegetation(parent_node: Node3D = null) -> void:
	ice_crystal_count = 0
	
	# Create parent node for all vegetation elements if not provided
	var vegetation_parent = SET_setup_vegetation_parent(parent_node)
	
	# Collect positions for crystals
	var vegetation_data = POS_collect_vegetation_positions()
	
	if vegetation_data.crystal_positions.size() > 0:
		BLD_create_ice_crystals_group(vegetation_parent, vegetation_data)
	
		# Add atmospheric ice mist
		var ice_mist_system = SF_add_ice_mist()
		if ice_mist_system:
			vegetation_parent.get_parent().add_child(ice_mist_system)
		
		# Add ice surface effect
		if vegetation_data.crystal_positions.size() >= 3:
			pass
			#SF_add_ice_surface(vegetation_parent)
	
	if Engine.is_editor_hint() and get_tree().edited_scene_root:
		recursive_set_owner(vegetation_parent, get_tree().edited_scene_root)

func SET_setup_vegetation_parent(parent_node: Node3D = null) -> Node3D:
	if parent_node:
		return parent_node
	
	var vegetation_parent = Node3D.new()
	vegetation_parent.name = "ColoredIceBlocksVegetation"
	add_child(vegetation_parent)
	return vegetation_parent

func POS_collect_vegetation_positions() -> Dictionary:
	var data = {
		"crystal_positions": [],
		"crystal_rotations": [],
		"crystal_scales": [],
		"crystal_colors": [],
		"crystal_normals": []
	}
	
	for x in range(grid_size):
		for z in range(grid_size):
			if is_building_tile(x, z):
				continue
			
			if biome_gen.get_tile_biome(x, z) == "colored_ice_blocks":
				POS_populate_tile_vegetation(x, z, data)
	
	return data

func POS_populate_tile_vegetation(x: int, z: int, data: Dictionary) -> void:
	var count = randi_range(min_density, max_density)
	if count > 0:
		var result = generate_positions_in_tile(x, z, count, 0.3)
		var positions = result[0]
		var normals = result[1]
		
		for i in range(positions.size()):
			data.crystal_positions.append(positions[i])
			data.crystal_rotations.append(randf_range(0, PI * 2))
			data.crystal_scales.append(Vector3(
				randf_range(0.7, 1.3),
				randf_range(0.7, 1.3),
				randf_range(0.7, 1.3)
			))
			var colors = [
				Color(1.0, 0.2, 0.2),  # Red
				Color(0.2, 0.6, 1.0),  # Blue
				Color(0.2, 1.0, 0.2),  # Green
				Color(1.0, 1.0, 0.2)   # Yellow
			]
			data.crystal_colors.append(colors[randi() % colors.size()])
			data.crystal_normals.append(normals[i])
			ice_crystal_count += 1

func BLD_create_ice_crystals_group(parent: Node3D, data: Dictionary) -> void:
	for i in range(data.crystal_positions.size()):
		var crystal_type = randi() % 3  # Random crystal type
		var crystal = null
		
		match crystal_type:
			0:  # Default crystal
				crystal = vegetation_factory.create_ice_crystal(ice_crystal_count - data.crystal_positions.size() + i + 1)
			1:  # Jagged crystal
				crystal = vegetation_factory.create_jagged_ice_crystal(ice_crystal_count - data.crystal_positions.size() + i + 1)
			2:  # Crystal cluster
				crystal = vegetation_factory.create_crystal_cluster(ice_crystal_count - data.crystal_positions.size() + i + 1)
				
		crystal.position = data.crystal_positions[i]
		
		# Apply normal alignment and rotation
		var normal_transform = UT_align_with_normal(data.crystal_normals[i])
		crystal.transform = crystal.transform * normal_transform
		crystal.rotation.y = data.crystal_rotations[i]
		
		crystal.scale = data.crystal_scales[i]
		
		# Apply the calculated color to the main crystal
		var main_crystal = UT_find_node_by_name(crystal, "MainCrystal_%d" % (ice_crystal_count - data.crystal_positions.size() + i + 1))
		if main_crystal:
			BLD_apply_crystal_materials(main_crystal, data.crystal_colors[i], true)
		
		# Apply to smaller crystals with slight variation
		for j in range(crystal.get_child_count()):
			var child = crystal.get_child(j)
			if child.name.begins_with("SmallCrystal"):
				BLD_apply_crystal_materials(child, data.crystal_colors[i], false)
		
		# Add ice particles
		BLD_add_ice_particles(crystal)
		
		parent.add_child(crystal)

func BLD_apply_crystal_materials(crystal: Node3D, color: Color, is_main: bool) -> void:
	var material = crystal.material_override as StandardMaterial3D
	material.albedo_color = color.lightened(0.2 if is_main else 0.3)
	material.emission = color.darkened(0.8 if is_main else 0.7)
	
	if is_main:
		material.metallic = 0.4
		material.roughness = 0.1
		material.refraction_enabled = true
		material.refraction_scale = 0.05
		material.rim_enabled = true
		material.rim = 0.2
		material.rim_tint = 0.8

func BLD_add_ice_particles(crystal: Node3D) -> void:
	var particles = GPUParticles3D.new()
	particles.name = "IceParticles"
	
	var particle_material = ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_material.emission_sphere_radius = 0.1
	particle_material.gravity = Vector3(0, -0.05, 0)
	particle_material.initial_velocity_min = 0.01
	particle_material.initial_velocity_max = 0.05
	particle_material.scale_min = 0.01
	particle_material.scale_max = 0.03
	particle_material.damping_min = 0.1
	particle_material.damping_max = 0.2
	particle_material.angle_min = -15.0
	particle_material.angle_max = 15.0
	
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(0.02, 0.02)
	particles.draw_pass_1 = quad_mesh
	
	var particle_material_visual = StandardMaterial3D.new()
	particle_material_visual.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particle_material_visual.albedo_color = Color(0.8, 0.9, 1.0, 0.3)
	particle_material_visual.emission_enabled = true
	particle_material_visual.emission = Color(0.8, 0.9, 1.0)
	particle_material_visual.emission_energy = 0.5
	particle_material_visual.billboard_mode = StandardMaterial3D.BILLBOARD_ENABLED
	particle_material_visual.metallic = 0.2
	particle_material_visual.roughness = 0.3
	
	particles.material_override = particle_material_visual
	particles.process_material = particle_material
	particles.amount = 20
	particles.lifetime = 2.0
	particles.randomness = 1.0
	
	crystal.add_child(particles)

func SF_add_ice_surface(parent: Node3D) -> void:
	var surface = MeshInstance3D.new()
	surface.name = "IceSurface"
	
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(tile_size * 2.1, tile_size * 2.1)
	surface.mesh = plane_mesh
	
	var ice_material = StandardMaterial3D.new()
	ice_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice_material.albedo_color = Color(0.8, 0.9, 1.0, 0.2)
	ice_material.metallic = 0.3
	ice_material.roughness = 0.1
	ice_material.refraction_enabled = true
	ice_material.refraction_scale = 0.05
	
	surface.material_override = ice_material
	
	# Position at first colored ice blocks tile found
	var first_tile_pos = UT_find_first_biome_tile()
	
	if first_tile_pos:
		surface.position = first_tile_pos + Vector3(tile_size, 0.01, tile_size)
		parent.add_child(surface)

func SF_add_ice_mist() -> Node3D:
	var biome_tiles = UT_find_all_biome_tiles()
	if biome_tiles.is_empty():
		return null
	
	var mist_parent = Node3D.new()
	mist_parent.name = "IceMistSystem"
	
	for tile_pos in biome_tiles:
		BLD_create_mist_emitter(mist_parent, tile_pos)
	
	# Add cold light source
	BLD_add_cold_light(mist_parent, biome_tiles)
	
	return mist_parent

func BLD_create_mist_emitter(parent: Node3D, tile_pos: Vector2) -> void:
	var mist = GPUParticles3D.new()
	mist.name = "IceMist_" + str(tile_pos.x) + "_" + str(tile_pos.y)
	
	var particle_material = ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	particle_material.emission_box_extents = Vector3(tile_size / 2, 0.3, tile_size / 2)
	particle_material.gravity = Vector3(0, -0.005, 0)
	particle_material.initial_velocity_min = 0.02
	particle_material.initial_velocity_max = 0.05
	
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(0.3, 0.3)
	mist.draw_pass_1 = quad_mesh
	
	var mist_material = StandardMaterial3D.new()
	mist_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist_material.albedo_color = Color(0.9, 0.95, 1.0, 0.05)
	mist_material.billboard_mode = StandardMaterial3D.BILLBOARD_ENABLED
	
	mist.material_override = mist_material
	mist.process_material = particle_material
	mist.amount = 5
	mist.lifetime = 8.0
	
	var world_pos = UT_get_world_pos_for_tile(tile_pos.x, tile_pos.y)
	mist.position = Vector3(world_pos.x, 0.3, world_pos.z)
	
	parent.add_child(mist)

func BLD_add_cold_light(parent: Node3D, biome_tiles: Array) -> void:
	var bounds = UT_calculate_biome_bounds(biome_tiles)
	var center = bounds.center
	
	var cold_light = OmniLight3D.new()
	cold_light.name = "IceBiomeLight"
	cold_light.light_color = Color(0.7, 0.8, 1.0)
	cold_light.light_energy = 0.5
	cold_light.omni_range = max(bounds.width, bounds.depth) * 0.6
	cold_light.position = Vector3(center.x, 1.5, center.y)
	
	var animation_script = GDScript.new()
	animation_script.source_code = """
	extends OmniLight3D

	var time = 0
	var original_energy = 0.5

	func _ready():
		original_energy = light_energy

	func _process(delta):
		time += delta
		light_energy = original_energy + sin(time * 0.3) * 0.05
	"""
	cold_light.set_script(animation_script)
	
	parent.add_child(cold_light)

func UT_find_all_biome_tiles() -> Array:
	var tiles = []
	for x in range(grid_size):
		for z in range(grid_size):
			if biome_gen.get_tile_biome(x, z) == "colored_ice_blocks":
				tiles.append(Vector2(x, z))
	return tiles

func UT_find_first_biome_tile() -> Vector3:
	for x in range(grid_size):
		for z in range(grid_size):
			if biome_gen.get_tile_biome(x, z) == "colored_ice_blocks":
				return Vector3(x * tile_size, 0, z * tile_size)
	return Vector3.ZERO

func UT_calculate_biome_bounds(biome_tiles: Array) -> Dictionary:
	var min_x = grid_size
	var min_z = grid_size
	var max_x = 0
	var max_z = 0
	
	for tile in biome_tiles:
		min_x = min(min_x, tile.x)
		min_z = min(min_z, tile.y)
		max_x = max(max_x, tile.x)
		max_z = max(max_z, tile.y)
	
	var min_world_pos = UT_get_world_pos_for_tile(min_x, min_z)
	var max_world_pos = UT_get_world_pos_for_tile(max_x, max_z)
	
	return {
		"center": Vector2((min_world_pos.x + max_world_pos.x) / 2, (min_world_pos.z + max_world_pos.z) / 2),
		"width": (max_x - min_x + 1) * tile_size,
		"depth": (max_z - min_z + 1) * tile_size
	}

func UT_get_world_pos_for_tile(x: int, z: int) -> Vector3:
	return generate_positions_in_tile(x, z, 1, 0)[0][0]

func UT_find_node_by_name(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	
	for child in node.get_children():
		var found = UT_find_node_by_name(child, target_name)
		if found:
			return found
	
	return null

func UT_align_with_normal(normal: Vector3) -> Transform3D:
	if normal.is_equal_approx(Vector3.UP):
		return Transform3D()
	
	var up = Vector3.UP
	var axis = up.cross(normal).normalized()
	
	if axis.length_squared() < 0.001:
		return Transform3D()
	
	var angle = up.angle_to(normal)
	
	if abs(angle) < 0.1:
		return Transform3D()
		
	return Transform3D(Basis().rotated(axis, angle))
