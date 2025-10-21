@tool
extends EditorPlugin

var import_plugin

func _enter_tree():
	# Add the enhanced Scene importer with physics options
	import_plugin = preload("res://addons/physics_collision_import_generator/import_physics_dockplugin.gd").new()
	add_import_plugin(import_plugin)
	print("Physics & Collision Import Generator enabled")
	print("Use 'Scene (with Physics Options)' importer for GLB/GLTF files")

func _exit_tree():
	if import_plugin:
		remove_import_plugin(import_plugin)
		import_plugin = null
	print("Physics & Collision Import Generator disabled")
