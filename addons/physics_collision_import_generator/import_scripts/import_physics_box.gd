@tool
extends "res://addons/physics_collision_import_generator/import_scripts/import_physics_base.gd"

# Physics import script for Box collision shapes

func get_shape_type() -> int:
	return ShapeType.BOX

func get_shape_name() -> String:
	return "Box"
