@tool
extends BiomeVegetationGenerator
class_name FishGenerator

var fish_plant_count: int = 0

func _init():
	super()

func CF_configure(veg_factory, grid, terrain, biome, tile_features_dict: Dictionary, buildings_dict = null):
	super.CF_configure(veg_factory, grid, terrain, biome, tile_features_dict, buildings_dict)
	set_density(1, 3)
	return self

func GEN_generate_vegetation(parent_node: Node3D = null) -> void:
	fish_plant_count = 0
	
	# Create parent node for all vegetation elements if not provided
	var vegetation_parent = SET_setup_vegetation_parent(parent_node)
	
	# Collect positions for plants
	var vegetation_data = POS_collect_vegetation_positions()
	
	if vegetation_data.plant_positions.size() > 0:
		BLD_create_fish_plants_group(vegetation_parent, vegetation_data)
	
		# Add atmospheric underwater effect
		SF_add_underwater_lighting(vegetation_parent)
	
	if Engine.is_editor_hint() and get_tree().edited_scene_root:
		recursive_set_owner(vegetation_parent, get_tree().edited_scene_root)

func SET_setup_vegetation_parent(parent_node: Node3D = null) -> Node3D:
	if parent_node:
		return parent_node
	
	var vegetation_parent = Node3D.new()
	vegetation_parent.name = "FishVegetation"
	add_child(vegetation_parent)
	return vegetation_parent

func POS_collect_vegetation_positions() -> Dictionary:
	var data = {
		"plant_positions": [],
		"plant_rotations": [],
		"plant_normals": []
	}
	
	for x in range(grid_size):
		for z in range(grid_size):
			if is_building_tile(x, z):
				continue
			
			if biome_gen.get_tile_biome(x, z) == "fish":
				POS_populate_tile_vegetation(x, z, data)
	
	return data

func POS_populate_tile_vegetation(x: int, z: int, data: Dictionary) -> void:
	var count = randi_range(min_density, max_density)
	if count > 0:
		var result = generate_positions_in_tile(x, z, count, 0.3)
		var positions = result[0]
		var normals = result[1]
		
		for i in range(positions.size()):
			data.plant_positions.append(positions[i])
			data.plant_rotations.append(randf_range(0, PI * 2))
			data.plant_normals.append(normals[i])
			fish_plant_count += 1

func BLD_create_fish_plants_group(parent: Node3D, data: Dictionary) -> void:
	for i in range(data.plant_positions.size()):
		var plant = vegetation_factory.create_fish_plant(fish_plant_count - data.plant_positions.size() + i + 1)
		
		# Apply position
		plant.position = data.plant_positions[i]
		
		# Apply normal alignment and rotation
		var normal_transform = UT_align_with_normal(data.plant_normals[i])
		plant.transform = plant.transform * normal_transform
		plant.rotation.y = data.plant_rotations[i]
		
		# Add color variation to plants
		var plant_parts = UT_find_meshes_in_children(plant)
		for part in plant_parts:
			if part.material_override:
				var original_color = part.material_override.albedo_color
				part.material_override = part.material_override.duplicate()
				part.material_override.albedo_color = original_color.lightened(randf_range(-0.1, 0.1))
		
		# Add some underwater particles for atmosphere
		if randf() > 0.7:  # Only on some plants
			BLD_add_bubble_particles(plant)
		
		parent.add_child(plant)

func BLD_add_bubble_particles(plant: Node3D) -> void:
	var bubbles = GPUParticles3D.new()
	bubbles.name = "Bubbles"
	
	var particle_material = ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_material.emission_sphere_radius = 0.1
	particle_material.gravity = Vector3(0, 0.5, 0)
	particle_material.initial_velocity_min = 0.1
	particle_material.initial_velocity_max = 0.2
	particle_material.scale_min = 0.01
	particle_material.scale_max = 0.03
	particle_material.damping_min = 0.1  # Add some damping for more natural movement
	particle_material.damping_max = 0.3
	
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.02
	sphere_mesh.height = 0.04
	bubbles.draw_pass_1 = sphere_mesh
	
	var bubble_material = StandardMaterial3D.new()
	bubble_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bubble_material.albedo_color = Color(1.0, 1.0, 1.0, 0.3)
	bubble_material.metallic = 0.8
	bubble_material.roughness = 0.1
	bubble_material.refraction_enabled = true  # Enable refraction for more realistic bubbles
	bubble_material.refraction_scale = 0.05
	bubbles.material_override = bubble_material
	
	bubbles.process_material = particle_material
	bubbles.amount = 5
	bubbles.lifetime = 2.0
	bubbles.position.y = 0.3
	bubbles.randomness = 1.0  # Add randomness
	
	plant.add_child(bubbles)

func SF_add_underwater_lighting(parent: Node3D) -> void:
	# Add caustics light (animated light patterns like in water)
	var caustics = OmniLight3D.new()
	caustics.name = "UnderwaterCaustics"
	caustics.light_color = Color(0.5, 0.8, 1.0)
	caustics.light_energy = 0.5
	caustics.omni_range = grid_size * tile_size * 0.5
	
	# Animate the light with a script
	var animation_script = GDScript.new()
	animation_script.source_code = """
	extends OmniLight3D

	var time = 0
	var original_energy = 0.5

	func _ready():
		original_energy = light_energy

	func _process(delta):
		time += delta
		light_energy = original_energy + sin(time * 2.0) * 0.2
		
		# Add subtle position variation for better underwater effect
		position.x += sin(time * 1.3) * 0.003
		position.z += cos(time * 1.7) * 0.003
	"""
	
	caustics.set_script(animation_script)
	parent.add_child(caustics)
	
	# Add a subtle underwater fog effect
	var fog = FogVolume.new()
	fog.name = "UnderwaterFog"
	fog.size = Vector3(grid_size * tile_size, 2.0, grid_size * tile_size)
	fog.position.y = 1.0
	
	# Set fog properties for underwater look
	var fog_material = FogMaterial.new()
	fog_material.density = 0.02
	fog_material.albedo = Color(0.1, 0.2, 0.4, 0.1)
	fog.material = fog_material
	
	parent.add_child(fog)

# Helper function to find all mesh instances in children
func UT_find_meshes_in_children(node: Node) -> Array:
	var meshes = []
	
	if node is MeshInstance3D:
		meshes.append(node)
	
	for child in node.get_children():
		meshes.append_array(UT_find_meshes_in_children(child))
	
	return meshes

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
