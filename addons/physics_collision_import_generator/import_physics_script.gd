@tool
extends EditorScenePostImport

# This script can be set in the Advanced Import Settings > Scene > Import Script > Path
# Path: res://addons/physics_collision_import_generator/import_physics_script.gd

func _post_import(scene):
	# Configuration - modify these values as needed
	var create_physics = true  # Set to true to enable physics generation
	var physics_shape_type = 0  # 0=Trimesh, 1=Convex, 2=Box, 3=Sphere, 4=Capsule
	var physics_layer = 1  # Collision layer
	var physics_mask = 1   # Collision mask
	
	if create_physics:
		print("Generating physics for imported scene: ", get_source_file())
		
		# First: Convert ImporterMeshInstance3D to MeshInstance3D
		print("Converting ImporterMeshInstance3D nodes...")
		_convert_all_importer_meshes(scene)
		
		# Second: Add physics to converted meshes
		print("Adding physics to meshes...")
		_add_physics_recursive(scene, physics_shape_type, physics_layer, physics_mask)
		
		print("Physics generation completed")
	
	return scene

func _convert_all_importer_meshes(node: Node):
	# Convert ImporterMeshInstance3D nodes to MeshInstance3D
	var children_to_process = []
	for child in node.get_children():
		children_to_process.append(child)
	
	# Process children (collect first to avoid modifying during iteration)
	for child in children_to_process:
		if child.get_class() == "ImporterMeshInstance3D":
			print("Converting: ", child.name)
			_convert_importer_mesh_instance(child)
		else:
			# Recursively process non-importer nodes
			_convert_all_importer_meshes(child)

func _convert_importer_mesh_instance(importer_node: Node):
	# Get the ImporterMesh from the ImporterMeshInstance3D
	var importer_mesh = importer_node.get("mesh")
	if not importer_mesh:
		print("  - No mesh found in ImporterMeshInstance3D")
		return
	
	# Create a new MeshInstance3D
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = importer_node.name
	mesh_instance.transform = importer_node.transform
	
	# Convert ImporterMesh to Mesh
	var mesh = importer_mesh.get_mesh()
	mesh_instance.mesh = mesh
	
	# Copy materials
	for surface_idx in range(importer_mesh.get_surface_count()):
		var material = importer_mesh.get_surface_material(surface_idx)
		if material:
			mesh_instance.set_surface_override_material(surface_idx, material)
	
	# Replace the node in the tree
	var parent = importer_node.get_parent()
	var index = importer_node.get_index()
	
	# Remove old node and add new one
	parent.remove_child(importer_node)
	parent.add_child(mesh_instance)
	parent.move_child(mesh_instance, index)
	
	# Set owner
	var scene_root = _find_scene_root(mesh_instance)
	if scene_root:
		mesh_instance.owner = scene_root
	
	print("  - Successfully converted to MeshInstance3D")

func _find_scene_root(node: Node) -> Node:
	# Find the root node by walking up the tree
	var current = node
	while current.get_parent() != null:
		current = current.get_parent()
	return current

func _add_physics_recursive(node: Node, physics_shape_type: int, physics_layer: int, physics_mask: int):
	# Check if this node has a MeshInstance3D
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		if mesh_instance.mesh:
			_add_physics_to_mesh(mesh_instance, physics_shape_type, physics_layer, physics_mask)
	
	# Recursively process children
	for child in node.get_children():
		_add_physics_recursive(child, physics_shape_type, physics_layer, physics_mask)

func _add_physics_to_mesh(mesh_instance: MeshInstance3D, physics_shape_type: int, physics_layer: int, physics_mask: int):
	var parent = mesh_instance.get_parent()
	var mesh_transform = mesh_instance.transform
	var mesh_index = mesh_instance.get_index()
	
	# Unset owner to avoid warning when reparenting
	var original_owner = mesh_instance.owner
	mesh_instance.owner = null
	
	# Create a new StaticBody3D to wrap this mesh
	var static_body = StaticBody3D.new()
	static_body.name = mesh_instance.name + "_StaticBody"
	static_body.transform = mesh_transform  # Use the mesh's transform
	static_body.collision_layer = physics_layer
	static_body.collision_mask = physics_mask
	
	# Remove mesh from its current parent
	parent.remove_child(mesh_instance)
	
	# Add StaticBody3D to the parent at the same position
	parent.add_child(static_body)
	parent.move_child(static_body, mesh_index)
	
	# Reset mesh transform since StaticBody3D now has the transform
	mesh_instance.transform = Transform3D.IDENTITY
	
	# Add mesh as child of StaticBody3D
	static_body.add_child(mesh_instance)
	
	# Create collision shape
	var collision_shape = CollisionShape3D.new()
	collision_shape.name = mesh_instance.name + "_CollisionShape"
	collision_shape.transform = Transform3D.IDENTITY  # Collision shape is at origin relative to StaticBody3D
	
	# Create the physics shape
	var shape = _create_physics_shape(mesh_instance.mesh, physics_shape_type)
	if shape:
		collision_shape.shape = shape
		static_body.add_child(collision_shape)
		
		# Set owners
		if original_owner:
			static_body.owner = original_owner
			mesh_instance.owner = original_owner
			collision_shape.owner = original_owner
		
		print("Added physics to: ", mesh_instance.name, " with transform: ", static_body.transform)

func _create_physics_shape(mesh: Mesh, shape_type: int) -> Shape3D:
	match shape_type:
		0: # Trimesh
			return mesh.create_trimesh_shape()
		1: # Convex
			return mesh.create_convex_shape()
		2: # Box
			var aabb = mesh.get_aabb()
			var box_shape = BoxShape3D.new()
			box_shape.size = aabb.size
			return box_shape
		3: # Sphere
			var aabb = mesh.get_aabb()
			var sphere_shape = SphereShape3D.new()
			sphere_shape.radius = max(aabb.size.x, max(aabb.size.y, aabb.size.z)) / 2.0
			return sphere_shape
		4: # Capsule
			var aabb = mesh.get_aabb()
			var capsule_shape = CapsuleShape3D.new()
			capsule_shape.radius = max(aabb.size.x, aabb.size.z) / 2.0
			capsule_shape.height = aabb.size.y
			return capsule_shape
		_:
			return mesh.create_trimesh_shape()