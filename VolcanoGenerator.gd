@tool
extends BiomeVegetationGenerator
class_name VolcanoGenerator


var dead_tree_count: int = 0
var ash_plant_count: int = 0

func _init():
	super()

func BLD_apply_tree_particle_effects(tree: Node3D, idx: int, position: Vector3) -> void:
	var distance_to_center = position.distance_to(Vector3(0, 0, 0))
	var intensity = 1.0 - clamp(distance_to_center / 10.0, 0.0, 1.0)
	
	if tree.has_node("DeadBranch_" + str(idx) + "_1"):
		for j in range(1, 4):  # Branches 1-3
			var branch_name = "DeadBranch_%d_%d" % [idx, j]
			if tree.has_node(branch_name):
				var branch = tree.get_node(branch_name)
				if branch.has_node("AshParticles_" + str(idx) + "_" + str(j-1)):
					var particles = branch.get_node("AshParticles_" + str(idx) + "_" + str(j-1))
					particles.amount = 5 + int(intensity * 15)
					
					if particles.process_material:
						particles.process_material.initial_velocity_min = 0.02 + intensity * 0.1
						particles.process_material.initial_velocity_max = 0.05 + intensity * 0.2

func BLD_create_ash_plant(index: int) -> Node3D:
	# Create a unique volcanic ash plant
	var plant = Node3D.new()
	plant.name = "AshPlant_%d" % index
	var create_stem = false
	
	# Create the main stem
	if create_stem:
		var stem = MeshInstance3D.new()
		stem.name = "Stem_%d" % index
		var stem_mesh = CylinderMesh.new()
		stem_mesh.top_radius = 0.02
		stem_mesh.bottom_radius = 0.03
		stem_mesh.height = 0.3
		stem.mesh = stem_mesh
		stem.position.y = 0.15
		
		# Create a material that looks like charred/ashy plant
		var stem_material = vegetation_factory.get_shared_material(Color(0.3, 0.2, 0.2))
		stem.material_override = stem_material
		plant.add_child(stem)
		
	# Create spiky leaves
	var leaf_count = randi_range(3, 6)
	for i in range(leaf_count):
		var leaf = MeshInstance3D.new()
		leaf.name = "Leaf_%d_%d" % [index, i]
		
		# Create a spiky mesh using PrismMesh
		var leaf_mesh = PrismMesh.new()
		leaf_mesh.size = Vector3(0.02, 0.15, 0.04)
		leaf.mesh = leaf_mesh
		
		# Position around the center
		var angle = i * (2 * PI / leaf_count)
		var radius = 0.04
		leaf.position = Vector3(cos(angle) * radius, 0.075, sin(angle) * radius)
		
		# Rotate to point towards the center and upward
		var center_dir = -leaf.position.normalized()
		var up_dir = Vector3(0, 1, 0)
		var rotation_basis = Basis().looking_at(center_dir, up_dir)
		leaf.rotation = rotation_basis.get_euler()
		
		# Adjust the tilt upward
		leaf.rotate(leaf.transform.basis.x, -PI/4)  # Tilt up by 45 degrees
		
		# Ashy gray-red material
		var leaf_color = Color(0.6, 0.3, 0.2)
		leaf.material_override = vegetation_factory.get_shared_material(leaf_color)
		
		plant.add_child(leaf)
	
	# Add ash particles
	var particles = GPUParticles3D.new()
	particles.name = "AshParticles_%d" % index
	
	var particle_material = ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_material.emission_sphere_radius = 0.1
	particle_material.direction = Vector3(0, 1, 0)
	particle_material.spread = 20.0
	particle_material.gravity = Vector3(0, -0.1, 0)
	particle_material.initial_velocity_min = 0.02
	particle_material.initial_velocity_max = 0.05
	particle_material.scale_min = 0.01
	particle_material.scale_max = 0.02
	
	particles.process_material = particle_material
	
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(0.02, 0.02)
	particles.draw_pass_1 = quad_mesh
	
	particles.amount = 10
	particles.lifetime = 3.0
	particles.position.y = 0.3
	
	var ash_material = StandardMaterial3D.new()
	ash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ash_material.albedo_color = Color(0.2, 0.2, 0.2, 0.5)
	particles.material_override = ash_material
	
	plant.add_child(particles)
	
	# Create a small base of charred ground
	var base = MeshInstance3D.new()
	base.name = "Base_%d" % index
	var base_mesh = CylinderMesh.new()
	base_mesh.top_radius = 0.1
	base_mesh.bottom_radius = 0.12
	base_mesh.height = 0.03
	base.mesh = base_mesh
	base.position.y = 0.01
	
	# Dark ashy material
	var base_material = vegetation_factory.get_shared_material(Color(0.15, 0.12, 0.1))
	base.material_override = base_material
	
	plant.add_child(base)
	
	return plant

func BLD_create_ash_plants_group(parent: Node3D, data: Dictionary) -> void:
	var ash_plant_container = Node3D.new()
	ash_plant_container.name = "AshPlants"
	parent.add_child(ash_plant_container)
	
	for i in range(data.ash_plant_positions.size()):
		var ash_plant = BLD_create_ash_plant(i)
		ash_plant.position = data.ash_plant_positions[i]
		#ash_plant.position.y += 0.4  # Increase base height
		
		# Apply normal alignment if needed
		if data.ash_plant_normals[i].dot(Vector3.UP) < 0.99:
			var normal_transform = UT_align_with_normal(data.ash_plant_normals[i])
			ash_plant.transform = ash_plant.transform * normal_transform
		
		ash_plant.rotation.y = data.ash_plant_rotations[i]
		ash_plant_container.add_child(ash_plant)

func BLD_create_dead_trees(parent: Node3D, data: Dictionary) -> void:
	var tree_container = Node3D.new()
	tree_container.name = "DeadTrees"
	parent.add_child(tree_container)
	
	for i in range(data.tree_positions.size()):
		var tree = vegetation_factory.create_dead_tree(i)
		tree.position = data.tree_positions[i]
		#tree.position.y += 0.3
		
		# Apply normal alignment if needed
		if data.tree_normals[i].dot(Vector3.UP) < 0.99:
			var normal_transform = UT_align_with_normal(data.tree_normals[i])
			tree.transform = tree.transform * normal_transform
		
		tree.rotation.y = data.tree_rotations[i]
		
		# Apply particle effects
		BLD_apply_tree_particle_effects(tree, i, data.tree_positions[i])
		tree_container.add_child(tree)

func CF_configure(veg_factory, grid, terrain, biome, tile_features_dict: Dictionary, buildings_dict = null):
	super.CF_configure(veg_factory, grid, terrain, biome, tile_features_dict, buildings_dict)
	set_density(0, 2)
	return self

func GEN_generate_vegetation(parent_node: Node3D = null) -> void:
	# Reset counters
	dead_tree_count = 0
	ash_plant_count = 0
	
	# Create parent node for all vegetation elements if not provided
	var vegetation_parent = SET_setup_vegetation_parent(parent_node)
	
	# Collect positions for all vegetation types
	var vegetation_data = POS_collect_vegetation_positions()
	
	# Generate the actual vegetation instances
	if vegetation_data.tree_positions.size() > 0:
		BLD_create_dead_trees(vegetation_parent, vegetation_data)
	
	if vegetation_data.ash_plant_positions.size() > 0:
		BLD_create_ash_plants_group(vegetation_parent, vegetation_data)
	
	# Set ownership for editor
	if Engine.is_editor_hint() and get_tree().edited_scene_root:
		recursive_set_owner(vegetation_parent, get_tree().edited_scene_root)

func POS_collect_vegetation_positions() -> Dictionary:
	var data = {
		"tree_positions": [],
		"tree_rotations": [],
		"tree_normals": [],
		"ash_plant_positions": [],
		"ash_plant_rotations": [],
		"ash_plant_normals": []
	}
	
	# Iterate through grid to find suitable positions for vegetation
	for x in range(grid_size):
		for z in range(grid_size):
			# Skip special tiles and building locations
			if is_special_tile(x, z) or is_building_tile(x, z):
				continue
			
			# Check if current tile is in volcano biome
			if biome_gen.get_tile_biome(x, z) == "volcano":
				POS_populate_tile_vegetation(x, z, data)
	
	return data

func POS_populate_tile_vegetation(x: int, z: int, data: Dictionary) -> void:
	# Decide if we place ash plants or dead trees
	var place_dead_trees = randf() < 0.6  # 60% chance for dead trees
	
	# Generate random number of vegetation items based on density settings
	var count = randi_range(min_density, max_density)
	var result = generate_positions_in_tile(x, z, count, 0.25)
	var positions = result[0]
	var normals = result[1]
	
	# Add generated positions and random rotations to arrays
	for i in range(positions.size()):
		if place_dead_trees:
			data.tree_positions.append(positions[i])
			data.tree_rotations.append(randf_range(0, PI * 2))
			data.tree_normals.append(normals[i])
			dead_tree_count += 1
		else:
			data.ash_plant_positions.append(positions[i])
			data.ash_plant_rotations.append(randf_range(0, PI * 2))
			data.ash_plant_normals.append(normals[i])
			ash_plant_count += 1

func SET_setup_vegetation_parent(parent_node: Node3D = null) -> Node3D:
	if parent_node:
		return parent_node
	
	var vegetation_parent = Node3D.new()
	vegetation_parent.name = "VolcanoVegetation"
	add_child(vegetation_parent)
	return vegetation_parent

func SF_create_lava_vent(x: int, z: int) -> Node3D:
	var vent = Node3D.new()
	vent.name = "LavaVent_%d_%d" % [x, z]
	
	# Create the vent crater
	var crater = MeshInstance3D.new()
	crater.name = "Crater"
	var crater_mesh = CylinderMesh.new()
	crater_mesh.top_radius = 0.2
	crater_mesh.bottom_radius = 0.15
	crater_mesh.height = 0.1
	crater.mesh = crater_mesh
	crater.position.y = -0.05
	
	# Rocky material
	var crater_material = vegetation_factory.get_shared_material(Color(0.3, 0.2, 0.15))
	crater.material_override = crater_material
	
	vent.add_child(crater)
	
	# Create the lava pool
	var lava = MeshInstance3D.new()
	lava.name = "LavaPool"
	var lava_mesh = CylinderMesh.new()
	lava_mesh.top_radius = 0.15
	lava_mesh.bottom_radius = 0.14
	lava_mesh.height = 0.02
	lava.mesh = lava_mesh
	lava.position.y = -0.01
	
	# Glowing lava material
	var lava_material = StandardMaterial3D.new()
	lava_material.albedo_color = Color(1.0, 0.3, 0.0)
	lava_material.emission_enabled = true
	lava_material.emission = Color(1.0, 0.4, 0.0)
	lava_material.emission_energy = 2.0
	lava.material_override = lava_material
	
	vent.add_child(lava)
	
	# Add particle effects for smoke and embers
	var particles = GPUParticles3D.new()
	particles.name = "VentParticles"
	
	var particle_material = ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_material.emission_sphere_radius = 0.1
	particle_material.direction = Vector3(0, 1, 0)
	particle_material.spread = 10.0
	particle_material.gravity = Vector3(0, 0.1, 0)  # Slight upward gravity for hot air
	particle_material.initial_velocity_min = 0.1
	particle_material.initial_velocity_max = 0.3
	particle_material.scale_min = 0.1
	particle_material.scale_max = 0.3
	
	# Color randomness for ember-like effect
	particle_material.color_ramp = Gradient.new()
	particle_material.color_ramp.add_point(0.0, Color(1.0, 0.5, 0.0, 0.8))  # Orange-reddish
	particle_material.color_ramp.add_point(0.4, Color(0.3, 0.3, 0.3, 0.6))  # Gray smoke
	particle_material.color_ramp.add_point(1.0, Color(0.1, 0.1, 0.1, 0.0))  # Fade out
	
	particles.process_material = particle_material
	
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(0.2, 0.2)
	particles.draw_pass_1 = quad_mesh
	
	particles.amount = 30
	particles.lifetime = 2.0
	
	var particle_material_override = StandardMaterial3D.new()
	particle_material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particle_material_override.vertex_color_use_as_albedo = true
	particle_material_override.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	particles.material_override = particle_material_override
	
	vent.add_child(particles)
	
	return vent 

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
