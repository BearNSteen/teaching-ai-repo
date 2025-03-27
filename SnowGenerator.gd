@tool
extends BiomeVegetationGenerator
class_name SnowGenerator


var snow_tree_count: int = 0
var ice_crystal_count: int = 0

func _init():
	super()

func BLD_add_snowdrift_at_base(tree: Node3D) -> void:
	# Add a snowdrift at the base of the tree
	var drift = MeshInstance3D.new()
	drift.name = "Snowdrift"
	
	# Create an irregular shape with a SurfaceTool
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Create a noise generator for random drift shape
	var noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.5
	
	# Create a circular base with noise
	var radius = 0.25
	var segments = 12
	var center = Vector3(0, 0, 0)
	var _height = 0.05
	
	# Create vertices with noise
	for i in range(segments):
		var angle = i * 2 * PI / segments
		var next_angle = (i + 1) * 2 * PI / segments
		
		var noise_val1 = noise.get_noise_2d(cos(angle), sin(angle))
		var noise_val2 = noise.get_noise_2d(cos(next_angle), sin(next_angle))
		
		var edge_radius1 = radius * (1.0 + noise_val1 * 0.3)
		var edge_radius2 = radius * (1.0 + noise_val2 * 0.3)
		
		var center_point = center
		var edge_point1 = center + Vector3(cos(angle) * edge_radius1, 0, sin(angle) * edge_radius1)
		var edge_point2 = center + Vector3(cos(next_angle) * edge_radius2, 0, sin(next_angle) * edge_radius2)
		
		# Add a triangle
		st.add_vertex(center_point)
		st.add_vertex(edge_point1)
		st.add_vertex(edge_point2)
	
	# Create a simple mesh from the surface tool
	drift.mesh = st.commit()
	drift.material_override = vegetation_factory.get_shared_material(Color(0.95, 0.95, 1.0))
	
	# Position at the base of the tree
	drift.position.y = 0.02
	
	tree.add_child(drift)

func BLD_create_ice_crystal(index: int) -> Node3D:
	# Create a unique ice crystal formation
	var crystal = Node3D.new()
	crystal.name = "IceCrystal_%d" % index
	
	# Create the main crystal spike
	var main_spike = MeshInstance3D.new()
	main_spike.name = "MainSpike_%d" % index
	
	# Create a crystal mesh using PrismMesh
	var spike_mesh = PrismMesh.new()
	spike_mesh.size = Vector3(0.1, 0.4, 0.1)
	main_spike.mesh = spike_mesh
	
	# Position and rotate the main spike
	main_spike.position.y = 0.2
	main_spike.rotation_degrees.x = 180  # Point upward
	
	# Create ice material with reflection
	var ice_material = StandardMaterial3D.new()
	ice_material.albedo_color = Color(0.8, 0.9, 1.0, 0.9)
	ice_material.metallic = 0.7
	ice_material.roughness = 0.1
	ice_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	main_spike.material_override = ice_material
	
	crystal.add_child(main_spike)
	
	# Add smaller crystal formations around the main one
	var smaller_count = randi_range(2, 4)
	for i in range(smaller_count):
		var small_crystal = MeshInstance3D.new()
		small_crystal.name = "SmallCrystal_%d_%d" % [index, i]
		
		var small_mesh = PrismMesh.new()
		small_mesh.size = Vector3(0.06, 0.2, 0.06)
		small_crystal.mesh = small_mesh
		
		# Position around the main crystal
		var angle = i * (2 * PI / smaller_count)
		var radius = 0.08
		small_crystal.position = Vector3(
			cos(angle) * radius,
			0.1,
			sin(angle) * radius
		)
		
		# Rotate to point outward and upward
		small_crystal.rotation_degrees = Vector3(
			180 + randf_range(-20, 20),  # Slightly varied upward angle
			rad_to_deg(angle) + randf_range(-20, 20),  # Point outward with variation
			0
		)
		
		# Slight color variation
		var color_variation = randf_range(-0.1, 0.1)
		var small_material = StandardMaterial3D.new()
		small_material.albedo_color = Color(
			0.8 + color_variation,
			0.9 + color_variation,
			1.0,
			0.9
		)
		small_material.metallic = 0.7
		small_material.roughness = 0.1
		small_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		small_crystal.material_override = small_material
		
		crystal.add_child(small_crystal)
	
	# Add a snow base
	var snow_base = MeshInstance3D.new()
	snow_base.name = "SnowBase_%d" % index
	var base_mesh = CylinderMesh.new()
	base_mesh.top_radius = 0.15
	base_mesh.bottom_radius = 0.18
	base_mesh.height = 0.05
	snow_base.mesh = base_mesh
	snow_base.position.y = 0.02
	
	# Snow material
	var snow_material = vegetation_factory.get_shared_material(Color(0.95, 0.95, 1.0))
	snow_base.material_override = snow_material
	
	crystal.add_child(snow_base)
	
	# Add subtle glow effect with light
	var omni_light = OmniLight3D.new()
	omni_light.name = "CrystalGlow_%d" % index
	omni_light.light_color = Color(0.8, 0.9, 1.0)
	omni_light.light_energy = 0.3
	omni_light.omni_range = 0.5
	omni_light.position.y = 0.2
	
	crystal.add_child(omni_light)
	
	return crystal

func BLD_create_ice_crystals(parent: Node3D, data: Dictionary) -> void:
	if data.crystal_positions.size() <= 0:
		return
		
	var crystal_container = Node3D.new()
	crystal_container.name = "IceCrystals"
	parent.add_child(crystal_container)
	
	for i in range(data.crystal_positions.size()):
		var crystal = BLD_create_ice_crystal(i)
		crystal.position = data.crystal_positions[i]
		
		# Apply normal alignment and rotation
		var normal_transform = UT_align_with_normal(data.crystal_normals[i])
		crystal.rotation.y = data.crystal_rotations[i]
		crystal.transform = crystal.transform * normal_transform
		
		# Apply scale variation
		crystal.scale = data.crystal_scales[i]
		
		crystal_container.add_child(crystal)

func BLD_create_snow_trees(parent: Node3D, data: Dictionary) -> void:
	if data.tree_positions.size() <= 0:
		return
		
	var tree_container = Node3D.new()
	tree_container.name = "SnowTrees"
	parent.add_child(tree_container)
	
	for i in range(data.tree_positions.size()):
		var tree = vegetation_factory.create_snow_tree(i)
		
		# Position with slight height adjustment for snow
		var pos = data.tree_positions[i]
		pos.y += 0.1  # Trees should be above snow level
		tree.position = pos
		
		# Apply normal alignment for varied terrain
		var normal_transform = UT_align_with_normal(data.tree_normals[i])
		tree.rotation.y = data.tree_rotations[i]
		tree.transform = tree.transform * normal_transform
		
		# Add snowdrift at base
		BLD_add_snowdrift_at_base(tree)
		
		tree_container.add_child(tree)
		
func CF_configure(veg_factory, grid, terrain, biome, tile_features_dict: Dictionary, buildings_dict = null):
	super.CF_configure(veg_factory, grid, terrain, biome, tile_features_dict, buildings_dict)
	set_density(0, 2)
	return self

func GEN_generate_vegetation(parent_node: Node3D = null) -> void:
	# Reset counters
	snow_tree_count = 0
	ice_crystal_count = 0
	
	# Create parent node for all vegetation elements if not provided
	var vegetation_parent = SET_setup_vegetation_parent(parent_node)
	
	# Collect positions for all vegetation types
	var vegetation_data = POS_collect_vegetation_positions()
	
	# Create snow trees
	BLD_create_snow_trees(vegetation_parent, vegetation_data)
	
	# Create ice crystals
	BLD_create_ice_crystals(vegetation_parent, vegetation_data)
	
	# Set ownership for editor
	if Engine.is_editor_hint() and get_tree().edited_scene_root:
		recursive_set_owner(vegetation_parent, get_tree().edited_scene_root)

func POS_collect_vegetation_positions() -> Dictionary:
	var data = {
		"tree_positions": [],
		"tree_rotations": [],
		"tree_normals": [],
		"crystal_positions": [],
		"crystal_rotations": [],
		"crystal_normals": [],
		"crystal_scales": []
	}
	
	# Iterate through grid to find suitable positions for vegetation
	for x in range(grid_size):
		for z in range(grid_size):
			# Skip special tiles and building locations
			if is_special_tile(x, z) or is_building_tile(x, z):
				continue
			
			# Check if current tile is in snow biome
			if biome_gen.get_tile_biome(x, z) == "snow":
				POS_populate_tile_vegetation(x, z, data)
	
	return data

func POS_populate_tile_vegetation(x: int, z: int, data: Dictionary) -> void:
	# First, decide if we place snow trees or ice crystals
	var place_trees = randf() < 0.7  # 70% chance for trees
	
	# Generate random number of vegetation items based on density settings
	var count = randi_range(min_density, max_density)
	var result = generate_positions_in_tile(x, z, count, 0.3)
	var positions = result[0]
	var normals = result[1]
	
	# Add generated positions and random rotations to arrays
	for i in range(positions.size()):
		if place_trees:
			data.tree_positions.append(positions[i])
			data.tree_rotations.append(randf_range(0, PI * 2))
			data.tree_normals.append(normals[i])
			snow_tree_count += 1
		else:
			data.crystal_positions.append(positions[i])
			data.crystal_rotations.append(randf_range(0, PI * 2))
			data.crystal_normals.append(normals[i])
			
			# Varying crystal sizes
			var crystal_size = 0.1 + randf_range(0, 0.15)
			data.crystal_scales.append(Vector3(crystal_size, crystal_size * 1.5, crystal_size))
			ice_crystal_count += 1

func SET_setup_vegetation_parent(parent_node: Node3D = null) -> Node3D:
	if parent_node:
		return parent_node
	
	var vegetation_parent = Node3D.new()
	vegetation_parent.name = "SnowVegetation"
	add_child(vegetation_parent)
	return vegetation_parent

func SF_create_frozen_pond(x: int, z: int) -> Node3D:
	var pond = Node3D.new()
	pond.name = "FrozenPond_%d_%d" % [x, z]
	
	# Create the ice surface
	var ice = MeshInstance3D.new()
	ice.name = "IceSurface"
	
	# Create an irregular pond shape with a SurfaceTool
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Create a noise generator for random pond shape
	var noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.3
	
	# Create a circular pond with noise
	var radius = 0.4
	var segments = 16
	var center = Vector3(0, 0, 0)
	
	# Create vertices with noise
	for i in range(segments):
		var angle = i * 2 * PI / segments
		var next_angle = (i + 1) * 2 * PI / segments
		
		var noise_val1 = noise.get_noise_2d(cos(angle), sin(angle))
		var noise_val2 = noise.get_noise_2d(cos(next_angle), sin(next_angle))
		
		var edge_radius1 = radius * (1.0 + noise_val1 * 0.3)
		var edge_radius2 = radius * (1.0 + noise_val2 * 0.3)
		
		var v0 = center
		var v1 = center + Vector3(cos(angle) * edge_radius1, 0, sin(angle) * edge_radius1)
		var v2 = center + Vector3(cos(next_angle) * edge_radius2, 0, sin(next_angle) * edge_radius2)
		
		# Add a triangle
		st.add_vertex(v0)
		st.add_vertex(v1)
		st.add_vertex(v2)
	
	ice.mesh = st.commit()
	ice.position.y = 0.01
	
	# Create ice material with cracks
	var ice_material = StandardMaterial3D.new()
	ice_material.albedo_color = Color(0.85, 0.95, 1.0, 0.8)
	ice_material.metallic = 0.5
	ice_material.roughness = 0.1
	ice_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice.material_override = ice_material
	
	pond.add_child(ice)
	
	# Add ice cracks
	var cracks = MeshInstance3D.new()
	cracks.name = "IceCracks"
	
	# Create crack lines
	var crack_st = SurfaceTool.new()
	crack_st.begin(Mesh.PRIMITIVE_LINES)
	
	# Add a few random cracks
	var crack_count = randi_range(3, 6)
	for i in range(crack_count):
		var start_angle = randf_range(0, PI * 2)
		var start_radius = radius * 0.2 * randf_range(0.1, 0.4)
		var end_angle = start_angle + randf_range(PI/4, PI/2) * (-1 if randf() < 0.5 else 1)
		var end_radius = radius * randf_range(0.6, 0.9)
		
		var start_point = Vector3(cos(start_angle) * start_radius, 0.011, sin(start_angle) * start_radius)
		var end_point = Vector3(cos(end_angle) * end_radius, 0.011, sin(end_angle) * end_radius)
		
		crack_st.add_vertex(start_point)
		crack_st.add_vertex(end_point)
		
		# Add a few branches from this crack
		var branch_count = randi_range(1, 3)
		for j in range(branch_count):
			var branch_start_t = randf_range(0.3, 0.7)
			var branch_point = start_point.lerp(end_point, branch_start_t)
			
			var branch_angle = end_angle + randf_range(-PI/4, PI/4)
			var branch_length = (end_radius - start_radius) * randf_range(0.3, 0.5)
			var branch_end = branch_point + Vector3(
				cos(branch_angle) * branch_length,
				0,
				sin(branch_angle) * branch_length
			)
			
			crack_st.add_vertex(branch_point)
			crack_st.add_vertex(branch_end)

	cracks.mesh = crack_st.commit()
	
	# Create crack material
	var crack_material = StandardMaterial3D.new()
	crack_material.albedo_color = Color(1.0, 1.0, 1.0, 0.5)
	crack_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cracks.material_override = crack_material
	
	pond.add_child(cracks)
	
	# Add snow edge around the pond
	var snow_edge = MeshInstance3D.new()
	snow_edge.name = "SnowEdge"
	var edge_mesh = TorusMesh.new()
	edge_mesh.inner_radius = radius
	edge_mesh.outer_radius = radius + 0.1
	edge_mesh.rings = 16
	edge_mesh.sections = 6
	snow_edge.mesh = edge_mesh
	snow_edge.rotation_degrees.x = 90
	
	var snow_material = vegetation_factory.get_shared_material(Color(0.95, 0.95, 1.0))
	snow_edge.material_override = snow_material
	
	pond.add_child(snow_edge)
	
	return pond

func UT_align_with_normal(normal: Vector3) -> Transform3D:
	# If normal is very close to up vector, return identity transform
	if normal.is_equal_approx(Vector3.UP):
		return Transform3D()
	
	var up = Vector3.UP
	var axis = up.cross(normal).normalized()
	
	# If axis is too small, surface is probably flat
	if axis.length_squared() < 0.001:
		return Transform3D()
	
	var angle = up.angle_to(normal)
	
	# If angle is very small, don't rotate
	if abs(angle) < 0.1:  # About 5.7 degrees
		return Transform3D()
		
	return Transform3D(Basis().rotated(axis, angle))
