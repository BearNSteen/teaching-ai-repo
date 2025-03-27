@tool
extends BiomeVegetationGenerator
class_name GothicGenerator


var gothic_tree_count: int = 0
var gravestone_count: int = 0
var iron_fence_count: int = 0
var gothic_fog_color: Color = Color(0.7, 0.7, 0.9, 0.3)

func _init():
	super()

func CF_configure(veg_factory, grid, terrain, biome, tile_features_dict: Dictionary, buildings_dict = null, fog_color = null):
	super.CF_configure(veg_factory, grid, terrain, biome, tile_features_dict, buildings_dict)
	if fog_color:
		gothic_fog_color = fog_color
	set_density(0, 3)
	return self

func GEN_generate_vegetation(parent_node: Node3D = null) -> void:
	# Reset counters
	gothic_tree_count = 0
	gravestone_count = 0
	iron_fence_count = 0
	
	# Create parent node for all vegetation elements if not provided
	var vegetation_parent = SET_setup_vegetation_parent(parent_node)
	
	# Collect positions for all vegetation types
	var vegetation_data = POS_collect_vegetation_positions()
	
	# Create gothic trees
	if vegetation_data.tree_positions.size() > 0:
		BLD_create_gothic_trees_group(vegetation_parent, vegetation_data)
	
	# Create gravestones
	if vegetation_data.gravestone_positions.size() > 0:
		BLD_create_gravestones_group(vegetation_parent, vegetation_data)
	
	# Create iron fences
	if vegetation_data.fence_positions.size() > 0:
		BLD_create_iron_fences_group(vegetation_parent, vegetation_data)
	
	# Add a global fog effect to the gothic biome
	SF_add_gothic_fog(vegetation_parent)
	
	# Set ownership for editor
	if Engine.is_editor_hint() and get_tree().edited_scene_root:
		recursive_set_owner(vegetation_parent, get_tree().edited_scene_root)

func SET_setup_vegetation_parent(parent_node: Node3D = null) -> Node3D:
	if parent_node:
		return parent_node
	
	var vegetation_parent = Node3D.new()
	vegetation_parent.name = "GothicVegetation"
	add_child(vegetation_parent)
	return vegetation_parent

func POS_collect_vegetation_positions() -> Dictionary:
	var data = {
		"tree_positions": [],
		"tree_rotations": [],
		"tree_normals": [],
		"gravestone_positions": [],
		"gravestone_rotations": [],
		"gravestone_normals": [],
		"fence_positions": [],
		"fence_rotations": [],
		"fence_normals": []
	}
	
	# Iterate through grid to find suitable positions for vegetation
	for x in range(grid_size):
		for z in range(grid_size):
			# Skip special tiles and building locations
			if is_special_tile(x, z) or is_building_tile(x, z):
				continue
			
			# Check if current tile is in gothic biome
			if biome_gen.get_tile_biome(x, z) == "gothic":
				POS_populate_tile_vegetation(x, z, data)
	
	return data

func POS_populate_tile_vegetation(x: int, z: int, data: Dictionary) -> void:
	# Decide what to place in this tile
	var choice = randf()
	var vegetation_type = "tree"
	
	if choice < 0.4:  # 40% chance for trees
		vegetation_type = "tree"
	elif choice < 0.7:  # 30% chance for gravestones
		vegetation_type = "gravestone"
	else:  # 30% chance for fences
		vegetation_type = "fence"
	
	# Generate random number of vegetation items based on density settings
	var count = 1 if vegetation_type == "fence" else randi_range(min_density, max_density)
	var result = generate_positions_in_tile(x, z, count, 0.3)
	var positions = result[0]
	var normals = result[1]
	
	# Add generated positions and random rotations to arrays
	for i in range(positions.size()):
		if vegetation_type == "tree":
			data.tree_positions.append(positions[i])
			data.tree_rotations.append(randf_range(0, PI * 2))
			data.tree_normals.append(normals[i])
			gothic_tree_count += 1
		elif vegetation_type == "gravestone":
			data.gravestone_positions.append(positions[i])
			# Gravestones tend to face the same direction in a cemetery
			data.gravestone_rotations.append(randf_range(-PI/8, PI/8) + (0.0 if randf() < 0.5 else PI))
			data.gravestone_normals.append(normals[i])
			gravestone_count += 1
		else:  # fence
			data.fence_positions.append(positions[i])
			data.fence_rotations.append(randf_range(0, PI * 2))
			data.fence_normals.append(normals[i])
			iron_fence_count += 1

func BLD_create_gothic_trees_group(parent: Node3D, data: Dictionary) -> void:
	var tree_container = Node3D.new()
	tree_container.name = "GothicTrees"
	parent.add_child(tree_container)
	
	for i in range(data.tree_positions.size()):
		var tree = BLD_create_gothic_tree(i)
		tree.position = data.tree_positions[i]
		
		# Apply normal alignment for varied terrain
		var normal_transform = UT_align_with_normal(data.tree_normals[i])
		tree.rotation.y = data.tree_rotations[i]
		tree.transform = tree.transform * normal_transform
		
		tree_container.add_child(tree)

func BLD_create_gravestones_group(parent: Node3D, data: Dictionary) -> void:
	var gravestone_container = Node3D.new()
	gravestone_container.name = "Gravestones"
	parent.add_child(gravestone_container)
	
	for i in range(data.gravestone_positions.size()):
		var gravestone = BLD_create_gravestone(i)
		gravestone.position = data.gravestone_positions[i]
		
		# Apply normal alignment for varied terrain
		var normal_transform = UT_align_with_normal(data.gravestone_normals[i])
		gravestone.rotation.y = data.gravestone_rotations[i]
		gravestone.transform = gravestone.transform * normal_transform
		
		gravestone_container.add_child(gravestone)

func BLD_create_iron_fences_group(parent: Node3D, data: Dictionary) -> void:
	var fence_container = Node3D.new()
	fence_container.name = "IronFences"
	parent.add_child(fence_container)
	
	for i in range(data.fence_positions.size()):
		var fence = BLD_create_iron_fence(i)
		fence.position = data.fence_positions[i]
		
		# Apply normal alignment and rotation
		var normal_transform = UT_align_with_normal(data.fence_normals[i])
		fence.rotation.y = data.fence_rotations[i]
		fence.transform = fence.transform * normal_transform
		
		fence_container.add_child(fence)

func BLD_create_gothic_tree(index: int) -> Node3D:
	# Create a unique gothic tree (dead-looking with twisted branches)
	var tree = Node3D.new()
	tree.name = "GothicTree_%d" % index
	
	# Create the main trunk
	var trunk = MeshInstance3D.new()
	trunk.name = "GothicTrunk_%d" % index
	var trunk_mesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.03
	trunk_mesh.bottom_radius = 0.05
	trunk_mesh.height = 0.7
	trunk.mesh = trunk_mesh
	trunk.position.y = 0.35
	
	# Dark wood material
	var wood_material = vegetation_factory.get_shared_material(Color(0.2, 0.15, 0.1))
	trunk.material_override = wood_material
	
	tree.add_child(trunk)
	
	# Create twisted branches
	var branch_count = randi_range(3, 5)
	for i in range(branch_count):
		var branch = MeshInstance3D.new()
		branch.name = "GothicBranch_%d_%d" % [index, i]
		
		var branch_mesh = CylinderMesh.new()
		branch_mesh.top_radius = 0.01
		branch_mesh.bottom_radius = 0.02
		branch_mesh.height = 0.4
		branch.mesh = branch_mesh
		
		# Position branch along the trunk
		var height = 0.3 + i * 0.1
		var angle = i * (2 * PI / branch_count)
		branch.position = Vector3(0, height, 0)
		
		# Create a twisted appearance with multiple rotations
		branch.rotation_degrees = Vector3(
			randf_range(20, 50) * (1 if randf() < 0.5 else -1),  # Tilt up or down
			rad_to_deg(angle),  # Rotate around trunk
			randf_range(-20, 20)  # Random twist
		)
		
		branch.material_override = wood_material
		trunk.add_child(branch)
		
		# Sometimes add smaller sub-branches
		if randf() < 0.7:
			var twig = MeshInstance3D.new()
			twig.name = "GothicTwig_%d_%d" % [index, i]
			
			var twig_mesh = CylinderMesh.new()
			twig_mesh.top_radius = 0.005
			twig_mesh.bottom_radius = 0.01
			twig_mesh.height = 0.2
			twig.mesh = twig_mesh
			
			twig.position = Vector3(0, 0.15, 0)
			twig.rotation_degrees = Vector3(
				randf_range(-40, 40),
				randf_range(-40, 40),
				randf_range(-40, 40)
			)
			
			twig.material_override = wood_material
			branch.add_child(twig)
	
	# Add spooky particle effects (wisps)
	var particles = GPUParticles3D.new()
	particles.name = "GhostlyWisps_%d" % index
	
	var particle_material = ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	particle_material.emission_box_extents = Vector3(0.3, 0.5, 0.3)
	particle_material.direction = Vector3(0, 1, 0)
	particle_material.spread = 20.0
	particle_material.gravity = Vector3(0, 0.01, 0)  # Slight upward drift
	particle_material.initial_velocity_min = 0.02
	particle_material.initial_velocity_max = 0.05
	particle_material.scale_min = 0.05
	particle_material.scale_max = 0.1
	
	particles.process_material = particle_material
	
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(0.1, 0.1)
	particles.draw_pass_1 = quad_mesh
	
	particles.amount = 10
	particles.lifetime = 4.0
	particles.position.y = 0.4
	
	var wisp_material = StandardMaterial3D.new()
	wisp_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wisp_material.albedo_color = Color(0.8, 0.8, 0.9, 0.2)
	wisp_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	particles.material_override = wisp_material
	
	tree.add_child(particles)
	
	return tree

func BLD_create_gravestone(index: int) -> Node3D:
	# Create a unique gravestone
	var gravestone = Node3D.new()
	gravestone.name = "Gravestone_%d" % index
	
	# Choose a random gravestone style
	var style = randi() % 3  # 0 = simple, 1 = cross, 2 = ornate
	
	match style:
		0:  # Simple rectangular gravestone
			var stone = MeshInstance3D.new()
			stone.name = "SimpleStone_%d" % index
			
			var stone_mesh = BoxMesh.new()
			stone_mesh.size = Vector3(0.15, 0.3, 0.05)
			stone.mesh = stone_mesh
			stone.position.y = 0.15
			
			# Create stone material
			var stone_material = vegetation_factory.get_shared_material(Color(0.5, 0.5, 0.55))
			stone.material_override = stone_material
			
			gravestone.add_child(stone)
			
			# Add a subtle engraving texture
			var engraving = MeshInstance3D.new()
			engraving.name = "Engraving_%d" % index
			
			var engraving_mesh = QuadMesh.new()
			engraving_mesh.size = Vector2(0.13, 0.13)
			engraving.mesh = engraving_mesh
			
			engraving.position = Vector3(0, 0.15, 0.026)
			
			# Create engraving material
			var engraving_material = StandardMaterial3D.new()
			engraving_material.albedo_color = Color(0.4, 0.4, 0.45)
			engraving.material_override = engraving_material
			
			stone.add_child(engraving)
			
		1:  # Cross gravestone
			var base = MeshInstance3D.new()
			base.name = "CrossBase_%d" % index
			
			var base_mesh = BoxMesh.new()
			base_mesh.size = Vector3(0.15, 0.1, 0.15)
			base.mesh = base_mesh
			base.position.y = 0.05
			
			var vertical = MeshInstance3D.new()
			vertical.name = "CrossVertical_%d" % index
			
			var vertical_mesh = BoxMesh.new()
			vertical_mesh.size = Vector3(0.05, 0.3, 0.05)
			vertical.mesh = vertical_mesh
			vertical.position.y = 0.25
			
			var horizontal = MeshInstance3D.new()
			horizontal.name = "CrossHorizontal_%d" % index
			
			var horizontal_mesh = BoxMesh.new()
			horizontal_mesh.size = Vector3(0.15, 0.05, 0.05)
			horizontal.mesh = horizontal_mesh
			horizontal.position.y = 0.2
			
			# Create stone material
			var stone_material = vegetation_factory.get_shared_material(Color(0.5, 0.5, 0.55))
			base.material_override = stone_material
			vertical.material_override = stone_material
			horizontal.material_override = stone_material
			
			gravestone.add_child(base)
			gravestone.add_child(vertical)
			gravestone.add_child(horizontal)
			
		2:  # Ornate gravestone
			var base = MeshInstance3D.new()
			base.name = "OrnateBase_%d" % index
			
			var base_mesh = BoxMesh.new()
			base_mesh.size = Vector3(0.2, 0.1, 0.15)
			base.mesh = base_mesh
			base.position.y = 0.05
			
			var body = MeshInstance3D.new()
			body.name = "OrnateBody_%d" % index
			
			var body_mesh = BoxMesh.new()
			body_mesh.size = Vector3(0.18, 0.25, 0.1)
			body.mesh = body_mesh
			body.position.y = 0.22
			
			var top = MeshInstance3D.new()
			top.name = "OrnateTop_%d" % index
			
			# Create a triangular top using PrismMesh
			var top_mesh = PrismMesh.new()
			top_mesh.size = Vector3(0.18, 0.1, 0.1)
			top.mesh = top_mesh
			top.position.y = 0.4
			
			# Create stone material
			var stone_material = vegetation_factory.get_shared_material(Color(0.5, 0.5, 0.55))
			base.material_override = stone_material
			body.material_override = stone_material
			top.material_override = stone_material
			
			gravestone.add_child(base)
			gravestone.add_child(body)
			gravestone.add_child(top)
			
			# Add ornate details
			var detail = MeshInstance3D.new()
			detail.name = "OrnateDetail_%d" % index
			
			var detail_mesh = SphereMesh.new()
			detail_mesh.radius = 0.03
			detail_mesh.height = 0.06
			detail.mesh = detail_mesh
			detail.position = Vector3(0, 0.32, 0.06)
			
			var detail_material = vegetation_factory.get_shared_material(Color(0.6, 0.6, 0.65))
			detail.material_override = detail_material
			
			body.add_child(detail)
	
	# Add a base/ground
	var ground = MeshInstance3D.new()
	ground.name = "GraveBase_%d" % index
	
	var ground_mesh = BoxMesh.new()
	ground_mesh.size = Vector3(0.3, 0.02, 0.2)
	ground.mesh = ground_mesh
	ground.position.y = 0.01
	
	var ground_material = vegetation_factory.get_shared_material(Color(0.3, 0.25, 0.2))
	ground.material_override = ground_material
	
	gravestone.add_child(ground)
	
	# Occasionally add small particle effects
	if randf() < 0.3:
		var particles = GPUParticles3D.new()
		particles.name = "GhostlyWisps_%d" % index
		
		var particle_material = ParticleProcessMaterial.new()
		particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		particle_material.emission_box_extents = Vector3(0.1, 0.05, 0.1)
		particle_material.direction = Vector3(0, 1, 0)
		particle_material.spread = 10.0
		particle_material.gravity = Vector3(0, 0.01, 0)
		particle_material.initial_velocity_min = 0.01
		particle_material.initial_velocity_max = 0.03
		
		particles.process_material = particle_material
		
		var quad_mesh = QuadMesh.new()
		quad_mesh.size = Vector2(0.05, 0.05)
		particles.draw_pass_1 = quad_mesh
		
		particles.amount = 5
		particles.lifetime = 3.0
		particles.position.y = 0.1
		
		var wisp_material = StandardMaterial3D.new()
		wisp_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wisp_material.albedo_color = Color(0.8, 0.8, 0.9, 0.1)
		wisp_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		particles.material_override = wisp_material
		
		gravestone.add_child(particles)
	
	return gravestone

func BLD_create_iron_fence(index: int) -> Node3D:
	# Create a section of iron fence
	var fence = Node3D.new()
	fence.name = "IronFence_%d" % index
	
	# Create the fence section
	var width = 0.5
	var height = 0.3
	var post_radius = 0.02
	var post_count = 5  # Number of vertical posts
	
	# Create fence base
	var base = MeshInstance3D.new()
	base.name = "FenceBase_%d" % index
	
	var base_mesh = BoxMesh.new()
	base_mesh.size = Vector3(width, 0.05, 0.05)
	base.mesh = base_mesh
	base.position.y = 0.025
	
	var iron_material = StandardMaterial3D.new()
	iron_material.albedo_color = Color(0.1, 0.1, 0.1)
	iron_material.metallic = 0.8
	iron_material.roughness = 0.2
	base.material_override = iron_material
	
	fence.add_child(base)
	
	# Create vertical posts
	for i in range(post_count):
		var post = MeshInstance3D.new()
		post.name = "FencePost_%d_%d" % [index, i]
		
		var post_mesh = CylinderMesh.new()
		post_mesh.top_radius = post_radius
		post_mesh.bottom_radius = post_radius
		post_mesh.height = height
		post.mesh = post_mesh
		
		# Position posts along fence width
		var x_pos = -width/2 + i * (width / (post_count - 1))
		post.position = Vector3(x_pos, height/2, 0)
		
		post.material_override = iron_material
		fence.add_child(post)
		
		# Add decorative spikes to end posts
		if i == 0 or i == post_count - 1:
			var spike = MeshInstance3D.new()
			spike.name = "FenceSpike_%d_%d" % [index, i]
			
			var spike_mesh = CylinderMesh.new()
			spike_mesh.top_radius = 0.0
			spike_mesh.bottom_radius = post_radius
			spike_mesh.height = 0.05
			spike.mesh = spike_mesh
			
			spike.position.y = height/2 + 0.025
			spike.material_override = iron_material
			
			post.add_child(spike)
	
	# Create horizontal bars (2 rows)
	for row in range(2):
		var bar = MeshInstance3D.new()
		bar.name = "FenceBar_%d_%d" % [index, row]
		
		var bar_mesh = CylinderMesh.new()
		bar_mesh.top_radius = post_radius * 0.8
		bar_mesh.bottom_radius = post_radius * 0.8
		bar_mesh.height = width
		bar.mesh = bar_mesh
		
		bar.position.y = 0.1 + row * 0.15
		bar.rotation_degrees.z = 90
		
		bar.material_override = iron_material
		fence.add_child(bar)
	
	# Create a stone base
	var stone_base = MeshInstance3D.new()
	stone_base.name = "StoneBase_%d" % index
	
	var stone_mesh = BoxMesh.new()
	stone_mesh.size = Vector3(width + 0.1, 0.05, 0.15)
	stone_base.mesh = stone_mesh
	stone_base.position.y = -0.025
	
	var stone_material = vegetation_factory.get_shared_material(Color(0.5, 0.5, 0.55))
	stone_base.material_override = stone_material
	
	fence.add_child(stone_base)
	
	return fence

func SF_add_gothic_fog(parent: Node3D) -> void:
	# Add ambient fog to the gothic biome area
	var fog = WorldEnvironment.new()
	fog.name = "GothicFog"
	
	var env = Environment.new()
	# Correct fog settings for Godot 4
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.01
	env.volumetric_fog_albedo = gothic_fog_color  # Use albedo instead of color
	env.volumetric_fog_emission = gothic_fog_color.lightened(0.2)  # Use emission instead of sun_color
	env.volumetric_fog_length = 64.0
	
	fog.environment = env
	
	parent.add_child(fog)
	
	# Add mist particles
	var mist = GPUParticles3D.new()
	mist.name = "MistParticles"
	
	var mist_material = ParticleProcessMaterial.new()
	mist_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mist_material.emission_box_extents = Vector3(5.0, 0.2, 5.0)  # Large area
	mist_material.direction = Vector3(0, 0.05, 0)
	mist_material.spread = 10.0
	mist_material.gravity = Vector3(0, 0, 0)  # No gravity
	mist_material.initial_velocity_min = 0.05
	mist_material.initial_velocity_max = 0.1
	mist_material.scale_min = 2.0
	mist_material.scale_max = 4.0
	
	mist.process_material = mist_material
	
	var mist_mesh = QuadMesh.new()
	mist_mesh.size = Vector2(2.0, 1.0)
	mist.draw_pass_1 = mist_mesh
	
	mist.amount = 30
	mist.lifetime = 8.0
	mist.position.y = 0.1
	
	var mist_material_override = StandardMaterial3D.new()
	mist_material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist_material_override.albedo_color = Color(0.8, 0.8, 0.9, 0.05)
	mist_material_override.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mist.material_override = mist_material_override
	
	parent.add_child(mist)

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
