@tool
extends Node3D
class_name WM_VGOld

const TERRAIN_HEIGHT_OFFSET = -0.271

var grid_size: int
var tile_size: float
var editor_root: Node
var grass_color: Color
var gothic_fog_color: Color

const GridManagerScript = preload("res://SCENES/DIORAMA_MAP/GridManager.gd")

var terrain_gen: Node
var biome_gen: Node
var grid_manager: GridManagerScript
var building_positions = {}
var tile_features: Dictionary

var tree_count: int = 0
var cactus_count: int = 0
var palm_count: int = 0
var dead_tree_count: int = 0
var snow_tree_count: int = 0
var gothic_tree_count: int = 0
var candy_tree_count: int = 0
var fish_plant_count: int = 0
var ice_crystal_count: int = 0
var cardboard_plant_count: int = 0

var grassland_density_min: int = 0
var grassland_density_max: int = 2
var desert_density_min: int = 0
var desert_density_max: int = 2
var volcano_density_min: int = 0
var volcano_density_max: int = 2
var snow_density_min: int = 0
var snow_density_max: int = 2
var gothic_density_min: int = 0
var gothic_density_max: int = 2
var sweets_density_min: int = 0
var sweets_density_max: int = 2
var fish_density_min: int = 0
var fish_density_max: int = 2
var ice_blocks_density_min: int = 0
var ice_blocks_density_max: int = 2
var cardboard_density_min: int = 0
var cardboard_density_max: int = 2

var density_multiplier: float = 0

@export_category("Grid")
@export var use_grid_placement: bool = false
@export var grid_cells_per_tile: int = 2  # How many grid cells per tile side (will create grid_cells_per_tile²)
@export_range(0.0, 1.0) var grid_jitter: float = 0.2  # How much randomness to add to grid positions

# Then create a method to set them
func set_vegetation_density(biome: String, min_count: int, max_count: int) -> void:
	match biome:
		"grassland":
			grassland_density_min = min_count
			grassland_density_max = max_count
		"desert":
			desert_density_min = min_count
			desert_density_max = max_count
		"volcano":
			volcano_density_min = min_count
			volcano_density_max = max_count
		"snow":
			snow_density_min = min_count
			snow_density_max = max_count
		"gothic":
			gothic_density_min = min_count
			gothic_density_max = max_count
		"sweets":
			sweets_density_min = min_count
			sweets_density_max = max_count

# Cache for shared materials
var material_cache = {}

func get_shared_material(color: Color, metallic: float = 0.0, roughness: float = 1.0) -> Material:
	var key = "%s_%f_%f" % [color.to_html(), metallic, roughness]
	if not material_cache.has(key):
		var material = StandardMaterial3D.new()
		material.albedo_color = color
		material.metallic = metallic
		material.roughness = roughness
		material_cache[key] = material
	return material_cache[key]

func set_dependencies(terrain_generator: Node, biome_generator: Node, _grid_manager: GridManagerScript, _grass_color: Color, _gothic_fog_color: Color, _tile_features: Dictionary) -> void:
	self.terrain_gen = terrain_generator
	self.biome_gen = biome_generator
	self.grid_manager = _grid_manager
	self.grass_color = _grass_color
	self.gothic_fog_color = _gothic_fog_color
	self.tile_features = _tile_features

func setup(grid_size: int, tile_size: float) -> void:
	self.grid_size = grid_size
	self.tile_size = tile_size
	
func set_building_positions(positions: Dictionary) -> void:
	self.building_positions = positions.duplicate()

func is_building_tile(x: int, z: int) -> bool:
	# First check direct building positions dictionary
	return building_positions.has(str(x) + "," + str(z))

func is_special_tile(x: int, z: int) -> bool:
	var special_tiles = [
		Vector2(grid_size/2, grid_size/2),  # Town center
		Vector2(2, 2),  # Lake
		Vector2(-3, -2),  # Desert oasis
		Vector2(6, 1),  # Cave
	]
	return Vector2(x, z) in special_tiles

# Helper function for grid or random placement in a tile
func generate_positions_in_tile(x: int, z: int, count: int, min_distance: float = 0.2) -> Array:
	var positions = []
	var normals = []
	var tile_pos = terrain_gen.get_tile_position(x, z)
	var tile_height = terrain_gen.get_tile_height(x, z)
	
	if use_grid_placement:
		# Define quadrants for grid placement
		var quadrants = [
			Vector2(-0.25, -0.25),  # Northwest 
			Vector2(0.25, -0.25),   # Northeast
			Vector2(-0.25, 0.25),   # Southwest
			Vector2(0.25, 0.25)     # Southeast
		]
		
		# If more than 4, divide vegetation evenly across quadrants
		var items_per_quadrant = int(count / 4)
		var remainder = count % 4
		
		for q_index in range(4):
			var quadrant = quadrants[q_index]
			var quadrant_count = items_per_quadrant
			
			# Distribute remainder items
			if remainder > 0:
				quadrant_count += 1
				remainder -= 1
			
			# Place multiple items within this quadrant
			for i in range(quadrant_count):
				# Calculate base position for this quadrant
				var base_x = tile_pos.x + quadrant.x * tile_size
				var base_z = tile_pos.z + quadrant.y * tile_size
				
				# For multiple items in a quadrant, create a mini-grid
				var mini_grid_size = ceil(sqrt(quadrant_count)) if quadrant_count > 1 else 1
				var cell_size = tile_size * 0.4 / mini_grid_size
				var row = i / mini_grid_size
				var col = i % mini_grid_size
				
				# Position within the mini-grid
				var grid_offset_x = col * cell_size - (cell_size * (mini_grid_size-1)) * 0.5
				var grid_offset_z = row * cell_size - (cell_size * (mini_grid_size-1)) * 0.5
				
				# Apply jitter to the position within the mini-grid cell
				if grid_jitter > 0:
					grid_offset_x += randf_range(-grid_jitter, grid_jitter) * cell_size * 0.5  
					grid_offset_z += randf_range(-grid_jitter, grid_jitter) * cell_size * 0.5
				
				positions.append(Vector3(
					base_x + grid_offset_x,
					tile_height + TERRAIN_HEIGHT_OFFSET, # Apply the offset here
					base_z + grid_offset_z
				))
				var normal = Vector3.UP  # Default normal if no specific calculation method exists
				normals.append(normal)
	else:
		# Original random placement implementation
		var attempts = 0
		var max_attempts = 20
		
		while positions.size() < count and attempts < max_attempts:
			var safe_area = tile_size * 0.8
			var half_safe = safe_area * 0.5
			
			var offset = Vector2(
				randf_range(-half_safe, half_safe),
				randf_range(-half_safe, half_safe)
			)
			
			var is_valid = true
			for existing_pos in positions:
				var existing_offset = Vector2(existing_pos.x - tile_pos.x, existing_pos.z - tile_pos.z)
				if existing_offset.distance_to(offset) < min_distance:
					is_valid = false
					break
			
			if is_valid:
				positions.append(Vector3(
					tile_pos.x + offset.x,
					tile_height + TERRAIN_HEIGHT_OFFSET, # Apply the offset here
					tile_pos.z + offset.y
				))
				var normal = terrain_gen.get_normal_at_position(tile_pos.x + offset.x, tile_pos.z + offset.y)
				normals.append(normal)
			
			attempts += 1
	
	# Return both positions and normals
	return [positions, normals]


func generate_forest() -> void:
	# Reset the tree counter for this generation pass
	tree_count = 0
	
	# Create parent node for all vegetation elements
	var vegetation_parent = Node3D.new()
	vegetation_parent.name = "GrasslandVegetation"
	add_child(vegetation_parent)
	
	# First collect all positions using original logic
	var vegetation_positions = []
	var vegetation_rotations = []
	
	# Iterate through grid to find suitable positions for vegetation
	for x in range(grid_size):
		for z in range(grid_size):
			# Skip special tiles and building locations
			if is_special_tile(x, z) or is_building_tile(x, z):
				continue
			
			# Check if current tile is in grassland biome
			if biome_gen.get_tile_biome(x, z) == "grassland":
				# Generate random number of vegetation items based on density settings
				var count = randi_range(grassland_density_min, grassland_density_max)
				var result = generate_positions_in_tile(x, z, count, 0.2)
				var positions = result[0]
				var normals = result[1]
				
				# Add generated positions and random rotations to arrays
				for i in range(positions.size()):
					vegetation_positions.append(positions[i])
					vegetation_rotations.append(randf_range(0, PI * 2))
					tree_count += 1
	
	# Early return if no valid positions were found
	if vegetation_positions.size() == 0:
		return
		
	# Create MultiMesh instances for each component
	var trunk_multimesh = MultiMesh.new()
	var canopy_multimesh = MultiMesh.new()
	
	# Setup mesh data
	var sample = create_grassland_tree(0)
	var trunk = find_node_by_name(sample, "Trunk_0")
	var canopy = find_node_by_name(sample, "Canopy_0")
	
	trunk_multimesh.mesh = trunk.mesh
	canopy_multimesh.mesh = canopy.mesh
	
	trunk_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	canopy_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	
	trunk_multimesh.instance_count = vegetation_positions.size()
	canopy_multimesh.instance_count = vegetation_positions.size()
	
	# Apply transforms
	for i in range(vegetation_positions.size()):
		var pos = vegetation_positions[i]
		var rot = vegetation_rotations[i]
		
		# Trunk transform
		var trunk_transform = Transform3D().rotated(Vector3.UP, rot)
		trunk_transform.origin = pos
		trunk_transform.origin.y += 0.2  # Trunk height offset
		trunk_multimesh.set_instance_transform(i, trunk_transform)
		
		# Canopy transform
		var canopy_transform = Transform3D().rotated(Vector3.UP, rot)
		canopy_transform.origin = pos
		canopy_transform.origin.y += 0.6  # Canopy height offset
		canopy_multimesh.set_instance_transform(i, canopy_transform)
	
	# Create and add MultiMeshInstance3D nodes
	var trunk_instance = MultiMeshInstance3D.new()
	trunk_instance.name = "TreeTrunks"
	trunk_instance.multimesh = trunk_multimesh
	trunk_instance.material_override = get_shared_material(Color(0.4, 0.3, 0.2))
	
	var canopy_instance = MultiMeshInstance3D.new()
	canopy_instance.name = "TreeCanopies"
	canopy_instance.multimesh = canopy_multimesh
	canopy_instance.material_override = get_shared_material(grass_color.darkened(0.1))
	
	vegetation_parent.add_child(trunk_instance)
	vegetation_parent.add_child(canopy_instance)
	
	if Engine.is_editor_hint() and editor_root:
		recursive_set_owner(vegetation_parent, editor_root)

func set_grid_placement(enabled: bool, jitter: float) -> void:
	self.use_grid_placement = enabled
	self.grid_jitter = jitter

func set_density(multiplier: float) -> void:
	self.density_multiplier = multiplier
	
	# Apply multiplier to density ranges
	grassland_density_min = max(0, int(1 * multiplier))
	grassland_density_max = max(1, int(4 * multiplier))
	sweets_density_min = max(0, int(1 * multiplier))
	sweets_density_max = max(1, int(4 * multiplier))
	desert_density_min = max(0, int(0 * multiplier))
	desert_density_max = max(1, int(2 * multiplier))
	volcano_density_min = max(0, int(0 * multiplier))
	volcano_density_max = max(1, int(2 * multiplier))
	snow_density_min = max(0, int(0 * multiplier))
	snow_density_max = max(1, int(2 * multiplier))
	gothic_density_min = max(0, int(0 * multiplier))
	gothic_density_max = max(1, int(3 * multiplier))
	fish_density_min = max(0, int(1 * multiplier))
	fish_density_max = max(1, int(3 * multiplier))
	ice_blocks_density_min = max(0, int(1 * multiplier))
	ice_blocks_density_max = max(1, int(3 * multiplier))
	cardboard_density_min = max(0, int(1 * multiplier))
	cardboard_density_max = max(1, int(3 * multiplier))

# Helper function to find a node by name
func find_node_by_name(node: Node, name: String) -> Node:
	if node.name == name:
		return node
	
	for child in node.get_children():
		var found = find_node_by_name(child, name)
		if found:
			return found
	
	return null

# Modified desert vegetation generation with MultiMesh
func generate_desert_vegetation() -> void:
	cactus_count = 0
	palm_count = 0
	
	var vegetation = Node3D.new()
	vegetation.name = "DesertVegetation"
	add_child(vegetation)
	
	# Collect positions first
	var cactus_positions = []
	var cactus_rotations = []
	var palm_positions = []
	var palm_rotations = []
	var palm_scales = []
	
	# Find the oasis tile(s) anywhere in the map
	var oasis_positions = []
	for x in range(grid_size):
		for z in range(grid_size):
			var key = str(x) + "," + str(z)
			if tile_features.get(key) == "Oasis":
				oasis_positions.append(Vector2(x, z))
	
	# Track tiles used for vegetation
	var used_tiles = {}
	
	# First pass - place palm trees near oasis, but more sparsely
	for x in range(grid_size):
		for z in range(grid_size):
			if is_building_tile(x, z):
				continue
				
			var tile_key = str(x) + "," + str(z)
			if used_tiles.has(tile_key):
				continue
				
			if biome_gen.get_tile_biome(x, z) == "desert":
				# Check distance to nearest oasis
				var min_distance = INF
				for oasis_pos in oasis_positions:
					var distance = Vector2(x, z).distance_to(oasis_pos)
					min_distance = min(min_distance, distance)
				
				# Only place palm trees within 1.5 tiles of oasis (reduced radius)
				if min_distance <= 1.5:
					# 50% chance of palm trees per eligible tile (reduced density)
					if randf() < 0.5:
						var palm_count_for_tile = 1  # Just 1 palm per tile to reduce crowding
						var result = generate_positions_in_tile(x, z, palm_count_for_tile, 0.4)
						var positions = result[0]
						
						for pos in positions:
							palm_positions.append(pos)
							palm_rotations.append(randf_range(0, PI * 2))
							palm_scales.append(Vector3(0.2, 0.2 + randf_range(-0.05, 0.05), 0.2))
							palm_count += 1
						
						used_tiles[tile_key] = true
	
	# Second pass - place cacti on remaining desert tiles
	for x in range(grid_size):
		for z in range(grid_size):
			if is_building_tile(x, z):
				continue
				
			var tile_key = str(x) + "," + str(z)
			if used_tiles.has(tile_key):
				continue
				
			if biome_gen.get_tile_biome(x, z) == "desert":
				# Increased cacti density to ensure more appear
				var count = randi_range(1, 3)  # Guaranteed at least 1 cactus per tile
				if count > 0:
					var result = generate_positions_in_tile(x, z, count, 0.3)
					var positions = result[0]
					
					for pos in positions:
						cactus_positions.append(pos)
						cactus_rotations.append(randf_range(0, PI * 2))
						cactus_count += 1
	
	print("Generated %d cacti and %d palm trees" % [cactus_count, palm_count])
	
	# The rest of the function remains the same as before
	
	# Handle cacti as before
	if cactus_positions.size() > 0:
		var body_multimesh = MultiMesh.new()
		
		var sample = create_cactus(0)
		var body = find_node_by_name(sample, "CactusBody_0")
		body_multimesh.mesh = body.mesh
		
		body_multimesh.transform_format = MultiMesh.TRANSFORM_3D
		body_multimesh.instance_count = cactus_positions.size()
		
		for i in range(cactus_positions.size()):
			var pos = cactus_positions[i]
			var rot = cactus_rotations[i]
			
			var body_transform = Transform3D().rotated(Vector3.UP, rot)
			body_transform.origin = pos
			body_transform.origin.y += 0.25  # Body height offset
			
			body_multimesh.set_instance_transform(i, body_transform)
		
		var body_instance = MultiMeshInstance3D.new()
		body_instance.name = "CactusBodies"
		body_instance.multimesh = body_multimesh
		body_instance.material_override = get_shared_material(Color(0.0, 0.5, 0.0))
		
		vegetation.add_child(body_instance)
	
	# Handle palm trees with better positioning
	if palm_positions.size() > 0:
		var palm_container = Node3D.new()
		palm_container.name = "PalmTrees"
		vegetation.add_child(palm_container)
		
		for i in range(palm_positions.size()):
			var palm = get_parent().create_palm_tree()
			
			var adjusted_position = palm_positions[i]
			adjusted_position.y += 0.4  # Maintain the larger offset to ensure visibility
			palm.position = adjusted_position
			
			palm.rotate_y(palm_rotations[i])
			palm.scale = palm_scales[i]
			palm_container.add_child(palm)
	
	if Engine.is_editor_hint() and editor_root:
		recursive_set_owner(vegetation, editor_root)

# Modified volcano vegetation generation to match grassland pattern
func generate_volcano_vegetation() -> void:
	dead_tree_count = 0
	
	var vegetation = Node3D.new()
	vegetation.name = "VolcanoVegetation"
	add_child(vegetation)
	
	# Collect positions first
	var tree_positions = []
	var tree_rotations = []
	
	for x in range(grid_size):
		for z in range(grid_size):
			if is_building_tile(x, z):
				continue
			
			if biome_gen.get_tile_biome(x, z) == "volcano":
				var count = randi_range(volcano_density_min, volcano_density_max)
				if count > 0:
					var result = generate_positions_in_tile(x, z, count, 0.3)
					var positions = result[0]
					
					for pos in positions:
						tree_positions.append(pos)
						tree_rotations.append(randf_range(0, PI * 2))
						dead_tree_count += 1
	
	if tree_positions.size() == 0:
		return
	
	# Create MultiMesh
	var trunk_multimesh = MultiMesh.new()
	
	# Setup mesh data
	var sample = create_dead_tree(0)
	var trunk = find_node_by_name(sample, "DeadTrunk_0")
	trunk_multimesh.mesh = trunk.mesh
	
	trunk_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	trunk_multimesh.instance_count = tree_positions.size()
	
	# Apply transforms
	for i in range(tree_positions.size()):
		var pos = tree_positions[i]
		var rot = tree_rotations[i]
		
		var trunk_transform = Transform3D().rotated(Vector3.UP, rot)
		trunk_transform.origin = pos
		trunk_transform.origin.y += 0.3  # Trunk height offset
		
		trunk_multimesh.set_instance_transform(i, trunk_transform)
	
	# Create and add MultiMeshInstance3D
	var trunk_instance = MultiMeshInstance3D.new()
	trunk_instance.name = "DeadTreeTrunks"
	trunk_instance.multimesh = trunk_multimesh
	trunk_instance.material_override = get_shared_material(Color(0.4, 0.3, 0.2))
	
	vegetation.add_child(trunk_instance)
	
	# For branches, we'll create separate MultiMeshes at different angles
	var branch_material = get_shared_material(Color(0.4, 0.3, 0.2))
	
	# Sample a branch for its mesh
	var branch_sample = find_node_by_name(sample, "DeadBranch_0_1")
	
	for branch_index in range(3):  # 3 branches per tree
		var branch_multimesh = MultiMesh.new()
		branch_multimesh.mesh = branch_sample.mesh
		branch_multimesh.transform_format = MultiMesh.TRANSFORM_3D
		branch_multimesh.instance_count = tree_positions.size()
		
		for i in range(tree_positions.size()):
			var pos = tree_positions[i]
			var base_rot = tree_rotations[i]
			
			# Create unique transform for this branch
			var branch_transform = Transform3D()
			branch_transform = branch_transform.rotated(Vector3.RIGHT, deg_to_rad(randf_range(30, 60)))
			branch_transform = branch_transform.rotated(Vector3.UP, base_rot + randf_range(-PI/4, PI/4))
			
			branch_transform.origin = pos
			branch_transform.origin.y += randf_range(0.3, 0.5)  # Vary height on trunk
			
			branch_multimesh.set_instance_transform(i, branch_transform)
		
		var branch_instance = MultiMeshInstance3D.new()
		branch_instance.name = "DeadTreeBranches_%d" % (branch_index + 1)
		branch_instance.multimesh = branch_multimesh
		branch_instance.material_override = branch_material
		
		vegetation.add_child(branch_instance)
	
	if Engine.is_editor_hint() and editor_root:
		recursive_set_owner(vegetation, editor_root)

# Modified ice vegetation generation to match grassland pattern
func generate_ice_vegetation() -> void:
	snow_tree_count = 0
	
	var vegetation = Node3D.new()
	vegetation.name = "IceVegetation"
	add_child(vegetation)
	
	# Collect positions first
	var tree_positions = []
	var tree_rotations = []
	
	for x in range(grid_size):
		for z in range(grid_size):
			if is_building_tile(x, z):
				continue
			
			if biome_gen.get_tile_biome(x, z) == "snow":
				var count = randi_range(snow_density_min, snow_density_max)
				if count > 0:
					var result = generate_positions_in_tile(x, z, count, 0.3)
					var positions = result[0]
					
					for pos in positions:
						tree_positions.append(pos)
						tree_rotations.append(randf_range(0, PI * 2))
						snow_tree_count += 1

	if tree_positions.size() == 0:
		return
	
	# Create MultiMesh instances for each component
	var trunk_multimesh = MultiMesh.new()
	var canopy_multimesh = MultiMesh.new()
	var snow_cap_multimesh = MultiMesh.new()
	
	# Setup mesh data
	var sample = create_snow_tree(0)
	var trunk = find_node_by_name(sample, "Trunk_0")
	var canopy = find_node_by_name(sample, "Canopy_0")
	var snow_cap = find_node_by_name(sample, "SnowCap_0")
	
	trunk_multimesh.mesh = trunk.mesh
	canopy_multimesh.mesh = canopy.mesh
	snow_cap_multimesh.mesh = snow_cap.mesh
	
	trunk_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	canopy_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	snow_cap_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	
	trunk_multimesh.instance_count = tree_positions.size()
	canopy_multimesh.instance_count = tree_positions.size()
	snow_cap_multimesh.instance_count = tree_positions.size()
	
	# Apply transforms
	for i in range(tree_positions.size()):
		var pos = tree_positions[i]
		var rot = tree_rotations[i]
		
		# Trunk transform
		var trunk_transform = Transform3D().rotated(Vector3.UP, rot)
		trunk_transform.origin = pos
		trunk_transform.origin.y += 0.2  # Trunk height offset
		trunk_multimesh.set_instance_transform(i, trunk_transform)
		
		# Canopy transform
		var canopy_transform = Transform3D().rotated(Vector3.UP, rot)
		canopy_transform.origin = pos
		canopy_transform.origin.y += 0.6  # Canopy height offset
		canopy_multimesh.set_instance_transform(i, canopy_transform)
		
		# Snow cap transform
		var snow_transform = Transform3D().rotated(Vector3.UP, rot)
		snow_transform.origin = pos
		snow_transform.origin.y += 0.7  # Snow cap height offset
		snow_cap_multimesh.set_instance_transform(i, snow_transform)
	
	# Create and add MultiMeshInstance3D nodes
	var trunk_instance = MultiMeshInstance3D.new()
	trunk_instance.name = "SnowTreeTrunks"
	trunk_instance.multimesh = trunk_multimesh
	trunk_instance.material_override = get_shared_material(Color(0.4, 0.3, 0.2))
	
	var canopy_instance = MultiMeshInstance3D.new()
	canopy_instance.name = "SnowTreeCanopies"
	canopy_instance.multimesh = canopy_multimesh
	canopy_instance.material_override = get_shared_material(Color(0.2, 0.5, 0.1))
	
	var snow_instance = MultiMeshInstance3D.new()
	snow_instance.name = "SnowTreeSnowCaps"
	snow_instance.multimesh = snow_cap_multimesh
	snow_instance.material_override = get_shared_material(Color(1, 1, 1))
	
	vegetation.add_child(trunk_instance)
	vegetation.add_child(canopy_instance)
	vegetation.add_child(snow_instance)
	
	if Engine.is_editor_hint() and editor_root:
		recursive_set_owner(vegetation, editor_root)

# For gothic, keep using individual instances since they have particles and styles
func generate_gothic_vegetation() -> void:
	gothic_tree_count = 0
	
	var vegetation = Node3D.new()
	vegetation.name = "GothicVegetation"
	add_child(vegetation)
	
	var decors_to_add = []
	
	seed(24680)  # Use fixed seed for reproducibility
	
	for x in range(grid_size):
		for z in range(grid_size):
			if is_building_tile(x, z):
				continue
			
			if biome_gen.get_tile_biome(x, z) == "gothic":
				var count = randi_range(gothic_density_min, gothic_density_max)
				if count > 0:
					var result = generate_positions_in_tile(x, z, count, 0.2)
					var positions = result[0]
					
					for pos in positions:
						var decor = create_gothic_tree(gothic_tree_count + 1)
						gothic_tree_count += 1
						
						decor.position = Vector3(pos.x, pos.y, pos.z)
						decor.rotate_y(randf_range(0, PI * 2))
						decors_to_add.append(decor)
	
	# Add all decorations at once
	for decor in decors_to_add:
		vegetation.add_child(decor)
	
	if Engine.is_editor_hint() and editor_root:
		recursive_set_owner(vegetation, editor_root)

# For candy trees, using a combination approach for visual variety
func generate_sweets_vegetation() -> void:
	candy_tree_count = 0
	
	var vegetation = Node3D.new()
	vegetation.name = "SweetsVegetation"
	add_child(vegetation)
	
	# Collect positions first
	var tree_positions = []
	var tree_rotations = []
	var tree_colors = []  # Store unique colors per tree
	
	for x in range(grid_size):
		for z in range(grid_size):
			if is_building_tile(x, z):
				continue
			
			if biome_gen.get_tile_biome(x, z) == "sweets":
				var count = randi_range(sweets_density_min, sweets_density_max)
				var result = generate_positions_in_tile(x, z, count, 0.2)
				var positions = result[0]
				
				for pos in positions:
					tree_positions.append(pos)
					tree_rotations.append(randf_range(0, PI * 2))
					# Random cotton candy color
					tree_colors.append(Color(0.9, 0.7, 0.8) if randf() > 0.5 else Color(0.7, 0.8, 0.9))
					candy_tree_count += 1
	
	if tree_positions.size() == 0:
		return
	
	# Using full trees since they need color variation
	for i in range(tree_positions.size()):
		var tree = create_candy_tree(candy_tree_count - tree_positions.size() + i + 1)
		
		# Set position and rotation
		tree.position = tree_positions[i]
		tree.rotation.y = tree_rotations[i]
		
		# Set cotton candy color
		var top = find_node_by_name(tree, "CandyTop_%d" % (candy_tree_count - tree_positions.size() + i + 1))
		if top and top.material_override:
			var top_material = top.material_override as StandardMaterial3D
			top_material.albedo_color = tree_colors[i]
		
		vegetation.add_child(tree)
	
	if Engine.is_editor_hint() and editor_root:
		recursive_set_owner(vegetation, editor_root)

func generate_fish_vegetation() -> void:
	fish_plant_count = 0
	
	var vegetation = Node3D.new()
	vegetation.name = "FishVegetation"
	add_child(vegetation)
	
	# Collect positions first
	var plant_positions = []
	var plant_rotations = []
	
	for x in range(grid_size):
		for z in range(grid_size):
			if is_building_tile(x, z):
				continue
			
			if biome_gen.get_tile_biome(x, z) == "fish":
				var count = randi_range(fish_density_min, fish_density_max)
				if count > 0:
					var result = generate_positions_in_tile(x, z, count, 0.3)
					var positions = result[0]
					
					for pos in positions:
						plant_positions.append(pos)
						plant_rotations.append(randf_range(0, PI * 2))
						fish_plant_count += 1
	
	if plant_positions.size() == 0:
		return
		
	# Create individual plants for visual variety
	for i in range(plant_positions.size()):
		var plant = create_fish_plant(fish_plant_count - plant_positions.size() + i + 1)
		plant.position = plant_positions[i]
		plant.rotation.y = plant_rotations[i]
		vegetation.add_child(plant)
	
	if Engine.is_editor_hint() and editor_root:
		recursive_set_owner(vegetation, editor_root)

func generate_ice_blocks_vegetation() -> void:
	ice_crystal_count = 0
	
	var vegetation = Node3D.new()
	vegetation.name = "ColoredIceBlocksVegetation"
	add_child(vegetation)
	
	# Collect positions first
	var crystal_positions = []
	var crystal_rotations = []
	var crystal_scales = []
	var crystal_colors = []  # New array to store colors
	
	for x in range(grid_size):
		for z in range(grid_size):
			if is_building_tile(x, z):
				continue
			
			if biome_gen.get_tile_biome(x, z) == "colored_ice_blocks":
				var count = randi_range(ice_blocks_density_min, ice_blocks_density_max)
				if count > 0:
					var result = generate_positions_in_tile(x, z, count, 0.3)
					var positions = result[0]
					
					for pos in positions:
						crystal_positions.append(pos)
						crystal_rotations.append(randf_range(0, PI * 2))
						crystal_scales.append(Vector3(
							randf_range(0.7, 1.3),
							randf_range(0.7, 1.3),
							randf_range(0.7, 1.3)
						))
						# Replace hash-based color selection with random choice
						var colors = [
							Color(1.0, 0.2, 0.2),  # Red
							Color(0.2, 0.6, 1.0),  # Blue
							Color(0.2, 1.0, 0.2),  # Green
							Color(1.0, 1.0, 0.2)   # Yellow
						]
						crystal_colors.append(colors[randi() % colors.size()])
						ice_crystal_count += 1
	
	if crystal_positions.size() == 0:
		return
		
	# Create individual crystals
	for i in range(crystal_positions.size()):
		var crystal = create_ice_crystal(ice_crystal_count - crystal_positions.size() + i + 1)
		crystal.position = crystal_positions[i]
		crystal.rotation.y = crystal_rotations[i]
		crystal.scale = crystal_scales[i]
		
		# Apply the calculated color to the main crystal
		var main_crystal = find_node_by_name(crystal, "MainCrystal_%d" % (ice_crystal_count - crystal_positions.size() + i + 1))
		if main_crystal:
			var material = main_crystal.material_override as StandardMaterial3D
			material.albedo_color = crystal_colors[i].lightened(0.2)  # Lighten slightly for crystal effect
			material.emission = crystal_colors[i].darkened(0.8)
		
		# Apply to smaller crystals with slight variation
		for j in range(crystal.get_child_count()):
			var child = crystal.get_child(j)
			if child.name.begins_with("SmallCrystal"):
				var small_material = child.material_override as StandardMaterial3D
				small_material.albedo_color = crystal_colors[i].lightened(0.3)
				small_material.emission = crystal_colors[i].darkened(0.7)
		
		vegetation.add_child(crystal)
	
	if Engine.is_editor_hint() and editor_root:
		recursive_set_owner(vegetation, editor_root)

func generate_cardboard_vegetation() -> void:
	cardboard_plant_count = 0
	
	var vegetation = Node3D.new()
	vegetation.name = "CardboardVegetation"
	add_child(vegetation)
	
	# Collect positions first
	var plant_positions = []
	var plant_rotations = []
	
	for x in range(grid_size):
		for z in range(grid_size):
			if is_building_tile(x, z):
				continue
			
			if biome_gen.get_tile_biome(x, z) == "cardboard":
				var count = randi_range(cardboard_density_min, cardboard_density_max)
				if count > 0:
					var result = generate_positions_in_tile(x, z, count, 0.3)
					var positions = result[0]
					
					for pos in positions:
						plant_positions.append(pos)
						plant_rotations.append(randf_range(0, PI * 2))
						cardboard_plant_count += 1
	
	if plant_positions.size() == 0:
		return
		
	# Create individual plants
	for i in range(plant_positions.size()):
		var plant = create_cardboard_plant(cardboard_plant_count - plant_positions.size() + i + 1)
		plant.position = plant_positions[i]
		plant.rotation.y = plant_rotations[i]
		vegetation.add_child(plant)
	
	if Engine.is_editor_hint() and editor_root:
		recursive_set_owner(vegetation, editor_root)
		
# Original vegetation creation functions preserved exactly as before
func create_grassland_tree(index: int) -> Node3D:
	var tree = Node3D.new()
	tree.name = "GrasslandTree_%d" % index
	
	var trunk = MeshInstance3D.new()
	trunk.name = "Trunk_%d" % index
	var trunk_mesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.05
	trunk_mesh.bottom_radius = 0.075
	trunk_mesh.height = 0.4
	trunk.mesh = trunk_mesh
	trunk.position.y = 0.2
	var trunk_material = StandardMaterial3D.new()
	trunk_material.albedo_color = Color(0.4, 0.3, 0.2)
	trunk.material_override = trunk_material
	
	var canopy = MeshInstance3D.new()
	canopy.name = "Canopy_%d" % index
	var canopy_mesh = SphereMesh.new()
	canopy_mesh.radius = 0.2
	canopy_mesh.height = 0.4
	canopy.mesh = canopy_mesh
	canopy.position.y = 0.6
	var canopy_material = StandardMaterial3D.new()
	canopy_material.albedo_color = Color(0.2, 0.5, 0.1).darkened(randf_range(0, 0.2))
	canopy.material_override = canopy_material
	
	tree.add_child(trunk)
	tree.add_child(canopy)
	return tree

func create_snow_tree(index: int) -> Node3D:
	var tree = create_grassland_tree(index)
	tree.name = "SnowTree_%d" % index
	var snow = MeshInstance3D.new()
	snow.name = "SnowCap_%d" % index
	var snow_mesh = SphereMesh.new()
	snow_mesh.radius = 0.22
	snow_mesh.height = 0.2
	snow.mesh = snow_mesh
	snow.position.y = 0.7
	var snow_material = StandardMaterial3D.new()
	snow_material.albedo_color = Color(1, 1, 1)
	snow.material_override = snow_material
	tree.add_child(snow)
	return tree

func create_cactus(index: int) -> Node3D:
	var cactus = Node3D.new()
	cactus.name = "Cactus_%d" % index
	
	var body = MeshInstance3D.new()
	body.name = "CactusBody_%d" % index
	var body_mesh = CylinderMesh.new()
	body_mesh.top_radius = 0.05
	body_mesh.bottom_radius = 0.07
	body_mesh.height = 0.5
	body.mesh = body_mesh
	body.position.y = 0.25
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.0, 0.5, 0.0)
	body.material_override = material
	
	cactus.add_child(body)
	
	for i in range(2):
		var arm = MeshInstance3D.new()
		arm.name = "CactusArm_%d_%d" % [index, i + 1]
		var arm_mesh = CylinderMesh.new()
		arm_mesh.top_radius = 0.03
		arm_mesh.bottom_radius = 0.04
		arm_mesh.height = 0.2
		arm.mesh = arm_mesh
		arm.position = Vector3(0, randf_range(0.2, 0.4), 0)
		arm.rotation_degrees.x = 90
		arm.rotation_degrees.y = randf_range(0, 360)
		arm.material_override = material
		cactus.add_child(arm)
	
	return cactus

func create_dead_tree(index: int) -> Node3D:
	var tree = Node3D.new()
	tree.name = "DeadTree_%d" % index
	
	var trunk = MeshInstance3D.new()
	trunk.name = "DeadTrunk_%d" % index
	var trunk_mesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.03
	trunk_mesh.bottom_radius = 0.05
	trunk_mesh.height = 0.6
	trunk.mesh = trunk_mesh
	trunk.position.y = 0.3
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.4, 0.3, 0.2)
	trunk.material_override = material
	
	tree.add_child(trunk)
	
	for i in range(3):
		var branch = MeshInstance3D.new()
		branch.name = "DeadBranch_%d_%d" % [index, i + 1]
		var branch_mesh = CylinderMesh.new()
		branch_mesh.top_radius = 0.01
		branch_mesh.bottom_radius = 0.02
		branch_mesh.height = 0.3
		branch.mesh = branch_mesh
		branch.position = Vector3(0, randf_range(0.3, 0.5), 0)
		branch.rotation_degrees.x = randf_range(30, 60)
		branch.rotation_degrees.y = randf_range(0, 360)
		branch.material_override = material
		tree.add_child(branch)
	
	return tree

func create_gothic_tree(index: int) -> Node3D:
	var decoration = Node3D.new()
	decoration.name = "GothicDecor_%d" % index
	
	# Randomly choose between different gothic elements
	match randi() % 3:
		0: # Gravestone
			var stone = MeshInstance3D.new()
			stone.name = "Gravestone_%d" % index
			
			# Create rounded-top gravestone shape
			var stone_mesh = CylinderMesh.new()
			stone_mesh.top_radius = 0.1
			stone_mesh.bottom_radius = 0.15
			stone_mesh.height = 0.4
			stone.mesh = stone_mesh
			
			var stone_material = StandardMaterial3D.new()
			stone_material.albedo_color = Color(0.4, 0.4, 0.45) # Weathered stone color
			stone.material_override = stone_material
			
			# Add a cross on top
			var cross = MeshInstance3D.new()
			var cross_mesh = BoxMesh.new()
			cross_mesh.size = Vector3(0.15, 0.2, 0.02)
			cross.mesh = cross_mesh
			cross.position.y = 0.25
			
			var cross_hor = MeshInstance3D.new()
			var cross_hor_mesh = BoxMesh.new()
			cross_hor_mesh.size = Vector3(0.1, 0.02, 0.02)
			cross_hor.mesh = cross_hor_mesh
			cross_hor.position.y = 0.2
			
			cross.material_override = stone_material
			cross_hor.material_override = stone_material
			
			decoration.add_child(stone)
			decoration.add_child(cross)
			decoration.add_child(cross_hor)
			
		1: # Gargoyle
			var gargoyle = MeshInstance3D.new()
			gargoyle.name = "Gargoyle_%d" % index
			
			# Create base
			var base_mesh = BoxMesh.new()
			base_mesh.size = Vector3(0.2, 0.1, 0.2)
			gargoyle.mesh = base_mesh
			
			# Create body
			var body = MeshInstance3D.new()
			var body_mesh = BoxMesh.new()
			body_mesh.size = Vector3(0.15, 0.2, 0.25)
			body.mesh = body_mesh
			body.position = Vector3(0, 0.15, 0)
			
			# Create wings
			var wing_l = MeshInstance3D.new()
			var wing_r = MeshInstance3D.new()
			var wing_mesh = PrismMesh.new()
			wing_mesh.size = Vector3(0.2, 0.15, 0.05)
			wing_l.mesh = wing_mesh
			wing_r.mesh = wing_mesh
			wing_l.position = Vector3(-0.15, 0.2, 0)
			wing_r.position = Vector3(0.15, 0.2, 0)
			wing_r.rotation_degrees.y = 180
			
			var gargoyle_material = StandardMaterial3D.new()
			gargoyle_material.albedo_color = Color(0.3, 0.3, 0.35)
			gargoyle.material_override = gargoyle_material
			body.material_override = gargoyle_material
			wing_l.material_override = gargoyle_material
			wing_r.material_override = gargoyle_material
			
			decoration.add_child(gargoyle)
			decoration.add_child(body)
			decoration.add_child(wing_l)
			decoration.add_child(wing_r)
			
		2: # Iron Fence Section
			var fence = Node3D.new()
			fence.name = "IronFence_%d" % index
			
			# Create vertical bars
			for i in range(3):
				var bar = MeshInstance3D.new()
				var bar_mesh = CylinderMesh.new()
				bar_mesh.top_radius = 0.02
				bar_mesh.bottom_radius = 0.02
				bar_mesh.height = 0.4
				bar.mesh = bar_mesh
				bar.position = Vector3((i - 1) * 0.1, 0.2, 0)
				
				var spike = MeshInstance3D.new()
				var spike_mesh = CylinderMesh.new()
				spike_mesh.top_radius = 0.0
				spike_mesh.bottom_radius = 0.02
				spike_mesh.height = 0.1
				spike.mesh = spike_mesh
				spike.position = Vector3((i - 1) * 0.1, 0.45, 0)
				
				var iron_material = StandardMaterial3D.new()
				iron_material.albedo_color = Color(0.15, 0.15, 0.2)
				iron_material.metallic = 1.0
				iron_material.roughness = 0.4
				
				bar.material_override = iron_material
				spike.material_override = iron_material
				
				fence.add_child(bar)
				fence.add_child(spike)
			
			# Add horizontal connectors
			for i in range(2):
				var connector = MeshInstance3D.new()
				var connector_mesh = BoxMesh.new()
				connector_mesh.size = Vector3(0.25, 0.02, 0.02)
				connector.mesh = connector_mesh
				connector.position.y = 0.1 + (i * 0.2)
				
				var iron_material = StandardMaterial3D.new()
				iron_material.albedo_color = Color(0.15, 0.15, 0.2)
				iron_material.metallic = 1.0
				iron_material.roughness = 0.4
				connector.material_override = iron_material
				
				fence.add_child(connector)
			
			decoration.add_child(fence)
	
	# Add some fog particles for atmosphere
	var particles = GPUParticles3D.new()
	particles.name = "FogParticles_%d" % index
	var particle_material = ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	particle_material.emission_box_extents = Vector3(0.3, 0.1, 0.3)
	particle_material.gravity = Vector3(0, 0.1, 0)
	particle_material.initial_velocity_min = 0.1
	particle_material.initial_velocity_max = 0.2

	# Create the particle mesh
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(0.1, 0.1)
	particles.draw_pass_1 = quad_mesh

	# Create material for the particles
	var fog_material = StandardMaterial3D.new()
	fog_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fog_material.albedo_color = gothic_fog_color
	fog_material.vertex_color_use_as_albedo = true
	particles.material_override = fog_material

	particles.process_material = particle_material
	particles.amount = 10
	particles.lifetime = 2.0
	particles.position.y = 0.1
	
	decoration.add_child(particles)
	
	# Randomly rotate the entire decoration
	decoration.rotation_degrees.y = randf_range(0, 360)
	
	return decoration

func create_candy_tree(index: int) -> Node3D:
	var tree = Node3D.new()
	tree.name = "CandyTree_%d" % index
	
	# Create striped trunk
	var trunk = MeshInstance3D.new()
	trunk.name = "CandyTrunk_%d" % index
	var trunk_mesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.06
	trunk_mesh.bottom_radius = 0.08
	trunk_mesh.height = 0.5
	trunk.mesh = trunk_mesh
	trunk.position.y = 0.25
	
	var trunk_material = StandardMaterial3D.new()
	trunk_material.albedo_color = Color(0.9, 0.4, 0.4)  # Pink trunk
	trunk.material_override = trunk_material
	
	# Create cotton candy top
	var candy_top = MeshInstance3D.new()
	candy_top.name = "CandyTop_%d" % index
	var top_mesh = SphereMesh.new()
	top_mesh.radius = 0.25
	top_mesh.height = 0.4
	candy_top.mesh = top_mesh
	candy_top.position.y = 0.65
	
	var top_material = StandardMaterial3D.new()
	# Randomly choose between pink and blue cotton candy
	var cotton_candy_color = Color(0.9, 0.7, 0.8) if randf() > 0.5 else Color(0.7, 0.8, 0.9)
	top_material.albedo_color = cotton_candy_color
	candy_top.material_override = top_material
	
	# Add some "candy" decorations
	for i in range(3):
		var candy = MeshInstance3D.new()
		candy.name = "Candy_%d_%d" % [index, i]
		var candy_mesh = SphereMesh.new()
		candy_mesh.radius = 0.05
		candy_mesh.height = 0.08
		candy.mesh = candy_mesh
		candy.position = Vector3(
			randf_range(-0.2, 0.2),
			randf_range(0.4, 0.8),
			randf_range(-0.2, 0.2)
		)
		
		var candy_material = StandardMaterial3D.new()
		candy_material.albedo_color = Color(
			randf_range(0.8, 1.0),
			randf_range(0.3, 0.7),
			randf_range(0.3, 0.7)
		)
		candy.material_override = candy_material
		tree.add_child(candy)
	
	tree.add_child(trunk)
	tree.add_child(candy_top)
	return tree

func create_fish_plant(index: int) -> Node3D:
	var plant = Node3D.new()
	plant.name = "SeaPlant_%d" % index
	
	# Add slight random tilt to the whole plant
	plant.rotate_x(randf_range(-0.1, 0.1))
	plant.rotate_z(randf_range(-0.1, 0.1))
	
	# Create main stem with more variation
	var stem = MeshInstance3D.new()
	stem.name = "Stem_%d" % index
	var stem_mesh = CylinderMesh.new()
	var stem_height = randf_range(0.4, 0.8)  # Increased variation
	stem_mesh.top_radius = randf_range(0.015, 0.025)
	stem_mesh.bottom_radius = randf_range(0.03, 0.05)
	stem_mesh.height = stem_height
	stem.mesh = stem_mesh
	stem.position.y = stem_height / 2
	
	var stem_material = StandardMaterial3D.new()
	stem_material.albedo_color = Color(0.2, 0.5, 0.4).darkened(randf_range(0, 0.2))
	stem.material_override = stem_material
	
	# Add fronds with more organic shape
	var num_fronds = randi_range(4, 7)  # More fronds for fuller look
	
	# Evenly distribute fronds around the stem for more consistent placement
	var angle_step = 2 * PI / num_fronds
	
	for i in range(num_fronds):
		var frond = MeshInstance3D.new()
		frond.name = "Frond_%d_%d" % [index, i]
		
		# Position fronds with vertical variation but more consistent spacing
		var height_factor = float(i) / (num_fronds - 1) if num_fronds > 1 else 0.5
		# Add some randomness to height but keep it within bounds
		height_factor = clamp(height_factor + randf_range(-0.1, 0.1), 0.1, 0.9)
		
		# Use angle_step for more even distribution around stem
		var angle = i * angle_step + randf_range(-0.2, 0.2)  # Small random variation
		frond.position.y = stem_height * height_factor
		
		# Create curved frond using ArrayMesh
		var mesh = ArrayMesh.new()
		var vertices = PackedVector3Array()
		var normals = PackedVector3Array()
		var uvs = PackedVector2Array()
		var indices = PackedInt32Array()
		
		var segments = 6
		var width_start = randf_range(0.1, 0.15)
		var width_end = 0.02
		var length = randf_range(0.4, 0.6)
		var curve_factor = randf_range(0.1, 0.2)
		var thickness = randf_range(0.015, 0.025)
		
		# Generate curved frond vertices with improved normals
		for j in range(segments + 1):
			var t = float(j) / segments
			var width = lerp(width_start, width_end, t)
			var height = length * t
			# Add organic curve with multiple components
			var curve = sin(t * PI) * curve_factor + cos(t * PI * 2) * curve_factor * 0.3
			
			# Front face
			vertices.push_back(Vector3(-width/2, height, curve + thickness/2))
			vertices.push_back(Vector3(width/2, height, curve + thickness/2))
			# Back face
			vertices.push_back(Vector3(-width/2, height, curve - thickness/2))
			vertices.push_back(Vector3(width/2, height, curve - thickness/2))
			
			# Calculate better normals for solid appearance
			var tangent = Vector3(0, 1, cos(t * PI) * curve_factor * PI).normalized()
			var right = Vector3(1, 0, 0)
			var normal = right.cross(tangent).normalized()
			
			normals.push_back(normal)
			normals.push_back(normal)
			normals.push_back(-normal)
			normals.push_back(-normal)
			
			uvs.push_back(Vector2(0, t))
			uvs.push_back(Vector2(1, t))
			uvs.push_back(Vector2(0, t))
			uvs.push_back(Vector2(1, t))
		
		# Create triangles (same as before but adjusted for new vertex layout)
		for j in range(segments):
			var base = j * 4
			# Front face
			indices.push_back(base)
			indices.push_back(base + 1)
			indices.push_back(base + 4)
			indices.push_back(base + 1)
			indices.push_back(base + 5)
			indices.push_back(base + 4)
			# Back face
			indices.push_back(base + 2)
			indices.push_back(base + 6)
			indices.push_back(base + 3)
			indices.push_back(base + 3)
			indices.push_back(base + 6)
			indices.push_back(base + 7)
			# Sides
			indices.push_back(base)
			indices.push_back(base + 2)
			indices.push_back(base + 4)
			indices.push_back(base + 2)
			indices.push_back(base + 6)
			indices.push_back(base + 4)
			indices.push_back(base + 1)
			indices.push_back(base + 5)
			indices.push_back(base + 3)
			indices.push_back(base + 3)
			indices.push_back(base + 5)
			indices.push_back(base + 7)
		
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		frond.mesh = mesh
		
		# Rotate frond around stem
		frond.rotate_y(angle)
		frond.rotate_x(randf_range(-0.3, 0.3))  # Add some tilt
		
		var frond_material = StandardMaterial3D.new()
		var colors = [
			Color(0.1, 0.4, 0.25),
			Color(0.2, 0.5, 0.3),
			Color(0.3, 0.6, 0.4),
			Color(0.4, 0.45, 0.2)
		]
		frond_material.albedo_color = colors[randi() % colors.size()].lightened(height_factor * 0.2)
		frond_material.roughness = 0.8
		
		# Remove transparency to make fronds solid
		frond_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		
		frond.material_override = frond_material
		
		stem.add_child(frond)
	
	plant.add_child(stem)
	return plant

func create_ice_crystal(index: int) -> Node3D:
	var crystal = Node3D.new()
	crystal.name = "IceCrystal_%d" % index
	
	# Create main crystal
	var main_crystal = MeshInstance3D.new()
	main_crystal.name = "MainCrystal_%d" % index
	
	var crystal_mesh = PrismMesh.new()
	crystal_mesh.size = Vector3(0.15, 0.4, 0.15)
	main_crystal.mesh = crystal_mesh
	main_crystal.position.y = crystal_mesh.size.y / 2
	
	var crystal_material = StandardMaterial3D.new()
	crystal_material.albedo_color = Color(0.7, 0.85, 0.95, 0.8)
	crystal_material.metallic = 0.2
	crystal_material.roughness = 0.1
	crystal_material.emission_enabled = true
	crystal_material.emission = Color(0.7, 0.85, 0.95, 0.8).darkened(0.8)
	crystal_material.emission_energy = 0.2
	crystal_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	# Set a high render priority to ensure crystals render on top of other transparent objects
	crystal_material.render_priority = 20
	
	main_crystal.material_override = crystal_material
	
	# Add smaller surrounding crystals
	for i in range(randi() % 3 + 1):
		var small_crystal = MeshInstance3D.new()
		small_crystal.name = "SmallCrystal_%d_%d" % [index, i]
		
		var small_mesh = PrismMesh.new()
		small_mesh.size = Vector3(0.08, 0.25, 0.08)
		small_crystal.mesh = small_mesh
		
		small_crystal.position = Vector3(
			randf_range(-0.1, 0.1),
			small_mesh.size.y / 2,
			randf_range(-0.1, 0.1)
		)
		small_crystal.rotation_degrees.y = randf_range(0, 360)
		
		var small_material = crystal_material.duplicate()
		small_material.albedo_color = small_material.albedo_color.lightened(0.1)
		small_crystal.material_override = small_material
		
		crystal.add_child(small_crystal)
	
	crystal.add_child(main_crystal)
	return crystal

func create_cardboard_plant(index: int) -> Node3D:
	var plant = Node3D.new()
	plant.name = "CardboardPlant_%d" % index
	
	# TRUNK - basic cylinder with texture
	var trunk = MeshInstance3D.new()
	trunk.name = "Trunk"
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.05
	cylinder.bottom_radius = 0.07
	cylinder.height = randf_range(0.5, 0.7)
	trunk.mesh = cylinder
	trunk.position.y = cylinder.height/2
	
	# Create detailed cardboard material
	var cardboard_material = StandardMaterial3D.new()
	cardboard_material.albedo_color = Color(0.82, 0.71, 0.55)
	cardboard_material.roughness = 0.95
	trunk.material_override = cardboard_material
	
	plant.add_child(trunk)
	
	# Skip the problematic torus mesh and use a simple BoxMesh for tape instead
	var tape = MeshInstance3D.new()
	tape.name = "Tape"
	var tape_mesh = BoxMesh.new()
	tape_mesh.size = Vector3(0.15, 0.01, 0.15)
	tape.mesh = tape_mesh
	tape.position.y = randf_range(0.15, cylinder.height-0.15)
	
	var tape_material = StandardMaterial3D.new()
	tape_material.albedo_color = Color(0.9, 0.9, 0.9, 0.7)
	tape_material.metallic = 0.2
	tape_material.roughness = 0.3
	tape_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tape.material_override = tape_material
	plant.add_child(tape)
	
	# Add leaves directly to the plant instead of branches
	var leaf_count = randi() % 3 + 2
	
	for i in range(leaf_count):
		# Create leaf
		var leaf = MeshInstance3D.new()
		leaf.name = "Leaf_%d" % i
		
		# Use simple quad for leaf
		var quad = QuadMesh.new()
		quad.size = Vector2(0.2, 0.3)
		leaf.mesh = quad
		
		# Position around the trunk
		var angle = i * (2 * PI / leaf_count)
		var height_pos = randf_range(0.3, cylinder.height * 0.9)
		var pos = Vector3(
			cos(angle) * 0.1,
			height_pos,
			sin(angle) * 0.1
		)
		leaf.position = pos

		# Calculate the direction and manually set the rotation
		var target_pos = Vector3(cos(angle) * 2, height_pos, sin(angle) * 2)
		var direction = target_pos - pos
		if direction.length() > 0.001:
			var basis = Basis()
			var z_axis = direction.normalized()
			var y_axis = Vector3.UP
			var x_axis = y_axis.cross(z_axis).normalized()
			# Recalculate y_axis to ensure orthogonality
			y_axis = z_axis.cross(x_axis).normalized()
			basis.x = x_axis
			basis.y = y_axis
			basis.z = z_axis
			leaf.transform.basis = basis
		
		# Give the leaf a paper-like material
		var leaf_material = StandardMaterial3D.new()
		
		# Randomly choose from a few construction paper colors
		var color_options = [
			Color(0.9, 0.6, 0.5),  # Light red/orange
			Color(0.7, 0.9, 0.6),  # Light green
			Color(0.6, 0.7, 0.9),  # Light blue
			Color(0.9, 0.9, 0.6)   # Light yellow
		]
		leaf_material.albedo_color = color_options[randi() % color_options.size()]
		leaf_material.roughness = 1.0
		leaf_material.metallic = 0.0
		leaf_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		
		leaf.material_override = leaf_material
		plant.add_child(leaf)
		
		# Add a simple pencil mark to some leaves
		if randf() > 0.5:
			var mark = MeshInstance3D.new()
			mark.name = "PencilMark"
			
			var mark_mesh = QuadMesh.new()
			mark_mesh.size = Vector2(0.05, 0.01)
			mark.mesh = mark_mesh
			
			# Position slightly in front of leaf
			mark.position = Vector3(0, 0, -0.001)
			if randf() > 0.5:
				mark.rotation_degrees = Vector3(0, 0, 45)
			
			var mark_material = StandardMaterial3D.new()
			mark_material.albedo_color = Color(0.2, 0.2, 0.2)
			mark_material.cull_mode = BaseMaterial3D.CULL_DISABLED
			mark.material_override = mark_material
			
			leaf.add_child(mark)
	
	# Add base
	var base = MeshInstance3D.new()
	base.name = "Base"
	var base_mesh = CylinderMesh.new()
	base_mesh.top_radius = 0.12
	base_mesh.bottom_radius = 0.14
	base_mesh.height = 0.03
	base.mesh = base_mesh
	base.position.y = 0.015
	
	var base_material = cardboard_material.duplicate()
	base_material.albedo_color = base_material.albedo_color.darkened(0.1)
	base.material_override = base_material
	plant.add_child(base)
	
	return plant

func create_detailed_cardboard_leaf(style: String, tree_idx: int, branch_idx: int, leaf_idx: int) -> Node3D:
	var leaf = Node3D.new()
	leaf.name = "Leaf_%d_%d_%d" % [tree_idx, branch_idx, leaf_idx]
	
	# Create the leaf mesh based on style
	var leaf_mesh = MeshInstance3D.new()
	leaf_mesh.name = "LeafMesh"
	
	match style:
		"round":
			# Create round leaf from multiple quads
			var base = QuadMesh.new()
			base.size = Vector2(0.15, 0.2)
			leaf_mesh.mesh = base
			
		"pointed":
			# Create pointed leaf (triangle-ish)
			var mesh = ArrayMesh.new()
			var vertices = PackedVector3Array()
			vertices.push_back(Vector3(0, 0, 0))
			vertices.push_back(Vector3(-0.08, 0.12, 0))
			vertices.push_back(Vector3(0, 0.25, 0))
			vertices.push_back(Vector3(0.08, 0.12, 0))
			
			var indices = PackedInt32Array([0, 1, 2, 0, 2, 3])
			var normals = PackedVector3Array()
			for i in range(4):
				normals.push_back(Vector3(0, 0, 1))
				
			var uvs = PackedVector2Array()
			uvs.push_back(Vector2(0.5, 0))
			uvs.push_back(Vector2(0, 0.5))
			uvs.push_back(Vector2(0.5, 1))
			uvs.push_back(Vector2(1, 0.5))
			
			var arrays = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = vertices
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_TEX_UV] = uvs
			arrays[Mesh.ARRAY_INDEX] = indices
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			leaf_mesh.mesh = mesh
			
		"jagged":
			# Create jagged zigzag leaf
			var mesh = ArrayMesh.new()
			var vertices = PackedVector3Array()
			
			# Left side zigzag
			vertices.push_back(Vector3(0, 0, 0))  # base
			vertices.push_back(Vector3(-0.06, 0.05, 0))
			vertices.push_back(Vector3(-0.03, 0.07, 0))
			vertices.push_back(Vector3(-0.07, 0.12, 0))
			vertices.push_back(Vector3(-0.04, 0.15, 0))
			vertices.push_back(Vector3(-0.05, 0.22, 0))
			vertices.push_back(Vector3(0, 0.25, 0))  # tip
			
			# Right side zigzag
			vertices.push_back(Vector3(0.06, 0.05, 0))
			vertices.push_back(Vector3(0.03, 0.07, 0))
			vertices.push_back(Vector3(0.07, 0.12, 0))
			vertices.push_back(Vector3(0.04, 0.15, 0))
			vertices.push_back(Vector3(0.05, 0.22, 0))
			
			# Create triangles
			var indices = PackedInt32Array()
			# Left side triangles
			for i in range(1, 6):
				indices.push_back(0)
				indices.push_back(i)
				indices.push_back(i+1)
			
			# Right side triangles  
			for i in range(7, 12):
				indices.push_back(0)
				indices.push_back(i)
				indices.push_back(i+1 if i < 11 else 6)
			
			# Add center triangles
			indices.push_back(0)
			indices.push_back(6)
			indices.push_back(7)
			
			# Generate normals an UVs
			var normals = PackedVector3Array()
			for i in range(vertices.size()):
				normals.push_back(Vector3(0, 0, 1))
				
			var uvs = PackedVector2Array()
			for v in vertices:
				uvs.push_back(Vector2((v.x + 0.07)/0.14, v.y/0.25))
				
			var arrays = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = vertices
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_TEX_UV] = uvs
			arrays[Mesh.ARRAY_INDEX] = indices
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			leaf_mesh.mesh = mesh
			
		_:
			# Default to simple quad
			var base = QuadMesh.new()
			base.size = Vector2(0.15, 0.2)
			leaf_mesh.mesh = base
	
	# Create the advanced cardboard material
	var cardboard_material = StandardMaterial3D.new()
	
	# Select a color variation that looks like construction paper
	var hue_shift = randf_range(-0.1, 0.1)
	var base_color = Color(0.8, 0.7, 0.5)
	var leaf_color = Color(
		clamp(base_color.r + hue_shift, 0, 1),
		clamp(base_color.g + hue_shift, 0, 1),
		clamp(base_color.b + randf_range(-0.1, 0.1), 0, 1)
	)
	
	cardboard_material.albedo_color = leaf_color
	cardboard_material.roughness = 1.0
	cardboard_material.metallic = 0.0
	
	# Create paper fiber texture
	var noise_texture = NoiseTexture2D.new()
	noise_texture.noise = FastNoiseLite.new()
	noise_texture.noise.frequency = 40.0
	noise_texture.noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise_texture.seamless = true
	noise_texture.width = 256
	noise_texture.height = 256
	
	cardboard_material.roughness_texture = noise_texture
	cardboard_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	leaf_mesh.material_override = cardboard_material
	leaf.add_child(leaf_mesh)
	
	# Add folded edge details
	var has_fold = randf() > 0.3
	if has_fold:
		var fold_line = MeshInstance3D.new()
		var line_mesh = QuadMesh.new()
		
		var fold_dir = "horizontal" if randf() > 0.5 else "vertical"
		if fold_dir == "horizontal":
			line_mesh.size = Vector2(0.14, 0.003) 
		else:
			line_mesh.size = Vector2(0.003, 0.18)
			
		fold_line.mesh = line_mesh
		
		# Position fold line
		if fold_dir == "horizontal":
			fold_line.position = Vector3(0, randf_range(0.05, 0.15), 0.001)
		else:
			fold_line.position = Vector3(randf_range(-0.05, 0.05), 0.08, 0.001)
			
		var fold_material = StandardMaterial3D.new()
		fold_material.albedo_color = cardboard_material.albedo_color.darkened(0.2)
		fold_line.material_override = fold_material
		
		leaf.add_child(fold_line)
	
	# Add slightly curved shape to avoid perfect flatness
	leaf.rotation_degrees.z = randf_range(-10, 10)
	leaf.rotation_degrees.x = randf_range(-5, 5)
	
	return leaf

func create_cardboard_fastener(type: String) -> Node3D:
	var fastener = Node3D.new()
	fastener.name = "Fastener_" + type
	
	match type:
		"thumbtack":
			var tack_head = MeshInstance3D.new()
			var head_mesh = CylinderMesh.new()
			head_mesh.top_radius = 0.01
			head_mesh.bottom_radius = 0.01
			head_mesh.height = 0.005
			tack_head.mesh = head_mesh
			tack_head.position.z = 0.0025
			
			var tack_pin = MeshInstance3D.new()
			var pin_mesh = CylinderMesh.new()
			pin_mesh.top_radius = 0.002
			pin_mesh.bottom_radius = 0.0005
			pin_mesh.height = 0.01
			tack_pin.mesh = pin_mesh
			tack_pin.rotation_degrees.x = 90
			tack_pin.position.z = 0.005
			
			var metal_material = StandardMaterial3D.new()
			metal_material.albedo_color = Color(0.8, 0.8, 0.85)
			metal_material.metallic = 0.9
			metal_material.roughness = 0.2
			
			tack_head.material_override = metal_material
			tack_pin.material_override = metal_material
			
			fastener.add_child(tack_head)
			fastener.add_child(tack_pin)
			
		"staple":
			var staple = MeshInstance3D.new()
			
			# Create staple with ArrayMesh for precise shape
			var vertices = PackedVector3Array()
			vertices.push_back(Vector3(-0.01, 0, 0.003))  # left top front
			vertices.push_back(Vector3(-0.01, 0, 0))      # left top back
			vertices.push_back(Vector3(-0.01, -0.005, 0)) # left bottom back
			vertices.push_back(Vector3(-0.01, -0.005, 0.003)) # left bottom front
			
			vertices.push_back(Vector3(0.01, 0, 0.003))   # right top front
			vertices.push_back(Vector3(0.01, 0, 0))       # right top back  
			vertices.push_back(Vector3(0.01, -0.005, 0))  # right bottom back
			vertices.push_back(Vector3(0.01, -0.005, 0.003))  # right bottom front
			
			vertices.push_back(Vector3(-0.01, 0, 0.003))  # middle top front left
			vertices.push_back(Vector3(0.01, 0, 0.003))   # middle top front right
			vertices.push_back(Vector3(0.01, 0, 0))       # middle top back right
			vertices.push_back(Vector3(-0.01, 0, 0))      # middle top back left
			
			var indices = PackedInt32Array([
				0, 1, 2, 0, 2, 3,  # left leg
				4, 5, 6, 4, 6, 7,  # right leg
				8, 9, 10, 8, 10, 11  # top bar
			])
			
			var normals = PackedVector3Array()
			for i in range(12):
				match i:
					0, 1, 2, 3: normals.push_back(Vector3(-1, 0, 0))  # left side
					4, 5, 6, 7: normals.push_back(Vector3(1, 0, 0))   # right side
					8, 9, 10, 11: normals.push_back(Vector3(0, 1, 0)) # top side
			
			var mesh = ArrayMesh.new()
			var arrays = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = vertices
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_INDEX] = indices
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			
			staple.mesh = mesh
			
			var metal_material = StandardMaterial3D.new()
			metal_material.albedo_color = Color(0.7, 0.7, 0.75)
			metal_material.metallic = 0.9
			metal_material.roughness = 0.2
			staple.material_override = metal_material
			
			fastener.add_child(staple)
	
	return fastener

func generate_vegetation_for_tile(forest: Node3D, tile_x: int, tile_z: int, biome: String) -> void:
	if is_building_tile(tile_x, tile_z):
		return
	var tile_world_pos = terrain_gen.get_tile_position(tile_x, tile_z)
	var tile_height = terrain_gen.get_tile_height(tile_x, tile_z)
	
	var vegetation_positions = []
	var attempts = 0
	var max_attempts = 20
	var max_vegetation = randi_range(1, 4)
	
	while len(vegetation_positions) < max_vegetation and attempts < max_attempts:
		var safe_area = tile_size * 0.8
		var half_safe = safe_area * 0.5
		
		var new_pos = Vector2(
			randf_range(-half_safe, half_safe),
			randf_range(-half_safe, half_safe)
		)
		
		var is_valid = true
		for existing_pos in vegetation_positions:
			if new_pos.distance_to(existing_pos) < 0.2:
				is_valid = false
				break
		
		if is_valid:
			vegetation_positions.append(new_pos)
		
		attempts += 1
	
	for pos in vegetation_positions:
		var vegetation = create_vegetation(biome)
		vegetation.position = Vector3(
			tile_world_pos.x + pos.x,
			tile_height + TERRAIN_HEIGHT_OFFSET, # Apply the offset here
			tile_world_pos.z + pos.y
		)
		forest.add_child(vegetation)

# Update fix_vegetation_height to use our constant by default
func fix_vegetation_height(offset: float = TERRAIN_HEIGHT_OFFSET) -> void:
	# Apply offset to all vegetation containers
	for child in get_children():
		if child is Node3D:
			child.position.y = offset

# Add a new helper function to get adjusted height (can be used in other places if needed)
func get_adjusted_tile_height(x: int, z: int) -> float:
	return terrain_gen.get_tile_height(x, z) + TERRAIN_HEIGHT_OFFSET

func create_vegetation(biome: String) -> Node3D:
	match biome:
		"grassland":
			tree_count += 1
			return create_grassland_tree(tree_count)
		"snow":
			snow_tree_count += 1
			return create_snow_tree(snow_tree_count)
		"desert":
			cactus_count += 1
			return create_cactus(cactus_count)
		"volcano":
			dead_tree_count += 1
			return create_dead_tree(dead_tree_count)
		"gothic":
			gothic_tree_count += 1
			return create_gothic_tree(gothic_tree_count)
		"sweets":
			candy_tree_count += 1
			return create_candy_tree(candy_tree_count)
		_:
			tree_count += 1
			return create_grassland_tree(tree_count)

func recursive_set_owner(node: Node, owner: Node) -> void:
	node.owner = owner
	for child in node.get_children():
		recursive_set_owner(child, owner)

func align_with_normal(normal: Vector3) -> Transform3D:
	var transform = Transform3D()
	
	# Calculate rotation to align with normal
	if normal != Vector3.UP:
		var axis = Vector3.UP.cross(normal).normalized()
		var angle = Vector3.UP.angle_to(normal)
		transform = transform.rotated(axis, angle)
	
	return transform
