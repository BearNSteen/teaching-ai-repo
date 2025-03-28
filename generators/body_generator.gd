@tool
extends RefCounted
class_name BodyGenerator

const MaterialUtils = preload("res://CHARACTERS/JESTERETTE/utils/material_utils.gd")

class Limb:
	var mesh: Mesh
	var position: Vector3
	var rotation: Vector3
	var scale: Vector3
	
	func _init(m: Mesh, p: Vector3, r: Vector3 = Vector3.ZERO, s: Vector3 = Vector3.ONE):
		mesh = m
		position = p
		rotation = r
		scale = s

static func create_limb_mesh_instance(limb: Limb, name: String) -> MeshInstance3D:
	var instance = MeshInstance3D.new()
	instance.name = name
	instance.mesh = limb.mesh
	instance.position = limb.position
	instance.rotation = limb.rotation
	instance.scale = limb.scale
	return instance

func generate(parent: Node3D, settings: Resource) -> void:
	var torso = _generate_torso(settings)
	parent.add_child(torso)
	JesteretteCharacterGenerator.set_owner_recursive(torso, parent.owner)
	
	_generate_arms(parent, settings)
	_generate_legs(parent, settings)

func _generate_torso(settings: Resource) -> Node3D:
	var torso = Node3D.new()
	torso.name = "Torso"
	
	# Main body
	var main_body = create_limb_mesh_instance(
		Limb.new(
			_create_main_body_mesh(settings),
			Vector3(0, settings.leg_length + (settings.character_height * 0.35) / 2, 0)
		),
		"MainBody"
	)
	MaterialUtils.apply_material(main_body, settings.skin_color)
	torso.add_child(main_body)
	
	# Upper torso
	var upper_torso = create_limb_mesh_instance(
		Limb.new(
			_create_custom_upper_torso(settings),
			Vector3(0, 0.22, 0)
		),
		"UpperTorso"
	)
	MaterialUtils.apply_material(upper_torso, settings.skin_color)
	torso.add_child(upper_torso)
	
	# Neck
	var neck = create_limb_mesh_instance(
		Limb.new(
			_create_neck_mesh(settings),
			Vector3(0, 0.265, 0)
		),
		"Neck"
	)
	MaterialUtils.apply_material(neck, settings.skin_color)
	torso.add_child(neck)
	
	# Shoulders and trapezius muscles
	for side in [-1, 1]:
		var shoulder = create_limb_mesh_instance(
			Limb.new(
				_create_shoulder_mesh(settings),
				Vector3(side * 0.169, 0.202 + (0.009 if side > 0 else 0), 0),
				Vector3.ZERO,
				Vector3(1, 1, 0.699)
			),
			"Shoulder" + ("R" if side > 0 else "L")
		)
		MaterialUtils.apply_material(shoulder, settings.skin_color)
		torso.add_child(shoulder)
		
		var trap = create_limb_mesh_instance(
			Limb.new(
				_create_trapezius_mesh(settings),
				Vector3(side * 0.1, 0.26, 0),
				Vector3(0, 0, side * -15),
				Vector3(1, 0.6, 0.8)
			),
			"Trapezius" + ("R" if side > 0 else "L")
		)
		MaterialUtils.apply_material(trap, settings.skin_color)
		torso.add_child(trap)
	
	# Add chest areas
	_add_chest_areas(torso, settings)
	
	return torso

func _generate_arms(parent: Node3D, settings: Resource) -> void:
	for side in [-1, 1]:
		var arm_root = Node3D.new()
		arm_root.name = "Arm" + ("R" if side > 0 else "L")
		
		# Upper arm
		var upper_arm = create_limb_mesh_instance(
			Limb.new(
				_create_upper_arm_mesh(settings),
				Vector3(0, -settings.arm_length * 0.24, 0)
			),
			"UpperArm"
		)
		MaterialUtils.apply_material(upper_arm, settings.skin_color)
		arm_root.add_child(upper_arm)
		
		# Add elbow, lower arm, hand
		_add_lower_arm(arm_root, side, settings)
		
		arm_root.position = Vector3(
			side * (settings.body_width * 0.52),
			settings.leg_length + (settings.character_height * 0.33),
			0
		)
		arm_root.rotation_degrees = Vector3(0, 0, side * 10)
		
		parent.add_child(arm_root)
		JesteretteCharacterGenerator.set_owner_recursive(arm_root, parent.owner)

func _generate_legs(parent: Node3D, settings: Resource) -> void:
	for side in [-1, 1]:
		var leg_root = Node3D.new()
		leg_root.name = "Leg" + ("R" if side > 0 else "L")
		
		# Thigh
		var thigh = create_limb_mesh_instance(
			Limb.new(
				_create_thigh_mesh(settings),
				Vector3(0, settings.leg_length * 0.75, 0.02),
				Vector3(-5, 0, 0)
			),
			"Thigh"
		)
		MaterialUtils.apply_material(thigh, settings.skin_color)
		leg_root.add_child(thigh)
		
		# Add knee, calf, ankle, foot
		_add_lower_leg(leg_root, side, settings)
		
		leg_root.position = Vector3(side * settings.body_width * 0.2, 0, 0)
		
		parent.add_child(leg_root)
		JesteretteCharacterGenerator.set_owner_recursive(leg_root, parent.owner)

func _add_lower_arm(arm_root: Node3D, side: float, settings: Resource) -> void:
	# Elbow
	var elbow = create_limb_mesh_instance(
		Limb.new(
			_create_elbow_mesh(settings),
			Vector3(0, -settings.arm_length * 0.48, 0)
		),
		"Elbow"
	)
	MaterialUtils.apply_material(elbow, settings.skin_color)
	arm_root.add_child(elbow)
	
	# Lower arm
	var angle_rad = deg_to_rad(15)
	var horizontal_offset = sin(angle_rad) * (settings.arm_length * 0.225)
	var vertical_offset = -settings.arm_length * 0.48
	
	var lower_arm = create_limb_mesh_instance(
		Limb.new(
			_create_lower_arm_mesh(settings),
			Vector3(-side * horizontal_offset, vertical_offset - settings.arm_length * 0.225, 0),
			Vector3(0, 0, -side * 15)
		),
		"LowerArm"
	)
	MaterialUtils.apply_material(lower_arm, settings.skin_color)
	arm_root.add_child(lower_arm)
	
	# Hand
	var hand_group = Node3D.new()
	hand_group.name = "Hand"
	hand_group.position = Vector3(-side * 0.057, -(settings.arm_length * 0.48 + settings.arm_length * 0.45), 0)
	hand_group.rotation_degrees = Vector3(-17.1, -side * 90, side * 10)
	
	var palm = create_limb_mesh_instance(
		Limb.new(
			_create_palm_mesh(settings),
			Vector3(0, -settings.body_width * 0.1, 0)
		),
		"Palm"
	)
	MaterialUtils.apply_material(palm, settings.skin_color)
	hand_group.add_child(palm)
	
	# Fingers
	var finger_group = Node3D.new()
	finger_group.name = "Fingers"
	finger_group.position = Vector3(0, -settings.body_width * 0.15, 0)
	
	for i in range(4):
		var finger = _create_finger(i, settings)
		finger_group.add_child(finger)
	
	hand_group.add_child(finger_group)
	
	# Thumb
	var thumb = _create_thumb(settings, side)
	hand_group.add_child(thumb)
	
	arm_root.add_child(hand_group)

func _add_lower_leg(leg_root: Node3D, side: float, settings: Resource) -> void:
	# Knee
	var knee = create_limb_mesh_instance(
		Limb.new(
			_create_knee_mesh(settings),
			Vector3(0, settings.leg_length * 0.5, 0.04)
		),
		"Knee"
	)
	MaterialUtils.apply_material(knee, settings.skin_color)
	leg_root.add_child(knee)
	
	# Calf
	var calf = create_limb_mesh_instance(
		Limb.new(
			_create_calf_mesh(settings),
			Vector3(0, settings.leg_length * 0.25, 0.02),
			Vector3(5, 0, 0)
		),
		"Calf"
	)
	MaterialUtils.apply_material(calf, settings.skin_color)
	leg_root.add_child(calf)
	
	# Ankle
	var ankle = create_limb_mesh_instance(
		Limb.new(
			_create_ankle_mesh(settings),
			Vector3(0, settings.leg_length * 0.04, 0)
		),
		"Ankle"
	)
	MaterialUtils.apply_material(ankle, settings.skin_color)
	leg_root.add_child(ankle)
	
	# Foot
	var foot = create_limb_mesh_instance(
		Limb.new(
			_create_foot_mesh(settings),
			Vector3(0, 0, settings.body_width * 0.12),
			Vector3(90, 0, 0)
		),
		"Foot"
	)
	MaterialUtils.apply_material(foot, settings.outfit_color1)
	leg_root.add_child(foot)

# Mesh creation functions
func _create_main_body_mesh(settings: Resource) -> Mesh:
	var cylinder_mesh = CylinderMesh.new()
	cylinder_mesh.top_radius = 0
	cylinder_mesh.bottom_radius = settings.body_width * 0.35
	cylinder_mesh.height = settings.character_height * 0.35
	cylinder_mesh.radial_segments = 16
	return cylinder_mesh

func _create_custom_upper_torso(settings: Resource) -> ArrayMesh:
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var segments = 16
	var radius_top = settings.body_width * 0.3
	var radius_bottom = settings.body_width * 0.4
	var height = settings.character_height * 0.08
	
	var top_vertices = []
	var bottom_vertices = []
	
	for i in range(segments):
		var angle = i * (2*PI / segments)
		var v_top = Vector3(cos(angle) * radius_top, height/2, sin(angle) * radius_top)
		var v_bottom = Vector3(cos(angle) * radius_bottom, -height/2, sin(angle) * radius_bottom)
		top_vertices.append(v_top)
		bottom_vertices.append(v_bottom)
	
	for i in range(segments):
		var next = (i + 1) % segments
		surface_tool.add_vertex(top_vertices[i])
		surface_tool.add_vertex(bottom_vertices[i])
		surface_tool.add_vertex(top_vertices[next])
		surface_tool.add_vertex(top_vertices[next])
		surface_tool.add_vertex(bottom_vertices[i])
		surface_tool.add_vertex(bottom_vertices[next])
	
	for i in range(1, segments - 1):
		surface_tool.add_vertex(top_vertices[0])
		surface_tool.add_vertex(top_vertices[i])
		surface_tool.add_vertex(top_vertices[i + 1])
		surface_tool.add_vertex(bottom_vertices[0])
		surface_tool.add_vertex(bottom_vertices[i + 1])
		surface_tool.add_vertex(bottom_vertices[i])
	
	surface_tool.generate_normals()
	return surface_tool.commit()

func _create_neck_mesh(settings: Resource) -> Mesh:
	var cylinder_mesh = CylinderMesh.new()
	cylinder_mesh.top_radius = settings.body_width * 0.15
	cylinder_mesh.bottom_radius = settings.body_width * 0.2
	cylinder_mesh.height = settings.character_height * 0.1
	return cylinder_mesh

func _create_shoulder_mesh(settings: Resource) -> Mesh:
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = settings.body_width * 0.25
	sphere_mesh.height = settings.body_width * 0.5
	return sphere_mesh

func _create_trapezius_mesh(settings: Resource) -> Mesh:
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = settings.body_width * 0.15
	sphere_mesh.height = settings.body_width * 0.3
	return sphere_mesh

func _create_upper_arm_mesh(settings: Resource) -> Mesh:
	var cylinder_mesh = CylinderMesh.new()
	cylinder_mesh.top_radius = settings.body_width * 0.15
	cylinder_mesh.bottom_radius = settings.body_width * 0.1
	cylinder_mesh.height = settings.arm_length * 0.48
	return cylinder_mesh

func _create_elbow_mesh(settings: Resource) -> Mesh:
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = settings.body_width * 0.11
	sphere_mesh.height = settings.body_width * 0.22
	return sphere_mesh

func _create_lower_arm_mesh(settings: Resource) -> Mesh:
	var cylinder_mesh = CylinderMesh.new()
	cylinder_mesh.top_radius = settings.body_width * 0.1
	cylinder_mesh.bottom_radius = settings.body_width * 0.08
	cylinder_mesh.height = settings.arm_length * 0.45
	return cylinder_mesh

func _create_palm_mesh(settings: Resource) -> Mesh:
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(settings.body_width * 0.12, settings.body_width * 0.2, settings.body_width * 0.04)
	return box_mesh

func _create_finger(index: int, settings: Resource) -> MeshInstance3D:
	var finger = MeshInstance3D.new()
	finger.name = "Finger" + str(index)
	
	var finger_mesh = CapsuleMesh.new()
	finger_mesh.radius = settings.body_width * 0.015
	finger_mesh.height = settings.body_width * 0.15
	finger.mesh = finger_mesh
	
	var spread = lerp(-0.015, 0.015, float(index) / 3.0) * -1
	finger.position = Vector3(spread, -settings.body_width * 0.07, 0)
	finger.rotation_degrees = Vector3(-5, 0, 0)
	
	MaterialUtils.apply_material(finger, settings.skin_color)
	return finger

func _create_thumb(settings: Resource, side: float) -> MeshInstance3D:
	var thumb = MeshInstance3D.new()
	thumb.name = "Thumb"
	
	var thumb_mesh = CapsuleMesh.new()
	thumb_mesh.radius = settings.body_width * 0.02
	thumb_mesh.height = settings.body_width * 0.12
	thumb.mesh = thumb_mesh
	
	thumb.position = Vector3(side * 0.02, -settings.body_width * 0.08, settings.body_width * 0.02)
	thumb.rotation_degrees = Vector3(-15, side * 45, 0)
	
	MaterialUtils.apply_material(thumb, settings.skin_color)
	return thumb

func _create_thigh_mesh(settings: Resource) -> Mesh:
	var cylinder_mesh = CylinderMesh.new()
	cylinder_mesh.top_radius = settings.body_width * 0.22
	cylinder_mesh.bottom_radius = settings.body_width * 0.17
	cylinder_mesh.height = settings.leg_length * 0.45
	return cylinder_mesh

func _create_knee_mesh(settings: Resource) -> Mesh:
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = settings.body_width * 0.18
	sphere_mesh.height = settings.body_width * 0.36
	return sphere_mesh

func _create_calf_mesh(settings: Resource) -> Mesh:
	var cylinder_mesh = CylinderMesh.new()
	cylinder_mesh.top_radius = settings.body_width * 0.17
	cylinder_mesh.bottom_radius = settings.body_width * 0.1
	cylinder_mesh.height = settings.leg_length * 0.42
	return cylinder_mesh

func _create_ankle_mesh(settings: Resource) -> Mesh:
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = settings.body_width * 0.1
	sphere_mesh.height = settings.body_width * 0.2
	return sphere_mesh

func _create_foot_mesh(settings: Resource) -> Mesh:
	var capsule_mesh = CapsuleMesh.new()
	capsule_mesh.radius = settings.body_width * 0.1
	capsule_mesh.height = settings.body_width * 0.45
	return capsule_mesh

# Helper functions
func _add_chest_areas(torso: Node3D, settings: Resource) -> void:
	for i in range(2):
		var chest = create_limb_mesh_instance(
			Limb.new(
				_create_chest_mesh(settings),
				Vector3(0.05 if i == 0 else -0.05, 0.182, 0.114),
				Vector3.ZERO,
				Vector3(0.5, 0.5, 0.5)
			),
			"Chest" + str(i+1)
		)
		MaterialUtils.apply_material(chest, settings.skin_color)
		torso.add_child(chest)

func _create_chest_mesh(settings: Resource) -> Mesh:
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = settings.body_width * 0.45
	sphere_mesh.height = settings.body_width * 0.9
	return sphere_mesh
