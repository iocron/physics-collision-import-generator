@tool
extends EditorPlugin

const PhysicsBase = preload("res://addons/physics_collision_import_generator/import_scripts/import_physics_base.gd")

var physics_dock

func _enter_tree():
	# Add the physics import dock panel
	physics_dock = preload("res://addons/physics_collision_import_generator/physics_import_dock.gd").new()
	physics_dock.plugin_reference = self
	add_control_to_dock(DOCK_SLOT_LEFT_BR, physics_dock) # DOCK_SLOT_LEFT_UR
	print("Physics Collision Import Generator enabled")
	print("Check the Physics Collision Import dock panel to apply physics import scripts to GLB/GLTF files")

func _exit_tree():
	if physics_dock:
		remove_control_from_docks(physics_dock)
		physics_dock = null
	print("Physics Collision Import Generator disabled")

# Helper function to set import script and re-import a file
func set_physics_import_script(file_path: String, shape_type: int = 0):
	print("Setting physics import script for: ", file_path)
	
	# Get the file system
	var filesystem = EditorInterface.get_resource_filesystem()
	if not filesystem:
		push_error("Could not get resource filesystem")
		return
	
	# Get the file's current import settings
	var import_settings_path = file_path + ".import"
	
	# Check if it's a scene file (GLB/GLTF)
	var ext = file_path.get_extension().to_lower()
	if ext not in ["glb", "gltf"]:
		push_error("File is not a GLB or GLTF file: " + file_path)
		return
	
	# Create or modify the import file
	var config = ConfigFile.new()
	if FileAccess.file_exists(import_settings_path):
		config.load(import_settings_path)
	
	# Set the importer to scene importer (only if not already set)
	if not config.has_section_key("remap", "importer"):
		config.set_value("remap", "importer", "scene")
	if not config.has_section_key("remap", "type"):
		config.set_value("remap", "type", "PackedScene")
	
	# Set the shape-specific import script - no need for physics_shape_type parameter
	var script_path = _get_script_path_for_shape_type(shape_type)
	config.set_value("params", "import_script/path", script_path)
	print("Using import script: ", script_path, " for shape type: ", shape_type)
	
	# Save the configuration
	var error = config.save(import_settings_path)
	if error != OK:
		push_error("Failed to save import settings: " + str(error))
		return
	
	# Trigger re-import
	filesystem.update_file(file_path)
	filesystem.reimport_files([file_path])
	
	print("Successfully set import script and triggered re-import for: ", file_path)

# Helper function to remove physics import script and re-import a file
func remove_physics_import_script(file_path: String):
	print("Removing physics import script for: ", file_path)
	
	# Get the file system
	var filesystem = EditorInterface.get_resource_filesystem()
	if not filesystem:
		push_error("Could not get resource filesystem")
		return
	
	# Get the file's current import settings
	var import_settings_path = file_path + ".import"
	
	# Check if it's a scene file (GLB/GLTF)
	var ext = file_path.get_extension().to_lower()
	if ext not in ["glb", "gltf"]:
		push_error("File is not a GLB or GLTF file: " + file_path)
		return
	
	# Force a complete reimport by deleting the import file and cached resources
	print("Forcing complete reimport by clearing cache...")
	
	# Delete the import file to force Godot to recreate it with defaults
	if FileAccess.file_exists(import_settings_path):
		var dir = DirAccess.open("res://")
		if dir:
			dir.remove(import_settings_path)
			print("Deleted import file: ", import_settings_path)
	
	# Also clear any cached imported resources
	var resource_path = file_path.get_base_dir() + "/.godot/imported/" + file_path.get_file()
	var dir = DirAccess.open("res://")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.begins_with(".godot"):
				var imported_dir = DirAccess.open("res://.godot/imported/")
				if imported_dir:
					imported_dir.list_dir_begin()
					var imported_file = imported_dir.get_next()
					while imported_file != "":
						if imported_file.begins_with(file_path.get_file().get_basename()):
							imported_dir.remove(imported_file)
							print("Removed cached file: ", imported_file)
						imported_file = imported_dir.get_next()
					imported_dir.list_dir_end()
				break
			file_name = dir.get_next()
		dir.list_dir_end()
	
	# Trigger re-import to recreate with default settings
	filesystem.update_file(file_path)
	filesystem.reimport_files([file_path])
	
	print("Successfully forced complete reimport for: ", file_path)

# Helper function to get the correct import script path for a shape type
func _get_script_path_for_shape_type(shape_type: int) -> String:
	match shape_type:
		PhysicsBase.ShapeType.TRIMESH: return "res://addons/physics_collision_import_generator/import_scripts/import_physics_trimesh.gd"
		PhysicsBase.ShapeType.CONVEX: return "res://addons/physics_collision_import_generator/import_scripts/import_physics_convex.gd"
		PhysicsBase.ShapeType.BOX: return "res://addons/physics_collision_import_generator/import_scripts/import_physics_box.gd"
		PhysicsBase.ShapeType.SPHERE: return "res://addons/physics_collision_import_generator/import_scripts/import_physics_sphere.gd"
		PhysicsBase.ShapeType.CAPSULE: return "res://addons/physics_collision_import_generator/import_scripts/import_physics_capsule.gd"
		_: return "res://addons/physics_collision_import_generator/import_scripts/import_physics_trimesh.gd"  # Default fallback
