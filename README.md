# Physics & Collision Import Generator

This Godot plugin automatically generates physics bodies and collision shapes during the import of 3D scenes from GLB/GLTF files, with potential support for more formats in the future.

## Installation

1. Copy the `physics_collision_import_generator` folder to your project's `addons/` directory
2. Go to Project Settings → Plugins
3. Enable the "Physics & Collision Import Generator" plugin

## Usage

1. Import a GLB or GLTF file into your project
2. Select the file in the FileSystem dock
3. In the Import tab, select "Scene (with Physics Options)" as the importer
4. Configure the physics options:
   - **Physics > Create Physics Bodies**: Enable automatic physics generation
   - **Physics > Shape Type**: Choose between Trimesh, Convex, Box, Sphere, or Capsule
   - **Physics > Collision Layer**: Set the collision layer for the generated physics bodies
   - **Physics > Collision Mask**: Set the collision mask for the generated physics bodies
5. Use the "With Physics" preset for quick setup
6. Click "Reimport" to apply the changes

## Features

- Automatically creates StaticBody3D nodes with CollisionShape3D for all MeshInstance3D nodes
- Multiple physics shape types supported
- Configurable collision layers
- Preserves existing scene structure
- Only shows physics options when the main option is enabled

## Shape Types

- **Trimesh**: Exact mesh shape (best for static geometry)
- **Convex**: Convex hull approximation (good performance/accuracy balance)
- **Box**: Simple box shape based on mesh bounds
- **Sphere**: Simple sphere shape based on mesh bounds  
- **Capsule**: Simple capsule shape based on mesh bounds

## Notes

- Physics bodies are created as StaticBody3D by default
- Existing StaticBody3D nodes are reused when possible
- The plugin works by post-processing the imported scene after the standard GLTF import
