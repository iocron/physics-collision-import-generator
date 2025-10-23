@tool
extends "res://addons/physics_collision_import_generator/import_scripts/import_physics_base.gd"

# Physics import script for Sphere collision shapes

func get_shape_type() -> int:
	return ShapeType.SPHERE

func get_shape_name() -> String:
	return "Sphere"
