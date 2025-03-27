@tool
extends BiomeVegetationGenerator
class_name SweetsGenerator

var candy_tree_count: int = 0

func _init():
	super()

func CF_configure(veg_factory, grid, terrain, biome, tile_features_dict: Dictionary, buildings_dict = null):
	super.CF_configure(veg_factory, grid, terrain, biome, tile_features_dict, buildings_dict)
	set_density(1, 4)
	return self

func GEN_generate_vegetation(parent_node: Node3D = null) -> void:
	candy_tree_count = 0
	
	# Create parent node for all vegetation elements if not provided
	var vegetation_parent = SET_setup_vegetation_parent(parent_node)
	
	# Collect positions for trees
	var vegetation_data = POS_collect_vegetation_positions()
	
	if vegetation_data.tree_positions.size() > 0:
		BLD_create_candy_trees_group(vegetation_parent, vegetation_data)
	
		# Add candy pathway or sugar dust if we have enough trees
		if vegetation_data.tree_positions.size() >= 3:
			SF_add_sugar_dust(vegetation_parent)
	
	# Set ownership for editor
	if Engine.is_editor_hint() and get_tree().edited_scene_root:
		recursive_set_owner(vegetation_parent, get_tree().edited_scene_root)

func SET_setup_vegetation_parent(parent_node: Node3D = null) -> Node3D:
	if parent_node:
		return parent_node
	
	var vegetation_parent = Node3D.new()
	vegetation_parent.name = "SweetsVegetation"
	add_child(vegetation_parent)
	return vegetation_parent

func POS_collect_vegetation_positions() -> Dictionary:
	var data = {
		"tree_positions": [],
		"tree_rotations": [],
		"tree_colors": [],
		"tree_normals": []
	}
	
	for x in range(grid_size):
		for z in range(grid_size):
			if is_building_tile(x, z):
				continue
			
			if biome_gen.get_tile_biome(x, z) == "sweets":
				POS_populate_tile_vegetation(x, z, data)
	
	return data

func POS_populate_tile_vegetation(x: int, z: int, data: Dictionary) -> void:
	var count = randi_range(min_density, max_density)
	var result = generate_positions_in_tile(x, z, count, 0.2)
	var positions = result[0]
	var normals = result[1]
	
	for i in range(positions.size()):
		data.tree_positions.append(positions[i])
		data.tree_rotations.append(randf_range(0, PI * 2))
		data.tree_normals.append(normals[i])
		# Random cotton candy color
		data.tree_colors.append(Color(0.9, 0.7, 0.8) if randf() > 0.5 else Color(0.7, 0.8, 0.9))
		candy_tree_count += 1

func BLD_create_candy_trees_group(parent: Node3D, data: Dictionary) -> void:
	for i in range(data.tree_positions.size()):
		var tree = vegetation_factory.create_candy_tree(candy_tree_count - data.tree_positions.size() + i + 1)
		
		# Set position and normal alignment
		tree.position = data.tree_positions[i]
		var normal_transform = UT_align_with_normal(data.tree_normals[i])
		tree.transform = tree.transform * normal_transform
		tree.rotation.y = data.tree_rotations[i]
		
		# Set cotton candy color
		var top = UT_find_node_by_name(tree, "CandyTop_%d" % (candy_tree_count - data.tree_positions.size() + i + 1))
		if top and top.material_override:
			var top_material = top.material_override as StandardMaterial3D
			top_material.albedo_color = data.tree_colors[i]
		
		# Add some candy particles occasionally
		if randf() > 0.7:
			BLD_add_candy_sparkles(tree)
		
		# Add some candy decorations with varying colors
		for j in range(3):
			var candy = BLD_create_candy_decoration()
			candy.position = Vector3(
				randf_range(-0.2, 0.2),
				randf_range(0.4, 0.8),
				randf_range(-0.2, 0.2)
			)
			tree.add_child(candy)
		
		parent.add_child(tree)

func BLD_add_candy_sparkles(tree: Node3D) -> void:
	var sparkles = GPUParticles3D.new()
	sparkles.name = "CandySparkles"
	
	var particle_material = ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_material.emission_sphere_radius = 0.2
	particle_material.gravity = Vector3(0, -0.1, 0)
	particle_material.initial_velocity_min = 0.05
	particle_material.initial_velocity_max = 0.1
	particle_material.scale_min = 0.01
	particle_material.scale_max = 0.02
	particle_material.color = Color(1.0, 0.8, 0.9)  # Pink base color for all particles
	particle_material.hue_variation_min = -0.1  # Add some color variation
	particle_material.hue_variation_max = 0.1
	
	# Create the particle mesh
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(0.03, 0.03)
	sparkles.draw_pass_1 = quad_mesh
	
	# Create material for the particles
	var sparkle_material = StandardMaterial3D.new()
	sparkle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sparkle_material.albedo_color = Color(1.0, 1.0, 1.0, 0.7)
	sparkle_material.emission_enabled = true
	sparkle_material.emission = Color(1.0, 0.8, 0.9)
	sparkle_material.emission_energy = 1.5
	sparkle_material.billboard_mode = StandardMaterial3D.BILLBOARD_ENABLED  # Make particles always face camera
	
	sparkles.material_override = sparkle_material
	sparkles.process_material = particle_material
	sparkles.amount = 10
	sparkles.lifetime = 3.0
	sparkles.position.y = 0.6  # Close to cotton candy top
	sparkles.randomness = 1.0  # Add more randomness to particle behavior
	
	tree.add_child(sparkles)

func SF_add_sugar_dust(parent: Node3D) -> void:
	var sugar_dust = GPUParticles3D.new()
	sugar_dust.name = "SugarDust"
	
	var particle_material = ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	particle_material.emission_box_extents = Vector3(grid_size * tile_size / 3, 0.1, grid_size * tile_size / 3)
	particle_material.gravity = Vector3(0, -0.05, 0)
	particle_material.initial_velocity_min = 0.01
	particle_material.initial_velocity_max = 0.02
	particle_material.angular_velocity_min = 1.0  # Add some rotation to particles
	particle_material.angular_velocity_max = 2.0
	particle_material.color_ramp = UT_create_sugar_color_gradient()
	
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(0.02, 0.02)
	sugar_dust.draw_pass_1 = quad_mesh
	
	var dust_material = StandardMaterial3D.new()
	dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_material.albedo_color = Color(1.0, 0.95, 0.95, 0.3)
	dust_material.billboard_mode = StandardMaterial3D.BILLBOARD_ENABLED
	dust_material.vertex_color_use_as_albedo = true  # Use gradient colors
	sugar_dust.material_override = dust_material
	
	sugar_dust.process_material = particle_material
	sugar_dust.amount = 500
	sugar_dust.lifetime = 8.0
	sugar_dust.position.y = 0.2
	
	parent.add_child(sugar_dust)

func UT_create_sugar_color_gradient() -> Gradient:
	var gradient = Gradient.new()
	gradient.colors = [
		Color(1.0, 0.9, 0.9, 0.4),  # Light pink
		Color(0.9, 1.0, 0.9, 0.3),  # Light green
		Color(0.9, 0.9, 1.0, 0.3),  # Light blue
		Color(1.0, 1.0, 0.9, 0.2)   # Light yellow
	]
	gradient.offsets = [0.0, 0.3, 0.6, 1.0]
	return gradient

# Helper function to find a node by name
func UT_find_node_by_name(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	
	for child in node.get_children():
		var found = UT_find_node_by_name(child, node_name)
		if found:
			return found
	
	return null

func BLD_create_candy_decoration() -> Node3D:
	var candy = MeshInstance3D.new()
	candy.name = "CandyDecoration"
	
	# Randomly choose between different candy shapes
	var shape_type = randi() % 3
	
	match shape_type:
		0:  # Round candy
			var candy_mesh = SphereMesh.new()
			candy_mesh.radius = 0.05
			candy_mesh.height = 0.08
			candy.mesh = candy_mesh
		1:  # Star-shaped candy
			var prism = PrismMesh.new()
			prism.size = Vector3(0.08, 0.08, 0.04)
			candy.mesh = prism
			candy.rotation_degrees.x = 90
		2:  # Candy stick
			var cylinder = CylinderMesh.new()
			cylinder.top_radius = 0.02
			cylinder.bottom_radius = 0.02
			cylinder.height = 0.12
			candy.mesh = cylinder
			candy.rotation_degrees.x = randf_range(0, 90)
	
	# Create a bright, candy-colored material
	var candy_material = StandardMaterial3D.new()
	candy_material.albedo_color = Color(
		randf_range(0.8, 1.0),
		randf_range(0.3, 0.7),
		randf_range(0.3, 0.7)
	)
	candy_material.metallic = 0.2
	candy_material.roughness = 0.1
	
	candy.material_override = candy_material
	
	return candy

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
