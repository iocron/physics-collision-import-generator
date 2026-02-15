@tool
extends Control

# Custom dock for physics import functionality

const PhysicsBase = preload("res://addons/physics_collision_import_generator/import_scripts/import_physics_base.gd")

var plugin_reference
var file_list: ItemList
var refresh_button: Button
var apply_button: Button
var apply_all_button: Button # Added
var remove_button: Button
var shape_type_option: OptionButton
var shape_type_label: Label
var search_filter: LineEdit
var all_files: Array = []  # Store all found files for filtering
var _icon_green: ImageTexture
var _icon_gray: ImageTexture

func _init():
	name = "Collision Import Generator"
	custom_minimum_size = Vector2(200, 500)  # Increased height only
	_create_status_icons()
	_setup_ui()

func _create_status_icons():
	for color in [Color.GREEN, Color.GRAY]:
		var img = Image.create(12, 12, false, Image.FORMAT_RGBA8)
		img.fill(Color.TRANSPARENT)
		for x in range(2, 10):
			for y in range(2, 10):
				img.set_pixel(x, y, color)
		var tex = ImageTexture.create_from_image(img)
		if color == Color.GREEN:
			_icon_green = tex
		else:
			_icon_gray = tex

func _setup_ui():
	# Create vertical layout
	var vbox = VBoxContainer.new()
	add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Title label
	# var title = Label.new()
	# title.text = "Physics Collision Import Generator"
	# title.add_theme_stylebox_override("normal", _create_header_style())
	# vbox.add_child(title)
	
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
	search_filter.placeholder_text = "Filter Files"
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
	shape_type_option.add_item("CHOOSE:", PhysicsBase.ShapeType.NONE)
	shape_type_option.add_item("Trimesh (Exact, but Slow)", PhysicsBase.ShapeType.TRIMESH)
	shape_type_option.add_item("Convex (Optimized)", PhysicsBase.ShapeType.CONVEX)
	shape_type_option.add_item("Box (Simple, Fastest)", PhysicsBase.ShapeType.BOX)
	shape_type_option.add_item("Sphere (Simple, Fastest)", PhysicsBase.ShapeType.SPHERE)
	shape_type_option.add_item("Capsule (Simple, Fastest)", PhysicsBase.ShapeType.CAPSULE)
	shape_type_option.selected = 0  # Default to None/Unknown
	shape_type_option.item_selected.connect(_on_shape_type_changed)
	vbox.add_child(shape_type_option)
	
	# Add minimal spacing
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)  # Reduced spacing
	vbox.add_child(spacer)
	
	# First row of buttons
	var hbox1 = HBoxContainer.new()
	vbox.add_child(hbox1)
	
	refresh_button = Button.new()
	refresh_button.text = "Refresh List"
	refresh_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refresh_button.pressed.connect(_on_refresh_pressed)
	hbox1.add_child(refresh_button)
	
	remove_button = Button.new()
	remove_button.text = "Remove Physics (selected)"
	remove_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	remove_button.pressed.connect(_on_remove_physics_pressed)
	remove_button.disabled = true
	hbox1.add_child(remove_button)

	# Second row of buttons (Apply actions)
	var hbox2 = HBoxContainer.new()
	vbox.add_child(hbox2)

	apply_button = Button.new()
	apply_button.text = "Apply Physics (selected)"
	apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_button.pressed.connect(_on_apply_physics_pressed)
	apply_button.disabled = true
	hbox2.add_child(apply_button)

	apply_all_button = Button.new()
	apply_all_button.text = "Apply to All"
	apply_all_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_all_button.pressed.connect(_on_apply_to_all_pressed)
	apply_all_button.disabled = true
	hbox2.add_child(apply_all_button)
	
	file_list = ItemList.new()
	file_list.custom_minimum_size = Vector2(0, 200)
	file_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	file_list.select_mode = ItemList.SELECT_MULTI
	file_list.allow_reselect = true
	file_list.auto_height = false # Set to false to allow scrolling in the dock
	vbox.add_child(file_list)

	file_list.multi_selected.connect(_on_multi_selected)
	call_deferred("_refresh_file_list")

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
			file_list.set_item_icon(item_index, _icon_green)
			file_list.set_item_tooltip(item_index, file_path + "\n✓ Physics import script applied")
		else:
			file_list.set_item_icon(item_index, _icon_gray)
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
	return _is_physics_import_script(import_script_path)

# Check if an import script path is one of our physics scripts
func _is_physics_import_script(script_path: String) -> bool:
	if script_path.is_empty():
		return false
	return script_path.matchn("*import_physics_*.gd")

# Get the physics shape type for a specific file by reading its import script
func _get_file_physics_shape_type(file_path: String) -> int:
	var import_path = file_path + ".import"
	if not FileAccess.file_exists(import_path):
		return PhysicsBase.ShapeType.NONE
	
	var config = ConfigFile.new()
	if config.load(import_path) != OK:
		return PhysicsBase.ShapeType.NONE
	var script_path = config.get_value("params", "import_script/path", "")
	
	if script_path.is_empty():
		return PhysicsBase.ShapeType.NONE
	var type_name = script_path.get_file().get_basename().replace("import_physics_", "").to_upper()
	match type_name:
		"TRIMESH": return PhysicsBase.ShapeType.TRIMESH
		"CONVEX": return PhysicsBase.ShapeType.CONVEX
		"BOX": return PhysicsBase.ShapeType.BOX
		"SPHERE": return PhysicsBase.ShapeType.SPHERE
		"CAPSULE": return PhysicsBase.ShapeType.CAPSULE
		_: return PhysicsBase.ShapeType.NONE

func _restore_selection(file_paths: Array) -> void:
	for i in range(file_list.item_count):
		if file_list.get_item_metadata(i) in file_paths:
			file_list.select(i, false)
	var selected = file_list.get_selected_items()
	if selected.size() > 0:
		_on_multi_selected(selected[0], true)

func _on_refresh_pressed():
	_refresh_file_list()

func _on_search_text_changed(_new_text: String):
	# Update the filtered list whenever search text changes
	_update_filtered_list()

func _on_clear_search_pressed():
	# Clear the search filter
	search_filter.text = ""
	_update_filtered_list()

func _update_button_states() -> void:
	var has_shape := shape_type_option.get_selected_id() != PhysicsBase.ShapeType.NONE
	var has_selection := not file_list.get_selected_items().is_empty()
	apply_button.disabled = not (has_shape and has_selection)
	remove_button.disabled = not (has_shape and has_selection)
	apply_all_button.disabled = not has_shape

func _on_shape_type_changed(_index: int) -> void:
	_update_button_states()

func _on_multi_selected(_index: int, _selected: bool) -> void:
	if file_list.get_selected_items().size() == 1:
		var shape_type := _get_file_physics_shape_type(file_list.get_item_metadata(file_list.get_selected_items()[0]))
		shape_type_option.selected = shape_type_option.get_item_index(shape_type) if shape_type != PhysicsBase.ShapeType.NONE else 0
	_update_button_states()

func _on_apply_physics_pressed():
	var selected_items = file_list.get_selected_items()
	var paths = []
	for idx in selected_items: paths.append(file_list.get_item_metadata(idx))
	_apply_to_paths(paths)

func _on_apply_to_all_pressed():
	var paths = []
	for i in range(file_list.item_count):
		paths.append(file_list.get_item_metadata(i))
	if paths.is_empty():
		return
	var shape_name = shape_type_option.get_item_text(shape_type_option.selected)
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "Are you sure to apply \"%s\" to %d file(s)?\nFiles with an existing physics shape will be overridden!" % [shape_name, paths.size()]
	dialog.confirmed.connect(func(): _apply_to_paths(paths))
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.confirmed.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()

func _apply_to_paths(paths: Array):
	if paths.is_empty() or not plugin_reference:
		return

	var shape_type = shape_type_option.get_selected_id()
	
	for path in paths:
		if shape_type != PhysicsBase.ShapeType.NONE:
			plugin_reference.set_physics_import_script(path, shape_type)
		else:
			plugin_reference.remove_physics_import_script(path)
	
	# Wait a bit for import to complete, then refresh
	await get_tree().create_timer(0.5).timeout
	_update_filtered_list()
	# Restore selection by finding the file paths in the refreshed list
	_restore_selection(paths)

func _on_remove_physics_pressed():
	var selected_items = file_list.get_selected_items()
	if selected_items.size() == 0:
		return
	
	var paths = []
	for idx in selected_items: paths.append(file_list.get_item_metadata(idx))
	for path in paths:
		plugin_reference.remove_physics_import_script(path)
		
	await get_tree().create_timer(0.5).timeout
	_update_filtered_list()
	
	# Restore selection by finding the file paths in the refreshed list
	_restore_selection(paths)
