@tool
extends BiomeVegetationGenerator
class_name GrasslandGenerator

var tree_count: int = 0
var grass_color: Color = Color(0.3, 0.6, 0.3)

func _init():
	super()

func CF_configure(veg_factory, grid, terrain, biome, tile_features_dict: Dictionary, buildings_dict = null, grass_color_value = Color(0.3, 0.6, 0.3)):
	super.CF_configure(veg_factory, grid, terrain, biome, tile_features_dict, buildings_dict)
	grass_color = grass_color_value
	set_density(0, 2)
	return self

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

func VG_collect_vegetation_positions() -> Dictionary:
	var data = {
		"positions": [],
		"rotations": [],
		"normals": []
	}
	
	# Iterate through grid to find suitable positions for vegetation
	for x in range(grid_size):
		for z in range(grid_size):
			# Skip special tiles and building locations
			if is_special_tile(x, z) or is_building_tile(x, z):
				continue
			
			# Check if current tile is in grassland biome
			if biome_gen.get_tile_biome(x, z) == "grassland":
				VG_populate_tile_vegetation(x, z, data)
	
	return data

func VG_populate_tile_vegetation(x: int, z: int, data: Dictionary) -> void:
	# Generate random number of vegetation items based on density settings
	var count = randi_range(min_density, max_density)
	var result = generate_positions_in_tile(x, z, count, 0.2)
	var positions = result[0]
	var normals = result[1]
	
	# Add generated positions, normals and random rotations to arrays
	for i in range(positions.size()):
		data.positions.append(positions[i])
		data.normals.append(normals[i])
		data.rotations.append(randf_range(0, PI * 2))
		tree_count += 1

func VG_create_tree_multimeshes(data: Dictionary) -> Dictionary:
	var result = {}
	
	# Early return if no valid positions were found
	if data.positions.size() == 0:
		return result
	
	# Create MultiMesh instances for each component
	var trunk_multimesh = MultiMesh.new()
	var canopy_multimesh = MultiMesh.new()
	
	# Setup mesh data from vegetation factory
	var tree_data = vegetation_factory.get_grassland_tree_meshes()
	trunk_multimesh.mesh = tree_data.trunk_mesh
	canopy_multimesh.mesh = tree_data.canopy_mesh
	
	# Configure multimesh settings
	trunk_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	canopy_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	
	trunk_multimesh.instance_count = data.positions.size()
	canopy_multimesh.instance_count = data.positions.size()
	
	# Apply transforms with normal alignment
	for i in range(data.positions.size()):
		var pos = data.positions[i]
		var rot = data.rotations[i]
		var normal = data.normals[i]
		
		# Apply normal-aligned transform with rotation
		var normal_transform = UT_align_with_normal(normal)
		normal_transform = normal_transform.rotated(Vector3.UP, rot)
		
		# Trunk transform
		var trunk_transform = normal_transform
		trunk_transform.origin = pos
		trunk_transform.origin.y += 0.2  # Trunk height offset
		trunk_multimesh.set_instance_transform(i, trunk_transform)
		
		# Canopy transform
		var canopy_transform = normal_transform
		canopy_transform.origin = pos
		canopy_transform.origin.y += 0.6  # Canopy height offset
		canopy_multimesh.set_instance_transform(i, canopy_transform)
	
	result["trunk_multimesh"] = trunk_multimesh
	result["canopy_multimesh"] = canopy_multimesh
	
	return result

func VG_setup_vegetation_parent(parent_node: Node3D = null) -> Node3D:
	if parent_node:
		return parent_node
	
	var vegetation_parent = Node3D.new()
	vegetation_parent.name = "GrasslandVegetation"
	add_child(vegetation_parent)
	return vegetation_parent

func VG_generate_vegetation(parent_node: Node3D = null) -> void:
	# Validate dependencies before proceeding
	if biome_gen == null:
		push_error("GrasslandGenerator: biome_gen is null during generate_vegetation!")
		return
		
	if terrain_gen == null:
		push_error("GrasslandGenerator: terrain_gen is null during generate_vegetation!")
		return
	
	# Reset the tree counter for this generation pass
	tree_count = 0
	
	# Create parent node for all vegetation elements if not provided
	var vegetation_parent = VG_setup_vegetation_parent(parent_node)
	
	# Collect positions for all vegetation
	var vegetation_data = VG_collect_vegetation_positions()
	
	# Create multimeshes for efficient rendering
	var multimesh_data = VG_create_tree_multimeshes(vegetation_data)
	
	# Early return if no valid positions were found
	if multimesh_data.size() == 0:
		return
	
	# Get and configure materials from the factory
	var trunk_material = vegetation_factory.get_shared_material(Color(0.4, 0.3, 0.2))
	var canopy_material = vegetation_factory.get_shared_material(grass_color.darkened(0.1))
	
	# Create and add MultiMeshInstance3D nodes
	var trunk_instance = MultiMeshInstance3D.new()
	trunk_instance.name = "TreeTrunks"
	trunk_instance.multimesh = multimesh_data.trunk_multimesh
	trunk_instance.material_override = trunk_material
	trunk_instance.position.y = .05
	
	var canopy_instance = MultiMeshInstance3D.new()
	canopy_instance.name = "TreeCanopies"
	canopy_instance.multimesh = multimesh_data.canopy_multimesh
	canopy_instance.material_override = canopy_material
	
	# Add instances to parent
	vegetation_parent.add_child(trunk_instance)
	vegetation_parent.add_child(canopy_instance)
	
	# Set ownership for editor
	if Engine.is_editor_hint() and get_tree().edited_scene_root:
		recursive_set_owner(vegetation_parent, get_tree().edited_scene_root)

# Add dense forest patch to specific tile
func SF_add_forest_patch(x: int, z: int, parent_node: Node3D = null) -> void:
	var local_parent = parent_node if parent_node else self
	var forest_node = Node3D.new()
	forest_node.name = "DenseForestPatch_%d_%d" % [x, z]
	local_parent.add_child(forest_node)
	
	# Create 8-12 trees in a dense arrangement
	var local_tree_count = randi_range(8, 12)
	var result = generate_positions_in_tile(x, z, local_tree_count, 0.15)
	var positions = result[0]
	var normals = result[1]
	
	for i in range(positions.size()):
		var tree = vegetation_factory.create_grassland_tree(i)
		tree.position = positions[i]
		tree.rotation.y = randf_range(0, PI * 2)
		
		# Apply normal alignment for varied terrain
		var normal_transform = UT_align_with_normal(normals[i])
		tree.transform = tree.transform * normal_transform
		
		forest_node.add_child(tree)
	
	# Set ownership for editor
	if Engine.is_editor_hint() and get_tree().edited_scene_root:
		recursive_set_owner(forest_node, get_tree().edited_scene_root)
