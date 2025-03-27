@tool
extends BiomeVegetationGenerator
class_name DesertGenerator



var cactus_count: int = 0
var palm_count: int = 0

func _init():
	super()

func CF_configure(veg_factory, grid, terrain, biome, tile_features_dict: Dictionary, buildings_dict = null):
	super.CF_configure(veg_factory, grid, terrain, biome, tile_features_dict, buildings_dict)
	set_density(0, 2)
	return self

func SF_create_oasis(x: int, z: int, with_water: bool = true) -> Node3D:
	var oasis = Node3D.new()
	oasis.name = "Oasis_%d_%d" % [x, z]
	
	# Create a cluster of 4-7 palm trees
	var oasis_palm_count = randi_range(4, 7)
	var result = generate_positions_in_tile(x, z, oasis_palm_count, 0.25)
	var positions = result[0]
	var normals = result[1]
	
	for i in range(positions.size()):
		# Use the vegetation factory to create palm trees
		var palm = vegetation_factory.create_palm_tree(true)  # With wind sway
		palm.position = positions[i]
		palm.rotation.y = randf_range(0, PI * 2)
		
		# Apply scaling variation
		var scale_factor = 0.2 + randf_range(-0.05, 0.1)
		palm.scale = Vector3(scale_factor, scale_factor, scale_factor)
		
		# Apply normal alignment
		var normal_transform = UT_align_with_normal(normals[i])
		palm.transform = palm.transform * normal_transform
		
		oasis.add_child(palm)
	
	# Add a water feature if requested
	if with_water:
		var water = Node3D.new()
		water.name = "OasisWater"
		
		var water_mesh = MeshInstance3D.new()
		water_mesh.name = "WaterSurface"
		
		# Create a slightly irregular water surface shape
		var noise = FastNoiseLite.new()
		noise.seed = randi()
		noise.frequency = 0.5
		
		# Create a pool shape with ArrayMesh
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		
		var radius = 0.4
		var segments = 12
		var center = Vector3.ZERO
		
		# Create vertices with noise
		for i in range(segments):
			var angle = i * 2 * PI / segments
			var next_angle = (i + 1) * 2 * PI / segments
			
			var v0 = center
			var noise_offset1 = noise.get_noise_2d(cos(angle), sin(angle))
			var edge_radius1 = radius * (1.0 + noise_offset1 * 0.3)
			var v1 = center + Vector3(cos(angle) * edge_radius1, 0, sin(angle) * edge_radius1)
			
			var noise_offset2 = noise.get_noise_2d(cos(next_angle), sin(next_angle))
			var edge_radius2 = radius * (1.0 + noise_offset2 * 0.3)
			var v2 = center + Vector3(cos(next_angle) * edge_radius2, 0, sin(next_angle) * edge_radius2)
			
			# Create a triangle
			st.add_vertex(v0)
			st.add_vertex(v1)
			st.add_vertex(v2)
		
		water_mesh.mesh = st.commit()
		water_mesh.position.y = 0.05  # Slightly above ground
		
		# Create water material
		var water_material = StandardMaterial3D.new()
		water_material.albedo_color = Color(0.0, 0.4, 0.8, 0.7)
		water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		water_material.metallic = 0.8
		water_material.roughness = 0.1
		water_mesh.material_override = water_material
		
		water.add_child(water_mesh)
		
		# Add sandy shore around the water
		var shore = MeshInstance3D.new()
		shore.name = "SandyShore"
		var shore_mesh = CylinderMesh.new()
		shore_mesh.top_radius = radius * 1.5
		shore_mesh.bottom_radius = radius * 1.7
		shore_mesh.height = 0.1
		shore.mesh = shore_mesh
		shore.position.y = -0.05  # Slightly below water
		
		shore.material_override = vegetation_factory.get_shared_material(Color(0.9, 0.85, 0.7))
		water.add_child(shore)
		oasis.add_child(water)
	
	return oasis

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

func POS_collect_cactus_positions(used_tiles: Dictionary) -> Dictionary:
	var data = {
		"positions": [],
		"rotations": [],
		"normals": []
	}
	
	# Second pass - place cacti on remaining desert tiles
	for x in range(grid_size):
		for z in range(grid_size):
			if is_building_tile(x, z):
				continue
				
			var tile_key = str(x) + "," + str(z)
			if used_tiles.has(tile_key):
				continue
				
			if biome_gen.get_tile_biome(x, z) == "desert":
				# Random number of cacti based on density
				var count = randi_range(min_density, max_density)
				if count > 0:
					var result = generate_positions_in_tile(x, z, count, 0.3)
					var positions = result[0]
					var normals = result[1]
					
					for i in range(positions.size()):
						data.positions.append(positions[i])
						data.rotations.append(randf_range(0, PI * 2))
						data.normals.append(normals[i])
						cactus_count += 1
	
	return data

func POS_collect_palm_positions(oasis_positions: Array) -> Dictionary:
	var data = {
		"positions": [],
		"rotations": [],
		"scales": [],
		"normals": [],
		"used_tiles": {}
	}
	
	# First mark all oasis tiles as used to avoid placing palms on them
	for oasis_pos in oasis_positions:
		var tile_key = str(int(oasis_pos.x)) + "," + str(int(oasis_pos.y))
		data.used_tiles[tile_key] = true
	
	# First pass - place palm trees near oasis
	for x in range(grid_size):
		for z in range(grid_size):
			if is_building_tile(x, z):
				continue
				
			var tile_key = str(x) + "," + str(z)
			if data.used_tiles.has(tile_key):
				continue  # Skip this tile as it's either an oasis or already has palm trees
				
			if biome_gen.get_tile_biome(x, z) == "desert":
				# Check distance to nearest oasis
				var min_distance = INF
				for oasis_pos in oasis_positions:
					var distance = Vector2(x, z).distance_to(oasis_pos)
					min_distance = min(min_distance, distance)
				
				# Only place palm trees within 1.5 tiles of oasis, but not on the oasis itself
				if min_distance <= 1.5 and min_distance > 0:  # Added check to ensure not on oasis
					# 70% chance of palm trees per eligible tile for more visual impact
					if randf() < 0.7:
						var palm_count_for_tile = randi_range(1, 2)  # 1-2 palms per tile
						var result = generate_positions_in_tile(x, z, palm_count_for_tile, 0.4)
						var positions = result[0]
						var normals = result[1]
						
						for i in range(positions.size()):
							data.positions.append(positions[i])
							data.rotations.append(randf_range(0, PI * 2))
							data.scales.append(Vector3(0.2, 0.6, 0.2))
							data.normals.append(normals[i])
							palm_count += 1
						
						data.used_tiles[tile_key] = true
	
	return data

func BLD_create_cactus_multimesh(parent: Node3D, data: Dictionary) -> void:
	if data.positions.size() == 0:
		return
		
	var body_multimesh = MultiMesh.new()
	
	# Get cactus mesh from factory
	var cactus_data = vegetation_factory.get_cactus_meshes()
	body_multimesh.mesh = cactus_data.body_mesh
	
	body_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	body_multimesh.instance_count = data.positions.size()
	
	for i in range(data.positions.size()):
		var pos = data.positions[i]
		var rot = data.rotations[i]
		var normal = data.normals[i]
		
		# Apply normal-aligned transform with rotation
		var normal_transform = UT_align_with_normal(normal)
		normal_transform = normal_transform.rotated(Vector3.UP, rot)
		
		var body_transform = normal_transform
		body_transform.origin = pos
		# body_transform.origin.y += 0.25  # Body height offset
		
		body_multimesh.set_instance_transform(i, body_transform)
	
	var body_instance = MultiMeshInstance3D.new()
	body_instance.name = "CactusBodies"
	body_instance.multimesh = body_multimesh
	
	# Get material from factory
	body_instance.material_override = vegetation_factory.get_shared_material(Color(0.0, 0.5, 0.0))
	
	parent.add_child(body_instance)

func BLD_create_palm_trees(parent: Node3D, data: Dictionary) -> void:
	if data.positions.size() == 0:
		return
		
	var palm_container = Node3D.new()
	palm_container.name = "PalmTrees"
	parent.add_child(palm_container)
	
	for i in range(data.positions.size()):
		# Create a palm tree with procedural animation
		var palm = vegetation_factory.create_palm_tree(true)  # Enable wind sway
		
		var adjusted_position = data.positions[i]
		# adjusted_position.y += 0.4  # Larger offset to ensure visibility
		palm.position = adjusted_position
		
		# Apply normal alignment and rotation
		var normal = data.normals[i]
		var normal_transform = UT_align_with_normal(normal)
		palm.transform = palm.transform * normal_transform
		# palm.rotate_y(data.rotations[i])
		
		palm.scale = data.scales[i]
		
		# Add small dune under palm tree for aesthetic
		var dune = MeshInstance3D.new()
		dune.name = "SandDune"
		var dune_mesh = SphereMesh.new()
		dune_mesh.radius = 0.3
		dune_mesh.height = 0.15
		dune.mesh = dune_mesh
		dune.position = Vector3(0, -0.05, 0)  # Slightly below the ground
		dune.material_override = vegetation_factory.get_shared_material(Color(0.9, 0.85, 0.7))
		
		palm.add_child(dune)
		palm_container.add_child(palm)

func POS_find_oasis_positions() -> Array:
	var oasis_positions = []
	for x in range(grid_size):
		for z in range(grid_size):
			var key = str(x) + "," + str(z)
			if tile_features.get(key) == "Oasis":
				oasis_positions.append(Vector2(x, z))
				
	# Add default oasis if none defined
	if oasis_positions.size() == 0:
		oasis_positions.append(Vector2(-3, -2))  # Default oasis position
	
	return oasis_positions

func GEN_generate_vegetation(parent_node: Node3D = null) -> void:
	# Validate dependencies before proceeding
	if biome_gen == null:
		push_error("DesertGenerator: biome_gen is null during generate_vegetation!")
		return
		
	if terrain_gen == null:
		push_error("DesertGenerator: terrain_gen is null during generate_vegetation!")
		return
	
	# Reset counters
	cactus_count = 0
	palm_count = 0
	
	# Create parent node for all vegetation elements
	var vegetation_parent = SET_setup_vegetation_parent(parent_node)
	
	# Find oasis positions
	var oasis_positions = POS_find_oasis_positions()
	
	# Collect palm tree positions near oasis
	var palm_data = POS_collect_palm_positions(oasis_positions)
	
	# Collect cactus positions on remaining desert tiles
	var cactus_data = POS_collect_cactus_positions(palm_data.used_tiles)
	
	# Create cacti with multimesh
	BLD_create_cactus_multimesh(vegetation_parent, cactus_data)
	
	# Create palm trees with wind sway effect
	BLD_create_palm_trees(vegetation_parent, palm_data)
	
	# Set ownership for editor
	if Engine.is_editor_hint() and get_tree().edited_scene_root:
		recursive_set_owner(vegetation_parent, get_tree().edited_scene_root)

func SET_setup_vegetation_parent(parent_node: Node3D = null) -> Node3D:
	if parent_node:
		return parent_node
	
	var vegetation_parent = Node3D.new()
	vegetation_parent.name = "DesertVegetation"
	add_child(vegetation_parent)
	return vegetation_parent
