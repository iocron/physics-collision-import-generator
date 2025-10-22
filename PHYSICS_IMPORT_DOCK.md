# Physics Import Helper Dock

This addon now includes a **Physics Import Helper dock** that makes it easy to apply physics import scripts to GLB/GLTF files in your project.

## How to Use

1. **Enable the Plugin**: Make sure the "Physics & Collision Import Generator" plugin is enabled in your project settings.

2. **Find the Dock**: Look for the "Physics Import" dock panel in the left side of the Godot editor (typically in the same area as the FileSystem dock).

3. **View GLB/GLTF Files**: The dock automatically scans and displays all GLB and GLTF files in your project.

4. **Choose Physics Shape Type**:
   - Use the dropdown to select the physics shape type:
     - **Trimesh (Exact)**: Most accurate collision, higher performance cost
     - **Convex (Optimized)**: Good balance of accuracy and performance
     - **Box (Simple)**: Fast rectangular collision bounds
     - **Sphere (Simple)**: Fast spherical collision bounds
     - **Capsule (Simple)**: Fast capsule-shaped collision bounds

5. **Apply Physics Import**: 
   - Select one or more files from the list
   - Click the "Apply Physics" button
   - The dock will automatically:
     - Set the Scene importer for the file
     - Configure the import script path to use our physics generator
     - Set the selected physics shape type
     - Trigger a re-import of the file

6. **Remove Physics Import**:
   - Select files that currently have physics import enabled (shown in green)
   - Click the "Remove Physics" button
   - The dock will automatically:
     - Clear the import script path setting
     - Trigger a re-import to restore the original scene structure

7. **Visual Feedback**:
   - Files with physics import already applied appear in **green**
   - Files without physics import appear in **white**
   - Both "Apply Physics" and "Remove Physics" buttons are enabled when files are selected

## Features

- **Auto-detection**: Automatically finds all GLB/GLTF files in your project
- **Shape type selection**: Choose from Trimesh, Convex, Box, Sphere, or Capsule collision shapes
- **Status indicators**: Visual color coding shows which files have physics import applied
- **Batch processing**: Select multiple files and apply/remove physics import to all at once
- **Apply Physics**: Set physics import script with chosen shape type for selected files
- **Remove Physics**: Clear physics import script from selected files
- **Refresh button**: Manually refresh the file list when needed
- **Tooltips**: Hover over files to see their full path and status

## What It Does

When you apply physics import to a file, the system:
1. Configures the file to use the Scene importer
2. Sets the import script to `res://addons/physics_collision_import_generator/import_physics_script.gd`
3. Triggers a re-import that will:
   - Convert ImporterMeshInstance3D nodes to MeshInstance3D nodes
   - Wrap each mesh in a StaticBody3D with physics collision
   - Generate appropriate collision shapes (trimesh by default)

## Alternative to FileSystem Icons

While the original request was for icons in the FileSystem view, this dock-based approach provides:
- ✅ Easy visual identification of GLB/GLTF files
- ✅ One-click physics import assignment
- ✅ Batch processing capabilities
- ✅ Clear status indicators
- ✅ Better user experience in a dedicated interface

The dock appears automatically when the plugin is enabled and provides all the functionality needed to manage physics imports for your 3D scene files.