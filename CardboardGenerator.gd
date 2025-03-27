@tool
extends BiomeVegetationGenerator
class_name CardboardGenerator

var cardboard_plant_count: int = 0
var boxes_only_mode: bool = true

func _init():
	super()

func CF_configure(veg_factory, grid, terrain, biome, tile_features_dict: Dictionary, buildings_dict = null):
	super.CF_configure(veg_factory, grid, terrain, biome, tile_features_dict, buildings_dict)
	set_density(1, 3)
	return self

func GEN_generate_vegetation(parent_node: Node3D = null) -> void:
	# Create parent node for all vegetation elements if not provided
	var vegetation_parent = parent_node
	if not vegetation_parent:
		vegetation_parent = Node3D.new()
		vegetation_parent.name = "CardboardVegetation"
		add_child(vegetation_parent)
	
	if boxes_only_mode:
		# In boxes-only mode, skip all vegetation and just place boxes
		GEN_generate_cardboard_boxes_only(vegetation_parent)
	else:
		# Normal mode with reduced density (one per tile)
		GEN_generate_full_vegetation(vegetation_parent)
	
	if Engine.is_editor_hint() and get_tree().edited_scene_root:
		UT_recursive_set_owner(vegetation_parent, get_tree().edited_scene_root)

# New method for boxes-only mode
func GEN_generate_cardboard_boxes_only(parent: Node3D) -> void:
	var cardboard_tiles = []
	
	# Collect all cardboard biome tiles
	for x in range(grid_size):
		for z in range(grid_size):
			if biome_gen.get_tile_biome(x, z) == "cardboard" and not is_building_tile(x, z):
				cardboard_tiles.append(Vector2i(x, z))
	
	# Skip if no cardboard tiles
	if cardboard_tiles.size() == 0:
		return
	
	# Create a container for the boxes
	var boxes_container = Node3D.new()
	boxes_container.name = "CardboardBoxes"
	parent.add_child(boxes_container)
	
	# Place ONE box per cardboard tile
	for tile_pos in cardboard_tiles:
		# Check if this tile already has a feature
		var tile_key = str(tile_pos.x) + "," + str(tile_pos.y)
		if tile_features.has(tile_key):
			continue
			
		# Random position within the tile
		var offset_x = randf_range(-0.4, 0.4) * tile_size
		var offset_z = randf_range(-0.4, 0.4) * tile_size
		var world_pos = terrain_gen.get_tile_position(tile_pos.x, tile_pos.y)
		world_pos += Vector3(offset_x, 0, offset_z)
		
		# Adjust height to terrain
		var grid_x = int(floor(world_pos.x / tile_size))
		var grid_z = int(floor(world_pos.z / tile_size))
		grid_x = clamp(grid_x, 0, grid_size - 1)
		grid_z = clamp(grid_z, 0, grid_size - 1)
		var key = "%d,%d" % [grid_x, grid_z]
		var height = terrain_gen.height_data.get(key, 0.0)
		world_pos.y = height
		
		# Create and place the box
		var box = BLD_create_cardboard_box()
		box.position = world_pos
		box.rotation_degrees.y = randf_range(0, 360)
		boxes_container.add_child(box)
	
	if get_tree().edited_scene_root:
		UT_recursive_set_owner(boxes_container, get_tree().edited_scene_root)

# Move existing vegetation generation code to this method
func GEN_generate_full_vegetation(parent: Node3D) -> void:
	cardboard_plant_count = 0
	
	# Collect positions first
	var plant_positions = []
	var plant_rotations = []
	var plant_scales = []
	var plant_normals = []
	
	for x in range(grid_size):
		for z in range(grid_size):
			if is_building_tile(x, z):
				continue
			
			if biome_gen.get_tile_biome(x, z) == "cardboard":
				# Place only ONE plant per tile instead of min_density to max_density
				var result = generate_positions_in_tile(x, z, 1, 0.3)
				var positions = result[0]
				var normals = result[1]
				
				for i in range(positions.size()):
					plant_positions.append(positions[i])
					plant_rotations.append(randf_range(0, PI * 2))
					plant_scales.append(Vector3(
						randf_range(0.8, 1.2),
						randf_range(0.9, 1.3),
						randf_range(0.8, 1.2)
					))
					plant_normals.append(normals[i])
					cardboard_plant_count += 1
	
	if plant_positions.size() == 0:
		return
		
	# Create individual plants
	for i in range(plant_positions.size()):
		var plant_type = randi() % 3  # Random plant type for variation
		var plant = null
		
		match plant_type:
			0:  # Standard cardboard plant
				plant = BLD_create_cardboard_plant(cardboard_plant_count - plant_positions.size() + i + 1)
			1:  # Origami-style plant
				plant = BLD_create_origami_plant(cardboard_plant_count - plant_positions.size() + i + 1)
			2:  # Craft paper plant
				plant = BLD_create_craft_plant(cardboard_plant_count - plant_positions.size() + i + 1)
				
		plant.position = plant_positions[i]
		
		# Apply normal alignment and rotation
		var normal_transform = align_with_normal(plant_normals[i])
		plant.transform = plant.transform * normal_transform
		plant.rotation.y = plant_rotations[i]
		
		plant.scale = plant_scales[i]
		
		# Add fasteners to some plants
		if randf() > 0.7:
			var fastener_type = "thumbtack" if randf() > 0.5 else "staple"
			var fastener = BLD_create_cardboard_fastener(fastener_type)
			
			# Position fastener on the plant
			var trunk = UT_find_node_by_name(plant, "Trunk")
			if trunk:
				var fastener_height = randf_range(0.1, trunk.position.y * 1.5)
				var fastener_angle = randf_range(0, PI * 2)
				fastener.position = Vector3(
					cos(fastener_angle) * 0.05,
					fastener_height,
					sin(fastener_angle) * 0.05
				)
				plant.add_child(fastener)
		
		# Add pencil marks or drawing details
		UT_add_pencil_details(plant)
		
		parent.add_child(plant)
	
	# Add ambient cardboard elements
	UT_add_cardboard_scraps(parent)
	
	# Add small dust particles
	UT_add_paper_dust(parent)
	
	# Add warm ambient light
	UT_add_ambient_lighting(parent)
	
	# Add decorative cardboard elements (one per tile)
	GEN_generate_cardboard_decorations(parent)

# Added from WorldMapGenerator.gd
func GEN_generate_cardboard_decorations(parent: Node3D) -> void:
	var cardboard_tiles = []
	
	# Collect all cardboard biome tiles
	for x in range(grid_size):
		for z in range(grid_size):
			if biome_gen.get_tile_biome(x, z) == "cardboard":
				cardboard_tiles.append(Vector2i(x, z))
	
	# Skip if no cardboard tiles
	if cardboard_tiles.size() == 0:
		return
		
	# Create a decoration container
	var cardboard_decor = Node3D.new()
	cardboard_decor.name = "CardboardDecorations"
	parent.add_child(cardboard_decor)
	
	if get_tree().edited_scene_root:
		UT_recursive_set_owner(cardboard_decor, get_tree().edited_scene_root)
	
	# Place ONE cardboard box decoration per tile
	for tile_pos in cardboard_tiles:
		# Check if this tile already has a feature
		var tile_key = str(tile_pos.x) + "," + str(tile_pos.y)
		if tile_features.has(tile_key):
			continue
			
		# Place ONLY ONE decoration per tile
		var offset_x = randf_range(-0.4, 0.4) * tile_size
		var offset_z = randf_range(-0.4, 0.4) * tile_size
		var world_pos = terrain_gen.get_tile_position(tile_pos.x, tile_pos.y)
		world_pos += Vector3(offset_x, 0, offset_z)
		
		# Adjust height to terrain
		var grid_x = int(floor(world_pos.x / tile_size))
		var grid_z = int(floor(world_pos.z / tile_size))
		grid_x = clamp(grid_x, 0, grid_size - 1)
		grid_z = clamp(grid_z, 0, grid_size - 1)
		var key = "%d,%d" % [grid_x, grid_z]
		var height = terrain_gen.height_data.get(key, 0.0)
		world_pos.y = height
		
		# Create cardboard structure
		var cardboard_box = BLD_create_cardboard_box()
		cardboard_box.position = world_pos
		cardboard_box.rotation_degrees.y = randf_range(0, 360)
		cardboard_decor.add_child(cardboard_box)
		
		if get_tree().edited_scene_root:
			UT_recursive_set_owner(cardboard_box, get_tree().edited_scene_root)

# Added from WorldMapGenerator.gd
func BLD_create_cardboard_box() -> Node3D:
	var box = CSGBox3D.new()
	
	# Random box size
	box.size = Vector3(
		randf_range(0.15, 0.3),
		randf_range(0.15, 0.3),
		randf_range(0.15, 0.3)
	)
	
	box.material = BLD_create_cardboard_material()
	
	return box

# Added from WorldMapGenerator.gd
func BLD_create_cardboard_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = UT_get_default_cardboard_color()
	
	# Add some variation
	if randf() > 0.5:
		material.albedo_color = UT_get_default_cardboard_color().darkened(randf_range(0.05, 0.15))
	
	material.roughness = randf_range(0.7, 0.9)
	return material

# Added helper function for cardboard color
func UT_get_default_cardboard_color() -> Color:
	return Color(0.76, 0.6, 0.42)

# Added from WorldMapGenerator.gd
func SF_generate_cardboard_fort(parent_node: Node3D, x: int, z: int) -> void:
	# Check if we have enough space for a 2x2 structure
	if x+1 >= grid_size or z+1 >= grid_size:
		return
	
	# Calculate heights and find the maximum height
	var heights = []
	var max_height = -INF
	var min_height = INF
	
	for dx in range(2):
		for dz in range(2):
			var key = "%d,%d" % [x+dx, z+dz]
			var height = terrain_gen.height_data.get(key, 0.0)
			heights.append(height)
			max_height = max(max_height, height)
			min_height = min(min_height, height)
	
	var height_difference = max_height - min_height
	
	var fort = Node3D.new()
	fort.name = "CardboardFort_" + str(x) + "_" + str(z)
	
	# Create fort base with extended height to reach the ground
	var base = CSGBox3D.new()
	base.name = "FortBase"
	# Make the base extend down to the lowest point
	base.size = Vector3(1.8, 0.1 + height_difference, 1.8)
	# Adjust position to account for the extended height
	base.position = Vector3(0, -height_difference/2, 0)
	base.material = BLD_create_cardboard_material()
	fort.add_child(base)
	
	# Create support stilts under the fort
	var stilt_radius = 0.08
	var num_stilts = 4
	var stilt_positions = [
		Vector3(-0.7, 0, -0.7),  # Northwest
		Vector3(0.7, 0, -0.7),   # Northeast
		Vector3(-0.7, 0, 0.7),   # Southwest
		Vector3(0.7, 0, 0.7)     # Southeast
	]
	
	for i in range(num_stilts):
		var stilt = CSGCylinder3D.new()
		stilt.name = "Stilt_" + str(i)
		stilt.radius = stilt_radius
		stilt.height = height_difference
		stilt.position = stilt_positions[i] - Vector3(0, height_difference/2, 0)
		stilt.material = BLD_create_material(Color(0.6, 0.4, 0.2))  # Brown stilts
		fort.add_child(stilt)
	
	# Create improved walls that connect at corners
	var wall_height = 0.5
	var wall_thickness = 0.08
	var fort_size = 1.6  # Size of the fort walls
	var half_size = fort_size / 2
	
	# Create 4 walls with proper sizing to avoid gaps at corners
	# North wall (back)
	var wall_north = CSGBox3D.new()
	wall_north.name = "WallNorth"
	wall_north.size = Vector3(fort_size + wall_thickness, wall_height, wall_thickness)
	wall_north.position = Vector3(0, wall_height/2, -half_size)
	wall_north.material = BLD_create_cardboard_material()
	fort.add_child(wall_north)
	
	# South wall (front)
	var wall_south = CSGBox3D.new()
	wall_south.name = "WallSouth"
	wall_south.size = Vector3(fort_size + wall_thickness, wall_height, wall_thickness)
	wall_south.position = Vector3(0, wall_height/2, half_size)
	wall_south.material = BLD_create_cardboard_material()
	fort.add_child(wall_south)
	
	# East wall (right)
	var wall_east = CSGBox3D.new()
	wall_east.name = "WallEast"
	wall_east.size = Vector3(wall_thickness, wall_height, fort_size - 0.08)
	wall_east.position = Vector3(half_size, wall_height/2, 0)
	wall_east.material = BLD_create_cardboard_material()
	fort.add_child(wall_east)
	
	# West wall (left)
	var wall_west = CSGBox3D.new()
	wall_west.name = "WallWest"
	wall_west.size = Vector3(wall_thickness, wall_height, fort_size - 0.08)
	wall_west.position = Vector3(-half_size, wall_height/2, 0)
	wall_west.material = BLD_create_cardboard_material()
	fort.add_child(wall_west)
	
	# Add entrance (door opening)
	var door_width = 0.4
	var door = CSGBox3D.new()
	door.name = "DoorOpening"
	door.size = Vector3(door_width, wall_height * 0.8, wall_thickness * 2)
	door.position = Vector3(0, -wall_height * 0.1, 0)  # Lowered position 
	door.operation = CSGShape3D.OPERATION_SUBTRACTION
	wall_south.add_child(door)
	
	# Add some cardboard boxes inside
	var num_boxes = randi() % 6 + 3  # Fewer boxes so it's not too crowded
	for i in range(num_boxes):
		var box = BLD_create_cardboard_box()
		box.name = "CardboardBox_" + str(i)
		box.position = Vector3(
			randf_range(-0.6, 0.6),
			0.1,
			randf_range(-0.6, 0.6)
		)
		box.rotation_degrees.y = randf() * 360
		fort.add_child(box)
	
	# Add a flag attached to the corner of the fort
	var flag_node = Node3D.new()
	flag_node.name = "FlagCorner"
	
	# Position at the northwest corner of the fort
	flag_node.position = Vector3(-half_size, wall_height, -half_size)
	fort.add_child(flag_node)
	
	# Create the flag pole
	var flag_pole = CSGCylinder3D.new()
	flag_pole.name = "FlagPole"
	flag_pole.radius = 0.02
	flag_pole.height = 0.4
	flag_pole.position = Vector3(0, 0.2, 0)  # Positioned up from the corner
	flag_pole.material = BLD_create_material(Color(0.6, 0.5, 0.4))  # Brown pole
	flag_node.add_child(flag_pole)
	
	# Create the flag
	var flag = CSGBox3D.new()
	flag.name = "Flag"
	flag.size = Vector3(0.3, 0.2, 0.01)
	flag.position = Vector3(0.15, 0.35, 0)  # Positioned on upper part of pole
	flag.material = BLD_create_material(Color(randf_range(0.7, 0.9), randf_range(0.2, 0.5), randf_range(0.1, 0.3)))
	flag_node.add_child(flag)
	
	# Position at center of 2x2 area at maximum height
	# This places the fort at the highest point with the base extending down
	var world_pos = terrain_gen.get_tile_position(x, z)
	world_pos += Vector3(tile_size * 0.5, 0, tile_size * 0.5)  # Center of 2x2
	fort.position = Vector3(world_pos.x, max_height + 0.02, world_pos.z)
	
	# Register this structure in all 4 tiles
	for dx in range(2):
		for dz in range(2):
			UT_register_tile_feature(x+dx, z+dz, "Cardboard Fort")
	
	parent_node.add_child(fort)
	UT_recursive_set_owner(fort, get_tree().edited_scene_root)

func BLD_create_cardboard_plant(index: int) -> Node3D:
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
			var leaf_basis = Basis()
			var z_axis = direction.normalized()
			var y_axis = Vector3.UP
			var x_axis = y_axis.cross(z_axis).normalized()
			y_axis = z_axis.cross(x_axis).normalized()
			leaf_basis.x = x_axis
			leaf_basis.y = y_axis
			leaf_basis.z = z_axis
			leaf.transform.basis = leaf_basis
		
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
	
## Creates a decorative plant made from craft materials like construction paper and pipe cleaners
## [param index]: Unique identifier for this plant instance
## Returns: A complete craft plant Node3D object
func BLD_create_craft_plant(index: int) -> Node3D:
	var plant = Node3D.new()
	plant.name = "CraftPlant_%d" % index
	
	# Create trunk from rolled construction paper
	var trunk = MeshInstance3D.new()
	trunk.name = "Trunk"
	var trunk_mesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.04
	trunk_mesh.bottom_radius = 0.05
	trunk_mesh.height = randf_range(0.4, 0.6)
	trunk.mesh = trunk_mesh
	trunk.position.y = trunk_mesh.height / 2
	
	# Basic craft paper material for trunk
	var trunk_material = StandardMaterial3D.new()
	trunk_material.albedo_color = Color(0.76, 0.6, 0.42) # Brown craft paper color
	trunk_material.roughness = 1.0
	trunk.material_override = trunk_material
	
	plant.add_child(trunk)
	
	# Available colors for craft elements
	var craft_colors = [
		Color(0.9, 0.3, 0.3),  # Red
		Color(0.3, 0.7, 0.4),  # Green
		Color(0.2, 0.5, 0.8),  # Blue
		Color(0.9, 0.8, 0.3),  # Yellow
		Color(0.8, 0.5, 0.9),  # Purple
		Color(0.9, 0.6, 0.3)   # Orange
	]
	
	# Basic geometric shapes for leaves
	var leaf_shapes = ["circle", "triangle", "square"]
	
	# Add 3-6 colorful paper leaves
	var leaf_count = randi() % 4 + 3
	
	for i in range(leaf_count):
		var leaf = MeshInstance3D.new()
		leaf.name = "Leaf_%d" % i
		
		# Pick random shape and color
		var shape = leaf_shapes[randi() % leaf_shapes.size()]
		var color = craft_colors[randi() % craft_colors.size()]
		
		# Create leaf geometry based on shape
		match shape:
			"circle":
				var circle_mesh = QuadMesh.new()
				circle_mesh.size = Vector2(0.15, 0.15)
				leaf.mesh = circle_mesh
			
			"triangle":
				var tri_mesh = ArrayMesh.new()
				var vertices = PackedVector3Array([
					Vector3(0, 0.075, 0),       # Top
					Vector3(-0.075, -0.075, 0), # Bottom left
					Vector3(0.075, -0.075, 0)   # Bottom right
				])
				
				var normals = PackedVector3Array([
					Vector3(0, 0, 1),
					Vector3(0, 0, 1),
					Vector3(0, 0, 1)
				])
				
				var arrays = []
				arrays.resize(Mesh.ARRAY_MAX)
				arrays[Mesh.ARRAY_VERTEX] = vertices
				arrays[Mesh.ARRAY_NORMAL] = normals
				arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
				tri_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				leaf.mesh = tri_mesh
			
			"square":
				var square_mesh = QuadMesh.new()
				square_mesh.size = Vector2(0.12, 0.12)
				leaf.mesh = square_mesh
		
		# Apply material to leaf
		var leaf_material = StandardMaterial3D.new()
		leaf_material.albedo_color = color
		leaf_material.roughness = 1.0
		leaf_material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Visible from both sides
		leaf.material_override = leaf_material
		
		# Position leaf around trunk
		var angle = randf_range(0, PI * 2)
		var height = randf_range(0.2, trunk_mesh.height * 0.9)
		var distance = randf_range(0.1, 0.15)
		
		leaf.position = Vector3(
			cos(angle) * distance,
			height,
			sin(angle) * distance
		)
		
		# Random leaf orientation
		leaf.rotation_degrees = Vector3(
			randf_range(-20, 20),
			randf_range(0, 360),
			randf_range(-20, 20)
		)
		
		# 50% chance to add a pipe cleaner stem
		if randf() > 0.5:
			var wire = MeshInstance3D.new()
			wire.name = "PipeCleaner"
			
			var wire_mesh = CylinderMesh.new()
			wire_mesh.top_radius = 0.005
			wire_mesh.bottom_radius = 0.005
			wire_mesh.height = 0.1
			wire.mesh = wire_mesh
			wire.position = Vector3(0, -0.05, 0)
			
			var wire_material = StandardMaterial3D.new()
			# Either green or red pipe cleaner
			wire_material.albedo_color = Color(0.1, 0.8, 0.1) if randf() > 0.5 else Color(0.8, 0.1, 0.1)
			wire.material_override = wire_material
			
			leaf.add_child(wire)
		
		plant.add_child(leaf)
	
	# Add a few craft decorations
	var decoration_count = randi() % 3
	for i in range(decoration_count):
		var decoration = MeshInstance3D.new()
		decoration.name = "Decoration_%d" % i
		
		# Create either a pom-pom or bead
		if randf() > 0.5:
			# Pom-pom
			var pom_mesh = SphereMesh.new()
			pom_mesh.radius = randf_range(0.02, 0.04)
			decoration.mesh = pom_mesh
			
			var pom_material = StandardMaterial3D.new()
			pom_material.albedo_color = craft_colors[randi() % craft_colors.size()]
			pom_material.roughness = 1.0
			decoration.material_override = pom_material
		else:
			# Bead
			var bead_mesh = SphereMesh.new()
			bead_mesh.radius = randf_range(0.015, 0.025)
			decoration.mesh = bead_mesh
			
			var bead_material = StandardMaterial3D.new()
			bead_material.albedo_color = craft_colors[randi() % craft_colors.size()]
			bead_material.metallic = 0.8
			bead_material.roughness = 0.2
			decoration.material_override = bead_material
		
		# Position decoration on plant
		var height = randf_range(0.1, trunk_mesh.height)
		var angle = randf_range(0, PI * 2)
		var distance = randf_range(0.04, 0.07)
		
		decoration.position = Vector3(
			cos(angle) * distance,
			height,
			sin(angle) * distance
		)
		
		decoration.rotation_degrees.y = randf_range(0, 360)
		plant.add_child(decoration)
	
	# Add paper base
	var base = MeshInstance3D.new()
	base.name = "Base"
	
	var base_mesh = CylinderMesh.new()
	base_mesh.top_radius = 0.08
	base_mesh.bottom_radius = 0.1
	base_mesh.height = 0.03
	base.mesh = base_mesh
	base.position.y = 0.015
	
	var base_material = trunk_material.duplicate()
	base_material.albedo_color = base_material.albedo_color.darkened(0.2)
	base.material_override = base_material
	
	plant.add_child(base)
	
	# 70% chance to add decorative ribbon
	if randf() > 0.3:
		var ribbon = MeshInstance3D.new()
		ribbon.name = "Ribbon"
		
		# Use a cylinder mesh instead of a torus
		var ribbon_mesh = CylinderMesh.new()
		ribbon_mesh.top_radius = trunk_mesh.top_radius * 1.2
		ribbon_mesh.bottom_radius = trunk_mesh.top_radius * 1.2
		ribbon_mesh.height = 0.02
		ribbon.mesh = ribbon_mesh
		
		ribbon.position.y = trunk_mesh.height * randf_range(0.3, 0.7)
		
		var ribbon_material = StandardMaterial3D.new()
		ribbon_material.albedo_color = craft_colors[randi() % craft_colors.size()]
		ribbon_material.metallic = 0.3
		ribbon_material.roughness = 0.7
		ribbon.material_override = ribbon_material
		
		plant.add_child(ribbon)
	
	return plant
	
func BLD_create_origami_plant(index: int) -> Node3D:
	var plant = Node3D.new()
	plant.name = "OrigamiPlant_%d" % index
	
	# Available origami paper colors
	var origami_colors = [
		Color(0.9, 0.3, 0.3),  # Red
		Color(0.3, 0.8, 0.4),  # Green
		Color(0.3, 0.6, 0.9),  # Blue
		Color(0.9, 0.9, 0.3),  # Yellow
		Color(0.9, 0.6, 0.9),  # Pink
		Color(1.0, 0.6, 0.3)   # Orange
	]
	
	# Create stem from folded paper
	var stem = MeshInstance3D.new()
	stem.name = "Stem"
	var stem_mesh = PrismMesh.new()  # Using prism for folded paper look
	stem_mesh.size = Vector3(0.06, 0.4, 0.06)
	stem.mesh = stem_mesh
	stem.position.y = stem_mesh.size.y / 2
	
	var stem_material = StandardMaterial3D.new()
	stem_material.albedo_color = Color(0.2, 0.6, 0.3)  # Green stem
	stem_material.roughness = 1.0
	stem.material_override = stem_material
	
	plant.add_child(stem)
	
	# Add origami flowers/leaves
	var flower_count = randi() % 3 + 2  # 2-4 flowers
	
	for i in range(flower_count):
		var flower = Node3D.new()
		flower.name = "OrigamiFlower_%d" % i
		
		# Create flower center
		var center = MeshInstance3D.new()
		center.name = "Center"
		var center_mesh = PrismMesh.new()
		center_mesh.size = Vector3(0.08, 0.02, 0.08)
		center.mesh = center_mesh
		
		var color = origami_colors[randi() % origami_colors.size()]
		var center_material = StandardMaterial3D.new()
		center_material.albedo_color = color
		center_material.roughness = 1.0
		center.material_override = center_material
		
		flower.add_child(center)
		
		# Add petals
		var petal_count = randi() % 2 + 5  # 5-6 petals
		for j in range(petal_count):
			var petal = MeshInstance3D.new()
			petal.name = "Petal_%d" % j
			
			# Create triangular petal shape
			var petal_mesh = ArrayMesh.new()
			var vertices = PackedVector3Array([
				Vector3(0, 0, 0),           # Center
				Vector3(-0.04, 0, 0.08),    # Left
				Vector3(0.04, 0, 0.08)      # Right
			])
			
			var normals = PackedVector3Array([
				Vector3(0, 1, 0),
				Vector3(0, 1, 0),
				Vector3(0, 1, 0)
			])
			
			var arrays = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = vertices
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
			petal_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			
			petal.mesh = petal_mesh
			
			# Position and rotate petal
			var petal_angle = (2 * PI * j) / petal_count
			petal.rotation_degrees.y = rad_to_deg(petal_angle)
			petal.rotation_degrees.x = -30  # Angle upward
			
			var petal_material = StandardMaterial3D.new()
			petal_material.albedo_color = color.lightened(0.2)
			petal_material.roughness = 1.0
			petal_material.cull_mode = BaseMaterial3D.CULL_DISABLED
			petal.material_override = petal_material
			
			flower.add_child(petal)
		
		# Position flower on stem
		var height = randf_range(0.2, stem_mesh.size.y * 0.9)
		var angle = randf_range(0, PI * 2)
		var distance = randf_range(0.05, 0.1)
		
		flower.position = Vector3(
			cos(angle) * distance,
			height,
			sin(angle) * distance
		)
		
		flower.rotation_degrees = Vector3(
			randf_range(-20, 20),
			randf_range(0, 360),
			randf_range(-20, 20)
		)
		
		plant.add_child(flower)
	
	# Add origami base
	var base = MeshInstance3D.new()
	base.name = "Base"
	var base_mesh = PrismMesh.new()
	base_mesh.size = Vector3(0.15, 0.02, 0.15)
	base.mesh = base_mesh
	base.position.y = 0.01
	
	var base_material = StandardMaterial3D.new()
	base_material.albedo_color = Color(0.8, 0.8, 0.8)  # Light gray
	base_material.roughness = 1.0
	base.material_override = base_material
	
	plant.add_child(base)
	
	# Add folded paper creases
	var creases = MeshInstance3D.new()
	creases.name = "Creases"
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	
	# Add random crease lines
	for _i in range(6):
		var start_height = randf_range(0.05, stem_mesh.size.y)
		var end_height = start_height + randf_range(-0.1, 0.1)
		var angle = randf_range(0, PI * 2)
		
		st.add_vertex(Vector3(
			cos(angle) * 0.03,
			start_height,
			sin(angle) * 0.03
		))
		st.add_vertex(Vector3(
			cos(angle + PI) * 0.03,
			end_height,
			sin(angle + PI) * 0.03
		))
	
	creases.mesh = st.commit()
	
	var crease_material = StandardMaterial3D.new()
	crease_material.albedo_color = Color(0.3, 0.3, 0.3, 0.5)
	crease_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	creases.material_override = crease_material
	
	plant.add_child(creases)
	
	return plant
	
func BLD_create_cardboard_fastener(fastener_type: String) -> Node3D:
	var fastener = Node3D.new()
	fastener.name = "Fastener_" + fastener_type
	
	match fastener_type:
		"thumbtack":
			# Create thumbtack head
			var head = MeshInstance3D.new()
			head.name = "TackHead"
			var head_mesh = CylinderMesh.new()
			head_mesh.top_radius = 0.02
			head_mesh.bottom_radius = 0.02
			head_mesh.height = 0.005
			head.mesh = head_mesh
			
			# Create pin
			var pin = MeshInstance3D.new()
			pin.name = "TackPin"
			var pin_mesh = CylinderMesh.new()
			pin_mesh.top_radius = 0.002
			pin_mesh.bottom_radius = 0.004
			pin_mesh.height = 0.015
			pin.mesh = pin_mesh
			pin.position.y = -pin_mesh.height/2
			
			# Materials
			var metal_material = StandardMaterial3D.new()
			metal_material.albedo_color = Color(0.8, 0.8, 0.8)
			metal_material.metallic = 0.8
			metal_material.roughness = 0.2
			
			head.material_override = metal_material
			pin.material_override = metal_material
			
			fastener.add_child(head)
			fastener.add_child(pin)
			
		"staple":
			# Create staple from thin cylinders
			var staple = MeshInstance3D.new()
			staple.name = "Staple"
			
			# Create staple using ArrayMesh for better control
			var mesh = ArrayMesh.new()
			var vertices = PackedVector3Array()
			var normals = PackedVector3Array()
			
			# Staple dimensions
			var width = 0.02
			var height = 0.01
			var thickness = 0.001
			
			# Add vertices for the three parts of the staple
			# Top bar
			vertices.append(Vector3(-width/2, 0, -thickness/2))
			vertices.append(Vector3(width/2, 0, -thickness/2))
			vertices.append(Vector3(width/2, 0, thickness/2))
			vertices.append(Vector3(-width/2, 0, thickness/2))
			
			# Left leg
			vertices.append(Vector3(-width/2, 0, -thickness/2))
			vertices.append(Vector3(-width/2, -height, -thickness/2))
			vertices.append(Vector3(-width/2, -height, thickness/2))
			vertices.append(Vector3(-width/2, 0, thickness/2))
			
			# Right leg
			vertices.append(Vector3(width/2, 0, -thickness/2))
			vertices.append(Vector3(width/2, -height, -thickness/2))
			vertices.append(Vector3(width/2, -height, thickness/2))
			vertices.append(Vector3(width/2, 0, thickness/2))
			
			# Add simple normals
			for i in range(12):
				normals.append(Vector3(0, 1, 0))
			
			# Create indices for triangles
			var indices = PackedInt32Array([
				# Top bar
				0, 1, 2, 0, 2, 3,
				# Left leg
				4, 5, 6, 4, 6, 7,
				# Right leg
				8, 9, 10, 8, 10, 11
			])
			
			var arrays = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = vertices
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_INDEX] = indices
			
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			staple.mesh = mesh
			
			# Material
			var staple_material = StandardMaterial3D.new()
			staple_material.albedo_color = Color(0.7, 0.7, 0.7)
			staple_material.metallic = 0.9
			staple_material.roughness = 0.1
			staple.material_override = staple_material
			
			fastener.add_child(staple)
	
	return fastener

# Utility function needed for the create_cardboard_fort function
func BLD_create_material(color: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = randf_range(0.2, 0.8)
	return material

# Utility function for tile feature registration
func UT_register_tile_feature(x: int, z: int, feature: String) -> void:
	if tile_features == null:  # Safety check
		return
		
	var key = str(x) + "," + str(z)
	tile_features[key] = feature

# Added these existing functions from the CardboardGenerator
func UT_add_pencil_details(plant: Node3D) -> void:
	# Find leaves to add pencil marks to
	var leaves = []
	for child in plant.get_children():
		if child.name.begins_with("Leaf_"):
			leaves.append(child)
	
	if leaves.size() == 0:
		return
	
	# Add pencil details to some leaves
	for leaf in leaves:
		if randf() > 0.4:  # 60% chance to add details
			var detail_type = randi() % 3
			
			var mark = MeshInstance3D.new()
			mark.name = "PencilDetail"
			
			var mark_mesh = QuadMesh.new()
			mark_mesh.size = Vector2(0.05, 0.05)
			mark.mesh = mark_mesh
			
			# Position slightly in front of leaf
			mark.position = Vector3(0, 0, -0.001)
			
			var mark_material = StandardMaterial3D.new()
			mark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mark_material.cull_mode = BaseMaterial3D.CULL_DISABLED
			
			match detail_type:
				0:  # Simple line
					mark_mesh.size = Vector2(0.05, 0.01)
					mark.rotation_degrees = Vector3(0, 0, randf_range(0, 180))
					mark_material.albedo_color = Color(0.2, 0.2, 0.2, 0.8)
				
				1:  # Curved line or smile
					# Using small box meshes to create a curved line
					mark_mesh.size = Vector2(0.01, 0.01)
					var curve = Node3D.new()
					curve.name = "CurvedLine"
					
					var curve_segments = 5
					for j in range(curve_segments):
						var segment = MeshInstance3D.new()
						segment.mesh = mark_mesh
						var t = float(j) / (curve_segments - 1)
						var angle = lerp(-PI/4, PI/4, t)
						var radius = 0.02
						segment.position = Vector3(cos(angle) * radius, sin(angle) * radius, 0)
						segment.material_override = mark_material
						curve.add_child(segment)
					
					leaf.add_child(curve)
					continue
				
				2:  # Simple drawing (dot or asterisk)
					if randf() > 0.5:
						# Dot pattern
						mark_mesh.size = Vector2(0.01, 0.01)
						mark_material.albedo_color = Color(0.2, 0.2, 0.2, 0.9)
					else:
						# Asterisk
						var asterisk = Node3D.new()
						asterisk.name = "Asterisk"
						
						for j in range(3):
							var line = MeshInstance3D.new()
							var line_mesh = QuadMesh.new()
							line_mesh.size = Vector2(0.03, 0.005)
							line.mesh = line_mesh
							line.rotation_degrees = Vector3(0, 0, j * 60)
							line.material_override = mark_material
							asterisk.add_child(line)
						
						leaf.add_child(asterisk)
						continue
			
			mark.material_override = mark_material
			leaf.add_child(mark)

func UT_add_cardboard_scraps(parent: Node3D) -> void:
	# Add cardboard scraps on the ground for atmosphere
	var scraps_count = int(min(20, grid_size * 0.5))
	
	for i in range(scraps_count):
		var scrap = MeshInstance3D.new()
		scrap.name = "CardboardScrap_" + str(i)
		
		# Random scrap type
		var scrap_type = randi() % 3
		
		match scrap_type:
			0:  # Flat piece
				var mesh = QuadMesh.new()
				mesh.size = Vector2(randf_range(0.1, 0.3), randf_range(0.1, 0.2))
				scrap.mesh = mesh
				scrap.rotation_degrees.x = 90  # Lay flat
				
			1:  # Folded piece
				var mesh = ArrayMesh.new()
				var vertices = PackedVector3Array()
				var normals = PackedVector3Array()
				var uvs = PackedVector2Array()
				var indices = PackedInt32Array()
				
				var width = randf_range(0.1, 0.25)
				var length = randf_range(0.15, 0.3)
				var fold_angle = deg_to_rad(randf_range(100, 170))
				
				# First half
				vertices.append(Vector3(-width/2, 0, 0))
				vertices.append(Vector3(width/2, 0, 0))
				vertices.append(Vector3(width/2, 0, length/2))
				vertices.append(Vector3(-width/2, 0, length/2))
				
				# Second half (folded)
				var fold_dir = Vector3(0, sin(fold_angle), cos(fold_angle)).normalized()
				vertices.append(Vector3(-width/2, fold_dir.y * length/2, fold_dir.z * length/2 + length/2))
				vertices.append(Vector3(width/2, fold_dir.y * length/2, fold_dir.z * length/2 + length/2))
				vertices.append(Vector3(width/2, fold_dir.y * length, fold_dir.z * length + length/2))
				vertices.append(Vector3(-width/2, fold_dir.y * length, fold_dir.z * length + length/2))
				
				# Create triangles
				# First face
				indices.append(0); indices.append(1); indices.append(2)
				indices.append(0); indices.append(2); indices.append(3)
				# Second face
				indices.append(4); indices.append(6); indices.append(5)
				indices.append(4); indices.append(7); indices.append(6)
				# Connect the faces
				indices.append(3); indices.append(2); indices.append(5)
				indices.append(3); indices.append(5); indices.append(4)
				
				# Create simple normals
				for j in range(8):
					normals.append(Vector3(0, 1, 0))
				
				# Simple UVs
				for j in range(8):
					uvs.append(Vector2(0, 0))
				
				var arrays = []
				arrays.resize(Mesh.ARRAY_MAX)
				arrays[Mesh.ARRAY_VERTEX] = vertices
				arrays[Mesh.ARRAY_NORMAL] = normals
				arrays[Mesh.ARRAY_TEX_UV] = uvs
				arrays[Mesh.ARRAY_INDEX] = indices
				
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				scrap.mesh = mesh
				scrap.rotation_degrees.y = randf_range(0, 360)
				
			2:  # Crumpled piece
				var mesh = SphereMesh.new()
				mesh.radius = randf_range(0.05, 0.1)
				mesh.height = mesh.radius * 2
				scrap.mesh = mesh
				scrap.scale = Vector3(randf_range(0.8, 1.2), randf_range(0.6, 0.9), randf_range(0.8, 1.2))
				
		# Position scrap throughout the biome
		var x_pos = randf_range(0, grid_size * tile_size * 0.8) - grid_size * tile_size * 0.4
		var z_pos = randf_range(0, grid_size * tile_size * 0.8) - grid_size * tile_size * 0.4
		
		# Get height at position and add slight offset
		var height
		if terrain_gen.has_method("get_height_at_position"):
			height = terrain_gen.get_height_at_position(x_pos, z_pos) + 0.01
		else:
			# Fallback to another method if needed
			height = 0.01
		
		scrap.position = Vector3(x_pos, height, z_pos)
		
		# Create material with cardboard texture
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(
			randf_range(0.7, 0.9),  # R
			randf_range(0.6, 0.75),  # G
			randf_range(0.4, 0.6)    # B
		)
		material.roughness = randf_range(0.8, 1.0)
		material.metallic = 0.0
		
		# Add minimal torn edge effect
		if scrap_type < 2 and randf() > 0.6:
			material.normal_enabled = true
			var noise_texture = NoiseTexture2D.new()
			noise_texture.noise = FastNoiseLite.new()
			noise_texture.noise.frequency = 35.0
			noise_texture.noise.fractal_gain = 0.5
			noise_texture.width = 128
			noise_texture.height = 128
			material.normal_texture = noise_texture
			material.normal_scale = 0.2
		
		scrap.material_override = material
		
		parent.add_child(scrap)

func UT_add_paper_dust(parent: Node3D) -> void:
	var particles = GPUParticles3D.new()
	particles.name = "PaperDust"
	
	var particle_material = ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	particle_material.emission_box_extents = Vector3(grid_size * tile_size / 3, 0.5, grid_size * tile_size / 3)
	particle_material.gravity = Vector3(0, -0.03, 0)
	particle_material.initial_velocity_min = 0.02
	particle_material.initial_velocity_max = 0.1
	particle_material.scale_min = 0.01
	particle_material.scale_max = 0.03
	particle_material.damping_min = 0.1
	particle_material.damping_max = 0.3
	particle_material.angular_velocity_min = deg_to_rad(10)
	particle_material.angular_velocity_max = deg_to_rad(40)
	
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(0.01, 0.01)
	particles.draw_pass_1 = quad_mesh
	
	var dust_material = StandardMaterial3D.new()
	dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_material.albedo_color = Color(0.9, 0.85, 0.8, 0.2)
	dust_material.billboard_mode = StandardMaterial3D.BILLBOARD_ENABLED
	
	# Add a subtle glow for better visibility
	dust_material.emission_enabled = true
	dust_material.emission = Color(0.8, 0.75, 0.7, 0.1)
	dust_material.emission_energy = 0.1
	
	particles.material_override = dust_material
	particles.process_material = particle_material
	particles.amount = 100
	particles.lifetime = 4.0
	particles.randomness = 1.0
	particles.position.y = 1.0
	
	# Add a subtle air current effect to the dust
	var air_current = Node3D.new()
	air_current.name = "AirCurrent"
	
	var animation_script = GDScript.new()
	animation_script.source_code = """
	extends Node3D
	
	var time = 0
	var dust_parent: GPUParticles3D
	
	func _ready():
		dust_parent = get_parent() as GPUParticles3D
		if dust_parent and dust_parent.process_material:
			dust_parent.process_material = dust_parent.process_material.duplicate()
	
	func _process(delta):
		time += delta
		if dust_parent and dust_parent.process_material:
			var direction = Vector3(sin(time * 0.3), 0, cos(time * 0.5))
			dust_parent.process_material.direction = direction.normalized()
			dust_parent.process_material.initial_velocity_min = 0.02 + sin(time) * 0.01
			dust_parent.process_material.initial_velocity_max = 0.1 + sin(time) * 0.02
	"""
	
	air_current.set_script(animation_script)
	particles.add_child(air_current)
	
	parent.add_child(particles)

func UT_add_ambient_lighting(parent: Node3D) -> void:
	var warm_light = OmniLight3D.new()
	warm_light.name = "CardboardBiomeLight"
	warm_light.light_color = Color(1.0, 0.9, 0.8)  # Warm yellowish tint
	warm_light.light_energy = 0.6
	warm_light.omni_range = grid_size * tile_size * 0.6
	warm_light.position.y = 2.0
	
	# Add subtle animation to the light
	var animation_script = GDScript.new()
	animation_script.source_code = """
	extends OmniLight3D

	var time = 0
	var original_energy = 0.6

	func _ready():
		original_energy = light_energy

	func _process(delta):
		time += delta
		light_energy = original_energy + sin(time * 0.3) * 0.1
	"""
	warm_light.set_script(animation_script)
	
	parent.add_child(warm_light)

func UT_find_node_by_name(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	
	for child in node.get_children():
		var found = UT_find_node_by_name(child, node_name)
		if found:
			return found
	
	return null

# Helper function for recursive ownership setup (if needed)
func UT_recursive_set_owner(node: Node, new_owner: Node) -> void:
	if is_instance_valid(new_owner) and node.is_inside_tree():
		node.owner = new_owner
		for child in node.get_children():
			UT_recursive_set_owner(child, new_owner)
