@tool
extends EditorScenePostImport

# Base class for all physics import scripts
# Contains all shared logic for converting meshes and adding physics

enum ShapeType {
	NONE = 0,
	TRIMESH = 1,
	CONVEX = 2,
	BOX = 3,
	SPHERE = 4,
	CAPSULE = 5
}

func _post_import(scene):
	var physics_shape_type = get_shape_type()
	var shape_name = get_shape_name()
	
	print("Generating ", shape_name, " physics for: ", get_source_file())
	
	# Configuration
	var physics_layer = 1
	var physics_mask = 1
	
	# Convert ImporterMeshInstance3D to MeshInstance3D
	_convert_all_importer_meshes(scene)
	
	# Add physics to converted meshes
	_add_physics_recursive(scene, physics_shape_type, physics_layer, physics_mask)
	
	print(shape_name, " physics generation completed")
	return scene

# Override this in child classes to specify shape type
func get_shape_type() -> int:
	return ShapeType.NONE

# Override this in child classes to specify shape name for logging
func get_shape_name() -> String:
	return "Unknown"

func _convert_all_importer_meshes(node: Node):
	var children_to_process = []
	for child in node.get_children():
		children_to_process.append(child)
	
	for child in children_to_process:
		if child.get_class() == "ImporterMeshInstance3D":
			_convert_importer_mesh_instance(child)
		else:
			_convert_all_importer_meshes(child)

func _convert_importer_mesh_instance(importer_node: Node):
	var importer_mesh = importer_node.get("mesh")
	if not importer_mesh:
		return
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = importer_node.name
	mesh_instance.transform = importer_node.transform
	
	var mesh = importer_mesh.get_mesh()
	mesh_instance.mesh = mesh
	
	for surface_idx in range(importer_mesh.get_surface_count()):
		var material = importer_mesh.get_surface_material(surface_idx)
		if material:
			mesh_instance.set_surface_override_material(surface_idx, material)
	
	var parent = importer_node.get_parent()
	var index = importer_node.get_index()
	
	parent.remove_child(importer_node)
	parent.add_child(mesh_instance)
	parent.move_child(mesh_instance, index)
	
	var scene_root = _find_scene_root(mesh_instance)
	if scene_root:
		mesh_instance.owner = scene_root

func _find_scene_root(node: Node) -> Node:
	var current = node
	while current.get_parent() != null:
		current = current.get_parent()
	return current

func _add_physics_recursive(node: Node, physics_shape_type: int, physics_layer: int, physics_mask: int):
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		if mesh_instance.mesh:
			_add_physics_to_mesh(mesh_instance, physics_shape_type, physics_layer, physics_mask)
	
	for child in node.get_children():
		_add_physics_recursive(child, physics_shape_type, physics_layer, physics_mask)

func _add_physics_to_mesh(mesh_instance: MeshInstance3D, physics_shape_type: int, physics_layer: int, physics_mask: int):
	var parent = mesh_instance.get_parent()
	var mesh_transform = mesh_instance.transform
	var mesh_index = mesh_instance.get_index()
	
	var original_owner = mesh_instance.owner
	mesh_instance.owner = null
	
	var static_body = StaticBody3D.new()
	static_body.name = mesh_instance.name + "_StaticBody"
	static_body.transform = mesh_transform
	static_body.collision_layer = physics_layer
	static_body.collision_mask = physics_mask
	
	parent.remove_child(mesh_instance)
	parent.add_child(static_body)
	parent.move_child(static_body, mesh_index)
	
	mesh_instance.transform = Transform3D.IDENTITY
	static_body.add_child(mesh_instance)
	
	var collision_shape = CollisionShape3D.new()
	collision_shape.name = mesh_instance.name + "_CollisionShape"
	collision_shape.transform = Transform3D.IDENTITY
	
	var shape = _create_physics_shape(mesh_instance.mesh, physics_shape_type)
	if shape:
		collision_shape.shape = shape
		static_body.add_child(collision_shape)
		
		if original_owner:
			static_body.owner = original_owner
			mesh_instance.owner = original_owner
			collision_shape.owner = original_owner

# Override this in child classes for specific shape creation logic
func _create_physics_shape(mesh: Mesh, shape_type: int) -> Shape3D:
	if not mesh:
		return null
	
	var aabb = mesh.get_aabb()
	if aabb.size.length() < 0.001:
		return null
	
	match shape_type:
		ShapeType.TRIMESH: return _create_trimesh_shape(mesh)
		ShapeType.CONVEX: return _create_convex_shape(mesh, aabb)
		ShapeType.BOX: return _create_box_shape(aabb)
		ShapeType.SPHERE: return _create_sphere_shape(aabb)
		ShapeType.CAPSULE: return _create_capsule_shape(aabb)
		_: return null

# Helper methods for shape creation
func _create_trimesh_shape(mesh: Mesh) -> Shape3D:
	var trimesh_shape = mesh.create_trimesh_shape()
	if not trimesh_shape:
		print("Failed to create trimesh shape, falling back to convex")
		return mesh.create_convex_shape()
	return trimesh_shape

func _create_convex_shape(mesh: Mesh, aabb: AABB) -> Shape3D:
	var convex_shape = mesh.create_convex_shape()
	if not convex_shape:
		print("Failed to create convex shape, falling back to box")
		return _create_box_shape(aabb)
	return convex_shape

func _create_box_shape(aabb: AABB) -> Shape3D:
	var box_shape = BoxShape3D.new()
	box_shape.size = aabb.size
	return box_shape

func _create_sphere_shape(aabb: AABB) -> Shape3D:
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = max(aabb.size.x, max(aabb.size.y, aabb.size.z)) / 2.0
	return sphere_shape

func _create_capsule_shape(aabb: AABB) -> Shape3D:
	var capsule_shape = CapsuleShape3D.new()
	capsule_shape.radius = max(aabb.size.x, aabb.size.z) / 2.0
	capsule_shape.height = aabb.size.y
	return capsule_shape
