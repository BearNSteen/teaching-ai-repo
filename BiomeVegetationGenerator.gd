@tool
extends Node3D
class_name BiomeVegetationGenerator



const TERRAIN_HEIGHT_OFFSET = 0

var vegetation_factory
var grid_manager
var terrain_gen
var biome_gen
var tile_features: Dictionary
var tile_size: float
var grid_size: int
var building_positions = {}

# Grid settings
var use_grid_placement: bool = false
var grid_cells_per_tile: int = 2  
var grid_jitter: float = 0.2  

# Configuration for vegetation density
var min_density: int = 0
var max_density: int = 2
var density_multiplier: float = 1.0

func _init():
	# Empty constructor
	pass

func CF_configure(veg_factory, grid, terrain, biome, tile_features_dict: Dictionary, buildings_dict = null):
	# Initialize essential dependencies
	vegetation_factory = veg_factory
	grid_manager = grid
	terrain_gen = terrain
	biome_gen = biome
	tile_features = tile_features_dict
	
	# Add validation for biome_gen
	if biome_gen == null:
		push_error("BiomeVegetationGenerator: biome_gen is null during initialization!")
		print_stack()
	
	if buildings_dict:
		building_positions = buildings_dict
	
	return self

func setup(grid_size_value: int, tile_size_value: float) -> void:
	# Configure the grid settings
	grid_size = grid_size_value
	tile_size = tile_size_value

func set_density(min_value: int, max_value: int, multiplier: float = 1.0) -> void:
	# Apply density settings
	self.min_density = max(0, int(min_value * multiplier))
	self.max_density = max(1, int(max_value * multiplier))
	self.density_multiplier = multiplier

func set_grid_placement(enabled: bool, jitter: float) -> void:
	# Configure grid placement settings
	self.use_grid_placement = enabled
	self.grid_jitter = jitter

func generate_vegetation(_parent_node: Node3D) -> void:
	# Base implementation to be overridden by children
	push_error("Called abstract method! Should be implemented by child classes")
	pass

func is_building_tile(x: int, z: int) -> bool:
	# Check if there's a building at this position
	return building_positions.has(str(x) + "," + str(z))

func is_special_tile(x: int, z: int) -> bool:
	# Check for special tiles like town center, lakes, etc.
	var special_tiles = [
		Vector2(grid_size/2.0, grid_size/2.0),  # Town center
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
		var items_per_quadrant = int(count / 4.0)
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
				var row = i / float(mini_grid_size)
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
					tile_height + TERRAIN_HEIGHT_OFFSET,
					base_z + grid_offset_z
				))
				
				# Get normal from terrain or use UP vector if not available
				var normal = Vector3.UP
				if terrain_gen.has_method("get_normal_at_position"):
					normal = terrain_gen.get_normal_at_position(
						base_x + grid_offset_x, 
						base_z + grid_offset_z
					)
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
				var pos_vector = Vector3(
					tile_pos.x + offset.x,
					tile_height + TERRAIN_HEIGHT_OFFSET,
					tile_pos.z + offset.y
				)
				positions.append(pos_vector)
				
				var normal = Vector3.UP
				if terrain_gen.has_method("get_normal_at_position"):
					normal = terrain_gen.get_normal_at_position(
						tile_pos.x + offset.x, 
						tile_pos.z + offset.y
					)
				normals.append(normal)
			
			attempts += 1
	
	# Return both positions and normals
	return [positions, normals]

func get_adjusted_tile_height(x: int, z: int) -> float:
	# Helper to get tile height with adjustment
	return terrain_gen.get_tile_height(x, z) + TERRAIN_HEIGHT_OFFSET

func align_with_normal(normal: Vector3) -> Transform3D:
	# Create a transform that aligns with a surface normal
	var normal_transform = Transform3D()
	
	# Calculate rotation to align with normal
	if normal != Vector3.UP:
		var axis = Vector3.UP.cross(normal).normalized()
		var angle = Vector3.UP.angle_to(normal)
		normal_transform = normal_transform.rotated(axis, angle)
	
	return normal_transform

func recursive_set_owner(node: Node, new_owner: Node) -> void:
	# Set owner for all nodes in a hierarchy
	node.owner = new_owner
	for child in node.get_children():
		recursive_set_owner(child, new_owner)
