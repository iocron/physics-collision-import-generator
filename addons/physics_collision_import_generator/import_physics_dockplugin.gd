@tool
extends EditorImportPlugin

func _get_importer_name():
	return "scene_with_physics"

func _get_visible_name():
	return "Scene (with Physics Options)"

func _get_recognized_extensions():
	return ["glb", "gltf"]

func _get_save_extension():
	return "tscn"

func _get_resource_type():
	return "PackedScene"

func _get_preset_count():
	return 2

func _get_preset_name(preset_index):
	match preset_index:
		0: return "Default"
		1: return "With Physics"
		_: return ""

func _get_import_options(path, preset_index):
	var base_options = [
		# Root node options
		{"name": "root_type", "default_value": "", "property_hint": PROPERTY_HINT_TYPE_STRING, "hint_string": "Node3D"},
		{"name": "root_name", "default_value": ""},
		{"name": "root_scale", "default_value": 1.0},
		
		# Node options  
		{"name": "nodes/root_type", "default_value": "", "property_hint": PROPERTY_HINT_TYPE_STRING, "hint_string": "Node3D"},
		{"name": "nodes/root_name", "default_value": ""},
		{"name": "nodes/apply_root_scale", "default_value": true},
		{"name": "nodes/root_scale", "default_value": 1.0},
		{"name": "nodes/import_as_skeleton_bones", "default_value": false},
		
		# Mesh options
		{"name": "meshes/ensure_tangents", "default_value": true},
		{"name": "meshes/generate_lods", "default_value": true},
		{"name": "meshes/create_shadow_meshes", "default_value": true},
		{"name": "meshes/light_baking", "default_value": 1, "property_hint": PROPERTY_HINT_ENUM, "hint_string": "Disabled,Static (VoxelGI/SDFGI/LightmapGI),Static and Dynamic (VoxelGI/SDFGI only)"},
		{"name": "meshes/lightmap_texel_size", "default_value": 0.2},
		{"name": "meshes/force_disable_compression", "default_value": false},
		
		# Skin options
		{"name": "skins/use_named_skins", "default_value": true},
		
		# Animation options
		{"name": "animation/import", "default_value": true},
		{"name": "animation/fps", "default_value": 30},
		{"name": "animation/trimming", "default_value": false},
		{"name": "animation/remove_immutable_tracks", "default_value": true},
		
		# Import script
		{"name": "import_script/path", "default_value": "", "property_hint": PROPERTY_HINT_FILE, "hint_string": "*.gd"},
	]
	
	var physics_options = [
		{
			"name": "physics/create_physics_bodies",
			"default_value": preset_index == 1,
			"property_hint": PROPERTY_HINT_NONE
		},
		{
			"name": "physics/shape_type",
			"default_value": 0,
			"property_hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trimesh,Convex,Box,Sphere,Capsule"
		},
		{
			"name": "physics/collision_layer",
			"default_value": 1,
			"property_hint": PROPERTY_HINT_LAYERS_3D_PHYSICS
		},
		{
			"name": "physics/collision_mask", 
			"default_value": 1,
			"property_hint": PROPERTY_HINT_LAYERS_3D_PHYSICS
		}
	]
	
	return base_options + physics_options

func _get_option_visibility(path, option_name, options):
	if option_name.begins_with("physics/") and option_name != "physics/create_physics_bodies":
		return options.get("physics/create_physics_bodies", false)
	return true

func _import(source_file: String, save_path: String, options: Dictionary, platform_variants: Array, gen_files: Array):
	print("Importing GLB file: ", source_file)
	print("Options: ", options)
	
	# Create GLTF document and state
	var gltf_document = GLTFDocument.new()
	var gltf_state = GLTFState.new()
	
	# Configure GLTF state with import settings
	gltf_state.handle_binary_image = GLTFState.HANDLE_BINARY_EXTRACT_TEXTURES
	
	# Parse the GLTF file
	var error = gltf_document.append_from_file(source_file, gltf_state)
	if error != OK:
		print("Error loading GLTF file: ", error)
		return error
	
	print("GLTF loaded successfully, nodes: ", gltf_state.get_nodes().size())
	print("GLTF meshes: ", gltf_state.get_meshes().size())
	
	# Generate the scene
	var scene_root = gltf_document.generate_scene(gltf_state)
	if not scene_root:
		print("Error: Failed to generate scene from GLTF")
		return FAILED
	
	print("Generated scene root: '", scene_root.name, "' with ", scene_root.get_child_count(), " children")
	
	# Set the scene root as the owner for all child nodes
	_set_owner_recursive(scene_root, scene_root)
	
	# First pass: Convert all ImporterMeshInstance3D to MeshInstance3D
	print("Converting ImporterMeshInstance3D nodes...")
	_convert_all_importer_meshes(scene_root)
	
	# Second pass: Debug scene structure
	print("Final scene structure:")
	_debug_scene_structure(scene_root)
	
	# Apply scene settings
	_apply_scene_settings(scene_root, options)
	
	# Third pass: Add physics if requested
	if options.get("physics/create_physics_bodies", false):
		print("Adding physics to scene...")
		var physics_shape_type = options.get("physics/shape_type", 0)
		var physics_layer = options.get("physics/collision_layer", 1)
		var physics_mask = options.get("physics/collision_mask", 1)
		_add_physics_recursive(scene_root, physics_shape_type, physics_layer, physics_mask)
		print("Physics generation completed")
	
	# Create and save the packed scene
	var packed_scene = PackedScene.new()
	var pack_result = packed_scene.pack(scene_root)
	if pack_result != OK:
		print("Error packing scene: ", pack_result)
		return pack_result
	
	var final_path = save_path + "." + _get_save_extension()
	var save_result = ResourceSaver.save(packed_scene, final_path)
	if save_result != OK:
		print("Error saving scene to ", final_path, ": ", save_result)
		return save_result
	else:
		print("Successfully saved scene to: ", final_path)
	
	return OK

func _set_owner_recursive(node: Node, owner: Node):
	# Set owner for this node (except the root)
	if node != owner:
		node.owner = owner
	
	# Recursively set owner for all children
	for child in node.get_children():
		_set_owner_recursive(child, owner)

func _convert_all_importer_meshes(node: Node):
	# Convert ImporterMeshInstance3D nodes to MeshInstance3D
	var children_to_process = []
	for child in node.get_children():
		children_to_process.append(child)
	
	# Process children (we collect them first to avoid modifying during iteration)
	for child in children_to_process:
		if child.get_class() == "ImporterMeshInstance3D":
			print("Converting: ", child.name)
			_convert_importer_mesh_instance(child)
		else:
			# Recursively process non-importer nodes
			_convert_all_importer_meshes(child)

func _debug_scene_structure(node: Node, depth: int = 0):
	# Simple debug output for final scene structure
	var indent = "  ".repeat(depth)
	print(indent, "Node: ", node.name, " (", node.get_class(), ")")
	
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		print(indent, "  - Has mesh: ", mesh_instance.mesh != null)
		if mesh_instance.mesh:
			print(indent, "  - Mesh surfaces: ", mesh_instance.mesh.get_surface_count())
	
	for child in node.get_children():
		_debug_scene_structure(child, depth + 1)

func _debug_and_fix_scene_structure(node: Node, depth: int = 0):
	var indent = "  ".repeat(depth)
	print(indent, "Node: ", node.name, " (", node.get_class(), ")")
	
	# Convert ImporterMeshInstance3D to MeshInstance3D
	if node.get_class() == "ImporterMeshInstance3D":
		print(indent, "  - Converting ImporterMeshInstance3D to MeshInstance3D")
		_convert_importer_mesh_instance(node)
		return  # Don't process children here as the node structure changed
	
	# Check if it's a MeshInstance3D and debug its state
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		print(indent, "  - Has mesh: ", mesh_instance.mesh != null)
		print(indent, "  - Visible: ", mesh_instance.visible)
		print(indent, "  - Transform: ", mesh_instance.transform)
		
		if mesh_instance.mesh:
			print(indent, "  - Mesh surfaces: ", mesh_instance.mesh.get_surface_count())
			print(indent, "  - Mesh AABB: ", mesh_instance.mesh.get_aabb())
			
		# Ensure visibility is set
		mesh_instance.visible = true
		
		# Check material
		var material = mesh_instance.get_surface_override_material(0)
		if not material and mesh_instance.mesh.get_surface_count() > 0:
			material = mesh_instance.mesh.surface_get_material(0)
		print(indent, "  - Material: ", material)
	
	# Ensure node is visible if it's a CanvasItem or Node3D
	if node.has_method("set_visible"):
		node.visible = true
	
	# Recursively debug children
	for child in node.get_children():
		_debug_and_fix_scene_structure(child, depth + 1)

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

func _apply_gltf_settings(gltf_state: GLTFState, options: Dictionary):
	# Apply GLTF-specific settings before scene generation
	# These settings affect how the GLTF is processed
	
	# Handle mesh settings
	if options.has("meshes/ensure_tangents"):
		# This is handled during GLTF processing
		pass
	
	# Handle animation settings
	if options.has("animation/fps"):
		# Set animation FPS if needed
		pass

func _apply_scene_settings(scene_root: Node3D, options: Dictionary):
	# Apply root name if specified
	var root_name = options.get("root_name", "")
	if not root_name.is_empty():
		scene_root.name = root_name
	
	# Apply root scale
	var root_scale = options.get("root_scale", 1.0)
	if root_scale != 1.0:
		scene_root.scale = Vector3.ONE * root_scale
	
	# Apply nodes/root_scale if different from root_scale
	var nodes_root_scale = options.get("nodes/root_scale", 1.0)
	if nodes_root_scale != 1.0 and nodes_root_scale != root_scale:
		scene_root.scale = Vector3.ONE * nodes_root_scale

func _add_physics_recursive(node: Node, physics_shape_type: int, physics_layer: int, physics_mask: int):
	print("Checking node for physics: ", node.name, " (", node.get_class(), ")")
	
	# Check if this node has a MeshInstance3D
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		print("  Found MeshInstance3D: ", mesh_instance.name)
		if mesh_instance.mesh:
			print("  Adding physics to mesh: ", mesh_instance.name)
			_add_physics_to_mesh(mesh_instance, physics_shape_type, physics_layer, physics_mask)
		else:
			print("  MeshInstance3D has no mesh: ", mesh_instance.name)
	
	# Recursively process children
	for child in node.get_children():
		_add_physics_recursive(child, physics_shape_type, physics_layer, physics_mask)

func _add_physics_to_mesh(mesh_instance: MeshInstance3D, physics_shape_type: int, physics_layer: int, physics_mask: int):
	var parent = mesh_instance.get_parent()
	var mesh_transform = mesh_instance.transform
	var mesh_index = mesh_instance.get_index()
	
	# Create a new StaticBody3D to wrap this mesh
	var static_body = StaticBody3D.new()
	static_body.name = mesh_instance.name + "_StaticBody"
	static_body.transform = mesh_transform  # Use the mesh's transform
	static_body.collision_layer = physics_layer
	static_body.collision_mask = physics_mask
	
	# Unset owner to avoid warning when reparenting
	var original_owner = mesh_instance.owner
	mesh_instance.owner = null
	
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