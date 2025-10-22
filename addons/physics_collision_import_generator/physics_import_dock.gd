@tool
extends Control

# Custom dock for physics import functionality

var plugin_reference
var file_list: ItemList
var refresh_button: Button
var apply_button: Button
var remove_button: Button
var shape_type_option: OptionButton
var shape_type_label: Label
var search_filter: LineEdit
var all_files: Array = []  # Store all found files for filtering

func _init():
	name = "Physics Import"
	custom_minimum_size = Vector2(200, 500)  # Increased height only
	_setup_ui()

func _setup_ui():
	# Create vertical layout
	var vbox = VBoxContainer.new()
	add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Title label
	var title = Label.new()
	title.text = "Physics Import Helper"
	title.add_theme_stylebox_override("normal", _create_header_style())
	vbox.add_child(title)
	
	# Info label
	var info = Label.new()
	info.text = "GLB/GLTF files in project:"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)
	
	# Search filter container
	var search_container = HBoxContainer.new()
	vbox.add_child(search_container)
	
	# Search filter
	search_filter = LineEdit.new()
	search_filter.placeholder_text = "Search files..."
	search_filter.custom_minimum_size = Vector2(0, 24)
	search_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_filter.text_changed.connect(_on_search_text_changed)
	search_container.add_child(search_filter)
	
	# Clear search button
	var clear_button = Button.new()
	clear_button.text = "×"
	clear_button.custom_minimum_size = Vector2(24, 24)
	clear_button.tooltip_text = "Clear search"
	clear_button.pressed.connect(_on_clear_search_pressed)
	search_container.add_child(clear_button)
	
	# Shape type selection
	shape_type_label = Label.new()
	shape_type_label.text = "Physics Shape Type:"
	vbox.add_child(shape_type_label)
	
	shape_type_option = OptionButton.new()
	shape_type_option.add_item("Trimesh (Exact)", 0)
	shape_type_option.add_item("Convex (Optimized)", 1)
	shape_type_option.add_item("Box (Simple)", 2)
	shape_type_option.add_item("Sphere (Simple)", 3)
	shape_type_option.add_item("Capsule (Simple)", 4)
	shape_type_option.selected = 0  # Default to Trimesh
	vbox.add_child(shape_type_option)
	
	# Add minimal spacing
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)  # Reduced spacing
	vbox.add_child(spacer)
	
	# File list (expandable)
	file_list = ItemList.new()
	file_list.custom_minimum_size = Vector2(0, 200)  # Increased minimum height
	file_list.size_flags_vertical = Control.SIZE_EXPAND_FILL  # Make it expand to fill available space
	file_list.allow_reselect = true  # Allow clicking the same item again
	file_list.auto_height = true  # Auto-adjust height for content
	vbox.add_child(file_list)
	
	# Buttons container
	var hbox = HBoxContainer.new()
	vbox.add_child(hbox)
	
	# Refresh button
	refresh_button = Button.new()
	refresh_button.text = "Refresh"
	refresh_button.pressed.connect(_on_refresh_pressed)
	hbox.add_child(refresh_button)
	
	# Apply physics button
	apply_button = Button.new()
	apply_button.text = "Apply Physics"
	apply_button.pressed.connect(_on_apply_physics_pressed)
	apply_button.disabled = true
	hbox.add_child(apply_button)
	
	# Remove physics button
	remove_button = Button.new()
	remove_button.text = "Remove Physics"
	remove_button.pressed.connect(_on_remove_physics_pressed)
	remove_button.disabled = true
	hbox.add_child(remove_button)
	
	# Connect file list selection
	file_list.item_selected.connect(_on_file_selected)
	
	# Initial refresh
	call_deferred("_refresh_file_list")

func _create_header_style() -> StyleBox:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.3, 0.4, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.6, 0.8, 1.0)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

func _refresh_file_list():
	# Get all GLB/GLTF files in the project and store them
	all_files = _find_gltf_files("res://")
	_update_filtered_list()

func _update_filtered_list():
	file_list.clear()
	apply_button.disabled = true
	remove_button.disabled = true
	
	# Get the current search filter
	var filter_text = search_filter.text.to_lower() if search_filter else ""
	
	# Filter and display files
	for file_path in all_files:
		var file_name = file_path.get_file()
		
		# Apply search filter
		if filter_text != "" and not file_name.to_lower().contains(filter_text):
			continue
		
		var item_index = file_list.add_item(file_name)
		file_list.set_item_metadata(item_index, file_path)
		
		# Check if it already has physics import script
		if _has_physics_import_script(file_path):
			file_list.set_item_custom_fg_color(item_index, Color.GREEN)
			file_list.set_item_tooltip(item_index, file_path + "\n✓ Physics import script applied")
		else:
			file_list.set_item_custom_fg_color(item_index, Color.WHITE)
			file_list.set_item_tooltip(item_index, file_path + "\n○ No physics import script")

func _find_gltf_files(directory: String) -> Array:
	var files = []
	var dir = DirAccess.open(directory)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			var full_path = directory + "/" + file_name
			
			if dir.current_is_dir() and not file_name.begins_with("."):
				# Recursively search subdirectories
				files.append_array(_find_gltf_files(full_path))
			elif file_name.get_extension().to_lower() in ["glb", "gltf"]:
				files.append(full_path)
			
			file_name = dir.get_next()
		
		dir.list_dir_end()
	
	return files

func _has_physics_import_script(file_path: String) -> bool:
	var import_path = file_path + ".import"
	if not FileAccess.file_exists(import_path):
		return false
	
	var config = ConfigFile.new()
	if config.load(import_path) != OK:
		return false
	
	var import_script_path = config.get_value("params", "import_script/path", "")
	return import_script_path == "res://addons/physics_collision_import_generator/import_physics_script.gd"

func _on_refresh_pressed():
	_refresh_file_list()

func _on_search_text_changed(new_text: String):
	# Update the filtered list whenever search text changes
	_update_filtered_list()

func _on_clear_search_pressed():
	# Clear the search filter
	search_filter.text = ""
	_update_filtered_list()

func _on_file_selected(index: int):
	apply_button.disabled = false
	remove_button.disabled = false

func _on_apply_physics_pressed():
	var selected_items = file_list.get_selected_items()
	if selected_items.size() == 0:
		return
	
	# Get the selected shape type
	var shape_type = shape_type_option.selected
	
	for index in selected_items:
		var file_path = file_list.get_item_metadata(index)
		if plugin_reference:
			plugin_reference.set_physics_import_script(file_path, shape_type)
	
	# Refresh the list to update colors
	call_deferred("_update_filtered_list")

func _on_remove_physics_pressed():
	var selected_items = file_list.get_selected_items()
	if selected_items.size() == 0:
		return
	
	for index in selected_items:
		var file_path = file_list.get_item_metadata(index)
		if plugin_reference:
			plugin_reference.remove_physics_import_script(file_path)
	
	# Refresh the list to update colors
	call_deferred("_update_filtered_list")
